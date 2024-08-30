#!/bin/bash

# Find directories
source config.sh
sub="${w_d}/bin/scripts"
cd=$(pwd)

# Display help regardless of bash syntax error in -help
function display_help() {
    echo "${in} Usage:${r} nap <tool> [options]...${r}
    ${in}Tools/Options:${r}
        ${B}dorado  ${r}-${in} Basecalling and demultiplexing (dorado-auto to preload config settings) ${r}
            ${B}-a ${r}-${in} Exracts kit/basecalling model from config ${r}
            ${B}-m ${r}-${in} Manually input kit/model during run ${r}
        ${B}pipe  ${r}-${in} process 16s and 18s mixed amplicon samples ${r}
        ${B}update-database  ${r}-${in} update alighment database ${r} 
        ${B}--help  |  -h  ${r}- ${in} Print help info ${r}
        ${B}--version | -v  ${r}-${in} Print pipeline version ${r}"
}
# HELP
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    display_help
    exit 0
fi
# VERSION
if [ "$1" = "--version" ] || [ "$1" = "-v" ]; then
    echo "${in}NAP - ${B}v$pipeline_version${r}"
    exit 0
fi
# DORADO
if [[ "$1" == "dorado" ]]; then
    if [[ "$2" == "-h" || "$2" == "--help" ]]; then
        echo "${er} Usage:${in} nap dorado <mode> ${r}
        (1)${in} Be in the directory containing your ./pod5/ ${r}
        (2)${in} Choose <mode>: -a (auto) or -m (manual) ${r}"
        exit 0
    fi
fi
# PIPE
if [[ "$1" == "pipe" ]]; then
    if [[ "$2" == "-h" || "$2" == "--help" ]]; then
        echo "${er} Usage:${in} nap pipe <barcode_number> <sample_name>...... ${r}
        (1)${in} Be in the same directory as your ./raw-data/ ${r}"
        exit 0
    fi
fi
# Update database
if [[ "$1" == "update-database" ]]; then
    if [[ "$2" == "-h" || "$2" == "--help" ]]; then
        echo "${er} Usage:${in} nap update-database <file_prefix> ${r}
        (1)${in} Be in the ./bin/database/ folder along with your database.fasta ${r}"
        exit 0
    fi
fi

# Parse and initate scripts
TOOL_NAME=$1
shift

# Script 'nap dorado'
if [ "$TOOL_NAME" = "dorado" ]; then
  bash "${sub}/dorado.sh"
fi
# Script 'nap dorado-hq'
if [ "$TOOL_NAME" = "dorado-auto" ]; then
  bash "${sub}/dorado-auto.sh" "$1"
fi
# Script 'nap update-database'
if [ "$TOOL_NAME" = "update-database" ]; then
  bash "${sub}/update-database.sh" "$1" "1"
fi
# Script to run 'nap pipe' for each sample given and export variable
if [ "$TOOL_NAME" = "pipe" ]; then
    # Check if there are sufficient arguments for sample processing
    if [ $# -lt 2 ]; then
        echo "${in}Format: nap pipe <01> <corresponding_sample_id_1> <02> <corresponding_sample_id_2> ... ${r} "
        display_help
        exit 1
    fi

    # Prepare log file
    log_file="${w_d}/bin/logs/$(date +'%Y%m%d_%H-%M-%S')_pipe_log.txt"
    echo "Date: $(date)" > "$log_file"
    echo -e "\nSample ID\tBarcode\tFile Location" >> "$log_file"
    # Run nap pipe for each file sequentially
    while [ $# -ge 2 ]; do
        barcode="$1"
        sample_id="$2"
        sample_file=$(find ${cd}/raw_data -name "*barcode${barcode}.fastq" -type f -print -quit)

        if [ -n "$sample_file" ]; then
            # Pass the log file path as the third argument to pipe.sh
            echo -e "${sample_id}\t${barcode}\t${sample_file}" >> "$log_file"
            # Check temrinal size to prevent issues with progres bar
            min_width=150
            current_width=$(tput cols)
            if [ "$current_width" -lt "$min_width" ]; then
              echo "${er}WARNING:${in} resize your terminal to at least $min_width ($current_width current) columns for proper display"
              while [ "$current_width" -lt "$min_width" ]; do
                read -p "Press Enter after resizing your terminal..." # Wait for user to resize
                  current_width=$(tput cols) # Re-check the width
                if [ "$current_width" -lt "$min_width" ]; then
                  echo "${er}ERROR:${in} Terminal is $current_width, must be >$min_width"
                fi
              done
        fi
            bash "${sub}/pipe.sh" "${sample_file}" "${sample_id}" "${log_file}"
        else
            echo "${er}ERROR: ${in}File for barcode ${cd}/raw_data/*${barcode}.fastq not found ${r}"
            display_help
            exit 1
        fi

        shift 2
    done
    echo -e "${in}Log file created: ${log_file} ${r}"
fi
