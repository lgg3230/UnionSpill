#!/home/lgg3230/.conda/envs/venv_python312/bin/python
"""
Add z_clauses_proximity to the enhanced bilateral parquet.

Reads numb_clauses from the firm-level Stata file (year=2009 baseline),
computes clauses_proximity = -abs(numb_clauses_i - numb_clauses_j),
standardizes, and writes updated parquets to both GPFS and /tmp.

Input:
  - Data/RAIS_aux/bilateral_pairs_enhanced.parquet (271M directed pairs)
  - Data/CBA_RAIS_firm_level/cba_rais_firm_2009_2016_flows_1.dta (numb_clauses)
Output:
  - Data/RAIS_aux/bilateral_pairs_enhanced.parquet (overwritten with clauses)
  - /tmp/bilateral_pairs_enhanced.parquet (overwritten with clauses)
"""

import duckdb
import pandas as pd
import numpy as np
import time
import sys

sys.stdout.reconfigure(line_buffering=True)

# Paths
GPFS_PARQUET = '/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/bilateral_pairs_enhanced.parquet'
TMP_PARQUET = '/tmp/bilateral_pairs_enhanced.parquet'
FIRM_DTA = '/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/CBA_RAIS_firm_level/cba_rais_firm_2009_2016_flows_1.dta'

print("=" * 70)
print("ADDING z_clauses_proximity TO ENHANCED PARQUET")
print("=" * 70)

start_time = time.time()

# ==============================================================================
# STEP 1: Load numb_clauses from firm-level data (year=2009 baseline)
# ==============================================================================
print("\n--- Step 1: Loading numb_clauses from firm-level data ---")

clauses_df = pd.read_stata(FIRM_DTA, columns=['identificad', 'year', 'numb_clauses'])
print(f"  Loaded {len(clauses_df):,} firm-year rows")

clauses_df = clauses_df[clauses_df['year'] == 2009][['identificad', 'numb_clauses']].copy()
clauses_df['identificad'] = clauses_df['identificad'].astype(str).str.strip()
clauses_df = clauses_df.dropna(subset=['numb_clauses'])
print(f"  Year 2009 with non-null clauses: {len(clauses_df):,} firms")

elapsed = time.time() - start_time
print(f"  Elapsed: {elapsed/60:.1f} min")

# ==============================================================================
# STEP 2: Compute clauses_proximity and standardize
# ==============================================================================
print("\n--- Step 2: Computing clauses_proximity via DuckDB ---")

con = duckdb.connect()
con.execute("PRAGMA threads=8")
con.execute("PRAGMA memory_limit='64GB'")
con.execute("SET preserve_insertion_order=false")

# Register clauses lookup
con.register('clauses_lookup', clauses_df)

# First compute standardization stats over the full sample
print("  Computing standardization stats...")
stats = con.execute(f"""
    SELECT
        AVG(-ABS(ci.numb_clauses - cj.numb_clauses)) as mean_val,
        STDDEV_POP(-ABS(ci.numb_clauses - cj.numb_clauses)) as sd_val,
        COUNT(*) as n_matched
    FROM read_parquet('{GPFS_PARQUET}') p
    INNER JOIN clauses_lookup ci ON p.identificad_i = ci.identificad
    INNER JOIN clauses_lookup cj ON p.identificad_j = cj.identificad
""").fetchone()

clauses_mean = stats[0]
clauses_sd = max(stats[1], 0.0001)
n_matched = stats[2]

print(f"  clauses_proximity: mean={clauses_mean:.6f}, sd={clauses_sd:.6f}")
print(f"  Matched pairs: {n_matched:,}")

elapsed = time.time() - start_time
print(f"  Elapsed: {elapsed/60:.1f} min")

# ==============================================================================
# STEP 3: Write updated parquet with clauses columns
# ==============================================================================
print("\n--- Step 3: Writing updated parquet ---")

# Write to a temp file first, then move
TMP_OUTPUT = '/tmp/bilateral_pairs_enhanced_with_clauses.parquet'

query = f"""
    COPY (
        SELECT
            p.*,
            -ABS(ci.numb_clauses - cj.numb_clauses) as clauses_proximity,
            (-ABS(ci.numb_clauses - cj.numb_clauses) - {clauses_mean}) / {clauses_sd} as z_clauses_proximity
        FROM read_parquet('{GPFS_PARQUET}') p
        LEFT JOIN clauses_lookup ci ON p.identificad_i = ci.identificad
        LEFT JOIN clauses_lookup cj ON p.identificad_j = cj.identificad
    ) TO '{TMP_OUTPUT}' (FORMAT PARQUET, COMPRESSION ZSTD)
"""

print("  Writing parquet (this will take several minutes)...")
con.execute(query)

elapsed = time.time() - start_time
print(f"  Written in {elapsed/60:.1f} min")

# ==============================================================================
# STEP 4: Verify and move to final locations
# ==============================================================================
print("\n--- Step 4: Verifying output ---")

verify = con.execute(f"""
    SELECT
        COUNT(*) as n_rows,
        SUM(CASE WHEN clauses_proximity IS NOT NULL THEN 1 ELSE 0 END) as n_clauses,
        SUM(CASE WHEN z_clauses_proximity IS NOT NULL THEN 1 ELSE 0 END) as n_z_clauses,
        AVG(z_clauses_proximity) as z_mean,
        STDDEV_POP(z_clauses_proximity) as z_sd
    FROM read_parquet('{TMP_OUTPUT}')
""").fetchone()

print(f"  Total rows: {verify[0]:,}")
print(f"  clauses_proximity coverage: {verify[1]:,} ({verify[1]/verify[0]*100:.1f}%)")
print(f"  z_clauses_proximity coverage: {verify[2]:,} ({verify[2]/verify[0]*100:.1f}%)")
print(f"  z_clauses_proximity mean: {verify[3]:.6f} (should be ~0)")
print(f"  z_clauses_proximity sd: {verify[4]:.6f} (should be ~1)")

con.close()

# Move to final locations
import shutil
print(f"\n  Copying to {TMP_PARQUET}...")
shutil.copy2(TMP_OUTPUT, TMP_PARQUET)

print(f"  Copying to {GPFS_PARQUET}...")
shutil.copy2(TMP_OUTPUT, GPFS_PARQUET)

# Clean up temp
import os
os.remove(TMP_OUTPUT)

elapsed = time.time() - start_time
print(f"\n{'=' * 70}")
print(f"DONE in {elapsed/60:.1f} minutes")
print(f"Both parquets updated with clauses_proximity and z_clauses_proximity")
print(f"{'=' * 70}")
