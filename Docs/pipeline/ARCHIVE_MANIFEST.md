# Archive manifest

**Built 2026-08-10. Nothing has been moved.** Classification of every script under `Programs/` for the archive decision described in the approved prompt. Approve or amend this before any file moves.

Total scripts: **830**

| Bucket | Count | Disposition |
|---|---|---|
| A — CHAIN | 73 | stays in `Programs/` |
| B — LIVE SIBLING | 76 | archive; still runs against chain payloads |
| C — PHASE TWO | 286 | archive; hook back in later |
| D — SUPERSEDED | 73 | archive; duplicate or dead |
| E1 — REVIEW, reachable | 29 | **undecided** — a live script names it; check before moving |
| E2 — REVIEW, orphan | 293 | **undecided** — nothing live references it; likely dead |

Bucket E is a fifth bucket, not in the approved four. Classifying every file by rule alone would be false precision: E holds scripts that sit in directories which also contain chain scripts but never call the chain themselves. `INVENTORY.md §F` warns that "no traced exhibit" is not proof of death, and a wrong archive here stays invisible until someone re-estimates. E is split by reachability: **E1** is named by some live script and needs a look; **E2** is referenced by nothing live and is the safest bulk-archive candidate.

**Bucket A grew from 60 to 73 while building this file.** Reachability analysis found twelve scripts invoked directly by chain scripts that the schema never included -- the `explode_cba_coverage_*.py` coverage exploders, `1050_corrected_turnover.py`, the six `generate_*_latex.py` table writers, `4220_table_descriptives.py`, and `notify.sh`. Archiving on the previous classification would have broken the chain in a dozen places. They still carry their original names and should be renumbered before anything moves.

## By directory

| Directory | A chain | B sibling | C phase 2 | D superseded | E1 reachable | E2 orphan |
|---|---|---|---|---|---|---|
| `cba_similarity` | 0 | 0 | 124 | 0 | 0 | 0 |
| `layer_connectivity` | 6 | 11 | 0 | 8 | 7 | 85 |
| `(root)` | 22 | 20 | 0 | 0 | 6 | 65 |
| `conn_margins` | 2 | 9 | 0 | 0 | 6 | 35 |
| `Old` | 0 | 0 | 0 | 51 | 0 | 0 |
| `Gui_coding` | 0 | 0 | 42 | 0 | 0 | 0 |
| `robustness` | 10 | 6 | 0 | 0 | 1 | 14 |
| `turnover` | 4 | 8 | 0 | 0 | 0 | 17 |
| `conn_descriptives` | 3 | 2 | 0 | 0 | 1 | 19 |
| `main_results` | 7 | 4 | 0 | 0 | 1 | 11 |
| `residuals` | 3 | 5 | 0 | 0 | 3 | 10 |
| `rand_inference` | 3 | 2 | 0 | 0 | 3 | 12 |
| `entry_exit` | 0 | 0 | 20 | 0 | 0 | 0 |
| `max_clause_row` | 0 | 0 | 17 | 0 | 0 | 0 |
| `descriptives` | 4 | 2 | 0 | 0 | 0 | 8 |
| `clause_types` | 3 | 2 | 0 | 0 | 1 | 8 |
| `honest_did` | 0 | 0 | 14 | 0 | 0 | 0 |
| `results` | 0 | 0 | 14 | 0 | 0 | 0 |
| `numb_clauses_outliers` | 0 | 0 | 13 | 0 | 0 | 0 |
| `direction_convergence` | 0 | 0 | 11 | 0 | 0 | 0 |
| `composition` | 3 | 3 | 0 | 0 | 0 | 4 |
| `cba_value` | 3 | 2 | 0 | 0 | 0 | 5 |
| `within_firm_final` | 0 | 0 | 9 | 0 | 0 | 0 |
| `main_data_pipeline` | 0 | 0 | 0 | 8 | 0 | 0 |
| `main_data_pipeline_duckdb` | 0 | 0 | 0 | 6 | 0 | 0 |
| `sample_nesting` | 0 | 0 | 5 | 0 | 0 | 0 |
| `exit` | 0 | 0 | 3 | 0 | 0 | 0 |
| `iv_late_conn_early_conn` | 0 | 0 | 3 | 0 | 0 | 0 |
| `worker_wages` | 0 | 0 | 3 | 0 | 0 | 0 |
| `Python` | 0 | 0 | 2 | 0 | 0 | 0 |
| `avg_within_firm_cdf` | 0 | 0 | 2 | 0 | 0 | 0 |
| `aipw_robust` | 0 | 0 | 2 | 0 | 0 | 0 |
| `educ_premia_fullrais` | 0 | 0 | 1 | 0 | 0 | 0 |
| `connectivity_diagram` | 0 | 0 | 1 | 0 | 0 | 0 |

## B — LIVE SIBLING — 76 files

Disposition: archive; still runs against chain payloads


**`Programs/(root)/`**

- `011c_worker_panel.py` — calls chain script 1010_rais_to_firm.do
- `05_yearly_employers_post.do` — calls chain script 1050_yearly_employers.do
- `05_yearly_employers_post_master.do` — calls chain script 0000_master.do
- `05b_yearly_employers_extended.do` — calls chain script 1050_yearly_employers.do
- `05c_aggregate_extended_connectivity.do` — calls chain script 1050_yearly_employers.do
- `062_process_municipality_centroids.do` — calls chain script 0000_master.do
- `Main_Results_pct_tfpw_07_11_extpre.do` — calls chain script 3012_pct_tfpw.do
- `Main_Results_pct_tfpw_07_11_meanlog.do` — calls chain script 0000_master.do
- `Main_Results_robustness.do` — calls chain script 1050_yearly_employers.do
- `_run_012_worker_panel.do` — calls chain script 1060_rais_worker_panel.do
- `_run_pct_tfpw_07_11.do` — calls chain script 3012_pct_tfpw.do
- `_run_pct_tfpw_07_11_cc_meanlog.do` — calls chain script 3012_pct_tfpw.do
- `_run_pct_tfpw_07_11_cluster.do` — calls chain script 3012_pct_tfpw.do
- `_run_spill_base_only.do` — calls chain script 3012_pct_tfpw.do
- `_spill_base_only.do` — calls chain script 3012_pct_tfpw.do
- `cattaneo_test.do` — calls chain script 0000_master.do

**`Programs/cba_value/`**

- `Main_Results_cba_value_year.do` — calls chain script 3042_cba_value.do
- `_run_cba_value.do` — calls chain script 3042_cba_value.do

**`Programs/clause_types/`**

- `_run_clause_types.do` — calls chain script 3032_clause_types.do
- `clause_types_log.do` — calls chain script 3032_clause_types.do

**`Programs/composition/`**

- `Main_Results_composition_log.do` — calls chain script 3092_composition.do
- `Main_Results_composition_scale.do` — calls chain script 3092_composition.do
- `_run_composition.do` — calls chain script 3092_composition.do

**`Programs/conn_descriptives/`**

- `07db_submit.sh` — calls chain script 4110_figure_bilateral_coefplot.py
- `08_merge.py` — calls chain script 4110_figure_bilateral_coefplot.py

**`Programs/conn_margins/`**

- `_run_main_pct.do` — calls chain script 3012_pct_tfpw.do
- `conn_margins.do` — calls chain script 0000_master.do
- `conn_margins_thresholds.do` — calls chain script 3012_pct_tfpw.do
- `linearity_did_fd_cba_binstest.do` — calls chain script 3012_pct_tfpw.do
- `linearity_did_fd_cba_match.do` — calls chain script 3012_pct_tfpw.do
- `linearity_did_panel_cba.do` — calls chain script 3012_pct_tfpw.do
- `linearity_did_resid_cba.do` — calls chain script 3012_pct_tfpw.do
- `linearity_polytest.do` — calls chain script 3012_pct_tfpw.do
- `spill_trim_robustness.do` — calls chain script 3012_pct_tfpw.do

**`Programs/descriptives/`**

- `_run_descriptives.do` — calls chain script 3102_sample_descriptives.do
- `firm_conn_scatter_prep.do` — calls chain script 3012_pct_tfpw.do

**`Programs/(root)/`**

- `extpre_build.do` — calls chain script 2050_build_analysis_panel.do
- `extpre_eventstudy_export.do` — calls chain script 3012_pct_tfpw.do

**`Programs/layer_connectivity/`**

