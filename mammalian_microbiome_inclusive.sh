#!/bin/bash
# This filtration approach: includes only organisoms which are known microbiome members (mammalian microbiome), as opposed to filtering out unknown (inclusive).

input=$1
prefix=$2
out_dir=$3

# Create the output file if it doesn't exist
echo > "${out_dir}16s_${prefix}.fasta"
echo > "${out_dir}18s_${prefix}.fasta"
 
# Remove reads likely to be in microbiome
# 16S filter
awk -v out_dir="${out_dir}" -v prefix="${prefix}" '
/^>/ {
    printit = 0
    if ($0 ~ / Bacteria;/ || $0 ~ / Archaea;/) {
        if ($0 ~ /;Bacillota;/ || $0 ~ /;Bacteroidetes;/ || $0 ~ /;Actinobacteria;/ ||
            $0 ~ /;Pseudomonadota;/ || $0 ~ /;Verrucomicrobia;/ || $0 ~ /;Halobacteriota;/ ||
            $0 ~ /;Spirochaetota;/ || $0 ~ /;Cyanobacteriota;/ || $0 ~ /;Nanoarchaeota;/ ||
            $0 ~ /;Thaumarchaeota;/ || $0 ~ /;Methanobacteriota;/ || $0 ~ /;Fusobacteriota;/ ||
            $0 ~ /;Thermoplasmatota;/ || $0 ~ /;Sulfolobaceae;/ || $0 ~ /;Planctomycetota;/ ||
            $0 ~ /;Chlamydiota;/ || $0 ~ /;Deinococcota;/ || $0 ~ /;Acidobacteriota;/) {
            printit = 1
        }
    }
}
{
    if (printit) {
        print > out_dir "16s_expanded_" prefix ".fasta"
    }
}
' "${input}"

# 18S filter
awk -v out_dir="${out_dir}" -v prefix="${prefix}" '
/^>/ {
    printit = 0
    if ($0 ~ / Eukaryota;/) {
        if ($0 ~ /;Ascomycota;/ || $0 ~ /;Basidiomycota;/ || $0 ~ /;Stramenopiles;/ ||
            $0 ~ /;Chytridiomycota;/ || $0 ~ /;Mucoromycota;/ || $0 ~ /;Amoebozoa;/ ||
            $0 ~ /;Apicomplexa;/ || $0 ~ /;Blastocladiomycota;/ || $0 ~ /;Ciliophora;/ || $0 ~ /;Excavata;/) {
            printit = 1
        }
    }
}
{
    if (printit) {
        print > out_dir "18s_expanded_" prefix ".fasta"
    }
}
' "${input}"

# 16S
awk -v out_dir="${out_dir}" -v prefix="${prefix}" '
BEGIN { FS=";" }
{
    if ($1 ~ /^>/) {
        # Split the taxonomic path into levels
        n = split($0, levels, ";")
        
        # Get the last segment
        last_segment = levels[n]
        
        # Remove leading/trailing whitespace from last_segment
        gsub(/^ +| +$/, "", last_segment)
        
        # Count the number of words in the last segment, treating hyphenated words as one
        word_count = split(last_segment, words, /[- ]/)
        
        # If there are more than two words, truncate to the first two
        if (word_count > 2) {
            last_segment = words[1] " " words[2]
            levels[n] = last_segment
        }
        
        # Reconstruct the line with modified last segment
        modified_line = levels[1]
        for (i = 2; i <= n; i++) {
            modified_line = modified_line ";" levels[i]
        }
        
        # Output the modified header line
        print modified_line > out_dir "16s_" prefix ".fasta"
    } else {
        # Print the sequence lines as they are
        print > out_dir "16s_" prefix ".fasta"
    }
}
' "${out_dir}16s_expanded_${prefix}.fasta"

# 18S
awk -v out_dir="${out_dir}" -v prefix="${prefix}" '
BEGIN { FS=";" }
{
    if ($1 ~ /^>/) {
        # Split the taxonomic path into levels
        n = split($0, levels, ";")
        
        # Get the last segment
        last_segment = levels[n]
        
        # Remove leading/trailing whitespace from last_segment
        gsub(/^ +| +$/, "", last_segment)
        
        # Count the number of words in the last segment, treating hyphenated words as one
        word_count = split(last_segment, words, /[- ]/)
        
        # If there are more than two words, truncate to the first two
        if (word_count > 2) {
            last_segment = words[1] " " words[2]
            levels[n] = last_segment
        }
        
        # Reconstruct the line with modified last segment
        modified_line = levels[1]
        for (i = 2; i <= n; i++) {
            modified_line = modified_line ";" levels[i]
        }
        
        # Output the modified header line
        print modified_line > out_dir "18s_" prefix ".fasta"
    } else {
        # Print the sequence lines as they are
        print > out_dir "18s_" prefix ".fasta"
    }
}
' "${out_dir}18s_expanded_${prefix}.fasta"
