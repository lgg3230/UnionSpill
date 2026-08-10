#!/usr/bin/env python3
"""
Remap occ4 transitions to occ2c (occ2_C division).

occ4 → occ2c mapping:
    1_mgr   → upper_skill   (managers)
    23_high → upper_skill   (frontline high-skill)
    4_bur   → upper_skill   (bureaucrat lower)
    5p_low  → low_skill     (frontline low-skill only)

Coverage: 3,638 / 4,196 spillover firms have both layers (86.7%).

Reads:  Data/layer_connectivity/transitions_base/transitions_occ4.parquet
Writes: Data/layer_connectivity/transitions_base/transitions_occ2c.parquet

Usage:
    python 01f_remap_occ2c.py
"""

import os, sys
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from layer_config import OUT_BASE

REMAP = {
    "1_mgr":   "upper_skill",
    "23_high": "upper_skill",
    "4_bur":   "upper_skill",
    "5p_low":  "low_skill",
}

in_path  = os.path.join(OUT_BASE, "transitions_base", "transitions_occ4.parquet")
out_path = os.path.join(OUT_BASE, "transitions_base", "transitions_occ2c.parquet")

print(f"Reading {in_path} ...")
df = pd.read_parquet(in_path)
print(f"  Shape: {df.shape}")

df["layer_id_focal"]   = df["layer_id_focal"].map(REMAP)
df["layer_id_contact"] = df["layer_id_contact"].map(REMAP)

before = len(df)
df = df.dropna(subset=["layer_id_focal", "layer_id_contact"])
if before != len(df):
    print(f"  Dropped {before - len(df)} rows with unmapped layers")

print(f"  layer_id_focal values: {sorted(df['layer_id_focal'].unique())}")
print(f"  Final shape: {df.shape}")

df.to_parquet(out_path, index=False)
print(f"Saved: {out_path}")
