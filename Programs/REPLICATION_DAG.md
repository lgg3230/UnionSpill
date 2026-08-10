# Replication DAG — raw RAIS to paper exhibits

**Built 2026-08-09.** Companion to `INVENTORY.md` (exhibit → producing script) and
`quality_reports/sample_provenance.md` (exhibit → sample → definition site). This file
records the *dependency graph*: what each stage reads, what it writes, and whether that
link is reproducible today.

Driven by `Programs/0000_master.do`, which groups every stage into six tiers of flags, all
off by default.

---

## Status legend

| Mark | Meaning |
|---|---|
| **OK** | Runs today; output verified against the published artifact where one exists |
| **RUNNABLE** | Script and inputs present; not verified against a published artifact |
| **BLOCKED** | Input absent from disk *and* produced by no script in `Programs/` |

---

## Tier A — raw RAIS to firm panel and connectivity

| Stage | Script | Reads | Writes | Status |
|---|---|---|---|---|
| A1 | `1010_rais_to_firm.do` | `$rais_raw_dir/RAIS_{year}.dta` | firm-year files | RUNNABLE |
| A2 | `1020_clean_emp_assoc.do` | `$emp_assoc` | cleaned assoc. | RUNNABLE |
| A3 | `1030_clean_cba.do` + `explode_cba_coverage_*.py` | `$cba_dir` | cleaned CBAs | RUNNABLE |
| A4 | `1040_merge_cba_rais.do` | A1 + A3 | `cba_rais_firm_2007_2016.dta` (37 GB) | RUNNABLE |
| A5 | `1050_yearly_employers.do` | A4 + raw RAIS | `yearly_employers_*`, `employers_*_*.csv`, then shells five MATLAB scripts (`1051`…`1055_connectivity_*.m`) → `connectivity_*_2007_2011_agg.dta`, `cba_rais_firm_2009_2016_flows_1.dta` (56 GB), `lagos_sample_sep24_test.dta` | RUNNABLE |
| A6 | `1060_rais_worker_panel.do` | raw RAIS | `worker_estab_{year}.dta`, `worker_estab_all_years.dta` (63 GB) | RUNNABLE |

`1040_merge_cba_rais.do` also defines the three sample variables every estimator filters on:
`treat_ultra` (:161), `in_balanced_panel` (:198), `lagos_sample_avg` (:117).

---

## Tier B — frozen analysis panel — **BLOCKED**

| Stage | Script | Reads | Writes | Status |
|---|---|---|---|---|
| B1 | `2010_merge_lagos_worker.do` | `lagos_sample_sep24.dta` + `worker_estab_all_years.dta` | `lagos_sample_workers.dta` | RUNNABLE (output currently absent) |
| B2 | `2020_get_wage_pctiles.do` | `lagos_sample_workers.dta`, **`lagos_sample_sep24_pct_unionexp.dta`** | `lagos_sample_sep24_pct{,_unionexp_ext}.dta` | **BLOCKED** |
| B3 | `2030_get_wage_pctiles_df2.do` | **`worker_year_pre_new_vs_nonnew_dec26.dta`**, `lagos_sample_sep24_pct_unionexp.dta` | `lagos_sample_sep24_pct_unionexp_ext_df2.dta` | **BLOCKED** |

Two datasets are absent from disk and written by no script in `Programs/`:

```
Data/CBA_RAIS_firm_level/lagos_sample_sep24_pct_unionexp.dta
Data/CBA_RAIS_firm_level/worker_year_pre_new_vs_nonnew_dec26.dta
```

This is H2 of `sample_provenance.md`, independently found by
`main_data_pipeline/PIPELINE_STATUS.md` in April 2026 and never closed. Consequence: the
**frozen panel is a protected input** (140,773 obs × 550 vars, 194,200,617 B, 2026-03-02).
Tier B in `0000_master.do` refuses to run without the second opt-in flag
`allow_rebuild_frozen_panel`, because a partial rebuild would produce a panel differing
from the one every published number rests on, without announcing it.

Separately fixed 2026-08-09: `2030_get_wage_pctiles_df2.do:9` read `use "...", clearf`,
a syntax error that would have stopped the script on its first line regardless.

---

## Tier C — current-connectivity overlay — **OK, verified**

