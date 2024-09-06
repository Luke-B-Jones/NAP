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
# Get conda going and check for instilation issues
source "/opt/miniconda/etc/profile.d/conda.sh"
conda activate nap_env
if ! conda activate nap_env > /dev/null 2>&1; then
  echo "ERROR: Failed to activate conda environment 'nap_env'."
  exit 1
fi
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
trap 'kill ${PYTHON_PID} 2>/dev/null; rm -f ${progress_file}; conda deactivate; rm -f ${progress_info}; mv ${log} ${current_dir}/${id}/logs/; exit' EXIT INT TERM
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
required_files=("fasta_18s_database" "fasta_16s_database" "blastn_16s_database" "blastn_18s_database" "fasta_filtered_database")
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
merge_b="${current_dir}/${id}/merge/bin"
merge_o="${current_dir}/${id}/merge"
mkdir -p "${prep_f}"
mkdir -p "${prep_b}"
mkdir -p "${EUK}"
mkdir -p "${PROK}"
mkdir -p "${merge_b}"
mkdir -p ./logs
# Autoset Phred (aiming for 50-200k reads with highest phred possible)
if [ "${input_count}" -gt 500000 ]; then
    phred="${phred_500k}"
    varients_scaling_variable="2.05"
    clust_bit_star="0.845"
    clust_bit_end="0.81"
    clust_sim="0.848"
elif [ "${input_count}" -gt 300000 ]; then
    phred="${phred_300k}"
    varients_scaling_variable="2.1"
    clust_bit_star="0.845"
    clust_bit_end="0.81"
    clust_sim="0.847"
elif [ "${input_count}" -gt 200000 ]; then
    phred="${phred_200k}"
    varients_scaling_variable="2.2"
    clust_bit_star="0.843"
    clust_bit_end="0.81"
    clust_sim="0.846"
elif [ "${input_count}" -gt 100000 ]; then
    phred="${phred_100k}"
    varients_scaling_variable="2.35"
    clust_bit_star="0.84"
    clust_bit_end="0.8"
    clust_sim="0.844"
elif [ "${input_count}" -gt 50000 ]; then
    phred="${phred_50k}"
    varients_scaling_variable="2.45"
    clust_bit_star="0.84"
    clust_bit_end="0.8"
    clust_sim="0.84"
else
    phred="${phred_fail}"
    varients_scaling_variable="2.55"
    clust_bit_star="0.82"
    clust_bit_end="0.78"
    clust_sim="0.83"
fi
echo "Phred score auto set to: ${phred}" >> "${log}"
#
#
# FILTERING REA
echo "1,Filtering and trimming (Q${phred}, $min_length-$max_length bases)" > "${progress_file}"
echo "${input_count} reads; 100% O/T, Phred=${phred}" > "${progress_info}"
echo "(1) Filtering and trimming (Q${phred}, $min_length - $max_length bases): ${input_count} reads; 100%" >> "${log}"
if [ ! -s "${raw_data}" ]; then
  echo "${er}ERROR:${in} Input file ${raw_data} is empty or does not exist ${r}"
  echo "ERROR: Input file ${raw_data} is empty or does not exist" >> "${log}"
  exit 1
