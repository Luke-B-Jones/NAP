#!/usr/bin/env python3
import argparse
import pandas as pd

def build_species_to_genus_sets(full_taxa_file):
    """
    Reads the full‐taxonomy TSV (columns: taxonomy␉abundance),
    returns a dict mapping each species epithet → set of classifier‐assigned genera.
    Genus is defined as the first word of the species name (last semicolon field).
    """
    df = pd.read_csv(full_taxa_file, sep='\t', header=0, names=['taxonomy','abundance'])
    genus_sets = {}
    for tax in df['taxonomy']:
        parts = [p.strip() for p in tax.split(';') if p.strip()]
        if not parts:
            continue
        species = parts[-1]
        genus = species.split()[0] if species else None
        if genus:
            genus_sets.setdefault(species, set()).add(genus)
    return genus_sets

def rollup_to_genus(full_taxa_file, refined_file, output_file):
    """
    Uses the full‐taxonomy file to build species→genus sets, then:
     - if a species appears under one or more genera, collapse into a single name
       (just that genus when one, or hyphen‐joined when multiple)
     - if a species never appears in the full file, fall back to its first word
    Reads the refined species TSV (taxonomy␉abundance), maps each species
    to its consensus genus, and sums abundances.
    """
    sp_to_gsets = build_species_to_genus_sets(full_taxa_file)

    rdf = pd.read_csv(refined_file, sep='\t')
    if 'taxonomy' not in rdf.columns or 'abundance' not in rdf.columns:
        raise ValueError("Input must have 'taxonomy' and 'abundance' columns")

    def consensus_genus(sp):
        gset = sp_to_gsets.get(sp, set())
        if gset:
            return '-'.join(sorted(gset))
        return sp.split()[0] if sp else "Unknown"

    rdf['species'] = rdf['taxonomy'].str.split(';').str[-1].str.strip()
    rdf['genus']   = rdf['species'].map(consensus_genus)

    gdf = (
        rdf
        .groupby('genus', as_index=False)['abundance']
        .sum()
        .sort_values('abundance', ascending=False)
    )
    gdf.to_csv(output_file, sep='\t', index=False, header=['genus','abundance'])

def main():
    p = argparse.ArgumentParser(
        description="Roll species→genus with consensus collapse for multi-genus species"
    )
    p.add_argument('--full', required=True,
                   help="Full taxonomy TSV (taxonomy␉abundance) with full semicolon paths")
    p.add_argument('--in', dest='refined', required=True,
                   help="Species-level TSV (taxonomy␉abundance)")
    p.add_argument('-o', '--output', required=True,
                   help="Output genus-level TSV (genus␉abundance)")
    args = p.parse_args()

    rollup_to_genus(args.full, args.refined, args.output)

if __name__ == '__main__':
    main()
