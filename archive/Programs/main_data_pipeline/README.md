# Main Data Pipeline

This folder is the organized home for code that reconstructs or validates the
main analysis dataset.

The current protected reference dataset is:

`Data/CBA_RAIS_firm_level/lagos_sample_sep24_pct_unionexp_ext_df2.dta`

Do not overwrite it until the historical connectivity measure has been exactly
reproduced.

## Files

- `00_run_main_data_pipeline.do`: staged wrapper for the full construction path.
- `01_preflight_inputs.do`: checks whether the expected input/intermediate files exist.
- `90_smoke_test_analysis_dataset.do`: non-destructive test using a small firm sample
  from the protected analysis dataset.

Core construction do-files copied into this folder:

- `10_011_rais_to_firm.do`
- `20_02_clean_emp_assoc.do`
- `30_031_clean_cba.do`
- `40_041_merge_cba_rais.do`
- `50_05_yearly_employers.do`

## Current Reconstruction Map

The known lineage is:

1. RAIS firm-year files are built by `10_011_rais_to_firm.do`.
2. Employer association files are cleaned by `20_02_clean_emp_assoc.do`.
3. CBA files are cleaned by `30_031_clean_cba.do`.
4. RAIS and CBA are merged by `40_041_merge_cba_rais.do`.
5. Connectivity is built by `50_05_yearly_employers.do` and MATLAB scripts.
6. Union exposure is built by `Programs/union_treat_exp.do`.
7. Worker wage percentiles are added by `Programs/121_get_wage_pctiles_df2.do`.

Known external helper dependencies still outside this folder:

- `Programs/explode_cba_coverage_firm.py`, called by `30_031_clean_cba.do`.
- `Programs/connectivity_full_lagos.m`, called by `50_05_yearly_employers.do`.
- `Programs/connectivity_treat_lagos.m`, called by `50_05_yearly_employers.do`.
- `Programs/connectivity_control_lagos.m`, called by `50_05_yearly_employers.do`.
- `Programs/connectivity_treat_onecba.m`, called by `50_05_yearly_employers.do`.
- `Programs/connectivity_treat_zerocba.m`, called by `50_05_yearly_employers.do`.

The missing upstream link is the exact creation of:

`Data/CBA_RAIS_firm_level/lagos_sample_sep24_pct_unionexp.dta`

That file is not currently present in the workspace, but it is the input used by
`Programs/121_get_wage_pctiles_df2.do` to create the protected reference dataset.

## Cleanup Rule

Before deleting any intermediate data, the preflight and smoke test should pass.
For now, do not delete connectivity-related files or firm-level analysis datasets
that may be needed to reverse-engineer the protected reference file.
