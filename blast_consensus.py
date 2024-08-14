import sys
from collections import Counter

def parse_blast_output(blast_output_file):
    """
    Parse the BLAST output file into a list of dictionaries for each hit.
    """
    blast_results = {}
    with open(blast_output_file, 'r') as file:
        for line in file:
            cols = line.strip().split('\t')
            qseqid = cols[0]
            sseqid = cols[1]
            pident = float(cols[2])
            length = int(cols[3])
            mismatch = int(cols[4])
            gapopen = int(cols[5])
            qstart = int(cols[6])
            qend = int(cols[7])
            sstart = int(cols[8])
            send = int(cols[9])
            evalue = float(cols[10])
            bitscore = float(cols[11])
            stitle = cols[12]

            genus = stitle.split()[0]  # Assuming the genus is the first word in the title
            species = ' '.join(stitle.split()[:2])  # Assuming the species is the first two words

            hit_data = {
                'qseqid': qseqid,
                'sseqid': sseqid,
                'pident': pident,
                'length': length,
                'mismatch': mismatch,
                'gapopen': gapopen,
                'qstart': qstart,
                'qend': qend,
                'sstart': sstart,
                'send': send,
                'evalue': evalue,
                'bitscore': bitscore,
                'genus': genus,
                'species': species,
                'stitle': stitle
            }

            if qseqid not in blast_results:
                blast_results[qseqid] = []
            blast_results[qseqid].append(hit_data)
    
    return blast_results

def determine_consensus(blast_results):
    """
    Determine the consensus genus and species for each query.
    """
    consensus_results = []

    for qseqid, hits in blast_results.items():
        if len(hits) > 5:
            hits = hits[:5]

        genus_counter = Counter(hit['genus'] for hit in hits)
        most_common_genus, _ = genus_counter.most_common(1)[0]

        species_counter = Counter(hit['species'] for hit in hits if hit['genus'] == most_common_genus)
        most_common_species, _ = species_counter.most_common(1)[0]

        # If there's a tie, choose the hit with the highest bitscore
        consensus_hit = None
        if len(species_counter) > 1:
            highest_bitscore = max(hits, key=lambda x: x['bitscore'])
            consensus_hit = highest_bitscore
        else:
            consensus_hit = next(hit for hit in hits if hit['species'] == most_common_species)

        consensus_results.append(consensus_hit)
    
    return consensus_results

def write_consensus_output(consensus_results, output_file):
    """
    Write the consensus results to the output file in BLAST format.
    """
    with open(output_file, 'w') as file:
        for result in consensus_results:
            file.write(f"{result['qseqid']}\t{result['sseqid']}\t{result['pident']}\t{result['length']}\t{result['mismatch']}\t"
                       f"{result['gapopen']}\t{result['qstart']}\t{result['qend']}\t{result['sstart']}\t{result['send']}\t"
                       f"{result['evalue']}\t{result['bitscore']}\t{result['stitle']}\n")

def main():
    blast_output_file = sys.argv[1]
    consensus_output_file = sys.argv[2]

    blast_results = parse_blast_output(blast_output_file)
    consensus_results = determine_consensus(blast_results)
    write_consensus_output(consensus_results, consensus_output_file)

if __name__ == "__main__":
    main()
