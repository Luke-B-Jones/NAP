#!/bin/bash
source config.sh


loc=$(pwd)

printf "${in} Setup initiated in, press Enter once w_d=${r}${loc}${in} in the config.sh ${r} "
read -p "" 

# Check if config.sh exists REMAINS OF ME TRYING TO AUTOMATE $pwd storage, user now manually edits
#if [ -f "config.sh" ]; then
    # Update config.sh with the correct working_directory
    #sed -i "s|^export working_directory=.*$|export working_directory=\"$pipeline_directory\"|" config.sh
    #echo "${su} Tools directory saved: $pipeline_directory ${r} "
#else
    # Create config.sh if it doesn't exist
    #echo "export working_directory=\"$pipeline_directory\"" > config.sh
    #chmod +x ./bin/scripts/stor_config.sh
#fi


# Setup scripts
chmod +x "$loc/bin/scripts/nap.sh"
ln -s "$loc/bin/scripts/nap.sh" "$loc/nap"

chmod +x "$loc/bin/scripts/dorado.sh"

chmod +x "$loc/bin/scripts/pipe.sh"

chmod +x "$loc/bin/scripts/confirm.sh"

chmod +x "$loc/bin/scripts/update-database.sh"

chmod +x "$loc/bin/scripts/progress_monitor.py"



### Validate environments
## QIIME
#qiime_response=""
#if conda env list | grep -qE "qiime2-amplicon|qiime2"; then
    #qiime_env=$(conda env list | grep -E 'qiime2' | sort | tail -n 1 | awk '{print $1}')
    #echo -e "${su}Qiime2 (version: $qiime_env) found.${r} "
#else
    #echo -e "${er}ERROR: ${in}No Qiime2 environments found.${r} "
    #read -p "${in}Would you like to look for the latest general version of QIIME2? (yes/no) ${r} " qiime_response
    #if [ "$qiime_response" = "yes" ]; then
        #qiime_env=$(conda env list | grep -E 'qiime2' | sort | tail -n 1 | awk '{print $1}')
        #if [ -n "$qiime_env" ]; then
           # echo -e "${su}Qiime2 (version: $qiime_env) found${r} "
        #else
            #echo -e "${er}ERROR: ${ip}Qiime2 not found, please input environtment name into config.sh${r} "
            #exit 1
        #fi
    #elif [ "$qiime_response" = "no" ]; then
        #exit 1
    #fi
#fi


## BBmap
#bbmap_env=$(conda env list | grep bbmap | sort | tail -n 1 | awk '{print $1}')
#if [ -z "$bbmap_env" ]; then
    #echo -e "${er}ERROR: ${in}No BBmap environment found, please input environtment name into config.sh${r} "
#else
    #echo -e "${su}BBmap (version: $bbmap_env) found${r} "
#fi


## Fastqc
#fastqc_env=$(conda env list | grep fastqc | sort | tail -n 1 | awk '{print $1}')
#if [ -z "$fastqc_env" ]; then
#    echo -e "${er}ERROR: ${in}No fastqc environment found, please input environtment name into config.sh${r} "
#else
#    echo -e "${su}Fastqc (version: $fastqc_env) found ${r}"
#fi





# Print version and level of success
./bin/scripts/confirm.sh
if conda env list | grep -qE "qiime2.*amplicon" && conda env list | grep -qE "bbmap" && conda env list | grep -qE "qiime2*"; then
    echo "${su}${pipeline_name} v${pipeline_database_version} setup successful - ${in}default database ${default_database_name} v${default_database_version} installed
please use ${r} nap --help${in} or${r} nap -h${in} for more information ${r}"
elif ! conda env list | grep -qE "qiime2.*amplicon" && conda env list | grep -qE "bbmap"; then
    echo -e "${su}$pipeline_name - v$pipeline_database_version:${in} Qiime2 not found. Please use 'ns --help' or 'ns -h' to validate successful setup.${r}"
elif conda env list | grep -qE "qiime2.*amplicon" && ! conda env list | grep -qE "bbmap"; then
    echo -e "${su}$pipeline_name - v$pipeline_database_version:${in} BBmap not found. Please use 'ns --help' or 'ns -h' to validate successful setup.${r}"
else
    echo -e "${su}$pipeline_name - v$pipeline_database_version:${in} Environments not found. Please use 'ns --help' or 'ns -h' to validate successful setup.${r}"
fi


printf "${er} Please ensure this tools directory is on PATH ( cd ~/ | ls -a | vim .bashrc) before use ${r} 
"
echo "This version of nap (${pipeline_database_version}) also requires you to input environment names into config.sh before use"







