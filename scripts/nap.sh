#!/bin/bash

# Find directories
source config.sh
sub="${w_d}/bin/scripts"
cd=$(pwd)

# Display help regardless of bash syntax error in -help
function display_help() {
    echo "${in} Usage:${r} nap <tool> [options]...${r}
    Tools/Options:${r}
        dorado  ${r}-${in} Basecalling and demultiplexing (dorado-auto to preload config settings) ${r}
            -a ${r}-${in} Exracts kit/basecalling model from config ${r}
            -m ${r}-${in} Manually input kit/model during run ${r}
        pipe  ${r}-${in} process 16s and 18s mixed amplicon samples ${r}
        update-database  ${r}-${in} update alighment database ${r} 
        --help  |  -h  ${r}- ${in} Print help info ${r}
        --version | -v  ${r}-${in} Print pipeline version ${r}"
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
# Import
if [[ "$1" == "import" ]]; then
    if [[ "$2" == "-h" || "$2" == "--help" ]]; then
        echo "${er} Usage:${in} nap import
        Create your own primer specific preset, directly modifing database setup and pipeline activity ${r}"        
        exit 0
    fi
fi

# Parse and initate scripts
TOOL_NAME=$1
shift

# Script 'nap dorado'
if [ "$TOOL_NAME" = "dorado" ]; then
  bash "${sub}/dorado.sh" "$1"
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

# nap import <name>
if [ "$TOOL_NAME" = "import" ]; then
    template_file="${subconfig}AMP_template.sh"
    if [ ! -f "$template_file" ]; then
        echo "${er}ERROR:${in} Template file not found: ${template_file} ${r}"
        exit 1
    fi

    # Prompt the user for input to populate variables in the template
    echo "Enter the primer set name (e.g., 515y-926r):"
    read primer_set
    # create the output file
    output_file="${w_d}/bin/scripts/AMP_${primer_set}.sh"
    cp "$template_file" "$output_file"
    # Prompt for user input to populate the variables
    echo "Enter maximum length filter (e.g., 1200; recommend max length +25%):"
    read max_length
    echo "Enter minimum length filter (e.g., 150; recommend min length -10%):"
    read min_length
    echo "Enter Blastn CON 16s identity threshold (default 95):"
    read ident_CON_16s
    echo "Enter Blastn CON 18s identity threshold (default 95):"
    read ident_CON_18s
    echo "Enter Blastn RAW 16s identity threshold (default 80):"
    read ident_RAW_16s
    echo "Enter Blastn RAW 18s identity threshold (default 80):"
    read ident_RAW_18s
    echo "Enter (relative) bias correction factor for 16s (e.g., 1):"
    read bias_factor_16s
    echo "Enter (relative) bias correction factor for 18s (e.g., 2):"
    read bias_factor_18s
    echo "Enter forward sequence for database (e.g., AGAGTTTGATCCTGGCTCAG):"
    read for_seq
    echo "Enter reverse sequence for database (e.g., CTTACCTTGTTACGACTT):"
    read rev_seq
    echo "Enter forward primer binding range (e.g., 200-500; recommend extending higher value +20%):"
    read for_range
    echo "Enter reverse primer binding range (e.g., 600-1200; recommend extending lower value -20%):"
    read rev_range
    echo "Enter minimum 16s amplicon legnth when trimming SILVA (e.g., 300):"
    read ref_min_length_16s
    echo "Enter minimum 18s amplicon legnth when trimming SILVA (e.g., 400):"
    read ref_min_length_18s

    
    # Function to update the configuration in the new file
    update_amp_config() {
        local var_name=$1
        local new_value=$2
        local file_path=$3

        # Update the variable's value correctly within double quotes in the export statement
        if grep -q "^export ${var_name}=" "$file_path"; then
            sed -i "s|^export ${var_name}=\".*\"|export ${var_name}=\"${new_value}\"|" "$file_path"
        else
            echo "${er}ERROR:${in} Variable ${var_name} not found in template file ${r}"
        fi
    }

    # Update the variables in the new file
    update_amp_config "max_length" "$max_length" "$output_file"
    update_amp_config "min_length" "$min_length" "$output_file"
    update_amp_config "ident_CON_16s" "$ident_CON_16s" "$output_file"
    update_amp_config "ident_CON_18s" "$ident_CON_18s" "$output_file"
    update_amp_config "ident_RAW_16s" "$ident_RAW_16s" "$output_file"
    update_amp_config "ident_RAW_18s" "$ident_RAW_18s" "$output_file"
    update_amp_config "bias_factor_16s" "$bias_factor_16s" "$output_file"
    update_amp_config "bias_factor_18s" "$bias_factor_18s" "$output_file"
    update_amp_config "for_seq" "$for_seq" "$output_file"
    update_amp_config "rev_seq" "$rev_seq" "$output_file"
    update_amp_config "for_range" "$for_range" "$output_file"
    update_amp_config "ref_min_length_16s" "$ref_min_length_16s" "$output_file"
    update_amp_config "ref_min_length_18s" "$ref_min_length_18s" "$output_file"
    cat "$output_file"
    # Ask the user to check the file and press Enter to proceed
    read -p "${su}Please review, press Enter to continue.${r}"

    # Ask if the user wants to make this the new default
    read -p "Do you want to make this the new default configuration? (y/n): " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        # Update the default configuration in config.sh
        config_file="${w_d}/config.sh"
        sed -i "s|^export amplicon_pre_set=\".*\"|export amplicon_pre_set=\"AMP_${primer_set}\"|" "$config_file"
        echo "${su}Default configuration updated to: AMP_${primer_set} ${r}"
    else
        echo "${su}Default remains $amplicon_pre_set, use nap configure when you want to use 'AMP_${primer_set}'. ${r}"
    fi

    exit 0
fi
