import sys
from Bio import SeqIO
from Bio.Seq import Seq
from Bio.Data import IUPACData
from concurrent.futures import ProcessPoolExecutor, as_completed

def reverse_complement(seq):
    """Generate the reverse complement of a DNA sequence."""
    return str(Seq(seq).reverse_complement())

def replace_uracil_with_thymine(sequence):
    """Replace all instances of 'U' with 'T' in the sequence."""
    return sequence.replace('U', 'T')

def iupac_match(base, primer_base):
    """Check if a nucleotide matches an IUPAC-encoded base, allowing for more mismatches."""
    iupac_dict = IUPACData.ambiguous_dna_values
    return base in iupac_dict[primer_base]

def find_best_primer_hit(sequence, primers, start_range, end_range, min_identity=0.75, find_earliest=True):
    best_hit_position = -1
    best_identity = 0.0

    # Only search within the specified range
    search_segment = sequence[start_range:end_range]

    # Add reverse complements of primers to the search list
    full_primers = primers + [reverse_complement(primer) for primer in primers]

    positions = []

    for primer in full_primers:
        for i in range(len(search_segment) - len(primer) + 1):
            segment = search_segment[i:i + len(primer)]
            
            # Calculate identity considering IUPAC codes
            matches = sum(iupac_match(base, primer_base) for base, primer_base in zip(segment, primer))
            identity = matches / len(primer)
            
            if identity >= min_identity:
                positions.append((start_range + i, identity))  # Adjust to global sequence position

    if positions:
        if find_earliest:
            # Find the earliest match (lowest position)
            best_hit_position, best_identity = min(positions, key=lambda x: x[0])
        else:
            # Find the latest match (highest position)
            best_hit_position, best_identity = max(positions, key=lambda x: x[0])

    return best_hit_position


def process_sequence(record, forward_primers, reverse_primers, forward_range, reverse_range, min_length):
    sequence = str(record.seq)
    sequence = replace_uracil_with_thymine(sequence)
    
    if sequence is None:
        return record  # Return untrimmed if there's an issue with the sequence

    # Find the earliest forward primer hit within the specified range
    start_pos = find_best_primer_hit(sequence, forward_primers, forward_range[0], forward_range[1], find_earliest=True)
    
    if start_pos != -1:
        # Trim sequence before the best forward primer hit
        sequence = sequence[start_pos:]
        
        # Adjust the range for reverse primer search since sequence has been trimmed
        reverse_range_adjusted = (reverse_range[0] - start_pos, reverse_range[1] - start_pos)
        
        # Find the latest reverse primer hit within the adjusted range
        end_pos = find_best_primer_hit(sequence, reverse_primers, reverse_range_adjusted[0], reverse_range_adjusted[1], find_earliest=False)
        
        if end_pos != -1:
            # Trim sequence after the best reverse primer hit
            trimmed_seq = sequence[:end_pos + len(reverse_primers[0])]
            
            # Check if the trimmed sequence meets the minimum length requirement
            if len(trimmed_seq) >= min_length:
                record.seq = Seq(trimmed_seq)
                return record
    
    # If trimming fails, return the original untrimmed sequence
    return record


def update_progress(total_count, trimmed_count, total_records):
    percent_done = (total_count / total_records) * 100
    print(f"Processed {total_count} sequences, {trimmed_count} trimmed ({percent_done:.2f}% done)", end='\r')

def trim_sequences(input_fasta, output_fasta, forward_primers, reverse_primers, forward_range, reverse_range, min_length, processes, batch_size=100):
    records = list(SeqIO.parse(input_fasta, "fasta"))
    total_records = len(records)
    trimmed_count = 0
    total_count = 0

    with open(output_fasta, "w") as output_handle:
        with ProcessPoolExecutor(max_workers=processes) as executor:
            futures = []
            for record in records:
                futures.append(executor.submit(process_sequence, record, forward_primers, reverse_primers, forward_range, reverse_range, min_length))
                
                # Process in batches to keep things moving
                if len(futures) >= batch_size:
                    for future in as_completed(futures):
                        result = future.result()
                        total_count += 1
                        if result and result.seq != record.seq:
                            SeqIO.write(result, output_handle, "fasta")
                            trimmed_count += 1
                        else:
                            SeqIO.write(record, output_handle, "fasta")  # Write untrimmed sequence
                    futures = []  # Clear completed batch
                
                if total_count % (batch_size * 10) == 0:  # Update progress less frequently
                    update_progress(total_count, trimmed_count, total_records)

            # Process any remaining futures
            for future in as_completed(futures):
                result = future.result()
                total_count += 1
                if result and result.seq != record.seq:
                    SeqIO.write(result, output_handle, "fasta")
                    trimmed_count += 1
                else:
                    SeqIO.write(record, output_handle, "fasta")  # Write untrimmed sequence

            # Final progress update
            update_progress(total_count, trimmed_count, total_records)
            print()  # Move to the next line after final update

    return trimmed_count, total_count - trimmed_count

if __name__ == "__main__":
    if len(sys.argv) != 9:
        print("Usage: python script.py <input_fasta> <output_fasta> <processes> <forward_primer> <reverse_primer> <forward_range> <reverse_range> <min_length>")
        sys.exit(1)

    input_fasta = sys.argv[1]
    output_fasta = sys.argv[2]
    processes = int(sys.argv[3])
    
    forward_primers = [sys.argv[4]]  # Forward primer sequence
    reverse_primers = [sys.argv[5]]  # Reverse primer sequence

    # Convert the passed ranges to integers
    forward_range = tuple(map(int, sys.argv[6].split('-')))
    reverse_range = tuple(map(int, sys.argv[7].split('-')))
    
    # Minimum sequence length
    min_length = int(sys.argv[8])

    # Run the trimming process
    trimmed_count, untrimmed_count = trim_sequences(input_fasta, output_fasta, forward_primers, reverse_primers, forward_range, reverse_range, min_length, processes)

    # Output the number of successfully trimmed and untrimmed sequences
    print(f"Successfully trimmed sequences: {trimmed_count}")
    print(f"Sequences left untrimmed: {untrimmed_count}")
