#!/bin/bash -i

source config.sh
cd=$(pwd)


###	Settings	###

read -p "${in}Press Enter to confirm your pod5s are in${r} ./pod5/ "

# Ask the user for the processing option
read -p "${er}Select mode:${in}
  1. Basecalling only needed.
  2. Demultiplexing and basecalling needed.
 ${r}" dorado_choice

# Validate the processing option
if [ "$dorado_choice" != "1" ] && [ "$dorado_choice" != "2" ] && [ "$dorado_choice" != "3" ]; then
  echo "${er}Invalid option ${in}- try again with either '1' or '2' ${r}"
  exit 1
fi


###	 Set variables	###

if [ "$dorado_choice" == "1" ]; then
  read -p "${in}Please state the basecalling model needed (e.g., ${r}${defualt_model}${in}): ${r}" model

elif [ "$dorado_choice" == "2" ]; then
  read -p "${in}Please state the kit used (e.g., ${r}${defualt_kit}${in}): ${r}" kit
  read -p "${in}...and the basecalling model needed (e.g., ${r}${defualt_model}${in}): ${r}" model

fi




###	Processing	###

# Basecalling only
if [ "$dorado_choice" == "1" ]; then
  # Dorado basecall for a single sample
  mkdir -p ./fastq
  mkdir -p ./raw_data
  cd ./fastq
  
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

# Basecalling and demux
elif [ "$dorado_choice" == "2" ]; then
  mkdir -p ./fastq
  mkdir -p ./demux
  mkdir -p ./raw_data
  cd ./fastq
  dorado download --model "$model"
  dorado basecaller "$model" "${cd}/pod5/" >> SSU_raw.fastq --emit-fastq --no-trim

  cd ../
  cd ./demux

  dorado demux --kit-name "$kit" --output-dir ./ "${cd}/fastq/SSU_raw.fastq" --emit-fastq --barcode-both-ends
  cd ../
  mv "${cd}/demux/"*barcode*.fastq "${cd}/raw_data/"

  # Check if the mv command was successful
  if [ $? -eq 0 ]; then
      echo "${su}Basecalling and demux successfully completed: ${in} please proceed to ns pipe '--help' for further information ${r}"
  else
      echo "${er}ERROR:${in} Failed to move .fastq files. ${r}"
  fi
fi




