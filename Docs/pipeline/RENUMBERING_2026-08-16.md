# Renumbering, 2026-08-16

The parallel pipeline was promoted and every chain script renumbered so that
**the digits are a topological order of the dependency graph**: no script reads a
file written by a higher-numbered script. Scripts with no dependency between them
are ordered for readability.

Tier C (the current-connectivity overlay) was retired earlier, so the tier letters
close the gap: what were tiers D, E and F are now C, D and E.

| | before | after |
|---|---|---|
| raw RAIS -> firm panel + connectivity | A, 1010-1070 | **A, 1010-1050** |
| firm panel -> analysis panel | B, 2010-2050 | **B, 2010-2050** |
| overlay | C, 3010-3020 | *retired* |
| analysis panel -> estimates | D, 4011-4132 | **C, 3011-3132** |
| estimates -> tables and figures | E, 5010-5220 | **D, 4010-4220** |
| exhibits -> paper | F, 6010 | **E, 5010** |

## Promotion

| action | file |
|---|---|
| promoted | `parallel/1010p_rais_clean_combined.do` -> `1010_rais_clean.do` |
| promoted | `parallel/1050p_yearly_employers.do` -> `1040_yearly_employers.do` |
| retired | `1010_rais_to_firm.do` (superseded by the combined pass) |
| retired | `1060_rais_worker_panel.do` (absorbed into 1010) |
| retired | `1050_yearly_employers.do` (superseded by 1040) |
| moved out of the chain | `1020_clean_emp_assoc.do` |

Retired scripts are in `archive/Programs/superseded_2026-08-16/`.

**Why 1020_clean_emp_assoc.do left the numbered sequence.** It reads
`unique_estab_{y}.dta`, which is written only inside the commented-out block at the
tail of the old 1010, and no such file exists on disk. Nothing in the CBA merge, the
flows stage or tier B reads its outputs (`$emp_assoc/`, `unique_firms_*`). It is not
runnable as part of the chain and has no position in the dependency order, so giving
it a number would assert a relationship that does not exist.

## Old -> new map

