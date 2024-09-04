#!/bin/bash
# This filtration approach: Seporate silva into 16s and 18s, removing insuficcent classified and irrelvent organisms (multicellular Eukaryotes and bacterial rRNA derived from mitrocontrial DNA...etc)
source config.sh
input=$1
prefix=$2
out_dir=$3
# Rest to avoid concatination or hidden errors
echo "read_id\tfull_taxonomic_path\treduced_taxonomic_path\tscore\tretain" > "${out_dir}16s_reduced_${prefix}.tsv"
echo "read_id\tfull_taxonomic_path\treduced_taxonomic_path\tscore\tretain" > "${out_dir}18s_reduced_${prefix}.tsv"
> "${out_dir}16s_untrim_${prefix}.fasta"
> "${out_dir}18s_untrim_${prefix}.fasta"
> "${out_dir}16s_${prefix}.fasta"
> "${out_dir}16s_expanded_${prefix}.fasta"
> "${out_dir}18s_expanded_${prefix}.fasta"
> "${out_dir}16s_reduced_${prefix}.fasta"
> "${out_dir}18s_reduced_${prefix}.fasta"
> "${out_dir}18s_${prefix}.fasta"
echo "${su}${B}(1) Filtering reads into 16S and 18S bins${r}"
# 16S filter for Bacteria/Archaea, excluding "unknown" and "metagenome"
awk -v out_dir="${out_dir}" -v prefix="${prefix}" '
/^>/ {
    printit = 0
    if ($0 ~ / Bacteria;/ || $0 ~ / Archaea;/) {
        # Exclude "unknown", "metagenome", "unidentified", and "chloroplast" reads
        if ($0 !~ /unknown/ && $0 !~ /metagenome/ && $0 !~ /Chloroplast/ && $0 !~ /unidentified/ && $0 !~ /Mitochondria/) {
            printit = 1
        }
    }
}
{
    if (printit) {
        print $0 >> out_dir "16s_expanded_" prefix ".fasta"
    }
}
' "${input}"

# 18S filter for Eukaryota, excluding animals and plants
awk -v out_dir="${out_dir}" -v prefix="${prefix}" '
/^>/ {
    printit = 0
    if ($0 ~ / Eukaryota;/) {
        # Exclude animal entries and plant-related groups like Archaeplastida
        if ($0 !~ /unknown/ && $0 !~ /metagenome/ && $0 !~ /unidentified/ && $0 !~ /Chloroplast/ && $0 !~ /Embryophyta;/ && $0 !~ /Metazoa;/) {
            printit = 1
        }
    }
}
{
    if (printit) {
        print $0 >> out_dir "18s_expanded_" prefix ".fasta"
    }
}
' "${input}"

echo "${su}${B}(2) Simplifying taxanomy to species level, minimising uncultured species, and depopulating highly replciated species to remove blastn consensus bias ${r}"
# Final refinement using Python script, filter out 'uncultured' species when number of specues is >NUM_1 and proportion of culutered:total is <NUM_2
python "$remove_uncultured" "${out_dir}16s_expanded_${prefix}.fasta" "1" "0.05" "${out_dir}16s_reduced_${prefix}.fasta" 
python "$remove_uncultured" "${out_dir}18s_expanded_${prefix}.fasta" "1" "0.05" "${out_dir}18s_reduced_${prefix}.fasta"

# Remove brackets from entries
python "$bracket_cut" "${out_dir}16s_reduced_${prefix}.fasta" "${out_dir}16s_untrim_${prefix}.fasta"
python "$bracket_cut" "${out_dir}18s_reduced_${prefix}.fasta" "${out_dir}18s_untrim_${prefix}.fasta"

echo "${su}${B}(3) Trimming reads to fit 515y 926r theoretical binding sites ${r}"
# Source the current primer preset configuration
if [ -f "${subconfig}/${amplicon_pre_set}.sh" ]; then
    source "${subconfig}/${amplicon_pre_set}.sh"
else
    echo "${er}ERROR: Primer preset configuration file not found: ${subconfig}/${amplicon_pre_set}.sh, ensure the config is set correctly ${r}"
    exit 1
fi
# Extract relevant primer sequences and ranges from the sourced preset
forward_primer="$for_seq"
reverse_primer="$rev_seq"
forward_range="$for_range"
reverse_range="$rev_range"
# Make sure the variables were properly sourced
if [ -z "$forward_primer" ] || [ -z "$reverse_primer" ] || [ -z "$forward_range" ] || [ -z "$reverse_range" ]; then
    echo "${er}ERROR: One or more primer sequences/ranges are not set in ${subconfig}/${amplicon_pre_set}.sh, ensure your amplicon import is complete ${r}"
    exit 1
fi

# Trim 16S sequences
trimming_cores=$(echo "scale=0; ${all_cores} - 2" | bc)
python "${CPU_trim_script}" "${out_dir}16s_untrim_${prefix}.fasta" "${out_dir}16s_${prefix}.fasta" "${trimming_cores}" "$forward_primer" "$reverse_primer" "$forward_range" "$reverse_range"
python "${CPU_trim_script}" "${out_dir}18s_untrim_${prefix}.fasta" "${out_dir}18s_${prefix}.fasta" "${trimming_cores}" "$forward_primer" "$reverse_primer" "$forward_range" "$reverse_range"
