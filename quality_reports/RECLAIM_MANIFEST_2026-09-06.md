# Disk reclaim manifest — 2026-09-06

Built to decide how much space to free before the full from-scratch rerun of
`Programs/0000_master.do`. Scope: every file in `Data/` at or above 100 MB
(177 files, 410.6 GB of the 413 GB total).

**Nothing here has been deleted.** This is a review document.

## Method

For each file, the basename is reduced to a stem by stripping trailing `_YYYY`
groups repeatedly (so `employers_2007_2008.csv` -> `employers`, matching the
literal a year-looped script would contain), then that stem is searched with
`grep -rlF` across three trees:

- `Programs/` — the live chain. Any hit means KEEP.
- `archive/` — 759 non-chain exploration scripts.
- `Docs/` + `CLAUDE.md` — documentation.

A file with zero hits in `Programs/` cannot be read by the chain, so deleting it
cannot affect a replication run. The tiers below split those by whether anything
else in the repo still mentions them.

## Caveat on the matcher

The stem reduction is deliberately loose: it over-matches rather than under-matches,
so a file is only called unreferenced when even a partial-name search finds nothing.
The risk of a false ORPHAN is therefore low, but it is not zero for files whose
name is constructed dynamically in code (e.g. a path built by string concatenation
from a variable). Spot-check anything surprising before deleting.

## Summary

| Tier | GB | Files | Meaning |
|---|---|---|---|
| KEEP | 285.5 | 119 | Referenced by `Programs/` — required by the chain |
| TIER 1 | 62.9 | 21 | Zero references in `Programs/`, `archive/`, `Docs/` |
| TIER 2 | 62.2 | 37 | Zero references in `Programs/`; still named in `archive/` or `Docs/` |

Free space now: 117 GB. Projected peak demand of the rerun: 80–110 GB.

## Spot-check verification of TIER 1

The six least-obvious TIER 1 entries were re-checked with a plain substring search
(no stem reduction) across `Programs/` and `archive/`. All six confirmed:

| Stem searched | Result |
|---|---|
| `dec_roster` | Zero hits anywhere in `Programs/`. Confirmed orphan despite a recent (2026-07-15) mtime. |
| `separations` | Hits are all *variable* names (`egen separations`, `gen turnover = separations/firm_emp`). No script reads or writes a `*_separations.dta` path, and only the 2009 file exists — no sibling years. Confirmed orphan. |
| `firm_chars_avg` | Zero hits. Confirmed orphan. |
| `connectivity_treat_2007_2011` | The `_agg.dta` / `_agg.parquet` variants **are** live (1040:346, layer_config.py:195). The `_yearly.dta` variant listed here is a different file and is referenced nowhere. Confirmed orphan. |
| `collapsed_cba_firm_1` | Zero hits; only the `_test` copy is listed. Confirmed orphan. |
| `bilateral_pairs_descriptives` | Zero hits. The published `bilateral_coefplot.pdf` and the pairwise appendix table read `Docs/fixtures/figure_A2/*.csv` instead. Confirmed orphan. |

No false positives were found, so the matcher's over-matching design held.

## TIER 1 — no references anywhere (62.9 GB, 21 files)

