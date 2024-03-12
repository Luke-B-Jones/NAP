import pandas as pd
import sys

def merge_taxonomy_abundance(table_path, taxonomy_path, output_id):
    # Load the table and taxonomy data with the first column (#OTUID) as the index
    table_data = pd.read_csv(table_path, sep='\t', index_col='#OTUID')
    taxonomy_data = pd.read_csv(taxonomy_path, sep='\t', index_col='#OTUID')

    # Merge the table and taxonomy data on the index (#OTUID)
    merged_data = table_data.merge(taxonomy_data, left_index=True, right_index=True, how='inner')

    # Rename columns as needed to match the desired output structure
    # Assuming 'abundance' is in table_data and 'taxonomy' and 'confidence' are in taxonomy_data
    merged_data.rename(columns={merged_data.columns[0]: 'abundance', 'Taxon': 'taxonomy', 'Confidence': 'confidence'}, inplace=True)

    # Select only the columns needed for the output
    output_data = merged_data[['abundance', 'taxonomy', 'confidence']]

    # Save the merged data to a new file
    output_path = f"{output_id}"
    output_data.to_csv(output_path, sep='\t', index_label='#OTUID')


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python merge_taxonomy_abundance.py <table_path> <taxonomy_path> <output_id>")
        sys.exit(1)

    table_path = sys.argv[1]
    taxonomy_path = sys.argv[2]
    output_id = sys.argv[3]

    merge_taxonomy_abundance(table_path, taxonomy_path, output_id)





