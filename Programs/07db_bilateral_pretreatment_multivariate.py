#!/home/lgg3230/.conda/envs/venv_python312/bin/python
"""
07db BILATERAL REGRESSION: EARLY -> LATE PRE-TREATMENT (MULTIVARIATE)

Predicts late pre-treatment bilateral connectivity (2009-2011) using:
- Early pre-treatment connectivity (2007-2009)
- Gravity/proximity measures

Two-way fixed effects (identificad_i + identificad_j)
Two-way clustering (identificad_i + identificad_j)
Multivariate specification only (no parallel processing)

Re-standardizes dep var and early connectivity over the full 271M sample
(fixes bug where these were standardized over ~62K connected pairs only).

Input: Data/RAIS_aux/bilateral_pairs_enhanced.parquet (271M directed pairs)
Output: Data/RAIS_aux/bilateral_pretreatment_coefficients_multivariate.csv
"""

import os

# BLAS multithreading (no parallel workers, so use more threads)
N_THREADS = "16"
os.environ["OMP_NUM_THREADS"] = N_THREADS
os.environ["OPENBLAS_NUM_THREADS"] = N_THREADS
os.environ["MKL_NUM_THREADS"] = N_THREADS

import pyfixest as pf
import pandas as pd
import numpy as np
import pyarrow.parquet as pq
from pathlib import Path
import time
import warnings
warnings.filterwarnings('ignore')

# ==============================================================================
# CONFIGURATION
# ==============================================================================

INPUT_PARQUET = Path('/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/bilateral_pairs_enhanced.parquet')
OUTPUT_CSV = Path('/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/bilateral_pretreatment_coefficients_multivariate.csv')

# Dependent variable: late pre-treatment connectivity (2009-2011)
DEP_VAR = 'z_bilateral_conn_late_pre'
RAW_DEP_VAR = 'bilateral_conn_late_pre'  # Raw version for re-standardization

# Main predictor: early pre-treatment connectivity (2007-2009)
EARLY_CONN_VAR = 'z_bilateral_conn_early_pre'
RAW_EARLY_VAR = 'bilateral_conn_early_pre'  # Raw version for re-standardization

# Fixed effects and clustering
FE_VARS = 'identificad_i + identificad_j'
VCOV = {'CRV1': 'identificad_i + identificad_j'}

# Proximity measures
PROXIMITY_VARS = [
    'z_cep_proximity',
    'z_turnover_proximity',
    'z_size_proximity',
    'z_wage_proximity',
    'z_female_proximity',
    'z_nonwhite_proximity',
    'z_educ_proximity',
    'z_hs_proximity',
    'z_clauses_proximity',
]

# Dummy variables
DUMMY_VARS = [
    'same_microregion',
    'same_union',
    'same_industry',
    'same_industry_micro',
]

# All predictors for multivariate regression
ALL_VARS = [EARLY_CONN_VAR] + PROXIMITY_VARS + DUMMY_VARS


# ==============================================================================
# DATA LOADING
# ==============================================================================

