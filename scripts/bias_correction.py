#!/usr/bin/env python3
"""
bias_correct_mixed.py

Usage
-----
python bias_correct_mixed.py \
       --in  mixed_abundance.tsv \
       --o   corrected.tsv \
       --16s 2.5 \
       --18s 1.3 \
       --log run.log
"""
import argparse
import pandas as pd
import sys
from pathlib import Path

def is_16s(tax_string: str) -> bool:
    """Return True if the lineage starts with Bacteria or Archaea."""
    root = tax_string.split(';', 1)[0].strip()
    return root in {'Bacteria', 'Archaea'}

def main(args):
    data = pd.read_csv(args.infile, sep='\t')

    if 'abundance' not in data.columns or 'taxonomy' not in data.columns:
        sys.exit("Input must have 'taxonomy' and 'abundance' columns.")

    # classify rows
    mask_16s = data['taxonomy'].apply(is_16s)
    mask_18s = ~mask_16s

    # original sums (for sanity)
    sum_orig_16 = data.loc[mask_16s, 'abundance'].sum()
    sum_orig_18 = data.loc[mask_18s, 'abundance'].sum()

    # apply bias correction
    data.loc[mask_16s, 'abundance'] = data.loc[mask_16s, 'abundance'] / args.bias16
    data.loc[mask_18s, 'abundance'] = data.loc[mask_18s, 'abundance'] / args.bias18

    # write output
    data.to_csv(args.outfile, sep='\t', index=False)

    # verify and log
    sum_corr_16 = data.loc[mask_16s, 'abundance'].sum()
    sum_corr_18 = data.loc[mask_18s, 'abundance'].sum()

    if abs(sum_corr_16 - sum_orig_16 / args.bias16) > 1e-6 or \
       abs(sum_corr_18 - sum_orig_18 / args.bias18) > 1e-6:
        msg = "WARNING: Sum check failed – possible precision or input error."
    else:
        msg = "Bias correction successful."

    if args.log:
        with open(args.log, 'a') as lf:
            lf.write(
                f"{Path(args.infile).name} → {Path(args.outfile).name}: "
                f"16S bias={args.bias16}, 18S bias={args.bias18}. {msg}\n"
            )

if __name__ == "__main__":
    p = argparse.ArgumentParser(description="Apply separate 16S/18S bias factors.")
    p.add_argument("--in",  dest="infile",  required=True, help="input TSV")
    p.add_argument("--o",   dest="outfile", required=True, help="output TSV")
    p.add_argument("--16s", dest="bias16",  required=True, type=float,
                   help="bias factor for 16S rows")
    p.add_argument("--18s", dest="bias18",  required=True, type=float,
                   help="bias factor for 18S rows")
    p.add_argument("--log", dest="log",     default=None,  help="append run info here")
    main(p.parse_args())