| GB | Modified | File |
|---|---|---|
| 26.54 | 2026-01-29 | `Data/RAIS_aux/bilateral_pairs_descriptives_post.csv` |
| 10.33 | 2025-11-11 | `Data/CBA_RAIS_firm_level/worker_estab_all_years_test.dta` |
| 8.15 | 2025-01-21 | `Data/CBA_RAIS/cba_rais_collapsed_firm_2009.dta` |
| 6.15 | 2026-02-02 | `Data/RAIS_aux/temp_bilateral_prep.duckdb` |
| 1.04 | 2026-01-14 | `Data/RAIS_aux/connectivity_zero_2007_2011_yearly.dta` |
| 1.04 | 2026-01-14 | `Data/RAIS_aux/connectivity_one_2007_2011_yearly.dta` |
| 0.99 | 2026-01-14 | `Data/RAIS_aux/connectivity_control_2007_2011_yearly.dta` |
| 0.99 | 2026-01-14 | `Data/RAIS_aux/connectivity_treat_2007_2011_yearly.dta` |
| 0.76 | 2026-07-15 | `Data/RAIS_aux/dec_roster_2014.parquet` |
| 0.75 | 2026-07-15 | `Data/RAIS_aux/dec_roster_2013.parquet` |
| 0.74 | 2026-07-15 | `Data/RAIS_aux/dec_roster_2015.parquet` |
| 0.72 | 2026-07-15 | `Data/RAIS_aux/dec_roster_2012.parquet` |
| 0.71 | 2026-07-15 | `Data/RAIS_aux/dec_roster_2016.parquet` |
| 0.70 | 2026-07-15 | `Data/RAIS_aux/dec_roster_2011.parquet` |
| 0.66 | 2026-07-15 | `Data/RAIS_aux/dec_roster_2010.parquet` |
| 0.65 | 2025-10-16 | `Data/RAIS_aux/2009_separations.dta` |
| 0.62 | 2026-07-15 | `Data/RAIS_aux/dec_roster_2009.parquet` |
| 0.60 | 2026-07-15 | `Data/RAIS_aux/dec_roster_2008.parquet` |
| 0.37 | 2025-07-02 | `Data/CBA/collapsed_cba_firm_1_test.dta` |
| 0.21 | 2026-01-20 | `Data/RAIS_aux/firm_chars_avg_j.dta` |
| 0.21 | 2026-01-20 | `Data/RAIS_aux/firm_chars_avg_i.dta` |

## TIER 2 — referenced only by archived scripts or docs (62.2 GB, 37 files)

| GB | Modified | File | archive refs | doc refs |
|---|---|---|---|---|
| 25.78 | 2026-01-21 | `Data/RAIS_aux/bilateral_pairs_descriptives.csv` | 1 | 0 |
| 9.28 | 2026-02-09 | `Data/RAIS_aux/bilateral_pairs_enhanced.parquet` | 7 | 0 |
| 3.36 | 2026-04-08 | `Data/CBA_RAIS_firm_level/cba_rais_firm_unbal_flows.dta` | 12 | 0 |
| 3.18 | 2026-02-03 | `Data/RAIS_aux/bilateral_cep_turnover.parquet` | 2 | 1 |
| 2.50 | 2026-03-11 | `Data/worker_wages/worker_wages_panel.dta` | 3 | 0 |
| 1.95 | 2025-10-06 | `Data/CBA_RAIS_firm_level/cba_rais_firm_2009_2016_flows_1cba.dta` | 1 | 0 |
| 1.80 | 2026-02-04 | `Data/RAIS_aux/bilateral_cep_improved.parquet` | 1 | 0 |
| 1.73 | 2025-07-09 | `Data/RAIS_aux/spill_samples_connectivity.dta` | 1 | 0 |
| 1.25 | 2025-11-12 | `Data/RAIS_aux/worker_estab_lagos.parquet` | 6 | 0 |
| 1.13 | 2026-01-26 | `Data/RAIS_aux/connectivity_treat_2011_2016_yearly.dta` | 2 | 0 |
| 1.09 | 2026-02-12 | `Data/RAIS_aux/connectivity_treat_2005_2011_6yr_yearly.dta` | 1 | 0 |
| 0.87 | 2026-04-14 | `Data/main_pipeline_duckdb/reports/stata_yearly_employers_2010.parquet` | 1 | 0 |
| 0.86 | 2026-04-08 | `Data/CBA_RAIS_firm_level/cba_rais_firm_unbal_flows.parquet` | 12 | 0 |
| 0.81 | 2026-04-14 | `Data/main_pipeline_duckdb/reports/stata_yearly_employers_2009.parquet` | 1 | 0 |
| 0.66 | 2026-01-14 | `Data/RAIS_aux/connectivity_zerocba_2007_2011.csv` | 0 | 3 |
| 0.66 | 2026-01-14 | `Data/RAIS_aux/connectivity_onecba_2007_2011.csv` | 1 | 3 |
| 0.61 | 2026-04-08 | `Data/CBA_RAIS_firm_level/cba_rais_firm_unbal_2009_2016.parquet` | 16 | 0 |
| 0.61 | 2026-04-14 | `Data/main_pipeline_duckdb/staging/rais_selected_2010.parquet` | 3 | 0 |
| 0.60 | 2026-04-08 | `Data/RAIS_aux/connectivity_treat_unbal_2007_2011.csv` | 7 | 1 |
| 0.56 | 2026-04-14 | `Data/main_pipeline_duckdb/staging/rais_selected_2009.parquet` | 3 | 0 |
| 0.37 | 2025-05-08 | `Data/CBA/collapsed_cba_firm_1.dta` | 5 | 0 |
| 0.32 | 2025-11-11 | `Data/CBA_RAIS_firm_level/lagos_sample_sep24_str.dta` | 0 | 1 |
| 0.27 | 2025-07-30 | `Data/CBA_RAIS_firm_level/analysis_missing_mu_sing.dta` | 1 | 0 |
| 0.26 | 2025-08-08 | `Data/CBA_RAIS_firm_level/labor_analysis_sample_aug6.dta` | 11 | 0 |
| 0.23 | 2026-02-12 | `Data/RAIS_aux/connectivity_treat_2005_2011_6yr.dta` | 2 | 0 |
| 0.22 | 2025-07-16 | `Data/CBA_RAIS_firm_level/labor_analysis_lagos.dta` | 1 | 0 |
| 0.16 | 2025-05-03 | `Data/RAIS_aux/rais_unique_estab_09_16.dta` | 2 | 0 |
| 0.13 | 2025-03-07 | `Data/stata_emp_assoc/SIC 38970 - 2010-2011.txt` | 3 | 0 |
| 0.12 | 2025-03-07 | `Data/stata_emp_assoc/SIC 38970 - 2016-2018.txt` | 3 | 0 |
| 0.12 | 2026-01-20 | `Data/RAIS_aux/firm_chars_2011.dta` | 1 | 0 |
| 0.12 | 2026-01-20 | `Data/RAIS_aux/firm_chars_2010.dta` | 1 | 0 |
| 0.11 | 2025-09-24 | `Data/RAIS_aux/1_cba_treat.dta` | 2 | 4 |
| 0.11 | 2026-01-20 | `Data/RAIS_aux/firm_chars_2009.dta` | 1 | 0 |
| 0.11 | 2025-09-24 | `Data/RAIS_aux/0_cba_treat.csv` | 1 | 4 |
| 0.11 | 2025-09-24 | `Data/RAIS_aux/1_cba_treat.csv` | 2 | 4 |
| 0.10 | 2025-03-07 | `Data/stata_emp_assoc/SIC 38970 - 2014-2015.txt` | 3 | 0 |
| 0.10 | 2025-03-07 | `Data/stata_emp_assoc/SIC 38970 - 2012-2013.txt` | 3 | 0 |

