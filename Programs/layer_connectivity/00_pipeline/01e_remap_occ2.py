#!/usr/bin/env python3
"""
Remap occ4 transitions to occ2 (2-bin occupation).

occ4 → occ2 mapping:
    1_mgr   → high_skill   (managers)
    23_high → high_skill   (frontline high-skill)
    4_bur   → low_skill    (bureaucrat lower)
    5p_low  → low_skill    (frontline low-skill)

Reads:  Data/layer_connectivity/transitions_base/transitions_occ4.parquet
Writes: Data/layer_connectivity/transitions_base/transitions_occ2.parquet

Usage:
    python 01e_remap_occ2.py
"""

import os
import sys
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from layer_config import OUT_BASE

REMAP = {
    "1_mgr":   "high_skill",
    "23_high": "high_skill",
    "4_bur":   "low_skill",
    "5p_low":  "low_skill",
}

in_path  = os.path.join(OUT_BASE, "transitions_base", "transitions_occ4.parquet")
out_path = os.path.join(OUT_BASE, "transitions_base", "transitions_occ2.parquet")

print(f"Reading {in_path} ...")
df = pd.read_parquet(in_path)
print(f"  Shape: {df.shape}")
print(f"  layer_id_focal values: {sorted(df['layer_id_focal'].dropna().unique())}")

df["layer_id_focal"]   = df["layer_id_focal"].map(REMAP)
df["layer_id_contact"] = df["layer_id_contact"].map(REMAP)

# Drop rows where either layer is unmapped (shouldn't happen with full occ4 coverage)
before = len(df)
df = df.dropna(subset=["layer_id_focal", "layer_id_contact"])
if before != len(df):
    print(f"  Dropped {before - len(df)} rows with unmapped layers")

print(f"  occ2 layer_id_focal values: {sorted(df['layer_id_focal'].unique())}")
print(f"  occ2 layer_id_contact values: {sorted(df['layer_id_contact'].unique())}")
print(f"  Final shape: {df.shape}")

df.to_parquet(out_path, index=False)
print(f"Saved: {out_path}")
