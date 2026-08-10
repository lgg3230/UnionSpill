#!/home/lgg3230/.conda/envs/venv_python312/bin/python
"""
08 MERGE: Combine per-task regression results into 4 CSVs for the coefplot.

Reads individual result_*.csv from bilateral_combined_results/ and writes:
- coef_connectivity_univ.csv
- coef_connectivity_multi.csv
- coef_late_connectivity_univ.csv
- coef_late_connectivity_multi.csv
- bilateral_gravity_6yr_coefficients_univariate.csv
- bilateral_gravity_6yr_coefficients_multivariate.csv
- bilateral_pretreatment_6yr_coefficients_univariate.csv
- bilateral_pretreatment_6yr_coefficients_multivariate.csv

Usage: python Programs/08_merge.py
"""

import pandas as pd
from pathlib import Path

RESULTS_DIR = Path('/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/bilateral_combined_results')
OUTPUT_DIR = Path('/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux')

# Output filenames matching 5110_figure_bilateral_coefplot.py expectations
OUTPUT_MAP = {
    ('gravity', 'univariate'): 'coef_connectivity_univ.csv',
    ('gravity', 'multivariate'): 'coef_connectivity_multi.csv',
    ('pretreat', 'univariate'): 'coef_late_connectivity_univ.csv',
    ('pretreat', 'multivariate'): 'coef_late_connectivity_multi.csv',
    ('gravity_6yr', 'univariate'): 'bilateral_gravity_6yr_coefficients_univariate.csv',
    ('gravity_6yr', 'multivariate'): 'bilateral_gravity_6yr_coefficients_multivariate.csv',
    ('pretreat_6yr', 'univariate'): 'bilateral_pretreatment_6yr_coefficients_univariate.csv',
    ('pretreat_6yr', 'multivariate'): 'bilateral_pretreatment_6yr_coefficients_multivariate.csv',
}


def main():
    # Read all individual results
    files = sorted(RESULTS_DIR.glob('result_*.csv'))
    print(f"Found {len(files)} result files")

    if len(files) == 0:
        print("ERROR: No result files found.")
        return

    missing = [i for i in range(58) if not (RESULTS_DIR / f'result_{i:02d}.csv').exists()]
    if missing:
        print(f"WARNING: Missing task indices: {missing}")

    dfs = []
    for f in files:
        df = pd.read_csv(f)
        dfs.append(df)
        for _, row in df.iterrows():
            print(f"  {f.name}: {row['spec']}/{row['reg_type']} {row['variable']} coef={row['coef']:.6f}")

    combined = pd.concat(dfs, ignore_index=True)
    print(f"\nTotal rows: {len(combined)}")

    # Split by (spec, reg_type) and write to separate files
    for (spec, reg_type), filename in OUTPUT_MAP.items():
        subset = combined[(combined['spec'] == spec) & (combined['reg_type'] == reg_type)]
        if len(subset) == 0:
            print(f"\n  WARNING: No data for {spec}/{reg_type}")
            continue

        out_path = OUTPUT_DIR / filename
        subset.to_csv(out_path, index=False)
        print(f"\n  {filename}: {len(subset)} rows")
        for _, row in subset.iterrows():
            print(f"    {row['variable']}: coef={row['coef']:.6f}, se={row['se']:.6f}")

    print("\nDone.")


if __name__ == "__main__":
    main()
