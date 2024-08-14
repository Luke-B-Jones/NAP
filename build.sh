#!/bin/bash
source config.sh

# Save directory and overwrite config
echo "(${su}Step ${B}1 | 5${r}${su}:${in} Capturing directories and setting-up config{r})"
# Capture NAP directory and version
loc=$(pwd)
NAP_version=$(grep -oP '(?<=version: ")[^"]*' "meta.yaml")
# Update config via variable terminology
update_config() {
    local var_name=$1
    local new_value=$2
    if grep -q "^export ${var_name}=" "config.sh"; then
        sed -i "s|^export ${var_name}=.*|export ${var_name}=\"${new_value}\"|" "config.sh"
    else
        echo "${er}ERROR:${in} Variable $var_name could not be updated in config${r} "
    fi
}
#  Question user:
echo "${in}${B}Please answer the following questions${r}"
read -p "${su}  PC threads count:${r} " $thread_count
read -p "${su}  PC RAM (in GB):${r} " $RAM_count
echo "${su}Thank you! remember to visit config for more specific pipeline personalisation ${r}"
# Update config
update_config "w_d" "$loc"
update_config "pipeline_version" "$NAP_version"
update_config "all_cores" "$thread_count"
update_config "all_RAM" "$RAM_count"

# Build file structure
echo "(${su}Step ${B}2 | 5${r}${su}:${in} Generating file structure ${r})"
mkdir -p ${loc}/bin/databases
mkdir -p ${loc}/bin/scripts
mkdir -p ${loc}/bin/subconfigs
mkdir -p ${loc}/bin/logs

# Move git clone files into correct locations
mv "${loc}/*.py" "${loc}/bin/scripts"
mv "${loc}/nap.sh" "${loc}/bin/scripts"
mv "${loc}/update-database.sh" "${loc}/bin/scripts"
mv "${loc}/dorado.sh" "${loc}/bin/scripts"
mv "${loc}/mammalian_microbiome_inclusive.sh" "${loc}/bin/scripts"
mv "${loc}/pipe.sh" "${loc}/bin/scripts"
sleep 2
mv "${loc}/*.sh" "${loc}/bin/subconfig"

# NAP wrapper setup
ln -s "${loc}/bin/scripts/nap.sh" "${loc}/nap"
# Grant chmod +x all scripts
echo "(${su}Step ${B}3 | 5${r}${su}:${in} Modifying script permissions{r})"
chmod -R +x "${loc}/*"

# Setup database
cd "${loc}/bin/databases/"
wget -O SILVA_138.2_SSURef_NR99_tax_silva.fasta.gz "https://www.arb-silva.de/no_cache/download/archive/release_138_2/Exports/SILVA_138.2_SSURef_NR99_tax_silva.fasta.gz"
gzip -d SILVA_138.2_SSURef_NR99_tax_silva.fasta.gz
SILVA_prefix="SILVA_138.2_SSURef_NR99_tax_silva"
echo "(${su}Step ${B}4 | 5${r}${su}:${in} Generating databases${r})"
# Create databases in manual (0)
bash "${loc}/bin/scripts/update-database.sh" "$SILVA_prefix" "0"
echo "(${su}Step ${B}5 | 5${r}${su}:${in} Pipeline setup complete${r})"