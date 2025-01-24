#!/bin/bash

# Load configuration files and save variables
source config.sh
# Set raw_data and id from command-line arguments
raw_data="$1"  # The first argument is the input file path
id="$2"        # The second argument is the sample ID
log="$3"       # The third argument is the log file name
input_count=$(grep -c '^@' "${raw_data}")
current_dir=$(pwd)
# Append a separator to the log file
echo -e "///////////////////////////////////////////////////////////////////////////////////////////" >> "${log}"
mkdir -p "./${id}" # Create a directory for the sample ID
cd "./${id}"
# Prepare terminal display
total_tasks=15
progress_file="${current_dir}/${id}/progress.txt" # Define progress (in-terminal)
progress_info="${current_dir}/${id}/info.txt" # Define stats (in-terminal)
# Update message
echo "0,...and so it begins: ${input_count} raw reads" >> "${log}"
# Start the Python progress monitor in the background and pass the progress file path to it
python "${progress_monitor}" "${progress_file}" "${progress_info}" "${total_tasks}" "${id}" "${log}" &
# Save the PID of the background Python
PYTHON_PID=$!
# Ensure exit cleans up after itself
trap 'kill ${PYTHON_PID} 2>/dev/null; rm -f ${progress_file}; rm -f ${progress_info}; mv ${log} ${current_dir}/${id}/logs/; exit' EXIT INT TERM
# Update (weird fix to python issue)
echo "0,...and so it begins: ${input_count} raw reads" > "${progress_file}"
echo "|||||||||||||||||" > "${progress_info}"
# Setup hardware configuration based on the variable hardware_use
if [ "${hardware_use}" = "light" ]; then
  source "${subconfig}/hardware-light.sh"
elif [ "${hardware_use}" = "heavy" ]; then
  source "${subconfig}/hardware-heavy.sh"
elif [ "${hardware_use}" = "super-light" ]; then
  source "${subconfig}/hardware-super-light.sh"
fi
# Setup GPU configuration if greedy_gpu is true
if [ "${greedy_gpu}" = "true" ]; then
  source "${subconfig}/GPU-greedy.sh"
fi
# Setup amplicon configuration based on amplicon_pre_set
source "${subconfig}/AMP_${amplicon_pre_set}.sh"
# Check database is setup corretly
required_files=("fasta_18s_database" "fasta_16s_database" "fasta_filtered_database")
for file_var in "${required_files[@]}"; do
    file_path="${!file_var}"  # Get the actual file path from the variable name
    if [ ! -s "$file_path" ]; then
        echo "${er}ERROR:${in} $file_var ($file_path) is missing or empty, use 'nap update-database' ${r}"
        exit 1
    fi
done
# Setup directories and locations
prep_f="${current_dir}/${id}/QC/filter"
prep_b="${current_dir}/${id}/QC/bining"
EUK="${current_dir}/${id}/EUK"
PROK="${current_dir}/${id}/PROK"
merge_o="${current_dir}/${id}/merge"
mkdir -p "${prep_f}"
mkdir -p "${prep_b}"
mkdir -p "${EUK}"
mkdir -p "${PROK}"
mkdir -p "${merge_o}"
mkdir -p ./logs
# Autoset Phred (aiming for 50-200k reads with highest phred possible)
if [ "${input_count}" -gt 1500000 ]; then
    phred="${phred_1500k}"
    mute_threshold="0.995"
    # Make bin blaastn raw input
elif [ "${input_count}" -gt 500000 ]; then
    phred="${phred_500k}"
    mute_threshold="0.993"
    # Make bin blastn raw input
elif [ "${input_count}" -gt 300000 ]; then
    phred="${phred_300k}"
    mute_threshold="0.99"
    # Make bin blastn raw input
elif [ "${input_count}" -gt 200000 ]; then
    phred="${phred_200k}"
    mute_threshold="0.985"
    # Make bin blast raw input
elif [ "${input_count}" -gt 100000 ]; then
    phred="${phred_100k}"
    mute_threshold="0.98"
    # Make bin blastn raw input
elif [ "${input_count}" -gt 50000 ]; then
    phred="${phred_50k}"
    mute_threshold="0.975"
    # Make raw input blastn raw input
else
    phred="${phred_fail}"
    mute_threshold="0.95"
    # Make raw input blastn raw input