fi
# Filtering
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
echo "${seq_count_raw} filtered reads; ${percentage_filt_retained}% O/T" > "${progress_info}"
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
#
# BINNING AND ERROR CORRECTION
input_count=$(grep -c '^@' "${prep_b}/${id}_nonchimeric.fastq")
# 16S update
echo "5,Binning 16S (${default_database_name} ${default_database_version})" > "${progress_file}" 
echo "(5) Binning 16S: ${input_count} non-chimeric reads" >> "${log}"
# 16s BIN
minimap2 -ax map-ont -B 4 -O 2,5 -E 2,1 -N 5 --secondary=no -s 200 -t "${cores}" -K "${CHUNK_SIZE}" "${fasta_16s_database}" "${prep_b}/${id}_nonchimeric.fastq" > "${prep_b}/16s_nonchimeric.sam" 2>> "${log}" || {
  echo "ERROR: failed to bin nonchimeric reads against the 16s database" >> "${log}";
  exit 1;
}
# 18S update
echo "6,Binning 18S (${default_database_name} ${default_database_version})" > "${progress_file}" 
echo "(6) Binning 18S: ${input_count} non-chimeric reads" >> "${log}"
# 18s BIN
minimap2 -ax map-ont -B 4 -O 2,5 -E 2,1 -N 5 --secondary=no -s 200 -t "${cores}" -K "${CHUNK_SIZE}" "${fasta_18s_database}" "${prep_b}/${id}_nonchimeric.fastq" > "${prep_b}/18s_nonchimeric.sam" 2>> "${log}" || {
  echo "ERROR: failed to bin nonchimeric reads against the 18s database" >> "${log}";
  exit 1;
}
# Seporation
echo "7,Refining bins" > "${progress_file}" 
echo "(7) Refining bins " >> "${log}"
# 16S (trim sam header portion, allows python to easily identify entries, then export >60% identify alighnments)
sed '1,/^@PG/d' "${prep_b}/16s_nonchimeric.sam" > "${prep_b}/16s_trimmed.sam"
python "$iden_high_AQ" "${prep_b}/16s_trimmed.sam" "${prep_b}/16s_CON.fastq"
seqtk seq -A "${prep_b}/16s_CON.fastq" > "${prep_b}/16s_CON.fasta"
align_raw_16s=$(grep -c '^@' "${prep_b}/16s_CON.fastq")
per_16s=$(echo "scale=2; ($align_raw_16s / $input_count) * 100" | bc)
#
# 18S (trim sam header portion, allows python to easily identify entries, then export >60% identify alighnments)
sed '1,/^@PG/d' "${prep_b}/18s_nonchimeric.sam" > "${prep_b}/18s_trimmed.sam"
python "$iden_high_AQ" "${prep_b}/18s_trimmed.sam" "${prep_b}/18s_CON.fastq"
seqtk seq -A "${prep_b}/18s_CON.fastq" > "${prep_b}/18s_CON.fasta"
align_raw_18s=$(grep -c '^@' "${prep_b}/18s_CON.fastq")
per_18s=$(echo "scale=2; ($align_raw_18s / $input_count) * 100" | bc)
#
# Stats
count_total=$(echo "scale=0; ($align_raw_16s + $align_raw_18s)" | bc)
per_total=$(echo "scale=5; ($count_total/$input_count) * 100" | bc)
duplicated_count=$(python "$duplicated_count" "${prep_b}/18s_CON.fastq" "${prep_b}/16s_CON.fastq")
per_dup=$(echo "scale=5; ($duplicated_count/$count_total) * 100" | bc)
echo "${duplicated_count} (${per_dup}%) duplicated in ${count_total} (${per_total}% of non-chimeric)" > "${progress_info}"
echo "\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ BINNING //////////////////////////" >> "${log}"
echo "  ${per_16s}% 16s ${per_18s}% 18s
  16s $input_count -> $align_raw_16s
  18s $input_count -> $align_raw_18s
  total ${per_total}%
  $duplicated_count duplicated, ${per_dup}% " >> "${log}"
