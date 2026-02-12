#!/home/lgg3230/.conda/envs/venv_python312/bin/python
"""
Merge the 3 individual FE test results into a single CSV.

Input:  Data/RAIS_aux/fe_tests_v2/fe_spec_{0,1,2}.csv
Output: Data/RAIS_aux/bilateral_pretreatment_coefficients_fe_tests_v2.csv
"""

import pandas as pd
from pathlib import Path

INPUT_DIR = Path('/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/fe_tests_v2')
OUTPUT_CSV = Path('/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/bilateral_pretreatment_coefficients_fe_tests_v2.csv')

FE_LABELS = {0: 'none', 1: 'identificad_i + identificad_j', 2: 'identificad_i'}

dfs = []
for idx in sorted(FE_LABELS.keys()):
    path = INPUT_DIR / f'fe_spec_{idx}.csv'
    if path.exists():
        df = pd.read_csv(path)
        dfs.append(df)
        print(f"  Loaded spec {idx} ({FE_LABELS[idx]}): coef={df['coef'].iloc[0]:.6f}, se={df['se'].iloc[0]:.6f}")
    else:
        print(f"  WARNING: {path} not found — spec {idx} ({FE_LABELS[idx]}) missing")

if dfs:
    combined = pd.concat(dfs, ignore_index=True)
    combined.to_csv(OUTPUT_CSV, index=False)
    print(f"\nSaved {len(combined)} rows to {OUTPUT_CSV}")
    print("\nResults:")
    print(combined.to_string())
else:
    print("ERROR: No result files found.")
