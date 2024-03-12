#!/bin/bash

# Resourses and variables
source config.sh
cd=$(pwd)
# Set raw_data and id from command-line arguments
raw_data="$1"  # The first argument is the input file path
id="$2"        # The second argument is the sample ID
log="$3"	# The log name in
echo -e "///////////////////////////////////////////////////////////////////////////////////////////" >> "${log}"



###	Progress bar	###
#mkdir ./${id}
cd ./${id}

total_tasks=13  # Total number of tasks, adjust this based on your actual tasks
progress_file="${cd}/${id}/progress.txt" # Progress monitor
input_count=$(grep -c '^@' "$raw_data")

echo "0,...and so it begins: ${input_count} raw reads" > $progress_file
echo "0,...and so it begins: ${input_count} raw reads" >> ${log}
# Start the Python progress monitor in the background and pass the progress file path to it
python $progress_monitor "$progress_file" "$total_tasks" "$id" "${log}" &
# Save the PID of the background Python job to ensure we can wait for this specific job later
PYTHON_PID=$!
# Calculate the memory per core availbe
memory_per_core=$(echo "scale=0; ${RAM} / ${cores}" | bc)
export CUDA_VISIBLE_DEVICES=0 # Force GPU to be seen
# Ensure exit cleans up after itself # Ensure cancleing the script doesnt leave redundant progress.txt script
trap 'kill $PYTHON_PID 2>/dev/null; rm -f $progress_file; exit' EXIT INT TERM 
# Setup
#mkdir -p ./prep/bin
#mkdir -p ./prep/filter
#mkdir -p ./PROK/fasta
#mkdir -p ./EUK/fasta
#mkdir -p ./prep/RAW




######		Filtration and trimming by quality		######
echo "1,Filtering and trimming ${input_count} reads to Phred ${phred} and < ${filtered_amplicon_length}" > $progress_file
echo "1,Filtering and trimming ${input_count} reads to Phred ${phred} and < ${filtered_amplicon_length}" >> ${log}
#fastp \
#--in1 "${raw_data}" \
#--out1 ".${bb_f}/${id}_${phred}_Phred.fastq" \
#--cut_front \
#--cut_tail \
#--cut_mean_quality ${phred_t} \
#--length_required 200 \
#--average_qual ${phred} \
#--json ".${bb_out}/${id}_fastp_report.json" \
#--html ".${bb_out}/${id}_fastp_report.html" \
#>> ${log} 2>&1 || { echo "### fastp failed ###" >> "${log}"; exit 1; }

seq_count_raw=$(grep -c '^@' ".${bb_f}/${id}_${phred}_Phred.fastq")
percentage_filt_retained=$(echo "scale=2; $seq_count_raw / $input_count * 100" | bc)







#####		Chimera removal		######
echo "2,Searching for Chimeras in ${seq_count_raw} reads (${percentage_filt_retained}% retained from filtration)" > $progress_file
echo "2,Searching for Chimeras in ${seq_count_raw} reads (${percentage_filt_retained}% retained from filtration)" >> ${log}
#eval "$(conda shell.bash hook)"
#conda activate "${qiime}"  || { echo "${er}ERROR:${in} Please ensure config.sh contains correct environment names${r} "; exit 1; }

# Manifest
#echo -e "sample-id,absolute-filepath,direction" > manifest.csv
#echo -e "${id},${cd}/${id}${bb_f}/${id}_${phred}_Phred.fastq,forward" >> manifest.csv

# Import
#qiime tools import \
#  --type 'SampleData[SequencesWithQuality]' \
#  --input-path "manifest.csv" \
#  --output-path ".${bb_f}/${id}_${phred}_Phred.qza" \
#  --input-format SingleEndFastqManifestPhred33 \
#  >> ${log} 2>&1

