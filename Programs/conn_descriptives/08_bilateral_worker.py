#!/home/lgg3230/.conda/envs/venv_python312/bin/python
"""
08 WORKER: Run a single bilateral regression (gravity or pretreatment).

Called by SLURM array job (08_submit.sh). Each worker:
  1. Loads needed columns from the enhanced parquet on GPFS
  2. Restricts to non-missing cep_proximity (~254M rows)
  3. Re-standardizes continuous variables over restricted sample in float64
  4. Runs ONE regression (univariate or multivariate)
  5. Saves result to per-task CSV

Index mapping:
  0-8:   Gravity univariate (9 proximity)
  9-12:  Gravity univariate (4 dummies)
  13:    Gravity multivariate (all 13)
  14:    Pretreat univariate (early connectivity)
  15-23: Pretreat univariate (9 proximity)
  24-27: Pretreat univariate (4 dummies)
  28:    Pretreat multivariate (all 14)

Usage: python 08_bilateral_worker.py <task_index>  (0-28)
"""

import os
import sys

N_THREADS = os.environ.get("SLURM_CPUS_PER_TASK", "8")
os.environ["OMP_NUM_THREADS"] = N_THREADS
os.environ["OPENBLAS_NUM_THREADS"] = N_THREADS
os.environ["MKL_NUM_THREADS"] = N_THREADS

import gc
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
OUTPUT_DIR = Path('/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/bilateral_combined_results')

# One-way FE, two-way clustering
FE_VAR = 'identificad_i'
VCOV = {'CRV1': 'identificad_i + identificad_j'}

# Raw variable names in parquet
RAW_PROXIMITY_VARS = [
    'cep_proximity', 'turnover_proximity', 'size_proximity',
    'wage_proximity', 'female_proximity', 'nonwhite_proximity',
    'educ_proximity', 'hs_proximity', 'clauses_proximity',
]

RAW_DUMMY_VARS = [
    'same_microregion', 'same_union', 'same_industry', 'same_industry_micro',
]

# ==============================================================================
# TASK DEFINITIONS (0-28)
# ==============================================================================

TASKS = []

# --- Gravity univariate: proximity (0-8) ---
for var in RAW_PROXIMITY_VARS:
    TASKS.append({
        'spec': 'gravity', 'reg_type': 'univariate',
        'dep_var_raw': 'bilateral_conn_pw',
        'regressors_raw': [var],
    })

# --- Gravity univariate: dummies (9-12) ---
for var in RAW_DUMMY_VARS:
    TASKS.append({
        'spec': 'gravity', 'reg_type': 'univariate',
        'dep_var_raw': 'bilateral_conn_pw',
        'regressors_raw': [var],
    })

# --- Gravity multivariate (13) ---
TASKS.append({
    'spec': 'gravity', 'reg_type': 'multivariate',
    'dep_var_raw': 'bilateral_conn_pw',
    'regressors_raw': RAW_PROXIMITY_VARS + RAW_DUMMY_VARS,
})

# --- Pretreat univariate: early connectivity (14) ---
TASKS.append({
    'spec': 'pretreat', 'reg_type': 'univariate',
    'dep_var_raw': 'bilateral_conn_late_pre',
    'regressors_raw': ['bilateral_conn_early_pre'],
})

# --- Pretreat univariate: proximity (15-23) ---
for var in RAW_PROXIMITY_VARS:
    TASKS.append({
        'spec': 'pretreat', 'reg_type': 'univariate',
        'dep_var_raw': 'bilateral_conn_late_pre',
        'regressors_raw': [var],
    })

# --- Pretreat univariate: dummies (24-27) ---
for var in RAW_DUMMY_VARS:
    TASKS.append({
        'spec': 'pretreat', 'reg_type': 'univariate',
        'dep_var_raw': 'bilateral_conn_late_pre',
        'regressors_raw': [var],
    })