| Stage | Script | Reads | Writes | Status |
|---|---|---|---|---|
| C1 | `main_results/3010_build_currentconn_ingredient.do` | frozen panel + `connectivity_treat_2007_2011_agg.dta` (A5) | `currentconn_overlay_totaltreat.dta` | **OK** |
| C2 | `main_results/3020_build_currentconn_overlay_panel.do` | frozen panel + C1 | overlay panel (140,773 × 551) | **OK** |

Both were written 2026-08-09 to close H1 of `sample_provenance.md` — "no script in
`Programs/` writes the overlay panel", the hazard that made every published exhibit rest
on a binary of unrecorded provenance. The recipe was not lost, only inlined inside two
estimators rather than factored into a build step:
`layer_connectivity_standalone/scripts/05a_within_firm_estimates.do:190-199` and its R port
`within_firm_final/R/02_build.R:29-41`, both of which apply it in memory and never persist it.

**Verification.** Each stage was built to a scratch directory and compared with `cf _all`
against the published artifact. Both are silent — value-identical on every variable and
every row. A negative control (perturb one cell) confirms `cf` does report differences, so
the silence is real. The p90 diagnostics also reproduce exactly: legacy 0.02932389, current
0.02925788.

**The overlay is a 1-column swap, nothing more.** `totaltreat_pw_n` is renamed to
`totaltreat_pw_n_frozen` in place (position 90) and the current measure is appended
(position 551). No rows are dropped; 2,204 firm-years carry a different value, 16 are missing.

### Two traps recorded in the scripts

1. **`merge … update` silently drops conflicting rows.** With `update` in play, Stata
   resolves `keep(master match)` to result code 3 *only*, so rows coded 4 (missing updated)
   and 5 (nonmissing conflict) are discarded *before* the merge report prints — and the
   report then shows "nonmissing conflict 0". In C2 that dropped 2,220 of 140,773 rows:
   precisely the 2,204 that differ plus the 16 missing, i.e. the entire content of the
   overlay. Fixed by renaming first and using a plain merge.
2. **`totaltreat_pw_norm` is deliberately not rebuilt.** The published overlay carries it on
   the *legacy* divisor, and nine estimators rebuild it in-script. C2 prints both p90s so
   the discrepancy is visible in the log rather than latent.

---

## Tier D — estimators

Thirteen estimators from `INVENTORY.md §G`, each dispatched by `0000_master.do` as a **fresh
`stata-mp` process**. This is not stylistic: `reghdfe` carries session state, and running
two exercises in one process shifts coefficients in the sixth digit — `clear all` does not
reset it.

All thirteen wrappers point `$rais_firm` at the **overlay** directory, not the frozen one
(verified in `sample_provenance.md §3`).

| Flag | Wrapper | Estimator |
|---|---|---|
| `d_pct_tfpw` | `4011_pct_tfpw.do` | `4012_pct_tfpw.do` |
| `d_direct_coef_test` | `conn_margins/4021_direct_sample_coef_test.do` | `4022_direct_sample_coef_test.do` |
| `d_clause_types` | `clause_types/4031_clause_types.do` | `4032_clause_types.do` |
| `d_cba_value` | `cba_value/4041_cba_value.do` | `4042_cba_value.do` |
| `d_robustness` | `robustness/4051_robustness_bins.do` | `4052_robustness_bins.do` |
| `d_micro_ind_q` | `robustness/4061_micro_ind_q.do` | `4062_micro_ind_q.do` |
| `d_union_controls` | `robustness/4071_union_controls.do` | `4072_union_controls.do` |
| `d_turnover` | `turnover/4081_turnover.do` | `4082_turnover.do` |
| `d_composition` | `composition/4091_composition.do` | `4092_composition.do` |
| `d_descriptives` | `descriptives/4101_sample_descriptives.do` | `4102_sample_descriptives.do` |
| `d_mincer` | `main_results/4111_mincer.do` | `residuals/4112_mincer.do` |
| `d_within_firm` | `layer_connectivity/07_within_firm/4121_within_firm.do` | `4122_within_firm.do` |
| `d_within_firm_hw` | `layer_connectivity/07_within_firm/4131_within_firm_hourly.do` | `4132_within_firm_hourly.do` |