# Dereplicate for computation simplicity
#qiime vsearch dereplicate-sequences \
#  --i-sequences ".${bb_f}/${id}_${phred}_Phred.qza" \
#  --o-dereplicated-table ".${bb_out}/table-derep.qza" \
#  --o-dereplicated-sequences ".${bb_out}/rep-seqs-derep.qza" \
#  >> ${log} 2>&1

# Chimera removal
#qiime vsearch uchime-ref \
#  --i-sequences ".${bb_out}/rep-seqs-derep.qza" \
#  --i-table ".${bb_out}/table-derep.qza" \
#  --i-reference-sequences "${default_classifier}" \
#  --o-chimeras ".${bb_out}/chimeras.qza" \
#  --o-nonchimeras ".${bb}/nonchimeras.qza" \
#  --o-stats ".${bb_out}/uchime-stats.qza" \
#  --quiet \
#  --p-threads ${cores} \
#  >> ${log} 2>&1

# Export non chimeric structures
#qiime tools export \
#  --input-path ".${bb}/nonchimeras.qza" \
#  --output-path ".${bb}/${id}_nonchimeric" \
#  >> ${log} 2>&1
#conda deactivate

# Filter raw data
#mv ".${bb}/${id}_nonchimeric/dna-sequences.fasta" ".${bb}/${id}_nonchimeric.fasta"
#rm -r ".${bb}/M2_nonchimeric"
#eval "$(conda shell.bash hook)"
#conda activate "${biopy}"  || { echo "${er}ERROR:${in} Please ensure config.sh contains correct environment names${r} "; exit 1; }
#seqtk seq -F I ".${bb}/${id}_nonchimeric.fasta" > ".${bb}/${id}_nonchimeric.fastq" 2>> "${log}"
#conda deactivate
seq_count_nonchimeric=$(grep -c '^@' ".${bb}/${id}_nonchimeric.fastq")

echo "3,Isolating ${seq_count_nonchimeric} (partially dereplicated count) non-chimeric amplicons" > $progress_file
echo "3,Isolating ${seq_count_nonchimeric} (partially dereplicated count) non-chimeric amplicons" >> ${log}
# Minimap mapping non chimeric reads agianst filtered reads
#minimap2 -ax map-ont -t "${cores}" ".${bb}/${id}_nonchimeric.fastq" ".${bb_f}/${id}_${phred}_Phred.fastq" > ".${bb}/${id}_mapped.sam" 2>> "${log}"
# Extract non chimeric strcutures (This approach allows chimera detection before binning for optimal results, but without loss of abundance data through binning of depricated data)
#samtools view -@ "${cores}" -bS ".${bb}/${id}_mapped.sam" | samtools sort -@ "${cores}" -m "${memory_per_core}G" -o ".${bb}/${id}_mapped_sorted.bam"  2>> "${log}"
#samtools view -@ "${cores}" -b -F 4 ".${bb}/${id}_mapped_sorted.bam" | samtools fastq -@ "${cores}" > ".${bb}/${id}_filtered.fastq" 2>> "${log}"
# Count and present as fraction
seq_count_filtered=$(grep -c '^@' ".${bb}/${id}_filtered.fastq")
percentage_retained=$(echo "scale=2; $seq_count_filtered / $input_count * 100" | bc)





######		 Binning and error correction		######
echo "4,Binning ${seq_count_filtered} and error correcting reads using ${default_database_name} ${default_database_version} (${percentage_retained}% retained from QC)" > $progress_file
echo "4,Binning ${seq_count_filtered} and error correcting reads using ${default_database_name} ${default_database_version} (${percentage_retained}% retained from QC)" >> ${log}
eval "$(conda shell.bash hook)"
conda activate "${medaka}" || { echo "${er}ERROR:${in} Please ensure config.sh contains correct environment names${r} "; exit 1; }

