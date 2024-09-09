# ***NAP*** - Nanopore sequencing derived Amplicon Pipeline
By Luke B.Jones

## **Requirments**
(1) Docker

(2) PC capable of handleing large datasets (or alternatively, alot of free time), recommend >20GB RAM, GPU, and CPU with >4 cores

## **How to setup:**
(1 of 3) Clone repo, and setup docker
`````
git clone https://github.com/Luke-B-Jones/NAP.git
`````
`````
cd ./NAP
`````
`````
docker build --build-arg USER_NAME=$USER -t nap .
`````
(2 of 3) Activate your image (Change directory to where your samples are) and get going...
`````
docker run -it -v /home/$USER/Documents:/home/$USER/Documents nap
`````
(3 of 3) Use NAP
`````
nap --help
`````
Optional: change the config (Phred score, basecalling model...etc)
`````
nap configure -h
`````

## **How to use:**
\\\\\\\\\\\ UNDER CONSTRUCTION \\\\\\\\\\\\\\\\\\\\\\\\\\\\






## **THANKS TO:**
JAMES SWIFT (BSc University of Bath): Wrote the R scripts usng in the 'stat' module

MORGAN COCKRILL (Msc University of Bath): Improved 'pipe' modules robustness and QC section
