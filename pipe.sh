#!/bin/bash

# Load configuration files and save variables
source config.sh
# Set raw_data and id from command-line arguments
raw_data="$1"  # The first argument is the input file path
id="$2"        # The second argument is the sample ID
log="$3"       # The third argument is the log file name
input_count=$(grep -c '^@' "${raw_data}")
#start_point="$4"
current_dir=$(pwd)
# Append a separator to the log file
echo -e "///////////////////////////////////////////////////////////////////////////////////////////" >> "${log}"
mkdir -p ./${id} # Create a directory for the sample ID
cd ./${id}

# Prepare terminal display
total_tasks=11
progress_file="${current_dir}/${id}/progress.txt" # Define progress (in-terminal)
progress_info="${current_dir}/${id}/info.txt" # Define stats (in-terminal)
# Count the number of reads in the raw data file

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
if [ "${amplicon_pre_set}" = "515y-926r" ]; then
  source "${subconfig}/AMP_515y-926r.sh"
fi
#
# Create directories for different stages of the pipeline
mkdir -p ".${prep_f}"
mkdir -p ".${prep_b}"
mkdir -p ".${EUK}"
mkdir -p ".${PROK}"
mkdir -p ".${merge_b}"
mkdir -p ./logs
#
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
#NanoFilt -q "${phred}" -l $min_length --maxlength "$max_length" < "${raw_data}" > ".${prep_f}/${id}_${phred}_Phred.fastq" 2>> "${log}" || { echo "ERROR: NanoFilt failed" >> "${log}"; exit 1; }
if [ ! -s ".${prep_f}/${id}_${phred}_Phred.fastq" ]; then
  echo "${er}ERROR:${in} Filtered FASTQ file is empty ${r}"
  echo "ERROR: Filtered FASTQ file is empty" >> "${log}"
  exit 1
fi
seq_count_raw=$(grep -c '^@' ".${prep_f}/${id}_${phred}_Phred.fastq")
percentage_filt_retained=$(echo "scale=2; ${seq_count_raw} / ${input_count} * 100" | bc)
if [ "${seq_count_raw}" -eq 0 ]; then
  echo "${er}ERROR:${in} No reads retained after filtering ${r}"
  echo "${er}ERROR:${in} No reads retained after filtering" >> "${log}"
  exit 1
fi
# CHIMERA REMOVAL
echo "2,Prepairing to identify Chimeras" > "${progress_file}"
echo "${seq_count_raw} reads; ${percentage_filt_retained}% O/T" > "${progress_info}"
echo "(2) Searching for Chimeras: ${seq_count_raw} reads; ${percentage_filt_retained}%" >> "${log}"
# Convert the filtered FASTQ file to FASTA
#vsearch --fastq_filter ".${prep_f}/${id}_${phred}_Phred.fastq" --fastq_qmax 70 --fastaout ".${prep_f}/${id}_filtered.fasta" >> "${log}" 2>&1 || { echo "ERROR: vsearch fastq_filter failed" >> "${log}"; exit 1; }
# Check if the filtered FASTA file is created
if [ ! -s ".${prep_f}/${id}_filtered.fasta" ]; then
    echo "${er}ERROR:${in} vsearch output empty ${r}"
    echo "ERROR: vsearch fastq_filter failed: filtered file is empty" >> "${log}"
    exit 1
fi
# Run vsearch to detect and remove chimeras
echo "3,Searching for Chimeras" > "${progress_file}"
echo "(3) Searching for Chimeras" >> "${log}"
#vsearch --uchime_ref ".${prep_f}/${id}_filtered.fasta" --db "$fasta_filtered_database" --nonchimeras ".${prep_f}/${id}_nonchimeric.fasta" --chimeras ".${prep_f}/${id}_chimeras.fasta" --threads "$cores" >> "${log}" 2>&1
# Check if non-chimeric file is created
if [ ! -s ".${prep_f}/${id}_nonchimeric.fasta" ]; then
    echo "ERROR: vsearch chimera detection failed: non-chimeric file is empty" >> "${log}"
    echo "${er}ERROR:${in} non-chimeric file is empty ${r}"
    exit 1
fi
#
#
#
# QC
seq_count_nonchimeric=$(grep -c '^>' ".${prep_f}/${id}_nonchimeric.fasta")
total_qc_lost=$(echo "scale=2; ${seq_count_nonchimeric} / ${input_count} * 100" | bc)
percentage_nonchimeric_retained=$(echo "scale=2; ${seq_count_raw} / ${input_count} * 100" | bc)
if [ "${seq_count_nonchimeric}" -eq 0 ]; then
  echo "ERROR: No reads retained after filtering. Exiting" >> "${log}"
  echo "${er}ERROR:${in} No reads retained after filtering ${r}"
