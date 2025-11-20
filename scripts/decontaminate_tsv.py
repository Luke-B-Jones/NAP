# optimize~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# optimize~~~~~~~~~~~~~~ Decontamination Python script ~~~~~~~~~~~~~~#
# optimize~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

# !/usr/bin/env python3

"""
Decontamination pipeline CLI script using configuration file.

Usage:
    decontam.py --config <config_file> [--log LOG_FILE]

INI config named [decontamination] holds all parameters (paths, thresholds, reads, phred, etc.).
The configuration file should be in INI format, e.g.:

[decontamination]
# Input/output files
sample_tsv = path/to/sample.tsv
blank_tsv = path/to/blank.tsv
output_tsv = path/to/output.tsv

# Read counts
blank_raw_reads = 198079
sample_raw_reads = 103025

#Quality thresholds
phred_score = 34
prevalence_threshold = 0.32
ratio_threshold = 0.2

#Scaling
scaling_factor = 100000

#Aggression for high-quality decontamination
aggression_factor = 50

"""
import argparse
import sys
import os
import pandas as pd
import time
import datetime
from configparser import ConfigParser
import logging

# --------------------------------------
# Core decontamination functions
# --------------------------------------
def load_data(input_tsv: str) -> pd.DataFrame:
    """
    Load a TSV file into a pandas DataFrame, normalize column names.
    """
    logging.info(f"Loading data from {input_tsv}")
    try:
        df = pd.read_csv(input_tsv, sep='\t')
        df.columns = df.columns.str.strip().str.lower()
        logging.info(f"Loaded {input_tsv}, total abundance={df['abundance'].sum():.2f}")
        return df
    except Exception as e:
        logging.error(f"Failed to load {input_tsv}: {e}")
        sys.exit(1)


def preprocess_data(df: pd.DataFrame, is_blank: bool = False) -> pd.DataFrame:
    """
    Ensure required columns, convert abundance to numeric, extract/create genus column, handle blank prevalence (if need be).
    If is_blank=True:
        - If a 'prevalence' column exists, convert to numeric and fill missing with 0.
        - If 'prevalence' does not exist, do nothing extra (remain robust).
    """
    logging.info("Preprocessing data: normalizing columns, extracting genus...")
    required = ['taxonomy', 'abundance']
    for col in required:
        if col not in df.columns:
            logging.error(f"Missing column {col}")
            sys.exit(1)

    df['abundance'] = pd.to_numeric(df['abundance'], errors='coerce').fillna(0)
    if is_blank and 'prevalence' in df.columns:
        df['prevalence'] = pd.to_numeric(df['prevalence'], errors='coerce').fillna(0)
    # extract species as last semicolon-delimited field from the full taxonomy
    df['species'] = df['taxonomy'].str.split(';').str[-1].str.strip()
    # genus = first word of that species string
    df['genus']   = df['species'].str.split().str[0]
    logging.info(f"Preprocessed data: {len(df)} rows, {df['genus'].nunique()} unique genera")
    return df


def denormalize_abundance(df: pd.DataFrame, total_raw: int, scaling: float) -> pd.DataFrame:
    """
    Denormalize TSS-scaled abundances back to raw counts.
    """
    logging.info(f"Denormalizing abundances: raw_total={total_raw}, scaling={scaling}")
    df['abundance'] = df['abundance'] * total_raw / scaling
    logging.info(f"Denormalized: total abundance now={df['abundance'].sum():.2f}")
    return df


def merged_dataframes(sample_df: pd.DataFrame, blank_df: pd.DataFrame) -> pd.DataFrame:
    """
    Merge sample and blank on taxonomy and genus, fill missing.
    """
    logging.info("Merging sample and blank DataFrames")
    merged = pd.merge(
        sample_df, blank_df,
        on=['species', 'genus'], how='outer',
        suffixes=('_sample', '_blank')
    ).fillna(0)
    logging.info(f"Merged DataFrame: {len(merged)} rows")
    return merged


