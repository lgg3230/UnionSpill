# Main Data Pipeline Status

Last checked: 2026-04-13.

## Smoke Test

Command:

```bash
/software/Stata/stata17/stata-mp -q do Programs/main_data_pipeline/90_smoke_test_analysis_dataset.do
```

Result: passed.

What it tested:

- Loaded `Data/CBA_RAIS_firm_level/lagos_sample_sep24_pct_unionexp_ext_df2.dta`.
- Confirmed key variables needed for downstream analysis exist.
- Sampled 250 firms in memory.
- Merged `Data/RAIS_aux/totalflows_wide_2007_2011.csv`.
- Recreated basic period variables in memory.
- Ran a lightweight wage regression.
- Wrote no permanent data files.

## Preflight

Command:

```bash
/software/Stata/stata17/stata-mp -q do Programs/main_data_pipeline/01_preflight_inputs.do
```

Result: expected failure with 3 missing files.

Missing:

- `Data/CBA_RAIS_firm_level/lagos_sample_sep24_pct_unionexp.dta`
- `Data/CBA_RAIS_firm_level/rais_firm_2007.dta`
- `Data/CBA_RAIS_firm_level/rais_firm_2008.dta`

Interpretation:

- `lagos_sample_sep24_pct_unionexp.dta` is the important missing upstream link.
  It was the direct input to `Programs/121_get_wage_pctiles_df2.do`, which saved
  the protected reference dataset.
- `rais_firm_2007.dta` and `rais_firm_2008.dta` are missing firm-year outputs,
  but raw RAIS 2007 and 2008 files exist at `$rais_raw_dir`, so these should be
  reproducible if the RAIS firm-year construction scripts still run.

## Cleanup Guidance

Do not delete any firm-level analysis datasets or connectivity inputs/outputs
until the missing upstream link is reconstructed or shown to be unnecessary.

It is safer to clean first:

- root-level `.log` files
- generated Stata logs under `Logs/`
- cache folders such as `__pycache__`
- unrelated standalone copies such as `layer_connectivity_standalone/`, once its
  contents are confirmed duplicated or archived
- `node_modules/`, `package.json`, and `package-lock.json`, if they are not part
  of the research pipeline

Do not delete yet:

- `Data/CBA_RAIS_firm_level/lagos_sample_sep24_pct_unionexp_ext_df2.dta`
- `Data/CBA_RAIS_firm_level/lagos_sample_sep24*.dta`
- `Data/CBA_RAIS_firm_level/cba_rais_firm_*.dta`
- `Data/RAIS_aux/connectivity*`
- `Data/RAIS_aux/employers_*`
- `Data/RAIS_aux/yearly_employers_*`
- `Data/RAIS_aux/totalflows_wide_2007_2011.csv`
