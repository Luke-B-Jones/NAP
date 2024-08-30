import sys
import re

def clean_fasta_headers(input_fasta, output_fasta):
    with open(input_fasta, 'r') as infile, open(output_fasta, 'w') as outfile:
        header = None
        sequence = None

        for line in infile:
            if line.startswith('>'):  # It's a header line
                # If there is a previous header and sequence, write them to the file
                if header and sequence:
                    outfile.write(header + '\n')
                    outfile.write(sequence + '\n')
                
                # Clean the header by removing content within parentheses
                header = re.sub(r'\s*\(.*?\)\s*', '', line.strip())
                sequence = ""  # Reset the sequence for the new header
            
            else:
                sequence += line.strip()  # Collect the sequence

        # Write the last header and sequence
        if header and sequence:
            outfile.write(header + '\n')
            outfile.write(sequence + '\n')

def main():
    if len(sys.argv) != 3:
        print("Usage: python script.py <input_fasta> <output_fasta>", file=sys.stderr)
        exit(1)

    input_fasta = sys.argv[1]
    output_fasta = sys.argv[2]
    
    clean_fasta_headers(input_fasta, output_fasta)

if __name__ == "__main__":
    main()
