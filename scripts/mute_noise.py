import sys
import os
import gzip
import logging

def determine_phred_encoding(qual_str):
    """Determine whether the FASTQ file uses Phred+33 or Phred+64 encoding."""
    min_score = min([ord(char) for char in qual_str])
    if min_score >= 33 and min_score <= 73:
        return 33
    elif min_score >= 64 and min_score <= 104:
        return 64
    else:
        raise ValueError("Unrecognized Phred encoding.")

def process_fastq(fastq_path, threshold, output_path, log_path):
    # Set up logging
    logging.basicConfig(filename=log_path, level=logging.INFO)
    logging.info(f"Processing FASTQ file: {fastq_path}")

    # Input validation
    if not os.path.exists(fastq_path):
        logging.error(f"Input FASTQ file not found: {fastq_path}")
        sys.exit(1)
    if not (0 <= threshold <= 1):
        logging.error("Threshold must be a float between 0 and 1.")
        sys.exit(1)
    
    # Open FASTQ file and determine Phred encoding
    if fastq_path.endswith('.gz'):
        open_func = gzip.open
    else:
        open_func = open
    
    phred_offset = None
    with open_func(fastq_path, 'rt') as fastq_file:
        for i, line in enumerate(fastq_file):
            if i % 4 == 3:  # Quality score line
                phred_offset = determine_phred_encoding(line.strip())
                break

    if phred_offset is None:
        logging.error("Failed to determine Phred encoding.")
        sys.exit(1)
    
    logging.info(f"Determined Phred encoding: Phred+{phred_offset}")

    # Process FASTQ reads and tally Phred scores
    total_reads = 0
    total_bases = 0
    phred_tally = {i: 0 for i in range(0, 94)}  # Covering Phred 33-126 ASCII range

    with open_func(fastq_path, 'rt') as fastq_file, open(output_path, 'w') as out_file:
        while True:
            try:
                read_id = next(fastq_file).strip()
                sequence = next(fastq_file).strip()
                plus_line = next(fastq_file).strip()
                quality = next(fastq_file).strip()

                if len(sequence) != len(quality):
                    logging.error(f"Length mismatch in read: {read_id}")
                    continue

                total_reads += 1
                quality_scores = [ord(c) - phred_offset for c in quality]
                total_bases += len(quality_scores)
                
                # Tally Phred scores for all bases
                for score in quality_scores:
                    phred_tally[score] += 1

            except StopIteration:
                break
            except Exception as e:
                logging.error(f"Error processing read: {e}")
                break

    # Find Phred threshold after tallying all bases
    sorted_scores = sorted(phred_tally.keys(), reverse=True)
    cumulative_bases = 0
    selected_phred = 0
    for score in sorted_scores:
        cumulative_bases += phred_tally[score]
        if cumulative_bases / total_bases >= threshold:
            selected_phred = score
            break

    # Log the selected Phred score
    logging.info(f"Selected Phred score: {selected_phred}")

    # Second pass to apply N substitutions and output modified reads
    with open_func(fastq_path, 'rt') as fastq_file, open(output_path, 'w') as out_file:
        while True:
            try:
                read_id = next(fastq_file).strip()
                sequence = next(fastq_file).strip()
                plus_line = next(fastq_file).strip()
                quality = next(fastq_file).strip()

                if len(sequence) != len(quality):
                    logging.error(f"Length mismatch in read: {read_id}")
                    continue

                quality_scores = [ord(c) - phred_offset for c in quality]
                new_sequence = []
                new_quality = []
                average_phred = sum(quality_scores) / len(quality_scores)

                for base, score in zip(sequence, quality_scores):
                    if score >= selected_phred:
                        new_sequence.append(base)
                        new_quality.append(chr(score + phred_offset))
                    else:
                        new_sequence.append('N')
                        new_quality.append(chr(int(average_phred) + phred_offset))

                out_file.write(read_id + '\n')
                out_file.write(''.join(new_sequence) + '\n')
                out_file.write(plus_line + '\n')
                out_file.write(''.join(new_quality) + '\n')

            except StopIteration:
                break
            except Exception as e:
                logging.error(f"Error processing read: {e}")
                break

    # Log statistics
    logging.info(f"Total reads processed: {total_reads}")
    logging.info(f"Phred score tally: {phred_tally}")
    
    # Output selected Phred score for bash script
    print(selected_phred)
    
if __name__ == "__main__":
    if len(sys.argv) != 5:
        print("Usage: python script.py <input_fastq> <threshold> <output_fastq> <log_file>")
        sys.exit(1)
    
    input_fastq = sys.argv[1]
    threshold = float(sys.argv[2])
    output_fastq = sys.argv[3]
    log_file = sys.argv[4]
    
    process_fastq(input_fastq, threshold, output_fastq, log_file)
