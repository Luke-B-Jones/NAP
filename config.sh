#!/bin/bash

# PC settings
export greedy_gpu="true" # Would you like your GPU to be fully utalised?
export hardware_use="heavy" # 'super-light' uses 20%, 'light' uses 45%, and 'heavy' will use 95% of your computational resourses
export amplicon_pre_set="515y-926r" # premade configs to change amplicon handeling
# Hardware
export all_cores="32" # All threads availible
export all_RAM="96" # All RAM (memory)
# Dorado AUTO settings
export defualt_kit="SQK-NBD114-24" # Dorado
export defualt_model="dna_r10.4.1_e8.2_400bps_sup@v5.0.0" # Dorado
export medaka_model="r1041_e82_400bps_sup_v4.3.0" # Medaka
export demux_needed="yes" # yes or no do you need demux step in dorado
# Defualt QC info (pipe)
export phred="20" # Average Phred desired
export norm_factor="100000" # Normalisation factor
# Pipeline info
export pipeline_name="Nanopore_amplicon_pipeline"
export pipeline_version="0.1"
export w_d="/home/luke/Documents/tools/nap" # Directory where tool is stored
# Databases and info
export default_database_version="138.2"
export default_database_name='SILVA'
export fasta_18s_database="/home/luke/Documents/tools/nap/bin/databases/18s_SILVA_138.2_SSU_NR99.fasta"
export fasta_16s_database="/home/luke/Documents/tools/nap/bin/databases/16s_SILVA_138.2_SSU_NR99.fasta"
export fasta_filtered_database="/home/luke/Documents/tools/nap/bin/databases/filtered_SILVA_138.2_SSU_NR99.fasta"
export blastn_16s_database="/home/luke/Documents/tools/nap/bin/databases/16s_SILVA_138.2_SSU_NR99"
export blastn_18s_database="/home/luke/Documents/tools/nap/bin/databases/18s_SILVA_138.2_SSU_NR99"
# Python
export progress_monitor="${w_d}/bin/scripts/progress_monitor.py"
export normalise="${w_d}/bin/scripts/normalise.py"
export merge_16s_18s="${w_d}/bin/scripts/merge_16s_18s.py"
export bias_correction="${w_d}/bin/scripts/bias_correction.py"
export extract_rep_seq="${w_d}/bin/scripts/extract_rep_seq.py"
export extract_high_AS="${w_d}/bin/scripts/extract_high_AS.py"
export sam_dup_count="${w_d}/bin/scripts/SAM_dup_count.py"
export reduce_class="${w_d}/bin/scripts/reduce_class.py"
export blast_consensus="${w_d}/bin/scripts/blast_consensus.py"
# Conserved directorys
export prep_f="/QC/filter"
export prep_b="/QC/bining"
export EUK="/EUK"
export PROK="/PROK"
export merge_b="/merge/bin"
export merge="/merge"
export subconfig="$w_d/bin/subconfig/"
# Text editing ASCII
export in=$'\e[37m'  # Light gray colour INPUT
export er=$'\033[0;31m'  # Red colour ERROR
export su=$'\033[0;32m'  # Green colour SUCCESS
export r=$'\033[0m'      # Reset colour
export B=$'\033[1m'      # bold


