#!/bin/bash
# Filtering
export max_length="900"
export min_length="300"
# Blastn CON
export ident_HAC="97"
export cov_HAC="70"
# Blastn RAW
export ident_RAW="90"
# Bias correction
export bias_factor_16s="1"
export bias_factor_18s="0.4"
# Database info
export for_seq="GTGYCAGCMGCCGCGGTAA"
export rev_seq="CCGYCAATTYMTTTRAGTTT"
export for_range="300-800"
export rev_range="650-1500"
export ref_min_length_16s="350"
export ref_min_length_18s="350"
export amplicon_16s_length="400"
export amplicon_18s_length="700"
export type="16s-18s"
