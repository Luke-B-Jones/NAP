# ***NAP*** - Nanopore sequencing derived Amplicon Pipeline
By Luke B.Jones

## **Requirments**
(1) Docker

(2) PC capable of handleing large datasets (or alternatively, alot of free time), recommend >20GB RAM, GPU, and CPU with >4 cores

## **How to setup:**
`````
# Clone repo, and setup NAP
git clone https://github.com/Luke-B-Jones/NAP.git; \
cd ./NAP; \
./build.sh; \
nap update-database SILVA_138.2_SSU_NR99
`````
If nap update-database fails, check your ~/.bashrc has been correctly updated to include nap as alias
## **How to use:**
`````
# If you want to setup contamination (below assumes ./raw_data/*13*.fasta corisponds to B1 - blank 1)
nap pipe 13 B1 14 B2 15 B3; \
nap decon ./B1/B1*microbiome.tsv ./B2/B2*microbiome.tsv ./B3/B3*microbiome.tsv
`````
Once decontamination is turned on, proceed to data analysis
`````
# Again, assumes ./raw_data/*13*.fasta corisponds to S1 - sample 1
nap pipe 3 S1 2 S2 1 S3; \
nap decon ./B1/B1*microbiome.tsv ./B2/B2*microbiome.tsv ./B3/B3*microbiome.tsv
`````
## **Interpritation:**
(1) pipe score: values ranging from 0-100, calculated using Phred and read count, where >70% is considered a good output.
(2) Due to the nature of nanopore sequencing-based amplicons, low abundance artifacts will likely be present in any score <70%.
(3) Assuming 20% of reads are >Q30, we recommend a raw input of >500k reads.



## **THANKS TO:**
JAMES SWIFT (BSc University of Bath): Wrote the R scripts usng in the 'stat' module

MORGAN COCKRILL (Msc University of Bath): Improved 'pipe' modules robustness and QC section

JOSEPHINE ILOTT (Msc University of Bath): Wrote decontamination python