# Medaka Iteration 1
medaka_consensus -i ".${bb}/${id}_filtered.fastq" -d "${default_16s_database}" -o ".${bb_p}/${id}_16s_medaka_1" -m "${medaka_model}" >> ${log} 2>&1
medaka_consensus -i ".${bb}/${id}_filtered.fastq" -d "${default_18s_database}" -o ".${bb_p}/${id}_18s_medaka_1" -m "${medaka_model}" >> ${log} 2>&1

# Medaka Iteration 2 
medaka_consensus -i ".${bb_p}/${id}_16s_medaka_1/consensus.fasta" -d "${default_16s_database}" -o ".${bb_p}/${id}_16s_medaka_2" -m "${medaka_model}" >> ${log} 2>&1
medaka_consensus -i ".${bb_p}/${id}_18s_medaka_1/consensus.fasta" -d "${default_18s_database}" -o ".${bb_p}/${id}_18s_medaka_2" -m "${medaka_model}" >> ${log} 2>&1

# Medaka Iteration 3
medaka_consensus -i ".${bb_p}/${id}_16s_medaka_2/consensus.fasta" -d "${default_16s_database}" -o ".${bb_p}/${id}_16s_medaka_3" -m "${medaka_model}" >> ${log} 2>&1
medaka_consensus -i ".${bb_p}/${id}_18s_medaka_2/consensus.fasta" -d "${default_18s_database}" -o ".${bb_p}/${id}_18s_medaka_3" -m "${medaka_model}" >> ${log} 2>&1

conda deactivate

# QC
seq_count_medaka_16s=$(grep -c '^>' ".${bb_p}/${id}_16s_medaka_3/consensus.fasta")
seq_count_medaka_18s=$(grep -c '^>' ".${bb_p}/${id}_18s_medaka_3/consensus.fasta")
percentage_retained_16s_medaka=$(echo "scale=4; $seq_count_medaka_16s / $seq_count_filtered * 100" | bc)
percentage_retained_18s_medaka=$(echo "scale=4; $seq_count_medaka_18s / $seq_count_filtered * 100" | bc)


# Racon Iteration 1
echo "5,Medaka reduced amplicon varients by ${percentage_retained_16s_medaka}% (16s) and ${percentage_retained_18s_medaka}% (18s)" > $progress_file
echo "5,Medaka reduced amplicon varients by ${percentage_retained_16s_medaka}% (16s) and ${percentage_retained_18s_medaka}% (18s)" >> ${log}
eval "$(conda shell.bash hook)"
conda activate "${biopy}" || { echo "${er}ERROR:${in} Please ensure config.sh contains correct environment names${r} "; exit 1; }

# 16s
minimap2 -x ava-ont -k 15 -w 10 -t ${cores} ".${bb_p}/${id}_16s_medaka_3/consensus.fasta" ".${bb_p}/${id}_16s_medaka_3/consensus.fasta" > ".${bb_p}/16s_overlaps.paf" 2>> ${log}
racon -t ${cores} -m 3 -x -5 -g -3 -w 200 ".${bb_p}/${id}_16s_medaka_3/consensus.fasta" ".${bb_p}/16s_overlaps.paf" ".${bb_p}/${id}_16s_medaka_3/consensus.fasta" > ".${bb_p}/${id}_16s_racon_1.fasta" 2>> ${log}

# 18s
minimap2 -x ava-ont -k 15 -w 10 -t ${cores} ".${bb_p}/${id}_18s_medaka_3/consensus.fasta" ".${bb_p}/${id}_18s_medaka_3/consensus.fasta" > ".${bb_p}/18s_overlaps.paf" 2>> ${log}
racon -t ${cores} -m 3 -x -5 -g -3 -w 200 ".${bb_p}/${id}_18s_medaka_3/consensus.fasta" ".${bb_p}/18s_overlaps.paf" ".${bb_p}/${id}_18s_medaka_3/consensus.fasta" > ".${bb_p}/${id}_18s_racon_1.fasta" 2>> ${log}

