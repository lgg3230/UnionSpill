"""
011g_mincer_residuals_variants.py
==================================
Computes Mincer residuals for four additional cell specifications beyond the
base (race × educ × gender × year):

  - +4-dig. occ  : base cell × 4-digit ocup2002
  - +Tenure bins : base cell × tenure_bin
  - +2-dig. occ  : base cell × 2-digit ocup2002 (first two digits)
  - +Tenure poly : base cell, within-cell OLS adds quartic tenure polynomial

Uses the same numpy cell-by-cell OLS as 011f_mincer_residuals_pyfixest.py.
Rows with missing ocup2002 / tenure are dropped only for the relevant
variant (they still enter the base and other variants).

Outputs:
  Data/CBA_RAIS_firm_level/mincer_residuals_firm_year_ocup.csv
  Data/CBA_RAIS_firm_level/mincer_residuals_firm_year_tenure.csv
  Data/CBA_RAIS_firm_level/mincer_residuals_firm_year_ocup2.csv
  Data/CBA_RAIS_firm_level/mincer_residuals_firm_year_tenpoly.csv
"""

import time
import os
import numpy as np
import pandas as pd
import subprocess

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
PROJECT          = "/kellogg/proj/lgg3230/UnionSpill"
PARQUET          = f"{PROJECT}/Data/CBA_RAIS_firm_level/worker_panel_lagos.parquet"
OUT_CSV_OCUP     = f"{PROJECT}/Data/CBA_RAIS_firm_level/mincer_residuals_firm_year_ocup.csv"
OUT_CSV_TENURE   = f"{PROJECT}/Data/CBA_RAIS_firm_level/mincer_residuals_firm_year_tenure.csv"
OUT_CSV_OCUP2    = f"{PROJECT}/Data/CBA_RAIS_firm_level/mincer_residuals_firm_year_ocup2.csv"
OUT_CSV_TENPOLY  = f"{PROJECT}/Data/CBA_RAIS_firm_level/mincer_residuals_firm_year_tenpoly.csv"

t_total = time.time()