- `03a_compute_n.py` — calls chain script 1050_yearly_employers.do
- `01a_disentangle_edu.do` — calls chain script 0000_master.do
- `04_build_pdf.py` — calls chain script 4090_table_within_firm.py
- `_run_within_firm_hw_v3ml.do` — calls chain script 3132_within_firm_hourly.do
- `_run_within_firm_v3ml.do` — calls chain script 3122_within_firm.do
- `07_layer_spillover.do` — calls chain script 0000_master.do
- `07b_layer_spillover.do` — calls chain script 0000_master.do
- `11_disentangling_layers.do` — calls chain script 0000_master.do
- `make_data_dictionary.py` — calls chain script 1050_yearly_employers.do
- `TEST_layers_balance.do` — calls chain script 0000_master.do
- `layer_config.py` — calls chain script 1010_rais_to_firm.do

**`Programs/main_results/`**

- `_run_currentconn_mincer_full.do` — calls chain script 3112_mincer.do
- `_run_currentconn_mincer_ten_fullrais.do` — calls chain script 3112_mincer.do
- `main_logclauses.do` — calls chain script 3012_pct_tfpw.do
- `pre_period_means.do` — calls chain script 3092_composition.do

**`Programs/(root)/`**

- `make_variable_dictionary_pdf.py` — calls chain script 1010_rais_to_firm.do
- `pipeline_main_data.do` — calls chain script 1010_rais_to_firm.do

**`Programs/rand_inference/`**

- `02_export_regression_frame.do` — calls chain script 3012_pct_tfpw.do
- `17_direct_cf_placebo.py` — calls chain script 3012_pct_tfpw.do

**`Programs/residuals/`**

- `011f_mincer_residuals.do` — calls chain script 3112_mincer.do
- `_run_main_python_resid.do` — calls chain script 3112_mincer.do
- `_run_main_stata_resid.do` — calls chain script 3112_mincer.do
- `_run_mincer.do` — calls chain script 3112_mincer.do
- `es_mincer.do` — calls chain script 3112_mincer.do

**`Programs/robustness/`**

- `Main_Results_demo_controls.do` — calls chain script 3072_union_controls.do
- `Main_Results_micro_ind.do` — calls chain script 3012_pct_tfpw.do
- `_run_micro_ind_q.do` — calls chain script 3062_micro_ind_q.do
- `_run_robustness.do` — calls chain script 3052_robustness_bins.do
- `_run_union_controls.do` — calls chain script 3072_union_controls.do
- `_run_union_controls_cc.do` — calls chain script 3072_union_controls.do

**`Programs/turnover/`**

- `Main_Results_turnover_firmscale.do` — calls chain script 0000_master.do
- `Main_Results_turnover_firmscale_ll.do` — calls chain script 0000_master.do
- `Main_Results_turnover_log.do` — calls chain script 3082_turnover.do
- `Main_Results_turnover_loglevel.do` — calls chain script 0000_master.do
- `Main_Results_turnover_scale.do` — calls chain script 3082_turnover.do
- `_run_turnover.do` — calls chain script 3082_turnover.do
- `_run_turnover_cluster.do` — calls chain script 3082_turnover.do
- `run_turnover.do` — calls chain script 3082_turnover.do

## C — PHASE TWO — 286 files

Disposition: archive; hook back in later


**`Programs/Gui_coding/`**

- `Heterogeneity_within_firm.R` — Gui_coding/ — INVENTORY §E no traced exhibit
- `Residual_construction.R` — Gui_coding/ — INVENTORY §E no traced exhibit
- `Result_6yr.R` — Gui_coding/ — INVENTORY §E no traced exhibit
- `Results.R` — Gui_coding/ — INVENTORY §E no traced exhibit
- `Results_perflow.R` — Gui_coding/ — INVENTORY §E no traced exhibit
- `Results_residual.R` — Gui_coding/ — INVENTORY §E no traced exhibit
- `run_all.sh` — Gui_coding/ — INVENTORY §E no traced exhibit
- `01a_layer_spillover.do` — Gui_coding/ — INVENTORY §E no traced exhibit
- `01b_make_table_spillover.py` — Gui_coding/ — INVENTORY §E no traced exhibit
- `02a_horse_race_edu2.do` — Gui_coding/ — INVENTORY §E no traced exhibit
- `02b_make_table_horse_race.py` — Gui_coding/ — INVENTORY §E no traced exhibit
- `03a_layer_spillover_occ4.do` — Gui_coding/ — INVENTORY §E no traced exhibit
- `03b_make_table_spillover_occ4.py` — Gui_coding/ — INVENTORY §E no traced exhibit
- `04a_horse_race_occ4.do` — Gui_coding/ — INVENTORY §E no traced exhibit
- `04b_make_table_horse_race_occ4.py` — Gui_coding/ — INVENTORY §E no traced exhibit
- `run_all.do` — Gui_coding/ — INVENTORY §E no traced exhibit
- `00_variable_audit.R` — Gui_coding/ — INVENTORY §E no traced exhibit
- `01_reliability_iv.R` — Gui_coding/ — INVENTORY §E no traced exhibit
- `01b_reliability_robust.R` — Gui_coding/ — INVENTORY §E no traced exhibit
- `01c_firm_iv.R` — Gui_coding/ — INVENTORY §E no traced exhibit
- `01d_ar_ci.R` — Gui_coding/ — INVENTORY §E no traced exhibit
- `02_incidence.R` — Gui_coding/ — INVENTORY §E no traced exhibit
- `03_partitions.R` — Gui_coding/ — INVENTORY §E no traced exhibit
- `03b_reliability_all_partitions.R` — Gui_coding/ — INVENTORY §E no traced exhibit
- `04_firm_margins.R` — Gui_coding/ — INVENTORY §E no traced exhibit
- `05_size_interaction.R` — Gui_coding/ — INVENTORY §E no traced exhibit
- `06_mundlak.R` — Gui_coding/ — INVENTORY §E no traced exhibit
- `07_diag_halves.R` — Gui_coding/ — INVENTORY §E no traced exhibit
- `07_halves_main.R` — Gui_coding/ — INVENTORY §E no traced exhibit
- `07b_make_tables.R` — Gui_coding/ — INVENTORY §E no traced exhibit
- `07c_se_diagnostic.R` — Gui_coding/ — INVENTORY §E no traced exhibit
- `ext_common.R` — Gui_coding/ — INVENTORY §E no traced exhibit
- `ext_prep.R` — Gui_coding/ — INVENTORY §E no traced exhibit
- `prep_layer.R` — Gui_coding/ — INVENTORY §E no traced exhibit
- `run_a8_identity.R` — Gui_coding/ — INVENTORY §E no traced exhibit
- `run_a8_source.R` — Gui_coding/ — INVENTORY §E no traced exhibit
- `run_a8_sum.R` — Gui_coding/ — INVENTORY §E no traced exhibit
- `run_diag.R` — Gui_coding/ — INVENTORY §E no traced exhibit
- `run_fe_vs_sample.R` — Gui_coding/ — INVENTORY §E no traced exhibit
- `run_horse.R` — Gui_coding/ — INVENTORY §E no traced exhibit
- `run_spill2.R` — Gui_coding/ — INVENTORY §E no traced exhibit
- `run_t2_sample.R` — Gui_coding/ — INVENTORY §E no traced exhibit

**`Programs/Python/`**

- `create_lagos_workers.py` — Python/ — INVENTORY §E no traced exhibit
- `new_hires_vs_inc_shares_plot.py` — Python/ — INVENTORY §E no traced exhibit

**`Programs/aipw_robust/`**

- `_run_aipw_robust.do` — aipw_robust/ — INVENTORY §E no traced exhibit
- `aipw_robust.do` — aipw_robust/ — INVENTORY §E no traced exhibit

**`Programs/avg_within_firm_cdf/`**

- `avg_within_firm_cdf.py` — avg_within_firm_cdf/ — INVENTORY §E no traced exhibit
- `avg_within_firm_cdf_levels.py` — avg_within_firm_cdf/ — INVENTORY §E no traced exhibit

**`Programs/cba_similarity/`**

