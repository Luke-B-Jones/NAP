import sys
import csv

def extract_taxonomy_and_abundance(clusters_fastq, blastn_out, output_tsv):
    # Define the start markers for taxonomy
    start_markers = ['Bacteria;', 'Archaea;', 'Eukaryota;']

    # Parse BLAST output file and extract the taxonomy and cluster number
    taxonomy_data = {}
    with open(blastn_out, 'r') as blast_file:
        for line in blast_file:
            columns = line.strip().split('\t')
            cluster_num = columns[0].split('_')[1]  # Extract cluster_NUM from the first column
            taxonomy_full = columns[12]  # Full taxonomy line in column 13 (index 12)
            # Check if any of the start markers are in the taxonomy line
            if any(marker in taxonomy_full for marker in start_markers):
                taxonomy_data[cluster_num] = taxonomy_full

    # Parse clusters FASTQ file to extract total_reads number
    abundance_data = {}
    with open(clusters_fastq, 'r') as fastq_file:
        for line in fastq_file:
            if line.startswith('@'):
                cluster_header = line.strip().split(' ')[0]
                cluster_num = cluster_header.split('_')[1]
                for part in line.strip().split(' '):
                    if part.startswith('total_reads='):
                        total_reads = part.split('=')[1]
                        abundance_data[cluster_num] = total_reads

    # Write the output TSV
    with open(output_tsv, 'w', newline='') as output_file:
        tsv_writer = csv.writer(output_file, delimiter='\t')
        # Write header
        tsv_writer.writerow(['Taxonomy', 'Abundance'])

        # Write data
        for cluster_num, taxonomy in taxonomy_data.items():
            abundance = abundance_data.get(cluster_num, '0')  # Default to '0' if not found
            tsv_writer.writerow([taxonomy, abundance])

if __name__ == '__main__':
    if len(sys.argv) != 4:
        print("Usage: python script.py <clusters.fastq> <blastn.out> <output.tsv>")
    else:
        clusters_fastq = sys.argv[1]
        blastn_out = sys.argv[2]
        output_tsv = sys.argv[3]
        extract_taxonomy_and_abundance(clusters_fastq, blastn_out, output_tsv)
