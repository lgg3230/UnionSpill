#!/usr/bin/env python3
"""
PROJECT: UNION SPILLOVERS
AUTHOR: LUIS GOMES
PROGRAM: BILATERAL CONNECTIVITY REGRESSION - GRAVITY SPECIFICATION (PYTHON)

Runs gravity-style regressions using pyfixest (identical results to Stata reghdfe).
Two-way fixed effects (reference firm + connected firm) with two-way clustering.

OPTIMIZATIONS:
- BLAS multithreading enabled for matrix operations (8 threads)
- Parallel univariate regressions using ThreadPoolExecutor (4 workers)
- FE variables converted to categorical for memory efficiency
- Continuous variables downcast to float32 (halves memory usage)
"""

import os

# =============================================================================
# BLAS/OpenBLAS/MKL MULTITHREADING - Set BEFORE importing numpy
# =============================================================================
N_THREADS = "8"  # Adjust based on available cores
os.environ["OMP_NUM_THREADS"] = N_THREADS
os.environ["OPENBLAS_NUM_THREADS"] = N_THREADS
os.environ["MKL_NUM_THREADS"] = N_THREADS
os.environ["VECLIB_MAXIMUM_THREADS"] = N_THREADS
os.environ["NUMEXPR_NUM_THREADS"] = N_THREADS

import pandas as pd
import numpy as np
import pyarrow.parquet as pq
import pyfixest as pf
from pathlib import Path
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
import warnings
warnings.filterwarnings('ignore')

# Number of parallel workers for univariate regressions
# Rule of thumb: N_WORKERS * N_THREADS <= total_cores
# With 8 BLAS threads and 4 workers, optimal for ~32 core machine
N_WORKERS = 4

# Paths
BASE_DIR = Path("/kellogg/proj/lgg3230/UnionSpill")
RAIS_AUX = BASE_DIR / "Data" / "RAIS_aux"
TABLES = BASE_DIR / "Tables"
GRAPHS = BASE_DIR / "Graphs"

INPUT_PARQUET = Path("/tmp/bilateral_pairs_gravity_ready.parquet")
OUTPUT_UNIV = RAIS_AUX / "bilateral_univariate_coefficients_gravity.csv"
OUTPUT_MULTI = RAIS_AUX / "bilateral_multivariate_coefficients_gravity.csv"

# Variables
PROXIMITY_VARS = [
    'z_geo_proximity', 'z_size_proximity', 'z_wage_proximity',
    'z_female_proximity', 'z_nonwhite_proximity', 'z_educ_proximity',
    'z_hs_proximity', 'z_clauses_proximity'
]

DUMMY_VARS = ['same_microregion', 'same_union', 'same_industry', 'same_industry_micro']

DEP_VAR = 'z_bilateral_conn_pw'
FE_VARS = 'identificad_i + identificad_j'


def load_data():
    """Load parquet file with memory optimizations."""
    print(f"Loading {INPUT_PARQUET}...")
    start = time.time()
    df = pq.read_table(INPUT_PARQUET).to_pandas()
    load_time = time.time() - start
    print(f"  Loaded {len(df):,} rows in {load_time:.1f}s")
    print(f"  Initial memory: {df.memory_usage(deep=True).sum()/1e9:.2f} GB")

    # =========================================================================
    # OPTIMIZATION 1: Convert FE variables to categorical
    # =========================================================================
    print("\n  Converting FE variables to categorical...")
    for col in ['identificad_i', 'identificad_j']:
        if col in df.columns:
            df[col] = df[col].astype('category')

    # =========================================================================
    # OPTIMIZATION 2: Downcast float64 to float32 for continuous variables
    # =========================================================================
    print("  Downcasting float64 -> float32...")
    float_cols = df.select_dtypes(include=['float64']).columns
    for col in float_cols:
        df[col] = df[col].astype('float32')

    # =========================================================================
    # OPTIMIZATION 3: Downcast int64 to int32 where possible
    # =========================================================================
    int_cols = df.select_dtypes(include=['int64']).columns
    for col in int_cols:
        df[col] = pd.to_numeric(df[col], downcast='integer')

    print(f"  Optimized memory: {df.memory_usage(deep=True).sum()/1e9:.2f} GB")
    print(f"  BLAS threads: {N_THREADS}")

    return df


def _run_single_regression(var, df, dep_var, fe_vars):
    """
    Worker function for parallel univariate regression.
    Must be at module level for pickling.
    """
    try:
        # Check for non-missing
        subset = df[[dep_var, var, 'identificad_i', 'identificad_j']].dropna()
        if len(subset) < 100:
            return {'variable': var, 'status': 'skipped', 'reason': f'n={len(subset)}'}

        # Run regression with two-way FE and two-way clustering
        formula = f"{dep_var} ~ {var} | {fe_vars}"
        model = pf.feols(formula, data=df, vcov={'CRV1': 'identificad_i + identificad_j'})

        coef = model.coef()[var]
        se = model.se()[var]
        ci_lower = coef - 1.96 * se
        ci_upper = coef + 1.96 * se
        r2 = model._r2
        n = model._N

        var_type = 'proximity' if var.startswith('z_') else 'dummy'

        return {
            'variable': var,
            'var_type': var_type,
            'coef': coef,
            'se': se,
            'ci_lower': ci_lower,
            'ci_upper': ci_upper,
            'spec': 'univariate_twoway',
            'reg_type': 'univariate',
            'r2': r2,
            'n': n,
            'status': 'success'
        }

    except Exception as e:
        return {'variable': var, 'status': 'error', 'reason': str(e)}


