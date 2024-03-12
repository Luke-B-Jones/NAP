#!/bin/bash
# Welcome to the config!

###	User? Please edit me:	###

## Essential

# Conda envs
export qiime="qiime2_amplicon_env"
export biopy="biopy38_env"
export medaka="medaka_env"
export python="python3.10"
# Where are we?
export w_d="/mnt/data/lj752/tools/Nanopore_amplicon_pipeline" # Directory where tool is stored
# Hardware
export cores="18" # Cores availible (MAX -10% recommended)
export RAM="220" # RAM (memory) in Gigabytes (GB) availible for use (MAX -10% recommended)
export Q_cores="8" # Cores availible to QIIME (MAX -10% recommended)



## Optional
greedy_gpu="true" # Would you like your GPU to be fully utalised?
# Dorado personalisation (so you can copy input from 'ns dorado' prompts)
export defualt_kit="SQK-NBD114-24"
export defualt_model="dna_r10.4.1_e8.2_400bps_hac@v4.2.0"
export medaka_model="r1041_e82_400bps_sup_v4.3.0"
export nano_erro_rate="90" # Used to match uncorrected reads (abundance information) to error corrected reads (for taxanomic classiciation); 90='allow for a 10% difference between raw and corrected data'
# Filtering by quality and chimeras
export filtered_amplicon_length="1200" # Max length accepted +200
export average_amplicon_length="700" # Average plus some reasonabe headroom for error correction
export min_length="100" # Min length accepted
export phred="25" # Average Phred desired
export phred_t="20" # Trimming of ends (recommended slighlty lower than phred above)
export v_ident="0.97" # Ident required to identify varients and ASVs
# Merging and normalising of 16s and 18s reads (what is the 18s bias of your primers - default is set for 515y 926r primers)
export bias_factor="2"
export norm_factor="100000"

# Admin options
export test_mode="true" # Sleep 2 between steps, allows steps to be skipped







###	User? Dont edit me please!	###
# Defualt tool information
export pipeline_name="Nanopore_amplicon_pipeline"
export pipeline_database_version="1 (01/24)"
export default_database_version="138.1"
export default_database_name='SILVA'

# Locations
export default_database="${w_d}/bin/databases/SILVA_138.1_NR99.fasta"
export default_classifier="${w_d}/bin/databases/SILVA_138.1_NR99.qza"
export default_16s_classifier="${w_d}/bin/databases/16s_SILVA_138.1_NR99.qza"
export default_18s_classifier="${w_d}/bin/databases/18s_SILVA_138.1_NR99.qza"
export default_18s_database="${w_d}/bin/databases/18s_SILVA_138.1_NR99.fasta"
export default_16s_database="${w_d}/bin/databases/16s_SILVA_138.1_NR99.fasta"
# Python
export progress_monitor="${w_d}/bin/scripts/progress_monitor.py"
export bias_correction="${w_d}/bias_correction.py"
export abundance_sum="${w_d}/abundance_sum.py"
export merge_taxonomy_abundance="${w_d}/merge_taxonomy_abundance.py"
export trim_otu="${w_d}/trim_otu.py"
export qc_microbiome="${w_d}/qc_microbiome.py"
# Conserved directorys
export bb="/prep"
export bb_f="/prep/filter"
export bb_out="/prep/bin"
export bb_p="/prep/polishing"
export input_p="/PROK/fasta"
export output_p="/PROK"
export input_e="/EUK/fasta"
export output_e="/EUK"
export input_m="/merged/fasta"
export output_m="/merged"
export output_s="/prep/RAW"

export in=$'\e[37m'  # Light gray colour INPUT
export er=$'\033[0;31m'  # Red colour ERROR
export su=$'\033[0;32m'  # Green colour SUCCESS
export r=$'\033[0m'      # Reset colour
export B=$'\033[1m'    # bold

# Questions
if [ "$greedy_gpu" = "true" ]; then
  export TF_FORCE_GPU_ALLOW_GROWTH=true
fi


