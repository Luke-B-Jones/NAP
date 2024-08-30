import sys
from collections import defaultdict

def parse_fasta(input_fasta):
    total_counts = defaultdict(int)
    uncultured_counts = defaultdict(int)
    sequences = []

    with open(input_fasta, 'r') as infile:
        header = None
        sequence = None
        for line in infile:
            if line.startswith('>'):
                if header and sequence:
                    sequences.append((header, sequence))
                
                header = line.strip()
                sequence = ""

                # Extract the order;genus identifier
                last_semicolon_index = header.rfind(';')
                second_last_semicolon_index = header.rfind(';', 0, last_semicolon_index)

                order_genus = header[second_last_semicolon_index + 1:last_semicolon_index].strip() + ";" + header[last_semicolon_index + 1:].strip().split()[0]
                
                # Count total occurrences of this order;genus
                total_counts[order_genus] += 1
                
                # Count uncultured occurrences
                if "uncultured" in header.lower():
                    uncultured_counts[order_genus] += 1

            else:
                sequence += line.strip()

        # Add the last sequence
        if header and sequence:
            sequences.append((header, sequence))

    return total_counts, uncultured_counts, sequences

def filter_fasta(sequences, species_threshold, proportion_threshold, output_fasta, total_counts, uncultured_counts):
    with open(output_fasta, 'w') as outfile:
        for header, sequence in sequences:
            # Extract the order;genus identifier
            last_semicolon_index = header.rfind(';')
            second_last_semicolon_index = header.rfind(';', 0, last_semicolon_index)
            order_genus = header[second_last_semicolon_index + 1:last_semicolon_index].strip() + ";" + header[last_semicolon_index + 1:].strip().split()[0]

            total_entries = total_counts[order_genus]
            uncultured_entries = uncultured_counts[order_genus]
            cultured_proportion = (total_entries - uncultured_entries) / total_entries if total_entries > 0 else 0

            # Determine if the uncultured entries for this order;genus should be removed
            if uncultured_entries > 0 and total_entries > species_threshold and cultured_proportion < proportion_threshold:
                if "uncultured" in header.lower():
                    continue  # Skip this uncultured sequence

            # Write the sequence to the output file
            outfile.write(f"{header}\n{sequence}\n")

def main():
    if len(sys.argv) != 5:
        print("Usage: python remove_uncultured.py <input_fasta> <species_threshold> <proportion_threshold> <output_fasta>", file=sys.stderr)
        sys.exit(1)

    input_fasta = sys.argv[1]
    try:
        species_threshold = int(sys.argv[2])
        proportion_threshold = float(sys.argv[3])
    except ValueError:
        print("Error: <species_threshold> must be an integer and <proportion_threshold> must be a float.", file=sys.stderr)
        sys.exit(1)
    output_fasta = sys.argv[4]

    # Parse the FASTA file and count sequences
    total_counts, uncultured_counts, sequences = parse_fasta(input_fasta)

    # Filter and write the sequences to the output file
    filter_fasta(sequences, species_threshold, proportion_threshold, output_fasta, total_counts, uncultured_counts)

if __name__ == "__main__":
    main()