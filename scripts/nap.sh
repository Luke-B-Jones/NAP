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
        decon  ${r}-${in} setup decontamination protocol (in pipe) ${r}
        update-database  ${r}-${in} update alighment database ${r} 
        config ${r}-${in} Modify internal settings ${r} 
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
        echo "${er} Usage:${in} nap pipe <path/to/sample.fastq> <sample_name> ... ${r}"
        echo "${in}        nap pipe <sample_table.tsv> ${r}"
        echo "${in} Table format:${r} column 1 = full fastq path, column 2 = sample name (tab separated), no header row ${r}"
        exit 0
    fi
fi
# DECON-taminate
if [[ "$1" == "decon" ]]; then
    if [[ "$2" == "-h" || "$2" == "--help" ]]; then
        echo "${er} Usage:${in} nap decon <path/to/blank_pipe_output_1> <path/to/blank_pipe_output_2>..... ${r}(${in} turn ON decontamination) ${r}"
        echo "${er} Usage:${in} nap decon off ${r}(${in} turn OFF decontamination) ${r}"
        exit 0
    fi
fi
# Update database
if [[ "$1" == "update-database" ]]; then
    if [[ "$2" == "-h" || "$2" == "--help" ]]; then
        echo "${er} Usage:${in} nap update-database <file_prefix> ${r}
        (1)${in} Be in the ./bin/databases/ folder along with your new database.fasta ${r}"
        exit 0
    fi