**Benchmarks.** Direct 0.0262 (monthly) / 0.0285 (hourly); spillover 0.0050 (monthly) /
0.0065 (hourly). A baseline column that disagrees means the wrong panel or the wrong
normalization — stop and diagnose.

### The turnover CSV stub

`Data/RAIS_aux/corrected_turnover_sample.csv` is a **47-byte header-only stub**. The real
27 MB / 131,776-row file that `turnover/011b_corrected_turnover.py` writes lives under
`$rais_firm`. Two canonical estimators read the stub and so merged nothing:
`4012_pct_tfpw.do:47` and `robustness/4052_robustness_bins.do:36`.

In both, the merge feeds only `churn_u` and `churn_rate_u`, which are constructed and then
**never used**. No published number was affected. Both paths were repointed at `$rais_firm`
on 2026-08-09 so the code is not silently broken; `4082_turnover.do:48` already read
the real file.

---

## Tier E — tables and figures

Nine table generators plus `5100_inline_into_replication.py`, then the figure scripts. See
`0000_master.do` for the exact list.

`rand_inference/5152_recentered_eventstudy.do` was parameterized on 2026-08-09. It previously
set `local out "lr_remdezr_w"` at line 30 but hardcoded the outcome into all four export
filenames, so the local was inert and the **hourly pair that Draft.tex actually cites**
(`h_recentered_spill.pdf`, `h_recentered_cf.pdf`, lines 493 and 500) could not be produced
at all. Outcome, `$graphs` and `$paperfig` are now caller-overridable; run via
`rand_inference/5151_recentered_eventstudy.do <outcome>`. Verified for `lr_remdezr_h_w`: both PDFs
generate, pooled main 0.0066 (0.0023).

---

## Tier F — exhibits into the paper

`main_results/6010_copy_figures_to_paper.py` replaces the undocumented hand-copy-with-renaming
that `INVENTORY.md §C` describes. **Dry run by default**: it reports every file it would
replace with both md5s and writes nothing unless `--apply` is passed.

State as of 2026-08-09: 8 of 17 mapped figures already hash-match the paper (including all
four event studies), 7 differ (binscatters, `conn_hist`, the monthly recentered pair — the
D4 vintage drift), 2 were missing and are now producible (the hourly recentered pair).

Event-study sources are date-stamped (`es_..._directA__3_Aug_2026.pdf`), so the map globs and
takes the most recently modified match.

---

## Corrections to INVENTORY.md

| INVENTORY claim | Actual |
|---|---|
| Draft.tex has "13 tables, 6 figures" | 12 `table` floats, 7 `figure` floats, 13 `\includegraphics` |
| Honest-DiD figures are paper figures (§C, D4) | `grep -i honest Draft.tex` returns nothing — not in the draft. Phase 2. |
| v3 within-firm files are UNTRACKED (§G) | Tracked; committed in `7b2a49f` |
| "No script writes into paper Figures" (§C) | Four `rand_inference/` scripts write to `UnionSpill-paper/Figures/Main`. Draft.tex reads `Replication/Figures/`, a different directory. |
| `m_dir_es.pdf` ← `..._1_Aug_2026.pdf` | The `3_Aug_2026` files are the hash-exact match |

---

## What this file does not establish

- Tier A stages are marked RUNNABLE, not OK: none was re-executed here, because doing so
  rewrites 37–63 GB artifacts. Their scripts and inputs were confirmed present, and their
  declared write targets were read from source, not inferred from filenames.
- The two BLOCKED datasets were not reconstructed. Until they are, "raw RAIS to exhibits"
  runs in two verifiable halves joined by a protected input, not one continuous chain.
- Phase-2 directories (`honest_did/`, `cba_similarity/`, `max_clause_row/`, and the rest of
  the `INVENTORY.md §E` "no traced exhibit" list) are not wired into any tier yet.

---

## Naming scheme

Every script in the chain carries a digit-only prefix, so run order and dependency
are visible from `ls` alone. No letter codes, no separators inside the number.

```
T SS K      T  = tier
            SS = stage within the tier (01-99)
            K  = step: 0 single script, 1 wrapper, 2 payload

T:  0 master   1 raw RAIS -> firm panel + connectivity
               2 -> frozen analysis panel (fenced)
               3 -> current-connectivity overlay
               4 -> estimators
               5 -> tables and figures
               6 -> paper
```

