#!/usr/bin/env python3

import sys
import csv
from collections import defaultdict


def _trim_to_species(tax_path: str) -> str:
    """
    Given a semicolon-delimited taxonomic lineage, truncate the final element
    to just "Genus species", dropping any strain/isolate designations.

    Example
    -------
    '...;Lactobacillus fermentum ATCC 14931'  →
    '...;Lactobacillus fermentum'
    """
    parts = tax_path.split(';')
    if not parts:                        # empty string guard
        return tax_path
    last = parts[-1].strip()
    tokens = last.split()
    if len(tokens) >= 2:                 # keep only first two tokens
        parts[-1] = ' '.join(tokens[:2])
    else:                                # leave untouched if genus/species not clear
        parts[-1] = last
    return ';'.join(parts)


def extract_taxonomic_path(stitle: str) -> str:
    """
    Extract the taxonomic path that begins with one of the domain markers
    ('Bacteria;', 'Archaea;', or 'Eukaryota;') inside *stitle*.
    Returns 'Unknown' if no marker is found.
    """
    start_markers = ('Bacteria;', 'Archaea;', 'Eukaryota;')
    for marker in start_markers:
        pos = stitle.find(marker)
        if pos != -1:
            return stitle[pos:].strip()
    return "Unknown"


def process_blast_out(input_file: str, output_file: str) -> None:
    """
    Read the tab-separated BLAST output, collapse strain variants to the
    species level, count each unique taxonomic path, and write the results
    (taxonomy<TAB>abundance) to *output_file*, sorted by abundance.
    """
    taxonomy_counts: defaultdict[str, int] = defaultdict(int)

    with open(input_file, newline='') as infile:
        reader = csv.reader(infile, delimiter='\t')
        for row in reader:
            if len(row) < 13:
                continue                          # skip incomplete lines
            stitle = row[12]                      # 13th column (0-based index 12)
            raw_path = extract_taxonomic_path(stitle)
            cleaned_path = _trim_to_species(raw_path)
            taxonomy_counts[cleaned_path] += 1

    with open(output_file, 'w', newline='') as outfile:
        writer = csv.writer(outfile, delimiter='\t')
        writer.writerow(['taxonomy', 'abundance'])
        for path, count in sorted(taxonomy_counts.items(),
                                  key=lambda x: x[1],
                                  reverse=True):
            writer.writerow([path, count])


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.stderr.write("Usage: python script.py <input_file> <output_file>\n")
        sys.exit(1)

    process_blast_out(sys.argv[1], sys.argv[2])
