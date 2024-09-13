import sys
import csv
from collections import defaultdict

def extract_taxonomy_and_calculate_abundance(blastn_out, output_tsv):
    # Define the start markers for taxonomy
    start_markers = ['Bacteria;', 'Archaea;', 'Eukaryota;']
    
    # Dictionary to store taxonomy and their abundance
    taxonomy_abundance = defaultdict(int)
    
    # Parse BLAST output file and extract the taxonomy
    with open(blastn_out, 'r') as blast_file:
        for line in blast_file:
            columns = line.strip().split('\t')
            taxonomy_full = columns[12]  # Full taxonomy line in column 13 (index 12)
            
            # Check if the taxonomy starts with any of the defined start markers
            if any(marker in taxonomy_full for marker in start_markers):
                # Split the taxonomy line into parts by ';'
                taxonomy_parts = taxonomy_full.split(';')
                
                # Get the genus and species part after the last semicolon
                genus_species = taxonomy_parts[-1].strip().split()  # Split the last part (genus and species)
                
                # Handle 'sp' cases, where we need to keep the last three words after the last ';'
                if genus_species[0] == 'sp':
                    final_taxonomy = ';'.join(taxonomy_parts[:-1]) + ';' + ' '.join(genus_species[-3:])
                else:
                    # Otherwise, take only the genus and first two words of the species, trim the rest
                    final_taxonomy = ';'.join(taxonomy_parts[:-1]) + ';' + ' '.join(genus_species[:2])

                # Increment abundance for this taxonomy
                taxonomy_abundance[final_taxonomy] += 1

    # Write the output TSV
    with open(output_tsv, 'w', newline='') as output_file:
        tsv_writer = csv.writer(output_file, delimiter='\t')
        # Write header
        tsv_writer.writerow(['Taxonomy', 'Abundance'])

        # Write taxonomy and abundance
        for taxonomy, abundance in taxonomy_abundance.items():
            tsv_writer.writerow([taxonomy, abundance])

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: python script.py <blastn.out> <output.tsv>")
    else:
        blastn_out = sys.argv[1]
        output_tsv = sys.argv[2]
        extract_taxonomy_and_calculate_abundance(blastn_out, output_tsv)