def load_data():
    """Load enhanced bilateral data with memory optimizations.

    Re-standardizes dep var and early connectivity over the full 271M sample
    to fix the bug where they were standardized over ~62K connected pairs only.
    """
    print("Loading data...")
    start = time.time()

    # Load raw columns for re-standardization alongside z-scored proximity vars
    cols_needed = ['identificad_i', 'identificad_j', RAW_DEP_VAR, RAW_EARLY_VAR] + PROXIMITY_VARS + DUMMY_VARS
    df = pq.read_table(INPUT_PARQUET, columns=cols_needed).to_pandas()

    print(f"  Loaded {len(df):,} rows in {time.time() - start:.1f}s")
    print(f"  Memory: {df.memory_usage(deep=True).sum() / 1e9:.1f} GB", flush=True)

    # Immediately convert IDs to category and floats to float32 to reduce memory
    print("  Downcasting to reduce memory...", flush=True)
    df['identificad_i'] = df['identificad_i'].astype('category')
    df['identificad_j'] = df['identificad_j'].astype('category')
    for col in PROXIMITY_VARS:
        if col in df.columns:
            df[col] = df[col].astype('float32')
    print(f"  Memory after downcast: {df.memory_usage(deep=True).sum() / 1e9:.1f} GB", flush=True)

    # ------------------------------------------------------------------
    # Re-standardize dep var and early connectivity over FULL sample
    # (compute mean/sd at float64 precision, then overwrite in-place)
    # ------------------------------------------------------------------
    print("Re-standardizing over full sample...", flush=True)

    # Dep var: late pre-treatment connectivity — standardize in-place, rename
    dep_mean = df[RAW_DEP_VAR].mean()
    dep_sd = df[RAW_DEP_VAR].std()
    df[RAW_DEP_VAR] = ((df[RAW_DEP_VAR] - dep_mean) / dep_sd).astype('float32')
    df.rename(columns={RAW_DEP_VAR: DEP_VAR}, inplace=True)
    print(f"  {DEP_VAR}: mean={dep_mean:.8f}, sd={dep_sd:.8f}", flush=True)

    # Early connectivity — standardize in-place, rename
    early_mean = df[RAW_EARLY_VAR].mean()
    early_sd = df[RAW_EARLY_VAR].std()
    df[RAW_EARLY_VAR] = ((df[RAW_EARLY_VAR] - early_mean) / early_sd).astype('float32')
    df.rename(columns={RAW_EARLY_VAR: EARLY_CONN_VAR}, inplace=True)
    print(f"  {EARLY_CONN_VAR}: mean={early_mean:.8f}, sd={early_sd:.8f}", flush=True)

    print(f"  Memory after optimization: {df.memory_usage(deep=True).sum() / 1e9:.1f} GB", flush=True)

    return df


# ==============================================================================
# REGRESSION FUNCTION
# ==============================================================================

def get_var_type(var):
    """Determine variable type for output."""
    if var == EARLY_CONN_VAR:
        return 'early_connectivity'
    elif var in PROXIMITY_VARS:
        return 'proximity'
    else:
        return 'dummy'


def run_multivariate_regression(df, dep_var):
    """Run multivariate regression with all predictors including early connectivity."""
    print("\n--- Running multivariate regression ---")
    print(f"  BLAS threads: {N_THREADS}")

    # Drop rows with any missing values
    subset = df.dropna(subset=[dep_var] + ALL_VARS)
    print(f"  Sample size: {len(subset):,}")

    # Build formula
    predictors = ' + '.join(ALL_VARS)
    formula = f"{dep_var} ~ {predictors} | {FE_VARS}"

    print(f"  Formula: {formula[:80]}...")
    print(f"  Running regression...")

    start = time.time()
    model = pf.feols(formula, data=subset, vcov=VCOV)
    print(f"  Completed in {time.time() - start:.1f}s")
    print(f"  R-squared: {model._r2:.6f}")

    # Extract coefficients
    results = []
    for var in ALL_VARS:
        try:
            coef = model.coef()[var]
            se = model.se()[var]
            results.append({
                'variable': var,
                'var_type': get_var_type(var),
                'coef': coef,
                'se': se,
                'ci_lower': coef - 1.96 * se,
                'ci_upper': coef + 1.96 * se,
                'spec': 'pretreat',
                'reg_type': 'multivariate',
                'r2': model._r2,
                'n': model._N,
            })
            print(f"    {var}: coef={coef:.4f}, se={se:.4f}")
        except Exception as e:
            print(f"  Warning: Could not extract {var}: {e}")

    return pd.DataFrame(results)


# ==============================================================================
# MAIN
# ==============================================================================

def main():
    print("=" * 70)
    print("07db BILATERAL REGRESSION: EARLY -> LATE PRE-TREATMENT (MULTIVARIATE)")
    print("=" * 70)

    start_time = time.time()

    if not INPUT_PARQUET.exists():
        print(f"ERROR: Input file not found: {INPUT_PARQUET}")
        print("Please run 06_bilateral_data_enhance.py first.")
        return

    df = load_data()
    results = run_multivariate_regression(df, DEP_VAR)

    OUTPUT_CSV.parent.mkdir(parents=True, exist_ok=True)
    results.to_csv(OUTPUT_CSV, index=False)
    print(f"\n--- Saved {len(results)} coefficients to {OUTPUT_CSV} ---")

    elapsed = time.time() - start_time
    print(f"\n{'=' * 70}")
    print(f"COMPLETE in {elapsed/60:.1f} minutes")
    print(f"{'=' * 70}")

    print("\nResults:")
    print(results.to_string())


if __name__ == "__main__":
    main()
