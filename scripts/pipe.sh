#!/bin/bash

# Load configuration files and save variables
source config.sh
# Set raw_data and id from command-line arguments
raw_data="$1"  # The first argument is the input file path
id="$2"        # The second argument is the sample ID
log="$3"       # The third argument is the log file name
output_dir="$4" # The fourth argument controls output directory
input_count=$(grep -c '^@' "${raw_data}")
# Determine working/output directory
if [ -z "$output_dir" ] || [ "$output_dir" = "0" ]; then
    current_dir=$(pwd)
else
    if [ ! -d "$output_dir" ]; then
        echo "${er}ERROR:${in} Output directory does not exist: ${output_dir} ${r}"
        exit 1
    fi
    current_dir=$(cd "$output_dir" 2>/dev/null && pwd)
    if [ -z "$current_dir" ]; then
        echo "${er}ERROR:${in} Invalid output directory: ${output_dir} ${r}"
        exit 1
    fi
fi
# Append a separator to the log file
echo -e "///////////////////////////////////////////////////////////////////////////////////////////" >> "${log}"
mkdir -p "./${id}" # Create a directory for the sample ID
cd "./${id}"
# Prepare terminal display
total_tasks=9
progress_file="${current_dir}/${id}/progress.txt" # Define progress (in-terminal)
progress_info="${current_dir}/${id}/info.txt" # Define stats (in-terminal)
# Update message
echo "0,...and so it begins: ${input_count} raw reads" >> "${log}"
# Start the Python progress monitor in the background and pass the progress file path to it
python "${progress_monitor}" "${progress_file}" "${progress_info}" "${total_tasks}" "${id}" "${log}" &
# Save the PID of the background Python
PYTHON_PID=$!
# Ensure exit cleans up after itself
trap 'kill ${PYTHON_PID} 2>/dev/null; rm -f "${progress_file}" "${progress_info}"; mkdir -p "${current_dir}/${id}/logs"; mv "${log}" "${current_dir}/${id}/logs/" 2>/dev/null; exit' EXIT INT TERM
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
OTU="${current_dir}/${id}/OTU"
merge_o="${current_dir}/${id}/merge"
mkdir -p "${prep_f}"
mkdir -p "${prep_b}"
mkdir -p "${OTU}"
mkdir -p "${merge_o}"
mkdir -p ./logs
# Autoset Phred (aiming for 50-200k reads with highest phred possible)
if [ "${input_count}" -gt 2000000 ]; then
    phred="${phred_2000k}"
    mute_threshold="0.999"
elif [ "${input_count}" -gt 1500000 ]; then
    phred="${phred_1500k}"
    mute_threshold="0.999"
    # Make bin blaastn raw input
elif [ "${input_count}" -gt 500000 ]; then
    phred="${phred_500k}"
    mute_threshold="0.999"
    # Make bin blastn raw input
elif [ "${input_count}" -gt 300000 ]; then
    phred="${phred_300k}"
    mute_threshold="0.998"
    # Make bin blastn raw input
elif [ "${input_count}" -gt 200000 ]; then
    phred="${phred_200k}"
    mute_threshold="0.995"
    # Make bin blast raw input
elif [ "${input_count}" -gt 100000 ]; then
    phred="${phred_100k}"
    mute_threshold="0.995"
    # Make bin blastn raw input
elif [ "${input_count}" -gt 50000 ]; then
    phred="${phred_50k}"
    mute_threshold="0.99"
    # Make raw input blastn raw input
else
    phred="${phred_fail}"
    mute_threshold="0.99"
    # Make raw input blastn raw input
fi
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
cat "${prep_f}/${id}_muted_raw.fastq" | NanoFilt -q "${phred}" -l "$min_length" --maxlength "$max_length" > "${prep_f}/${id}_${phred}_Phred_total.fastq" 2>> "${log}" || { echo "ERROR: NanoFilt failed" >> "${log}"; exit 1; }
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
if [ "${input_count}" -lt "${min_Q_reads}" ]; then
  echo "${total_tasks}, ERROR" > "${progress_file}"
  wait "${PYTHON_PID}"
  rm -f "${progress_file}" "${progress_info}"
  sleep 1
  echo "${er}ERROR${r}: phred score filtration resulted in <"${min_Q_reads}" reads, this is insufficient depth, please go to the config and changes phred scores to match your data"
  echo "${er}ERROR${r}: phred score filtration resulted in <"${min_Q_reads}" reads, this is insufficient depth, please go to the config and changes phred scores to match your data" >> "${log}"
  exit 0