- `_build_log_variants.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `_run_all_similarity_log.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `_run_cba_dotprod_decomposition.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `_run_cba_self_similarity.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `_run_cba_self_similarity_log.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `_run_cba_similarity.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `_run_cba_similarity_avg.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `_run_cba_similarity_avg_log.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `_run_cba_similarity_avg_pos_conn.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `_run_cba_similarity_corr_w.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `_run_cba_similarity_corr_w_log.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `_run_cba_similarity_decomp.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `_run_cba_similarity_decomp_avg.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `_run_cba_similarity_focal_frozen.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `_run_cba_similarity_focal_frozen_log.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `_run_cba_similarity_log.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `_run_cba_similarity_multi_ref.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `_run_cba_similarity_pretreat_ref.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `_run_cba_similarity_pretreat_ref_log.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `_run_cba_similarity_pretreat_ref_uncorr_w.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `_run_cba_similarity_pretreat_ref_uncorr_w_log.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `_run_cba_similarity_sample_check.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `_run_mechanism_test.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `_run_mechanism_test_directional.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `_run_treated_cba_self_similarity.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `_run_treated_cba_self_similarity_log.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `_run_treated_cba_similarity.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `_run_treated_cba_similarity_log.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `_run_treated_cba_similarity_pretreat_ref.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `_run_treated_cba_similarity_pretreat_ref_log.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `_run_treated_cba_similarity_pretreat_ref_uncorr_w.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `_run_treated_cba_similarity_pretreat_ref_uncorr_w_log.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `cba_dotprod_decomposition.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `cba_dotprod_decomposition_prep.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `cba_self_similarity.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `cba_self_similarity_log.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `cba_self_similarity_prep.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `cba_similarity.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `cba_similarity_avg.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `cba_similarity_avg_log.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `cba_similarity_avg_pos_conn.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `cba_similarity_avg_prep.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `cba_similarity_corr_w.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `cba_similarity_corr_w_log.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `cba_similarity_corr_w_prep.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `cba_similarity_decomp.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `cba_similarity_decomp_avg.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `cba_similarity_decomp_avg_prep.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `cba_similarity_decomp_prep.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `cba_similarity_focal_frozen.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `cba_similarity_focal_frozen_log.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `cba_similarity_focal_frozen_prep.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `cba_similarity_log.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `cba_similarity_multi_ref.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `cba_similarity_prep.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `cba_similarity_pretreat_ref.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `cba_similarity_pretreat_ref_log.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `cba_similarity_pretreat_ref_prep.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `cba_similarity_pretreat_ref_uncorr_w.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `cba_similarity_pretreat_ref_uncorr_w_log.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `cba_similarity_pretreat_ref_uncorr_w_prep.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `cba_similarity_sample_check.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `clause_count_descriptives.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_abc_decomposition_latex.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_cba_similarity_decomp_avg_latex.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_cba_similarity_decomp_latex.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_cba_similarity_multi_ref_latex.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_corr_w_ln_similarity_latex.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_corr_w_ln_similarity_latex_log.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_corr_w_similarity_latex.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_dotprod_decomposition_latex.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_focal_frozen_ln_similarity_latex.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_focal_frozen_ln_similarity_latex_log.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_focal_frozen_similarity_latex.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_ln_similarity_avg_latex.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_ln_similarity_avg_latex_log.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_ln_similarity_latex.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_ln_similarity_latex_log.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_mechanism_test_directional_latex.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_mechanism_test_latex.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_pretreat_ref_ln_similarity_latex.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_pretreat_ref_ln_similarity_latex_log.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_pretreat_ref_similarity_latex.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_pretreat_ref_uncorr_w_ln_similarity_latex.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_pretreat_ref_uncorr_w_ln_similarity_latex_log.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_pretreat_ref_uncorr_w_similarity_latex.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_sample_check_latex.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_self_ln_similarity_latex.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_self_ln_similarity_latex_log.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_self_similarity_latex.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_similarity_avg_latex.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_similarity_avg_pos_conn_latex.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_similarity_latex.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_treated_ln_similarity_latex.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_treated_ln_similarity_latex_log.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_treated_pretreat_ref_ln_similarity_latex.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_treated_pretreat_ref_ln_similarity_latex_log.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_treated_pretreat_ref_similarity_latex.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_treated_pretreat_ref_uncorr_w_ln_similarity_latex.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_treated_pretreat_ref_uncorr_w_ln_similarity_latex_log.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_treated_pretreat_ref_uncorr_w_similarity_latex.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_treated_self_ln_similarity_latex.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_treated_self_ln_similarity_latex_log.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_treated_self_similarity_latex.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `generate_treated_similarity_latex.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `mechanism_gap_prep.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `mechanism_gap_prep_untreated.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `mechanism_test.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `mechanism_test_pooled.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `mechanism_test_untreated.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `plot_dotprod_decomposition_event_study.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `plot_similarity_headline_coefplot.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `treated_cba_self_similarity.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `treated_cba_self_similarity_log.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `treated_cba_self_similarity_prep.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `treated_cba_similarity.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `treated_cba_similarity_log.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `treated_cba_similarity_prep.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `treated_cba_similarity_pretreat_ref.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `treated_cba_similarity_pretreat_ref_log.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `treated_cba_similarity_pretreat_ref_prep.py` — cba_similarity/ — INVENTORY §E no traced exhibit
- `treated_cba_similarity_pretreat_ref_uncorr_w.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `treated_cba_similarity_pretreat_ref_uncorr_w_log.do` — cba_similarity/ — INVENTORY §E no traced exhibit
- `treated_cba_similarity_pretreat_ref_uncorr_w_prep.py` — cba_similarity/ — INVENTORY §E no traced exhibit

**`Programs/connectivity_diagram/`**

- `make_connectivity_diagram.py` — connectivity_diagram/ — INVENTORY §E no traced exhibit

**`Programs/direction_convergence/`**

- `_run_direction_convergence.do` — direction_convergence/ — INVENTORY §E no traced exhibit
- `direction_convergence_currentbench_prep.py` — direction_convergence/ — INVENTORY §E no traced exhibit
- `direction_convergence_eventstudy.do` — direction_convergence/ — INVENTORY §E no traced exhibit
- `direction_convergence_geometry.py` — direction_convergence/ — INVENTORY §E no traced exhibit
- `direction_convergence_prep.py` — direction_convergence/ — INVENTORY §E no traced exhibit
- `direction_convergence_static.do` — direction_convergence/ — INVENTORY §E no traced exhibit
- `direction_convergence_treated_eventstudy.do` — direction_convergence/ — INVENTORY §E no traced exhibit
- `direction_convergence_treated_prep.py` — direction_convergence/ — INVENTORY §E no traced exhibit
- `direction_convergence_treated_static.do` — direction_convergence/ — INVENTORY §E no traced exhibit
- `generate_direction_convergence_eventstudy_plots.py` — direction_convergence/ — INVENTORY §E no traced exhibit
- `generate_direction_convergence_latex.py` — direction_convergence/ — INVENTORY §E no traced exhibit

**`Programs/educ_premia_fullrais/`**

- `01_educ_premia_fullrais.py` — educ_premia_fullrais/ — INVENTORY §E no traced exhibit

**`Programs/entry_exit/`**

- `041_merge_cba_rais_unbal.do` — entry_exit/ — INVENTORY §E no traced exhibit
- `05_employers_unbal.do` — entry_exit/ — INVENTORY §E no traced exhibit
- `_check_vars.do` — entry_exit/ — INVENTORY §E no traced exhibit
- `_peek_cba.py` — entry_exit/ — INVENTORY §E no traced exhibit
- `_run_entry_exit.do` — entry_exit/ — INVENTORY §E no traced exhibit
- `_run_pipeline_batch.do` — entry_exit/ — INVENTORY §E no traced exhibit
- `_run_prep_and_results.do` — entry_exit/ — INVENTORY §E no traced exhibit
- `build_unbal_dataset.py` — entry_exit/ — INVENTORY §E no traced exhibit
- `compare_datasets.do` — entry_exit/ — INVENTORY §E no traced exhibit
- `connectivity_treat_unbal.m` — entry_exit/ — INVENTORY §E no traced exhibit
- `generate_entry_exit_latex.py` — entry_exit/ — INVENTORY §E no traced exhibit
- `generate_lpm_latex.py` — entry_exit/ — INVENTORY §E no traced exhibit
- `lpm_entry_exit.do` — entry_exit/ — INVENTORY §E no traced exhibit
- `lpm_entry_exit_sandbox.do` — entry_exit/ — INVENTORY §E no traced exhibit
- `lpm_es_export.do` — entry_exit/ — INVENTORY §E no traced exhibit
- `merge_connectivity_unbal.py` — entry_exit/ — INVENTORY §E no traced exhibit
- `patch_add_hourly_pre4.do` — entry_exit/ — INVENTORY §E no traced exhibit
- `prep_entry_exit_data.do` — entry_exit/ — INVENTORY §E no traced exhibit
- `results_entry_exit.do` — entry_exit/ — INVENTORY §E no traced exhibit
- `validate_hourly_wage_rais_firm.do` — entry_exit/ — INVENTORY §E no traced exhibit

**`Programs/exit/`**

