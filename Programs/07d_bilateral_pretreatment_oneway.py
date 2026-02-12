#!/home/lgg3230/.conda/envs/venv_python312/bin/python
"""
07d BILATERAL REGRESSION: EARLY -> LATE PRE-TREATMENT (ONE-WAY FE)

Same regression as 07d_bilateral_pretreatment_pyfixest.py but with:
- 135M undirected pairs (swapped == 0) instead of 271M directed
- One-way FE: identificad_i only
- One-way clustering: identificad_i only

This replicates the Stata specification from 07d_bilateral_pretreatment.do
to understand why early connectivity's coefficient changed so dramatically
between one-way and two-way FE specifications.

Key question: In the one-way FE spec, early connectivity had coef ~0.20 in
multivariate while same_industry_micro had ~1.42. In two-way FE, early
connectivity jumps to ~0.85 and same_industry_micro collapses to ~0.07.

Input: /tmp/bilateral_pairs_enhanced.parquet (filter to swapped==0)
Output: Data/RAIS_aux/bilateral_pretreatment_coefficients_univariate_oneway.csv
        Data/RAIS_aux/bilateral_pretreatment_coefficients_multivariate_oneway.csv
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
from concurrent.futures import ThreadPoolExecutor, as_completed
import time
import warnings
warnings.filterwarnings('ignore')

# ==============================================================================
# CONFIGURATION
# ==============================================================================

INPUT_PARQUET = Path('/tmp/bilateral_pairs_enhanced.parquet')
OUTPUT_DIR = Path('/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux')
OUTPUT_UNIV = OUTPUT_DIR / 'bilateral_pretreatment_coefficients_univariate_oneway.csv'
OUTPUT_MULTI = OUTPUT_DIR / 'bilateral_pretreatment_coefficients_multivariate_oneway.csv'

# Dependent variable: late pre-treatment connectivity (2009-2011)
DEP_VAR = 'z_bilateral_conn_late_pre'
RAW_DEP_VAR = 'bilateral_conn_late_pre'

# Main predictor: early pre-treatment connectivity (2007-2009)
EARLY_CONN_VAR = 'z_bilateral_conn_early_pre'
RAW_EARLY_VAR = 'bilateral_conn_early_pre'

# ONE-WAY FE and clustering (replicating Stata spec)
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

UNIVARIATE_VARS = [EARLY_CONN_VAR] + PROXIMITY_VARS + DUMMY_VARS
ALL_VARS = PROXIMITY_VARS + DUMMY_VARS

N_WORKERS = 4


# ==============================================================================
# DATA LOADING
# ==============================================================================

def load_data():
    """Load undirected bilateral data (swapped==0)."""
    print("Loading data (undirected pairs only, swapped==0)...")
    start = time.time()

    cols_needed = ['identificad_i', 'identificad_j', RAW_DEP_VAR, RAW_EARLY_VAR, 'swapped'] + ALL_VARS
    df = pq.read_table(INPUT_PARQUET, columns=cols_needed).to_pandas()

    n_before = len(df)
    df = df[df['swapped'] == 0].drop(columns=['swapped'])
    print(f"  Filtered from {n_before:,} to {len(df):,} undirected pairs")

    # Re-standardize connectivity vars over the FULL undirected sample
    # (matching what Stata did, and what 07da_worker.py does for two-way)
    print("  Re-standardizing connectivity over full sample...")
    dep_mean = df[RAW_DEP_VAR].mean()
    dep_sd = df[RAW_DEP_VAR].std()
    df[DEP_VAR] = (df[RAW_DEP_VAR] - dep_mean) / dep_sd
    print(f"    {DEP_VAR}: mean={dep_mean:.8f}, sd={dep_sd:.8f}")

    early_mean = df[RAW_EARLY_VAR].mean()
    early_sd = df[RAW_EARLY_VAR].std()
    df[EARLY_CONN_VAR] = (df[RAW_EARLY_VAR] - early_mean) / early_sd
    print(f"    {EARLY_CONN_VAR}: mean={early_mean:.8f}, sd={early_sd:.8f}")

    df.drop(columns=[RAW_DEP_VAR, RAW_EARLY_VAR], inplace=True)

    df['identificad_i'] = df['identificad_i'].astype('category')
    df['identificad_j'] = df['identificad_j'].astype('category')

    for col in PROXIMITY_VARS + [DEP_VAR, EARLY_CONN_VAR]:
        if col in df.columns:
            df[col] = df[col].astype('float32')

    print(f"  Loaded {len(df):,} rows in {time.time() - start:.1f}s")
    print(f"  Memory: {df.memory_usage(deep=True).sum() / 1e9:.1f} GB")

    return df


# ==============================================================================
# REGRESSION FUNCTIONS
# ==============================================================================

def get_var_type(var):
    if var == EARLY_CONN_VAR:
        return 'early_connectivity'
    elif var in PROXIMITY_VARS:
        return 'proximity'
    else:
        return 'dummy'


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
            'var_type': get_var_type(var),
            'coef': coef,
            'se': se,
            'ci_lower': coef - 1.96 * se,
            'ci_upper': coef + 1.96 * se,
            'spec': 'pretreat_oneway',
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
            for var in UNIVARIATE_VARS
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


def run_multivariate_regression(df, dep_var):
    """Run multivariate regression with all predictors including early connectivity."""
    print("\n--- Running multivariate regression (ONE-WAY FE) ---")
    print(f"  FE: {FE_VARS}")
    print(f"  Clustering: {VCOV}")

    all_predictors = [EARLY_CONN_VAR] + ALL_VARS

    subset = df.dropna(subset=[dep_var] + all_predictors)
    print(f"  Sample size: {len(subset):,}")

    predictors = ' + '.join(all_predictors)
    formula = f"{dep_var} ~ {predictors} | {FE_VARS}"

    print(f"  Formula: {formula[:80]}...")

    start = time.time()
    model = pf.feols(formula, data=subset, vcov=VCOV)
    print(f"  Completed in {time.time() - start:.1f}s")
    print(f"  R-squared: {model._r2:.6f}")

    results = []
    for var in all_predictors:
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
                'spec': 'pretreat_oneway',
                'reg_type': 'multivariate',
                'r2': model._r2,
                'n': model._N,
            })
            print(f"    {var}: coef={coef:.6f}, se={se:.6f}")
        except Exception as e:
            print(f"  Warning: Could not extract {var}: {e}")

    return pd.DataFrame(results)


# ==============================================================================
# MAIN
# ==============================================================================

def main():
    print("=" * 70)
    print("07d PRETREATMENT: EARLY -> LATE (ONE-WAY FE: identificad_i only)")
    print("=" * 70)

    start_time = time.time()

    if not INPUT_PARQUET.exists():
        print(f"ERROR: Input file not found: {INPUT_PARQUET}")
        return

    df = load_data()

    # Univariate regressions
    univ_results = run_univariate_regressions(df, DEP_VAR)

    # Multivariate regression
    multi_results = run_multivariate_regression(df, DEP_VAR)

    # Save split files
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    univ_results.to_csv(OUTPUT_UNIV, index=False)
    print(f"\nSaved univariate: {OUTPUT_UNIV}")

    multi_results.to_csv(OUTPUT_MULTI, index=False)
    print(f"Saved multivariate: {OUTPUT_MULTI}")

    elapsed = time.time() - start_time
    print(f"\n{'=' * 70}")
    print(f"COMPLETE in {elapsed/60:.1f} minutes")
    print(f"{'=' * 70}")

    # Print comparison-ready summary
    print("\n--- SUMMARY (for comparison with two-way FE) ---")
    all_results = pd.concat([univ_results, multi_results], ignore_index=True)
    for _, row in all_results.iterrows():
        print(f"  {row['reg_type']:15s} | {row['variable']:35s} | coef={row['coef']:.6f} | se={row['se']:.6f} | n={row['n']:,}")


if __name__ == "__main__":
    main()
