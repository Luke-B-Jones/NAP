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
        (1)${in} Be in the ./bin/database/ folder along with your new database.fasta ${r}"
        exit 0
    fi
fi

# Reconfigure
if [[ "$1" == "configure" ]]; then
    if [[ "$2" == "-h" || "$2" == "--help" ]]; then
        echo "${er} Usage:${in} nap configure <variable_name>=<new_content>... as many varibales as you like
        e.g., nap configure hardware_use=heavy ${r} 
        use 'nap configure -c' to show current config"
        
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

# nap configure <var_name> <new_content> or nap configure -c
if [ "$TOOL_NAME" = "configure" ]; then
    config_location="${w_d}/config.sh"

    # Function to update the config
    update_config() {
        local var_name=$1
        local new_value=$2

        # Check if the variable exists in the config file
        if grep -q "^export ${var_name}=" "$config_location"; then
            # Update the variable's value correctly within double quotes
            sed -i "s|^export ${var_name}=\".*\"|export ${var_name}=\"${new_value}\"|" "$config_location"
            echo "Updated ${var_name} to ${new_value}"
        else
            # Variable not found, print an error
            echo "${er}ERROR:${in} Variable ${var_name} not found in config, check spelling? ${r}"
        fi
    }

    # Function to display the config file
    display_config() {
        echo "Current configuration:"
        cat "$config_location"
    }

    # Check for the -c option
    if [ "$1" = "-c" ]; then
        display_config
        exit 0
    fi

    # Loop through the arguments and update configs
    shift  # Skip the 'configure' argument
    while [ $# -gt 0 ]; do
        var_name=$1   # First argument is the variable name
        new_value=$2  # Second argument is the new value
        
        # Check if we have both a variable name and new value
        if [ -n "$var_name" ] && [ -n "$new_value" ]; then
            update_config "$var_name" "$new_value"
        else
            echo "${er}ERROR:${in} Missing variable name or new value, 'var_name=new_value' expected ${r}"
        fi

        # Shift by 2 to move to the next variable and value pair
        shift 2
    done

    # Echo a confirmation message and the entire configuration file for verification
    echo "${su}Reconfiguration complete: ${r}"
    cat "$config_location"
fi
