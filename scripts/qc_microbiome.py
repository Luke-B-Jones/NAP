import pandas as pd
import sys

def sum_abundances_and_count_rows(files):
    total_abundance = 0
    total_rows = 0

    for file_path in files:
        try:
            # Skip the first row and assume the first column after skipping has abundance data
            data = pd.read_csv(file_path, sep='\t', header=None, usecols=[0], dtype={0: float}, skiprows=1)
            total_abundance += data.iloc[:, 0].sum()
            # Count rows with non-null abundance values
            total_rows += len(data[data.iloc[:, 0].notnull()])
        except Exception as e:
            print(f"Error processing file {file_path}: {e}", file=sys.stderr)
            continue

    return total_abundance, total_rows

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python sum_abundances_and_count_rows.py <file1> <file2> ...", file=sys.stderr)
        sys.exit(1)

    total_abundance, total_rows = sum_abundances_and_count_rows(sys.argv[1:])
    print(f"{total_abundance},{total_rows}")


