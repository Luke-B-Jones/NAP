#!/bin/bash

# Find directories
source config.sh
sub="${w_d}/bin/scripts"
cd=$(pwd)





###	 HELP	###
## General
# Display help regardless of bash syntax error in -help
function display_help() {
    echo "${in} Usage: nap <dorado/pipe/stat/update-database> [options]...${r} "
    echo "${in} Try: nap <tool name> -h or --help for more specific information ${r} "
}

if [ "$1" = "-help" ] || [ "$1" = "-h" ]; then
    display_help
    exit 0
fi


# DORADO

if [[ "$1" == "dorado" ]]; then
    if [[ "$2" == "-h" || "$2" == "--help" ]]; then
        echo "${er} Usage:${in} nap dorado (simply be in the directory containing your ./pod5/ ${r}"
        exit 0
    fi
fi


# PIPE

if [[ "$1" == "pipe" ]]; then
    if [[ "$2" == "-h" || "$2" == "--help" ]]; then
        echo "${er} Usage:${in} nap pipe <(barcode number:)01> <corresponding_sample_id_1> <02> <corresponding_sample_id_2>.... ${r}"
        exit 0
    fi
fi


if [[ "$1" == "update-database" ]]; then
    if [[ "$2" == "-h" || "$2" == "--help" ]]; then
        echo "${er} Usage:${in} nap update-database; simply be in the database folder along with your database.fasta${r}"
        exit 0
    fi
fi





###	Data identification	###
TOOL_NAME=$1
shift


# Script 'nap dorado'
if [ "$TOOL_NAME" = "dorado" ]; then
  bash "${sub}/dorado.sh"
fi

# Script 'nap dorado-hq'
if [ "$TOOL_NAME" = "dorado-hq" ]; then
  bash "${sub}/dorado-strict.sh"
fi

if [ "$TOOL_NAME" = "dorado-auto" ]; then
  bash "${sub}/dorado-auto.sh"
fi


# Script 'nap cd'
if [ "$TOOL_NAME" = "update-database" ]; then
  bash "${sub}/update-database.sh"
fi


# Script to run 'nap pipe' for each sample given and export variable
if [ "$TOOL_NAME" = "pipe" ]; then
    # Check if there are arguments
    if [ $# -lt 2 ]; then
        echo "${in}Format: nap pipe <01> <corresponding_sample_id_1> <02> <corresponding_sample_id_2> ... for up to 12 samples (please copy barcode file names) ${r} "
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
            bash "${sub}/pipe.sh" "${sample_file}" "${sample_id}" "${log_file}"
        else
            echo "${er}ERROR: ${in}File for barcode ${cd}/raw_data/*${barcode}.fastq not found ${r}"
            display_help
            exit 1
        fi

        shift 2
    done
    echo -e "${in}Log file created: ${log_file} ${r}"

else
    # Run the tool script with the remaining arguments
    bash "$sub/$TOOL_NAME" "$@"
fi







