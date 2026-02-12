#!/home/lgg3230/.conda/envs/venv_python312/bin/python
"""
07e v2: BILATERAL FE TESTS WITH CORRECT STANDARDIZATION

Changes from v1:
  1) float64 throughout (no float32 casting)
  2) Re-standardize connectivity over the full 271M sample,
     not the pre-computed z-scores from the parquet

Takes a single CLI argument: FE spec index
  0 = no FE
  1 = two-way FE (identificad_i + identificad_j)
  2 = one-way FE (identificad_i)

Input:  /tmp/bilateral_pairs_enhanced.parquet (271M directed pairs)
Output: Data/RAIS_aux/fe_tests_v2/fe_spec_{index}.csv
"""

import os
import sys

N_THREADS = "8"
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
OUTPUT_DIR = Path('/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/fe_tests_v2')

# Raw connectivity variables (will be re-standardized)
RAW_DEP_VAR = 'bilateral_conn_late_pre'
RAW_EARLY_VAR = 'bilateral_conn_early_pre'

# Standardized names (computed here, not from parquet)
DEP_VAR = 'z_bilateral_conn_late_pre'
EARLY_CONN_VAR = 'z_bilateral_conn_early_pre'

# Two-way clustering for all specs
VCOV = {'CRV1': 'identificad_i + identificad_j'}

# FE specifications (index -> spec)
FE_SPEC_MAP = {
    0: {'label': 'none',                        'fe': '',                             'has_fe': False},
    1: {'label': 'identificad_i + identificad_j', 'fe': 'identificad_i + identificad_j', 'has_fe': True},
    2: {'label': 'identificad_i',                'fe': 'identificad_i',                'has_fe': True},
}


# ==============================================================================
# DATA LOADING
# ==============================================================================

def load_data():
    """Load raw connectivity and re-standardize over the full 271M sample."""
    print("Loading data...")
    start = time.time()

    cols_needed = ['identificad_i', 'identificad_j', RAW_DEP_VAR, RAW_EARLY_VAR]
    df = pq.read_table(INPUT_PARQUET, columns=cols_needed).to_pandas()

    print(f"  Loaded {len(df):,} rows in {time.time() - start:.1f}s")
    print(f"  Memory: {df.memory_usage(deep=True).sum() / 1e9:.1f} GB")

    # --- Re-standardize over the full 271M sample (float64) ---
    print("\n  Re-standardizing connectivity over full sample (float64)...")

    dep_mean = df[RAW_DEP_VAR].mean()
    dep_sd = df[RAW_DEP_VAR].std()
    df[DEP_VAR] = (df[RAW_DEP_VAR] - dep_mean) / dep_sd
    print(f"    {DEP_VAR}: mean={dep_mean:.10f}, sd={dep_sd:.10f}")

    early_mean = df[RAW_EARLY_VAR].mean()
    early_sd = df[RAW_EARLY_VAR].std()
    df[EARLY_CONN_VAR] = (df[RAW_EARLY_VAR] - early_mean) / early_sd
    print(f"    {EARLY_CONN_VAR}: mean={early_mean:.10f}, sd={early_sd:.10f}")

    # Drop raw columns to save memory
    df.drop(columns=[RAW_DEP_VAR, RAW_EARLY_VAR], inplace=True)

    # Categorical IDs for FE
    df['identificad_i'] = df['identificad_i'].astype('category')
    df['identificad_j'] = df['identificad_j'].astype('category')

    # Verify no float32 anywhere
    for col in [DEP_VAR, EARLY_CONN_VAR]:
        assert df[col].dtype == np.float64, f"{col} is {df[col].dtype}, expected float64"

    print(f"\n  Final dtypes:")
    print(f"    {DEP_VAR}: {df[DEP_VAR].dtype}")
    print(f"    {EARLY_CONN_VAR}: {df[EARLY_CONN_VAR].dtype}")
    print(f"  Memory after standardization: {df.memory_usage(deep=True).sum() / 1e9:.1f} GB")

    return df


# ==============================================================================
# REGRESSION
# ==============================================================================

def run_regression(df, fe_spec):
    """Run early_conn -> late_conn with the given FE spec."""
    var = EARLY_CONN_VAR

    subset_cols = [DEP_VAR, var, 'identificad_i', 'identificad_j']
    subset = df[subset_cols].dropna()
    print(f"  Observations after dropna: {len(subset):,}")

    if fe_spec['has_fe']:
        formula = f"{DEP_VAR} ~ {var} | {fe_spec['fe']}"
    else:
        formula = f"{DEP_VAR} ~ {var}"

    print(f"  Formula: {formula}")
    print(f"  VCOV: {VCOV}")

    reg_start = time.time()
    model = pf.feols(formula, data=subset, vcov=VCOV)
    reg_time = time.time() - reg_start

    coef = float(model.coef()[var])
    se = float(model.se()[var])

    result = {
        'variable': var,
        'var_type': 'early_connectivity',
        'coef': coef,
        'se': se,
        'ci_lower': coef - 1.96 * se,
        'ci_upper': coef + 1.96 * se,
        'spec': 'pretreat',
        'reg_type': 'univariate',
        'fe_spec': fe_spec['label'],
        'r2': getattr(model, "_r2", None),
        'n': getattr(model, "_N", len(subset)),
    }

    print(f"  coef={coef:.6f}, se={se:.6f}, r2={result['r2']:.8f}, "
          f"n={result['n']:,}, time={reg_time:.1f}s")

    return result


# ==============================================================================
# MAIN
# ==============================================================================

def main():
    if len(sys.argv) < 2:
        print("Usage: 07e_bilateral_fe_tests_v2.py <fe_spec_index>")
        print("  0 = no FE")
        print("  1 = two-way FE (identificad_i + identificad_j)")
        print("  2 = one-way FE (identificad_i)")
        sys.exit(1)

    spec_idx = int(sys.argv[1])
    if spec_idx not in FE_SPEC_MAP:
        print(f"ERROR: Invalid FE spec index {spec_idx}. Must be 0, 1, or 2.")
        sys.exit(1)

    fe_spec = FE_SPEC_MAP[spec_idx]

    print("=" * 70)
    print(f"07e v2: FE TEST — spec {spec_idx}: {fe_spec['label']}")
    print("  float64 throughout, re-standardized over full 271M sample")
    print("=" * 70)

    start_time = time.time()

    if not INPUT_PARQUET.exists():
        print(f"ERROR: Input file not found: {INPUT_PARQUET}")
        print("Please run 06_bilateral_data_enhance.py first.")
        sys.exit(1)

    df = load_data()

    print(f"\n--- Running regression with FE: {fe_spec['label']} ---")
    result = run_regression(df, fe_spec)

    # Save individual result
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    out_path = OUTPUT_DIR / f'fe_spec_{spec_idx}.csv'
    pd.DataFrame([result]).to_csv(out_path, index=False)
    print(f"\n--- Saved to {out_path} ---")

    elapsed = time.time() - start_time
    print(f"\n{'=' * 70}")
    print(f"COMPLETE in {elapsed/60:.1f} minutes")
    print(f"{'=' * 70}")


if __name__ == "__main__":
    main()