# --- Pretreat multivariate (28) ---
TASKS.append({
    'spec': 'pretreat', 'reg_type': 'multivariate',
    'dep_var_raw': 'bilateral_conn_late_pre',
    'regressors_raw': ['bilateral_conn_early_pre'] + RAW_PROXIMITY_VARS + RAW_DUMMY_VARS,
})

assert len(TASKS) == 29


# ==============================================================================
# HELPERS
# ==============================================================================

def get_var_type(raw_var):
    if raw_var == 'bilateral_conn_early_pre':
        return 'early_connectivity'
    elif raw_var in RAW_DUMMY_VARS:
        return 'dummy'
    else:
        return 'proximity'


def z_name(raw_var):
    """Map raw variable name to the output z-name expected by the coefplot."""
    if raw_var in RAW_DUMMY_VARS:
        return raw_var  # dummies keep raw names
    return f'z_{raw_var}'


# ==============================================================================
# DATA LOADING
# ==============================================================================

def load_and_prepare(task):
    """Load parquet, restrict to non-missing CEP, re-standardize in float64.

    Memory-optimised path:
      1. self_destruct Arrow table during pandas conversion
      2. Convert string IDs to category immediately (saves ~30 GB)
      3. Drop every raw column the moment its z_ counterpart is created
      4. dropna on ALL analysis columns early so standardisation uses the
         exact regression sample (and subsequent steps work on fewer rows)
    """
    print("Loading data...")
    start = time.time()

    dep_raw = task['dep_var_raw']
    reg_raws = task['regressors_raw']

    # Columns to load: IDs + DV + regressors + cep_proximity (for restriction)
    cols = list(set(['identificad_i', 'identificad_j', 'cep_proximity', dep_raw] + reg_raws))

    # self_destruct=True frees Arrow buffers as pandas columns are built,
    # avoiding holding both representations in memory simultaneously.
    table = pq.read_table(INPUT_PARQUET, columns=cols)
    df = table.to_pandas(self_destruct=True)
    del table
    gc.collect()

    print(f"  Loaded {len(df):,} rows, {len(cols)} columns in {time.time() - start:.1f}s")

    # Restrict to non-missing CEP
    n_before = len(df)
    df.dropna(subset=['cep_proximity'], inplace=True)
    print(f"  Sample restriction: {n_before:,} -> {len(df):,} (dropped {n_before - len(df):,} missing CEP)")

    # Drop cep_proximity (no longer needed after restriction)
    if 'cep_proximity' not in reg_raws and 'cep_proximity' != dep_raw:
        df.drop(columns=['cep_proximity'], inplace=True)

    # Convert IDs to category early — string object columns are ~16 GB each;
    # categorical with ~16 K levels is ~1 GB each.
    df['identificad_i'] = df['identificad_i'].astype('category')
    df['identificad_j'] = df['identificad_j'].astype('category')
    gc.collect()
    print(f"  Memory after ID categorisation: {df.memory_usage(deep=True).sum() / 1e9:.1f} GB")

    # Drop rows with NA in ANY analysis variable so standardisation and
    # regression operate on the identical sample (no extra copy later).
    analysis_cols = [dep_raw] + reg_raws
    n_before_dropna = len(df)
    df.dropna(subset=analysis_cols, inplace=True)
    if len(df) < n_before_dropna:
        print(f"  Dropped {n_before_dropna - len(df):,} rows with missing analysis vars ({len(df):,} remain)")

    # Re-standardize continuous variables over restricted sample (float64)
    print("  Re-standardizing over restricted sample (float64)...")

    # Standardize DV, drop raw immediately
    df[dep_raw] = df[dep_raw].astype(np.float64)
    dep_mean = df[dep_raw].mean()
    dep_sd = df[dep_raw].std()
    z_dep = f'z_{dep_raw}'
    df[z_dep] = (df[dep_raw] - dep_mean) / dep_sd
    df.drop(columns=[dep_raw], inplace=True)
    print(f"    {z_dep}: mean={dep_mean:.10f}, sd={dep_sd:.10f}")

    # Standardize each regressor and drop its raw column immediately
    for var in reg_raws:
        if var in RAW_DUMMY_VARS:
            continue  # dummies stay 0/1
        df[var] = df[var].astype(np.float64)
        var_mean = df[var].mean()
        var_sd = df[var].std()
        z_var = f'z_{var}'
        df[z_var] = (df[var] - var_mean) / var_sd
        df.drop(columns=[var], inplace=True)
        print(f"    {z_var}: mean={var_mean:.10f}, sd={var_sd:.10f}")

    gc.collect()

    # Verify float64
    for var in reg_raws:
        col = z_name(var) if var not in RAW_DUMMY_VARS else var
        if var not in RAW_DUMMY_VARS:
            assert df[col].dtype == np.float64, f"{col} is {df[col].dtype}"

    print(f"  Memory: {df.memory_usage(deep=True).sum() / 1e9:.1f} GB")
    return df


