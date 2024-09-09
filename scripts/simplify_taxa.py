import sys
import pandas as pd
import re

def extract_genus_species(taxonomy):
    """Extracts the 'genus species' from the taxonomy string, handling special cases and formatting."""
    # Remove any bracketed terms
    cleaned_taxonomy = re.sub(r'\[.*?\]', '', taxonomy).strip()
    levels = cleaned_taxonomy.split(';')

    if len(levels) >= 2:
        genus = levels[-2].strip().capitalize()  # Capitalize the genus
        species = levels[-1].strip()
        species_parts = species.split(' ')  # Split species by spaces to manage subspecies or strains

        # Handle subspecies and strains by ignoring anything beyond the first two parts
        # This will merge all subspecies and strains under the main species
        if len(species_parts) > 1 and (species_parts[1].startswith('subsp.') or re.match(r'ATCC \d+', species_parts[1])):
            species = species_parts[0]  # Only take the main species name
        return f'{genus} {species}'
    elif len(levels) == 1:
        # Only one level, treat it as genus (or the whole taxonomy if it's unclear)
        return levels[0].capitalize()
    return cleaned_taxonomy.capitalize()  # Default to the whole cleaned taxonomy if it's too short

def process_tsv(input_file, output_file):
    """Reads a TSV, processes the taxonomy to extract genus and species, and writes the sum of abundances."""
    try:
        df = pd.read_csv(input_file, sep='\t')
    except FileNotFoundError:
        print(f"Error: File '{input_file}' not found.")
        sys.exit(1)
    except pd.errors.EmptyDataError:
        print(f"Error: File '{input_file}' is empty.")
        sys.exit(1)

    if 'taxonomy' not in df.columns or 'abundance' not in df.columns:
        print("Error: Input file must contain 'taxonomy' and 'abundance' columns.")
        sys.exit(1)

    df['genus_species'] = df['taxonomy'].apply(extract_genus_species)
    summed_abundance = df.groupby('genus_species')['abundance'].sum().reset_index()

    summed_abundance.columns = ['taxonomy', 'abundance']
    summed_abundance.to_csv(output_file, sep='\t', index=False)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python script.py <input_file> <output_file>")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]

    process_tsv(input_file, output_file)
