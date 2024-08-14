import sys
import csv
from collections import defaultdict

def extract_taxonomic_path(line):
    # Search for the start term (Kingdom) within the entire line
    kingdoms = ['Eukaryota;', 'Bacteria;', 'Archaea;']
    for kingdom in kingdoms:
        if kingdom in line:
            start_idx = line.index(kingdom)
            taxonomic_info = line[start_idx:]
            return taxonomic_info.strip()  # Return the full taxonomic path without modification
    return "Unknown"

def reduce_classification(input_file, output_file):
    abundance = defaultdict(int)
    total_rows = 0
    retained_count = 0
    unknown_count = 0

    # Open the BLAST output file
    with open(input_file, 'r') as infile:
        reader = csv.reader(infile, delimiter='\t')

        for row in reader:
            total_rows += 1
            try:
                # Convert the row into a single string (as each row is an entry from BLASTn)
                line = "\t".join(row)

                # Extract the taxonomic path based on the kingdom search
                taxonomic_path = extract_taxonomic_path(line)

                if taxonomic_path != "Unknown":
                    retained_count += 1
                else:
                    unknown_count += 1

                # Increment the count for this taxonomic path
                abundance[taxonomic_path] += 1

            except Exception as e:
                print(f"Error processing row: {row}")
                print(f"Exception: {e}")
                continue

    # Write the abundance data to a TSV file with 'abundance' column
    with open(output_file, 'w') as outfile:
        writer = csv.writer(outfile, delimiter='\t')
        writer.writerow(['Taxonomic Path', 'abundance'])  # Column name changed to 'abundance'

        for taxon, count in abundance.items():
            writer.writerow([taxon, count])

    # Calculate the percentage of retained and unknown rows
    if total_rows > 0:
        percentage_retained = (retained_count / total_rows) * 100
        percentage_unknown = (unknown_count / total_rows) * 100
    else:
        percentage_retained = 0
        percentage_unknown = 0

    print(f"{percentage_retained:.2f}% retained")
    print(f"{percentage_unknown:.2f}% unknown")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python reduce_classification_by_kingdom.py <input_file> <output_file>")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]

    reduce_classification(input_file, output_file)
