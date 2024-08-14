import pandas as pd
import sys

def normalize_data(input_file, scaling_factor, output_file, log_file):
    try:
        # Read the input TSV file
        data = pd.read_csv(input_file, sep='\t')
        
        # Check if the 'abundance' column exists
        if 'abundance' not in data.columns:
            raise ValueError("Column 'abundance' does not exist in the input file.")
        
        # Calculate the total count of 'abundance'
        total_count = data['abundance'].sum()
        
        # Normalize the data
        data['abundance'] = (data['abundance'] / total_count) * float(scaling_factor)
        
        # Save the normalized data to the output file
        data.to_csv(output_file, sep='\t', index=False)
        
        # Verify the result by checking if the pre-normalization total equals post-normalization total scaled back
        post_normalization_sum = (data['abundance'] * (total_count / float(scaling_factor))).sum()
        
        # Log the outcome
        with open(log_file, 'a') as log:
            if abs(total_count - post_normalization_sum) < 1e-6:  # Consider floating-point precision
                log.write(f"Normalization successful. Pre-normalization sum: {total_count}, Post-normalization corrected sum: {post_normalization_sum}\n")
                return True
            else:
                log.write(f"Normalization check failed. Pre-normalization sum: {total_count}, Post-normalization corrected sum: {post_normalization_sum}\n")
                return False

    except Exception as e:
        # Log any errors that occur
        with open(log_file, 'a') as log:
            log.write(f"Error processing file: {str(e)}\n")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 5:
        print("Usage: python normalise.py <input_file> <scaling_factor> <output_file> <log_file>")
        sys.exit(1)

    _, input_file, scaling_factor, output_file, log_file = sys.argv
    normalize_data(input_file, scaling_factor, output_file, log_file)