| old | new |
|---|---|
| `1010p_rais_clean_combined.do` | `1010_rais_clean.do` |
| `1030_clean_cba.do` | `1020_clean_cba.do` |
| `1031_explode_cba_coverage_firm.py` | `1021_explode_cba_coverage_firm.py` |
| `1032_explode_cba_coverage_sector.py` | `1022_explode_cba_coverage_sector.py` |
| `1040_merge_cba_rais.do` | `1030_merge_cba_rais.do` |
| `1050p_yearly_employers.do` | `1040_yearly_employers.do` |
| `1051_connectivity_full_lagos.m` | `1041_connectivity_full_lagos.m` |
| `1052_connectivity_treat_lagos.m` | `1042_connectivity_treat_lagos.m` |
| `1053_connectivity_control_lagos.m` | `1043_connectivity_control_lagos.m` |
| `1054_connectivity_treat_onecba.m` | `1044_connectivity_treat_onecba.m` |
| `1055_connectivity_treat_zerocba.m` | `1045_connectivity_treat_zerocba.m` |
| `1070_corrected_turnover.py` | `1050_corrected_turnover.py` |
| `2040_build_pct_unionexp.do` | `2030_build_pct_unionexp.do` |
| `2050_build_worker_panel_w.do` | `2040_build_worker_panel_w.do` |
| `2030_get_wage_pctiles_df2.do` | `2050_build_analysis_panel.do` |
| `4011_pct_tfpw.do` | `3011_pct_tfpw.do` |
| `4012_pct_tfpw.do` | `3012_pct_tfpw.do` |
| `5160_table_pct_latex.py` | `4160_table_pct_latex.py` |
| `4041_cba_value.do` | `3041_cba_value.do` |
| `4042_cba_value.do` | `3042_cba_value.do` |
| `5200_table_cba_value_latex.py` | `4200_table_cba_value_latex.py` |
| `4031_clause_types.do` | `3031_clause_types.do` |
| `4032_clause_types.do` | `3032_clause_types.do` |
| `5040_table_clause.py` | `4040_table_clause.py` |
| `4091_composition.do` | `3091_composition.do` |
| `4092_composition.do` | `3092_composition.do` |
| `5080_table_pairwise_appendix.py` | `4080_table_pairwise_appendix.py` |
| `5110_figure_bilateral_coefplot.py` | `4110_figure_bilateral_coefplot.py` |
| `5140_figure_conn_hist.py` | `4140_figure_conn_hist.py` |
| `4021_direct_sample_coef_test.do` | `3021_direct_sample_coef_test.do` |
| `4022_direct_sample_coef_test.do` | `3022_direct_sample_coef_test.do` |
| `4101_sample_descriptives.do` | `3101_sample_descriptives.do` |
| `4102_sample_descriptives.do` | `3102_sample_descriptives.do` |
| `5120_figure_distributions.py` | `4120_figure_distributions.py` |
| `5220_table_descriptives.py` | `4220_table_descriptives.py` |
| `4121_within_firm.do` | `3121_within_firm.do` |
| `4122_within_firm.do` | `3122_within_firm.do` |
| `4131_within_firm_hourly.do` | `3131_within_firm_hourly.do` |
| `4132_within_firm_hourly.do` | `3132_within_firm_hourly.do` |
| `5090_table_within_firm.py` | `4090_table_within_firm.py` |
| `5100_inline_into_replication.py` | `4100_inline_into_replication.py` |
| `4111_mincer.do` | `3111_mincer.do` |
| `5010_table_direct.py` | `4010_table_direct.py` |
| `5020_table_spill.py` | `4020_table_spill.py` |
| `5030_table_twopanel.py` | `4030_table_twopanel.py` |
| `6010_copy_figures_to_paper.py` | `5010_copy_figures_to_paper.py` |
| `5130_figure_binscatter.py` | `4130_figure_binscatter.py` |
| `5151_recentered_eventstudy.do` | `4151_recentered_eventstudy.do` |
| `5152_recentered_eventstudy.do` | `4152_recentered_eventstudy.do` |
| `4112_mincer.do` | `3112_mincer.do` |
| `5070_table_resid.py` | `4070_table_resid.py` |
| `5190_table_mincer_latex.py` | `4190_table_mincer_latex.py` |
| `4051_robustness_bins.do` | `3051_robustness_bins.do` |
| `4052_robustness_bins.do` | `3052_robustness_bins.do` |
| `4061_micro_ind_q.do` | `3061_micro_ind_q.do` |
| `4062_micro_ind_q.do` | `3062_micro_ind_q.do` |
| `4071_union_controls.do` | `3071_union_controls.do` |
| `4072_union_controls.do` | `3072_union_controls.do` |
| `5050_table_union.py` | `4050_table_union.py` |
| `5060_table_rob_logwages.py` | `4060_table_rob_logwages.py` |
| `5170_table_robustness_latex.py` | `4170_table_robustness_latex.py` |
| `5180_table_union_controls_latex.py` | `4180_table_union_controls_latex.py` |
| `4081_turnover.do` | `3081_turnover.do` |
| `4082_turnover.do` | `3082_turnover.do` |
| `5210_table_turnover_latex.py` | `4210_table_turnover_latex.py` |

## Verification

Every producer -> consumer edge extracted from the source and checked
mechanically. **15 edges, 2 flagged**, both the same structure:

| consumer | reads | producer |
|---|---|---|
| `1020_clean_cba.do` | `cba_firm_exploded.dta` | `1021_explode_cba_coverage_firm.py` |
| `1040_yearly_employers.do` | `connectivity_*.csv` | `1041`-`1045` (MATLAB) |

**These cannot be fixed by renumbering, and are not the pattern the invariant is
aimed at.** Both are a stage that shells its own helper and consumes the result:
1020 writes `cba_coverage_clean_firm.dta`, calls the exploders, reads
`cba_firm_exploded.dta` back; 1040 writes `employers_*.csv`, shells the five MATLAB
scripts, reads `connectivity_*.csv` back. The dependency is *inside* one stage, and
it is genuinely cyclic at file level, so no linear numbering of two scripts can
express it. Splitting each stage into a pre-helper and post-helper script would
linearise it at the cost of two more files and a shared temporary state.

The `T SS K` step digit already encodes this: `1021` is step 1 **of stage 1020**,
not a later stage. A replicator runs stage 1020 as a unit. The invariant the user
asked for -- never seeing a `1020` consume a `1030` output, i.e. across stages --
holds everywhere.


