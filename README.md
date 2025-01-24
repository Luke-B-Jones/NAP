# ***NAP*** - Nanopore sequencing derived Amplicon Pipeline
By Luke B.Jones

## **Requirments**
(1) Docker

(2) PC capable of handleing large datasets (or alternatively, alot of free time), recommend >20GB RAM, GPU, and CPU with >4 cores

## **How to setup:**
(1 of 4) Clone repo, and setup
`````
git clone https://github.com/Luke-B-Jones/NAP.git
`````
`````
cd ./NAP
`````
`````
./build.sh
`````
# Update your ~/.bashrc
`````

(2 of 4) Activate your image (Change directory to where your samples are) and get going...
`````
docker run -it -v /home/$USER/Documents:/home/$USER/Documents nap
`````
(3 of 4) Inspect config and choose your primer set
`````
nap configure amplicon_pre_set=515y-926r
`````
(4 of 4) Build database based on primer selected
`````
nap update-database SILVA_138.2_SSU_NR99
`````

## **How to use:**
\\\\\\\\\\\ UNDER CONSTRUCTION \\\\\\\\\\\\\\\\\\\\\\\\\\\\






## **THANKS TO:**
JAMES SWIFT (BSc University of Bath): Wrote the R scripts usng in the 'stat' module

MORGAN COCKRILL (Msc University of Bath): Improved 'pipe' modules robustness and QC section
