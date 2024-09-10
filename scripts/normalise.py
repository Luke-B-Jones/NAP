import pandas as pd
import sys

def normalize_data(input_file, scaling_factor, output_file, log_file, total_abundance):
    try:
        # Read the input TSV file
        data = pd.read_csv(input_file, sep='\t')
        
        # Check if the 'abundance' column exists
        if 'abundance' not in data.columns:
            raise ValueError("Column 'abundance' does not exist in the input file.")
        
        # Use the provided total_abundance instead of calculating from the column
        total_abundance = float(total_abundance)

        # Normalize the data
        data['abundance'] = (data['abundance'] / total_abundance) * float(scaling_factor)
        
        # Save the normalized data to the output file
        data.to_csv(output_file, sep='\t', index=False)
        
        # Verify the result by checking if the pre-normalization total equals post-normalization total scaled back
        post_normalization_sum = (data['abundance'] * (total_abundance / float(scaling_factor))).sum()
        
        # Log the outcome
        with open(log_file, 'a') as log:
            if abs(total_abundance - post_normalization_sum) < 1e-6:  # Consider floating-point precision
                log.write(f"Normalization successful. Pre-normalization sum: {total_abundance}, Post-normalization corrected sum: {post_normalization_sum}\n")
                return True
            else:
                log.write(f"Normalization check failed. Pre-normalization sum: {total_abundance}, Post-normalization corrected sum: {post_normalization_sum}\n")
                return False

    except Exception as e:
        # Log any errors that occur
        with open(log_file, 'a') as log:
            log.write(f"Error processing file: {str(e)}\n")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 6:
        print("Usage: python normalise.py <input_file> <scaling_factor> <output_file> <log_file> <total_abundance>")
        sys.exit(1)

    _, input_file, scaling_factor, output_file, log_file, total_abundance = sys.argv
    normalize_data(input_file, scaling_factor, output_file, log_file, total_abundance)
