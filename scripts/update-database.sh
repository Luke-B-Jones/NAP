#!/bin/bash

source config.sh


# Easy edit!
input="SILVA_138.1_NR99" # Raw database name
prefix="_SILVA_138.1_NR99" # Prefix carried into other documents (update the config accordingly)
file_type=".fasta"
pass="100.00000" # The % of reads retained in split databases (change at own risk - only for when unable to fix error)


## Scripts
# GO!
#echo "${in}This script is currently formatted to function with ${er}${default_database_name} ${default_database_version}${in}; therefore headers are ' NAME;' for Bacteria, Archaea, and Eukaryota${r}"

# Correcting sequence extraction and counting
#awk '/^>/ {printit = ($0 ~ / Bacteria;/ || $0 ~ / Archaea;/)} {if(printit) print}' "${input}${file_type}" > "16s${prefix}${file_type}"
#awk '/^>/ {printit = ($0 ~ / Eukaryota;/)} {if(printit) print}' "${input}${file_type}" > "18s${prefix}${file_type}"


## Verification of Success
# Correcting count commands
prok_count=$(grep -c '>' "16s${prefix}${file_type}")
euk_count=$(grep -c '>' "18s${prefix}${file_type}")
total_count=$((prok_count + euk_count))
input_count=$(grep -c '>' "${input}${file_type}")

# Calculate the percentage
percentage_kept=$(echo "scale=5; $total_count*100 / $input_count" | bc -l)


# Display the result
is_full=$(echo "${percentage_kept} == ${pass}" | bc)
if [ "$is_full" -eq 1 ]; then
  echo -e "${su}${percentage_kept}% of reads retained${in} (${total_count} of ${input_count})${r}"
  eval "$(conda shell.bash hook)"
  conda activate $qiime
  # Import data
  #qiime tools import --type 'FeatureData[Sequence]' --input-path "16s${prefix}${file_type}" --output-path "16s_ref-seq${prefix}.qza"
  #qiime tools import --type 'FeatureData[Sequence]' --input-path "18s${prefix}${file_type}" --output-path "18s_ref-seq${prefix}.qza"

  # Generate the taxonomy.tsv
  #awk '/^>/ {print substr($1,2) "\t" substr($0, index($0,$2))}' "16s${prefix}${file_type}" > "16s_taxonomy${prefix}.tsv"
  #awk '/^>/ {print substr($1,2) "\t" substr($0, index($0,$2))}' "18s${prefix}${file_type}" > "18s_taxonomy${prefix}.tsv"
  
  # Counting lines in the taxonomy files
  tax_count_16s=$(wc -l < "16s_taxonomy${prefix}.tsv")
  tax_count_18s=$(wc -l < "18s_taxonomy${prefix}.tsv")

  # Calculating unaccounted reads
  # Assuming prok_count and euk_count are the total reads identified for 16s and 18s respectively
  unaccounted_16s=$((prok_count - tax_count_16s))
  unaccounted_18s=$((euk_count - tax_count_18s))

  if [ "$unaccounted_16s" -eq 0 ] && [ "$unaccounted_18s" -eq 0 ]; then
    # Displaying the results
    echo "${su}16s reads unaccounted for: ${unaccounted_16s}${r}"
    echo "${su}18s reads unaccounted for: ${unaccounted_18s}${r}"
  elif [ "$unaccounted_16s" -ne 0 ] || [ "$unaccounted_18s" -ne 0 ]; then
    echo "${er}16s reads unaccounted for: ${unaccounted_16s}${r}"
    echo "${er}18s reads unaccounted for: ${unaccounted_18s}${r}"
    exit 0
  fi
  # Import taxa
  #qiime tools import --type 'FeatureData[Taxonomy]' --input-format HeaderlessTSVTaxonomyFormat --input-path "16s_taxonomy${prefix}.tsv" --output-path "16s_ref-taxonomy${prefix}.qza"
  #qiime tools import --type 'FeatureData[Taxonomy]' --input-format HeaderlessTSVTaxonomyFormat --input-path "18s_taxonomy${prefix}.tsv" --output-path "18s_ref-taxonomy${prefix}.qza"


  # Train classifier
  #qiime feature-classifier fit-classifier-naive-bayes --i-reference-reads "18s_ref-seq${prefix}.qza" --i-reference-taxonomy "18s_ref-taxonomy${prefix}.qza" --o-classifier "18s${prefix}.qza"
  qiime feature-classifier fit-classifier-naive-bayes --i-reference-reads "16s_ref-seq${prefix}.qza" --i-reference-taxonomy "16s_ref-taxonomy${prefix}.qza" --o-classifier "16s${prefix}.qza"

  conda deactivate

  # Check if 16s and 18s .qza files exist
  if [ -f "16s${prefix}.qza" ] && [ -f "18s${prefix}.qza" ]; then
    echo -e "${su}QIIME classifiers generated successfully -> please edit the config.sh 'defualt_database'..etc...${r}"
    mousepad "${w_d}/config.sh" &
    # Continue with further processing or exit if this is the end of the script
  else
    echo -e "${er}ERROR${in}: QIIME classifiers were not generated successfully.${r}"
    exit 0
  fi
else
  echo -e "${er}${percentage_kept}% of reads retained (${total_count} of ${input_count})${r}"
  echo -e "${er}ERROR${in}: Won't generate QIIME classifiers until ${percentage_kept} = 100.000%"
fi


