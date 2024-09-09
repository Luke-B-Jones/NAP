import sys
import pandas as pd
import re

def extract_genus_species(taxonomy):
    """Extracts the 'genus species' from the taxonomy string, ensuring proper formatting."""
    # Remove any bracketed terms
    cleaned_taxonomy = re.sub(r'\[.*?\]', '', taxonomy).strip()
    levels = cleaned_taxonomy.split(';')

    # Check if we have at least genus and species levels
    if len(levels) >= 2:
        genus = levels[-2].strip().capitalize()  # Extract and capitalize the genus
        species = levels[-1].strip()  # Extract the species

        # Handle cases like "sp." or "sp"
        if species.lower() == "sp" or "sp." in species.lower():
            return f'{genus} sp'  # Return "Genus sp" for species "sp"
        else:
            species_parts = species.split(' ')
            return f'{genus} {species_parts[0]}'  # Return "Genus Species", ignoring any additional description

    elif len(levels) == 1:
        # If only one level, treat it as the genus
        return levels[0].capitalize()
    
    return cleaned_taxonomy.capitalize()  # Use the whole taxonomy if shorter than expected

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

    # Ensure necessary columns are present
    if 'taxonomy' not in df.columns or 'abundance' not in df.columns:
        print("Error: Input file must contain 'taxonomy' and 'abundance' columns.")
        sys.exit(1)

    # Apply taxonomy extraction
    df['genus_species'] = df['taxonomy'].apply(extract_genus_species)

    # Sum abundances for the same genus-species combinations
    summed_abundance = df.groupby('genus_species')['abundance'].sum().reset_index()

    # Write the output to a new TSV file
    summed_abundance.columns = ['taxonomy', 'abundance']
    summed_abundance.to_csv(output_file, sep='\t', index=False)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python script.py <input_file> <output_file>")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]

    process_tsv(input_file, output_file)
