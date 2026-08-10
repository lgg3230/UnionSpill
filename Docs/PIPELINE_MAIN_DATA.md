# Main Data Pipeline

This document is the working map for organizing the data construction pipeline
before deleting or moving large files. It distinguishes canonical inputs,
generated intermediates, analysis-ready outputs, and protected reference files.

## Protected Target

Current main analysis file:

`Data/CBA_RAIS_firm_level/lagos_sample_sep24_pct_unionexp_ext_df2.dta`

Status: protected reference target. Do not overwrite or delete.

Known direct construction step:

`Programs/2030_get_wage_pctiles_df2.do`

This script reads `worker_year_pre_new_vs_nonnew_dec26.dta`, computes firm-year
worker wage percentiles, merges them into
`Data/CBA_RAIS_firm_level/lagos_sample_sep24_pct_unionexp.dta`, and saves the
protected target. Therefore, it does not explain the older connectivity measure;
it inherits that measure from the upstream `lagos_sample_sep24_pct_unionexp.dta`
lineage.

## Canonical Pipeline Skeleton

### 0. Environment and Paths

Current path setup lives in:

`Programs/0000_master.do`

It defines Stata globals for raw RAIS data, CBA data, auxiliary files, firm-level
outputs, tables, graphs, and scripts. It is currently a legacy switchboard, not a
complete replication runner.

Replication cleanup status: `Programs/pipeline_main_data.do` now supplements the
legacy master file with an explicit staged runner. All stages are off by default,
and the wage-percentile stage refuses to overwrite the protected reference file
unless an explicit override is set.

### 1. RAIS Firm-Year Construction

Primary scripts:

- `Programs/1010_rais_to_firm.do`
- `Programs/011_rais_to_firm_optimized.do`
- `Programs/011_rais_to_firm_parallel.do`

Canonical outputs used downstream:

- `Data/CBA_RAIS_firm_level/rais_firm_2007.dta`
- `Data/CBA_RAIS_firm_level/rais_firm_2008.dta`
- `Data/CBA_RAIS_firm_level/rais_firm_2009.dta`
- `Data/CBA_RAIS_firm_level/rais_firm_2010.dta`
- `Data/CBA_RAIS_firm_level/rais_firm_2011.dta`
- `Data/CBA_RAIS_firm_level/rais_firm_2012.dta`
- `Data/CBA_RAIS_firm_level/rais_firm_2013.dta`
- `Data/CBA_RAIS_firm_level/rais_firm_2014.dta`
- `Data/CBA_RAIS_firm_level/rais_firm_2015.dta`
- `Data/CBA_RAIS_firm_level/rais_firm_2016.dta`

Auxiliary outputs used by CBA matching/connectivity:

- `Data/RAIS_aux/unique_firms_*.dta`
- `Data/RAIS_aux/worker_estab_*.dta`
- `Data/RAIS_aux/rais_mode_mun_ind.dta`

Cleanup status: do not delete until each file is classified as either a required
stage output or a reproducible intermediate.

### 2. CBA Cleaning and Establishment Matching

Primary script:

`Programs/1030_clean_cba.do`

Main raw/current input:

`Data/CBA/cnes_contracts_coverage_updated.dta`

Important generated outputs:

- `Data/CBA/cba_coverage_clean.dta`
- `Data/CBA/cba_coverage_clean_firm.dta`
- `Data/CBA/cba_firm_exploded.dta`
- `Data/CBA/cba_estab_firm.dta`
- `Data/CBA/collapsed_cba_bunit_updated.dta`
- `Data/CBA/collapsed_cba_firm_updated.dta`

Notes:

- Sectoral CBA code is present but largely commented out in the current script.
- The firm-level path is the active path used by `1040_merge_cba_rais.do`.

Cleanup status: large CBA exploded files are likely generated intermediates, but
should not be deleted until the CBA stage can be rerun cleanly from raw inputs.

### 3. Merge RAIS and CBA, Define Samples

Primary script:

`Programs/1040_merge_cba_rais.do`

Inputs:

- `Data/CBA_RAIS_firm_level/rais_firm_*.dta`
- `Data/CBA/collapsed_cba_firm_updated.dta`
- `Data/IBGE/mun_microregion_ibge.dta`

Key outputs:

- `Data/CBA_RAIS_firm_level/cba_rais_firm_2007_2016.dta`
- `Data/RAIS_aux/lagos_sample.dta`
- `Data/RAIS_aux/lagos_sample.csv`
- `Data/RAIS_aux/lagos_control.dta`
- `Data/RAIS_aux/lagos_control.csv`
- `Data/RAIS_aux/lagos_treat.dta`
- `Data/RAIS_aux/lagos_treat.csv`
- `Data/RAIS_aux/1_cba_treat.dta`
- `Data/RAIS_aux/1_cba_treat.csv`
- `Data/RAIS_aux/0_cba_treat.csv`
- `Data/RAIS_aux/bal_pan.dta`