---

## Directory restructure, same day

`Programs/` is now organised by role rather than being flat:

```
Programs/
    0000_master.do
    notify.sh
    fonts/
    sample_construction/     10xx and 20xx: raw RAIS -> analysis panel
    analysis/
        cba_value/  clause_types/  composition/  conn_descriptives/
        conn_margins/  descriptives/  layer_connectivity/  main_results/
        rand_inference/  residuals/  robustness/  turnover/
```

- `1050_corrected_turnover.py` moved from `turnover/` to `sample_construction/`;
  it is a 10-series stage and belonged with the rest of the chain.
- `3011`/`3012_pct_tfpw.do` and `4160_table_pct_latex.py` moved from the flat root
  into `analysis/main_results/`.

**Path consequences that had to be fixed, not just the moves:**

| what | why |
|---|---|
| 15 Python files | `Path(__file__).resolve().parents[N]` and `.parent.parent.parent` resolve to the project root. Every script that gained a directory level needed `N+1`; `4160` gained two levels and needed `N+2`. All 12 root-resolving expressions were re-verified to land on the project root. |
| `1040_yearly_employers.do` | shells its MATLAB scripts via `$programs/`, now `$programs/sample_construction/` |
| 15 wrapper do-files | `do "$programs/<sub>/..."` -> `do "$programs/analysis/<sub>/..."` |
| `3121`/`3131` | set their own `$programs` to an absolute subpath |
| `0000_master.do` | every call site |

## Logs never land in Programs/

`stata-mp -b do X.do` writes `X.log` into the **current directory**, not next to the
do-file, so a batch run started from inside `Programs/` would drop logs there. Fixed
at the source: all 32 shelled calls in `0000_master.do` now run `cd "$logs" &&`
first, so batch logs go to `Logs/`. `.gitignore` carries `Programs/**/*.log` and
`Programs/*.log` as a second line of defence.

## Verified

Tier A re-run end to end from the new layout, zero errors, and
`rais_firm_{2007,2011,2016}` are **identical on all 62 variables** to the
pre-restructure run. The reorganisation is inert with respect to output.


---

## Tier-B side branches numbered, same day

The three restored producer pipelines were on their own private numbering (`00_`,
`01a_`, `011f_`, `17b_`). They now carry `T SS K` prefixes like the rest of the
chain. They sit in tier B because they consume the worker panel that `2010` builds,
and their outputs feed tier-C estimators.

| range | directory | builds | consumed by |
|---|---|---|---|
| `2060`-`2078` | `sample_construction/layers/` | `Data/layer_connectivity/` | `07_within_firm/3121`, `3131` |
| `2080`-`2084` | `sample_construction/mincer_residuals/` | `mincer_residuals_*.csv` | `residuals/3112_mincer.do` |
| `2090`-`2106` | `sample_construction/rand_inference/` | permutation inputs | `4130`, `4151`, `4152` |

42 files renamed, cross-references and self-labels updated in 34 of them.

Two deliberate exceptions:

- **`layer_config.py` keeps its name.** It is imported as a module by 19 scripts
  (`from layer_config import ...`); a numeric prefix would make it an invalid Python
  identifier and break every one of them. It is configuration, not a pipeline step.
- **`2080_mincer_residuals.py` and `2083_mincer_residuals.do` share a number.** They
  are alternate implementations of the same step, not two steps.

Lineage references to archived predecessors (for example `06_prep_layer_outcomes.py`
in `99_archive/`) were left alone: they name files that still exist under those names
in `archive/`.

## Protected inputs still outstanding

Numbering these branches makes visible that two of them start from files nothing in
the repository writes:

| missing artifact | needed by | note |
|---|---|---|
| `CBA_RAIS_firm_level/worker_panel_lagos.parquet` | `2061`, `2080`, `2081` | conceptually `lagos_sample_workers.dta` (2010's output) in parquet; likely a small export step |
| `CBA_RAIS_firm_level/fullrais_panel/worker_panel_fullrais_{year}.parquet` | `2083` (the published mincer path) | producer absent from `Programs/` and `archive/` |

Both exist on disk. Both are the same class of gap tier B had before the 2026-08-16
reconstruction: the estimator is reproducible, its input is not.
