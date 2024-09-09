import pandas as pd
import re
import sys

# Function to clean and process the taxonomy
def clean_taxonomy(taxonomy):
    # Remove brackets
    taxonomy = re.sub(r'[\(\)\[\]\{\}]', '', taxonomy)
    
    # Split taxonomy into levels and extract genus and species
    parts = taxonomy.strip().split(';')
    genus_species = parts[-1].strip()
    
    # Handle "sp" cases: if second word is "sp", retain it, otherwise trim after genus and species
    genus_species_split = genus_species.split()
    if len(genus_species_split) > 1 and genus_species_split[1] == 'sp':
        genus_species = ' '.join(genus_species_split[:2])  # Keep "Genus sp"
    else:
        genus_species = ' '.join(genus_species_split[:2])  # Only keep Genus and Species
    
    # Return cleaned taxonomy path with genus and species
    return ';'.join(parts[:-1]) + ';' + genus_species

# Load the TSV file
def process_tsv(input_file, output_file):
    # Load TSV
    df = pd.read_csv(input_file, sep='\t')

    # Remove brackets from the taxonomy column and clean taxonomy
    df['taxonomy'] = df['taxonomy'].apply(clean_taxonomy)

    # Group by taxonomy without case normalization and merge abundance, ignoring case
    df['taxonomy_lower'] = df['taxonomy'].str.lower()  # Create a lowercase version for comparison
    df_grouped = df.groupby('taxonomy_lower', as_index=False).agg(
        {'taxonomy': 'first', 'abundance': 'sum'}
    )

    # Sort by abundance in descending order
    df_grouped = df_grouped.sort_values(by='abundance', ascending=False)

    # Output the result as TSV
    df_grouped[['taxonomy', 'abundance']].to_csv(output_file, sep='\t', index=False)

# Main function to handle command line arguments
if __name__ == '__main__':
    # Ensure two arguments are provided: input and output file paths
    if len(sys.argv) != 3:
        print("Usage: python script.py <input_file> <output_file>")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]

    # Process the TSV file
    process_tsv(input_file, output_file)