Important issue:

The zero-CBA treatment block saves `zero_cba_treat` to
`Data/RAIS_aux/1_cba_treat.dta` before exporting `0_cba_treat.csv`. That looks
like a bug or legacy typo and should be checked before declaring the pipeline
replication-ready.

### 4. Worker Flow and Connectivity Construction

Primary script:

`Programs/1050_yearly_employers.do`

Inputs:

- Raw RAIS yearly files from `$rais_raw_dir/RAIS_*.dta`
- Sample/treatment CSVs from `1040_merge_cba_rais.do`

Intermediate outputs:

- `Data/RAIS_aux/yearly_employers_2007.dta` through `yearly_employers_2011.dta`
- `Data/RAIS_aux/employers_2007_2008.dta`
- `Data/RAIS_aux/employers_2008_2009.dta`
- `Data/RAIS_aux/employers_2009_2010.dta`
- `Data/RAIS_aux/employers_2010_2011.dta`
- Matching `.csv` files for MATLAB

MATLAB scripts called:

- `Programs/1051_connectivity_full_lagos.m`
- `Programs/1052_connectivity_treat_lagos.m`
- `Programs/1053_connectivity_control_lagos.m`
- `Programs/1054_connectivity_treat_onecba.m`
- `Programs/1055_connectivity_treat_zerocba.m`

MATLAB outputs:

- `Data/RAIS_aux/connectivity_2007_2011.csv`
- `Data/RAIS_aux/connectivity_treat_2007_2011.csv`
- `Data/RAIS_aux/connectivity_control_2007_2011.csv`
- `Data/RAIS_aux/connectivity_onecba_2007_2011.csv`
- `Data/RAIS_aux/connectivity_zerocba_2007_2011.csv`

Aggregated connectivity outputs:

- `Data/RAIS_aux/connectivity_2007_2011_agg.dta`
- `Data/RAIS_aux/connectivity_treat_2007_2011_agg.dta`
- `Data/RAIS_aux/connectivity_control_2007_2011_agg.dta`
- `Data/RAIS_aux/connectivity_one_2007_2011_agg.dta`
- `Data/RAIS_aux/connectivity_zero_2007_2011_agg.dta`
- `Data/RAIS_aux/connectivity_2007_2011_tcl.dta`

Downstream firm-level outputs:

- `Data/CBA_RAIS_firm_level/cba_rais_firm_2009_2016_flows_1.dta`
- `Data/CBA_RAIS_firm_level/labor_analysis_sample.dta`
- `Data/CBA_RAIS_firm_level/lagos_sample_sep24_test.dta`

Open reconstruction issue:

The current `1050_yearly_employers.do` gets close to the protected connectivity
measure but is not confirmed to reproduce the exact connectivity in
`lagos_sample_sep24_pct_unionexp_ext_df2.dta`. Until this is resolved, preserve
all plausible connectivity inputs and outputs.

### 5. Union Exposure and Worker Percentiles

Known scripts:

- `Programs/union_treat_exp.do`
- `Programs/2020_get_wage_pctiles.do`
- `Programs/2030_get_wage_pctiles_df2.do`

Known lineage:

- `union_treat_exp.do` reads `cba_rais_firm_2007_2016.dta` and writes
  `Data/RAIS_aux/union_treat_exp_sep24.dta`.
- `2030_get_wage_pctiles_df2.do` reads worker-level wage data and
  `lagos_sample_sep24_pct_unionexp.dta`, then writes the protected target.

Missing link to document:

The script or manual step that creates
`Data/CBA_RAIS_firm_level/lagos_sample_sep24_pct_unionexp.dta` from the
connectivity-enriched sample needs to be identified.

### 6. Analysis Modules

Main analysis scripts currently read the protected target directly:

- `Programs/4012_pct_tfpw.do`
- `Programs/UnionSpillovers_FinalResults_gtfpe_gout_alldir_0conn.do`
- `Programs/composition/4092_composition.do`
- `Programs/composition/Main_Results_composition_log.do`
- `Programs/composition/Main_Results_composition_scale.do`
- `Programs/descriptives/4102_sample_descriptives.do`

Common extra inputs:

- `Data/RAIS_aux/totalflows_wide_2007_2011.csv`
- `Data/RAIS_aux/corrected_turnover_sample.csv`

Replication cleanup goal: analysis modules should read a clearly named
analysis-ready file from a stable location and should not depend on hidden manual
patches.

## Immediate Organization Tasks

1. Identify the missing step that creates
   `lagos_sample_sep24_pct_unionexp.dta`.
2. Compare the protected file's connectivity variables against current
   `1050_yearly_employers.do` outputs.
3. Decide whether `Programs/pipeline_main_data.do` should become the canonical
   runner or remain a transition runner beside `Programs/0000_master.do`.
4. Only after steps 1-3, classify large data files as required input, protected
   reference, reproducible intermediate, analysis output, or disposable clutter.
