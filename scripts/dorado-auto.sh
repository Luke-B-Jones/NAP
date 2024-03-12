#!/bin/bash

source config.sh
cd=$(pwd)


# Basecalling and demux
mkdir -p ./fastq
mkdir -p ./demux
mkdir -p ./raw_data
cd ./fastq
dorado download --model "${defualt_model}"
dorado basecaller "${defualt_model}" "${cd}/pod5/" >> SSU_raw.fastq --emit-fastq --no-trim

cd ../
cd ./demux

dorado demux --kit-name "${defualt_kit}" --output-dir ./ "${cd}/fastq/SSU_raw.fastq" --emit-fastq
cd ../
mv "${cd}/demux/"*barcode*.fastq "${cd}/raw_data/"

# Check if the mv command was successful
if [ $? -eq 0 ]; then
  :
else
  echo "${er}ERROR:${in} Failed to move .fastq files. ${r}"
fi





