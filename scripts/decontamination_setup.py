import sys
import os
import pandas as pd
from datetime import datetime

def validate_and_load_tsv(file_paths):
    data_frames = []
    for file_path in file_paths:
        # Check if file exists and has content
        if os.path.exists(file_path) and os.path.getsize(file_path) > 0:
            try:
                # Load TSV into a pandas DataFrame
                df = pd.read_csv(file_path, sep="\t")
                # Check if required columns are present
                if 'taxonomy' not in df.columns or 'abundance' not in df.columns:
                    print(f"Skipping {file_path}, missing required 'taxonomy' or 'abundance' column.", file=sys.stderr)
                    continue
                data_frames.append(df)
            except Exception as e:
                print(f"Error reading {file_path}: {e}", file=sys.stderr)
        else:
            print(f"File {file_path} is either missing or empty.", file=sys.stderr)
    return data_frames

def process_and_average_abundance(data_frames):
    if not data_frames:
        print("No valid TSV files to process.", file=sys.stderr)
        return None
    
    # Concatenate all DataFrames and fill missing values with zero
    concatenated = pd.concat(data_frames).fillna(0)
    
    # Group by 'taxonomy' and compute the average abundance and prevalence
    # Prevalence is the proportion of files where the species was present (non-zero abundance)
    def calculate_prevalence(series):
        return (series > 0).sum() / len(data_frames)  # Prevalence as a fraction of the number of files
    
    result = concatenated.groupby('taxonomy', as_index=False).agg(
        abundance=('abundance', 'mean'),  # Calculate average abundance
        prevalence=('abundance', calculate_prevalence)  # Calculate prevalence
    )
    
    return result

def save_output(result):
    # Get current date and time for the filename
    timestamp = datetime.now().strftime("%d_%m_%Y-%H_%M_%S")
    output_filename = f"decontamination_{timestamp}.tsv"
    
    # Save to current working directory
    output_path = os.path.join(os.getcwd(), output_filename)
    result.to_csv(output_path, sep="\t", index=False)
    
    return output_path

if __name__ == "__main__":
    # Ensure that at least one file path is passed
    if len(sys.argv) < 2:
        print("Usage: python setup_decontamination.py path/to/tsv1 path/to/tsv2 ...", file=sys.stderr)
        sys.exit(1)
    
    # Get the file paths from command-line arguments (starting from the first argument)
    file_paths = sys.argv[1:]
    
    # Validate and load TSV files
    data_frames = validate_and_load_tsv(file_paths)
    
    # Process and average abundances, and calculate prevalence
    result = process_and_average_abundance(data_frames)
    
    # If result is valid, save the output file and print the absolute path
    if result is not None:
        output_path = save_output(result)
        print(f"{output_path}")