The stage field is two digits because tier 4 has 13 stages and tier 5 has 15; a
one-digit field would overflow at 9. The `K` digit also fixes parent ordering:
`1050_yearly_employers.do` sorts before its five MATLAB children `1051`-`1055`.

```
0000_master.do
1010_rais_to_firm.do            tier 1, stage 01
1050_yearly_employers.do        tier 1, stage 05, parent
1051_connectivity_full_lagos.m  tier 1, stage 05, step 1
4011_pct_tfpw.do                tier 4, stage 01, wrapper
4012_pct_tfpw.do                tier 4, stage 01, payload
4131_within_firm_hourly.do      tier 4, stage 13, wrapper
```

Files keep their existing directory, so the pipeline-subfolder convention is intact;
only the basename changed. Sibling wrappers outside the chain (`_run_turnover_log.do`,
`_run_within_firm_v3ml.do`, and the rest) keep their names but had their internal
calls repointed, so they still run.

Applied 2026-08-09/10 in two passes, 60 files, 0 dangling references after each.
Renaming used stem-plus-extension matching with boundary anchors on both sides,
longest stem first. Two hazards this guards against, both hit in practice:
stems that double as directory names (`clause_types` is also `Programs/clause_types/`
and appears bare in `cap mkdir "$tables/clause_types"`), and prefix collisions
(`05_yearly_employers` inside `05_yearly_employers_post`; `Main_Results_turnover`
inside `Main_Results_turnover_scale`).

Not rewritten, because each holds its own copies and rewriting would corrupt their
self-references: `Old/`, `Programs_2025.05.03/`, `main_data_pipeline{,_duckdb}/`,
`layer_connectivity_standalone/`.

### Rename map — original name to current name