# QC
seq_count_racon_16s=$(grep -c '^>' ".${bb_p}/${id}_16s_racon_1.fasta")
seq_count_racon_18s=$(grep -c '^>' ".${bb_p}/${id}_18s_racon_1.fasta")
percentage_retained_16s_racon=$(echo "scale=2; $seq_count_racon_16s / $seq_count_filtered * 100" | bc)
percentage_retained_18s_racon=$(echo "scale=2; $seq_count_racon_18s / $seq_count_filtered * 100" | bc)

echo "6,Error correction reduced varients by ${percentage_retained_16s_racon}% (18s) and ${percentage_retained_18s_racon}% (18s)" > $progress_file
echo "6,Error correction reduced varients by ${percentage_retained_16s_racon}% (18s) and ${percentage_retained_18s_racon}% (18s)" >> ${log}

conda deactivate

mv ".${bb_p}/${id}_16s_racon_1.fasta" ".${input_p}/${id}.fasta"
mv ".${bb_p}/${id}_18s_racon_1.fasta" ".${input_e}/${id}.fasta"
seq_count_CON_16s=$(grep -c '^>' ".${bb_p}/${id}_16s_racon_1.fasta")
seq_count_CON_18s=$(grep -c '^>' ".${bb_p}/${id}_18s_racon_1.fasta")

echo "7,Importing ${seq_count_CON_18s} 18s and ${seq_count_CON_16s} 16s high quality varients (amplicons) to QIIME2" > $progress_file
echo "7,Importing ${seq_count_CON_18s} 18s and ${seq_count_CON_16s} 16s high quality varients (amplicons) to QIIME2" >> ${log}










######		Classification and abundance extraction		######
eval "$(conda shell.bash hook)"
conda activate "${qiime}"  || { echo "${er}ERROR:${in} Please ensure config.sh contains correct environment names${r} "; exit 1; }

## RAW
# Import
echo -e "sample-id\tabsolute-filepath" > manifest.tsv
echo -e "${id}\t${cd}/${id}${bb}/${id}_filtered.fastq" >> manifest.tsv

qiime tools import \
  --type 'SampleData[SequencesWithQuality]' \
  --input-path ./manifest.tsv \
  --output-path ."${output_s}/RAW_qiime2_input.qza" \
  --input-format SingleEndFastqManifestPhred33V2 \
  >> ${log} 2>&1 || { sleep 5; echo "###failed here: RAW data importing to qiime###" >> "${log}"; exit 1; }

# RAW data Dereplication
qiime vsearch dereplicate-sequences \
  --i-sequences ."${output_s}/RAW_qiime2_input.qza" \
  --o-dereplicated-table ".${output_s}/RAW_table-derep.qza" \
  --o-dereplicated-sequences ".${output_s}/RAW_rep-seqs-derep.qza" \
  >> ${log} 2>&1 || { sleep 5; echo "###failed here: RAW data dereplication###" >> "${log}"; exit 1; }



## 16S
echo "8,Identifying 16s amplicon varients amongst ${seq_count_16s_CON} amplicons" > $progress_file
echo "8,Identifying 16s amplicon varients amongst ${seq_count_16s_CON} amplicons" >> ${log}

# Import 16s CON
qiime tools import \
  --type 'FeatureData[Sequence]' \
  --input-path ".${input_p}/${id}.fasta" \
  --output-path ".${output_p}/CON_qiime2_input.qza"
  >> ${log} 2>&1 || { sleep 5; echo "###failed here: consensus data 16s import###" >> "${log}"; exit 1; }

# Run CON taxonomic classification for SILVA
qiime feature-classifier classify-sklearn \
  --i-classifier "${default_16s_classifier}" \
  --i-reads ".${output_p}/CON_qiime2_input.qza" \
  --o-classification ".${output_p}/CON_taxonomy.qza" \
  --p-n-jobs ${Q_cores} \
  >> ${log} 2>&1 || { sleep 5; echo "###failed here: 16s taxonomic classification QIIME2###" >> "${log}"; exit 1; }