## KEEP — referenced by Programs/ (285.5 GB, 119 files)

| GB | Modified | File | Programs refs |
|---|---|---|---|
| 59.31 | 2026-04-29 | `Data/RAIS_aux/worker_estab_all_years.dta` | 2 |
| 55.31 | 2026-01-14 | `Data/CBA_RAIS_firm_level/cba_rais_firm_2009_2016_flows_1.dta` | 4 |
| 36.30 | 2025-09-24 | `Data/CBA_RAIS_firm_level/cba_rais_firm_2007_2016.dta` | 8 |
| 11.31 | 2026-01-30 | `Data/RAIS_aux/bilateral_regression_data.parquet` | 1 |
| 7.53 | 2026-02-23 | `Data/CBA_RAIS_firm_level/worker_panel_lagos.rds` | 13 |
| 5.54 | 2026-01-14 | `Data/CBA_RAIS_firm_level/labor_analysis_sample.dta` | 1 |
| 5.34 | 2026-04-29 | `Data/RAIS_aux/worker_estab_2009.dta` | 4 |
| 4.78 | 2026-08-11 | `Data/CBA_RAIS_firm_level/lagos_sample_workers.dta` | 4 |
| 2.80 | 2025-09-24 | `Data/CBA/cba_estab_firm.dta` | 1 |
| 2.47 | 2026-01-14 | `Data/RAIS_aux/employers_2010_2011.csv` | 17 |
| 2.39 | 2026-01-23 | `Data/RAIS_aux/employers_2014_2015.csv` | 17 |
| 2.37 | 2026-01-14 | `Data/RAIS_aux/employers_2009_2010.csv` | 17 |
| 2.37 | 2026-01-23 | `Data/RAIS_aux/employers_2013_2014.csv` | 17 |
| 2.33 | 2026-01-26 | `Data/RAIS_aux/employers_2015_2016.csv` | 17 |
| 2.26 | 2026-01-23 | `Data/RAIS_aux/employers_2012_2013.csv` | 17 |
| 2.25 | 2026-01-14 | `Data/RAIS_aux/employers_2008_2009.csv` | 17 |
| 2.24 | 2026-01-26 | `Data/RAIS_aux/employers_2011_2012.csv` | 17 |
| 2.24 | 2025-09-24 | `Data/CBA_RAIS_firm_level/cba_rais_firm_2007_1.dta` | 1 |
| 2.12 | 2026-01-14 | `Data/RAIS_aux/employers_2007_2008.csv` | 17 |
| 2.04 | 2026-04-14 | `Data/main_pipeline_duckdb/transitions/employers_2009_2010.csv` | 17 |
| 2.04 | 2026-02-12 | `Data/RAIS_aux/employers_2006_2007.csv` | 17 |
| 1.92 | 2026-02-12 | `Data/RAIS_aux/employers_2005_2006.csv` | 17 |
| 1.76 | 2025-12-26 | `Data/RAIS_aux/worker_year_pre_new_vs_nonnew.dta` | 3 |
| 1.68 | 2025-09-24 | `Data/CBA/collapsed_cba_bunit_updated.dta` | 1 |
| 1.66 | 2026-02-12 | `Data/RAIS_aux/employers_2006_2007.dta` | 17 |
| 1.59 | 2026-01-23 | `Data/RAIS_aux/yearly_employers_2014.dta` | 9 |
| 1.57 | 2026-01-23 | `Data/RAIS_aux/yearly_employers_2013.dta` | 9 |
| 1.56 | 2026-02-12 | `Data/RAIS_aux/employers_2005_2006.dta` | 17 |
| 1.55 | 2026-01-23 | `Data/RAIS_aux/yearly_employers_2015.dta` | 9 |
| 1.51 | 2026-01-23 | `Data/RAIS_aux/yearly_employers_2012.dta` | 9 |
| 1.49 | 2026-01-23 | `Data/RAIS_aux/yearly_employers_2016.dta` | 9 |
| 1.47 | 2026-01-14 | `Data/RAIS_aux/yearly_employers_2011.dta` | 9 |
| 1.40 | 2026-01-14 | `Data/RAIS_aux/yearly_employers_2010.dta` | 9 |
| 1.31 | 2026-01-14 | `Data/RAIS_aux/yearly_employers_2009.dta` | 9 |
| 1.26 | 2026-01-14 | `Data/RAIS_aux/yearly_employers_2008.dta` | 9 |
| 1.20 | 2026-03-02 | `Data/CBA_RAIS_firm_level/worker_panel_mincer.dta` | 3 |
| 1.20 | 2026-01-14 | `Data/RAIS_aux/yearly_employers_2007.dta` | 9 |
| 1.15 | 2026-02-22 | `Data/CBA_RAIS_firm_level/worker_panel_lagos.parquet` | 13 |
| 1.13 | 2026-02-12 | `Data/RAIS_aux/yearly_employers_2006.dta` | 9 |
| 1.07 | 2026-07-10 | `Data/CBA_RAIS_firm_level/fullrais_panel/worker_panel_fullrais_2014.parquet` | 4 |
| 1.07 | 2026-02-12 | `Data/RAIS_aux/yearly_employers_2005.dta` | 9 |
| 1.05 | 2026-07-10 | `Data/CBA_RAIS_firm_level/fullrais_panel/worker_panel_fullrais_2015.parquet` | 4 |
| 1.05 | 2026-07-10 | `Data/CBA_RAIS_firm_level/fullrais_panel/worker_panel_fullrais_2013.parquet` | 4 |
| 1.01 | 2026-07-10 | `Data/CBA_RAIS_firm_level/fullrais_panel/worker_panel_fullrais_2016.parquet` | 4 |
| 1.00 | 2026-07-10 | `Data/CBA_RAIS_firm_level/fullrais_panel/worker_panel_fullrais_2012.parquet` | 4 |
| 1.00 | 2026-02-12 | `Data/RAIS_aux/connectivity_treat_2005_2011.csv` | 4 |
| 0.97 | 2026-01-14 | `Data/RAIS_aux/connectivity_2007_2011_tcl.dta` | 1 |
| 0.97 | 2026-07-11 | `Data/CBA_RAIS_firm_level/fullrais_panel/worker_panel_fullrais_2011.parquet` | 4 |
| 0.93 | 2026-01-26 | `Data/RAIS_aux/connectivity_treat_2011_2016.csv` | 4 |
| 0.91 | 2026-07-10 | `Data/CBA_RAIS_firm_level/fullrais_panel/worker_panel_fullrais_2010.parquet` | 4 |
| 0.91 | 2026-04-14 | `Data/main_pipeline_duckdb/transitions/employers_2009_2010.parquet` | 17 |
| 0.85 | 2026-07-10 | `Data/CBA_RAIS_firm_level/fullrais_panel/worker_panel_fullrais_2009.parquet` | 4 |
| 0.84 | 2025-04-29 | `Data/CBA/cnes_contracts_coverage.dta` | 1 |
| 0.84 | 2025-09-17 | `Data/CBA/cnes_contracts_coverage_updated.dta` | 1 |
| 0.82 | 2025-10-15 | `Data/CBA_RAIS_firm_level/rais_firm_2015.dta` | 41 |
| 0.82 | 2025-10-15 | `Data/CBA_RAIS_firm_level/rais_firm_2014.dta` | 41 |
| 0.81 | 2025-10-15 | `Data/CBA_RAIS_firm_level/rais_firm_2016.dta` | 41 |
| 0.79 | 2025-10-15 | `Data/CBA_RAIS_firm_level/rais_firm_2013.dta` | 41 |
| 0.79 | 2026-07-16 | `Data/RAIS_aux/spells_2014.parquet` | 7 |
| 0.77 | 2026-07-16 | `Data/RAIS_aux/spells_2013.parquet` | 7 |
| 0.76 | 2025-10-15 | `Data/CBA_RAIS_firm_level/rais_firm_2012.dta` | 41 |
| 0.75 | 2026-07-16 | `Data/RAIS_aux/spells_2015.parquet` | 7 |
| 0.75 | 2026-07-16 | `Data/RAIS_aux/spells_2012.parquet` | 7 |
| 0.74 | 2025-10-15 | `Data/CBA_RAIS_firm_level/rais_firm_2011.dta` | 41 |
| 0.73 | 2026-07-16 | `Data/RAIS_aux/spells_2016.parquet` | 7 |
| 0.72 | 2026-07-16 | `Data/RAIS_aux/spells_2017.parquet` | 7 |
| 0.71 | 2026-07-16 | `Data/RAIS_aux/spells_2011.parquet` | 7 |
| 0.70 | 2025-10-15 | `Data/CBA_RAIS_firm_level/rais_firm_2010.dta` | 41 |
| 0.69 | 2026-01-14 | `Data/RAIS_aux/connectivity_2007_2011_yearly.dta` | 1 |
| 0.68 | 2026-08-11 | `Data/CBA_RAIS_firm_level/worker_year_pre_new_vs_nonnew_dec26.dta` | 3 |
| 0.66 | 2025-10-15 | `Data/CBA_RAIS_firm_level/rais_firm_2009.dta` | 41 |
| 0.66 | 2025-07-04 | `Data/RAIS_aux/connectivity_zero_2007_2011.csv` | 2 |
| 0.66 | 2025-07-04 | `Data/RAIS_aux/connectivity_one_2007_2011.csv` | 2 |
| 0.62 | 2026-07-24 | `Data/main_pipeline_duckdb/yearly_employers/yearly_employers_2010.parquet` | 9 |
| 0.61 | 2025-05-19 | `Data/RAIS_aux/connectivity_2007_2011.dta` | 79 |
| 0.61 | 2026-07-16 | `Data/RAIS_aux/spells_2010.parquet` | 7 |
| 0.61 | 2025-05-19 | `Data/RAIS_aux/connectivity_2007_2011.csv` | 79 |
| 0.60 | 2026-01-14 | `Data/RAIS_aux/connectivity_treat_2007_2011.csv` | 4 |
| 0.60 | 2026-01-14 | `Data/RAIS_aux/connectivity_control_2007_2011.csv` | 3 |
| 0.59 | 2026-03-11 | `Data/RAIS_aux/yearly_employers_2011.parquet` | 9 |
| 0.57 | 2026-07-24 | `Data/main_pipeline_duckdb/yearly_employers/yearly_employers_2009.parquet` | 9 |
| 0.57 | 2025-09-24 | `Data/CBA/cba_coverage_clean.dta` | 3 |
| 0.56 | 2026-03-11 | `Data/RAIS_aux/yearly_employers_2010.parquet` | 9 |
| 0.56 | 2026-07-16 | `Data/RAIS_aux/spells_2009.parquet` | 7 |
| 0.54 | 2026-07-16 | `Data/RAIS_aux/spells_2008.parquet` | 7 |
| 0.52 | 2026-03-11 | `Data/RAIS_aux/yearly_employers_2009.parquet` | 9 |
| 0.50 | 2026-03-11 | `Data/RAIS_aux/yearly_employers_2008.parquet` | 9 |
| 0.47 | 2026-03-11 | `Data/RAIS_aux/yearly_employers_2007.parquet` | 9 |
| 0.44 | 2025-09-24 | `Data/CBA/cba_firm_exploded.dta` | 2 |
| 0.43 | 2025-09-24 | `Data/CBA/cba_firm_exploded_mun.dta` | 1 |
| 0.39 | 2025-09-24 | `Data/CBA/collapsed_cba_firm_updated.dta` | 2 |
| 0.35 | 2025-04-23 | `Data/CBA/collapsed_cba_firm.dta` | 2 |
| 0.35 | 2026-08-11 | `Data/CBA_RAIS_firm_level/lagos_sample_sep24_pct_unionexp.dta` | 23 |
| 0.35 | 2026-08-11 | `Data/CBA_RAIS_firm_level/lagos_sample_sep24_pct.dta` | 23 |
| 0.31 | 2025-10-06 | `Data/CBA_RAIS_firm_level/lagos_sample_sep24.dta` | 26 |
| 0.31 | 2026-08-11 | `Data/CBA_RAIS_firm_level/lagos_sample_sep24_test.dta` | 3 |
| 0.30 | 2026-08-16 | `Data/CBA_RAIS_firm_level/lagos_sample_sep24_pct_unionexp_ext_df2.dta` | 20 |
| 0.25 | 2026-01-14 | `Data/RAIS_aux/connectivity_control_2007_2011_agg.dta` | 2 |
| 0.25 | 2026-01-14 | `Data/RAIS_aux/connectivity_treat_2007_2011_agg.dta` | 3 |
| 0.25 | 2026-01-14 | `Data/RAIS_aux/connectivity_zero_2007_2011_agg.dta` | 1 |
| 0.25 | 2026-01-14 | `Data/RAIS_aux/connectivity_one_2007_2011_agg.dta` | 1 |
| 0.24 | 2025-05-19 | `Data/RAIS_aux/connectivity_control_2007_2011.dta` | 3 |
| 0.24 | 2025-05-19 | `Data/RAIS_aux/connectivity_treat_2007_2011.dta` | 4 |
| 0.21 | 2026-01-14 | `Data/RAIS_aux/connectivity_2007_2011_agg.dta` | 1 |
| 0.20 | 2026-01-26 | `Data/RAIS_aux/connectivity_post_treat_agg.dta` | 1 |
| 0.19 | 2025-09-24 | `Data/RAIS_aux/rais_mode_mun_ind.dta` | 1 |
| 0.11 | 2025-09-24 | `Data/RAIS_aux/lagos_treat.dta` | 5 |
| 0.11 | 2025-09-24 | `Data/RAIS_aux/lagos_control.dta` | 5 |
| 0.11 | 2025-09-24 | `Data/RAIS_aux/lagos_sample.dta` | 32 |
| 0.11 | 2025-09-24 | `Data/RAIS_aux/bal_pan.dta` | 1 |
| 0.11 | 2025-09-24 | `Data/RAIS_aux/lagos_sample.csv` | 32 |
| 0.11 | 2025-09-24 | `Data/RAIS_aux/lagos_control.csv` | 5 |
| 0.11 | 2025-09-24 | `Data/RAIS_aux/lagos_treat.csv` | 5 |
| 0.10 | 2025-07-30 | `Data/RAIS_aux/zero_cba_treat.dta` | 2 |
| 0.10 | 2025-07-30 | `Data/RAIS_aux/one_cba_treat.dta` | 2 |
| 0.10 | 2025-05-15 | `Data/RAIS_aux/luis_sample.dta` | 1 |
| 0.10 | 2025-07-30 | `Data/RAIS_aux/zero_cba_treat.csv` | 2 |
| 0.10 | 2025-07-30 | `Data/RAIS_aux/one_cba_treat.csv` | 2 |
| 0.10 | 2025-05-15 | `Data/RAIS_aux/luis_sample.csv` | 1 |
