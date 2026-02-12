#!/home/lgg3230/.conda/envs/venv_python312/bin/python
"""
07d BILATERAL REGRESSION: EARLY → LATE PRE-TREATMENT CONNECTIVITY

Predicts late pre-treatment bilateral connectivity (2009-2011) using:
- Early pre-treatment connectivity (2007-2009)
- Gravity/proximity measures

Two-way fixed effects (identificad_i + identificad_j)
Two-way clustering (identificad_i + identificad_j)
Univariate and multivariate specifications

Input: /tmp/bilateral_pairs_enhanced.parquet (271M directed pairs)
Output: Data/RAIS_aux/bilateral_pretreatment_coefficients.csv
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

# %%

# ==============================================================================
# CONFIGURATION
# ==============================================================================

INPUT_PARQUET = Path('/tmp/bilateral_pairs_enhanced.parquet')
OUTPUT_CSV = Path('/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/bilateral_pretreatment_coefficients_fe_tests.csv')

# Dependent variable: late pre-treatment connectivity (2009-2011)
DEP_VAR = 'z_bilateral_conn_late_pre'

# Main predictor: early pre-treatment connectivity (2007-2009)
EARLY_CONN_VAR = 'z_bilateral_conn_early_pre'

# Fixed effects and clustering
FE_VARS_1 = 'identificad_i + identificad_j'
FE_VARS_2 = 'identificad_i'
FE_VARS_3 = ''

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

# All variables for univariate regressions (includes early connectivity)
UNIVARIATE_VARS = [EARLY_CONN_VAR] 
# All variables for multivariate regression
ALL_VARS = PROXIMITY_VARS + DUMMY_VARS

# Parallel workers for univariate regressions
N_WORKERS = 4

#All FE specs to test
FE_SPECS = [s for s in [FE_VARS_1, FE_VARS_2, FE_VARS_3] if s]


# %%
# ==============================================================================
# DATA LOADING
# ==============================================================================

def load_data():
    """Load enhanced bilateral data with memory optimizations."""
    print("Loading data...")
    start = time.time()

    # Read only needed columns
    cols_needed = ['identificad_i', 'identificad_j', 'z_bilateral_conn_late_pre', 'z_bilateral_conn_early_pre']

    df = pq.read_table(INPUT_PARQUET, columns=cols_needed).to_pandas()

    # Memory optimizations
    df['identificad_i'] = df['identificad_i'].astype('category')
    df['identificad_j'] = df['identificad_j'].astype('category')

    # for col in PROXIMITY_VARS + [DEP_VAR, EARLY_CONN_VAR]:
    #     if col in df.columns:
    #         df[col] = df[col].astype('float32')

    print(f"  Loaded {len(df):,} rows in {time.time() - start:.1f}s")
    print(f"  Memory: {df.memory_usage(deep=True).sum() / 1e9:.1f} GB")

    return df

# %%
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


def run_single_univariate(var, df, dep_var, fe_vars):
    """Run a single univariate regression."""
    try:
        # Drop rows with missing values for this variable
        subset_cols = [dep_var, var, 'identificad_i', 'identificad_j']
        subset = df[subset_cols].dropna()

        if len(subset) < 100:
            return None

        formula = f"{dep_var} ~ {var} | {fe_vars}"
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
                'r2': getattr(model, "_r2", None),
                'n': getattr(model, "_N", len(subset)),
            }
    except Exception as e:
        print(f"  Error in {var}: {e}")
        return None

def run_univariate_no_fe(var, df, dep_var):
    """Run univariate regression without fixed effects."""
    try:
        subset_cols = [dep_var, var, 'identificad_i', 'identificad_j']
        subset = df[subset_cols].dropna()

        if len(subset) < 100:
            return None

        formula = f"{dep_var} ~ {var}"
        model = pf.feols(formula, data=subset, vcov=VCOV)

        coef = float(model.coef()[var])
        se   = float(model.se()[var])

        return {
            'variable': var,
            'var_type': get_var_type(var),
            'coef': coef,
            'se': se,
            'ci_lower': coef - 1.96 * se,
            'ci_upper': coef + 1.96 * se,
            'spec': 'pretreat',
            'reg_type': 'univariate',
            'fe_spec': 'none',
            'r2': getattr(model, "_r2", None),
            'n': getattr(model, "_N", len(subset)),
        }
    except Exception as e:
        print(f"  Error in NO-FE regression: {e}")
        return None

#LOOP OVER FE VARS, DEP VAR IS ALWAYS LATE PRE-TREATMENT CONNECTIVITY, VAR IS ALWAYS EARLY PRE-TREATMENT CONNECTIVITY, BUT FE VARS CHANGE. 

def run_univariate_regressions(df, dep_var):
    print("\n--- Running univariate regressions (vary FE spec) ---")
    results = []

    var = EARLY_CONN_VAR

    # 1) No fixed effects
    print("  Running NO-FE regression")
    result = run_univariate_no_fe(var, df, dep_var)
    if result:
        results.append(result)
        print(f"  FE: none | coef={result['coef']:.4f}, se={result['se']:.4f}, n={result['n']:,}")

    # 2) With fixed effects
    for fe_vars in FE_SPECS:
        result = run_single_univariate(var, df, dep_var, fe_vars)
        if result:
            result["fe_spec"] = fe_vars
            results.append(result)
            print(f"  FE: {fe_vars} | coef={result['coef']:.4f}, se={result['se']:.4f}, n={result['n']:,}")
        else:
            print(f"  FE: {fe_vars} | FAILED/empty")

    return pd.DataFrame(results)



# %%
# ==============================================================================
# MAIN
# ==============================================================================

def main():
    print("=" * 70)
    print("07e TESTING FE'S IN BILATERAL REGRESSION: EARLY → LATE PRE-TREATMENT")
    print("=" * 70)

    start_time = time.time()

    # Check input exists
    if not INPUT_PARQUET.exists():
        print(f"ERROR: Input file not found: {INPUT_PARQUET}")
        print("Please run 06_bilateral_data_enhance.py first.")
        return

    # Load data
    df = load_data()
    print(f"Running FE specs: {FE_SPECS}")

    # Run univariate regressions
    univ_results = run_univariate_regressions(df, DEP_VAR)

    
    # Combine results
    all_results = univ_results.copy()

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