# Match RAW abundances with CON reads
qiime vsearch cluster-features-closed-reference \
  --i-table ".${output_s}/RAW_table-derep.qza" \
  --i-sequences ".${output_s}/RAW_rep-seqs-derep.qza" \
  --i-reference-sequences ".${output_p}/CON_qiime2_input.qza" \
  --p-perc-identity "${nano_erro_rate}" \
  --o-clustered-table ".${output_p}/table.qza" \
  --o-unmatched-sequences ".${output_p}/unmatched_sequences.qza" \
  --p-threads ${cores} \
  >> ${log} 2>&1 || { sleep 5; echo "###failed here: matching RAW abundances with CON reads###" >> "${log}"; exit 1; }

# Run taxa collapse
qiime taxa collapse \
  --i-table ".${output_p}/table.qza" \
  --i-taxonomy ".${output_p}/taxonomy.qza" \
  --p-level 7 \
  --o-collapsed-table ".${output_p}/table_collapsed.qza" \
  >> ${log} 2>&1 || { sleep 5; echo "###failed here: collapse taxa QIIME2###" >> "${log}"; exit 1; }

# Barplot
qiime taxa barplot \
  --i-table ".${output_p}/table_collapsed.qza" \
  --i-taxonomy ".${output_p}/taxonomy.qza" \
  --m-metadata-file ./manifest.tsv \
  --o-visualization .${output_p}/${id}_taxa_barplot.qzv \
  >> ${log} 2>&1 || { sleep 5; echo "###failed here: barplot creation QIIME2###" >> "${log}"; exit 1; }

firefox ${cd}/${id}${output_p}/${id}_taxa_barplot.qzv
conda deactivate


echo "9,Identifying 18s amplicon varients amongst ${seq_count_18s_CON} amplicons" > $progress_file
echo "9,Identifying 18s amplicon varients amongst ${seq_count_18s_CON} amplicons" >> ${log}
eval "$(conda shell.bash hook)"
conda activate "${qiime}"  || { echo "${er}ERROR:${in} Please ensure config.sh contains correct environment names${r} "; exit 1; }

# Import 18s CON
qiime tools import \
  --type 'FeatureData[Sequence]' \
  --input-path ".${input_e}/${id}.fasta" \
  --output-path ".${output_e}/CON_qiime2_input.qza"
  >> ${log} 2>&1 || { sleep 5; echo "###failed here: consensus data 18s import###" >> "${log}"; exit 1; }

# Run CON taxonomic classification for SILVA
qiime feature-classifier classify-sklearn \
  --i-classifier "${default_18s_classifier}" \
  --i-reads ".${output_e}/CON_qiime2_input.qza" \
  --o-classification ".${output_e}/CON_taxonomy.qza" \
  --p-n-jobs ${Q_cores} \
  >> ${log} 2>&1 || { sleep 5; echo "###failed here: 18s taxonomic classification QIIME2###" >> "${log}"; exit 1; }

# Match RAW abundances with CON reads
qiime vsearch cluster-features-closed-reference \
  --i-table ".${output_s}/RAW_table-derep.qza" \
  --i-sequences ".${output_s}/RAW_rep-seqs-derep.qza" \
  --i-reference-sequences ".${output_e}/CON_qiime2_input.qza" \
  --p-perc-identity "${nano_erro_rate}" \
  --o-clustered-table ".${output_e}/table.qza" \
  --o-unmatched-sequences ".${output_e}/unmatched_sequences.qza" \
  --p-threads ${cores} \
  >> ${log} 2>&1 || { sleep 5; echo "###failed here: matching RAW abundances with 18s CON reads###" >> "${log}"; exit 1; }

# Run taxa collapse
qiime taxa collapse \
  --i-table ".${output_e}/table.qza" \
  --i-taxonomy ".${output_e}/taxonomy.qza" \
  --p-level 7 \
  --o-collapsed-table ".${output_e}/table_collapsed.qza" \
  >> ${log} 2>&1 || { sleep 5; echo "###failed here: collapse taxa QIIME2###" >> "${log}"; exit 1; }