fi
# config
if [[ "$1" == "config" ]]; then
    if [[ "$2" == "-h" || "$2" == "--help" ]]; then
        sed -n '3,31p' "$config_location" | while IFS= read -r line; do
            if [[ $line == \#* ]]; then
                # Print lines starting with # in bold green
                echo -e "\033[1;32m$line\033[0m"
            else
                # Remove 'export', and split the line around '=' to color before and after
                line_no_export="${line//export/}"
                if [[ $line_no_export == *"="* ]]; then
                    # Split at '=' and print part before in grey, and after normally
                    before_equals="${line_no_export%%=*}"
                    after_equals="${line_no_export#*=}"
                    echo -e "\e[37m$before_equals\033[0m=$after_equals"
                else
                    # Print line normally if no '=' is found
                    echo "$line_no_export"
                fi
            fi
        done
        echo "${er} Usage:${r} nap config <variable_name>=<new_content>...${in} as many variables as you like
        e.g., ${r}nap config hardware_use=heavy${in}
        use '${r}nap config -h${in}' to show current config ${r} "
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


# Script to run 'nap pipe'
if [ "$TOOL_NAME" = "pipe" ]; then
    # Check input exists
    if [ $# -lt 1 ]; then
        echo "${in}Format:${r} nap pipe <path/to/sample.fastq> <sample_name> ... ${r}"
        echo "${in}   or:${r} nap pipe <sample_table.tsv> ${r}"
        display_help
        exit 1
    fi
    # Prepare log file
    log_file="${w_d}/bin/logs/$(date +'%Y%m%d_%H-%M-%S')_pipe_log.txt"
    echo "Date: $(date)" > "$log_file"
    echo -e "\nSample ID\tFile Location" >> "$log_file"
    # Function to run one sample
    run_pipe_sample() {
        sample_file="$1"
        sample_id="$2"
        if [ ! -f "$sample_file" ]; then
            echo "${er}ERROR:${in} Input file not found: ${sample_file} ${r}"
            exit 1
        fi
        echo -e "${sample_id}\t${sample_file}" >> "$log_file"
        # Check temrinal size to prevent issues with progres bar
        min_width=150
        current_width=$(tput cols < /dev/tty)
        if [ "$current_width" -lt "$min_width" ]; then
            echo "${er}WARNING:${in} resize your terminal to at > $min_width ($current_width current) columns for proper display"
            while [ "$current_width" -lt "$min_width" ]; do
                read -r -p "Press Enter after resizing your terminal..." < /dev/tty
                current_width=$(tput cols < /dev/tty)
                if [ "$current_width" -lt "$min_width" ]; then
                    echo "${er}ERROR:${in} Terminal is $current_width, must be >$min_width"
                fi
            done
        fi

        bash "${sub}/pipe.sh" "${sample_file}" "${sample_id}" "${log_file}"
    }
    # Mode 1: nap pipe <table.tsv>
    if [ $# -eq 1 ] && [ -f "$1" ]; then
        input_table="$1"
        while IFS=$'\t' read -r sample_file sample_id extra || [ -n "$sample_file" ]; do
            # Skip empty lines and comments
            if [ -z "$sample_file" ]; then
                continue
            fi
            if [[ "$sample_file" =~ ^# ]]; then
                continue
            fi
            # Skip simple header row if present
            lower_file=$(echo "$sample_file" | tr '[:upper:]' '[:lower:]')
            lower_id=$(echo "$sample_id" | tr '[:upper:]' '[:lower:]')
            if [[ "$lower_file" == "path" || "$lower_file" == "read_path" || "$lower_file" == "file" || "$lower_file" == "file_path" ]]; then
                if [[ "$lower_id" == "sample" || "$lower_id" == "sample_name" || "$lower_id" == "sample_id" ]]; then
                    continue
                fi
            fi
            if [ -z "$sample_id" ]; then
                echo "${er}ERROR:${in} Invalid table format in ${input_table}. Use tab-separated: <full_path><TAB><sample_name> ${r}"
                exit 1
            fi
            run_pipe_sample "$sample_file" "$sample_id"
        done < "$input_table"

    # Mode 2: nap pipe <path> <sample_name> <path2> <sample_name2> ...
    else
        if [ $(( $# % 2 )) -ne 0 ]; then
            echo "${er}ERROR:${in} Invalid format. Use path/sample_name pairs, or a single table file ${r}"
            exit 1
        fi
        while [ $# -ge 2 ]; do
            sample_file="$1"
            sample_id="$2"
            run_pipe_sample "$sample_file" "$sample_id"
            shift 2
        done
    fi
    echo -e "${in}Log file created: ${log_file} ${r}"
fi




if [ "$TOOL_NAME" = "decon" ]; then
    if [ "$1" = "off" ]; then
        # Turn off decontamination by setting blank_active to 0
        nap config "blank_active"="0"
        echo "${su}Decontamination has been turned off for 'pipe' ${r}"
    else
        # Create blank TSV and ensure config is updated
        blank_tsv_location=$(python "$setup_decontamination" "${@:1}")
        sync
        nap config "blank_loc"="$blank_tsv_location"

        
        # Initialize an array to store read counts
        read_counts=()

        # Loop through each TSV file path provided in ${@:1}
        for tsv_file in "${@:1}"; do
            # Identify the log directory relative to the TSV path
            log_dir=$(dirname "$tsv_file")/logs

            # Get the latest log file in the log directory
            latest_log=$(ls -t "$log_dir" 2>/dev/null | head -n 1)
            latest_log_path="$log_dir/$latest_log"

            # Check if the latest log file exists and extract sample_read_count
            if [[ -f "$latest_log_path" ]]; then
                # Extract sample_read_count from the latest log file
                sample_read_count=$(grep -oP 'sample_read_count=\K[0-9.]+' "$latest_log_path")
                
                # Ensure the extracted value is numeric and add it to the read_counts array
                if [[ -n "$sample_read_count" && "$sample_read_count" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                    read_counts+=("$sample_read_count")
                    echo "Found sample_read_count=$sample_read_count in $latest_log"  # Debugging output
                else
                    echo "Warning: No valid sample_read_count found in $latest_log" >&2
                fi
            else
                echo "Warning: No log file found in $log_dir" >&2
            fi
        done

        # Calculate the median read count if values are found
        if [ ${#read_counts[@]} -gt 0 ]; then
            # Sort the read_counts array numerically
            sorted_counts=($(printf '%s\n' "${read_counts[@]}" | sort -n))
            mid_index=$(( ${#sorted_counts[@]} / 2 ))

            # Calculate the median based on the number of entries
            if (( ${#sorted_counts[@]} % 2 == 0 )); then
                # Even number of entries: average the two middle values
                median=$(echo "(${sorted_counts[$mid_index-1]} + ${sorted_counts[$mid_index]}) / 2" | bc -l)
            else
                # Odd number of entries: take the middle value
                median=${sorted_counts[$mid_index]}
            fi
        else
            median=0
            echo "Warning: No valid sample_read_count values found across files." >&2
        fi

        # Update config with the calculated median read count
        nap config "blank_read_count"="$median"
        source "$config_location"
        
        # Verify configuration update for blank location
        if [ "$blank_tsv_location" = "$blank_loc" ]; then
            echo "${su}Decontamination has now correctly been set up and is enabled for 'pipe' ${r}"
            nap config "blank_active"="1"
        else
            echo "${er}ERROR:${in} The decontamination TSV doesn't match the config location ${r}"
            echo "${in}Python returned: ${r} $blank_tsv_location"
            echo "${in}Config specifies: ${r} $blank_average"
        fi
    fi
fi




if [ "$TOOL_NAME" = "config" ]; then
    # Function to update the config
    update_config() {
        local var_name=$1
        local new_value=$2

        # Check if the variable exists in the config file
        if grep -q "^export ${var_name}=" "$config_location"; then
            # Update the variable's value correctly within double quotes
            sed -i "s|^export ${var_name}=\".*\"|export ${var_name}=\"${new_value}\"|" "$config_location"
            echo "${su}Updated ${var_name} to ${new_value} ${r}"
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
    echo "${or}Enter Blastn HAC coverage threshold (default 70): ${r}"
    read cov_HAC
    echo "${or}Enter Blastn HAC identity threshold (default 95): ${r}"
    read ident_HAC
    echo "${or}Enter Blastn RAW identity threshold (default 80): ${r}"
    read ident_RAW
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
    update_amp_config "cov_HAC" "$cov_HAC" "$output_file"
    update_amp_config "ident_HAC" "$ident_CON" "$output_file"
    update_amp_config "ident_RAW" "$ident_RAW" "$output_file"
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
        echo "${su}Default remains $amplicon_pre_set, use nap config when you want to use 'AMP_${primer_set}'. ${r}"
    fi

    exit 0
fi