fi
echo "4,Isolating non-chimeric amplicons" > "${progress_file}"
echo "${seq_count_nonchimeric} reads, ${percentage_nonchimeric_retained}% non-chimeric, ${total_qc_lost} O/T" > "${progress_info}"
echo "(4) Isolating non-chimeric amplicons: ${seq_count_nonchimeric} reads, ${percentage_nonchimeric_retained}% of ${total_qc_lost}" >> "${log}"
# Extract
#minimap2 -ax map-ont -t "${cores}" ".${prep_f}/${id}_nonchimeric.fasta" ".${prep_f}/${id}_${phred}_Phred.fastq" > ".${prep_f}/${id}_nonchimeric.sam" 2>> "${log}"
#samtools view -F 260 -F 4 -F 2048 -bS ".${prep_f}/${id}_nonchimeric.sam" | samtools sort -o ".${prep_f}/${id}_nonchimeric.bam" 2>> "${log}"
#samtools fastq ".${prep_f}/${id}_nonchimeric.bam" > ".${prep_b}/${id}_nonchimeric.fastq" 2>> "${log}"
#
#
#
# BINNING AND ERROR CORRECTION
input_count=$(grep -c '^@' ".${prep_b}/${id}_nonchimeric.fastq")
# 16S update
echo "5,Binning 16S (${default_database_name} ${default_database_version})" > "${progress_file}" 
echo "(5) Binning 16S: non-chimeric reads =${seq_count_filtered}, ${percentage_retained}% " >> "${log}"
# 16s BIN
#minimap2 -ax map-ont -t "${cores}" --secondary=no "${fasta_16s_database}" ".${prep_b}/${id}_nonchimeric.fastq" > ".${prep_b}/16s_nonchimeric.sam" 2>> "${log}"
#samtools view -h -F 260 -F 4 -F 2048 ".${prep_b}/16s_nonchimeric.sam" > ".${prep_b}/16s_filtered_output.sam" 2>> "${log}"
align_raw_16s=$(grep -v '^@' ".${prep_b}/16s_filtered_output.sam" | wc -l)
per_16s=$(echo "scale=2; ($align_raw_16s / $input_count) * 100" | bc)

# 18S update
echo "6,Binning 18S (${default_database_name} ${default_database_version})" > "${progress_file}" 
echo "(6) Binning 18S: non-chimeric reads =${seq_count_filtered}, ${percentage_retained}% " >> "${log}"
# 18s BIN
#minimap2 -ax map-ont -t "${cores}" --secondary=no "${fasta_18s_database}" ".${prep_b}/${id}_nonchimeric.fastq" > ".${prep_b}/18s_nonchimeric.sam" 2>> "${log}"
#samtools view -h -F 260 -F 4 -F 2048 ".${prep_b}/18s_nonchimeric.sam" > ".${prep_b}/18s_filtered_output.sam" 2>> "${log}"
align_raw_18s=$(grep -v '^@' ".${prep_b}/18s_filtered_output.sam" | wc -l)
per_18s=$(echo "scale=2; ($align_raw_18s / $input_count) * 100" | bc)

# Seporation
echo "7,Refining bins" > "${progress_file}" 
echo "(7) Refining bins " >> "${log}"
count_total=$(echo "scale=0; ($align_raw_16s + $align_raw_18s)" | bc)
per_total=$(echo "scale=5; ($count_total/$input_count) * 100" | bc)
duplicated_count=$(comm -12 <(grep -o '^@[^[:space:]]*' ".${prep_b}/18s_filtered_output.sam" | sort) <(grep -o '^@[^[:space:]]*' ".${prep_b}/16s_filtered_output.sam" | sort) | wc -l)
per_dup=$(echo "scale=5; ($duplicated_count/$count_total) * 100" | bc)

echo "${duplicated_count} (${per_dup}%) duplicated in ${count_total} (${per_total}% O/T)" > "${progress_info}"
echo "\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ BINNING //////////////////////////" >> "${log}"
echo "  ${per_16s}% 16s ${per_18s}% 18s
  16s $input_count -> $align_raw_16s
  18s $input_count -> $align_raw_18s
  total ${per_total}%
  $duplicated_count duplicated, ${per_dup}% " >> "${log}"