# Barplot
qiime taxa barplot \
  --i-table ".${output_e}/table_collapsed.qza" \
  --i-taxonomy ".${output_e}/taxonomy.qza" \
  --m-metadata-file ./manifest.tsv \
  --o-visualization .${output_e}/${id}_taxa_barplot.qzv \
  >> ${log} 2>&1 || { sleep 5; echo "###failed here: barplot creation QIIME2###" >> "${log}"; exit 1; }

firefox ${cd}/${id}${output_e}/${id}_taxa_barplot.qzv
conda deactivate






######		Normalisation, bias correction and merge		#######
echo "10,Exporting and preparing 16S QIIME2 ouputs" > $progress_file 
echo "10,Exporting and preparing 16S QIIME2 ouputs" >> ${log}
# Setup
mkdir -p ./merge/bin
m_o="${cd}/${id}/merge/bin/"
m_c="${cd}/${id}/merge/" 
ab_R_16s="${m_o}16s_table.tsv"
ab_R_18s="${m_o}18s_table.tsv"
ab_16s="${m_o}16s_table_corrected.tsv"
ab_18s="${m_o}18s_table_corrected.tsv"
tx_16s="${m_o}16s_taxonomy.tsv"
tx_18s="${m_o}18s_taxonomy.tsv"
ab_n_16s="${m_o}16s_table_corrected_NORM.tsv"
ab_n_18s="${m_o}18s_table_corrected_NORM.tsv"
microbiome_16s="${m_c}16s_microbiome.tsv"
microbiome_18s="${m_c}18s_microbiome.tsv"

## Export data
# 16s
eval "$(conda shell.bash hook)"
conda activate "${qiime}"  || { echo "${er}ERROR:${in} Please ensure config.sh contains correct environment names${r} "; exit 1; }

qiime tools export --input-path "${cd}/${id}${output_p}/table.qza" --output-path "${m_o}" >> ${log} 2>&1 || { sleep 5; echo "###failed here: import 16s table data QIIME2###" >> "${log}"; exit 1; }
biom convert -i "${m_o}feature-table.biom" -o "${m_o}16s_table.tsv" --to-tsv >> ${log} 2>&1 || { sleep 5; echo "###failed here: 16s biome convert###" >> "${log}"; exit 1; }

cp "${cd}/${id}${output_p}/taxonomy.qza" "${m_o}16s_taxonomy.qza" >> ${log} 2>&1 || { sleep 5; echo "###failed here: biome convert for 16s taxonomy###" >> "${log}"; exit 1; }
qiime tools export --input-path "${m_o}16s_taxonomy.qza" --output-path "${m_o}" >> ${log} 2>&1 || { sleep 5; echo "###failed here: import data QIIME2 for 16s taxonomy###" >> "${log}"; exit 1; }
mv "${m_o}taxonomy.tsv" "${m_o}16s_taxonomy.tsv"

conda deactivate
echo "11,Exporting and preparing 18S QIIME2 ouputs" > $progress_file
echo "11,Exporting and preparing 18S QIIME2 ouputs" >> ${log}

# 18s
eval "$(conda shell.bash hook)"
conda activate "${qiime}" 

qiime tools export --input-path "${cd}/${id}${output_e}/table.qza" --output-path "${m_o}" >> ${log} 2>&1 || { sleep 5; echo "###failed here: export data QIIME2###" >> "${log}"; exit 1; }
biom convert -i "${m_o}feature-table.biom" -o "${m_o}18s_table.tsv" --to-tsv >> ${log} 2>&1 || { sleep 5; echo "###failed here: biom convert###" >> "${log}"; exit 1; }

