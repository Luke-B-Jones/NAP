import pandas as pd
import sys

def decontaminate(input_file, blank_file, decontamination_factor):
    # Load the input and blank data
    input_data = pd.read_csv(input_file, sep='\t')
    blank_data = pd.read_csv(blank_file, sep='\t')

    # Create a dictionary from the blank data for quick lookup
    blank_dict = {row['taxonomy']: row['abundance'] for index, row in blank_data.iterrows()}

    # Process each entry in the input data
    for index, row in input_data.iterrows():
        tax = row['taxonomy']
        if tax in blank_dict:
            # Calculate the new abundance
            new_abundance = row['abundance'] - blank_dict[tax] * decontamination_factor
            if new_abundance <= 0:
                # Remove entry if abundance is zero or negative
                input_data.drop(index, inplace=True)
            else:
                # Update the abundance
                input_data.at[index, 'abundance'] = new_abundance

    # Write the updated data back to the input file
    input_data.to_csv(input_file, sep='\t', index=False)

if __name__ == "__main__":
    # Read arguments from the command line
    script, input_tsv, blank_microbiome, decontamination_factor = sys.argv
    # Convert decontamination factor to float
    decontamination_factor = float(decontamination_factor)
    # Call the function with provided arguments
    decontaminate(input_tsv, blank_microbiome, decontamination_factor)