# ==============================================================================
# REGRESSION
# ==============================================================================

def run_regression(df, task):
    """Run one regression and return result rows."""
    dep_raw = task['dep_var_raw']
    reg_raws = task['regressors_raw']
    z_dep = f'z_{dep_raw}'

    # Build regressor names for formula
    z_regs = [z_name(v) for v in reg_raws]
    predictors = ' + '.join(z_regs)
    formula = f"{z_dep} ~ {predictors} | {FE_VAR}"

    # NAs already dropped in load_and_prepare — pass df directly to avoid
    # allocating a second copy of the full dataset.
    print(f"  Observations: {len(df):,}")
    print(f"  Formula: {formula}")

    reg_start = time.time()
    model = pf.feols(formula, data=df, vcov=VCOV)
    reg_time = time.time() - reg_start
    print(f"  Regression time: {reg_time:.1f}s")

    # Extract results
    results = []
    for raw_var in reg_raws:
        z_var = z_name(raw_var)
        coef = float(model.coef()[z_var])
        se = float(model.se()[z_var])

        results.append({
            'variable': z_var,
            'var_type': get_var_type(raw_var),
            'coef': coef,
            'se': se,
            'ci_lower': coef - 1.96 * se,
            'ci_upper': coef + 1.96 * se,
            'spec': task['spec'],
            'reg_type': task['reg_type'],
            'r2': getattr(model, '_r2', None),
            'n': getattr(model, '_N', len(df)),
        })

        print(f"    {z_var}: coef={coef:.6f}, se={se:.6f}")

    return pd.DataFrame(results)


# ==============================================================================
# MAIN
# ==============================================================================

def main():
    if len(sys.argv) < 2:
        print("Usage: 08_bilateral_worker.py <task_index>  (0-28)")
        sys.exit(1)

    idx = int(sys.argv[1])
    if idx < 0 or idx >= len(TASKS):
        print(f"ERROR: task index {idx} out of range (0-{len(TASKS)-1})")
        sys.exit(1)

    task = TASKS[idx]

    print("=" * 70)
    print(f"08 BILATERAL WORKER — Task {idx}")
    print(f"  Spec: {task['spec']}, Type: {task['reg_type']}")
    print(f"  DV: {task['dep_var_raw']}")
    print(f"  Regressors: {task['regressors_raw']}")
    print(f"  FE: {FE_VAR} (one-way), Cluster: {VCOV}")
    print(f"  float64, restricted to non-missing CEP")
    print("=" * 70)

    start_time = time.time()

    if not INPUT_PARQUET.exists():
        print(f"ERROR: Input file not found: {INPUT_PARQUET}")
        sys.exit(1)

    df = load_and_prepare(task)

    print(f"\n--- Running regression ---")
    results = run_regression(df, task)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    out_path = OUTPUT_DIR / f'result_{idx:02d}.csv'
    results.to_csv(out_path, index=False)
    print(f"\n--- Saved to {out_path} ---")

    elapsed = time.time() - start_time
    print(f"\n{'=' * 70}")
    print(f"COMPLETE in {elapsed / 60:.1f} minutes")
    print(f"{'=' * 70}")


if __name__ == "__main__":
    main()