| Current | Directory | Original |
|---|---|---|
| `0000_master.do` | `Programs/` | `00_master.do` |
| `1010_rais_to_firm.do` | `Programs/` | `011_rais_to_firm.do` |
| `1020_clean_emp_assoc.do` | `Programs/` | `02_clean_emp_assoc.do` |
| `1030_clean_cba.do` | `Programs/` | `031_clean_cba.do` |
| `1040_merge_cba_rais.do` | `Programs/` | `041_merge_cba_rais.do` |
| `1050_yearly_employers.do` | `Programs/` | `05_yearly_employers.do` |
| `1051_connectivity_full_lagos.m` | `Programs/` | `connectivity_full_lagos.m` |
| `1052_connectivity_treat_lagos.m` | `Programs/` | `connectivity_treat_lagos.m` |
| `1053_connectivity_control_lagos.m` | `Programs/` | `connectivity_control_lagos.m` |
| `1054_connectivity_treat_onecba.m` | `Programs/` | `connectivity_treat_onecba.m` |
| `1055_connectivity_treat_zerocba.m` | `Programs/` | `connectivity_treat_zerocba.m` |
| `1060_rais_worker_panel.do` | `Programs/` | `012_rais_worker_panel.do` |
| `2010_merge_lagos_worker.do` | `Programs/` | `10_merge_lagos_worker.do` |
| `2020_get_wage_pctiles.do` | `Programs/` | `12_get_wage_pctiles.do` |
| `2030_get_wage_pctiles_df2.do` | `Programs/` | `121_get_wage_pctiles_df2.do` |
| `3010_build_currentconn_ingredient.do` | `Programs/main_results/` | `build_currentconn_ingredient.do` |
| `3020_build_currentconn_overlay_panel.do` | `Programs/main_results/` | `build_currentconn_overlay_panel.do` |
| `4011_pct_tfpw.do` | `Programs/` | `_run_pct_tfpw_07_11_cc.do` |
| `4012_pct_tfpw.do` | `Programs/` | `Main_Results_pct_tfpw_07_11.do` |
| `4021_direct_sample_coef_test.do` | `Programs/conn_margins/` | `_run_direct_sample_coef_test_cc.do` |
| `4022_direct_sample_coef_test.do` | `Programs/conn_margins/` | `direct_sample_coef_test.do` |
| `4031_clause_types.do` | `Programs/clause_types/` | `_run_clause_types_cc.do` |
| `4032_clause_types.do` | `Programs/clause_types/` | `clause_types.do` |
| `4041_cba_value.do` | `Programs/cba_value/` | `_run_cba_value_cc.do` |
| `4042_cba_value.do` | `Programs/cba_value/` | `Main_Results_cba_value.do` |
| `4051_robustness_bins.do` | `Programs/robustness/` | `_run_robustness_cc.do` |
| `4052_robustness_bins.do` | `Programs/robustness/` | `Main_Results_robustness_bins.do` |
| `4061_micro_ind_q.do` | `Programs/robustness/` | `_run_micro_ind_q_hw.do` |
| `4062_micro_ind_q.do` | `Programs/robustness/` | `Main_Results_micro_ind_q.do` |
| `4071_union_controls.do` | `Programs/robustness/` | `_run_union_controls_hw_cc.do` |
| `4072_union_controls.do` | `Programs/robustness/` | `Main_Results_union_controls.do` |
| `4081_turnover.do` | `Programs/turnover/` | `_run_turnover_cc.do` |
| `4082_turnover.do` | `Programs/turnover/` | `Main_Results_turnover.do` |
| `4091_composition.do` | `Programs/composition/` | `_run_composition_cc.do` |
| `4092_composition.do` | `Programs/composition/` | `Main_Results_composition.do` |
| `4101_sample_descriptives.do` | `Programs/descriptives/` | `_run_descriptives_estsample.do` |
| `4102_sample_descriptives.do` | `Programs/descriptives/` | `22_sample_descriptives.do` |
| `4111_mincer.do` | `Programs/main_results/` | `_run_currentconn_mincer_age_fullrais.do` |
| `4112_mincer.do` | `Programs/residuals/` | `Main_Results_mincer.do` |
| `4121_within_firm.do` | `Programs/layer_connectivity/07_within_firm/` | `_run_within_firm_v3.do` |
| `4122_within_firm.do` | `Programs/layer_connectivity/07_within_firm/` | `01c_within_firm_estimates.do` |
| `4131_within_firm_hourly.do` | `Programs/layer_connectivity/07_within_firm/` | `_run_within_firm_hw_v3.do` |
| `4132_within_firm_hourly.do` | `Programs/layer_connectivity/07_within_firm/` | `01c_within_firm_estimates_hw.do` |
| `5010_table_direct.py` | `Programs/main_results/` | `generate_direct_replication_table.py` |
| `5020_table_spill.py` | `Programs/main_results/` | `generate_spill_replication_table.py` |
| `5030_table_twopanel.py` | `Programs/main_results/` | `generate_twopanel_replication_tables.py` |
| `5040_table_clause.py` | `Programs/clause_types/` | `generate_clause_replication_table.py` |
| `5050_table_union.py` | `Programs/robustness/` | `generate_union_replication_table.py` |
| `5060_table_rob_logwages.py` | `Programs/robustness/` | `generate_rob_logwages_8col.py` |
| `5070_table_resid.py` | `Programs/residuals/` | `generate_resid_replication_tables.py` |
| `5080_table_pairwise_appendix.py` | `Programs/conn_descriptives/` | `generate_pairwise_appendix_table.py` |
| `5090_table_within_firm.py` | `Programs/layer_connectivity/07_within_firm/` | `02b_make_tables_all.py` |
| `5100_inline_into_replication.py` | `Programs/layer_connectivity/07_within_firm/` | `05_inline_into_replication.py` |
| `5110_figure_bilateral_coefplot.py` | `Programs/conn_descriptives/` | `06_bilateral_coefplot_combined.py` |
| `5120_figure_distributions.py` | `Programs/descriptives/` | `distribution_plots.py` |
| `5130_figure_binscatter.py` | `Programs/rand_inference/` | `13_binscatter.py` |
| `5140_figure_conn_hist.py` | `Programs/conn_descriptives/` | `hist_connectivity.py` |
| `5151_recentered_eventstudy.do` | `Programs/rand_inference/` | `_run_recentered.do` |
| `5152_recentered_eventstudy.do` | `Programs/rand_inference/` | `16_recentered_eventstudy.do` |
| `6010_copy_figures_to_paper.py` | `Programs/main_results/` | `copy_figures_to_paper.py` |
