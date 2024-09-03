import sys
from Bio import SeqIO
from Bio.Seq import Seq
from Bio.Data import IUPACData
from concurrent.futures import ProcessPoolExecutor, as_completed
import multiprocessing

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

    # Initialize position variable
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


def process_sequence(record, primers_515Y, primers_926R, range_515Y, range_926R):
    sequence = str(record.seq)
    sequence = replace_uracil_with_thymine(sequence)
    
    if sequence is None:
        return record  # Return untrimmed if there's an issue with the sequence

    # Find the earliest 515Y primer hit within the specified range
    start_pos = find_best_primer_hit(sequence, primers_515Y, range_515Y[0], range_515Y[1], find_earliest=True)
    
    if start_pos != -1:
        # Trim sequence before the best 515Y primer hit
        sequence = sequence[start_pos:]
        
        # Adjust the range for 926R search since sequence has been trimmed
        range_926R_adjusted = (range_926R[0] - start_pos, range_926R[1] - start_pos)
        
        # Find the latest 926R primer hit within the adjusted range
        end_pos = find_best_primer_hit(sequence, primers_926R, range_926R_adjusted[0], range_926R_adjusted[1], find_earliest=False)
        
        if end_pos != -1:
            # Trim sequence after the best 926R primer hit
            trimmed_seq = sequence[:end_pos + len(primers_926R[0])]
            
            # Check if the trimmed sequence is at least 325bp long
            if len(trimmed_seq) >= 325:
                record.seq = Seq(trimmed_seq)
                return record
    
    # If trimming fails, return the original untrimmed sequence
    return record


def update_progress(total_count, trimmed_count, total_records):
    percent_done = (total_count / total_records) * 100
    print(f"Processed {total_count} sequences, {trimmed_count} trimmed ({percent_done:.2f}% done)", end='\r')

def trim_sequences(input_fasta, output_fasta, primers_515Y, primers_926R, range_515Y, range_926R, processes, batch_size=100):
    records = list(SeqIO.parse(input_fasta, "fasta"))
    total_records = len(records)
    trimmed_count = 0
    total_count = 0

    with open(output_fasta, "w") as output_handle:
        with ProcessPoolExecutor(max_workers=processes) as executor:
            futures = []
            for record in records:
                futures.append(executor.submit(process_sequence, record, primers_515Y, primers_926R, range_515Y, range_926R))
                
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
    if len(sys.argv) != 4:
        print("Usage: python script.py <input_fasta> <output_fasta> <processes>")
        sys.exit(1)

    input_fasta = sys.argv[1]
    output_fasta = sys.argv[2]
    processes = int(sys.argv[3])

    # Define primers
    primers_515Y = [
        "GTGYCAGCMGCCGCGGTAA",
    ]

    primers_926R = [
        "CCGYCAATTYMTTTRAGTTT",
    ]

    # Define the range for each primer search
    range_515Y = (300, 800)    # Search for 515Y primers between 300-800bp
    range_926R = (650, 1500)   # Search for 926R primers between 650-1400bp

    # Run the trimming process
    trimmed_count, untrimmed_count = trim_sequences(input_fasta, output_fasta, primers_515Y, primers_926R, range_515Y, range_926R, processes)

    # Output the number of successfully trimmed and untrimmed sequences
    print(f"Successfully trimmed sequences: {trimmed_count}")
    print(f"Sequences left untrimmed: {untrimmed_count}")