- `_run_exit.do` — exit/ — INVENTORY §E no traced exhibit
- `generate_exit_latex.py` — exit/ — INVENTORY §E no traced exhibit
- `results_exit.do` — exit/ — INVENTORY §E no traced exhibit

**`Programs/honest_did/`**

- `_install_honestdid.do` — honest_did/ — INVENTORY §E no traced exhibit
- `_install_pretrends.do` — honest_did/ — INVENTORY §E no traced exhibit
- `_run_finegrid.do` — honest_did/ — INVENTORY §E no traced exhibit
- `_run_honest_did_cluster.do` — honest_did/ — INVENTORY §E no traced exhibit
- `_test_extract.do` — honest_did/ — INVENTORY §E no traced exhibit
- `_test_honestdid.do` — honest_did/ — INVENTORY §E no traced exhibit
- `_test_pretrends.do` — honest_did/ — INVENTORY §E no traced exhibit
- `honest_did.do` — honest_did/ — INVENTORY §E no traced exhibit
- `honest_did_F1.py` — honest_did/ — INVENTORY §E no traced exhibit
- `honest_did_finegrid.do` — honest_did/ — INVENTORY §E no traced exhibit
- `honest_did_plot.py` — honest_did/ — INVENTORY §E no traced exhibit
- `honest_did_rm_2x2.py` — honest_did/ — INVENTORY §E no traced exhibit
- `honest_did_rm_spillover_2x2.py` — honest_did/ — INVENTORY §E no traced exhibit
- `pretrends_plot.py` — honest_did/ — INVENTORY §E no traced exhibit

**`Programs/iv_late_conn_early_conn/`**

- `Main_Results_iv_late_conn_early_conn.do` — iv_late_conn_early_conn/ — INVENTORY §E no traced exhibit
- `_run_iv_late_conn_early_conn.do` — iv_late_conn_early_conn/ — INVENTORY §E no traced exhibit
- `generate_iv_late_conn_early_conn_latex.py` — iv_late_conn_early_conn/ — INVENTORY §E no traced exhibit

**`Programs/max_clause_row/`**

- `cba_period_arms.do` — max_clause_row/ — INVENTORY §E no traced exhibit
- `cba_period_arms_deciles.do` — max_clause_row/ — INVENTORY §E no traced exhibit
- `cba_period_arms_lagos.do` — max_clause_row/ — INVENTORY §E no traced exhibit
- `cba_period_arms_vingtiles.do` — max_clause_row/ — INVENTORY §E no traced exhibit
- `cba_period_v2.do` — max_clause_row/ — INVENTORY §E no traced exhibit
- `cba_period_v3.do` — max_clause_row/ — INVENTORY §E no traced exhibit
- `duration_connectivity_check.do` — max_clause_row/ — INVENTORY §E no traced exhibit
- `exact_pretrend_pval.do` — max_clause_row/ — INVENTORY §E no traced exhibit
- `generate_cba_period_arms_deciles_latex.py` — max_clause_row/ — INVENTORY §E no traced exhibit
- `generate_cba_period_arms_lagos_latex.py` — max_clause_row/ — INVENTORY §E no traced exhibit
- `generate_cba_period_arms_latex.py` — max_clause_row/ — INVENTORY §E no traced exhibit
- `generate_cba_period_arms_vingtiles_latex.py` — max_clause_row/ — INVENTORY §E no traced exhibit
- `generate_cba_period_v2_latex.py` — max_clause_row/ — INVENTORY §E no traced exhibit
- `generate_cba_period_v3_latex.py` — max_clause_row/ — INVENTORY §E no traced exhibit
- `generate_max_clause_latex.py` — max_clause_row/ — INVENTORY §E no traced exhibit
- `max_clause_row.do` — max_clause_row/ — INVENTORY §E no traced exhibit
- `pretrend_sample_sizes.do` — max_clause_row/ — INVENTORY §E no traced exhibit

**`Programs/numb_clauses_outliers/`**

- `_run_labor_prefix_effects.do` — numb_clauses_outliers/ — INVENTORY §E no traced exhibit
- `_run_labor_top1_effects.do` — numb_clauses_outliers/ — INVENTORY §E no traced exhibit
- `_run_numb_clauses_outliers.do` — numb_clauses_outliers/ — INVENTORY §E no traced exhibit
- `_run_numb_clauses_outliers.sh` — numb_clauses_outliers/ — INVENTORY §E no traced exhibit
- `_run_numb_clauses_winsor.do` — numb_clauses_outliers/ — INVENTORY §E no traced exhibit
- `generate_labor_combined_latex.py` — numb_clauses_outliers/ — INVENTORY §E no traced exhibit
- `generate_labor_prefix_latex.py` — numb_clauses_outliers/ — INVENTORY §E no traced exhibit
- `generate_labor_top1_latex.py` — numb_clauses_outliers/ — INVENTORY §E no traced exhibit
- `generate_numb_clause_outlier_latex.py` — numb_clauses_outliers/ — INVENTORY §E no traced exhibit
- `labor_prefix_effects.do` — numb_clauses_outliers/ — INVENTORY §E no traced exhibit
- `labor_top1_effects.do` — numb_clauses_outliers/ — INVENTORY §E no traced exhibit
- `numb_clauses_outliers.do` — numb_clauses_outliers/ — INVENTORY §E no traced exhibit
- `numb_clauses_winsor.do` — numb_clauses_outliers/ — INVENTORY §E no traced exhibit

**`Programs/results/`**

- `combine_csvs_to_excel.py` — results/ — INVENTORY §E no traced exhibit
- `combine_csvs_to_excel_2.py` — results/ — INVENTORY §E no traced exhibit
- `combine_csvs_to_excel_2_aug6.py` — results/ — INVENTORY §E no traced exhibit
- `combine_csvs_to_excel_2_ctf.py` — results/ — INVENTORY §E no traced exhibit
- `combine_csvs_to_excel_2_ctf_aug6.py` — results/ — INVENTORY §E no traced exhibit
- `combine_csvs_to_excel_3.py` — results/ — INVENTORY §E no traced exhibit
- `combine_csvs_to_excel_3_aug6.py` — results/ — INVENTORY §E no traced exhibit
- `combine_csvs_to_excel_Oct25.py` — results/ — INVENTORY §E no traced exhibit
- `combine_csvs_to_excel_aug6.py` — results/ — INVENTORY §E no traced exhibit
- `combine_csvs_to_excel_p0911.py` — results/ — INVENTORY §E no traced exhibit
- `combine_csvs_to_excel_p0911_B.py` — results/ — INVENTORY §E no traced exhibit
- `combine_csvs_to_excel_p0911_B_aug6.py` — results/ — INVENTORY §E no traced exhibit
- `combine_csvs_to_excel_p0911_aug6.py` — results/ — INVENTORY §E no traced exhibit
- `make_table_from_mega.py` — results/ — INVENTORY §E no traced exhibit

**`Programs/sample_nesting/`**

- `check_sample_nesting.do` — sample_nesting/ — INVENTORY §E no traced exhibit
- `diagnose_clause_extra_firms.do` — sample_nesting/ — INVENTORY §E no traced exhibit
- `diagnose_within_period_variation.do` — sample_nesting/ — INVENTORY §E no traced exhibit
- `resid_bin_zerofill.do` — sample_nesting/ — INVENTORY §E no traced exhibit
- `resid_vs_raw_wages.do` — sample_nesting/ — INVENTORY §E no traced exhibit

**`Programs/within_firm_final/`**

- `00_config.R` — within_firm_final/ — INVENTORY §E no traced exhibit
- `01_functions.R` — within_firm_final/ — INVENTORY §E no traced exhibit
- `02_build.R` — within_firm_final/ — INVENTORY §E no traced exhibit
- `03_estimate.R` — within_firm_final/ — INVENTORY §E no traced exhibit
- `04_engine.R` — within_firm_final/ — INVENTORY §E no traced exhibit
- `verify.R` — within_firm_final/ — INVENTORY §E no traced exhibit
- `run_all.R` — within_firm_final/ — INVENTORY §E no traced exhibit
- `05b_make_tables_within_firm.py` — within_firm_final/ — INVENTORY §E no traced exhibit
- `build_pdf.py` — within_firm_final/ — INVENTORY §E no traced exhibit

**`Programs/worker_wages/`**

- `01_prep_data.py` — worker_wages/ — INVENTORY §E no traced exhibit
- `02_regressions.do` — worker_wages/ — INVENTORY §E no traced exhibit
- `_run_worker_wages.sh` — worker_wages/ — INVENTORY §E no traced exhibit

## D — SUPERSEDED — 73 files

