"""
011f_mincer_residuals.py
========================
Residualizes log December wages AND log hourly wages on worker characteristics
(all × year) using the full Mincer fixed-effects specification, then collapses
to firm × year means.

Specification (all absorbed as FE, no regressors on the RHS):
    outcome ~ 1
    | educ_bin^year + race_group^year + age_bin^year + tenure_bin^year
    + d_male^year + hours_ge40^year + d_disabled^year
    + d_rural^year + d_apprentice^year + d_fixed_term^year
    + d_public^year + d_other_contract^year
    + ocup4^year

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
import pyfixest as pf

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
PROJECT = "/kellogg/proj/lgg3230/UnionSpill"
PARQUET  = os.path.join(PROJECT, "Data/CBA_RAIS_firm_level/worker_panel_lagos.parquet")
OUT_CSV  = os.path.join(PROJECT, "Data/CBA_RAIS_firm_level/mincer_residuals_firm_year.csv")

# ---------------------------------------------------------------------------
# Load
# ---------------------------------------------------------------------------
t0 = time.time()
print(f"Reading {PARQUET} ...")
df = pd.read_parquet(PARQUET)
print(f"  Rows: {len(df):,}   Columns: {df.shape[1]}   ({time.time()-t0:.1f}s)")

# ---------------------------------------------------------------------------
# FE variables — convert to strings so pyfixest treats them as categoricals
# ---------------------------------------------------------------------------
FE_VARS = [
    "educ_bin",
    "race_group",
    "age_bin",
    "tenure_bin",
    "d_male",
    "hours_ge40",
    "d_disabled",
    "d_rural",
    "d_apprentice",
    "d_fixed_term",
    "d_public",
    "d_other_contract",
    "ocup4",
]

for col in ["d_male", "hours_ge40", "d_disabled",
            "d_rural", "d_apprentice", "d_fixed_term",
            "d_public", "d_other_contract", "ocup4"]:
    df[col] = df[col].astype(str)

df["year_str"] = df["year"].astype(str)

# ---------------------------------------------------------------------------
# Construct log hourly wage
# ---------------------------------------------------------------------------
df["lr_hourly"] = np.where(
    (df["horascontr"] > 0) & (df["remdezr"] > 0),
    np.log(df["remdezr"] / (df["horascontr"] * 4.33)),
    np.nan
)

# ---------------------------------------------------------------------------
# FE formula (shared across both outcomes)
# ---------------------------------------------------------------------------
fe_terms = (
    "educ_bin^year_str + race_group^year_str + age_bin^year_str "
    "+ tenure_bin^year_str + d_male^year_str + hours_ge40^year_str "
    "+ d_disabled^year_str + d_rural^year_str + d_apprentice^year_str "
    "+ d_fixed_term^year_str + d_public^year_str + d_other_contract^year_str "
    "+ ocup4^year_str"
)

# ---------------------------------------------------------------------------
# Helper: run one Mincer regression and return firm-year collapsed residuals
# ---------------------------------------------------------------------------
def run_mincer(df_full, outcome, label):
    print(f"\n{'='*60}")
    print(f"Outcome: {label}")
    print(f"{'='*60}")

    # Drop missing outcome, FE vars, and ocup4 NA strings
    n_before = len(df_full)
    df_est = df_full.dropna(subset=[outcome] + FE_VARS).copy()
    df_est = df_est[df_est["ocup4"] != "<NA>"].copy()
    df_est = df_est.reset_index(drop=True)
    print(f"  Dropped {n_before - len(df_est):,} rows with missing vars")
    print(f"  Estimation sample: {len(df_est):,} rows")

    formula = f"{outcome} ~ 1 | {fe_terms}"
    print(f"  Formula: {formula}\n")

    print("  Running feols ...")
    t1 = time.time()
    model = pf.feols(formula, data=df_est, vcov="hetero")
    print(f"  feols done in {(time.time()-t1)/60:.1f} min")

    # Extract residuals
    dropped = set(model._na_index)
    kept_idx = [i for i in range(len(df_est)) if i not in dropped]
    df_kept = df_est.iloc[kept_idx].copy()
    df_kept[f"{outcome}_resid"] = model.resid()

    print(f"  Dropped rows (NA + singletons): {len(dropped):,}")
    print(f"  Estimation rows (after drop): {len(df_kept):,}")
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
out = fyr_dezr.merge(
    fyr_hourly.drop(columns=["year"]),  # identificad + year already in dezr
    on="identificad",
    how="outer",
    suffixes=("", "_dup")
)
# Re-merge properly on both keys
out = fyr_dezr.merge(
    fyr_hourly,
    on=["identificad", "year"],
    how="outer"
)

out.to_csv(OUT_CSV, index=False)
size_mb = os.path.getsize(OUT_CSV) / 1e6
print(f"Done. File size: {size_mb:.1f} MB   Rows: {len(out):,}")
print(f"Total elapsed: {(time.time()-t0)/60:.1f} min")
