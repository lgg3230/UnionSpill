#!/home/lgg3230/.conda/envs/venv_python312/bin/python
"""
Quick script to convert pretreatment parquet to Stata .dta format.
"""

import pandas as pd
import pyarrow.parquet as pq
from pathlib import Path
import time

RAIS_AUX = Path("/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux")
INPUT_PARQUET = RAIS_AUX / "bilateral_pretreatment_regression_data.parquet"
OUTPUT_DTA = RAIS_AUX / "bilateral_pretreatment_regression_data.dta"

print(f"Converting {INPUT_PARQUET} to Stata format...")
start = time.time()

# Load parquet
df = pq.read_table(INPUT_PARQUET).to_pandas()
print(f"  Loaded {len(df):,} rows")

# Convert ID columns to string
df['identificad_i'] = df['identificad_i'].astype(str)
df['identificad_j'] = df['identificad_j'].astype(str)

# Convert float64 to float32 to reduce file size
float_cols = df.select_dtypes(include=['float64']).columns
for col in float_cols:
    df[col] = df[col].astype('float32')

print(f"  Memory: {df.memory_usage(deep=True).sum()/1e9:.2f} GB")

# Save to Stata
print(f"  Writing to {OUTPUT_DTA}...")
df.to_stata(OUTPUT_DTA, write_index=False, version=118)

elapsed = time.time() - start
print(f"Done in {elapsed/60:.1f} minutes")
print(f"Output: {OUTPUT_DTA}")
