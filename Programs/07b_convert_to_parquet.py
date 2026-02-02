#!/usr/bin/env python3
"""
Convert bilateral regression data from Stata .dta to parquet format.
Run after 07b_bilateral_data_prep.do completes.
"""

import pandas as pd
import os

# Paths
input_path = "/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/bilateral_regression_data.dta"
output_path = "/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/bilateral_regression_data.parquet"

print(f"Reading: {input_path}")
print("This may take a few minutes for 135M+ rows...")

# Read Stata file
df = pd.read_stata(input_path)

print(f"Loaded {len(df):,} rows, {len(df.columns)} columns")
print(f"Columns: {list(df.columns)}")
print(f"Memory usage: {df.memory_usage(deep=True).sum() / 1e9:.2f} GB")

# Save to parquet with snappy compression
print(f"\nSaving to: {output_path}")
df.to_parquet(output_path, index=False, compression='snappy')

# Verify
file_size = os.path.getsize(output_path) / 1e9
print(f"Done! File size: {file_size:.2f} GB")