Disposition: archive; duplicate or dead


**`Programs/Old/`**

- `012_rais_to_cba_merge_keys.do` — Old/ — archived or duplicate tree
- `031_clean_cba.do` — Old/ — archived or duplicate tree
- `032_clean_cba.do` — Old/ — archived or duplicate tree
- `033_clean_cba.do` — Old/ — archived or duplicate tree
- `03_clean_cba.do` — Old/ — archived or duplicate tree
- `041_merge_cba_rais.do` — Old/ — archived or duplicate tree
- `04_merge_cba_rais.do` — Old/ — archived or duplicate tree
- `05_yearly_employers.do` — Old/ — archived or duplicate tree
- `Collecting unique cnpjs RAIS.do` — Old/ — archived or duplicate tree
- `Homogenizing RAIS variables.do` — Old/ — archived or duplicate tree
- `Inflows_outflows_Aug4.do` — Old/ — archived or duplicate tree
- `Merging RAIS and Assoc.do` — Old/ — archived or duplicate tree
- `Merging RAIS and CBAs.do` — Old/ — archived or duplicate tree
- `Recap_Aug6.do` — Old/ — archived or duplicate tree
- `_temp_pw_n_extract.py` — Old/ — archived or duplicate tree
- `arranging cba rais.do` — Old/ — archived or duplicate tree
- `arranging rais and cba_connectivity.do` — Old/ — archived or duplicate tree
- `checking cnpj string problem.do` — Old/ — archived or duplicate tree
- `checking municipio in rais.do` — Old/ — archived or duplicate tree
- `collapsing to the firm level and appending.do` — Old/ — archived or duplicate tree
- `connectivity.m` — Old/ — archived or duplicate tree
- `connectivity1.m` — Old/ — archived or duplicate tree
- `connectivity2.m` — Old/ — archived or duplicate tree
- `connectivity_full.m` — Old/ — archived or duplicate tree
- `connectivity_lcontrol.m` — Old/ — archived or duplicate tree
- `connectivity_lsample.m` — Old/ — archived or duplicate tree
- `connectivity_ltreat.m` — Old/ — archived or duplicate tree
- `connectivity_restricted_lsample.m` — Old/ — archived or duplicate tree
- `connectivity_treat_lagos.m` — Old/ — archived or duplicate tree
- `defining treatment status.do` — Old/ — archived or duplicate tree
- `descriptive statistics.do` — Old/ — archived or duplicate tree
- `flow.m` — Old/ — archived or duplicate tree
- `investigate_missing_connectivity.do` — Old/ — archived or duplicate tree
- `investigate_na_avgflowtreatpf.do` — Old/ — archived or duplicate tree
- `investigate_sing_mu.do` — Old/ — archived or duplicate tree
- `luis_antonio_block_did.do` — Old/ — archived or duplicate tree
- `non-linear-specs_Jul31.do` — Old/ — archived or duplicate tree
- `optimize_data_types.do` — Old/ — archived or duplicate tree
- `rais_sample.do` — Old/ — archived or duplicate tree
- `results.R` — Old/ — archived or duplicate tree
- `results.do` — Old/ — archived or duplicate tree
- `results_1.R` — Old/ — archived or duplicate tree
- `results_spillovers_pw.do` — Old/ — archived or duplicate tree
- `results_spillovers_rough.do` — Old/ — archived or duplicate tree
- `selecting_2011_workers.do` — Old/ — archived or duplicate tree
- `selecting_fsize_predictors.do` — Old/ — archived or duplicate tree
- `selecting_lagos_sample_firms.do` — Old/ — archived or duplicate tree
- `singleton_fix_comparison.R` — Old/ — archived or duplicate tree
- `test2.py` — Old/ — archived or duplicate tree
- `test_cba_estab_merge.do` — Old/ — archived or duplicate tree
- `test_stata.do` — Old/ — archived or duplicate tree

**`Programs/layer_connectivity/`**

- `01_within_firm_estimates.do` — obsolete within-firm estimator (mean-of-log arm)
- `01_within_firm_estimates_hw.do` — obsolete within-firm estimator (mean-of-log arm)
- `01b_within_firm_estimates.do` — obsolete within-firm estimator (mean-of-log arm)
- `01b_within_firm_estimates_hw.do` — obsolete within-firm estimator (mean-of-log arm)
- `_run_within_firm.do` — obsolete within-firm estimator (mean-of-log arm)
- `_run_within_firm_hw.do` — obsolete within-firm estimator (mean-of-log arm)
- `_run_within_firm_hw_v2.do` — obsolete within-firm estimator (mean-of-log arm)
- `_run_within_firm_v2.do` — obsolete within-firm estimator (mean-of-log arm)

**`Programs/main_data_pipeline/`**

- `00_run_main_data_pipeline.do` — main_data_pipeline/ — archived or duplicate tree
- `01_preflight_inputs.do` — main_data_pipeline/ — archived or duplicate tree
- `10_011_rais_to_firm.do` — main_data_pipeline/ — archived or duplicate tree
- `20_02_clean_emp_assoc.do` — main_data_pipeline/ — archived or duplicate tree
- `30_031_clean_cba.do` — main_data_pipeline/ — archived or duplicate tree
- `40_041_merge_cba_rais.do` — main_data_pipeline/ — archived or duplicate tree
- `50_05_yearly_employers.do` — main_data_pipeline/ — archived or duplicate tree
- `90_smoke_test_analysis_dataset.do` — main_data_pipeline/ — archived or duplicate tree

**`Programs/main_data_pipeline_duckdb/`**

- `00_config.py` — main_data_pipeline_duckdb/ — archived or duplicate tree
- `10_ingest_rais_to_parquet.py` — main_data_pipeline_duckdb/ — archived or duplicate tree
- `20_select_yearly_employers_duckdb.py` — main_data_pipeline_duckdb/ — archived or duplicate tree
- `30_build_transitions_duckdb.py` — main_data_pipeline_duckdb/ — archived or duplicate tree
- `90_compare_employer_selection.py` — main_data_pipeline_duckdb/ — archived or duplicate tree
- `run_phase1_2009_2010.sh` — main_data_pipeline_duckdb/ — archived or duplicate tree

## E1 — REVIEW, reachable — 29 files

Disposition: **undecided** — a live script names it; check before moving


**`Programs/(root)/`**

- `13_pctiles_specs.do` — referenced by 3020_build_currentconn_overlay_panel.do
- `bilateral_connectivity_post.m` — referenced by 05_yearly_employers_post_master.do

**`Programs/clause_types/`**

- `generate_clause_count_log_latex.py` — referenced by clause_types_log.do

**`Programs/conn_descriptives/`**

- `07db_bilateral_pretreatment_multivariate.py` — referenced by 07db_submit.sh

**`Programs/conn_margins/`**

- `generate_conn_margins_latex.py` — referenced by conn_margins.do
- `generate_thresholds_latex.py` — referenced by conn_margins_thresholds.do
- `linearity_binstest.do` — referenced by linearity_polytest.do
- `linearity_did.do` — referenced by linearity_polytest.do
- `linearity_did_fd.do` — referenced by linearity_did_fd_cba_binstest.do, linearity_polytest.do
- `spill_trim_robustness_table.py` — referenced by spill_trim_robustness.do

**`Programs/(root)/`**

- `connectivity_control_lagos_post.m` — referenced by 05_yearly_employers_post_master.do
- `connectivity_full_lagos_post.m` — referenced by 05_yearly_employers_post_master.do
- `connectivity_treat_lagos_post.m` — referenced by 05_yearly_employers_post_master.do

**`Programs/layer_connectivity/`**

- `01b_remap_edu2.py` — referenced by layer_config.py
- `01e_remap_occ2.py` — referenced by layer_config.py
- `01f_remap_occ2c.py` — referenced by layer_config.py
- `06_prep_demog_outcomes.py` — referenced by make_data_dictionary.py
- `06_prep_layer_outcomes.py` — referenced by make_data_dictionary.py
- `000_clean_rais.do` — referenced by layer_config.py
- `010_collapse_firm.do` — referenced by layer_config.py

**`Programs/main_results/`**

- `main_results.do` — referenced by pre_period_means.do

**`Programs/rand_inference/`**

- `04_permutation_engine.py` — referenced by 17_direct_cf_placebo.py
- `07_placebo_diag.py` — referenced by 17_direct_cf_placebo.py
- `18_direct_cf_placebo_report.py` — referenced by 17_direct_cf_placebo.py

**`Programs/residuals/`**

