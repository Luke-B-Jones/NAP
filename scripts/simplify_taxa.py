import pandas as pd
import re
import sys

# Function to clean and process the taxonomy
def clean_taxonomy(taxonomy):
    # Remove brackets
    taxonomy = re.sub(r'[\(\)\[\]\{\}]', '', taxonomy)
    # Split taxonomy into levels and take only the part after the last semicolon
    genus_species = taxonomy.strip().split(';')[-1].strip()  # Only take the last part (genus and species level)
    # Split the genus_species part into individual words
    genus_species_split = genus_species.split()
    # Case 1: Handle case where the second word is 'sp'
    if len(genus_species_split) >= 2 and genus_species_split[1] == 'sp':
        # Keep genus and "sp", and any words after "sp"
        genus_species = ' '.join(genus_species_split[:3]) if len(genus_species_split) > 2 else ' '.join(genus_species_split[:2])
    # Case 2: Otherwise, keep only the first two words (Genus and Species)
    else:
        genus_species = ' '.join(genus_species_split[:2])
    # Return only the cleaned genus and species
    return genus_species


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

    # Sort the grouped data by abundance in descending order and save the result
    df_grouped = df_grouped.sort_values(by='abundance', ascending=False)
   # Output the sorted result as TSV
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
