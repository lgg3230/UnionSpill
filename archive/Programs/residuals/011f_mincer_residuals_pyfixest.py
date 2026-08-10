"""
011f_mincer_residuals_pyfixest.py
==================================
Python equivalent of the Mincer residualization (011f_mincer_residuals.do).

Specification (same as Stata):
  outcome ~ 1 | cell_id[age1, age2, age3, age4]
  i.e., cell-specific intercept + cell-specific age polynomial slopes

  where cell_id = race_group x grinstrucao x genero x year

NOTE on pyfixest varying slopes
---------------------------------
pyfixest 0.40 does NOT implement varying slopes (fe_var[slope_var]) in the FE
absorb formula. The wrap_factorize() helper splits on '+' and wraps each term
with factorize(), so cell_id[age1] → factorize(cell_id[age1]) which formulaic
evaluates as pandas indexing, not a varying slope.

The correct Python equivalent is cell-by-cell OLS (numpy lstsq), which is
exactly what R's fixest and Stata's reghdfe do internally when absorbing
cell_id#c.ageK terms. Results are mathematically identical.

Runtime comparison (timed):
  - Stata reghdfe x2:   see log
  - Python numpy x2:    see log

Output
------
Data/CBA_RAIS_firm_level/mincer_residuals_firm_year_python.csv
  identificad, year,
  lr_remdezr_resid, lr_remdezr_mean, n_workers_dezr,
  lr_hourly_resid,  lr_hourly_mean,  n_workers_hourly
"""

import time
import os
import numpy as np
import pandas as pd

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
PROJECT = "/kellogg/proj/lgg3230/UnionSpill"
PARQUET  = f"{PROJECT}/Data/CBA_RAIS_firm_level/worker_panel_lagos.parquet"
OUT_CSV  = f"{PROJECT}/Data/CBA_RAIS_firm_level/mincer_residuals_firm_year_python.csv"

t_total = time.time()

# ---------------------------------------------------------------------------
# Load
# ---------------------------------------------------------------------------
cols = [
    "identificad", "remdezr", "horascontr",
    "genero", "grinstrucao", "race_group",
    "lr_remdezr", "year", "age"
]

print(f"Reading {PARQUET} ...")
t0 = time.time()
df = pd.read_parquet(PARQUET, columns=cols)
print(f"  Rows: {len(df):,}   ({time.time()-t0:.1f}s)")

# ---------------------------------------------------------------------------
# Log hourly wage
# ---------------------------------------------------------------------------
df["lr_hourly"] = np.where(
    (df["horascontr"] > 0) & (df["remdezr"] > 0),
    np.log(df["remdezr"] / (df["horascontr"] * 4.33)),
    np.nan
)

# ---------------------------------------------------------------------------
# Sample restriction (mirrors Stata: keep if !missing(grinstrucao, genero, age)
#                                    drop if race_group == "" | race_group == ".")
# ---------------------------------------------------------------------------
df = df.dropna(subset=["grinstrucao", "genero", "age"])
df = df[df["race_group"].notna() & (df["race_group"] != "") & (df["race_group"] != ".")]
print(f"  Rows after sample restriction: {len(df):,}")

# ---------------------------------------------------------------------------
# Age polynomials
# ---------------------------------------------------------------------------
df["age"] = pd.to_numeric(df["age"], errors="coerce")
df = df.dropna(subset=["age"])
df["age1"] = df["age"]
df["age2"] = df["age"] ** 2
df["age3"] = df["age"] ** 3
df["age4"] = df["age"] ** 4

# ---------------------------------------------------------------------------
# Cell identifier: race_group x grinstrucao x genero x year
# (mirrors Stata: egen cell_id = group(race_group grinstrucao genero year))
# ---------------------------------------------------------------------------
cell_key = (
    df["race_group"].astype(str) + "_" +
    df["grinstrucao"].astype(str) + "_" +
    df["genero"].astype(str) + "_" +
    df["year"].astype(str)
)
df["cell_id"] = pd.factorize(cell_key)[0]
n_cells = df["cell_id"].nunique()
print(f"  Number of cells: {n_cells:,}")

