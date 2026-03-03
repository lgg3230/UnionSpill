"""
DEPRECATED — superseded by 011f_mincer_residuals.do (Stata/reghdfe).
The Stata version implements the identical specification natively via
reghdfe's varying-slopes absorb(), is ~3x faster, and requires no
cell-by-cell OLS workaround. Do not run this script for new results.

011f_mincer_residuals.py
========================
Residualizes log December wages AND log hourly wages on worker characteristics
following Neri (Gui_coding/Residual_construction.R).

Specification (one OLS per race × education × gender × year cell):
    outcome = β₀(cell) + β₁(cell)·age + β₂(cell)·age² + β₃(cell)·age³ + β₄(cell)·age⁴ + ε

Equivalent to the fixest R formula:
    outcome ~ 1 | race_group^grinstrucao^genero^year[age1, age2, age3, age4]

Each cell gets its own intercept and its own 4th-degree age polynomial (varying
slopes). No occupation, tenure, or contract-type dummies.

Missing-value handling matches R's drop_na(required_vars):
    drop rows where outcome, grinstrucao, race_group, genero, or age is NA.

Hourly wage: remdezr / (horascontr * 4.33), requires remdezr > 0 and horascontr > 0.

Output
------
Data/CBA_RAIS_firm_level/mincer_residuals_firm_year.csv
  identificad, year
  lr_remdezr_resid      (mean residual per firm-year, December wage)
  lr_remdezr_mean       (mean raw log December wage per firm-year)
  n_workers_dezr        (worker count for December wage regression)
  lr_hourly_resid       (mean residual per firm-year, hourly wage)
  lr_hourly_mean        (mean raw log hourly wage per firm-year)
  n_workers_hourly      (worker count for hourly wage regression)
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
OUT_CSV  = os.path.join(PROJECT, "Data/CBA_RAIS_firm_level/mincer_residuals_firm_year.csv")

# ---------------------------------------------------------------------------
# Load (only columns used in Gui's specification)
# ---------------------------------------------------------------------------
t0 = time.time()
print(f"Reading {PARQUET} ...")
df = pd.read_parquet(PARQUET, columns=[
    "identificad", "remdezr", "horascontr",
    "genero", "grinstrucao", "race_group",
    "lr_remdezr", "year", "age"
])
print(f"  Rows: {len(df):,}   Columns: {df.shape[1]}   ({time.time()-t0:.1f}s)")

# ---------------------------------------------------------------------------
# Age polynomials (continuous, matching Gui's age1..age4)
# ---------------------------------------------------------------------------
df["age_num"] = pd.to_numeric(df["age"], errors="coerce")
df["age1"] = df["age_num"]
df["age2"] = df["age_num"] ** 2
df["age3"] = df["age_num"] ** 3
df["age4"] = df["age_num"] ** 4

# ---------------------------------------------------------------------------
# Log hourly wage (same formula as before)
# ---------------------------------------------------------------------------
df["lr_hourly"] = np.where(
    (df["horascontr"] > 0) & (df["remdezr"] > 0),
    np.log(df["remdezr"] / (df["horascontr"] * 4.33)),
    np.nan
)

# ---------------------------------------------------------------------------
# Required variables for missing-value filter (matches Gui's required_vars)
# ---------------------------------------------------------------------------
REQUIRED_VARS = ["grinstrucao", "race_group", "genero", "age_num"]

# ---------------------------------------------------------------------------
# Helper: residualize outcome within each (race × educ × gender × year) cell.
# Runs OLS of outcome on [1, age, age², age³, age⁴] within each cell — the
# cell-by-cell equivalent of fixest's varying slopes FE.
# ---------------------------------------------------------------------------
def run_mincer(df_full, outcome, label):
    print(f"\n{'='*60}")
    print(f"Outcome: {label}")
    print(f"{'='*60}")

    # Drop rows with missing outcome or FE / polynomial inputs
    # Mirrors R: filter(!is.na(outcome_var)) %>% drop_na(required_vars)
    n_before = len(df_full)
    df_est = df_full.dropna(subset=[outcome] + REQUIRED_VARS).copy()
    df_est = df_est.reset_index(drop=True)
    print(f"  Dropped {n_before - len(df_est):,} rows with missing vars")
    print(f"  Estimation sample: {len(df_est):,} rows")

    # Cell identifier: race_group × grinstrucao × genero × year
    df_est["cell"] = (
        df_est["race_group"].astype(str) + "_" +
        df_est["grinstrucao"].astype(int).astype(str) + "_" +
        df_est["genero"].astype(int).astype(str) + "_" +
        df_est["year"].astype(str)
    )
    n_cells = df_est["cell"].nunique()
    print(f"  Spec : {outcome} ~ 1 | race_group^grinstrucao^genero^year[age1,age2,age3,age4]")
    print(f"  Cells: {n_cells:,}")

    # Pre-build design matrix (intercept + age polynomial) and outcome vector
    X = np.column_stack([
        np.ones(len(df_est), dtype=np.float64),
        df_est["age1"].values,
        df_est["age2"].values,
        df_est["age3"].values,
        df_est["age4"].values,
    ])
    y = df_est[outcome].values.astype(np.float64)
    resid = np.full(len(df_est), np.nan, dtype=np.float64)

    t1 = time.time()
    n_singleton = 0
    cell_groups = df_est.groupby("cell").groups  # {cell: Int64Index}

    for cell_name, grp_idx in cell_groups.items():
        idx = grp_idx.values
        if len(idx) < 6:          # fewer obs than parameters → skip (singleton)
            n_singleton += len(idx)
            continue
        beta, _, _, _ = np.linalg.lstsq(X[idx], y[idx], rcond=None)
        resid[idx] = y[idx] - X[idx] @ beta

    print(f"  Cell-by-cell OLS done in {(time.time()-t1)/60:.2f} min")
    print(f"  Rows dropped (singleton cells, <6 obs): {n_singleton:,}")

    df_est[f"{outcome}_resid"] = resid
    df_kept = df_est.dropna(subset=[f"{outcome}_resid"])
    print(f"  Rows with residuals: {len(df_kept):,}")
    print(f"  Residual mean : {df_kept[f'{outcome}_resid'].mean():.6f}  (should be ~0)")
    print(f"  Residual std  : {df_kept[f'{outcome}_resid'].std():.4f}")
    print(f"  Raw wage std  : {df_kept[outcome].std():.4f}")

    # Collapse to firm × year
    print("\n  Collapsing to identificad × year ...")
    firm_year = (
        df_kept
        .groupby(["identificad", "year"], observed=True)
        .agg(
            **{f"{outcome}_resid": (f"{outcome}_resid", "mean")},
            **{f"{outcome}_mean":  (outcome,             "mean")},
            **{f"n_workers":       (outcome,             "count")},
        )
        .reset_index()
        .rename(columns={"n_workers": f"n_workers_{label}"})
    )
    print(f"  Firm-year cells: {len(firm_year):,}")
    print(f"  Unique firms   : {firm_year['identificad'].nunique():,}")
    print(f"  Years covered  : {sorted(firm_year['year'].unique())}")
    print(f"\n  Collapsed {outcome}_resid stats:")
    print(firm_year[f"{outcome}_resid"].describe().round(4))

    return firm_year


# ---------------------------------------------------------------------------
# Run for December wage
# ---------------------------------------------------------------------------
fyr_dezr = run_mincer(df, "lr_remdezr", "dezr")

# ---------------------------------------------------------------------------
# Run for hourly wage
# ---------------------------------------------------------------------------
fyr_hourly = run_mincer(df, "lr_hourly", "hourly")

# ---------------------------------------------------------------------------
# Merge and save
# ---------------------------------------------------------------------------
print("\nMerging and saving ...")
out = fyr_dezr.merge(fyr_hourly, on=["identificad", "year"], how="outer")

out.to_csv(OUT_CSV, index=False)
size_mb = os.path.getsize(OUT_CSV) / 1e6
print(f"Done. File size: {size_mb:.1f} MB   Rows: {len(out):,}")
print(f"Total elapsed: {(time.time()-t0)/60:.1f} min")
