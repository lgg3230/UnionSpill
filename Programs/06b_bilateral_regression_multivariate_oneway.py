#!/home/lgg3230/.conda/envs/venv_python312/bin/python
"""
06b BILATERAL REGRESSION: PRE-TREATMENT CONNECTIVITY (MULTIVARIATE, ONE-WAY FE)

Same as 06b_bilateral_regression_multivariate.py but with:
- 135M undirected pairs (swapped == 0) instead of 271M directed
- One-way FE: identificad_i only
- One-way clustering: identificad_i only

Input: /tmp/bilateral_pairs_enhanced.parquet (filter to swapped==0)
Output: Data/RAIS_aux/bilateral_pretreat_gravity_coefficients_multivariate_oneway.csv
"""

import os

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

INPUT_PARQUET = Path('/tmp/bilateral_pairs_enhanced.parquet')
OUTPUT_CSV = Path('/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/bilateral_pretreat_gravity_coefficients_multivariate_oneway.csv')

DEP_VAR = 'z_bilateral_conn_pw'

# ONE-WAY FE and clustering
FE_VARS = 'identificad_i'
VCOV = {'CRV1': 'identificad_i'}

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

DUMMY_VARS = [
    'same_microregion',
    'same_union',
    'same_industry',
    'same_industry_micro',
]

ALL_VARS = PROXIMITY_VARS + DUMMY_VARS


# ==============================================================================
# DATA LOADING
# ==============================================================================

def load_data():
    """Load undirected bilateral data (swapped==0)."""
    print("Loading data (undirected pairs only, swapped==0)...")
    start = time.time()

    cols_needed = ['identificad_i', 'identificad_j', DEP_VAR, 'swapped'] + ALL_VARS
    df = pq.read_table(INPUT_PARQUET, columns=cols_needed).to_pandas()

    n_before = len(df)
    df = df[df['swapped'] == 0].drop(columns=['swapped'])
    print(f"  Filtered from {n_before:,} to {len(df):,} undirected pairs")

    df['identificad_i'] = df['identificad_i'].astype('category')
    df['identificad_j'] = df['identificad_j'].astype('category')

    for col in PROXIMITY_VARS:
        if col in df.columns:
            df[col] = df[col].astype('float32')
    df[DEP_VAR] = df[DEP_VAR].astype('float32')

    print(f"  Loaded {len(df):,} rows in {time.time() - start:.1f}s")
    print(f"  Memory: {df.memory_usage(deep=True).sum() / 1e9:.1f} GB")

    return df


# ==============================================================================
# REGRESSION
# ==============================================================================

def run_multivariate_regression(df, dep_var):
    """Run multivariate regression with one-way FE."""
    print("\n--- Running multivariate regression (ONE-WAY FE) ---")
    print(f"  FE: {FE_VARS}")
    print(f"  Clustering: {VCOV}")

    subset = df.dropna(subset=[dep_var] + ALL_VARS)
    print(f"  Sample size: {len(subset):,}")

    predictors = ' + '.join(ALL_VARS)
    formula = f"{dep_var} ~ {predictors} | {FE_VARS}"

    print(f"  Formula: {formula[:80]}...")

    start = time.time()
    model = pf.feols(formula, data=subset, vcov=VCOV)
    print(f"  Completed in {time.time() - start:.1f}s")
    print(f"  R-squared: {model._r2:.6f}")

    results = []
    for var in ALL_VARS:
        try:
            coef = model.coef()[var]
            se = model.se()[var]
            results.append({
                'variable': var,
                'var_type': 'proximity' if var in PROXIMITY_VARS else 'dummy',
                'coef': coef,
                'se': se,
                'ci_lower': coef - 1.96 * se,
                'ci_upper': coef + 1.96 * se,
                'spec': 'gravity_oneway',
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
    print("06b GRAVITY MULTIVARIATE (ONE-WAY FE: identificad_i only)")
    print("=" * 70)

    start_time = time.time()

    if not INPUT_PARQUET.exists():
        print(f"ERROR: Input file not found: {INPUT_PARQUET}")
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
