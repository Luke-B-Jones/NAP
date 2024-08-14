NAP - Made by Luke Jones (PhD student, University of Bath) with help from Morgan Cockrill (optimisation and script debugging) and James Swift (R scripts development)

How to setup:
conda install -c bioforge nap


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
                           /prep/           -> Ongoing files for all QC and binning stages (Alighment, chimera filtration, binnning, bin refinment)
                                /filter     -> Fastp output (first round QC reads)
                                /bin        -> Fastp reports and none essential chimeria removal files 
                                
                           /PROK/           -> 16S blastn files

                           /EUK/            -> 18S blastn files

                           /merged/         -> final 'microbiome.tsv' file
                                  /bin/     -> Processing files for normalisation, bias correction, scalling, and merging of 16S and 18S data

STATISTICAL ANALYSIS R SCRIPTS WILL BE AVAILBE IN THE FUTURE THANKS TO JAMES SWIFT (Bsc University of Bath)

