#!/bin/bash

# Find directories
source config.sh
sub="${w_d}/bin/scripts"
cd=$(pwd)
config_location="${w_d}/config.sh"
# Display help regardless of bash syntax error in -help
function display_help() {
    echo "${in} Usage:${r} nap <tool> [options]...${r}
    Tools/Options:${r}
        pipe  ${r}-${in} process 16s and 18s mixed amplicon samples ${r}
        update-database  ${r}-${in} update alighment database ${r} 
        configure ${r}-${in} Modify internal settings ${r} 
        import ${r}-${in} Setup a new primer-set/amplicon-type for use ${r}
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
        cat "$config_location"
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

if [ "$TOOL_NAME" = "configure" ]; then
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
            echo "${er}ERROR:${in} Variable ${var_name} not found in config. Check spelling ${r}"
        fi
    }
    while [ $# -gt 0 ]; do
        arg=$1
        
        if [[ "$arg" =~ ^([^=]+)=(.*)$ ]]; then
            var_name="${BASH_REMATCH[1]}"
            new_value="${BASH_REMATCH[2]}"
            update_config "$var_name" "$new_value"
        else
            echo "${er}ERROR:${in} Invalid format. Use 'var_name=new_value' ${r}"
            break  # prevent spam
        fi
        
        shift  # Move to the next argument
    done

    cat "$config_location"
    echo "${su}Reconfiguration complete: ${r}"
fi


# nap import <name>
if [ "$TOOL_NAME" = "import" ]; then
    template_file="${subconfig}/AMP_template.sh"
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
    echo "${or}Enter maximum length filter (e.g., 1200; recommend max length +25%): ${r}"
    read max_length
    echo "${or}Enter minimum length filter (e.g., 150; recommend min length -10%): ${r}"
    read min_length
    echo "${or}Enter Blastn CON 16s identity threshold (default 95): ${r}"
    read ident_CON_16s
    echo "${or}Enter Blastn CON 18s identity threshold (default 95): ${r}"
    read ident_CON_18s
    echo "${or}Enter Blastn RAW 16s identity threshold (default 80): ${r}"
    read ident_RAW_16s
    echo "${or}Enter Blastn RAW 18s identity threshold (default 80): ${r}"
    read ident_RAW_18s
    echo "${or}Enter (relative) bias correction factor for 16s (e.g., 1): ${r}"
    read bias_factor_16s
    echo "${or}Enter (relative) bias correction factor for 18s (e.g., 2): ${r}"
    read bias_factor_18s
    echo "${or}Enter forward sequence for database (e.g., AGAGTTTGATCCTGGCTCAG): ${r}"
    read for_seq
    echo "${or}Enter reverse sequence for database (e.g., CTTACCTTGTTACGACTT): ${r}"
    read rev_seq
    echo "${or}Enter forward primer binding site range (e.g., 200-500; recommend extending higher value +20%): ${r}"
    read for_range
    echo "${or}Enter reverse primer binding site range (e.g., 600-1200; recommend extending lower value -20%): ${r}"
    read rev_range
    echo "${or}Enter minimum 16s amplicon length when trimming SILVA (e.g., 300): ${r}"
    read ref_min_length_16s
    echo "${or}Enter minimum 18s amplicon length when trimming SILVA (e.g., 400): ${r}"
    read ref_min_length_18s
    echo "${or}Average 16S amplicon length (e.g., 400): ${r}"
    read amplicon_16s_length
    echo "${or}Average 18S amplicon length (e.g., 700): ${r}"
    read amplicon_18s_length
    echo "${or}Type of primer (16s-18s;16s;18s): ${r}"
    read type


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
    update_amp_config "rev_range" "$rev_range" "$output_file"
    update_amp_config "ref_min_length_16s" "$ref_min_length_16s" "$output_file"
    update_amp_config "ref_min_length_18s" "$ref_min_length_18s" "$output_file"
    update_amp_config "amplicon_16s_length" "$amplicon_16s_length" "$output_file"
    update_amp_config "amplicon_18s_length" "$amplicon_18s_length" "$output_file"
    update_amp_config "type" "$type" "$output_file"

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
