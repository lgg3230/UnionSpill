#!/home/lgg3230/.conda/envs/venv_python312/bin/python
"""
07da BILATERAL REGRESSION: EARLY -> LATE PRE-TREATMENT (UNIVARIATE)

Predicts late pre-treatment bilateral connectivity (2009-2011) using:
- Early pre-treatment connectivity (2007-2009)
- Gravity/proximity measures

Two-way fixed effects (identificad_i + identificad_j)
Two-way clustering (identificad_i + identificad_j)
Univariate specifications only (sequential execution)

Input: /tmp/bilateral_pairs_enhanced.parquet (271M directed pairs)
Output: Data/RAIS_aux/bilateral_pretreatment_coefficients_univariate.csv
"""

import os

# BLAS multithreading (reduced to limit memory)
N_THREADS = "4"
os.environ["OMP_NUM_THREADS"] = N_THREADS
os.environ["OPENBLAS_NUM_THREADS"] = N_THREADS
os.environ["MKL_NUM_THREADS"] = N_THREADS

import pyfixest as pf
import pandas as pd
import numpy as np
import pyarrow.parquet as pq
from pathlib import Path
import gc
import time
import warnings
warnings.filterwarnings('ignore')

# ==============================================================================
# CONFIGURATION
# ==============================================================================

INPUT_PARQUET = Path('/tmp/bilateral_pairs_enhanced.parquet')
OUTPUT_CSV = Path('/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/bilateral_pretreatment_coefficients_univariate.csv')

# Dependent variable: late pre-treatment connectivity (2009-2011)
DEP_VAR = 'z_bilateral_conn_late_pre'

# Main predictor: early pre-treatment connectivity (2007-2009)
EARLY_CONN_VAR = 'z_bilateral_conn_early_pre'

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

# All variables for univariate regressions (includes early connectivity)
UNIVARIATE_VARS = [EARLY_CONN_VAR] + PROXIMITY_VARS + DUMMY_VARS



# ==============================================================================
# DATA LOADING
# ==============================================================================

def load_data():
    """Load enhanced bilateral data with memory optimizations."""
    print("Loading data...")
    start = time.time()

    cols_needed = ['identificad_i', 'identificad_j', DEP_VAR, EARLY_CONN_VAR] + PROXIMITY_VARS + DUMMY_VARS
    df = pq.read_table(INPUT_PARQUET, columns=cols_needed).to_pandas()

    # Memory optimizations
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
    """Determine variable type for output."""
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
            'spec': 'pretreat',
            'reg_type': 'univariate',
            'r2': model._r2,
            'n': model._N,
        }
    except Exception as e:
        print(f"  Error in {var}: {e}")
        return None


def run_univariate_regressions(df, dep_var):
    """Run all univariate regressions sequentially to limit memory usage."""
    print("\n--- Running univariate regressions (sequential) ---")
    print(f"  BLAS threads: {N_THREADS}")
    print(f"  Variables to run: {len(UNIVARIATE_VARS)}")
    results = []

    for i, var in enumerate(UNIVARIATE_VARS, 1):
        print(f"\n  [{i}/{len(UNIVARIATE_VARS)}] {var}...")
        reg_start = time.time()
        result = run_single_univariate(var, df, dep_var)
        if result:
            results.append(result)
            print(f"    coef={result['coef']:.4f}, se={result['se']:.4f}, "
                  f"r2={result['r2']:.6f}, n={result['n']:,}, "
                  f"time={time.time() - reg_start:.1f}s")
        else:
            print(f"    FAILED or skipped")
        gc.collect()

    return pd.DataFrame(results)


# ==============================================================================
# MAIN
# ==============================================================================

def main():
    print("=" * 70)
    print("07da BILATERAL REGRESSION: EARLY -> LATE PRE-TREATMENT (UNIVARIATE)")
    print("=" * 70)

    start_time = time.time()

    if not INPUT_PARQUET.exists():
        print(f"ERROR: Input file not found: {INPUT_PARQUET}")
        print("Please run 06_bilateral_data_enhance.py first.")
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