# Identify a proportional background abundance
min_coverage_16s=$(echo "($align_raw_16s * 0.00005 + 0.999999)/1" | bc) # reduce minimum coverage to 0.00025% of the total reads
min_coverage_18s=$(echo "($align_raw_18s * 0.00005 + 0.999999)/1" | bc) # reduce minimum coverage to 0.005% of the total reads
# Filter -q <95% alingment confidence
python "$extract_high_AS" ".${prep_b}/16s_filtered_output.sam" "$min_coverage_16s" "$iden_16s" "$min_length" ".${prep_b}/16s_HQ_bin.sam" ".${prep_b}/16s_sim_filt.tsv" ".${prep_b}/16s_coverage.tsv" ".${PROK}/16s_filtered_bin" "fasta" >> "${log}"
python "$extract_high_AS" ".${prep_b}/18s_filtered_output.sam" "$min_coverage_18s" "$iden_18s" "$min_length" ".${prep_b}/18s_HQ_bin.sam" ".${prep_b}/18s_sim_filt.tsv" ".${prep_b}/18s_coverage.tsv" ".${EUK}/18s_filtered_bin" "fasta" >> "${log}"
# Log and count
fastq_bin_18s=$(grep -c '^>' ".${EUK}/18s_filtered_bin.fasta")
fastq_bin_16s=$(grep -c '^>' ".${PROK}/16s_filtered_bin.fasta")
bin_retain_16s=$(echo "scale=5; ($fastq_bin_16s/$align_raw_16s) * 100" | bc)
bin_retain_18s=$(echo "scale=5; ($fastq_bin_18s/$align_raw_18s) * 100" | bc)
bin_retain_total_16s=$(echo "scale=5; ($fastq_bin_16s/$count_total) * 100" | bc)
bin_retain_total_18s=$(echo "scale=5; ($fastq_bin_18s/$count_total) * 100" | bc)
read shared_count unique_16s unique_18s < <(python "$sam_dup_count" ".${prep_b}/16s_sim_filt.tsv" ".${PROK}/16s_filtered_bin.fasta" ".${prep_b}/18s_sim_filt.tsv" ".${EUK}/18s_filtered_bin.fasta")
# Log stats
echo "\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\ BIN FILTER RESULT /////////////////
  16s: $fastq_bin_16s reads, $unique_16s hits, ${bin_retain_16s}% retained across bin refinement, ${bin_retain_total_16s}% O/T
  18s: $fastq_bin_18s reads, $unique_18s hits, ${bin_retain_18s}% retained across bin refinement, ${bin_retain_total_18s}% O/T
  ${shared_count} duplicated reads
  " >> "${log}"
#
#
#
# Blastn 16S
echo "$align_raw_16s->$fastq_bin_16s ($unique_16s hits) 16S, ${shared_count} duplicated reads " > "${progress_info}"
echo "8,Blasting 16S bin" > "${progress_file}"
echo "(8) Blasting 16S bin" >> "${log}"
# Blastn
blastn -query ".${PROK}/16s_filtered_bin.fasta" -db "$blastn_16s_database" -out ".${PROK}/${id}_16s_blastn.out" -max_target_seqs 5 -perc_identity 85 -evalue 1e-5 -outfmt "6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore stitle" -num_threads "${cores}" 2>> "${log}"
python "$blast_consensus" ".${PROK}/${id}_16s_blastn.out" ".${PROK}/${id}_16s_blast_consensus.out"
python "$reduce_class" ".${PROK}/${id}_16s_blast_consensus.out" ".${PROK}/${id}_16s_class.tsv" 2>> "${log}"
# Update
echo "$align_raw_18s->$fastq_bin_18s 18S ($unique_18s hits) reads, ${shared_count} duplicated reads " > "${progress_info}"
echo "9,Blasting 18S bin" > "${progress_file}"
echo "(9) Blasting 18S bin" >> "${log}"
# Blastn 18S
blastn -query ".${EUK}/18s_filtered_bin.fasta" -db "$blastn_18s_database" -out ".${EUK}/${id}_18s_blastn.out" -max_target_seqs 5 -perc_identity 85 -evalue 1e-5 -outfmt "6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore stitle" -num_threads "${cores}" 2>> "${log}"
python "$blast_consensus" ".${EUK}/${id}_18s_blastn.out" ".${EUK}/${id}_18s_blast_consensus.out"
python "$reduce_class" ".${EUK}/${id}_18s_blast_consensus.out" ".${EUK}/${id}_18s_class.tsv" 2>> "${log}"
#
#
#
# NORMALISE, UNBIAS, AND MERGE DATA
echo "10,Normalising, bias correcting, and merging data" > "${progress_file}"
echo "(10) Blasting 16S bin" >> "${log}"
# Bias correction
python "${bias_correction}" ".${EUK}/${id}_16s_class.tsv" "${bias_factor_16s}" ".${merge_b}/${id}_16s_unbias.tsv" "${log}"
python "${bias_correction}" ".${EUK}/${id}_18s_class.tsv" "${bias_factor_18s}" ".${merge_b}/${id}_18s_unbias.tsv" "${log}"
# Count total reads and normalize
python "${normalise}" ".${merge_b}/${id}_16s_unbias.tsv" "${norm_factor}" ".${merge_b}/16s_microbiome.tsv" "${log}"
python "${normalise}" ".${merge_b}/${id}_18s_unbias.tsv" "${norm_factor}" ".${merge_b}/18s_microbiome.tsv" "${log}"
# Merge
python "${merge_16s_18s}" ".${merge_b}/${id}${in_m}/18s_microbiome.tsv" ".${merge_b}/${id}${in_m}/16s_microbiome.tsv" ".${merge_b}/${id}_microbiome_CON.tsv" "${log}"
# Log completion message
echo "11,Pipeline complete: see ${merge_b}/${id}_microbiome_CON.tsv" > "${progress_file}"
# Wait for the Python script to finish before removing the progress file and exiting
wait "${PYTHON_PID}"
rm -f "${progress_file}" "${progress_info}"