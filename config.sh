#!/bin/bash

# PC settings
export hardware_use="heavy"         # 'super-light' uses 20%, 'light' uses 45%, and 'heavy' will use 95% of your computational resourses
export amplicon_pre_set="515y-926r" # premade configs to change amplicon handeling 
# Defualt QC info (pipe)
export norm_factor="100000" # Normalisation factor
export max_depth="230000"   # Recommend 'true max' + 20%
# Phred scaling
export phred_1500k="34" # Phred if imput is >1.5 million reads
export phred_500k="32"  # Phred if input is >0.5 million reads
export phred_300k="30"  # Phred if input is >0.3 million reads
export phred_200k="27"  # Phred if input is >0.2 million reads
export phred_100k="25"  # Phred if input is >0.1 million reads
export phred_50k="23"   # Phred if input is >50,000 reads
export phred_fail="20"  # Phred if <50,000 reads

# Hardware
export all_cores=""
export all_RAM=""
# Databases and info
export default_database_version="138.2"
export default_database_name='SILVA'
export fasta_18s_database="/home/luke/Documents/tools/NAP/bin/databases/18s_SILVA_138.2_SSURef_NR99_tax_silva.fasta"
export fasta_16s_database="/home/luke/Documents/tools/NAP/bin/databases/16s_SILVA_138.2_SSURef_NR99_tax_silva.fasta"
export fasta_filtered_database="/home/luke/Documents/tools/NAP/bin/databases/filtered_SILVA_138.2_SSURef_NR99_tax_silva.fasta"
export blastn_16s_database="/home/luke/Documents/tools/NAP/bin/databases/16s_SILVA_138.2_SSURef_NR99_tax_silva"
export blastn_18s_database="/home/luke/Documents/tools/NAP/bin/databases/18s_SILVA_138.2_SSURef_NR99_tax_silva"
export blank_average="/home/luke/Documents/data/rat_project/BLANK/decontamination_05_11_2024-15_35_22.tsv"
export blank_active="0"
export blank_read_count=""

####### CUT OFF #######
# databases and info 2
export subconfig="${w_d}/bin/subconfigs"
# Pipeline info 2
export pipeline_name="Nanopore_amplicon_pipeline"
export pipeline_version="1.0.0-alpha"
export w_d="/home/luke/Documents/tools/NAP"
# Python
export progress_monitor="${w_d}/bin/scripts/progress_monitor.py"             # In terminal progress bar
export normalise="${w_d}/bin/scripts/normalise.py"                           # TSS normalisation
export merge_16s_18s="${w_d}/bin/scripts/merge_16s_18s.py"                   # Merge 16s and 18s tsv's
export bias_correction="${w_d}/bin/scripts/bias_correction.py"               # Correct for amplicon bias
export reduce_to_abundance="${w_d}/bin/scripts/reduce_to_abundance.py"       # Reduce blastn raw hits against con into abudnance data
export blast_consensus="${w_d}/bin/scripts/blast_consensus.py"               # CON hit consensus
export generate_con_database="${w_d}/bin/scripts/generate_con_database.py"   # Generate database from CON blastn hits (for raw data)
export remove_uncultured="${w_d}/bin/scripts/remove_uncultured.py"           # Reduce number of 'uncultured' hits in SILVA (only in highly classified genera)
export CPU_trim_script="${w_d}/bin/scripts/cpu_dynamic_trim.py"              # Trim exess from SILVA entires (reduce computation time)
export iden_high_AQ="${w_d}/bin/scripts/iden_high_AQ.py"                     # Extract high identify (uses % ident rather than AQ algorythm [more sensetive])
export duplicated_count="${w_d}/bin/scripts/count_duplicate.py"              # Counts duplicated read ids (16s/18s binning QC)
export bracket_cut="${w_d}/bin/scripts/bracket_cut.py"                       # de-brackets silva entires (standardise formatting)
export extract_nonchimeric="${w_d}/bin/scripts/extract_nonchimeric.py"       # Extract fastq non-chimeric using fasta non chimeric vsearch output
export decontaminate="${w_d}/bin/scripts/decontaminate_tsv.py"               # Remove contmaintion from microibome tsv using blank
export simplify_taxa="${w_d}/bin/scripts/simplify_taxa.py"                   # Cut kingdom-> <genus species> <- sub...
export plot_taxa="${w_d}/bin/scripts/plot_taxa.py"                           # Plot genus and species level stacked barchart
export mute="${w_d}/bin/scripts/mute_noise.py"                               # Silence low quality bases in a sequence
export setup_decontamination="${w_d}/bin/scripts/decontamination_setup.py"   # Prepaire a decontamination.tsv from blanks.tsv
export decontaminate="${w_d}/bin/scripts/decontaminate_tsv.py" 
# Text editing ASCII
export in=$'\e[37m'              # Light gray colour INPUT
export er=$'\033[0;31m'          # Red colour ERROR
export su=$'\033[0;32m'          # Green colour SUCCESS
export r=$'\033[0m'              # Reset
export B=$'\033[1m'              # bold
export or=$'\e[38;2;255;165;0m'  # Orange QUESTION