fi
ident_threshold=$(echo "$mute_threshold - 0.095" | bc)
echo "Phred score auto set to: ${phred}" >> "${log}"
#
#
# FILTERING REA
echo "1,Filtering and trimming (Q${phred}, $min_length-$max_length bases)" > "${progress_file}"
echo "${input_count} reads; 100% O/T" > "${progress_info}"
echo "(1) Filtering and trimming (Q${phred}, $min_length - $max_length bases): ${input_count} reads; 100%" >> "${log}"
if [ ! -s "${raw_data}" ]; then
  echo "${er}ERROR:${in} Input file ${raw_data} is empty or does not exist ${r}"
  echo "ERROR: Input file ${raw_data} is empty or does not exist" >> "${log}"
  exit 1
fi
# Filtering
muted_phred=$(python "${mute}" "${raw_data}" "${mute_threshold}" "${prep_f}/${id}_muted_raw.fastq" "${log}")
NanoFilt -q "${phred}" -l "$min_length" --maxlength "$max_length" < "${raw_data}" > "${prep_f}/${id}_${phred}_Phred_total.fastq" 2>> "${log}" || { echo "ERROR: NanoFilt failed" >> "${log}"; exit 1; }
if [ ! -s "${prep_f}/${id}_${phred}_Phred_total.fastq" ]; then
  echo "${er}ERROR:${in} Filtered FASTQ file is empty ${r}"
  echo "ERROR: Q${phred} Filtered FASTQ file is empty" >> "${log}"
  exit 1
fi
seq_count_raw=$(grep -c '^@' "${prep_f}/${id}_${phred}_Phred_total.fastq")
percentage_filt_retained=$(echo "scale=2; ${seq_count_raw} / ${input_count} * 100" | bc)
if [ "${seq_count_raw}" -eq 0 ]; then
  echo "${er}ERROR:${in} No reads retained after filtering ${r}"
  echo "${er}ERROR:${in} No reads retained after filtering" >> "${log}"
  exit 1
fi
# If phred is to agressive, cancel run and warn user.
if [ "${input_count}" -lt 12000 ]; then
  wait "${PYTHON_PID}"
  rm -f "${progress_file}" "${progress_info}"
  echo "${er}ERROR${r}: phred score filtration resulted in <12,0000 reads, this is insufficient depth, please go to the config and changes phred scores to match your data"
fi
seqtk sample -s100 "${prep_f}/${id}_${phred}_Phred_total.fastq" "${max_depth}" > "${prep_f}/${id}_${phred}_Phred.fastq"
#
# CHIMERA REMOVAL
echo "2,Prepairing to identify Chimeras" > "${progress_file}"
echo "${seq_count_raw} filtered reads; muted <${muted_phred} phred; ${percentage_filt_retained}% O/T" > "${progress_info}"
echo "(2) Searching for Chimeras: ${seq_count_raw} reads; ${percentage_filt_retained}%" >> "${log}"
# Convert the filtered FASTQ file to FASTA
vsearch --fastq_filter "${prep_f}/${id}_${phred}_Phred.fastq" --fastq_qmax 70 --fastaout "${prep_f}/${id}_filtered.fasta" >> "${log}" 2>&1 || { echo "ERROR: vsearch fastq_filter failed" >> "${log}"; exit 1; }
# Check if the filtered FASTA file is created
if [ ! -s "${prep_f}/${id}_filtered.fasta" ]; then
    echo "${er}ERROR:${in} vsearch output empty ${r}"
    echo "ERROR: vsearch fastq_filter failed: filtered file is empty" >> "${log}"
    exit 1
fi
# Run vsearch to detect and remove chimeras
echo "3,Searching for Chimeras" > "${progress_file}"
echo "(3) Searching for Chimeras" >> "${log}"
# Vsearch chimera/nonchimera
vsearch --uchime_ref "${prep_f}/${id}_filtered.fasta" --db "${fasta_filtered_database}" --nonchimeras "${prep_b}/${id}_nonchimeric.fasta" --chimeras "${prep_f}/${id}_chimeras.fasta" --threads "$cores" >> "${log}" 2>&1
# Check if non-chimeric file is created
if [ ! -s "${prep_b}/${id}_nonchimeric.fasta" ]; then
    echo "ERROR: vsearch chimera detection failed: non-chimeric file is empty" >> "${log}"
    echo "${er}ERROR:${in} non-chimeric file is empty ${r}"
    exit 1
