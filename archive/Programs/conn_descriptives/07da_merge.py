#!/home/lgg3230/.conda/envs/venv_python312/bin/python
"""
07da MERGE: Combine per-variable univariate regression results from SLURM array job.

Reads individual CSVs from pretreat_univariate_results/ and merges into
coef_late_connectivity_univ.csv

Usage: python Programs/07da_merge.py
"""

import pandas as pd
from pathlib import Path

RESULTS_DIR = Path('/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/pretreat_univariate_results')
OUTPUT_CSV = Path('/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/coef_late_connectivity_univ.csv')

def main():
    csv_files = sorted(RESULTS_DIR.glob('result_*.csv'))

    if not csv_files:
        print(f"ERROR: No result files found in {RESULTS_DIR}")
        return

    print(f"Found {len(csv_files)} result files:")
    dfs = []
    for f in csv_files:
        df = pd.read_csv(f)
        print(f"  {f.name}: {df['variable'].iloc[0]} -> coef={df['coef'].iloc[0]:.6f}")
        dfs.append(df)

    combined = pd.concat(dfs, ignore_index=True)
    combined.to_csv(OUTPUT_CSV, index=False)
    print(f"\nSaved {len(combined)} coefficients to {OUTPUT_CSV}")
    print("\nResults:")
    print(combined.to_string())


if __name__ == "__main__":
    main()
