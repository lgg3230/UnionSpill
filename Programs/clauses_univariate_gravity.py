#!/home/lgg3230/.conda/envs/venv_python312/bin/python
"""
Run univariate gravity regression for z_clauses_proximity only,
then append the result to the existing univariate CSV.

Input: /tmp/bilateral_pairs_enhanced.parquet
Output: Appends to Data/RAIS_aux/bilateral_pretreat_gravity_coefficients_univariate.csv
"""

import os

N_THREADS = "8"
os.environ["OMP_NUM_THREADS"] = N_THREADS
os.environ["OPENBLAS_NUM_THREADS"] = N_THREADS
os.environ["MKL_NUM_THREADS"] = N_THREADS

import pyfixest as pf
import pandas as pd
import pyarrow.parquet as pq
from pathlib import Path
import time
import warnings
warnings.filterwarnings('ignore')

INPUT_PARQUET = Path('/tmp/bilateral_pairs_enhanced.parquet')
OUTPUT_CSV = Path('/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/bilateral_pretreat_gravity_coefficients_univariate.csv')

DEP_VAR = 'z_bilateral_conn_pw'
VAR = 'z_clauses_proximity'
FE_VARS = 'identificad_i + identificad_j'
VCOV = {'CRV1': 'identificad_i + identificad_j'}


def main():
    print("=" * 70)
    print("CLAUSES UNIVARIATE GRAVITY REGRESSION")
    print("=" * 70)

    start_time = time.time()

    if not INPUT_PARQUET.exists():
        print(f"ERROR: Input file not found: {INPUT_PARQUET}")
        return

    print("Loading data...")
    cols = ['identificad_i', 'identificad_j', DEP_VAR, VAR]
    df = pq.read_table(INPUT_PARQUET, columns=cols).to_pandas()

    df['identificad_i'] = df['identificad_i'].astype('category')
    df['identificad_j'] = df['identificad_j'].astype('category')
    df[VAR] = df[VAR].astype('float32')
    df[DEP_VAR] = df[DEP_VAR].astype('float32')

    print(f"  Loaded {len(df):,} rows")
    print(f"  Memory: {df.memory_usage(deep=True).sum() / 1e9:.1f} GB")

    subset = df.dropna(subset=[DEP_VAR, VAR])
    print(f"  Non-missing: {len(subset):,}")

    print(f"\nRunning: {DEP_VAR} ~ {VAR} | {FE_VARS}")
    reg_start = time.time()

    model = pf.feols(f"{DEP_VAR} ~ {VAR} | {FE_VARS}", data=subset, vcov=VCOV)

    coef = model.coef()[VAR]
    se = model.se()[VAR]

    result = pd.DataFrame([{
        'variable': VAR,
        'var_type': 'proximity',
        'coef': coef,
        'se': se,
        'ci_lower': coef - 1.96 * se,
        'ci_upper': coef + 1.96 * se,
        'spec': 'gravity',
        'reg_type': 'univariate',
        'r2': model._r2,
        'n': model._N,
    }])

    print(f"  coef={coef:.6f}, se={se:.6f}, r2={model._r2:.6f}, n={model._N:,}")
    print(f"  Regression time: {time.time() - reg_start:.1f}s")

    # Append to existing CSV (remove old clauses row if any)
    if OUTPUT_CSV.exists():
        existing = pd.read_csv(OUTPUT_CSV)
        existing = existing[existing['variable'] != VAR]
        combined = pd.concat([existing, result], ignore_index=True)
    else:
        combined = result

    combined.to_csv(OUTPUT_CSV, index=False)
    print(f"\nSaved to {OUTPUT_CSV} ({len(combined)} total rows)")

    elapsed = time.time() - start_time
    print(f"\n{'=' * 70}")
    print(f"COMPLETE in {elapsed/60:.1f} minutes")
    print(f"{'=' * 70}")


if __name__ == "__main__":
    main()
