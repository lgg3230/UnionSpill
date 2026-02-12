#!/home/lgg3230/.conda/envs/venv_python312/bin/python
"""
07da WORKER: Run a single univariate regression for the pretreatment specification.

Called by SLURM array job (07da_submit.sh). Each worker:
  1. Loads the parquet from GPFS
  2. Re-standardizes the dep var over the full sample (fixes standardization bug)
  3. Runs ONE univariate regression
  4. Saves result to a per-variable CSV

Usage: python 07da_worker.py <variable_index>
  where variable_index is 0-13 corresponding to UNIVARIATE_VARS list
"""

import os
import sys

# BLAS threads — use what SLURM allocated
N_THREADS = os.environ.get("SLURM_CPUS_PER_TASK", "8")
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
OUTPUT_DIR = Path('/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/pretreat_univariate_results')

# Dependent variable: late pre-treatment connectivity (2009-2011)
DEP_VAR = 'z_bilateral_conn_late_pre'
RAW_DEP_VAR = 'bilateral_conn_late_pre'  # Raw version for re-standardization

# Main predictor
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

# Full list (index 0-13)
UNIVARIATE_VARS = [EARLY_CONN_VAR] + PROXIMITY_VARS + DUMMY_VARS


def get_var_type(var):
    if var == EARLY_CONN_VAR:
        return 'early_connectivity'
    elif var in PROXIMITY_VARS:
        return 'proximity'
    else:
        return 'dummy'


def main():
    var_idx = int(sys.argv[1])
    var = UNIVARIATE_VARS[var_idx]

    print(f"=" * 70)
    print(f"07da WORKER: Variable {var_idx}/{len(UNIVARIATE_VARS)-1} = {var}")
    print(f"  BLAS threads: {N_THREADS}")
    print(f"=" * 70, flush=True)

    start_time = time.time()

    # ------------------------------------------------------------------
    # Load data (only needed columns)
    # ------------------------------------------------------------------
    print("Loading data...", flush=True)

    # Always load raw dep var + raw early var for re-standardization
    cols_needed = ['identificad_i', 'identificad_j', RAW_DEP_VAR, RAW_EARLY_VAR]

    # Add the regressor (if it's not early connectivity, which we already have)
    if var != EARLY_CONN_VAR:
        cols_needed.append(var)

    df = pq.read_table(INPUT_PARQUET, columns=cols_needed).to_pandas()
    print(f"  Loaded {len(df):,} rows in {time.time() - start_time:.1f}s", flush=True)
    print(f"  Memory: {df.memory_usage(deep=True).sum() / 1e9:.1f} GB", flush=True)

    # ------------------------------------------------------------------
    # Re-standardize dep var and early connectivity over FULL sample
    # ------------------------------------------------------------------
    print("Re-standardizing over full sample...", flush=True)

    # Dep var: late pre-treatment connectivity
    dep_mean = df[RAW_DEP_VAR].mean()
    dep_sd = df[RAW_DEP_VAR].std()
    df[DEP_VAR] = (df[RAW_DEP_VAR] - dep_mean) / dep_sd
    print(f"  {DEP_VAR}: mean={dep_mean:.8f}, sd={dep_sd:.8f}", flush=True)

    # Early connectivity (used as regressor for var_idx=0)
    early_mean = df[RAW_EARLY_VAR].mean()
    early_sd = df[RAW_EARLY_VAR].std()
    df[EARLY_CONN_VAR] = (df[RAW_EARLY_VAR] - early_mean) / early_sd
    print(f"  {EARLY_CONN_VAR}: mean={early_mean:.8f}, sd={early_sd:.8f}", flush=True)

    # Drop raw columns to save memory
    df.drop(columns=[RAW_DEP_VAR, RAW_EARLY_VAR], inplace=True)

    # Memory optimizations
    df['identificad_i'] = df['identificad_i'].astype('category')
    df['identificad_j'] = df['identificad_j'].astype('category')
    for col in df.columns:
        if df[col].dtype == 'float64' and col not in ['identificad_i', 'identificad_j']:
            df[col] = df[col].astype('float32')

    print(f"  Memory after optimization: {df.memory_usage(deep=True).sum() / 1e9:.1f} GB", flush=True)

    # ------------------------------------------------------------------
    # Run regression
    # ------------------------------------------------------------------
    print(f"\nRunning regression: {DEP_VAR} ~ {var} | {FE_VARS}", flush=True)
    reg_start = time.time()

    subset_cols = [DEP_VAR, var, 'identificad_i', 'identificad_j']
    subset = df[subset_cols].dropna()
    print(f"  Sample size: {len(subset):,}", flush=True)

    formula = f"{DEP_VAR} ~ {var} | {FE_VARS}"
    model = pf.feols(formula, data=subset, vcov=VCOV)

    coef = model.coef()[var]
    se = model.se()[var]

    result = pd.DataFrame([{
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
    }])

    reg_time = time.time() - reg_start
    print(f"  Completed in {reg_time:.1f}s", flush=True)
    print(f"  coef={coef:.6f}, se={se:.6f}, r2={model._r2:.6f}", flush=True)

    # ------------------------------------------------------------------
    # Save result
    # ------------------------------------------------------------------
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    output_file = OUTPUT_DIR / f"result_{var_idx:02d}_{var}.csv"
    result.to_csv(output_file, index=False)
    print(f"\nSaved: {output_file}", flush=True)

    total_time = time.time() - start_time
    print(f"\n{'=' * 70}")
    print(f"COMPLETE in {total_time/60:.1f} minutes")
    print(f"{'=' * 70}", flush=True)


if __name__ == "__main__":
    main()