cp "${cd}/${id}${output_e}/taxonomy.qza" "${m_o}18s_taxonomy.qza"
qiime tools export --input-path "${m_o}18s_taxonomy.qza" --output-path "${m_o}" >> ${log} 2>&1 || { sleep 5; echo "###failed here: export data QIIME2###" >> "${log}"; exit 1; }
mv "${m_o}taxonomy.tsv" "${m_o}18s_taxonomy.tsv"

conda deactivate



## Bias correction and TSV reformatting for consistency
echo "12,Normalising, scaling and merging data" > $progress_file
echo "12,Normalising, scaling and merging data" >> ${log}
eval "$(conda shell.bash hook)"
conda activate "$python"
# error correct ab_18s
awk -v id="abundance" 'BEGIN{FS=OFS="\t"; print "#OTUID", id; found=0} {if (!found && $2 ~ /^[0-9]+(\.[0-9]+)?$/) found=1; if(found) print $0}' "$ab_R_18s" > "${ab_18s}"

# Pass to python
output_stat_file="${m_o}test_bias_correction_stats.txt"
python ${bias_correction} "${ab_18s}" "$bias_factor" "${output_stat_file}"

# Calculate success
percentage_retained=$(cat "${m_o}test_bias_correction_stats.txt")
echo "18s reads/abundances retained from bias correction: $percentage_retained"
rm "${m_o}test_bias_correction_stats.txt"

# Reformat 16s data
awk -v id="abundance" 'BEGIN{FS=OFS="\t"; print "#OTUID", id}{if($2 ~ /^[0-9]+(\.[0-9]+)?$/ && !found){found=1; print $0} else if(found)print $0}' "$ab_R_16s" > "$ab_16s"

# QC 
count_row_ab_R_18s=$(awk -F'\t' 'NR > 1 && $2 != "" {print}' "$ab_R_18s" | wc -l)
count_row_ab_R_16s=$(awk -F'\t' 'NR > 1 && $2 != "" {print}' "$ab_R_16s" | wc -l)
count_row_ab_18s=$(awk -F'\t' 'NR > 1 && $2 != "" {print}' "$ab_18s" | wc -l)
count_row_ab_16s=$(awk -F'\t' 'NR > 1 && $2 != "" {print}' "$ab_16s" | wc -l)
percentage_discrepancy_18s=$(echo "scale=5; (($count_row_ab_R_18s - $count_row_ab_18s) - 1)" | bc)
percentage_discrepancy_16s=$(echo "scale=5; (($count_row_ab_R_16s - $count_row_ab_16s) - 1)" | bc)

echo "Read discrepancy? 16s = $percentage_discrepancy_16s 18s = $percentage_discrepancy_18s" >> ${log}


## Normalisation
IFS=',' read total_reads_prok total_reads_euk <<< $(python $abundance_sum "$ab_16s" "$ab_18s")
echo "Normalisation will use $total_reads_prok 16s and $total_reads_euk 18s" >> ${log}

# Process the 18s file
awk -v total_reads="$total_reads_euk" -v norm_factor="$norm_factor" -F'\t' 'BEGIN{OFS="\t"} NR > 1 && $2 != "" {$2 = ($2 / total_reads) * norm_factor; print} NR == 1 {print}' "${ab_18s}" > "${ab_n_18s}"
# Process the 16s file
awk -v total_reads="$total_reads_prok" -v norm_factor="$norm_factor" -F'\t' 'BEGIN{OFS="\t"} NR > 1 && $2 != "" {$2 = ($2 / total_reads) * norm_factor; print} NR == 1 {print}' "${ab_16s}" > "${ab_n_16s}"

IFS=',' read total_reads_prok_n total_reads_euk_n <<< $(python $abundance_sum "$ab_n_16s" "$ab_n_18s")
echo "Normalisation produced $total_reads_prok_n 16s and $total_reads_euk_n 18s" >> ${log}

# Quality control
percentage_abundance_change_raw=$(echo "scale=5; ($total_reads_prok / $total_reads_euk)" | bc)
percentage_abundance_change_norm=$(echo "scale=5; ($total_reads_prok_n / $total_reads_euk_n)" | bc)

