#!/bin/bash
# Filtering
export max_length=""  # Max length of amplicon expected
export min_length=""  # Min length of amplicon expected
# Blastn CON
export ident_HAC="" # Identitiy required when alinging RAW to HAC
export cov_HAC=""   # Coverage required when aligning RAW to HAC
# Blastn RAW
export ident_RAW="90" # READ identify to centroid hit
# Bias correction
export bias_factor_16s="" # abundances bias 16S
export bias_factor_18s="" # abundances bias 18S
# Database info
export for_seq="" # sequence of forward
export rev_seq="" # sequence of reverse
export for_range="" # into rRNA SSU, base range
export rev_range="" # into rRNA SSU, base range
export ref_min_length_16s="" # min length of amplicon
export ref_min_length_18s="" # min length of amplicon
export amplicon_16s_length="" # average length of amplicon
export amplicon_18s_length="" # average length of amplicon
export type="" # 16s-18s always