fi
# QC
seq_count_nonchimeric=$(grep -c '^>' "${prep_b}/${id}_nonchimeric.fasta")
total_qc_lost=$(echo "scale=2; ${seq_count_nonchimeric} / ${input_count} * 100" | bc)
# Confirm success
if [ "${seq_count_nonchimeric}" -eq 0 ]; then
  echo "ERROR: No reads retained after filtering. Exiting" >> "${log}"
  echo "${er}ERROR:${in} No reads retained after filtering ${r}"
fi
# Update terminal
echo "4,Isolating non-chimeric amplicons" > "${progress_file}"
echo "${seq_count_nonchimeric} non-chimeric reads, ${total_qc_lost} O/T" > "${progress_info}"
echo "(4) Isolating non-chimeric amplicons: ${seq_count_nonchimeric} reads, ${total_qc_lost}% O/T" >> "${log}"
# Extract
FILE_SIZE=$(stat -c%s "${prep_f}/${id}_${phred}_Phred.fastq")
CHUNK_SIZE=$(echo "$FILE_SIZE * 0.1 / 1" | bc)
CHUNK_SIZE=$(awk "BEGIN {print int(($CHUNK_SIZE+500)/1000)*1000}")
# Ensure a minimum chunk size to avoid too small chunks
MIN_CHUNK_SIZE=1000
if [ $CHUNK_SIZE -lt $MIN_CHUNK_SIZE ]; then
    CHUNK_SIZE=$MIN_CHUNK_SIZE
fi
python "$extract_nonchimeric" "${prep_b}/${id}_nonchimeric.fasta" "${prep_f}/${id}_${phred}_Phred.fastq" "${prep_b}/${id}_nonchimeric.fastq" "${cores}" "${CHUNK_SIZE}" >> "${log}" 2>&1 || {
  echo "ERROR: failed to extract nonchimeric reads quality information" >> "${log}";
  exit 1;
}
#
#
# Determin quality of data
input_count=$(grep -c '^@' "${prep_b}/${id}_nonchimeric.fastq")
# Constants
max_reads=200000   # Maximum read count for scaling
min_reads=10000    # Minimum read count to avoid log(0)
low_phred=20       # Minimum phred for scaling
high_phred=35      # Maximum phred for scaling
# Reads Contribution
if [ "${input_count}" -ge "${min_reads}" ]; then
    reads_contribution=$(echo "50 * l(${input_count}) / l(${max_reads})" | bc -l)
else
    reads_contribution=0
fi
# Phred Contribution
if [ "${phred}" -ge "${low_phred}" ]; then
    phred_contribution=$(echo "50 * (${phred} - ${low_phred}) / (${high_phred} - ${low_phred})" | bc -l)
    if [ "${phred}" -gt "${high_phred}" ]; then
        phred_contribution=50
    fi
else
    phred_contribution=0