- `011f_mincer_export.py` — referenced by 011f_mincer_residuals.do
- `es_mincer_overlay_plot.py` — referenced by es_mincer.do
- `es_mincer_plot.py` — referenced by es_mincer.do

**`Programs/robustness/`**

- `generate_demo_controls_latex.py` — referenced by Main_Results_demo_controls.do

**`Programs/(root)/`**

- `union_treat_exp.do` — referenced by pipeline_main_data.do

## E2 — REVIEW, orphan — 293 files

Disposition: **undecided** — nothing live references it; likely dead


**`Programs/(root)/`**

- `011_rais_to_firm_optimized.do` — (root)/ — no live script references it
- `011_rais_to_firm_parallel.do` — (root)/ — no live script references it
- `011b_compile_data_dictionary.py` — (root)/ — no live script references it
- `011d_worker_panel_bins.py` — (root)/ — no live script references it
- `011e_worker_panel_bins2.py` — (root)/ — no live script references it
- `01_rais_to_firm.do` — (root)/ — no live script references it
- `05_fix_employers_2015_2016.do` — (root)/ — no live script references it
- `061_export_sample_estabs.do` — (root)/ — no live script references it
- `06_spillover_sample_char.do` — (root)/ — no live script references it
- `071_spec_tests_year.do` — (root)/ — no live script references it
- `07_post_connectivity_analysis.do` — (root)/ — no live script references it
- `07_specification_tests.do` — (root)/ — no live script references it
- `07a_process_post_connectivity.do` — (root)/ — no live script references it
- `08_specification_tests_2.do` — (root)/ — no live script references it
- `09_investigate_negativespill.do` — (root)/ — no live script references it
- `09_specification_tests_3.do` — (root)/ — no live script references it
- `11_worker_level_direct_remdezr.do` — (root)/ — no live script references it
- `14_table_02.do` — (root)/ — no live script references it
- `15_table_03.do` — (root)/ — no live script references it
- `16_remdezr_spill_newinc_worker.do` — (root)/ — no live script references it
- `17_table_dir_effects.do` — (root)/ — no live script references it
- `18_table_02_draft.do` — (root)/ — no live script references it
- `19_story_spill_dist.do` — (root)/ — no live script references it
- `20_all_specs_dofile.do` — (root)/ — no live script references it
- `21_story_dist.do` — (root)/ — no live script references it
- `22_post_treat_IV.do` — (root)/ — no live script references it
- `22_sample_descriptives.do` — (root)/ — no live script references it
- `Correct_retention.do` — (root)/ — no live script references it
- `Main_Results_IV.do` — (root)/ — no live script references it
- `Simulating_bil_pairs.py` — (root)/ — no live script references it
- `Simulation_billateral_Conn.do` — (root)/ — no live script references it
- `UnionSpillovers_FinalResults_gtfpe_gout_alldir_0conn.do` — (root)/ — no live script references it
- `_check_vars.do` — (root)/ — no live script references it
- `_diag2.do` — (root)/ — no live script references it
- `_diag3.do` — (root)/ — no live script references it
- `_diag_spill.do` — (root)/ — no live script references it
- `bilateral_connectivity.m` — (root)/ — no live script references it
- `bilateral_connectivity_extended.m` — (root)/ — no live script references it
- `binscatter_geo_log_proximity.do` — (root)/ — no live script references it

**`Programs/cba_value/`**

- `01_compute_cba_value.py` — cba_value/ — no live script references it
- `01b_compute_cba_value_subgroup.py` — cba_value/ — no live script references it
- `_run_cba_value_year.do` — cba_value/ — no live script references it
- `_run_lagos_spec.do` — cba_value/ — no live script references it
- `lagos_spec_direct.do` — cba_value/ — no live script references it

**`Programs/clause_types/`**

- `_run_clause_types.sh` — clause_types/ — no live script references it
- `_run_clause_types_log.do` — clause_types/ — no live script references it
- `_run_subgroup_analysis.do` — clause_types/ — no live script references it
- `generate_clause_count_latex.py` — clause_types/ — no live script references it
- `generate_subgroup_coefplot.py` — clause_types/ — no live script references it
- `generate_subgroup_latex.py` — clause_types/ — no live script references it
- `subgroup_analysis.do` — clause_types/ — no live script references it
- `subgroup_prep.py` — clause_types/ — no live script references it

**`Programs/(root)/`**

- `cleanup_intermediate_files.do` — (root)/ — no live script references it

**`Programs/composition/`**

- `_run_composition_log.do` — composition/ — no live script references it
- `_run_composition_scale.do` — composition/ — no live script references it
- `generate_composition_log_latex.py` — composition/ — no live script references it
- `generate_composition_scale_latex.py` — composition/ — no live script references it

**`Programs/conn_descriptives/`**

- `063_extract_cep_from_rais.do` — conn_descriptives/ — no live script references it
- `064_process_cep_centroids.py` — conn_descriptives/ — no live script references it
- `065_bilateral_cep_turnover_prep.py` — conn_descriptives/ — no live script references it
- `06_bilateral_coefplot_6yr.py` — conn_descriptives/ — no live script references it
- `06_bilateral_data_prep.py` — conn_descriptives/ — no live script references it
- `06a_bilateral_regression_univariate.py` — conn_descriptives/ — no live script references it
- `06b_bilateral_regression_multivariate.py` — conn_descriptives/ — no live script references it
- `07d_bilateral_pretreatment_coefplot.py` — conn_descriptives/ — no live script references it
- `07d_bilateral_pretreatment_pyfixest.py` — conn_descriptives/ — no live script references it
- `07da_merge.py` — conn_descriptives/ — no live script references it
- `07da_submit.sh` — conn_descriptives/ — no live script references it
- `07da_worker.py` — conn_descriptives/ — no live script references it
- `08_bilateral_decomp.py` — conn_descriptives/ — no live script references it
- `08_bilateral_worker.py` — conn_descriptives/ — no live script references it
- `08_paircell_fe_test.do` — conn_descriptives/ — no live script references it
- `08_submit.sh` — conn_descriptives/ — no live script references it
- `08b_statistics_script.py` — conn_descriptives/ — no live script references it
- `figure_A2.py` — conn_descriptives/ — no live script references it
- `variance_decomposition_within_across_cells.py` — conn_descriptives/ — no live script references it

**`Programs/conn_margins/`**

- `_run_conn_margins_cluster.do` — conn_margins/ — no live script references it
- `_run_conn_margins_quartiles_vs_zero.do` — conn_margins/ — no live script references it
- `_run_conn_margins_thresholds.do` — conn_margins/ — no live script references it
- `_run_conn_margins_thresholds_vs_zero.do` — conn_margins/ — no live script references it
- `conn_margins_quartiles_vs_zero.do` — conn_margins/ — no live script references it
- `conn_margins_scatter.do` — conn_margins/ — no live script references it
- `conn_margins_scatter.py` — conn_margins/ — no live script references it
- `conn_margins_scatter_controls.do` — conn_margins/ — no live script references it
- `conn_margins_scatter_did.py` — conn_margins/ — no live script references it
- `conn_margins_scatter_het.py` — conn_margins/ — no live script references it
- `conn_margins_scatter_het2.py` — conn_margins/ — no live script references it
- `conn_margins_scatter_raw.py` — conn_margins/ — no live script references it
- `conn_margins_scatter_raw2.py` — conn_margins/ — no live script references it
- `conn_margins_thresholds_vs_zero.do` — conn_margins/ — no live script references it
- `conn_margins_trim.do` — conn_margins/ — no live script references it
- `conn_margins_trim_table.py` — conn_margins/ — no live script references it
- `generate_linearity_binstest_latex.py` — conn_margins/ — no live script references it
- `generate_linearity_did_fd_latex.py` — conn_margins/ — no live script references it
- `generate_linearity_did_poly_latex.py` — conn_margins/ — no live script references it
- `generate_quartiles_vs_zero_latex.py` — conn_margins/ — no live script references it
- `generate_thresholds_vs_zero_latex.py` — conn_margins/ — no live script references it
- `linearity_binstest.py` — conn_margins/ — no live script references it
- `linearity_did_eventstudy_plot.py` — conn_margins/ — no live script references it
- `linearity_did_fd_cba.do` — conn_margins/ — no live script references it
- `linearity_did_fd_figure.py` — conn_margins/ — no live script references it
- `linearity_did_poly.do` — conn_margins/ — no live script references it
- `linearity_fig1_raw.py` — conn_margins/ — no live script references it
- `linearity_fig2_resid.py` — conn_margins/ — no live script references it
- `linearity_fig3_binsreg.py` — conn_margins/ — no live script references it
- `linearity_fig3_binsreg_corrected.py` — conn_margins/ — no live script references it
- `linearity_fig3_lowess.py` — conn_margins/ — no live script references it
- `linearity_fig3_spline.py` — conn_margins/ — no live script references it
- `linearity_fig4_bincoef.py` — conn_margins/ — no live script references it
- `linearity_fig5_poly.py` — conn_margins/ — no live script references it
- `linearity_fig_emp_binsreg.py` — conn_margins/ — no live script references it