fi
seqtk sample -s100 "${prep_f}/${id}_${phred}_Phred_total.fastq" "${max_depth}" > "${prep_f}/${id}_${phred}_Phred.fastq"
#
# CHIMERA REMOVAL
echo "2,Prepairing to identify Chimeras" > "${progress_file}"
echo "${seq_count_raw} filtered reads; muted <${muted_phred} phred; ${percentage_filt_retained}% O/T" > "${progress_info}"
echo "(2) Searching for Chimeras: ${seq_count_raw} reads; ${percentage_filt_retained}%" >> "${log}"
# Convert the filtered FASTQ file to FASTA
seqtk seq -A "${prep_f}/${id}_${phred}_Phred.fastq" > "${prep_f}/${id}_filtered.fasta" || { echo "ERROR: converting fastq to fasta failed" >> "${log}"; exit 1; }
# Check if the filtered FASTA file is created
if [ ! -s "${prep_f}/${id}_filtered.fasta" ]; then
    echo "${er}ERROR:${in} vsearch output empty ${r}"
    echo "ERROR: fastq to fasta conversion (seqtk) failed: filtered file is empty" >> "${log}"
    exit 1
fi
# Run vsearch to detect and remove chimeras
echo "3,Searching for Chimeras" > "${progress_file}"
echo "(3) Searching for Chimeras" >> "${log}"
# Vsearch chimera/nonchimera
vsearch --uchime_ref "${prep_f}/${id}_filtered.fasta" --db "${fasta_filtered_database}" --nonchimeras "${prep_b}/${id}_nonchimeric.fasta" --chimeras "${prep_f}/${id}_chimeras.fasta" --threads "$cores" --minh 0.25  >> "${log}" 2>&1
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
# Clustering
echo "5,Clustering reads" > "${progress_file}" 
echo "(5) Clustering reads" >> "${log}"
# working original
seq_ident_cd="0.80"
align_long_cd="0.80"
align_short_cd="0.70"
unalign_short_cd="0.20"
unalign_long_cd="0.18"
#
M_RAM=$(echo "$RAM * 1000" | bc)
cd-hit-est -i "${prep_b}/${id}_nonchimeric.fasta" -o "${OTU}/clusters.fasta" -c "${seq_ident_cd}" -aL "${align_long_cd}" -aS "${align_short_cd}" -uL "${unalign_long_cd}" -uS "${unalign_short_cd}" -b 100 -G 0 -g 1 -r 1 -mask N -M "${M_RAM}" -T "${cores}" >> "${log}" 2>&1 || {
  echo "ERROR: failed to cluster reads" >> "${log}"
  exit 1;
}
hits=$(grep -c '^>' "${OTU}/clusters.fasta" )
#
# Blastn HAC
echo "$input_count reads in $hits OTUs" > "${progress_info}"
echo "6,Blasting HAC data" > "${progress_file}"
echo "(6) Blasting HAC data" >> "${log}"
# Blastn HAC
blastn -query "${OTU}/clusters.fasta" -db "$blastn_database" -out "${OTU}/${id}_blastn.out" -task megablast -reward 8 -penalty -10 -gapopen 6 -gapextend 10 -max_target_seqs 10 -qcov_hsp_perc "${cov_HAC}" -perc_identity "${ident_HAC}" -evalue 1e-5 -outfmt "6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore stitle" -num_threads "${cores}" 2>> "${log}" || {
  echo "ERROR: Blastn failed HAC data" >> "${log}";
  exit 1;
}
python "$blast_consensus" "${OTU}/${id}_blastn.out" "${OTU}/${id}_blast_consensus.out" 2>> "${log}"
#
# Blastn RAW against HAC
echo "7,Blasting RAW data" > "${progress_file}"
echo "(7) Blasting RAW data" >> "${log}"
echo "$input_count in $hits hits" > "${progress_info}"
python "$generate_con_database" "${OTU}/${id}_blast_consensus.out" "${OTU}/clusters.fasta" "${OTU}/HAC_database.fasta" >> "${log}" 2>&1
makeblastdb -in "${OTU}/HAC_database.fasta" -dbtype nucl -out "${OTU}/HAC/" -title "HAC" >> "${log}" 2>&1
blastn -query "${prep_b}/${id}_nonchimeric.fasta" -db "${OTU}/HAC" -out "${OTU}/${id}_RAWxHAC.out" -task megablast -reward 8 -penalty -10 -gapopen 6 -gapextend 10 -max_target_seqs 1 -perc_identity "${ident_RAW}" -evalue 1e-30 -outfmt "6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore stitle" -num_threads "${cores}" 2>> "${log}" || {
  echo "ERROR: Blastn failed w/ raw bin" >> "${log}";
  exit 1;
}
# Reduce to abundance values
python "$reduce_to_abundance" "${OTU}/${id}_RAWxHAC.out" "${OTU}/${id}_RAWxHAC.tsv" >> "${log}" 2>&1
OTU_num=$(wc -l < "${OTU}/${id}_RAWxHAC.out")
#
#
#
# NORMALISE, UNBIAS, AND MERGE DATA
echo "8,Normalising, bias correcting, and merging data" > "${progress_file}"
echo "(8) Blasting bin" >> "${log}"
echo "$OTU_num OTUs identified" > "${progress_info}"
# Count total reads and normalize
echo "sample_read_count=$OTU" >> "${log}"
python "${normalise}" "${OTU}/${id}_RAWxHAC.tsv" "${norm_factor}" "${merge_o}/${id}_norm_bias.tsv" "${log}" "${OTU_num}"
# Bias correction
python "${bias_correction}" --in "${merge_o}/${id}_norm_bias.tsv" --18s "${bias_factor_18s}" --16s "${bias_factor_16s}" --o "${merge_o}/${id}_microbiome_full-tax.tsv" --log "${log}"
# Decontaminate if setup
if [ "$blank_active" -eq 1 ] && [ -e "$blank_loc" ]; then
  python "${simplify_taxa}" "${merge_o}/${id}_microbiome_full-tax.tsv" "${merge_o}/${id}_Q${phred}_contaminated_microbiome.tsv"
  # Make contig
  ini_path="${merge_o}/decon.ini"
  cat <<EOF > "$ini_path"
