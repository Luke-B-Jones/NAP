#!/usr/bin/env python3
import pandas as pd
import matplotlib
matplotlib.use('Agg')  # no GUI, no interactive output
import matplotlib.pyplot as plt
import argparse
import sys

def load_and_normalise(path):
    """
    Load a TSV with two columns: one of ['taxonomy','genus','species'] and 'abundance'.
    Normalize abundance to percent and return a DataFrame sorted by abundance_pct desc.
    """
    df = pd.read_csv(path, sep='\t')
    tax_cols = [c for c in df.columns if c in ('taxonomy','genus','species')]
    if not tax_cols:
        raise ValueError(f"No 'taxonomy', 'genus' or 'species' column found in {path}")
    df = df.rename(columns={tax_cols[0]: 'taxonomy'})
    if 'abundance' not in df:
        raise ValueError(f"No 'abundance' column found in {path}")
    total = df['abundance'].sum()
    if total <= 0:
        raise ValueError(f"All abundance values are zero or negative in {path}")
    df['abundance_pct'] = df['abundance'] / total * 100
    return df.sort_values('abundance_pct', ascending=False)

def stacked_bar(ax, df, title, legend_title):
    taxa = df['taxonomy'].tolist()
    vals = df['abundance_pct'].tolist()
    # Use the new colormap API: no deprecation warning
    cmap = matplotlib.colormaps.get('tab20', len(taxa))
    bottom = 0.0
    for i, (name, pct) in enumerate(zip(taxa, vals)):
        ax.bar(0, pct, bottom=bottom, color=cmap(i), label=name)
        bottom += pct

    ax.set_title(f'{title} Level Abundance')
    ax.set_xticks([0])
    ax.set_xticklabels(['Total Sample'])
    ax.set_ylabel('Relative Abundance (%)')
    ax.legend(bbox_to_anchor=(1.05, 1), loc='upper left', title=legend_title)

def main():
    p = argparse.ArgumentParser(
        description="Plot side-by-side stacked barplots of genus- and species-level abundances.")
    p.add_argument('species_file', help="TSV of species-level abundances")
    p.add_argument('genus_file',   help="TSV of genus-level abundances")
    p.add_argument('output_file',  help="Path to save the PNG")
    args = p.parse_args()

    try:
        species_df = load_and_normalise(args.species_file)
        genus_df   = load_and_normalise(args.genus_file)
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

    fig, axes = plt.subplots(ncols=2, figsize=(14, 8))
    stacked_bar(axes[0], genus_df,   title='Genus',   legend_title='Genus')
    stacked_bar(axes[1], species_df, title='Species', legend_title='Species')
    plt.tight_layout()
    fig.savefig(args.output_file, dpi=300)
    # no stdout output on success

if __name__ == '__main__':
    main()