def run_univariate_regressions(df):
    """Run univariate regressions with two-way FE and two-way clustering (PARALLEL)."""
    print("\n" + "=" * 60)
    print("UNIVARIATE REGRESSIONS (Two-way FE, Two-way Clustering)")
    print(f"Running in PARALLEL with {N_WORKERS} workers")
    print("=" * 60)

    # Filter to variables that exist in data
    all_vars = [v for v in PROXIMITY_VARS + DUMMY_VARS if v in df.columns]
    missing_vars = [v for v in PROXIMITY_VARS + DUMMY_VARS if v not in df.columns]

    if missing_vars:
        print(f"  Skipping {len(missing_vars)} missing variables: {missing_vars}")

    print(f"  Running {len(all_vars)} regressions...")

    results = []
    start_time = time.time()

    # Parallel execution using ThreadPoolExecutor (shares memory, GIL released during BLAS)
    with ThreadPoolExecutor(max_workers=N_WORKERS) as executor:
        # Submit all jobs
        future_to_var = {
            executor.submit(_run_single_regression, var, df, DEP_VAR, FE_VARS): var
            for var in all_vars
        }

        # Collect results as they complete
        for future in as_completed(future_to_var):
            var = future_to_var[future]
            try:
                result = future.result()
                if result['status'] == 'success':
                    # Remove status key before appending
                    del result['status']
                    results.append(result)
                    print(f"    {var}: β = {result['coef']:.6f} (SE = {result['se']:.6f}), R² = {result['r2']:.6f}")
                elif result['status'] == 'skipped':
                    print(f"    {var}: SKIPPED ({result['reason']})")
                else:
                    print(f"    {var}: ERROR ({result['reason']})")
            except Exception as e:
                print(f"    {var}: FAILED ({e})")

    elapsed = time.time() - start_time
    print(f"\n  Completed {len(results)} regressions in {elapsed:.1f}s ({elapsed/len(results):.1f}s each)")

    return pd.DataFrame(results)


def run_multivariate_regression(df):
    """Run multivariate regression with two-way FE and two-way clustering."""
    print("\n" + "=" * 60)
    print("MULTIVARIATE REGRESSION (Two-way FE, Two-way Clustering)")
    print(f"Using {N_THREADS} BLAS threads for matrix operations")
    print("=" * 60)

    # Build regressor list from available variables
    regressors = []
    for var in PROXIMITY_VARS + DUMMY_VARS:
        if var in df.columns:
            regressors.append(var)

    print(f"  Regressors: {len(regressors)}")

    # Build formula
    regressors_str = ' + '.join(regressors)
    formula = f"{DEP_VAR} ~ {regressors_str} | {FE_VARS}"

    print(f"  Running regression...")
    start = time.time()

    model = pf.feols(formula, data=df, vcov={'CRV1': 'identificad_i + identificad_j'})

    print(f"  Completed in {time.time()-start:.1f}s")
    print(f"  N = {model._N:,}, R² = {model._r2:.6f}")

    # Extract results
    results = []
    for var in regressors:
        coef = model.coef()[var]
        se = model.se()[var]
        ci_lower = coef - 1.96 * se
        ci_upper = coef + 1.96 * se

        var_type = 'proximity' if var.startswith('z_') else 'dummy'

        results.append({
            'variable': var,
            'var_type': var_type,
            'coef': coef,
            'se': se,
            'ci_lower': ci_lower,
            'ci_upper': ci_upper,
            'spec': 'multivariate_twoway',
            'reg_type': 'multivariate',
            'r2': model._r2,
            'n': model._N
        })

        print(f"    {var}: β = {coef:.6f} (SE = {se:.6f})")

    return pd.DataFrame(results)


def print_threading_info():
    """Print info about BLAS/threading configuration."""
    try:
        import numpy as np
        print(f"  NumPy config: {np.__config__.show()}" if hasattr(np.__config__, 'show') else "")
    except:
        pass

    # Check actual thread settings
    print(f"  OMP_NUM_THREADS: {os.environ.get('OMP_NUM_THREADS', 'not set')}")
    print(f"  OPENBLAS_NUM_THREADS: {os.environ.get('OPENBLAS_NUM_THREADS', 'not set')}")
    print(f"  MKL_NUM_THREADS: {os.environ.get('MKL_NUM_THREADS', 'not set')}")
    print(f"  Parallel workers: {N_WORKERS}")


def main():
    total_start = time.time()

    print("=" * 60)
    print("BILATERAL CONNECTIVITY REGRESSION (GRAVITY SPECIFICATION)")
    print("Python/pyfixest implementation - OPTIMIZED")
    print("=" * 60)
    print("\nThreading configuration:")
    print_threading_info()

    # Load data
    df = load_data()

    # Run univariate regressions
    univ_results = run_univariate_regressions(df)

    # Run multivariate regression
    multi_results = run_multivariate_regression(df)

    # Save results
    print("\n" + "=" * 60)
    print("SAVING RESULTS")
    print("=" * 60)

    univ_results.to_csv(OUTPUT_UNIV, index=False)
    print(f"  Saved: {OUTPUT_UNIV}")

    multi_results.to_csv(OUTPUT_MULTI, index=False)
    print(f"  Saved: {OUTPUT_MULTI}")

    # Summary
    total_time = time.time() - total_start
    print("\n" + "=" * 60)
    print("COMPLETE")
    print("=" * 60)
    print(f"Total time: {total_time/60:.1f} min")
    print(f"\nOutput files:")
    print(f"  - {OUTPUT_UNIV}")
    print(f"  - {OUTPUT_MULTI}")
    print(f"\nNext: Run 06_bilateral_coefplot_gravity.py to create figures")


if __name__ == "__main__":
    main()