fi
# Calculate Quality Score
quality_score=$(echo "${reads_contribution} + ${phred_contribution}" | bc -l)
quality_score=$(echo "if (${quality_score} > 100) 100 else if (${quality_score} < 0) 0 else ${quality_score}" | bc -l)
quality_score=$(printf "%.0f" "$quality_score")
#
#
# BINNING AND ERROR CORRECTION
# 16S update
echo "5,Binning 16S (${default_database_name} ${default_database_version})" > "${progress_file}" 
echo "(5) Binning 16S: ${input_count} non-chimeric reads" >> "${log}"
# 16s BIN
minimap2 -ax map-ont --secondary=no --eqx -t "${cores}" -K "${CHUNK_SIZE}" "${fasta_16s_database}" "${prep_b}/${id}_nonchimeric.fastq" > "${prep_b}/16s_nonchimeric.sam" 2>> "${log}" || {
  echo "ERROR: failed to bin nonchimeric reads against the 16s database" >> "${log}";
  exit 1;
}
# 18S update
echo "6,Binning 18S (${default_database_name} ${default_database_version})" > "${progress_file}" 
echo "(6) Binning 18S: ${input_count} non-chimeric reads" >> "${log}"
# 18s BIN
minimap2 -ax map-ont --secondary=no --eqx -t "${cores}" -K "${CHUNK_SIZE}" "${fasta_18s_database}" "${prep_b}/${id}_nonchimeric.fastq" > "${prep_b}/18s_nonchimeric.sam" 2>> "${log}" || {
  echo "ERROR: failed to bin nonchimeric reads against the 18s database" >> "${log}";
  exit 1;
}
# Seporation
echo "7,Refining bins" > "${progress_file}" 
echo "(7) Refining bins " >> "${log}"
# 16S (trim sam header portion, allows python to easily identify entries, then export >80% identify alighnments)
samtools view -F 4 -h "${prep_b}/16s_nonchimeric.sam" > "${prep_b}/16s_trimmed.sam"
python "$iden_high_AQ" "${prep_b}/16s_trimmed.sam" "${prep_b}/16s_CON.fasta" "${log}" "${ident_threshold}"
align_raw_16s=$(grep -c '^>' "${prep_b}/16s_CON.fasta")
per_16s=$(echo "scale=2; ($align_raw_16s / $input_count) * 100" | bc)
#
# 18S (trim sam header portion, allows python to easily identify entries, then export >80% identify alighnments)
samtools view -F 4 -h "${prep_b}/18s_nonchimeric.sam" > "${prep_b}/18s_trimmed.sam"
python "$iden_high_AQ" "${prep_b}/18s_trimmed.sam" "${prep_b}/18s_CON.fasta" "${log}" "${ident_threshold}"
align_raw_18s=$(grep -c '^>' "${prep_b}/18s_CON.fasta")
per_18s=$(echo "scale=2; ($align_raw_18s / $input_count) * 100" | bc)
#
# Stats
count_total=$(echo "scale=0; ($align_raw_16s + $align_raw_18s)" | bc)
per_total=$(echo "scale=5; ($count_total/$input_count) * 100" | bc)
duplicated_count=$(python "$duplicated_count" "${prep_b}/18s_CON.fasta" "${prep_b}/16s_CON.fasta")
per_dup=$(echo "scale=5; ($duplicated_count/$count_total) * 100" | bc)
echo "${duplicated_count} (${per_dup}%) duplicated in ${count_total} (${per_total}% of non-chimeric)" > "${progress_info}"
echo "\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ BINNING //////////////////////////" >> "${log}"
echo "  ${per_16s}% 16s ${per_18s}% 18s
  16s $input_count -> $align_raw_16s
  18s $input_count -> $align_raw_18s
  total ${per_total}%
  $duplicated_count duplicated, ${per_dup}% " >> "${log}"
