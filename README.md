# **NAP — Nanopore sequencing-derived Amplicon Pipeline**
By **Luke B. Jones**

![NAP Pipeline Workflow](pipeline.png)

---

## **Requirements**

1. **Docker**
2. **Hardware:** A PC capable of handling large datasets (or alternatively, sufficient time).  
   Recommended: **>20 GB RAM** and a **CPU with >4 cores**.

---

## **How to set up**

```
# Clone the git and move into dir
git clone https://github.com/Luke-B-Jones/NAP.git
cd ./NAP

# Establish the nap wrapper (not manditory, just easier for users)
echo "alias nap_activate='bash $(pwd)/nap_docker_wrap.sh'" >> ~/.bashrc
source ~/.bashrc

# Build the docker image
docker build --no-cache -t nap:latest .

# Activate the image
nap_activate /home/luke/Documents/data
```

---

## **How to use**
# *basal use*

Data is ran through the pipeline using `nap pipe`, to which data in two ways

(1) Directly providing files via commandline
```
# Single or multi input via commandline, given as <path to fastq> <sample id> - output folder is ./$sample_id
# Single input example
nap pipe /path/barcode.fastq B1
# multi input example
nap pipe /path/barcode13.fastq B1 /path/barcode14.fastq B2 /path/barcode15.fastq B3 
```
(2) Provide a table
```
# Provoding a table allows control over output location
nap pipe /path/table.tsv

# Table should be a three column, no header, tab seporated .TSV (must be .tsv named). Example content
/home/luke/Documents/data/ARCHIVE/rat_project/CO/raw_data/80793809db7ab12ecb5727975f1307826551ee7e_SQK-NBD114-24_barcode13.fastq	test-1	/home/luke/Documents/data/ARCHIVE/rat_project/TEST-1
/home/luke/Documents/data/ARCHIVE/rat_project/CO/raw_data/80793809db7ab12ecb5727975f1307826551ee7e_SQK-NBD114-24_barcode15.fastq	test-2	/home/luke/Documents/data/ARCHIVE/rat_project/TEST-2
```
# *decontamination*
If you run `nap pipe` before setting up decontamination, samples will simply skip decontamination step without flagging in terminal.

To setup decontamination you must first identify contaminatants. You have two options:
(1) RECOMMENDED method
```
# Sequence blanks from your setup/lab, run these through `nap pipe` 
nap pipe /path/barcode45.fastq B1 /path/barcode46.fastq B2 /path/barcode47.fastq B3
# Then pass nap decon the resulting outputs
nap decon ./B1/B1*SPECIES-LEVEL.tsv ./B2/B2*SPECIES-LEVEL.tsv ./B3/B3*SPECIES-LEVEL.tsv
# nap decon will update the contig, activating decontamination mode (blank_active turns from 0 to 1) and providing a path to blank table
```
(2) Manual method (not recommended, can inconsistent results)
```
# If you do not have lab blanks, but you know contaminants (from another project..etc), simply update config.sh manually.

# Update blank to active
nap config blank_active=1

# Provide 3 column table (more details below)
nap config blank_loc=/path/blank.tsv

# Provide the number (NUM) of reads represented in table
nap config blank_read_count=NUM

# table format should include taxa, normalised abundance, and prevolance across blanks (for manual, mark all as 1)
taxonomy	abundance	prevalence
Acidovorax sp.	101.8737322598151	1.0
Acinetobacter johnsonii	104.08898831717624	0.3333333333333333
```

---

## **Interpretation**

1. **Pipe score:** Ranges from 0–100, calculated using Phred quality and read count.  
   Values **>90** are considered high-quality outputs.

2. Due to the nature of nanopore sequencing-based amplicons,  
   **low-abundance artefacts** may be present in any run scoring **<90**.

3. Assuming ~20% of reads are >Q30, we recommend a raw input of  
   **>500,000 reads per sample**.

---

## **User Manual**

### **1. Database setup**

The classification database is set up via the following process:

1. The user downloads the desired database.
2. `scripts/update-database` performs conserved processing steps, and  
   defers filtering to `scripts/mammalian_microbiome_inclusion.sh`, which by default removes:
   - uncultured entries  
   - metagenome-derived entries  
   - unclassified entries  
   - chlorophyll-derived sequences  
   - unlikely eukaryotes (for microbiome research)

3. Remaining reference reads are trimmed to isolate amplified regions,  
   using the primer configuration specified in `subconfigs/AMP*` (as set in `config.sh`).

Users wishing to use a different database should:

- examine how the database is annotated  
- update the `awk` commands in `scripts/mammalian_microbiome_inclusion.sh` (lines 21 and 29) accordingly  
- consider the classification conventions used by their chosen database

To configure a **new primer set**, users should:

1. Create a new subconfig:  
   `subconfigs/AMP_${primer_name}.sh`
2. Update `config.sh`:  
   `export amplicon_pre_set="${primer_name}"`
3. Re-run database setup.

---

### **2. Custom amplicons**

Custom amplicons are added by creating a new file in:

```
subconfigs/AMP*.sh
```

(where `*` is the primer name), and activating it in `config.sh` via:

```
amplicon_pre_set=""
```

Users should follow the template and guidance in:

```
subconfigs/AMP_template.sh
```

---

### **3. Using non-barcoded raw data**

Inside the `nap` wrapper (around line 99), the script extracts the path of a barcoded dataset  
based on the numeric identifier supplied on the command line.

Example:

```
nap pipe 14 S1
```

This instructs the pipeline to use:

```
./raw_data/*barcode14.fastq
```

as the raw input for sample `S1`.

Users with differently named raw data may safely modify this part of the wrapper.

---

## **Thanks to**

- **Morgan Cockrill (MSc, University of Bath)** — Improved robustness of `pipe` modules and QC section  
- **Josephine Ilott (MSc, University of Bath)** — Authored the decontamination Python module