# ---------------------------------------------------------------------------
# Helper: cell-by-cell OLS (equivalent to reghdfe varying-slopes absorb)
#
# For each cell c, estimate:
#   outcome_i = α_c + β1_c*age1_i + β2_c*age2_i + β3_c*age3_i + β4_c*age4_i + ε_i
# by OLS, save ε_i as the residual.
#
# This is mathematically identical to:
#   reghdfe outcome, absorb(cell_id cell_id#c.age1 ... cell_id#c.age4)
# ---------------------------------------------------------------------------
AGE_COLS = ["age1", "age2", "age3", "age4"]

def run_mincer_numpy(df_full, outcome, label):
    print(f"\n{'='*60}")
    print(f"Outcome: {label}")
    print(f"{'='*60}")

    # Drop rows with missing outcome (mirrors Stata: if !missing(outcome))
    df_sub = df_full.dropna(subset=[outcome]).copy().reset_index(drop=True)
    n = len(df_sub)
    print(f"  Estimation sample: {n:,} rows")
    print(f"  Spec: {outcome} ~ 1 + age1 + age2 + age3 + age4 (within each cell)")

    # Build design matrix once (intercept + 4 age polynomials)
    X_full = np.column_stack([
        np.ones(n, dtype=np.float64),
        df_sub["age1"].values,
        df_sub["age2"].values,
        df_sub["age3"].values,
        df_sub["age4"].values,
    ])
    y_full = df_sub[outcome].values.astype(np.float64)
    resid  = np.full(n, np.nan, dtype=np.float64)

    t_reg = time.time()
    print(f"  TIMING: {label} cell-by-cell OLS started: {time.strftime('%Y-%m-%d %H:%M:%S')}")

    cell_ids  = df_sub["cell_id"].values
    n_skip    = 0
    # Group row indices by cell_id (faster than groupby for pure numpy)
    sort_idx  = np.argsort(cell_ids, kind="stable")
    sorted_cells = cell_ids[sort_idx]
    boundaries   = np.where(np.diff(sorted_cells))[0] + 1
    groups       = np.split(sort_idx, boundaries)

    for idx in groups:
        if len(idx) < 6:          # fewer obs than parameters → skip (singleton)
            n_skip += len(idx)
            continue
        Xi = X_full[idx]
        yi = y_full[idx]
        beta, _, _, _ = np.linalg.lstsq(Xi, yi, rcond=None)
        resid[idx] = yi - Xi @ beta

    elapsed_reg = time.time() - t_reg
    print(f"  TIMING: {label} cell-by-cell OLS finished: {time.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"  TIMING: {label} regression time: {elapsed_reg/60:.2f} min ({elapsed_reg:.1f}s)")
    print(f"  Rows skipped (singleton cells, <6 obs): {n_skip:,}")

    df_sub[f"{outcome}_resid"] = resid
    df_kept = df_sub.dropna(subset=[f"{outcome}_resid"])
    print(f"  Obs in regression: {len(df_kept):,}")
    resid_mean = df_kept[f"{outcome}_resid"].mean()
    resid_std  = df_kept[f"{outcome}_resid"].std()
    print(f"  Residual mean : {resid_mean:.6f}  (should be ~0)")
    print(f"  Residual std  : {resid_std:.4f}")

    # Collapse to firm x year
    print("  Collapsing to firm x year ...")
    firm_year = (
        df_kept
        .groupby(["identificad", "year"], observed=True)
        .agg(
            **{f"{outcome}_resid":        (f"{outcome}_resid", "mean")},
            **{f"{outcome}_mean":         (outcome,            "mean")},
            **{f"n_workers_{label}":      (outcome,            "count")},
        )
        .reset_index()
    )
    print(f"  Firm-year rows: {len(firm_year):,}")
    return firm_year

# ---------------------------------------------------------------------------
# Run regressions
# ---------------------------------------------------------------------------
fyr_dezr   = run_mincer_numpy(df, "lr_remdezr", "dezr")
fyr_hourly = run_mincer_numpy(df, "lr_hourly",  "hourly")

# ---------------------------------------------------------------------------
# Merge and save
# ---------------------------------------------------------------------------
print("\nMerging and saving ...")
out = fyr_dezr.merge(fyr_hourly, on=["identificad", "year"], how="outer")
out.to_csv(OUT_CSV, index=False)
size_mb = os.path.getsize(OUT_CSV) / 1e6
print(f"Done. File size: {size_mb:.1f} MB   Rows: {len(out):,}")
print(f"Total elapsed: {(time.time()-t_total)/60:.1f} min")
