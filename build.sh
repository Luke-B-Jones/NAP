#!/bin/bash
echo "# Setting up directorys (1 of 3)"
source config.sh
if [ ! -f config.sh ]; then
    echo "ERROR: config.sh not found!"
    exit 1
fi
# Capture NAP directory and version
loc="$1"
# Build file structure
mkdir -p "${loc}/bin/"
mv "${loc}/scripts/" "${loc}/bin/"
mv "${loc}/subconfigs/" "${loc}/bin/"
mkdir -p "${loc}/bin/databases"
mkdir -p "${loc}/bin/logs"
ln -s "${loc}/bin/scripts/nap.sh" "${loc}/nap"
#
echo "# Populating the config (2 of 3)"
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
#
# Setup database
echo "# Generating a SILVA database (3 of 3)"
cd "${loc}/bin/databases/"
wget -O SILVA_138.2_SSU_NR99.fasta.gz "https://www.arb-silva.de/fileadmin/silva_databases/release_138_2/Exports/SILVA_138.2_SSURef_NR99_tax_silva.fasta.gz" || { echo "ERROR: Failed to download SILVA database"; exit 1; }
gzip -d SILVA_138.2_SSU_NR99.fasta.gz
SILVA_prefix="SILVA_138.2_SSU_NR99"
# Create databases in manual (0)
bash "${loc}/bin/scripts/update-database.sh" "$SILVA_prefix" "0"
