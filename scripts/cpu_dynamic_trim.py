import sys
from Bio import SeqIO
from Bio.Seq import Seq
from Bio.Data import IUPACData
from concurrent.futures import ProcessPoolExecutor, as_completed

def reverse_complement(seq):
    return str(Seq(seq).reverse_complement())

def replace_uracil_with_thymine(sequence):
    return sequence.replace('U', 'T')

def iupac_match(base, primer_base):
    return base in IUPACData.ambiguous_dna_values[primer_base]

def find_primer_hits(sequence, primers, start, end, min_identity):
    """Return list of (position, identity, primer_length) for hits ≥ min_identity."""
    hits = []
    segment = sequence[start:end]
    all_primers = primers + [reverse_complement(p) for p in primers]
    for primer in all_primers:
        plen = len(primer)
        for i in range(len(segment) - plen + 1):
            subseq = segment[i:i+plen]
            matches = sum(iupac_match(b, pb) for b, pb in zip(subseq, primer))
            identity = matches / plen
            if identity >= min_identity:
                hits.append((start + i, identity, plen))
    return hits

def update_progress(processed, trimmed, total):
    percent = (processed / total) * 100 if total else 100
    print(f"Processed {processed} sequences, {trimmed} trimmed ({percent:.2f}% done)", end='\r')

def process_sequence(record, forward_primers, reverse_primers,
                     forward_range, reverse_range, min_length, min_identity):
    seq_str = replace_uracil_with_thymine(str(record.seq))
    seq_len = len(seq_str)
    if seq_len == 0:
        return record

    # Clamp user‐provided search windows to the actual sequence length
    fr0 = max(0, forward_range[0])
    fr1 = min(seq_len, forward_range[1])
    r0  = max(0, reverse_range[0])
    r1  = min(seq_len, reverse_range[1])

    # Find all forward/reverse hits
    fwd_hits = find_primer_hits(seq_str, forward_primers, fr0, fr1, min_identity)
    if not fwd_hits:
        return record
    rev_hits = find_primer_hits(seq_str, reverse_primers, r0, r1, min_identity)
    if not rev_hits:
        return record

    # Estimate the “expected” amplicon length from midpoint of the two search ranges
    f_mid = (forward_range[0] + forward_range[1]) / 2
    r_mid = (reverse_range[0] + reverse_range[1]) / 2
    avg_rev_len = sum(len(p) for p in reverse_primers) / len(reverse_primers)
    expected_len = (r_mid - f_mid) + avg_rev_len

    # Pick the primer-pair whose amplicon length is closest to expected_len,
    # tie‐breaking by the highest combined primer identity
    best_pair = None
    best_diff = None
    best_bonus = None
    for fpos, fident, flen in fwd_hits:
        for rpos, rident, rlen in rev_hits:
            if rpos + rlen <= fpos:
                continue
            amp_len = (rpos + rlen) - fpos
            diff = abs(amp_len - expected_len)
            bonus = fident + rident
            if (best_pair is None
                or diff < best_diff
                or (diff == best_diff and bonus > best_bonus)):
                best_pair = (fpos, flen, rpos, rlen)
                best_diff  = diff
                best_bonus = bonus

    if best_pair is None:
        return record

    start_pos, f_len, end_pos, r_len = best_pair
    trimmed_seq = seq_str[start_pos:end_pos + r_len]
    if len(trimmed_seq) < min_length:
        return record

    record.seq = Seq(trimmed_seq)
    return record

def trim_sequences(input_fasta, output_fasta, forward_primers, reverse_primers,
                   forward_range, reverse_range, min_length, processes,
                   min_identity=0.75, batch_size=100):
    records = list(SeqIO.parse(input_fasta, "fasta"))
    total_records = len(records)
    processed = 0
    trimmed_count = 0

    with open(output_fasta, "w") as out_handle:
        future_to_record = {}
        pending = []
        with ProcessPoolExecutor(max_workers=processes) as executor:
            for record in records:
                fut = executor.submit(
                    process_sequence,
                    record,
                    forward_primers,
                    reverse_primers,
                    forward_range,
                    reverse_range,
                    min_length,
                    min_identity
                )
                future_to_record[fut] = record
                pending.append(fut)
                if len(pending) >= batch_size:
                    for f in as_completed(pending):
                        orig = future_to_record.pop(f)
                        result = f.result()
                        processed += 1
                        if result.seq != orig.seq:
                            trimmed_count += 1
                        SeqIO.write(result, out_handle, "fasta")
                    pending = []
                    if processed % (batch_size * 10) == 0:
                        update_progress(processed, trimmed_count, total_records)
            # process any remaining
            for f in as_completed(pending):
                orig = future_to_record.pop(f)
                result = f.result()
                processed += 1
                if result.seq != orig.seq:
                    trimmed_count += 1
                SeqIO.write(result, out_handle, "fasta")
            update_progress(processed, trimmed_count, total_records)
            print()

    return trimmed_count, total_records - trimmed_count

if __name__ == "__main__":
    if len(sys.argv) != 9:
        print("Usage: python script.py <input_fasta> <output_fasta> <processes> "
              "<forward_primer> <reverse_primer> <forward_range> "
              "<reverse_range> <min_length>")
        sys.exit(1)

    input_fasta   = sys.argv[1]
    output_fasta  = sys.argv[2]
    processes     = int(sys.argv[3])
    forward_primers = [sys.argv[4]]
    reverse_primers = [sys.argv[5]]
    forward_range = tuple(map(int, sys.argv[6].split('-')))
    reverse_range = tuple(map(int, sys.argv[7].split('-')))
    min_length    = int(sys.argv[8])

    trimmed, untrimmed = trim_sequences(
        input_fasta,
        output_fasta,
        forward_primers,
        reverse_primers,
        forward_range,
        reverse_range,
        min_length,
        processes
    )

    print(f"Successfully trimmed sequences: {trimmed}")
    print(f"Sequences left untrimmed: {untrimmed}")

