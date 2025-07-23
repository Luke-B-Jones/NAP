#!/usr/bin/env python3
"""
blast_consensus.py
------------------
Create a consensus taxonomic assignment for each query sequence in a BLAST
output (format 6 with 13 columns, where column 13 is `stitle`).

Fixes over the original version
===============================
1. Safely handles lines whose final taxon segment contains **only one word** –
   species is recorded as ``sp.`` instead of raising IndexError.
2. Removes square/round/curly brackets and quotes around the genus, so
   ``[Mycobacterium]`` and ``Mycobacterium`` are treated identically.
3. Emits warnings (to *stderr*) when it skips an obviously malformed line
   (fewer than 13 columns or bad numeric values).

Usage
-----
    python blast_consensus.py <blast_outfmt6> <consensus_output>
"""

import sys
import re
from collections import Counter

# --------------------------------------------------------------------------- #
#  Helper functions                                                           #
# --------------------------------------------------------------------------- #
_BRACKET_CHARS = "[](){}\"'"

def extract_taxonomy(stitle: str):
    """
    Parse the semicolon-delimited taxonomic path in *stitle*.

    Returns a tuple: (order, genus, species)
    with fall-backs:
        order   → "Unknown"   if not present
        genus   → "Unknown"   if not present
        species → "sp."       if not present
    """
    parts = stitle.split(";")

    # Order – second-to-last segment when available
    order = parts[-2].strip() if len(parts) >= 2 and parts[-2].strip() else "Unknown"

    # Last segment should carry genus [+ species + strain info ...]
    last_seg = parts[-1].strip() if parts else ""
    tokens = last_seg.split()

    if not tokens:
        return order, "Unknown", "sp."

    raw_genus = tokens[0].strip(_BRACKET_CHARS)
    genus = raw_genus if raw_genus else "Unknown"

    species = tokens[1] if len(tokens) >= 2 else "sp."

    return order, genus, species


def parse_blast_output(blast_output_file):
    """
    Read BLAST format-6 output and return a dict:
        {qseqid: [hit_dict, …]}
    Each *hit_dict* contains both numeric fields and the extracted taxonomy.
    """
    blast_results = {}

    with open(blast_output_file, "r") as fh:
        for lineno, line in enumerate(fh, 1):
            if not line.strip():
                continue

            cols = line.rstrip("\n").split("\t")
            if len(cols) < 13:
                sys.stderr.write(
                    f"WARNING line {lineno}: expected 13 columns, got {len(cols)} – skipped.\n"
                )
                continue

            (
                qseqid,
                sseqid,
                pident,
                length,
                mismatch,
                gapopen,
                qstart,
                qend,
                sstart,
                send,
                evalue,
                bitscore,
                stitle,
            ) = cols

            # Numeric conversions – skip row on error
            try:
                hit = {
                    "qseqid": qseqid,
                    "sseqid": sseqid,
                    "pident": float(pident),
                    "length": int(length),
                    "mismatch": int(mismatch),
                    "gapopen": int(gapopen),
                    "qstart": int(qstart),
                    "qend": int(qend),
                    "sstart": int(sstart),
                    "send": int(send),
                    "evalue": float(evalue),
                    "bitscore": float(bitscore),
                    "stitle": stitle,
                }
            except ValueError:
                sys.stderr.write(
                    f"WARNING line {lineno}: numeric parse error – skipped.\n"
                )
                continue

            # Taxonomy fields
            order, genus, species = extract_taxonomy(stitle)
            hit.update({"order": order, "genus": genus, "species": species})

            blast_results.setdefault(qseqid, []).append(hit)

    return blast_results


def determine_consensus(blast_results):
    """
    For each query:
        1. Keep at most the top-10 hits.
        2. Identify the two most common *orders*.
        3. Within each order:
              • pick the most common genus,
              • then the most common species in that genus,
              • finally, pick the best-scoring hit (pident, bitscore, –evalue).
        4. From the two candidate hits (one per order), choose the best overall.
    """
    consensus = []

    for qseqid, hits in blast_results.items():
        hits = hits[:10]  # limit

        # Step 1 – two most common orders
        order_counter = Counter(h["order"] for h in hits)
        top_orders = [o for o, _ in order_counter.most_common(2)]

        best_hits = []
        for order in top_orders:
            order_hits = [h for h in hits if h["order"] == order]

            # Step 2 – most common genus
            genus_counter = Counter(h["genus"] for h in order_hits)
            top_genus = genus_counter.most_common(1)[0][0]
            genus_hits = [h for h in order_hits if h["genus"] == top_genus]

            # Step 3 – most common species within that genus
            species_counter = Counter(h["species"] for h in genus_hits)
            top_species = species_counter.most_common(1)[0][0]
            species_hits = [h for h in genus_hits if h["species"] == top_species]

            # Best scoring hit for this order
            best_hit = max(
                species_hits,
                key=lambda x: (x["pident"], x["bitscore"], -x["evalue"]),
            )
            best_hits.append(best_hit)

        # Step 4 – overall best
        final_hit = max(
            best_hits,
            key=lambda x: (x["pident"], x["bitscore"], -x["evalue"]),
        )
        consensus.append(final_hit)

    return consensus


def write_consensus_output(consensus, outfile):
    """
    Write selected hits in the same 13-column tab-delimited format,
    keeping the full taxonomy, but trimming the last taxon field to just 'Genus species'.
    """
    with open(outfile, "w") as fh:
        for h in consensus:
            original_stitle = re.sub(r'^\S+\s+', '', h["stitle"])          
            parts = original_stitle.split(";")

            if parts:
                last_segment_tokens = parts[-1].strip().split()
                if len(last_segment_tokens) >= 2:
                    # Replace the last part with only 'Genus species'
                    genus_species = f"{last_segment_tokens[0]} {last_segment_tokens[1]}"
                    parts[-1] = genus_species
                else:
                    # In case last segment is malformed, fallback to 'Unknown sp.'
                    parts[-1] = "Unknown sp."

            short_title = ";".join(p.strip() for p in parts)

            fh.write(
                "\t".join(
                    [
                        h["qseqid"],
                        h["sseqid"],
                        f"{h['pident']:.3f}",
                        str(h["length"]),
                        str(h["mismatch"]),
                        str(h["gapopen"]),
                        str(h["qstart"]),
                        str(h["qend"]),
                        str(h["sstart"]),
                        str(h["send"]),
                        f"{h['evalue']:.3e}",
                        f"{h['bitscore']:.0f}",
                        short_title,
                    ]
                )
                + "\n"
            )


# --------------------------------------------------------------------------- #
#  Main                                                                       #
# --------------------------------------------------------------------------- #
def main():
    if len(sys.argv) != 3:
        sys.stderr.write(
            "Usage: python blast_consensus.py <blast_outfmt6> <consensus_output>\n"
        )
        sys.exit(1)

    blast_file, out_file = sys.argv[1:3]
    blast_results = parse_blast_output(blast_file)
    consensus = determine_consensus(blast_results)
    write_consensus_output(consensus, out_file)


if __name__ == "__main__":
    main()
