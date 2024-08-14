import sys

def extract_read_names_from_fastq(fastq_file):
    read_names = set()
    try:
        with open(fastq_file, "r") as file:
            while True:
                header = file.readline().strip()
                sequence = file.readline().strip()
                plus = file.readline().strip()
                quality = file.readline().strip()
                if not header:
                    break
                read_name = header.split()[0][1:]  # Extract read name, removing the '@'
                read_names.add(read_name)
    except Exception as e:
        print(f"Error reading {fastq_file}: {e}")
        sys.exit(1)
    return read_names

def extract_silva_references(tsv_file, retained_reads):
    references = set()
    try:
        with open(tsv_file, "r") as file:
            next(file)  # Skip the header line
            for line in file:
                columns = line.strip().split("\t")
                if len(columns) > 1 and columns[0] in retained_reads:
                    silva_ref = columns[1]  # Assuming the second column contains the SILVA reference
                    references.add(silva_ref)
    except Exception as e:
        print(f"Error reading {tsv_file}: {e}")
        sys.exit(1)
    return references

def compare_bins(tsv_16s, fastq_16s, tsv_18s, fastq_18s):
    try:
        # Extract read names from FASTQ files
        retained_reads_16s = extract_read_names_from_fastq(fastq_16s)
        retained_reads_18s = extract_read_names_from_fastq(fastq_18s)
        
        # Extract SILVA references from TSV files, filtering by retained reads
        references_16s = extract_silva_references(tsv_16s, retained_reads_16s)
        references_18s = extract_silva_references(tsv_18s, retained_reads_18s)
        
        # Find the intersection of the two sets (shared references)
        shared_references = references_16s.intersection(references_18s)
        
        # Count unique references in each set
        unique_references_16s = len(references_16s)
        unique_references_18s = len(references_18s)
        
        # Return the counts as space-separated values
        print(f"{len(shared_references)} {unique_references_16s} {unique_references_18s}")
        
    except Exception as e:
        print(f"An error occurred: {e}")
        sys.exit(1)

def main():
    if len(sys.argv) != 5:
        print("Usage: python <script> <16s_tsv_file> <16s_fastq_file> <18s_tsv_file> <18s_fastq_file>")
        sys.exit(1)

    tsv_16s = sys.argv[1]
    fastq_16s = sys.argv[2]
    tsv_18s = sys.argv[3]
    fastq_18s = sys.argv[4]

    compare_bins(tsv_16s, fastq_16s, tsv_18s, fastq_18s)

if __name__ == "__main__":
    main()

