#!/home/lgg3230/.conda/envs/venv_python312/bin/python
"""
PROJECT: UNION SPILLOVERS
AUTHOR: LUIS GOMES
PROGRAM: PRETREATMENT BILATERAL CONNECTIVITY - PYFIXEST REGRESSION
PURPOSE: Run the same regressions as Stata using pyfixest and compare results
INPUT: bilateral_pretreatment_regression_data.parquet
OUTPUT: Comparison of pyfixest vs Stata coefficients
"""

import pandas as pd
import numpy as np
import pyfixest as pf
from pathlib import Path
import time

# ==============================================================================
# PATHS
# ==============================================================================

PROJECT_ROOT = Path("/gpfs/kellogg/proj/lgg3230/UnionSpill")
RAIS_AUX = PROJECT_ROOT / "Data" / "RAIS_aux"

PARQUET_FILE = RAIS_AUX / "bilateral_pretreatment_regression_data.parquet"
STATA_COEF_FILE = RAIS_AUX / "bilateral_pretreatment_coefficients.csv"

# ==============================================================================
# MAIN
# ==============================================================================

def main():
    print("=" * 70)
    print("PRETREATMENT BILATERAL CONNECTIVITY - PYFIXEST REGRESSION")
    print("=" * 70)

    start_time = time.time()

    # -------------------------------------------------------------------------
    # STEP 1: Load data
    # -------------------------------------------------------------------------
    print("\n--- Step 1: Loading data ---")
    print(f"Reading: {PARQUET_FILE}")

    df = pd.read_parquet(PARQUET_FILE)
    print(f"Loaded {len(df):,} rows, {len(df.columns)} columns")

    # -------------------------------------------------------------------------
    # STEP 2: Compute missing variables (clauses_proximity not in parquet)
    # -------------------------------------------------------------------------
    print("\n--- Step 2: Computing additional variables ---")

    # Load clauses data
    clauses_file = PROJECT_ROOT / "Data" / "CBA_RAIS_firm_level" / "cba_rais_firm_2009_2016_flows_1.dta"
    print(f"Loading clauses from: {clauses_file}")

    clauses_df = pd.read_stata(clauses_file, columns=['identificad', 'year', 'numb_clauses'])
    clauses_df = clauses_df[clauses_df['year'].isin([2009, 2010, 2011])]
    clauses_avg = clauses_df.groupby('identificad')['numb_clauses'].mean().reset_index()
    clauses_avg.columns = ['identificad', 'avg_numb_clauses']

    # Merge for i and j
    df = df.merge(clauses_avg.rename(columns={'identificad': 'identificad_i', 'avg_numb_clauses': 'numb_clauses_i'}),
                  on='identificad_i', how='left')
    df = df.merge(clauses_avg.rename(columns={'identificad': 'identificad_j', 'avg_numb_clauses': 'numb_clauses_j'}),
                  on='identificad_j', how='left')

    # Compute clauses proximity
    df['clauses_proximity'] = -np.abs(df['numb_clauses_i'] - df['numb_clauses_j'])

    # -------------------------------------------------------------------------
    # STEP 3: Standardize variables
    # -------------------------------------------------------------------------
    print("\n--- Step 3: Standardizing variables ---")

    vars_to_standardize = [
        'bilateral_conn_early_pre', 'bilateral_conn_late_pre',
        'size_proximity', 'wage_proximity', 'female_proximity', 'nonwhite_proximity',
        'educ_proximity', 'hs_proximity', 'nhs_proximity', 'geo_proximity', 'clauses_proximity'
    ]

    for var in vars_to_standardize:
        if var in df.columns:
            mean_val = df[var].mean()
            std_val = df[var].std()
            if std_val > 0:
                df[f'z_{var}'] = (df[var] - mean_val) / std_val
                print(f"  Standardized {var}: mean={mean_val:.6e}, std={std_val:.6e}")

    # -------------------------------------------------------------------------
    # STEP 4: Run univariate regressions with pyfixest
    # -------------------------------------------------------------------------
    print("\n--- Step 4: Running univariate regressions with pyfixest ---")

    proximity_vars = ['z_geo_proximity', 'z_size_proximity', 'z_wage_proximity',
                      'z_female_proximity', 'z_nonwhite_proximity', 'z_educ_proximity',
                      'z_hs_proximity', 'z_nhs_proximity', 'z_clauses_proximity']
    dummy_vars = ['same_muni', 'same_microregion', 'same_union', 'same_industry', 'same_industry_micro']

    pyfixest_results = []

    # Univariate: proximity variables
    for var in proximity_vars:
        if var in df.columns:
            print(f"  Regressing on {var}...")
            try:
                model = pf.feols(f"z_bilateral_conn_late_pre ~ {var} | identificad_i", data=df, vcov='hetero')
                coef = model.coef()[var]
                se = model.se()[var]
                pyfixest_results.append({
                    'variable': var,
                    'var_type': 'proximity',
                    'coef_pyfixest': coef,
                    'se_pyfixest': se,
                    'reg_type': 'univariate'
                })
            except Exception as e:
                print(f"    Error: {e}")

    # Univariate: dummy variables
    for var in dummy_vars:
        if var in df.columns:
            print(f"  Regressing on {var}...")
            try:
                model = pf.feols(f"z_bilateral_conn_late_pre ~ {var} | identificad_i", data=df, vcov='hetero')
                coef = model.coef()[var]
                se = model.se()[var]
                pyfixest_results.append({
                    'variable': var,
                    'var_type': 'dummy',
                    'coef_pyfixest': coef,
                    'se_pyfixest': se,
                    'reg_type': 'univariate'
                })
            except Exception as e:
                print(f"    Error: {e}")

    # Univariate: early-pre connectivity
    print("  Regressing on z_bilateral_conn_early_pre...")
    try:
        model = pf.feols("z_bilateral_conn_late_pre ~ z_bilateral_conn_early_pre | identificad_i", data=df, vcov='hetero')
        coef = model.coef()['z_bilateral_conn_early_pre']
        se = model.se()['z_bilateral_conn_early_pre']
        pyfixest_results.append({
            'variable': 'z_bilateral_conn_early_pre',
            'var_type': 'early_connectivity',
            'coef_pyfixest': coef,
            'se_pyfixest': se,
            'reg_type': 'univariate'
        })
    except Exception as e:
        print(f"    Error: {e}")

    # -------------------------------------------------------------------------
    # STEP 5: Run multivariate regression with pyfixest
    # -------------------------------------------------------------------------
    print("\n--- Step 5: Running multivariate regression with pyfixest ---")

    all_vars = ['z_bilateral_conn_early_pre'] + proximity_vars + dummy_vars
    formula = "z_bilateral_conn_late_pre ~ " + " + ".join(all_vars) + " | identificad_i"

    print(f"  Formula: {formula[:80]}...")
    try:
        model_multi = pf.feols(formula, data=df, vcov='hetero')
        print("  Multivariate regression completed!")

        for var in all_vars:
            if var in model_multi.coef().index:
                coef = model_multi.coef()[var]
                se = model_multi.se()[var]
                var_type = 'early_connectivity' if 'early_pre' in var else ('dummy' if 'same_' in var else 'proximity')
                pyfixest_results.append({
                    'variable': var,
                    'var_type': var_type,
                    'coef_pyfixest': coef,
                    'se_pyfixest': se,
                    'reg_type': 'multivariate'
                })
    except Exception as e:
        print(f"    Error: {e}")

    # -------------------------------------------------------------------------
    # STEP 6: Compare with Stata results
    # -------------------------------------------------------------------------
    print("\n--- Step 6: Comparing with Stata results ---")

    pyfixest_df = pd.DataFrame(pyfixest_results)

    # Load Stata results
    stata_df = pd.read_csv(STATA_COEF_FILE)
    stata_df = stata_df.rename(columns={'coef': 'coef_stata', 'se': 'se_stata'})

    # Merge
    comparison = pyfixest_df.merge(
        stata_df[['variable', 'reg_type', 'coef_stata', 'se_stata']],
        on=['variable', 'reg_type'],
        how='outer'
    )

    # Compute differences
    comparison['coef_diff'] = comparison['coef_pyfixest'] - comparison['coef_stata']
    comparison['coef_pct_diff'] = (comparison['coef_diff'] / comparison['coef_stata'].abs()) * 100
    comparison['se_diff'] = comparison['se_pyfixest'] - comparison['se_stata']

    # -------------------------------------------------------------------------
    # STEP 7: Print comparison
    # -------------------------------------------------------------------------
    print("\n" + "=" * 90)
    print("COMPARISON: PYFIXEST vs STATA (reghdfe)")
    print("=" * 90)

    print("\n--- UNIVARIATE REGRESSIONS ---")
    uni_comp = comparison[comparison['reg_type'] == 'univariate'].copy()
    print(f"{'Variable':<30} {'Stata':>12} {'pyfixest':>12} {'Diff':>12} {'%Diff':>10}")
    print("-" * 76)
    for _, row in uni_comp.iterrows():
        print(f"{row['variable']:<30} {row['coef_stata']:>12.6f} {row['coef_pyfixest']:>12.6f} "
              f"{row['coef_diff']:>12.2e} {row['coef_pct_diff']:>10.4f}%")

    print("\n--- MULTIVARIATE REGRESSION ---")
    multi_comp = comparison[comparison['reg_type'] == 'multivariate'].copy()
    print(f"{'Variable':<30} {'Stata':>12} {'pyfixest':>12} {'Diff':>12} {'%Diff':>10}")
    print("-" * 76)
    for _, row in multi_comp.iterrows():
        print(f"{row['variable']:<30} {row['coef_stata']:>12.6f} {row['coef_pyfixest']:>12.6f} "
              f"{row['coef_diff']:>12.2e} {row['coef_pct_diff']:>10.4f}%")

    # Summary statistics
    print("\n--- SUMMARY ---")
    print(f"Max absolute coefficient difference: {comparison['coef_diff'].abs().max():.2e}")
    print(f"Max percentage difference: {comparison['coef_pct_diff'].abs().max():.4f}%")
    print(f"Mean absolute coefficient difference: {comparison['coef_diff'].abs().mean():.2e}")

    # Save comparison
    output_file = RAIS_AUX / "bilateral_pretreatment_pyfixest_comparison.csv"
    comparison.to_csv(output_file, index=False)
    print(f"\nComparison saved to: {output_file}")

    # -------------------------------------------------------------------------
    # STEP 8: Save coefficients in format expected by coefplot script
    # -------------------------------------------------------------------------
    print("\n--- Step 7: Saving coefficients for coefplot ---")

    # Create coefficients file in the expected format
    coef_output = []
    for result in pyfixest_results:
        coef = result['coef_pyfixest']
        se = result['se_pyfixest']
        ci_lower = coef - 1.96 * se
        ci_upper = coef + 1.96 * se
        coef_output.append({
            'variable': result['variable'],
            'var_type': result['var_type'],
            'coef': coef,
            'se': se,
            'ci_lower': ci_lower,
            'ci_upper': ci_upper,
            'spec': 'pretreat',
            'reg_type': result['reg_type'],
            'r2': ''  # Not computing R2 as we're not displaying it
        })

    coef_df = pd.DataFrame(coef_output)
    coef_file = RAIS_AUX / "bilateral_pretreatment_coefficients.csv"
    coef_df.to_csv(coef_file, index=False)
    print(f"Coefficients saved to: {coef_file}")

    elapsed = time.time() - start_time
    print(f"\nElapsed time: {elapsed/60:.1f} minutes")


if __name__ == "__main__":
    main()
