#!/usr/bin/env python3
"""
Build firm × layer × year outcomes for occ2c by aggregating occ4 outcomes.

occ4 → occ2c mapping:
    1_mgr + 23_high + 4_bur → upper_skill
    5p_low                  → low_skill

Reads:  Data/layer_connectivity/firm_layer_outcomes_occ4.dta
Writes: Data/layer_connectivity/firm_layer_outcomes_occ2c.dta

Usage:
    python 2077_prep_occ2c_outcomes.py
"""

import os, sys
import numpy as np
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from layer_config import OUT_BASE

REMAP = {
    "1_mgr":   "upper_skill",
    "23_high": "upper_skill",
    "4_bur":   "upper_skill",
    "5p_low":  "low_skill",
}

in_path  = os.path.join(OUT_BASE, "firm_layer_outcomes_occ4.dta")
out_path = os.path.join(OUT_BASE, "firm_layer_outcomes_occ2c.dta")

print(f"Reading {in_path} ...")
df = pd.read_stata(in_path)
df["layer_id_occ2c"] = df["layer_id"].map(REMAP)

# Level wages for weighted average
df["r_remdezr_layer"] = np.exp(df["lr_remdezr_layer"].where(df["lr_remdezr_layer"].notna()))
df["wage_emp_product"] = df["r_remdezr_layer"] * df["layer_emp"]

key = ["identificad", "layer_id_occ2c", "year"]
agg = df.groupby(key, observed=True).agg(
    layer_emp    = ("layer_emp",        "sum"),
    wage_emp_sum = ("wage_emp_product", "sum"),
    wage_obs     = ("r_remdezr_layer",  "count"),
).reset_index()

agg["l_layer_emp"] = np.where(agg["layer_emp"] > 0, np.log(agg["layer_emp"]), np.nan)
agg["r_remdezr_layer"] = np.where(
    (agg["wage_obs"] > 0) & (agg["layer_emp"] > 0),
    agg["wage_emp_sum"] / agg["layer_emp"], np.nan)
agg["lr_remdezr_layer"] = np.log(agg["r_remdezr_layer"])
agg = agg.drop(columns=["wage_emp_sum", "wage_obs", "r_remdezr_layer"])
agg = agg.rename(columns={"layer_id_occ2c": "layer_id"})

print(f"  occ2c shape: {agg.shape}")
print(f"  layer_id values: {sorted(agg['layer_id'].unique())}")
for lv in ["upper_skill", "low_skill"]:
    s = agg[agg["layer_id"] == lv]
    print(f"  {lv}: {s['identificad'].nunique():,} firms, avg emp={s['layer_emp'].mean():.1f}")

agg.to_stata(out_path, write_index=False, version=118)
print(f"Saved: {out_path}")
