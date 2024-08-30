NAP - Nanopore sequencing derived Amplicon Pipeline
By Luke B.Jones

How to setup:
# GO TO YOUR TOOLS DIRECTORY
git clone https://github.com/Luke-B-Jones/NAP.git
cd ./NAP
docker build -t nap .



Directory info:
(DORADO.SH)
current_directory/
                 /pod5/                     -> Your preexisting data
                 /demux/                    -> All demuxed data (barcodes and unassigned in fastq format)
                 /raw_data/                 -> All fastq data associated with a barcode
(PIPE.sh)
current_directory/sample_id/
                           /prep/           -> Ongoing files for all QC and binning stages (Alighment, chimera filtration, binnning, bin refinment)
                                /filter     -> Chimiera detection and quality filtering output (first round QC reads)
                                /bin        -> Extract reads and quality info for reads which pass QC
                                
                           /PROK/           -> 16S binning and blastn files

                           /EUK/            -> 18S binning and blastn files

                           /merged/         -> final 'microbiome.tsv' file (labled with Phred used)
                                  /bin/     -> Processing files for normalisation, bias correction, scalling, and merging of 16S and 18S data

(STAT.sh)
current_directory/analysis_id/

THANKS TO:
JAMES SWIFT (Bsc University of Bath): STATISTICAL ANALYSIS R SCRIPTS (AVAILBE IN THE FUTURE THANKS)
MORGAN COCKRILL (Msc University of Bath): IMPROVING CODE FUNCTIONALITY AND QC FUNCTIONALITY
