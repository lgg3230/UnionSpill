#!/home/lgg3230/.conda/envs/venv_python312/bin/python
"""
06a BILATERAL REGRESSION: PRE-TREATMENT CONNECTIVITY (UNIVARIATE, ONE-WAY FE)

Same as 06a_bilateral_regression_univariate.py but with:
- 135M undirected pairs (swapped == 0) instead of 271M directed
- One-way FE: identificad_i only
- One-way clustering: identificad_i only

Purpose: Compare with two-way FE specification to understand why
         same_industry_micro dominates in one-way but not two-way FE.

Input: /tmp/bilateral_pairs_enhanced.parquet (filter to swapped==0)
Output: Data/RAIS_aux/bilateral_pretreat_gravity_coefficients_univariate_oneway.csv
"""

import os

N_THREADS = "8"
os.environ["OMP_NUM_THREADS"] = N_THREADS
os.environ["OPENBLAS_NUM_THREADS"] = N_THREADS
os.environ["MKL_NUM_THREADS"] = N_THREADS

import pyfixest as pf
import pandas as pd
import numpy as np
import pyarrow.parquet as pq
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
import time
import warnings
warnings.filterwarnings('ignore')


# ==============================================================================
# CONFIGURATION
# ==============================================================================

INPUT_PARQUET = Path('/tmp/bilateral_pairs_enhanced.parquet')
OUTPUT_CSV = Path('/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/bilateral_pretreat_gravity_coefficients_univariate_oneway.csv')

# Dependent variable: full pre-treatment connectivity
DEP_VAR = 'z_bilateral_conn_pw'

# ONE-WAY FE and clustering (key difference from two-way version)
FE_VARS = 'identificad_i'
VCOV = {'CRV1': 'identificad_i'}

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

ALL_VARS = PROXIMITY_VARS + DUMMY_VARS
N_WORKERS = 4


# ==============================================================================
# DATA LOADING
# ==============================================================================

def load_data():
    """Load undirected bilateral data (swapped==0) with memory optimizations."""
    print("Loading data (undirected pairs only, swapped==0)...")
    start = time.time()

    cols_needed = ['identificad_i', 'identificad_j', DEP_VAR, 'swapped'] + ALL_VARS
    df = pq.read_table(INPUT_PARQUET, columns=cols_needed).to_pandas()

    # Filter to undirected pairs only
    n_before = len(df)
    df = df[df['swapped'] == 0].drop(columns=['swapped'])
    print(f"  Filtered from {n_before:,} to {len(df):,} undirected pairs")

    # Memory optimizations
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
# REGRESSION FUNCTIONS
# ==============================================================================

def run_single_univariate(var, df, dep_var):
    """Run a single univariate regression."""
    try:
        subset_cols = [dep_var, var, 'identificad_i', 'identificad_j']
        subset = df[subset_cols].dropna()

        if len(subset) < 100:
            return None

        formula = f"{dep_var} ~ {var} | {FE_VARS}"
        model = pf.feols(formula, data=subset, vcov=VCOV)

        coef = model.coef()[var]
        se = model.se()[var]

        return {
            'variable': var,
            'var_type': 'proximity' if var in PROXIMITY_VARS else 'dummy',
            'coef': coef,
            'se': se,
            'ci_lower': coef - 1.96 * se,
            'ci_upper': coef + 1.96 * se,
            'spec': 'gravity_oneway',
            'reg_type': 'univariate',
            'r2': model._r2,
            'n': model._N,
        }
    except Exception as e:
        print(f"  Error in {var}: {e}")
        return None


def run_univariate_regressions(df, dep_var):
    """Run all univariate regressions in parallel."""
    print("\n--- Running univariate regressions (ONE-WAY FE) ---")
    print(f"  FE: {FE_VARS}")
    print(f"  Clustering: {VCOV}")
    results = []

    with ThreadPoolExecutor(max_workers=N_WORKERS) as executor:
        futures = {
            executor.submit(run_single_univariate, var, df, dep_var): var
            for var in ALL_VARS
        }

        for future in as_completed(futures):
            var = futures[future]
            try:
                result = future.result()
                if result:
                    results.append(result)
                    print(f"  {var}: coef={result['coef']:.4f}, se={result['se']:.4f}, n={result['n']:,}")
            except Exception as e:
                print(f"  {var}: FAILED - {e}")

    return pd.DataFrame(results)


# ==============================================================================
# MAIN
# ==============================================================================

def main():
    print("=" * 70)
    print("06a GRAVITY UNIVARIATE (ONE-WAY FE: identificad_i only)")
    print("=" * 70)

    start_time = time.time()

    if not INPUT_PARQUET.exists():
        print(f"ERROR: Input file not found: {INPUT_PARQUET}")
        return

    df = load_data()
    results = run_univariate_regressions(df, DEP_VAR)

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