# ---------------------------------------------------------------------------
# Load
# ---------------------------------------------------------------------------
cols = [
    "identificad", "remdezr", "horascontr",
    "genero", "grinstrucao", "race_group",
    "lr_remdezr", "year", "age",
    "ocup2002", "tenure_bin", "tempempr",
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
# Base sample restriction (mirrors 011f)
# ---------------------------------------------------------------------------
df = df.dropna(subset=["grinstrucao", "genero", "age"])
df = df[df["race_group"].notna() & (df["race_group"] != "") & (df["race_group"] != ".")]
df["age"] = pd.to_numeric(df["age"], errors="coerce")
df = df.dropna(subset=["age"])
print(f"  Rows after base sample restriction: {len(df):,}")

# ---------------------------------------------------------------------------
# Age polynomials
# ---------------------------------------------------------------------------
df["age1"] = df["age"]
df["age2"] = df["age"] ** 2
df["age3"] = df["age"] ** 3
df["age4"] = df["age"] ** 4

# ---------------------------------------------------------------------------
# Base cell key (race_group x grinstrucao x genero x year)
# ---------------------------------------------------------------------------
base_cell_key = (
    df["race_group"].astype(str) + "_" +
    df["grinstrucao"].astype(str) + "_" +
    df["genero"].astype(str) + "_" +
    df["year"].astype(str)
)

# ---------------------------------------------------------------------------
# Helper: cell-by-cell OLS (verbatim from 011f_mincer_residuals_pyfixest.py)
#
# For each cell c, estimate:
#   outcome_i = α_c + β1_c*age1_i + ... + β4_c*age4_i + ε_i
# Residuals ε_i are the Mincer residual for that worker-spell.
# Cells with fewer than 6 obs are skipped (same singleton threshold as 011f).
# ---------------------------------------------------------------------------

def run_mincer_numpy(df_full, outcome, label, extra_features=None):
    """
    Cell-by-cell OLS: outcome ~ 1 + age1 + age2 + age3 + age4 [+ extra_features].
    extra_features: list of column names in df_full to append to the regressor matrix.
    """
    print(f"\n{'='*60}")
    print(f"Outcome: {label}")
    print(f"{'='*60}")

    feature_cols = ["age1", "age2", "age3", "age4"] + (extra_features or [])
    df_sub = df_full.dropna(subset=[outcome] + (extra_features or [])).copy().reset_index(drop=True)
    n = len(df_sub)
    print(f"  Estimation sample: {n:,} rows")
    print(f"  Spec: {outcome} ~ 1 + {' + '.join(feature_cols)} (within each cell)")

    X_full = np.column_stack(
        [np.ones(n, dtype=np.float64)] + [df_sub[c].values.astype(np.float64) for c in feature_cols]
    )
    y_full = df_sub[outcome].values.astype(np.float64)
    resid  = np.full(n, np.nan, dtype=np.float64)

    t_reg = time.time()
    print(f"  TIMING: {label} cell-by-cell OLS started: {time.strftime('%Y-%m-%d %H:%M:%S')}")

    cell_ids     = df_sub["cell_id"].values
    n_skip       = 0
    sort_idx     = np.argsort(cell_ids, kind="stable")
    sorted_cells = cell_ids[sort_idx]
    boundaries   = np.where(np.diff(sorted_cells))[0] + 1
    groups       = np.split(sort_idx, boundaries)

    for idx in groups:
        if len(idx) < 6:
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

    print("  Collapsing to firm x year ...")
    firm_year = (
        df_kept
        .groupby(["identificad", "year"], observed=True)
        .agg(
            **{f"{outcome}_resid": (f"{outcome}_resid", "mean")},
            **{f"{outcome}_mean":  (outcome,            "mean")},
            **{f"n_workers_{label}": (outcome,          "count")},
        )
        .reset_index()
    )
    print(f"  Firm-year rows: {len(firm_year):,}")
    return firm_year


# ---------------------------------------------------------------------------
# VARIANT 1: +Occupation (base cell × ocup2002)
# ---------------------------------------------------------------------------
print("\n" + "="*60)
print("VARIANT 1: +Occupation (base x 4-digit ocup2002)")
print("="*60)

df_ocup = df.dropna(subset=["ocup2002"]).copy()
print(f"  Rows with non-missing ocup2002: {len(df_ocup):,}")
print(f"  Rows dropped (missing ocup2002): {len(df) - len(df_ocup):,}")

df_ocup["ocup2002_str"] = df_ocup["ocup2002"].astype(int).astype(str)
cell_key_ocup = (
    base_cell_key.loc[df_ocup.index] + "_" +
    df_ocup["ocup2002_str"]
)
df_ocup["cell_id"] = pd.factorize(cell_key_ocup)[0]
n_cells = df_ocup["cell_id"].nunique()
print(f"  Number of cells: {n_cells:,}")

fyr_dezr_ocup   = run_mincer_numpy(df_ocup, "lr_remdezr", "dezr")
fyr_hourly_ocup = run_mincer_numpy(df_ocup, "lr_hourly",  "hourly")

print("\nMerging and saving ocup variant ...")
out_ocup = fyr_dezr_ocup.merge(fyr_hourly_ocup, on=["identificad", "year"], how="outer")
out_ocup.to_csv(OUT_CSV_OCUP, index=False)
size_mb = os.path.getsize(OUT_CSV_OCUP) / 1e6
print(f"  Saved: {OUT_CSV_OCUP}  ({size_mb:.1f} MB, {len(out_ocup):,} rows)")


# ---------------------------------------------------------------------------
# VARIANT 2: +Tenure bins (base cell × tenure_bin)
# ---------------------------------------------------------------------------
print("\n" + "="*60)
print("VARIANT 2: +Tenure bins (base x tenure_bin)")
print("="*60)

df_tenure = df.dropna(subset=["tenure_bin"]).copy()
print(f"  Rows with non-missing tenure_bin: {len(df_tenure):,}")
print(f"  Rows dropped (missing tenure_bin): {len(df) - len(df_tenure):,}")

df_tenure["tenure_bin_str"] = df_tenure["tenure_bin"].astype(str)
cell_key_tenure = (
    base_cell_key.loc[df_tenure.index] + "_" +
    df_tenure["tenure_bin_str"]
)
df_tenure["cell_id"] = pd.factorize(cell_key_tenure)[0]
n_cells = df_tenure["cell_id"].nunique()
print(f"  Number of cells: {n_cells:,}")

fyr_dezr_tenure   = run_mincer_numpy(df_tenure, "lr_remdezr", "dezr")
fyr_hourly_tenure = run_mincer_numpy(df_tenure, "lr_hourly",  "hourly")

print("\nMerging and saving tenure variant ...")
out_tenure = fyr_dezr_tenure.merge(fyr_hourly_tenure, on=["identificad", "year"], how="outer")
out_tenure.to_csv(OUT_CSV_TENURE, index=False)
size_mb = os.path.getsize(OUT_CSV_TENURE) / 1e6
print(f"  Saved: {OUT_CSV_TENURE}  ({size_mb:.1f} MB, {len(out_tenure):,} rows)")

# ---------------------------------------------------------------------------
# VARIANT 3: +2-digit occupation (base cell × first 2 digits of ocup2002)
# ---------------------------------------------------------------------------
print("\n" + "="*60)
print("VARIANT 3: +2-digit occupation (base x ocup2002[:2])")
print("="*60)

df_ocup2 = df.dropna(subset=["ocup2002"]).copy()
print(f"  Rows with non-missing ocup2002: {len(df_ocup2):,}")

df_ocup2["ocup2_str"] = df_ocup2["ocup2002"].astype(int).astype(str).str[:2]
cell_key_ocup2 = (
    base_cell_key.loc[df_ocup2.index] + "_" +
    df_ocup2["ocup2_str"]
)
df_ocup2["cell_id"] = pd.factorize(cell_key_ocup2)[0]
n_cells = df_ocup2["cell_id"].nunique()
print(f"  Number of cells: {n_cells:,}")

fyr_dezr_ocup2   = run_mincer_numpy(df_ocup2, "lr_remdezr", "dezr")
fyr_hourly_ocup2 = run_mincer_numpy(df_ocup2, "lr_hourly",  "hourly")

print("\nMerging and saving ocup2 variant ...")
out_ocup2 = fyr_dezr_ocup2.merge(fyr_hourly_ocup2, on=["identificad", "year"], how="outer")
out_ocup2.to_csv(OUT_CSV_OCUP2, index=False)
size_mb = os.path.getsize(OUT_CSV_OCUP2) / 1e6
print(f"  Saved: {OUT_CSV_OCUP2}  ({size_mb:.1f} MB, {len(out_ocup2):,} rows)")


# ---------------------------------------------------------------------------
# VARIANT 4: +Tenure polynomial (base cell, within-cell adds quartic tenure)
# ---------------------------------------------------------------------------
print("\n" + "="*60)
print("VARIANT 4: +Tenure polynomial (base cell + age1-4 + ten1-4)")
print("="*60)

df_tenpoly = df.dropna(subset=["tempempr"]).copy()
print(f"  Rows with non-missing tempempr: {len(df_tenpoly):,}")
print(f"  Rows dropped (missing tempempr): {len(df) - len(df_tenpoly):,}")

# Tenure polynomials (raw months)
df_tenpoly["ten1"] = df_tenpoly["tempempr"].astype(np.float64)
df_tenpoly["ten2"] = df_tenpoly["ten1"] ** 2
df_tenpoly["ten3"] = df_tenpoly["ten1"] ** 3
df_tenpoly["ten4"] = df_tenpoly["ten1"] ** 4

# Same base cell as always
df_tenpoly["cell_id"] = pd.factorize(base_cell_key.loc[df_tenpoly.index])[0]
n_cells = df_tenpoly["cell_id"].nunique()
print(f"  Number of cells: {n_cells:,}")

fyr_dezr_tenpoly   = run_mincer_numpy(
    df_tenpoly, "lr_remdezr", "dezr",
    extra_features=["ten1", "ten2", "ten3", "ten4"],
)
fyr_hourly_tenpoly = run_mincer_numpy(
    df_tenpoly, "lr_hourly",  "hourly",
    extra_features=["ten1", "ten2", "ten3", "ten4"],
)

print("\nMerging and saving tenpoly variant ...")
out_tenpoly = fyr_dezr_tenpoly.merge(fyr_hourly_tenpoly, on=["identificad", "year"], how="outer")
out_tenpoly.to_csv(OUT_CSV_TENPOLY, index=False)
size_mb = os.path.getsize(OUT_CSV_TENPOLY) / 1e6
print(f"  Saved: {OUT_CSV_TENPOLY}  ({size_mb:.1f} MB, {len(out_tenpoly):,} rows)")


print(f"\nTotal elapsed: {(time.time()-t_total)/60:.1f} min")

# ---------------------------------------------------------------------------
# Notify
# ---------------------------------------------------------------------------
subprocess.run([
    "curl", "-s", "-o", "/dev/null",
    "-H", "Title: 011g done",
    "-d", "Mincer residual variants (ocup + tenure + ocup2 + tenpoly) complete",
    "https://ntfy.sh/lgg3230-kellogg"
])
