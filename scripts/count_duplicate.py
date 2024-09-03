from Bio import SeqIO
import sys

def get_fasta_headers(fasta_file):
    """Return a set of headers from a FASTA file."""
    headers = set()
    with open(fasta_file, "r") as file:
        for record in SeqIO.parse(file, "fasta"):
            headers.add(record.id)
    return headers

def count_shared_headers(fasta1, fasta2):
    """Count how many headers are shared between two FASTA files."""
    headers1 = get_fasta_headers(fasta1)
    headers2 = get_fasta_headers(fasta2)

    shared_headers = headers1.intersection(headers2)
    return len(shared_headers)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python count_shared_headers.py <fasta1> <fasta2>")
        sys.exit(1)

    fasta1 = sys.argv[1]
    fasta2 = sys.argv[2]

    shared_count = count_shared_headers(fasta1, fasta2)
    print(shared_count)  # Output the count directly
