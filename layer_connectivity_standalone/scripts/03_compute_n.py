#!/usr/bin/env python3
"""
Script 03: NaN-aware average across year pairs → final firm × layer dataset.

Replicates the _n logic from 05_yearly_employers.do for each of:
  - ratio_total  → layer_treat_pw_n
  - ratio_same   → sametreat_pw_n
  - ratio_cross  → crosstreat_pw_n

Usage:
    python 03_compute_n.py --layer occ3
    python 03_compute_n.py --layer edu
"""

import argparse
import os
import sys
import pandas as pd
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from layer_config import LAYER_DEFS, PAIR_LABELS, OUT_BASE


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--layer", required=True, choices=list(LAYER_DEFS.keys()))
    return p.parse_args()


def nan_aware_avg(df: pd.DataFrame, pair_cols: list, out_name: str) -> pd.DataFrame:
    """Compute NaN-aware average across pair_cols, add {out_name} and {out_name}_count_n."""
    existing = [c for c in pair_cols if c in df.columns]
    if not existing:
        df[out_name]             = np.nan
        df[f"{out_name}_count_n"] = 0
        return df

    vals = df[existing]
    count_n = vals.notna().sum(axis=1)
    sum_n   = vals.sum(axis=1, min_count=1)  # NaN if all missing
    df[out_name]              = np.where(count_n > 0, sum_n / count_n, np.nan)
    df[f"{out_name}_count_n"] = count_n
    return df


def main():
    args = parse_args()
    print(f"Computing NaN-aware averages for layer: {args.layer}")

    wide_path = os.path.join(OUT_BASE, "connectivity_components",
                             f"wide_{args.layer}.parquet")
    out_dir   = os.path.join(OUT_BASE, "final_measures")
    os.makedirs(out_dir, exist_ok=True)
    # Issue 13: rename to reflect all three connectivity measures (total/same/cross)
    out_path         = os.path.join(out_dir, f"firm_layer_connectivity_{args.layer}.dta")
    out_parquet_path = os.path.join(out_dir, f"firm_layer_connectivity_{args.layer}.parquet")

    df = pd.read_parquet(wide_path)

    pairs = list(PAIR_LABELS.values())  # ["0708","0809","0910","1011"]

    # Build individual year-pair columns with standardised names
    for prefix, out_stub in [
        ("ratio_total",          "layer_treat_pw"),
        ("ratio_same",           "sametreat_pw"),
        ("ratio_cross",          "crosstreat_pw"),
        ("totalflows_layer_pw",  "totalflows_layer_pw"),
    ]:
        pair_cols = [f"{prefix}_{p}" for p in pairs]
        # Rename to {out_stub}_{pair} for clarity in output
        rename_map = {c: f"{out_stub}_{p}" for c, p in zip(pair_cols, pairs) if c in df.columns}
        df = df.rename(columns=rename_map)
        renamed_cols = [f"{out_stub}_{p}" for p in pairs]
        df = nan_aware_avg(df, renamed_cols, f"{out_stub}_n")

    print(f"Rows: {len(df):,}")
    print("Columns:", list(df.columns))

    # Save as parquet (fast, for Python reads) + DTA (for Stata do-file)
    df.to_parquet(out_parquet_path, index=False)
    df.to_stata(out_path, write_index=False, version=118)
    print(f"Saved to {out_parquet_path} and {out_path}")


if __name__ == "__main__":
    main()
