import sys
import pysam
import os

def extract_info_from_sam(input_sam, min_ident, min_length):
    reads_data = []
    with pysam.AlignmentFile(input_sam, "r") as samfile:
        for read in samfile.fetch(until_eof=True):
            if read.has_tag("AS"):
                alignment_score = read.get_tag("AS")
                read_length = read.query_length  # Correctly extract sequence length
                if read_length >= min_length:  # Filter by minimum length
                    ident = round((alignment_score / 2) / read_length, 5)  # Calculate identity to 5 decimal places
                    # Check if the read passes the identity filter
                    if ident >= min_ident:
                        silva_ref = read.reference_name.split('.')[0] + '.' + read.reference_name.split('.')[1]
                        reads_data.append((read.query_name, silva_ref, alignment_score, read_length, ident))
    print(f"Extracted {len(reads_data)} reads passing length and identity filters")
    return reads_data

def calculate_coverage(reads_data, min_coverage):
    coverage_dict = {}
    for _, silva_ref, _, _, _ in reads_data:
        if silva_ref in coverage_dict:
            coverage_dict[silva_ref] += 1
        else:
            coverage_dict[silva_ref] = 1
    
    filtered_refs = {ref for ref, count in coverage_dict.items() if count >= min_coverage}
    print(f"Calculated coverage for {len(coverage_dict)} references; {len(filtered_refs)} references pass coverage filter")
    return filtered_refs

def write_filtered_output(input_sam, reads_data, valid_refs, output_path, output_format):
    output_file = f"{output_path}.{output_format}"
    with pysam.AlignmentFile(input_sam, "r") as samfile, open(output_file, "w") as out:
        written_reads = 0
        for read in samfile.fetch(until_eof=True):
            read_name = read.query_name
            silva_ref = read.reference_name.split('.')[0] + '.' + read.reference_name.split('.')[1]
            if read_name in [r[0] for r in reads_data if r[1] in valid_refs]:
                if output_format == "fastq":
                    out.write(f"@{read_name}\n{read.query_sequence}\n+\n{read.qual}\n")
                elif output_format == "fasta":
                    out.write(f">{read_name}\n{read.query_sequence}\n")
                written_reads += 1
    print(f"Wrote {written_reads} reads to {output_format.upper()} file: {output_file}")

def process_sam(input_sam, min_coverage, min_ident, min_length, output_sam, output_tsv, output_coverage_tsv, output_path, output_format):
    # Echo the input variables to the terminal
    print(f"[BIN REFINMENT PYTHON] - Minimum Coverage: {min_coverage}; Minimum Identity: {min_ident}; Minimum Length: {min_length}; Output Format: {output_format}")

    # Step 1: Extract information from SAM and filter by length and identity
    reads_data = extract_info_from_sam(input_sam, min_ident, min_length)

    # Step 2: Calculate coverage and filter by reference coverage
    valid_refs = calculate_coverage(reads_data, min_coverage)

    # Step 3: Write valid reads to the chosen format (FASTA or FASTQ)
    write_filtered_output(input_sam, reads_data, valid_refs, output_path, output_format)

    # Step 4: Optionally, write remaining reads back to a SAM file (keeping original SAM structure intact)
    with pysam.AlignmentFile(input_sam, "r") as samfile, pysam.AlignmentFile(output_sam, "wh", template=samfile) as outfile:
        for read in samfile:
            if read.query_name in [r[0] for r in reads_data if r[1] in valid_refs]:
                outfile.write(read)

    # Step 5: Write the filtered information to the TSVs
    with open(output_tsv, "w") as tsv_file:
        tsv_file.write("AmpliconName\tSilvaRef\tLength\tAlignmentScore\tIdent\n")
        for read_name, silva_ref, alignment_score, read_length, ident in reads_data:
            if silva_ref in valid_refs:
                tsv_file.write(f"{read_name}\t{silva_ref}\t{read_length}\t{alignment_score}\t{ident:.5f}\n")

    with open(output_coverage_tsv, "w") as coverage_file:
        for ref_name in valid_refs:
            coverage_file.write(f"{ref_name}\t{len([r for r in reads_data if r[1] == ref_name])}\n")

def main():
    if len(sys.argv) != 10:
        print("Usage: python <script> <input_sam> <min_coverage> <min_ident> <min_length> <output_sam> <output_tsv> <output_coverage_tsv> <output_path> <output_format>")
        sys.exit(1)

    input_sam = sys.argv[1]
    min_coverage = int(sys.argv[2])
    min_ident = float(sys.argv[3])
    min_length = int(sys.argv[4])
    output_sam = sys.argv[5]
    output_tsv = sys.argv[6]
    output_coverage_tsv = sys.argv[7]
    output_path = sys.argv[8]
    output_format = sys.argv[9]  # "fasta" or "fastq"

    process_sam(input_sam, min_coverage, min_ident, min_length, output_sam, output_tsv, output_coverage_tsv, output_path, output_format)

if __name__ == "__main__":
    main()
