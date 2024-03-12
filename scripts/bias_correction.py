import pandas as pd
import sys

def bias_correction(file_path, bias_factor, output_stats_file):
    # Load the table, assuming the first row after the header has been adjusted by AWK
    data = pd.read_csv(file_path, sep='\t', header=0)

    # Check if the 'abundance' column exists and is numeric
    if 'abundance' in data.columns:
        # Convert the 'abundance' column to float, if not already
        data['abundance'] = pd.to_numeric(data['abundance'], errors='coerce')

        # Sum the original abundances
        original_sum = data['abundance'].sum()

        # Apply bias correction
        data['abundance'] = data['abundance'] / float(bias_factor)

        # Sum the corrected abundances
        corrected_sum = data['abundance'].sum()

        # Calculate percentage retained
        percentage_retained = (corrected_sum * float(bias_factor) / original_sum) * 100

        # Write the modified data back to the original file
        data.to_csv(file_path, sep='\t', index=False)

        # Write the percentage retained to a file
        with open(output_stats_file, 'w') as f:
            f.write(f"{percentage_retained:.6f}%\n")
    else:
        print(f"Column 'abundance' not found in {file_path}")

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python bias_correction.py <file_path> <bias_factor> <output_stats_file>")
        sys.exit(1)

    file_path = sys.argv[1]
    bias_factor = sys.argv[2]
    output_stats_file = sys.argv[3]

    bias_correction(file_path, bias_factor, output_stats_file)



