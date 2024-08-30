import sys
import csv
from collections import defaultdict

def extract_taxonomic_path(stitle):
    """
    Extracts the taxonomic path starting from 'Bacteria;', 'Archaea;', or 'Eukaryota;'
    within the stitle field. Returns the path or "Unknown" if none is found.
    """
    start_markers = ['Bacteria;', 'Archaea;', 'Eukaryota;']
    for marker in start_markers:
        marker_pos = stitle.find(marker)
        if marker_pos != -1:
            return stitle[marker_pos:].strip()
    return "Unknown"

def process_blast_out(input_file, output_file):
    """
    Processes a BLASTN .out file to count the occurrences of each unique taxonomic path.
    Writes the counts to an output file with columns for taxonomic path and abundance,
    ensuring headers are in lowercase.
    """
    taxonomy_counts = defaultdict(int)

    with open(input_file, 'r') as infile:
        reader = csv.reader(infile, delimiter='\t')
        for row in reader:
            if len(row) < 13:
                continue  # Skip rows that do not have enough columns
            stitle = row[12]  # stitle is expected to be in the 13th column (0-based index 12)
            taxonomic_path = extract_taxonomic_path(stitle)
            taxonomy_counts[taxonomic_path] += 1

    with open(output_file, 'w', newline='') as outfile:
        writer = csv.writer(outfile, delimiter='\t')
        writer.writerow(['taxonomy', 'abundance'])  # Headers in lowercase
        for path, count in sorted(taxonomy_counts.items(), key=lambda item: item[1], reverse=True):
            writer.writerow([path, count])

if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.stderr.write("Usage: python script.py <input_file> <output_file>\n")
        sys.exit(1)

    input_file, output_file = sys.argv[1], sys.argv[2]
    process_blast_out(input_file, output_file)