[decontamination]
sample_tsv = ${merge_o}/${id}_Q${phred}_contaminated_microbiome.tsv
blank_tsv = ${blank_loc}
output_tsv = ${merge_o}/${id}_Q${phred}_microbiome_all.tsv

blank_raw_reads = ${blank_read_count}
sample_raw_reads = ${OTU_num}
phred_score = ${phred}
phred_hq_threshold = ${phred_hq}

prevalence_threshold = 0.32
ratio_threshold = 0.2

scaling_factor = ${norm_factor}
aggression_factor = ${decontamination_factor}
EOF
  # Run the decontamination Python script with the generated INI
  python "${decontaminate}" --config "${ini_path}" --log "${log}"
else
  python "${simplify_taxa}" "${merge_o}/${id}_microbiome_full-tax.tsv" "${merge_o}/${id}_Q${phred}_microbiome_all.tsv"
fi
# Remove low abundance (likely missclassifications) and plot
cutoff=$(printf "%.0f" "$(echo "$norm_factor * $norm_filter" | bc -l)")
awk -v c="$cutoff" -F'\t' '$2 >= c' "${merge_o}/${id}_Q${phred}_microbiome_all.tsv" > "./${id}_Q${phred}_SPECIES-LEVEL.tsv"
python "${genus_roleup}" --full "${merge_o}/${id}_microbiome_full-tax.tsv" --in "./${id}_Q${phred}_SPECIES-LEVEL.tsv" -o "./${id}_Q${phred}_GENUS-LEVEL.tsv"
python "${plot_taxa}" "./${id}_Q${phred}_SPECIES-LEVEL.tsv" "./${id}_Q${phred}_GENUS-LEVEL.tsv" "./${id}_Q${phred}_microbiome.png"
# Log completion message
echo "9,Pipeline complete" > "${progress_file}"
echo " " > "${progress_info}"
echo "(9) Pipeline complete:
${id}/
${id}_Q${phred}_SPECIES-LEVEL.tsv
${id}_Q${phred}_GENUS-LEVEL.tsv
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