**`Programs/(root)/`**

- `connectivity_treat_lagos_extended.m` — (root)/ — no live script references it
- `create_worker_panel_chunked.do` — (root)/ — no live script references it
- `create_worker_panel_efficient.do` — (root)/ — no live script references it

**`Programs/descriptives/`**

- `balance_binscatter.py` — descriptives/ — no live script references it
- `balance_table_task2.do` — descriptives/ — no live script references it
- `firm_conn_binscatter.py` — descriptives/ — no live script references it
- `firm_conn_residualize.do` — descriptives/ — no live script references it
- `firm_conn_residualize_plots.py` — descriptives/ — no live script references it
- `firm_conn_scatter.py` — descriptives/ — no live script references it
- `generate_balance_table_task2_latex.py` — descriptives/ — no live script references it
- `generate_distribution_figure_latex.py` — descriptives/ — no live script references it

**`Programs/(root)/`**

- `diag_totalflows_absorption.py` — (root)/ — no live script references it
- `explode_cba_coverage_2011_025326.py` — (root)/ — no live script references it
- `explode_cba_sectoral.py` — (root)/ — no live script references it
- `fix_missing_transition_matrices.sh` — (root)/ — no live script references it
- `generate_extpre_latex.py` — (root)/ — no live script references it
- `generate_latex.py` — (root)/ — no live script references it
- `generate_ntile_robustness_latex.py` — (root)/ — no live script references it
- `include_employment2008.do` — (root)/ — no live script references it
- `labor_ladder_lagos.do` — (root)/ — no live script references it

**`Programs/layer_connectivity/`**

- `00_cache_rais.py` — layer_connectivity/ — no live script references it
- `01a_build_transitions.py` — layer_connectivity/ — no live script references it
- `01c_totalflows_layer.py` — layer_connectivity/ — no live script references it
- `01d_build_demog_transitions.py` — layer_connectivity/ — no live script references it
- `02a_aggregate.py` — layer_connectivity/ — no live script references it
- `02b_aggregate_demog.py` — layer_connectivity/ — no live script references it
- `03b_compute_n_demog.py` — layer_connectivity/ — no live script references it
- `04a_validate.py` — layer_connectivity/ — no live script references it
- `04b_decompose.py` — layer_connectivity/ — no live script references it
- `05_compare_layers.py` — layer_connectivity/ — no live script references it
- `06a_prep_layer_outcomes.py` — layer_connectivity/ — no live script references it
- `06b_prep_demog_outcomes.py` — layer_connectivity/ — no live script references it
- `06c_prep_occ2_outcomes.py` — layer_connectivity/ — no live script references it
- `06d_prep_occ2c_outcomes.py` — layer_connectivity/ — no live script references it
- `06z_prep_outcomes_unified.py` — layer_connectivity/ — no live script references it
- `01_compute.py` — layer_connectivity/ — no live script references it
- `02_make_table.py` — layer_connectivity/ — no live script references it
- `01a_layer_spillover.do` — layer_connectivity/ — no live script references it
- `01b_layer_spillover_occ4.do` — layer_connectivity/ — no live script references it
- `01c_layer_spillover_occ4_test.do` — layer_connectivity/ — no live script references it
- `01d_layer_spillover_occ2.do` — layer_connectivity/ — no live script references it
- `01e_layer_spillover_occ2c.do` — layer_connectivity/ — no live script references it
- `02a_make_table_spillover.py` — layer_connectivity/ — no live script references it
- `02b_make_table_spillover_occ4.py` — layer_connectivity/ — no live script references it
- `02c_make_table_spillover_occ4_test.py` — layer_connectivity/ — no live script references it
- `02e_make_table_spillover_occ2c.py` — layer_connectivity/ — no live script references it
- `01b_disentangle_occ4.do` — layer_connectivity/ — no live script references it
- `02a_make_table_edu.py` — layer_connectivity/ — no live script references it
- `02b_make_table_occ4.py` — layer_connectivity/ — no live script references it
- `01a_horse_race_edu2.do` — layer_connectivity/ — no live script references it
- `01b_horse_race_occ4.do` — layer_connectivity/ — no live script references it
- `01c_horse_race_occ2.do` — layer_connectivity/ — no live script references it
- `01d_horse_race_occ2c.do` — layer_connectivity/ — no live script references it
- `02a_make_table_edu2.py` — layer_connectivity/ — no live script references it
- `02b_make_table_occ4.py` — layer_connectivity/ — no live script references it
- `02f_make_table_horse_race_occ2c.py` — layer_connectivity/ — no live script references it
- `01_cross_layer.do` — layer_connectivity/ — no live script references it
- `02_make_table.py` — layer_connectivity/ — no live script references it
- `01_univariate_per_layer_occ4.do` — layer_connectivity/ — no live script references it
- `01b_firmcheck_per_layer_occ4.do` — layer_connectivity/ — no live script references it
- `02_make_table.py` — layer_connectivity/ — no live script references it
- `02_make_tables.py` — layer_connectivity/ — no live script references it
- `03_verify_v2.py` — layer_connectivity/ — no live script references it
- `_run_tenure.do` — layer_connectivity/ — no live script references it
- `_run_tenure_hw.do` — layer_connectivity/ — no live script references it
- `07_layer_spillover_portable.do` — layer_connectivity/ — no live script references it
- `07_layer_spillover_size.do` — layer_connectivity/ — no live script references it
- `07_layer_spillover_size100.do` — layer_connectivity/ — no live script references it
- `07_layer_spillover_size_full.do` — layer_connectivity/ — no live script references it
- `07c_layer_spillover.do` — layer_connectivity/ — no live script references it
- `07d_layer_spillover.do` — layer_connectivity/ — no live script references it
- `08_make_table_layer_specs.py` — layer_connectivity/ — no live script references it
- `08b_make_table_layer_specs_abvmed.py` — layer_connectivity/ — no live script references it
- `08c_make_table_layer_specs_abvp25.py` — layer_connectivity/ — no live script references it
- `09_make_table_size_full.py` — layer_connectivity/ — no live script references it
- `09_make_table_size_specs.py` — layer_connectivity/ — no live script references it
- `09b_make_table_size100_specs.py` — layer_connectivity/ — no live script references it
- `10_cross_layer_prep.py` — layer_connectivity/ — no live script references it
- `12_make_table_disentangle.py` — layer_connectivity/ — no live script references it
- `12c_make_table_disentangle_xfirm.py` — layer_connectivity/ — no live script references it
- `13b_horse_race_edu2_xfirm.do` — layer_connectivity/ — no live script references it
- `13c_horse_race_edu2_lbal.do` — layer_connectivity/ — no live script references it
- `13d_horse_race_edu2_lbal_geo.do` — layer_connectivity/ — no live script references it
- `13e_horse_race_binary_lbal.do` — layer_connectivity/ — no live script references it
- `13e_horse_race_xfirm_abvmed.do` — layer_connectivity/ — no live script references it
- `13f_horse_race_binary.do` — layer_connectivity/ — no live script references it
- `13f_horse_race_xfirm_abvp25.do` — layer_connectivity/ — no live script references it
- `13g_horse_race_xfirm_size_large.do` — layer_connectivity/ — no live script references it
- `14b_make_table_horse_race_xfirm.py` — layer_connectivity/ — no live script references it
- `14c_make_table_horse_race_lbal.py` — layer_connectivity/ — no live script references it
- `14d_make_table_horse_race_lbal_geo.py` — layer_connectivity/ — no live script references it
- `14e_make_table_horse_race_binary_lbal.py` — layer_connectivity/ — no live script references it
- `14f_make_table_horse_race_binary.py` — layer_connectivity/ — no live script references it
- `14g_make_table_horse_race_xfirm_abvmed.py` — layer_connectivity/ — no live script references it
- `14h_make_table_horse_race_xfirm_abvp25.py` — layer_connectivity/ — no live script references it
- `14h_make_table_horse_race_xfirm_size_large.py` — layer_connectivity/ — no live script references it
- `14i_make_table_horse_race_xfirm_abvp25_combined.py` — layer_connectivity/ — no live script references it
- `_firmrestr_standalone.do` — layer_connectivity/ — no live script references it
- `_run_01_to_03.sh` — layer_connectivity/ — no live script references it
- `_run_demog_layers.sh` — layer_connectivity/ — no live script references it
- `_run_layer_connectivity.sh` — layer_connectivity/ — no live script references it
- `_run_layer_spillover.sh` — layer_connectivity/ — no live script references it
- `_run_tenure_standalone.sh` — layer_connectivity/ — no live script references it
- `_wait_and_table.sh` — layer_connectivity/ — no live script references it
- `_wait_and_table_run.sh` — layer_connectivity/ — no live script references it

