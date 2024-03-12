NAP - Made by Luke Jones (Biochemistry Ph.D. student, department of life sciences, the University of Bath) 01/2024

How to use:
(1) Install dependencies

(2) Run 'setup.sh'

(3) Add tools directory to you '.bashrc'

(4) Setup 'config.sh'

(5) Use 'nap dorado' (both -h and --help availble) to prepair data

(6) Use 'nap pipe' (both -h and --help availble) to generate microbiome abundance and taxonomy data

(7) Check your log for further infomation on runs


Additional:
(1) Use 'nap update-database' to update the database used for taxonomy binning and classification



Decode files:
(DORADO.SH)
current_directory/
                 /pod5/                     -> Your preexisting data
                 /demux/                    -> All demuxed data (barcodes and unassigned in fastq format)
                 /raw_data/                 -> All fastq data associated with a barcode
(PIPE.sh)
current_directory/Sample_id/
                           /prep/           -> Ongoing files for all QC and binning stages (Alighment, chimera filtration, binnning, error correction)
                                /bin        -> Fastp reports and none essential chimeria removal files 
                                /filter     -> Fastp output (first round QC reads)
                                /RAW        -> RAW reads for QIIME (showing untampered abundances of all reads)
                                
                           /PROK/           -> 16S amplicon QIIME outputs
                                /fastq      -> 16S binned and error corrected reads for QIIME (partially dereplicated)

                           /EUK/            -> 18S amplicon QIIME outputs
                               /fastq       -> 18S binned and error corrected reads for QIIME (partially dereplicated)

                           /merged/         -> final 'microbiome.tsv' file
                                  /bin/     -> Processing files for normalisation, bias correction, scalling, and merging of 16S and 18S data