total_rows_n_16s=$(awk -F'\t' '$2 ~ /^[0-9]+(\.[0-9]+)?$/ {count++} END{print count+0}' "${ab_n_16s}")
total_rows_16s=$(awk -F'\t' '$2 ~ /^[0-9]+(\.[0-9]+)?$/ {count++} END{print count+0}' "${ab_16s}")
total_rows_n_18s=$(awk -F'\t' '$2 ~ /^[0-9]+(\.[0-9]+)?$/ {count++} END{print count+0}' "${ab_n_18s}")
total_rows_18s=$(awk -F'\t' '$2 ~ /^[0-9]+(\.[0-9]+)?$/ {count++} END{print count+0}' "${ab_18s}")

percentage_otu_change_16s=$(echo "scale=5; -100 * (($total_rows_16s - 1) - $total_rows_n_16s)" | bc)
percentage_otu_change_18s=$(echo "scale=5; -100 * (($total_rows_18s - 1) - $total_rows_n_18s)" | bc)

echo "Are abundances preserved? raw:normalised = ${percentage_abundance_change_raw}:${percentage_abundance_change_norm} (minor discrepencies may be caused by differeing distrobution of aundances) | Are number of OTU preserved? 16s = ${percentage_otu_change_16s}% 18s = ${percentage_otu_change_18s}% (+/- 0.1% due to Floating-point arithmetic)" >> ${log}



## Merge metadata
# Unite abundance and taxa
python $merge_taxonomy_abundance "$ab_n_16s" "$tx_16s" "$microbiome_16s"
python $merge_taxonomy_abundance "$ab_n_18s" "$tx_18s" "$microbiome_18s"

python $trim_otu "$microbiome_16s" "${m_c}16s_microbiome.tsv" # Remove OTU comuln
python $trim_otu "$microbiome_18s" "${m_c}18s_microbiome.tsv" # Remove OTU comuln

# Merge tables
cp "${m_c}16s_microbiome.tsv" "${m_c}${id}_microbiome.tsv" # Copy 16s data over with headers
tail -n +2 "${m_c}18s_microbiome.tsv" >> "${m_c}${id}_microbiome.tsv" # Copy 18s data over without headers

# QC
IFS=',' read ab_16s rows_16s <<< $(python $qc_microbiome "${m_c}16s_microbiome.tsv")
IFS=',' read ab_18s rows_18s <<< $(python $qc_microbiome "${m_c}18s_microbiome.tsv")
IFS=',' read ab_merged rows_merged <<< $(python $qc_microbiome "${m_c}${id}_microbiome.tsv")

# Calculate the expected totals by adding 16s and 18s using bc for floating-point arithmetic
expected_ab=$(echo "$ab_16s + $ab_18s" | bc)
expected_rows=$(echo "$rows_16s + $rows_18s" | bc)

# Calculate differences using bc for floating-point arithmetic
diff_ab=$(echo "$expected_ab - $ab_merged" | bc)
diff_rows=$(echo "$expected_rows - $rows_merged" | bc)

# Display the results
echo "Expected Total Abundance (16s+18s): $expected_ab" >> ${log}
echo "Actual Total Abundance (Merged): $ab_merged" >> ${log}
echo "Difference in Abundance: $diff_ab" >> ${log}

echo "Expected Total Rows (16s+18s): $expected_rows" >> ${log}
echo "Actual Total Rows (Merged): $rows_merged" >> ${log}
echo "Difference in Rows: $diff_rows" >> ${log}

conda deactivate

echo "13,Done: see ${cd}/${id}/microbiome_${id}.tsv" > $progress_file 
echo "13,Done: see ${cd}/${id}/microbiome_${id}.tsv" >> ${log}
sleep 2

# Make sure to wait for the Python script to finish before removing the progress file and exiting
wait $PYTHON_PID
rm -f $progress_file






