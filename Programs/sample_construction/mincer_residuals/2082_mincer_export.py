"""
2082_mincer_export.py
=====================
Exports the 9 required columns from worker_panel_lagos.parquet to a Stata DTA
file for use in the Stata Mincer residualization (2083_mincer_residuals.do).

Computes lr_hourly = log(remdezr / (horascontr * 4.33)) when both > 0.

Output
------
Data/CBA_RAIS_firm_level/worker_panel_mincer.dta
  ~1-2 GB, 18M rows x 10 columns (9 original + lr_hourly)

Runtime: ~1 min (40s write)
"""

import os
import time
import numpy as np
import pandas as pd

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
PROJECT = "/kellogg/proj/lgg3230/UnionSpill"
PARQUET  = os.path.join(PROJECT, "Data/CBA_RAIS_firm_level/worker_panel_lagos.parquet")
OUT_DTA  = os.path.join(PROJECT, "Data/CBA_RAIS_firm_level/worker_panel_mincer.dta")

# ---------------------------------------------------------------------------
# Load (only columns needed for Mincer spec)
# ---------------------------------------------------------------------------
cols = [
    "identificad", "remdezr", "horascontr",
    "genero", "grinstrucao", "race_group",
    "lr_remdezr", "year", "age"
]

t0 = time.time()
print(f"Reading {PARQUET} ...")
df = pd.read_parquet(PARQUET, columns=cols)
print(f"  Rows: {len(df):,}   Columns: {df.shape[1]}   ({time.time()-t0:.1f}s)")

# ---------------------------------------------------------------------------
# Log hourly wage: remdezr / (horascontr * 4.33), requires both > 0
# ---------------------------------------------------------------------------
df["lr_hourly"] = np.where(
    (df["horascontr"] > 0) & (df["remdezr"] > 0),
    np.log(df["remdezr"] / (df["horascontr"] * 4.33)),
    np.nan
)
n_hourly = df["lr_hourly"].notna().sum()
print(f"  lr_hourly non-missing: {n_hourly:,} ({100*n_hourly/len(df):.1f}%)")

# ---------------------------------------------------------------------------
# Export to Stata format
# ---------------------------------------------------------------------------
print(f"\nWriting {OUT_DTA} ...")
t1 = time.time()
df.to_stata(OUT_DTA, write_index=False, version=118)
size_gb = os.path.getsize(OUT_DTA) / 1e9
print(f"  Done in {time.time()-t1:.1f}s   File size: {size_gb:.2f} GB")
print(f"Total elapsed: {(time.time()-t0)/60:.1f} min")
