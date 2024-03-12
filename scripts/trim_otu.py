import pandas as pd
import sys

def remove_first_column_and_save(input_file, output_file):
    # Load the TSV file. Assuming no header row for simplicity; adjust as needed.
    # If your file does have headers, change header=None to header=0.
    df = pd.read_csv(input_file, sep='\t', header=None, low_memory=False)

    # Drop the first column (column at index 0)
    df_modified = df.drop(df.columns[0], axis=1)

    # Save the modified dataframe to a new TSV file
    df_modified.to_csv(output_file, sep='\t', index=False, header=False)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python remove_first_column.py <input_file> <output_file>", file=sys.stderr)
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]

    remove_first_column_and_save(input_file, output_file)

