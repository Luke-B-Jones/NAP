import sys
from Bio import SeqIO
from concurrent.futures import ProcessPoolExecutor
from itertools import islice

def process_chunk(chunk, non_chimeric_ids):
    return [record for record in chunk if record.id in non_chimeric_ids]

def filter_reads(fasta_file, fastq_file, output_file, num_threads, chunk_size):
    # Read non-chimeric read IDs from the FASTA file
    with open(fasta_file, 'r') as fasta:
        non_chimeric_ids = {record.id for record in SeqIO.parse(fasta, 'fasta')}

    # Estimate total number of reads in FASTQ
    total_reads = sum(1 for _ in SeqIO.parse(open(fastq_file), 'fastq'))
    print_interval = total_reads // 10  # Calculate the interval for 10% of total reads
    processed_count = 0
    non_chimeric_count = 0
    filtered_reads = []

    with open(fastq_file, 'r') as fastq:
        record_iter = SeqIO.parse(fastq, 'fastq')
        # Use multiprocessing to filter reads
        with ProcessPoolExecutor(max_workers=num_threads) as executor:
            for result in executor.map(process_chunk, iter(lambda: list(islice(record_iter, int(chunk_size))), []), [non_chimeric_ids]*100000):
                count = len(result)
                non_chimeric_count += count
                processed_count += int(chunk_size)  # Update processed count by the chunk size
                filtered_reads.extend(result)
                # Check progress to print every 10%
                if processed_count >= print_interval:
                    percent_complete = (processed_count / total_reads) * 100
                    percent_non_chimeric = (non_chimeric_count / processed_count) * 100
                    print(f"{percent_complete:.2f}% total completed, {percent_non_chimeric:.2f}% non chimeric")
                    print_interval += total_reads // 10  # Update the next threshold for 10% interval

    # Write filtered reads to a new FASTQ file
    with open(output_file, 'w') as output:
        SeqIO.write(filtered_reads, output, 'fastq')

    print(f"Filtered {len(filtered_reads)} reads from {fastq_file} to {output_file}")

if __name__ == "__main__":
    if len(sys.argv) < 6:
        print("Usage: python script.py <nonchimeric.fasta> <input.fastq> <filtered_nonchimeric.fastq> <num_threads> <chunk_size>")
        sys.exit(1)

    fasta_file = sys.argv[1]
    fastq_file = sys.argv[2]
    output_file = sys.argv[3]
    num_threads = int(sys.argv[4])
    chunk_size = sys.argv[5]
    filter_reads(fasta_file, fastq_file, output_file, num_threads, chunk_size)