def contaminant_identifier(
        row, mock_taxon_set, mock_genus_set, blank_genus_set,
        prevalence_threshold: float, ratio_threshold: float
) -> bool:
    """
    Determine if a taxon is a contaminant based on blank and mock.
    """
    # 1. Skip mock taxa (If present in Mock, False)
    if row['species'] in mock_taxon_set:
        return False
    # 2. If the taxon is not directly detected/present in the blank, False
    if row['abundance_blank'] <= 0:
        if row['genus'] in blank_genus_set:
            # If sample abundance is very low (<5), flag as contaminant even if the genus is in the mock.
            if row['abundance_sample'] < 5:
                return True
            # If this genus is present in the mock, revert to non-contaminant
            if row['genus'] in mock_genus_set:
                return False
            # If the candidate is in the blank but the genus is not in the mock, flag as contaminant.
            return True
        return False  # If the genus is not found in the blank, leave as False

    # 3. Prevalence threshold (If available)
    if 'prevalence_blank' in row and row['prevalence_blank'] >= prevalence_threshold:
        return True
        # If the taxon is prevalence above the blank prevalence threshold, True

    # 4. Ratio threshold: blank/sample
    # Check the abundance ratio (sample abundance divided by blank abundance).
    # If sample abundance > 0, compute the ratio.
    if row['abundance_sample'] > 0:
        ratio = row['abundance_blank'] / (row['abundance_sample'] + 1e-6)
        if ratio >= ratio_threshold:
            return True

    # 5. Blank >> sample
    # If the blank's abundance is more than twice that of the sample, flag as contaminant.
    if row['abundance_blank'] > 2 * row['abundance_sample']:
        return True

    # Otherwise, do not flag as contaminant.
    return False


def high_quality_sample_decontamination(
        df: pd.DataFrame, aggression_factor: float
) -> (pd.DataFrame, None):
    """
    Apply two-tier decontamination for high-quality data:
    - High aggression for low-abundance contaminants
    - Medium aggression otherwise
    """
    logging.info("Starting high-quality decontamination")
    df = df.copy()
    # Conditions
    medium_cond = df['contaminant_flag']
    high_cond = (
            (df['abundance_blank'] < 0.05 * df['abundance_sample']) &
            df['contaminant_flag'] & ~medium_cond
    )
    logging.info(f"High-tier removal: {high_cond.sum()} rows; medium-tier: {medium_cond.sum()}")

    def high_aggression_decontamination(row, multiplier=10, alpha=8):
        abundance_sample = row['abundance_sample']
        abundance_blank = row['abundance_blank']
        logging.debug(f"High aggression: alpha={alpha}, multiplier={multiplier}")
        ratio = abundance_blank / (abundance_sample + 1e-6)
        cf = min(1, ratio)
        reduction = cf ** alpha * multiplier * 2 * abundance_blank * (10 ** (-aggression_factor))
        return max(abundance_sample - reduction, 0)

    def medium_aggression_decontamination(row, multiplier=10, alpha=0.4):
        abundance_sample = row['abundance_sample']
        abundance_blank = row['abundance_blank']
        logging.debug(f"Medium aggression: alpha={alpha}, multiplier={multiplier}")
        if abundance_blank == 0:
            reduction = 1
        else:
            ratio = abundance_blank / (abundance_sample + 1e-6)
            cf = min(1, ratio)
            reduction = cf ** alpha * multiplier * abundance_blank * (10 ** (-aggression_factor))
        return max(abundance_sample - reduction, 0)

    df.loc[high_cond, 'abundance_sample'] = df.loc[high_cond].apply(
        high_aggression_decontamination, axis=1
    )
    df.loc[medium_cond, 'abundance_sample'] = df.loc[medium_cond].apply(
        medium_aggression_decontamination, axis=1
    )
    logging.info(
        f"Completed high-quality decontamination; total remaining abundance={df['abundance_sample'].sum():.2f}")
    return df, None


