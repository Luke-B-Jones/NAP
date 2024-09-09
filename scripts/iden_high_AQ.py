import sys

def calculate_identity(as_score, read_length):
    """Calculate identity as (AS:i / 2) / read length."""
    return (as_score / 2) / read_length

def process_sam_file(sam_file, fastq_output, identity_threshold=0.70, dup_identity_threshold=0.95):
    """Process SAM file and output to FASTQ if identity threshold is met, handle duplicates."""
    reads = {}
    
    with open(sam_file, 'r') as infile:
        for line in infile:
            if line.startswith('@'):
                continue
            
            fields = line.strip().split('\t')
            read_id = fields[0]
            seq = fields[9]
            qual = fields[10]
            as_score = None
            
            for field in fields:
                if field.startswith('AS:i:'):
                    as_score = int(field.split(':')[2])
                    break
            
            if as_score is None or not seq or not qual:
                continue
            
            read_length = len(seq)
            identity = calculate_identity(as_score, read_length)
            
            if read_id in reads:
                reads[read_id].append((seq, qual, identity))
            else:
                reads[read_id] = [(seq, qual, identity)]
    
    with open(fastq_output, 'w') as outfile:
        for read_id, entries in reads.items():
            if len(entries) > 1:  # Handling duplicates
                sorted_entries = sorted(entries, key=lambda x: x[2], reverse=True)
                best_entries = [entry for entry in sorted_entries if entry[2] >= dup_identity_threshold]
                if not best_entries:
                    best_entries = [sorted_entries[0]]  # None meet higher threshold; take the best available
            else:
                best_entries = [entry for entry in entries if entry[2] >= identity_threshold]
            
            # Write to FASTQ with modified headers if necessary
            for idx, (seq, qual, _) in enumerate(best_entries):
                suffix = '' if len(best_entries) == 1 else f'.{chr(97 + idx)}'  # .a, .b, .c, etc.
                outfile.write(f'@{read_id}{suffix}\n')
                outfile.write(f'{seq}\n')
                outfile.write('+\n')
                outfile.write(f'{qual}\n')

if __name__ == "__main__":
    sam_file = sys.argv[1]
    fastq_output = sys.argv[2]
    process_sam_file(sam_file, fastq_output)