# 
# 16S Clustering
echo "8,Clustering 16S bin" > "${progress_file}" 
echo "(8) Clustering 16S bin" >> "${log}"
seq_ident_cd="0.88"
word_len_cd="8"
align_long_cd="0.7"
align_short_cd="0.7"
unalign_short_cd="0.4"
unalign_long_cd="0.4"
#
M_RAM=$(echo "$RAM * 1000" | bc)
cd-hit-est -i "${prep_b}/16s_CON.fasta" -o "${PROK}/clusters.fasta" -c "${seq_ident_cd}" -n "${word_len_cd}" -aL "${align_long_cd}" -aS "${align_short_cd}" -uL "${unalign_long_cd}" -uS "${unalign_short_cd}" -b 70 -G 0 -g 1 -r 1 -mask N -M "${M_RAM}" -T "${cores}" >> "${log}" 2>&1 || {
  echo "ERROR: failed to cluster 16S bin with cd-hit-est" >> "${log}"
  exit 1;
}
hits_16s=$(grep -c '^>' "${PROK}/clusters.fasta" )
#
# 18S Clustering
echo "9,Clustering 18S bin" > "${progress_file}" 
echo "(9) Clustering 18S bin" >> "${log}"
cd-hit-est -i "${prep_b}/18s_CON.fasta" -o "${EUK}/clusters.fasta" -c "${seq_ident_cd}" -n "${word_len_cd}" -aL "${align_long_cd}" -aS "${align_short_cd}" -uL "${unalign_long_cd}" -uS "${unalign_short_cd}" -b 70 -G 0 -g 1 -r 1 -mask N -M "${M_RAM}" -T "${cores}" >> "${log}" 2>&1 || {
  echo "ERROR: failed to cluster 18S bin with cd-hit-est" >> "${log}";
  exit 1;
}
hits_18s=$(grep -c '^>' "${EUK}/clusters.fasta" )
#
#
# Taxanomiuc classification
# Blastn 16S CON
echo "$align_raw_16s in $hits_16s 16S hits" > "${progress_info}"
echo "10,Blasting 16S bin" > "${progress_file}"
echo "(10) Blasting 16S bin" >> "${log}"
# Blastn CON
blastn -query "${PROK}/clusters.fasta" -db "$blastn_16s_database" -out "${PROK}/${id}_16s_blastn.out" -reward 8 -penalty -10 -gapopen 6 -gapextend 10 -max_target_seqs 10 -perc_identity "${ident_CON_16s}" -evalue 1e-5 -outfmt "6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore stitle" -num_threads "${cores}" 2>> "${log}" || {
  echo "ERROR: Blastn failed w/ error corrected 16S" >> "${log}";
  exit 1;
}
python "$blast_consensus" "${PROK}/${id}_16s_blastn.out" "${PROK}/${id}_16s_blast_consensus.out" 2>> "${log}"
#
# Update
echo "11,Blasting 18S bin" > "${progress_file}"
echo "(11) Blasting 18S bin" >> "${log}"
echo "$align_raw_18s in $hits_18s 18S hits" > "${progress_info}"
# Blastn 18S CON
blastn -query "${EUK}/clusters.fasta" -db "$blastn_18s_database" -out "${EUK}/${id}_18s_blastn.out" -reward 8 -penalty -10 -gapopen 6 -gapextend 10 -max_target_seqs 10 -perc_identity "${ident_CON_18s}" -evalue 1e-5 -outfmt "6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore stitle" -num_threads "${cores}" 2>> "${log}" || {
  echo "ERROR: Blastn failed w/ error corrected 18S" >> "${log}";
  exit 1;
}
python "$blast_consensus" "${EUK}/${id}_18s_blastn.out" "${EUK}/${id}_18s_blast_consensus.out" 2>> "${log}"
#
# Blastn 16S RAW against CON
echo "12,Blasting RAW data against 16S CON" > "${progress_file}"
echo "(12) Blasting RAW data against 16S CON" >> "${log}"
echo "$align_raw_16s in $hits_16s 16S hits" > "${progress_info}"
python "$generate_con_database" "${PROK}/${id}_16s_blast_consensus.out" "${PROK}/clusters.fasta" "${PROK}/16s_CON_database.fasta" >> "${log}" 2>&1
makeblastdb -in "${PROK}/16s_CON_database.fasta" -dbtype nucl -out "${PROK}/16S_CON/" -title "16S_CON" >> "${log}" 2>&1
blastn -query "${prep_b}/16s_CON.fasta" -db "${PROK}/16S_CON" -out "${PROK}/${id}_16s_RAWxCON.out" -reward 8 -penalty -10 -gapopen 6 -gapextend 10 -max_target_seqs 1 -perc_identity "${ident_RAW_16s}" -evalue 1e-30 -outfmt "6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore stitle" -num_threads "${cores}" 2>> "${log}" || {
  echo "ERROR: Blastn failed w/ raw 16S bin" >> "${log}";
  exit 1;
}
python "$reduce_to_abundance" "${PROK}/${id}_16s_RAWxCON.out" "${PROK}/${id}_16s_RAWxCON.tsv" >> "${log}" 2>&1
#
# Blastn 18S RAW against CON
echo "13,Blasting RAW data against 18S CON" > "${progress_file}"
echo "(13) Blasting RAW data against 18S CON" >> "${log}"
echo "$align_raw_18s in $hits_18s 18S hits" > "${progress_info}"
python "$generate_con_database" "${EUK}/${id}_18s_blast_consensus.out" "${EUK}/clusters.fasta" "${EUK}/18s_CON_database.fasta" >> "${log}" 2>&1
makeblastdb -in "${EUK}/18s_CON_database.fasta" -dbtype nucl -out "${EUK}/18S_CON/" -title "18S_CON" >> "${log}" 2>&1
blastn -query "${prep_b}/18s_CON.fasta"  -db "${EUK}/18S_CON" -out "${EUK}/${id}_18s_RAWxCON.out" -reward 8 -penalty -10 -gapopen 6 -gapextend 10 -max_target_seqs 1 -perc_identity "${ident_RAW_18s}" -evalue 1e-30 -outfmt "6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore stitle" -num_threads "${cores}" 2>> "${log}" || {
  echo "ERROR: Blastn failed w/ raw 18S bin" >> "${log}";
  exit 1;
}
python "$reduce_to_abundance" "${EUK}/${id}_18s_RAWxCON.out" "${EUK}/${id}_18s_RAWxCON.tsv" >> "${log}" 2>&1
# Count taxanomic units
OTU_18s=$(wc -l < "${EUK}/${id}_18s_RAWxCON.out")
OTU_16s=$(wc -l < "${PROK}/${id}_16s_RAWxCON.out")
#
#
#
# NORMALISE, UNBIAS, AND MERGE DATA
echo "14,Normalising, bias correcting, and merging data" > "${progress_file}"
echo "(14) Blasting 16S bin" >> "${log}"
echo "$OTU_16s 16S and $OTU_18s 18S microbes identified" > "${progress_info}"
# Count total reads and normalize
total_abundance=$(echo "$OTU_18s + $OTU_16s" | bc)
echo "sample_read_count=$total_abundance" >> "${log}"
python "${normalise}" "${PROK}/${id}_16s_RAWxCON.tsv" "${norm_factor}" "${merge_o}/${id}_16s_norm_bias.tsv" "${log}" "$total_abundance"
python "${normalise}" "${EUK}/${id}_18s_RAWxCON.tsv" "${norm_factor}" "${merge_o}/${id}_18s_norm_bias.tsv" "${log}" "$total_abundance"
# Bias correction
python "${bias_correction}" "${merge_o}/${id}_16s_norm_bias.tsv" "${bias_factor_16s}" "${merge_o}/${id}_16s_unbias.tsv" "${log}"
python "${bias_correction}" "${merge_o}/${id}_18s_norm_bias.tsv" "${bias_factor_18s}" "${merge_o}/${id}_18s_unbias.tsv" "${log}"
# Merge, decontaminate, simplify taxa (genus species), and plot
python "${merge_16s_18s}" "${merge_o}/${id}_18s_unbias.tsv" "${merge_o}/${id}_16s_unbias.tsv" "${merge_o}/${id}_microbiome_full-tax.tsv" "${log}"
# Decontaminate if setup
if [ "$blank_active" -eq 1 ] && [ -e "$blank_average" ]; then
  python "${simplify_taxa}" "${merge_o}/${id}_microbiome_full-tax.tsv" "${merge_o}/${id}_Q${phred}_contaminated_microbiome.tsv"
  python "${decontaminate}" "${merge_o}/${id}_Q${phred}_contaminated_microbiome.tsv" "./${id}_Q${phred}_microbiome.tsv" "1.8" "$blank_average" "$phred" "$total_abundance" "$blank_read_count" "${log}"