def low_quality_sample_decontamination(df: pd.DataFrame):
    """
    Three genus-level approaches for low-quality data.
    For low-quality samples (phred < 30), apply three different genus-level decontamination approaches.
    Returns a list of DataFrames (one for each approach) and an output dictionary.

    For each genus, we want to reduce or redistribute abundance among flagged species.
    """
    logging.info("Starting low-quality decontamination")
    df = df.copy()

    # label contaminant levels
    def label(x):
        if x > 100: return 'High'
        if x >= 10: return 'Medium'
        if x > 0: return 'Low'
        return 'None'

    df['contaminant_level'] = df['abundance_blank'].apply(label)

    # Approach 1: proportional
    def prop(group):
        """
           Approach 1: For each genus group, penalize all species proportionally to the fraction flagged.
           :param group: pd.DataFrame input. Penalize proportionally unflagged and flagged.
           :return: pd.DataFrame output
           """
        total = group['abundance_sample'].sum()
        if total <= 0: return group
        flagged = group.loc[group['contaminant_flag'], 'abundance_sample'].sum()
        frac = flagged / total
        # All species in this genus lose fraction_flagged of their abundance
        group['abundance_sample'] *= (1 - frac)
        return group

    """
    PROS: Any contamination in the genus reduces the entire genus proportionally
    CON: Any amount of flagged contamination can penalize the entire genus severely
    (if the flagged fraction is small but not trivial)
    """

    # Approach 2: sig-fraction threshold
    def sig(group, min_frac=0.2):
        """
        Approach 2: If flagged species are > X% of the genus abundance,
        apply a proportional penalty to *all* species in the genus.
        Otherwise, only penalize flagged species (e.g., zero them out).
        """
        total = group['abundance_sample'].sum()
        flagged = group.loc[group['contaminant_flag'], 'abundance_sample'].sum()
        frac = flagged / total if total > 0 else 0
        if frac >= min_frac:
            group['abundance_sample'] *= (1 - frac)
            # Penalize entire genus
        else:
            # Only penalize flagged species
            # e.g. zero out flagged, keep unflagged
            group.loc[group['contaminant_flag'], 'abundance_sample'] = 0
        return group

    """
    group by genus, apply threshold-based correction.
    PROS: Avoids punishing the entire genus if only a small fraction is flagged
    CONS: You still might be too lenient if e.g. 19% is flagged but the 19% is truly contamination.
    The threshold is an arbitrary cutoff that needs careful tuning.
    """

    # Approach 3: flagged-only
    def flag_only(group):
        """
        Approach 3: For each genus group, adjust abundance_sample only for rows flagged as contaminants,
        based on their contaminant_level. Unflagged rows remain unchanged.

        If any species in the genus is flagged as a contaminant, then reduce the abundance of
        all species in that genus by the penalty_fraction.

        The rules are:
        - If contaminant_level is "High abundance contaminant", set abundance_sample to 0.
        - If contaminant_level is "Medium abundance contaminant", reduce abundance_sample by multiplying by (1 - penalty_fraction).
        - If contaminant_level is "Low abundance contaminant", reduce abundance_sample by multiplying by (1 - 2*penalty_fraction),
        ensuring the value does not go negative.
        - Otherwise, leave abundance_sample unchanged.
        """

        def adjust(row):
            lvl = row['contaminant_level']
            a = row['abundance_sample']
            if not row['contaminant_flag']:
                return a
            if lvl == 'High': return 0
            if lvl == 'Medium': return max(a * 0.0, 0)
            if lvl == 'Low': return max(a * -0.2, 0)
            return a

        group['abundance_sample'] = group.apply(adjust, axis=1)
        return group

    """
    group by genus, only penalize flagged species.
    PROS: Minimal risk of removing real data for unflagged species.
    CONS: If classification is poor (especially for low-quality reads), unflagged species in the same genus may actually be contaminants.
    You risk not catching cross-species misclassifications inside the same genus.
    """

    out1 = df.groupby('genus', group_keys=False).apply(prop,  include_groups=False)
    out2 = df.groupby('genus', group_keys=False).apply(sig,   include_groups=False)
    out3 = df.groupby('genus', group_keys=False).apply(flag_only, include_groups=False)

    logging.info("Completed low-quality decontamination approaches")
    return [out1, out2, out3], None


def filter_low_abundance(df: pd.DataFrame) -> pd.DataFrame:
    """
    Remove taxa below 1.0 if flagged as a contaminant, below 0.1 otherwise.
    """
    logging.info("Filtering low-abundance taxa")
    cond = (
            ((df['contaminant_flag']) & (df['abundance_sample'] >= 1.0)) |
            (~df['contaminant_flag'] & (df['abundance_sample'] >= 0.1))
    )
    filtered = df[cond].copy()
    logging.info(f"Filtered: {len(filtered)} taxa remain")
    return df[cond].sort_values('abundance_sample', ascending=False)


def re_tss_normalize(df: pd.DataFrame, scaling: float) -> pd.DataFrame:
    """
    Re-apply TSS normalization for final output.
    """
    logging.info("Re-normalizing to relative abundances")
    df = df.copy()
    total = df['abundance_sample'].sum()
    if total > 0:
        df['abundance_sample'] = df['abundance_sample'] / total * scaling
    else:
        df['abundance_sample'] = 0
    logging.info(f"Re-normalized: total relative abundance sum={df['abundance_sample'].sum():.2f}")
    return df


