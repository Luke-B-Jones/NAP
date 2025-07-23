import sys
from Bio import SeqIO

def usage():
    print("Usage: python script.py <input.out> <input.fasta> <output.fasta>")
    print("Ensure the .out file has sequence names in the first column and taxonomic paths in the last column.")
    sys.exit(1)

def main():
    if len(sys.argv) != 4:
        usage()

    out_file = sys.argv[1]
    fasta_file = sys.argv[2]
    output_file = sys.argv[3]

    try:
        # Load the .out file and store sequences with the correct format
        sequences = {}
        with open(out_file, 'r') as f:
            for line in f:
                parts = line.strip().split('\t')
                if len(parts) < 13:  # Ensure there are enough parts
                    continue
                sequence_name = parts[0]  # qseqid is in the first column
                taxonomic_info = parts[-1]  # The combined ID and taxonomic path

                # Remove the reference ID (both from the second column and start of the taxonomic path)
                ref_id = parts[1]  # Reference ID in the second column
                taxonomic_path = taxonomic_info.replace(ref_id, '').strip()

                # Store the sequence name and cleaned taxonomic path
                sequences[sequence_name] = taxonomic_path
        
        print(f"Found {len(sequences)} sequences with valid taxonomic paths.")

        if not sequences:
            print("No sequences found with the required taxonomic paths (Bacteria;, Archaea;, Eukaryota;).")
            sys.exit(1)

        # Parse the FASTA file and write the matching sequences to the output file
        with open(output_file, 'w') as output_handle:
            count = 0
            for record in SeqIO.parse(fasta_file, "fasta"):
                if record.id in sequences:
                    # Replace hyphens in the record ID with underscores
                    cleaned_id = record.id.replace('-', '_')

                    # Write the sequence in annotated FASTA format with only the cleaned ID and the taxonomic path
                    output_handle.write(f">{cleaned_id} {sequences[record.id]}\n")
                    output_handle.write(f"{str(record.seq)}\n")
                    count += 1

        print(f"Written {count} sequences to the output file.")

    except FileNotFoundError as e:
        print(f"Error: {str(e)}")
        sys.exit(1)
    except Exception as e:
        print(f"An unexpected error occurred: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    main()
