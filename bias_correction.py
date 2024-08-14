import pandas as pd
import sys

def process_file(input_file, bias_factor, output_file, log_file):
    try:
        # Read the input TSV file
        data = pd.read_csv(input_file, sep='\t')
        
        # Check if the 'abundance' column exists
        if 'abundance' not in data.columns:
            raise ValueError("Column 'abundance' does not exist in the input file.")
        
        # Convert bias_factor to float if it's not and handle possible conversion errors
        try:
            bias_factor = float(bias_factor)
        except ValueError:
            raise ValueError("Bias factor must be a numeric value.")
        
        # Apply the bias correction
        original_sum = data['abundance'].sum()
        data['abundance'] = data['abundance'] / bias_factor
        corrected_sum = data['abundance'].sum()
        
        # Save the corrected data to the output file
        data.to_csv(output_file, sep='\t', index=False)
        
        # Verify the result by comparing sums
        if not abs((original_sum / bias_factor) - corrected_sum) < 1e-6:
            raise ValueError("The corrected sum does not match the expected value.")
        
        # Log success
        with open(log_file, 'a') as log:
            log.write(f"File processed successfully. Original sum: {original_sum}, Corrected sum: {corrected_sum}\n")
            return True
    except Exception as e:
        # Log any errors that occur
        with open(log_file, 'a') as log:
            log.write(f"Error processing file: {str(e)}\n")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 5:
        print("Usage: python bias_correction.py <input_file> <bias_factor> <output_file> <log_file>")
        sys.exit(1)

    _, input_file, bias_factor, output_file, log_file = sys.argv
    process_file(input_file, bias_factor, output_file, log_file)