# --------------------------------------
# CLI and Config handling
# --------------------------------------
def parse_args():
    parser = argparse.ArgumentParser(
        description="Run decontamination using parameters from a config file"
    )
    parser.add_argument(
        "--config", required=True,
        help="Path to configuration INI file containing all parameters"
    )
    parser.add_argument(
        "--log", default="decontamination.log",
        help="Path to log file (default: decontamination.log)"
    )
    return parser.parse_args()


def load_config(path: str) -> dict:
    cfg = ConfigParser()
    cfg.read(path)
    if 'decontamination' not in cfg:
        raise KeyError("Config file missing [decontamination] section")
    return cfg['decontamination']


def setup_logging(log_path: str):
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        handlers=[
            logging.FileHandler(log_path)    # write everything to the log file
        ]
    )


def main():
    start_time = time.time()
    args = parse_args()
    setup_logging(args.log)
    logging.info("=== Decontamination pipeline started ===")

    cfg = load_config(args.config)
    # Extract parameters from config, with appropriate types
    sample_tsv = cfg.get('sample_tsv')
    blank_tsv = cfg.get('blank_tsv')
    output_tsv = cfg.get('output_tsv')
    aggression_factor = cfg.getfloat('aggression_factor')
    blank_raw_reads = cfg.getint('blank_raw_reads')
    sample_raw_reads = cfg.getint('sample_raw_reads')
    phred_score = cfg.getint('phred_score')
    prevalence_threshold = cfg.getfloat('prevalence_threshold')
    ratio_threshold = cfg.getfloat('ratio_threshold')
    scaling_factor = cfg.getfloat('scaling_factor')

    logging.info(
        f"Config loaded: sample={sample_tsv}, blank={blank_tsv}, "
        f"output={output_tsv}, aggression={aggression_factor}, "
        f"reads(blank)={blank_raw_reads}, reads(sample)={sample_raw_reads}, "
        f"phred={phred_score}, prevalence_thresh={prevalence_threshold}, "
        f"ratio_thresh={ratio_threshold}, scaling_factor={scaling_factor}"
    )

    # Load data
    sample_df = load_data(sample_tsv)
    blank_df = load_data(blank_tsv)

    # Preprocess (normalize column names, extract genus)
    sample_df = preprocess_data(sample_df)
    blank_df = preprocess_data(blank_df, is_blank=True)

    # Denormalize based on raw read counts
    sample_df = denormalize_abundance(sample_df, sample_raw_reads, scaling_factor)
    blank_df = denormalize_abundance(blank_df, blank_raw_reads, scaling_factor)

    # Merge and flag contaminants
    merged_df = merged_dataframes(sample_df, blank_df)
    merged_df["contaminant_flag"] = merged_df.apply(
        lambda row: contaminant_identifier(
            row,
            mock_taxon_set=set(),
            mock_genus_set=set(),
            blank_genus_set=set(blank_df['genus']),
            prevalence_threshold=prevalence_threshold,
            ratio_threshold=ratio_threshold
        ),
        axis=1
    )

    # Decontaminate
    phred_hq_threshold = cfg.getint('phred_hq_threshold', fallback=20)
    if phred_score >= phred_hq_threshold:
        logging.info("High-quality decontamination")
        decont_df, _ = high_quality_sample_decontamination(merged_df, aggression_factor)
        filtered = filter_low_abundance(decont_df)
    else:
        logging.info("Low-quality decontamination")
        dfs, _ = low_quality_sample_decontamination(merged_df)
        filtered = filter_low_abundance(dfs[0])

    # Final normalize & save
    final_df = re_tss_normalize(filtered, scaling_factor)

    # ───────────────────────────────────────────────────────────────────
    # Reduce to the two‐column format expected by downstream tools:
    #   taxonomy   abundance
    final_df['taxonomy'] = final_df['species']
    out = final_df[['taxonomy','abundance_sample']].rename(
        columns={'abundance_sample':'abundance'}
    )

    os.makedirs(os.path.dirname(output_tsv) or '.', exist_ok=True)
    out.to_csv(output_tsv, sep='\t', index=False)
    # ───────────────────────────────────────────────────────────────────


    logging.info(f"Saved results to {output_tsv}")

    elapsed = time.time() - start_time
    logging.info(f"=== Pipeline finished in {elapsed:.2f} seconds ===")


if __name__ == '__main__':
    main()

