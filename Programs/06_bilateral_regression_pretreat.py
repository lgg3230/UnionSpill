#!/home/lgg3230/.conda/envs/venv_python312/bin/python
"""
06 BILATERAL REGRESSION: PRE-TREATMENT CONNECTIVITY

Predicts pre-treatment bilateral connectivity (2007-2011) using gravity/proximity measures.
- Two-way fixed effects (identificad_i + identificad_j)
- Two-way clustering (identificad_i + identificad_j)
- Univariate and multivariate specifications

Input: /tmp/bilateral_pairs_enhanced.parquet (271M directed pairs)
Output: Data/RAIS_aux/bilateral_pretreat_gravity_coefficients.csv
"""

import pyfixest as pf
import pandas as pd
import numpy as np
import pyarrow.parquet as pq
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import time
import warnings
warnings.filterwarnings('ignore')

# ==============================================================================
# CONFIGURATION
# ==============================================================================

INPUT_PARQUET = Path('/tmp/bilateral_pairs_enhanced.parquet')
OUTPUT_CSV = Path('/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/bilateral_pretreat_gravity_coefficients.csv')

# Dependent variable: full pre-treatment connectivity (bilateral_conn_pw is the full pre-treatment)
DEP_VAR = 'z_bilateral_conn_pw'

# Fixed effects and clustering
FE_VARS = 'identificad_i + identificad_j'
VCOV = {'CRV1': 'identificad_i + identificad_j'}

# Proximity measures (excluding nhs per user request)
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

# Dummy variables (excluding same_muni per user request)
DUMMY_VARS = [
    'same_microregion',
    'same_union',
    'same_industry',
    'same_industry_micro',
]

ALL_VARS = PROXIMITY_VARS + DUMMY_VARS

# Parallel workers for univariate regressions
N_WORKERS = 4


# ==============================================================================
# DATA LOADING
# ==============================================================================

def load_data():
    """Load enhanced bilateral data with memory optimizations."""
    print("Loading data...")
    start = time.time()

    # Read only needed columns
    cols_needed = ['identificad_i', 'identificad_j', DEP_VAR] + ALL_VARS

    df = pq.read_table(INPUT_PARQUET, columns=cols_needed).to_pandas()

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
        # Drop rows with missing values for this variable
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
            'spec': 'gravity',
            'reg_type': 'univariate',
            'r2': model._r2,
            'n': model._N,
        }
    except Exception as e:
        print(f"  Error in {var}: {e}")
        return None


def run_univariate_regressions(df, dep_var):
    """Run all univariate regressions in parallel."""
    print("\n--- Running univariate regressions ---")
    results = []

    with ThreadPoolExecutor(max_workers=N_WORKERS) as executor:
        futures = {
            executor.submit(run_single_univariate, var, df, dep_var): var
            for var in ALL_VARS
        }

        for future in futures:
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
    """Run multivariate regression with all predictors."""
    print("\n--- Running multivariate regression ---")

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

    # Extract coefficients
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
                'spec': 'gravity',
                'reg_type': 'multivariate',
                'r2': model._r2,
                'n': model._N,
            })
        except Exception as e:
            print(f"  Warning: Could not extract {var}: {e}")

    return pd.DataFrame(results)


# ==============================================================================
# MAIN
# ==============================================================================

def main():
    print("=" * 70)
    print("06 BILATERAL REGRESSION: PRE-TREATMENT CONNECTIVITY")
    print("=" * 70)

    start_time = time.time()

    # Check input exists
    if not INPUT_PARQUET.exists():
        print(f"ERROR: Input file not found: {INPUT_PARQUET}")
        print("Please run 06_bilateral_data_enhance.py first.")
        return

    # Load data
    df = load_data()

    # Run univariate regressions
    univ_results = run_univariate_regressions(df, DEP_VAR)

    # Run multivariate regression
    multi_results = run_multivariate_regression(df, DEP_VAR)

    # Combine results
    all_results = pd.concat([univ_results, multi_results], ignore_index=True)

    # Save
    OUTPUT_CSV.parent.mkdir(parents=True, exist_ok=True)
    all_results.to_csv(OUTPUT_CSV, index=False)
    print(f"\n--- Saved {len(all_results)} coefficients to {OUTPUT_CSV} ---")

    # Summary
    elapsed = time.time() - start_time
    print(f"\n{'=' * 70}")
    print(f"COMPLETE in {elapsed/60:.1f} minutes")
    print(f"{'=' * 70}")

    print("\nResults summary:")
    print(all_results.to_string())


if __name__ == "__main__":
    main()
