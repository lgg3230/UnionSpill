"""
Extract sample establishments with per-worker flow measures (NaN-aware averages).

Reads yearly connectivity data, computes _pw_n variables, merges with sample
indicators from the firm-level file, and saves to .dta.
"""

import pandas as pd
import numpy as np
import sys

DATA = "/kellogg/proj/lgg3230/UnionSpill/Data"
RAIS_AUX = f"{DATA}/RAIS_aux"
RAIS_FIRM = f"{DATA}/CBA_RAIS_firm_level"

# ── 1. Load yearly connectivity (has year-pair _pw_ variables) ──────────────
print("Loading connectivity_2007_2011_yearly.dta...")
yearly = pd.read_stata(f"{RAIS_AUX}/connectivity_2007_2011_yearly.dta",
                       convert_categoricals=False)
print(f"  Loaded {len(yearly):,} rows, {len(yearly.columns)} cols")

# Identify _pw_ year-pair columns for each prefix
prefixes = ["totalout", "totalin", "totalflows", "outlagos", "inlagos", "totallagos"]

for prefix in prefixes:
    pw_prefix = f"{prefix}_pw"
    # Find year-pair columns like totalflows_pw_0708, totalflows_pw_0809, etc.
    yp_cols = [c for c in yearly.columns if c.startswith(f"{pw_prefix}_") and c != pw_prefix]
    if not yp_cols:
        print(f"  WARNING: no year-pair columns found for {pw_prefix}_*")
        continue
    print(f"  {pw_prefix}: {len(yp_cols)} year-pair cols: {yp_cols}")

    # NaN-aware mean across year-pairs
    yearly[f"{pw_prefix}_n"] = yearly[yp_cols].mean(axis=1)  # pandas mean skips NaN by default

print(f"\nNew _pw_n columns created.")

# Keep only identificad + pw_n vars + pw vars (non-year-pair)
keep_cols = ["identificad"]
for prefix in prefixes:
    pw = f"{prefix}_pw"
    keep_cols.append(pw)
    keep_cols.append(f"{pw}_n")

# Filter to columns that exist
keep_cols = [c for c in keep_cols if c in yearly.columns]
conn = yearly[keep_cols].copy()
print(f"Connectivity data: {len(conn):,} rows, cols: {list(conn.columns)}")

# ── 2. Load sample indicators from firm-level file ──────────────────────────
# Only read the columns we need (the file is 59 GB)
print("\nLoading sample indicators from firm-level file...")
# Read just identificad, year, lagos_sample_avg, in_balanced_panel
firm = pd.read_stata(f"{RAIS_FIRM}/cba_rais_firm_2009_2016_flows_1.dta",
                     columns=["identificad", "year", "lagos_sample_avg", "in_balanced_panel"],
                     convert_categoricals=False)
print(f"  Loaded {len(firm):,} rows")

# Collapse to establishment level (these are time-invariant)
sample = firm.groupby("identificad").agg(
    lagos_sample_avg=("lagos_sample_avg", "max"),
    in_balanced_panel=("in_balanced_panel", "max")
).reset_index()
print(f"  {len(sample):,} unique establishments")

# ── 3. Merge ────────────────────────────────────────────────────────────────
print("\nMerging...")
merged = conn.merge(sample, on="identificad", how="inner")
print(f"  Matched: {len(merged):,} establishments")

# Filter to sample
lagos = merged[merged["lagos_sample_avg"] == 1].copy()
print(f"  Lagos sample: {len(lagos):,}")
balanced = lagos[lagos["in_balanced_panel"] == 1].copy()
print(f"  Balanced panel: {len(balanced):,}")

# ── 4. Summary stats ───────────────────────────────────────────────────────
pw_n_cols = [c for c in balanced.columns if c.endswith("_pw_n")]
print(f"\nSummary of _pw_n variables (balanced panel, lagos sample):")
print(balanced[pw_n_cols].describe().round(6).to_string())

# ── 5. Drop lagos flow variables and save ───────────────────────────────────
lagos_cols = [c for c in balanced.columns if "lagos" in c.lower() and c not in ("lagos_sample_avg",)]
print(f"\nDropping lagos flow columns: {lagos_cols}")
balanced.drop(columns=lagos_cols, inplace=True)

print(f"Final columns: {list(balanced.columns)}")
outpath = f"{RAIS_AUX}/sample_estabs_pw_flows.dta"
print(f"\nSaving to {outpath}...")
balanced.to_stata(outpath, write_index=False, version=118)
print("Done.")