# 
# 16S
# Rattle 16s
echo "8,Clustering and polishing 16S bin" > "${progress_file}" 
echo "(8) Clustering and polishing 16S bin " >> "${log}"
# Return to gcc/g++ 9 env
conda deactivate
# Rattle
max_16s_variance=$(echo "$amplicon_16s_length * "$varients_scaling_variable" | bc)
rattle cluster -i "${prep_b}/16s_CON.fastq" -o "${PROK}/" -t "${cores}" -k 11 -s "${clust_sim}" -v "${max_16s_variance}" -B "${clust_bit_star}" -b "${clust_bit_end}" -f 0.05 --lower-length "$min_length" --upper-length "$max_length" --raw -t "${cores}" >> "${log}" 2>&1 || {
  echo "ERROR: Rattle failed to cluster 16s data" >> "${log}";
  exit 1;
}
rattle correct -i "${prep_b}/16s_CON.fastq" -c "${PROK}/clusters.out" -o "${PROK}/" -t "${cores}" -g 0.3 -m 0.33 -r 1 >> "${log}" 2>&1 || {
  echo "ERROR: Rattle failed to correct 16s data" >> "${log}";
  exit 1;
}
rattle polish -i "${PROK}/consensi.fq" -o "${PROK}/" -t "${cores}" --summary >> "${log}" 2>&1 || {
  echo "ERROR: Rattle failed to polish 16s clusters" >> "${log}";
  exit 1;
}
# Rattle 18s
echo "9,Clustering and polishing 18S bin" > "${progress_file}" 
echo "(9) Clustering and polishing 18S bin " >> "${log}"
max_18s_variance=$(echo "$amplicon_18s_length * "$varients_scaling_variable" | bc)
rattle cluster -i "${prep_b}/18s_CON.fastq" -o "${EUK}/" -t "${cores}" -k 11 -s "${clust_sim}" -v "${max_18s_variance}" -B "${clust_bit_star}" -b "${clust_bit_end}" -f 0.05 --lower-length "$min_length" --upper-length "$max_length" --raw -t "${cores}" >> "${log}" 2>&1 || {
  echo "ERROR: Rattle failed to cluster 18s data" >> "${log}";
  exit 1;
}
rattle correct -i "${prep_b}/18s_CON.fastq" -c "${EUK}/clusters.out" -o "${EUK}/" -t "${cores}" -g 0.3 -m 0.33 -r 1 >> "${log}" 2>&1 || {
  echo "ERROR: Rattle failed to correct 18s data" >> "${log}";
  exit 1;
}
rattle polish -i "${EUK}/consensi.fq" -o "${EUK}/" -t "${cores}" --summary >> "${log}" 2>&1 || {
  echo "ERROR: Rattle failed to polish 18s clusters" >> "${log}";
  exit 1;
}
# Return to conda env
source "/opt/miniconda/etc/profile.d/conda.sh"
conda activate nap_env
# Calc and convert
seqtk seq -A "${PROK}/transcriptome.fq" > "${PROK}/clusters.fasta"
hits_16s=$(grep -c '^>' "${PROK}/clusters.fasta" )
seqtk seq -A "${EUK}/transcriptome.fq" > "${EUK}/clusters.fasta"
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
blastn -query "${prep_b}/${id}_nonchimeric.fasta" -db "${PROK}/16S_CON" -out "${PROK}/${id}_16s_RAWxCON.out" -reward 8 -penalty -10 -gapopen 6 -gapextend 10 -max_target_seqs 1 -perc_identity "${ident_RAW_16s}" -evalue 1e-30 -outfmt "6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore stitle" -num_threads "${cores}" 2>> "${log}" || {
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
blastn -query "${prep_b}/${id}_nonchimeric.fasta"  -db "${EUK}/18S_CON" -out "${EUK}/${id}_18s_RAWxCON.out" -reward 8 -penalty -10 -gapopen 6 -gapextend 10 -max_target_seqs 1 -perc_identity "${ident_RAW_18s}" -evalue 1e-30 -outfmt "6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore stitle" -num_threads "${cores}" 2>> "${log}" || {
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
# Bias correction
python "${bias_correction}" "${PROK}/${id}_16s_RAWxCON.tsv" "${bias_factor_16s}" "${merge_b}/${id}_16s_unbias.tsv" "${log}"
python "${bias_correction}" "${EUK}/${id}_18s_RAWxCON.tsv" "${bias_factor_18s}" "${merge_b}/${id}_18s_unbias.tsv" "${log}"
# Count total reads and normalize
python "${normalise}" "${merge_b}/${id}_16s_unbias.tsv" "${norm_factor}" "${merge_b}/${id}_16s_microbiome.tsv" "${log}"
python "${normalise}" "${merge_b}/${id}_18s_unbias.tsv" "${norm_factor}" "${merge_b}/${id}_18s_microbiome.tsv" "${log}"
# Merge
python "${merge_16s_18s}" "${merge_b}/${id}_18s_microbiome.tsv" "${merge_b}/${id}_16s_microbiome.tsv" "${merge_b}/${id}_microbiome_full-tax.tsv" "${log}"
#python "${decontaminate}" "${merge_o}/${id}_microbiome.tsv" "${blank_microbiome}" "${decontamination_factor}"
python "{simplify_taxa}" "${merge_b}/${id}_microbiome_full-tax.tsv" "${merge_o}/${id}_Q${phred}_microbiome.tsv"
python "{plot_taxa}" "${merge_o}/${id}_Q${phred}_microbiome.tsv" "${merge_o}/${id}_Q${phred}_microbiome.png"
# Log completion message
echo "15,Pipeline complete: see ${merge_o}/${id}_Q${phred}_microbiome.tsv" > "${progress_file}"
# Wait for the Python script to finish before removing the progress file and exiting
wait "${PYTHON_PID}"
rm -f "${progress_file}" "${progress_info}"
conda deactivate