else
  python "${simplify_taxa}" "${merge_o}/${id}_microbiome_full-tax.tsv" "./${id}_Q${phred}_microbiome.tsv"
fi
python "${plot_taxa}" "./${id}_Q${phred}_microbiome.tsv" "./${id}_Q${phred}_microbiome.png"
# Log completion message
echo "15,Pipeline complete: see ./${id}/${id}_Q${phred}_microbiome.tsv" > "${progress_file}"
echo "(15) Pipeline complete:
${id}/${id}_Q${phred}_microbiome.tsv
SAMPLE QUALITY SCORE: ${quality_score}" >> "${log}"
# Wait for the Python script to finish before removing the progress file and exiting
wait "${PYTHON_PID}"
rm -f "${progress_file}" "${progress_info}"
# Assess quality score
if (( $(echo "$quality_score > 80" | bc -l) )); then
    # Great
    echo -e "\033[42;30m SAMPLE QUALITY SCORE: ${quality_score}% \033[0m \033[47;30m Highly trustworthy output \033[0m"
elif (( $(echo "$quality_score > 60" | bc -l) )); then
    # OK
    echo -e "\033[43;30m SAMPLE QUALITY SCORE: ${quality_score}% \033[0m \033[47;30m Trustworthy results in highly taxonomically distinct organisms \033[0m"
elif (( $(echo "$quality_score > 20" | bc -l) )); then
    # low quality
    echo -e "\033[43;31m SAMPLE QUALITY SCORE: ${quality_score}% \033[0m \033[47;30m Likely contains artifacts, contamination with low microbiome resolution \033[0m"
else
    # very poor
    echo -e "\033[40;37m SAMPLE QUALITY SCORE: ${quality_score}% \033[0m \033[47;30m Low quality data, will contain artifacts, contamination, and low community resolution \033[0m"
fi
