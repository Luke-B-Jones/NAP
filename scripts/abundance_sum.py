import pandas as pd
import sys

def calculate_abundances(ab_16s_path, ab_18s_path):
    # Load the data while ignoring potential non-numeric header rows
    data_16s = pd.read_csv(ab_16s_path, sep='\t', usecols=[1], dtype={1: 'float'}, skiprows=lambda x: x in [0, 1], header=None)
    data_18s = pd.read_csv(ab_18s_path, sep='\t', usecols=[1], dtype={1: 'float'}, skiprows=lambda x: x in [0, 1], header=None)
    
    # Calculate total abundances
    total_ab_16s = data_16s.sum().item()
    total_ab_18s = data_18s.sum().item()

    # Print total abundances to stdout to capture in Bash
    print(f"{total_ab_16s},{total_ab_18s}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python abundance_sum.py <ab_16s_path> <ab_18s_path>", file=sys.stderr)
        sys.exit(1)

    calculate_abundances(sys.argv[1], sys.argv[2])



