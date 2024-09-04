import sys
import pandas as pd

def extract_genus_species(taxonomy):
    """Extracts the 'genus species' from the taxonomy string."""
    levels = taxonomy.split(';')
    if len(levels) >= 6:
        genus_species = ' '.join(levels[-2:])  # Taking the last two levels as 'Genus Species'
    else:
        genus_species = levels[-1]  # If not enough levels, just take the last one
    return genus_species.strip()

def process_tsv(input_file, output_file):
    # Read the input TSV file
    try:
        df = pd.read_csv(input_file, sep='\t')
    except FileNotFoundError:
        print(f"Error: File '{input_file}' not found.")
        sys.exit(1)
    except pd.errors.EmptyDataError:
        print(f"Error: File '{input_file}' is empty.")
        sys.exit(1)
    
    # Ensure the necessary columns exist
    if 'taxonomy' not in df.columns or 'abundance' not in df.columns:
        print("Error: Input file must contain 'taxonomy' and 'abundance' columns.")
        sys.exit(1)

    # Extract 'genus species' and sum abundances by these taxa
    df['genus_species'] = df['taxonomy'].apply(extract_genus_species)
    summed_abundance = df.groupby('genus_species')['abundance'].sum().reset_index()

    # Write the output to a new TSV file with appropriate headers
    summed_abundance.columns = ['taxonomy', 'abundance']
    summed_abundance.to_csv(output_file, sep='\t', index=False)
  
if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python sim_taxa.py <input_file> <output_file>")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]

    process_tsv(input_file, output_file)
