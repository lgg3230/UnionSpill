#!/usr/bin/env python3
"""
Build firm × layer × year outcomes for occ2 by aggregating occ4 outcomes.

occ4 → occ2 mapping:
    1_mgr + 23_high → high_skill
    4_bur + 5p_low  → low_skill

For employment: sum across sub-layers.
For wages: weighted average by layer employment (ln-wage back-transformed,
           re-averaged, then re-logged).

Reads:  Data/layer_connectivity/firm_layer_outcomes_occ4.dta
Writes: Data/layer_connectivity/firm_layer_outcomes_occ2.dta

Usage:
    python 06c_prep_occ2_outcomes.py
"""

import os
import sys
import numpy as np
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from layer_config import OUT_BASE

REMAP = {
    "1_mgr":   "high_skill",
    "23_high": "high_skill",
    "4_bur":   "low_skill",
    "5p_low":  "low_skill",
}

in_path  = os.path.join(OUT_BASE, "firm_layer_outcomes_occ4.dta")
out_path = os.path.join(OUT_BASE, "firm_layer_outcomes_occ2.dta")

print(f"Reading {in_path} ...")
df = pd.read_stata(in_path)
print(f"  Shape: {df.shape}")
print(f"  Columns: {list(df.columns)}")

df["layer_id_occ2"] = df["layer_id"].map(REMAP)

# ── Employment: sum across sub-layers ─────────────────────────────────────────
# layer_emp: count of workers in layer
# l_layer_emp: log(layer_emp) — recompute after aggregation
emp_cols = [c for c in df.columns if c == "layer_emp"]

# ── Wage aggregation: employment-weighted average of level wages ───────────────
# lr_remdezr_layer = log real wage (December, deflated)
# Back-transform → level → weighted avg → re-log

# Compute level wages (needed for weighted average)
df["r_remdezr_layer"] = np.exp(df["lr_remdezr_layer"].where(df["lr_remdezr_layer"].notna()))

# Numerator for weighted average: level_wage × employment
df["wage_emp_product"] = df["r_remdezr_layer"] * df["layer_emp"]

key = ["identificad", "layer_id_occ2", "year"]

agg = df.groupby(key, observed=True).agg(
    layer_emp       = ("layer_emp",         "sum"),
    wage_emp_sum    = ("wage_emp_product",   "sum"),
    wage_obs        = ("r_remdezr_layer",    "count"),
).reset_index()

# Re-log employment (NaN if zero)
agg["l_layer_emp"] = np.where(agg["layer_emp"] > 0, np.log(agg["layer_emp"]), np.nan)

# Weighted average wage (NaN if no wage observations)
agg["r_remdezr_layer"] = np.where(
    (agg["wage_obs"] > 0) & (agg["layer_emp"] > 0),
    agg["wage_emp_sum"] / agg["layer_emp"],
    np.nan,
)
agg["lr_remdezr_layer"] = np.log(agg["r_remdezr_layer"])

# Drop helper columns
agg = agg.drop(columns=["wage_emp_sum", "wage_obs", "r_remdezr_layer"])
agg = agg.rename(columns={"layer_id_occ2": "layer_id"})

print(f"  occ2 shape: {agg.shape}")
print(f"  layer_id values: {sorted(agg['layer_id'].unique())}")
print(f"  Years: {sorted(agg['year'].unique())}")
print(f"  Sample rows:")
print(agg.head(4).to_string(index=False))

agg.to_stata(out_path, write_index=False, version=118)
print(f"\nSaved: {out_path}")
