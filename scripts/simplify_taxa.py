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

        # Handle special cases for species
        if "sp." in species.lower() or species.lower() == "sp":
            return f'{genus} {species}'  # Keep 'sp' in the output with following characters
        else:
            # Return genus and species name, strip out any extra detail after species name
            species = species.split(' ')[0]  # Take only the first part if species name is compound or followed by other descriptors
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
