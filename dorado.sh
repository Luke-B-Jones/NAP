#!/bin/bash

source config.sh
cd=$(pwd)
man_auto_choice=$1

# Error if no man/auto
if [ "$man_auto_choice" != "-a" ] && [ "$man_auto_choice" != "-m" ]; then
  echo "${er}ERROR:${in} man/auto not selected, try -a or -m.${r}"
  exit 1
fi
# Setup
read -p "${in}Press Enter to confirm your pod5s are in${r} ./pod5/ "
# Man or auto
if [ "$man_auto_choice" != "-m" ]; then
  # Ask the user for the processing option
  read -p "${er}Select mode:${in}
    1. Basecalling only needed.
    2. Demultiplexing and basecalling needed.
   ${r}" dorado_choice
  # Validate the processing option
  if [ "$dorado_choice" != "1" ] && [ "$dorado_choice" != "2" ]; then
    echo "${er}Invalid option ${in}- try again with either '1' or '2' ${r}"
    exit 1
fi


basecall_only() {
  # setup directorys
  mkdir -p ./fastq
  mkdir -p ./raw_data
  cd ./fastq
  # Model and basecall
  dorado download --model "$model"
  dorado basecaller "$model" "${cd}/pod5/" >> SSU_raw.fastq --emit-fastq
  # Move all .fastq files from the fastq directory to dorado_output directory
  mv "${cd}/fastq/"*.fastq "${cd}/raw_data/"
  cd ../
  # Check if the mv command was successful
  if [ $? -eq 0 ]; then
      echo "${su}Basecalling successfully completed: ${in} please proceed to ns pipe '--help' for further information ${r}"
  else
      echo "${er}ERROR:${in} Failed to move .fastq files. ${r}"
  fi
}
basecall_demux(){
  # setup direcotrys
  mkdir -p ./fastq
  mkdir -p ./demux
  mkdir -p ./raw_data
  cd ./fastq
  # Model and basecall
  dorado download --model "$model"
  dorado basecaller "$model" "${cd}/pod5/" >> SSU_raw.fastq --emit-fastq --no-trim
  # Move all files and demux
  cd ../
  cd ./demux
  dorado demux --kit-name "$kit" --output-dir ./ "${cd}/fastq/SSU_raw.fastq" --emit-fastq
  cd ../
  mv "${cd}/demux/"*barcode*.fastq "${cd}/raw_data/"
  # Check if the mv command was successful
  if [ $? -eq 0 ]; then
      echo "${su}Basecalling and demux successfully completed: ${in} please proceed to ns pipe '--help' for further information ${r}"
  else
      echo "${er}ERROR:${in} Failed to move .fastq files. ${r}"
  fi
}

# Run
if [ "$man_auto_choice" == "-m" ]; then
  if [ "$dorado_choice" == "1" ]; then
    read -p "${in}Please state the basecalling model needed (e.g., ${r}${default_model}${in}): ${r}" model
    basecall_only
  elif [ "$dorado_choice" == "2" ]; then
    read -p "${in}Please state the kit used (e.g., ${r}${default_kit}${in}): ${r}" kit
    read -p "${in}...and the basecalling model needed (e.g., ${r}${default_model}${in}): ${r}" model
    basecall_demux
  fi
elif [ "$man_auto_choice" == "-a" ]; then
  if [ "$demux_needed" == "yes" ]; then
     basecall_demux
  elif [ "$demux_needed" == "no" ]; then
     basecall_only
  fi
fi