**`Programs/main_results/`**

- `_run_contamination_test_cluster.do` — main_results/ — no live script references it
- `_run_logclauses_local.do` — main_results/ — no live script references it
- `_run_main_results_cluster.do` — main_results/ — no live script references it
- `_run_panelC_numb_clauses_cluster.do` — main_results/ — no live script references it
- `_run_pre_period_means.do` — main_results/ — no live script references it
- `direct_contamination_test.do` — main_results/ — no live script references it
- `direct_contamination_test_table.py` — main_results/ — no live script references it
- `generate_logclauses_latex.py` — main_results/ — no live script references it
- `main_results_es_plot.py` — main_results/ — no live script references it
- `main_results_tables.py` — main_results/ — no live script references it
- `panelC_and_spill_numb_clauses.do` — main_results/ — no live script references it

**`Programs/(root)/`**

- `merge_lagos_worker_all.do` — (root)/ — no live script references it
- `paper_push.sh` — (root)/ — no live script references it
- `permutation_test_mu.do` — (root)/ — no live script references it
- `plot_tfpe_distribution.py` — (root)/ — no live script references it
- `process_municipality_centroids.py` — (root)/ — no live script references it
- `pull_paper.sh` — (root)/ — no live script references it
- `rais_sample.do` — (root)/ — no live script references it
- `rais_worker_sample.do` — (root)/ — no live script references it

**`Programs/rand_inference/`**

- `01_build_flow_weights.py` — rand_inference/ — no live script references it
- `03_validate_baseline.py` — rand_inference/ — no live script references it
- `05_plot.py` — rand_inference/ — no live script references it
- `06_fill_section.py` — rand_inference/ — no live script references it
- `08_placebo_diag_report.py` — rand_inference/ — no live script references it
- `09_expected_exposure.py` — rand_inference/ — no live script references it
- `10_horserace.do` — rand_inference/ — no live script references it
- `11_balance_recentered_report.py` — rand_inference/ — no live script references it
- `12_balance_permute.py` — rand_inference/ — no live script references it
- `14_control_connectivity.py` — rand_inference/ — no live script references it
- `15_survivor_table.py` — rand_inference/ — no live script references it
- `17b_direct_cf_composition.py` — rand_inference/ — no live script references it

**`Programs/residuals/`**

- `011f_mincer_residuals.py` — residuals/ — no live script references it
- `011f_mincer_residuals_pyfixest.py` — residuals/ — no live script references it
- `011g_mincer_residuals_variants.py` — residuals/ — no live script references it
- `_run_es_mincer.do` — residuals/ — no live script references it
- `_run_resid_explore.do` — residuals/ — no live script references it
- `compare_r_vs_python_stata.py` — residuals/ — no live script references it
- `02_residualize_fullrais.py` — residuals/ — no live script references it
- `03_safeguards.py` — residuals/ — no live script references it
- `resid_explore.do` — residuals/ — no live script references it
- `resid_explore_table.py` — residuals/ — no live script references it

**`Programs/(root)/`**

- `results.do` — (root)/ — no live script references it
- `results_clauses.do` — (root)/ — no live script references it
- `results_spillovers_preliminary.do` — (root)/ — no live script references it

**`Programs/robustness/`**

- `Main_Results_alt_conn.do` — robustness/ — no live script references it
- `Main_Results_demo_direct.do` — robustness/ — no live script references it
- `Main_Results_demo_linear.do` — robustness/ — no live script references it
- `_run_alt_conn.do` — robustness/ — no live script references it
- `_run_demo_controls.do` — robustness/ — no live script references it
- `_run_demo_controls_cc.do` — robustness/ — no live script references it
- `_run_demo_direct.do` — robustness/ — no live script references it
- `_run_demo_linear.do` — robustness/ — no live script references it
- `_run_micro_ind.do` — robustness/ — no live script references it
- `generate_alt_conn_latex.py` — robustness/ — no live script references it
- `generate_demo_combined_latex.py` — robustness/ — no live script references it
- `generate_demo_direct_latex.py` — robustness/ — no live script references it
- `generate_demo_linear_latex.py` — robustness/ — no live script references it
- `generate_micro_ind_latex.py` — robustness/ — no live script references it

**`Programs/(root)/`**

- `run_post_analysis.sh` — (root)/ — no live script references it
- `run_post_connectivity.sh` — (root)/ — no live script references it

**`Programs/turnover/`**

- `011b_totalflows_panel.py` — turnover/ — no live script references it
- `011b_turnover_diagnostics.py` — turnover/ — no live script references it
- `011b_yearly_totalflows_panel.py` — turnover/ — no live script references it
- `_run_turnover_firmscale.do` — turnover/ — no live script references it
- `_run_turnover_firmscale_ll.do` — turnover/ — no live script references it
- `_run_turnover_log.do` — turnover/ — no live script references it
- `_run_turnover_loglevel.do` — turnover/ — no live script references it
- `_run_turnover_scale.do` — turnover/ — no live script references it
- `_test_flows_pw_noexy.do` — turnover/ — no live script references it
- `_test_flows_pw_with_exy.do` — turnover/ — no live script references it
- `_test_flows_spill.do` — turnover/ — no live script references it
- `_test_ll_flows_with_exy.do` — turnover/ — no live script references it
- `_test_ll_totalflows_variation.py` — turnover/ — no live script references it
- `_test_totalflows_absorb.do` — turnover/ — no live script references it
- `generate_turnover_firmscale_latex.py` — turnover/ — no live script references it
- `generate_turnover_firmscale_ll_latex.py` — turnover/ — no live script references it
- `generate_turnover_loglevel_latex.py` — turnover/ — no live script references it



---

## Restored to the chain, 2026-08-16

Three sub-pipelines were archived by `cd49461` ("Programs/: code only") because they
are not on the paper-exhibit critical path. That left tier-C estimators in the chain
whose **inputs** were not, so the package could not be replicated from raw data.
They are back under `Programs/sample_construction/`:

| now at | was at | builds | consumed by |
|---|---|---|---|
| `sample_construction/layers/` (20 files) | `archive/Programs/layer_connectivity/00_pipeline/` + `layer_config.py` | `Data/layer_connectivity/` | `analysis/layer_connectivity/07_within_firm/3121`, `3131` |
| `sample_construction/mincer_residuals/` (6 files) | `archive/Programs/residuals/fullrais/` and `archive/Programs/residuals/011f_*` | `mincer_residuals_firm_year*.csv` | `analysis/residuals/3112_mincer.do` |
| `sample_construction/rand_inference/` (17 files) | `archive/Programs/rand_inference/` | permutation inputs | `analysis/rand_inference/4130`, `4151`, `4152` |

Each carries a `README.md` giving run order, inputs, outputs and the consuming
estimator.

**Still open after the restore:** nothing in the repository builds
`Data/CBA_RAIS_firm_level/fullrais_panel/worker_panel_fullrais_{year}.parquet`,
which `02_residualize_fullrais.py` reads to produce the residuals the published
mincer results use. The parquets exist on disk; their producer is absent from both
`Programs/` and `archive/`. This is the same class of gap tier B had before its
reconstruction.

Note: three scripts left behind in `archive/Programs/layer_connectivity/`
(`01_descriptives/01_compute.py`, `99_archive/06_prep_layer_outcomes.py`,
`99_archive/06_prep_demog_outcomes.py`) import `layer_config`, which has moved. They
are archived exploration, not chain code, but they will not run as-is.

## Fixtures

`Programs/conn_descriptives/figure_A2/` moved to `Docs/fixtures/figure_A2/`. Its four
coefficient CSVs and the PDF are **committed inputs with no producer** in the repo,
so they belong with the other reference fixtures rather than in `Programs/` or in
`Tables/` — the latter would have untracked them, since `.gitignore` carries
`Tables/**/*.csv` and these are the only copy.

That move also fixed `4110_figure_bilateral_coefplot.py`, which had been reading the
same four filenames from `Data/RAIS_aux/`, where they do not exist. It could not have
run.
