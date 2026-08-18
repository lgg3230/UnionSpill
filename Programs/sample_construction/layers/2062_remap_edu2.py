#!/usr/bin/env python3
"""
Script 2062: Derive edu2 transitions from edu transitions via layer remap.

edu  (3 bins): 0_no_hs / 1_hs / 2_higher
edu2 (2 bins): no_hs   / has_hs  (collapses 1_hs and 2_higher)

Reads  transitions_edu.parquet  (must exist — run 2061_build_transitions.py --layer edu first)
Writes transitions_edu2.parquet

Usage:
    python 2062_remap_edu2.py
"""

import os
import sys
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from layer_config import OUT_BASE

REMAP = {
    "0_no_hs":  "no_hs",
    "1_hs":     "has_hs",
    "2_higher": "has_hs",
}

def main():
    transitions_dir = os.path.join(OUT_BASE, "transitions_base")
    in_path  = os.path.join(transitions_dir, "transitions_edu.parquet")
    out_path = os.path.join(transitions_dir, "transitions_edu2.parquet")

    print(f"Reading {in_path}...")
    df = pd.read_parquet(in_path)
    print(f"  Rows: {len(df):,}")

    df["layer_id_focal"]   = df["layer_id_focal"].map(REMAP)
    df["layer_id_contact"] = df["layer_id_contact"].map(REMAP)  # NaN stays NaN

    # Drop rows where focal layer is unmapped (shouldn't happen, but guard)
    n_before = len(df)
    df = df[df["layer_id_focal"].notna()]
    if len(df) < n_before:
        print(f"  Dropped {n_before - len(df):,} rows with unmapped focal layer")

    print(f"  edu2 layer counts:\n{df['layer_id_focal'].value_counts()}")
    print(f"Saving to {out_path}...")
    df.to_parquet(out_path, index=False)
    print("Done.")


if __name__ == "__main__":
    main()
