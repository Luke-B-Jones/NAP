#!/bin/bash
source config.sh

# Save directory and overwrite config
echo "(${su}Step ${B}1 | 5${r}${su}:${in} Capturing directories and setting-up config{r})"
# Capture NAP directory and version
loc=$(pwd)
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
# Update config
thread_count=$(nproc)
ram_bytes=$(free -b | awk '/^Mem:/{print $2}')
update_config "w_d" "$loc"
update_config "pipeline_version" "$NAP_version"
update_config "all_cores" "$thread_count"
update_config "all_RAM" "$ram_bytes"
update_config "w_d" "$loc"
# Build file structure
echo "(${su}Step ${B}2 | 5${r}${su}:${in} Generating file structure ${r})"
mkdir -p "${loc}/bin/databases"
mkdir -p "${loc}/bin/scripts"
mkdir -p "${loc}/bin/subconfig"
mkdir -p "${loc}/bin/logs"

# Move git clone files into correct locations
mv "${loc}/*.py" "${loc}/bin/scripts"
mv "${loc}/AMP_515y-926r.sh" "${loc}/bin/subconfig"
mv "${loc}/hardware-heavy.sh" "${loc}/bin/subconfig"
mv "${loc}/hardware-light.sh" "${loc}/bin/subconfig"
mv "${loc}/hardware-super-light.sh" "${loc}/bin/subconfig"
sleep 2
mv "${loc}/*.sh" "${loc}/bin/scripts"

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