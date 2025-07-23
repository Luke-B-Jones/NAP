# ***NAP*** - Nanopore sequencing derived Amplicon Pipeline
By Luke B.Jones

## **Requirments**
(1) Conda

(2) PC capable of handleing large datasets (or alternatively, free time), recommend >20GB RAM and CPU with >4 cores

## **How to setup:**
`````
# Clone repo, and setup NAP
git clone https://github.com/Luke-B-Jones/NAP.git
cd ./NAP
./build.sh
# The conda env should be names 'nap_env', be sure to activate it before use of the pipeline tools.
conda env create -f environment.yml
# If nap update-database fails, check your ~/.bashrc has been correctly updated to include nap as alias
# If you intend to use primers which are not default, skip this last step, see User Manual (parts 1 and 2).
nap update-database SILVA_138.2_SSU_NR99
`````
## **How to use:**
ALWAYS ensure your input data for a project is stored in ./raw_data before running these commands, or consider reworking the wrapper to suit your needs.
`````
# If you want to setup contamination (below assumes ./raw_data/*13*.fasta corisponds to B1 - blank 1)
nap pipe 13 B1 14 B2 15 B3
nap decon ./B1/B1*SPECIES-LEVEL.tsv ./B2/B2*SPECIES-LEVEL.tsv ./B3/B3*SPECIES-LEVEL.tsv
`````
Once decontamination is turned on, proceed to data analysis - you can confirm this be checking /config.sh, if variables blank_read_count has content and blank_active="1", then your good to go.
`````
# Again, assumes ./raw_data/*13*.fasta corisponds to S1 - sample 1
nap pipe 3 S1 2 S2 1 S3
`````
## **Interpritation:**
(1) pipe score: values ranging from 0-100, calculated using Phred and read count, where >90% is considered a good output.
(2) Due to the nature of nanopore sequencing-based amplicons, low abundance artifacts will likely be present in any score <90%.
(3) Assuming 20% of reads are >Q30, we recommend a raw input of >500k reads.

## **User Manual**
(1) DATABASE SETUP
The classification database is setup in a simple process: (1) User downloads database; (2) /scripts/update-database handles basic conserved work, but offloads filtration to /scripts/mammalian_microbiome_inclusion.sh, which by default removes uncultured/metagenomic derived/unclassified/chlorophil rerived/unlikely eukaryotes for microbiome research; (3) remaning reference reads are trimmed in length to isolate amplified region (this relies on /subconfigs/AMP* configation pointed to by the /config).

Users which to use a different database should consider how the database is annoted, and update /scripts/mammalian_microbiome_inclusion.sh awk (lines 21 and 29) accordingly. Those who wish to modify the awks to include/exclude different taxa can do so with ease, consider checking your database of choise for classications used. Furthermore, should a user which to setup a new primer set for the pipeline, be sure to produce the required subconfig (as /subconfigs/AMP*${primer_name}.sh), amend the /config.sh with export amplicon_pre_set="${primer_name}", and then rerun the database setup.

(2) CUSTOM AMPLICONS
As outlines above, custom amplicons are added to the pipeline by adding a new entry to /subconfigs/AMP*.sh, where * is your primer name, and will be used by changing the config to reflect this (using variable amplicon_pre_set=""). Inside this, all details should be given using the guide in /subconfigs/AMP_template.sh.

(3) USING NONE BARCODED RAW DATA.
Inside /nap wrapper, starting line 99, the wrapper extract the file path of a barcoded dataset from the number given via commandline. nap pipe 14 S1, for example, tells the pipeline to look at ./raw_data/*barcode14.fastq - and have this be raw input for sample S1. Users can safely modify this if using data with different naming conventions.




## **THANKS TO:**
MORGAN COCKRILL (Msc University of Bath): Improved 'pipe' modules robustness and QC section

JOSEPHINE ILOTT (Msc University of Bath): Wrote decontamination python
