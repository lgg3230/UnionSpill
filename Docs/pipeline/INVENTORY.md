# Programs Inventory — exhibit → producer map

**Built 2026-08-02. Nothing was moved, renamed, or deleted to produce this file.**

Purpose: record which script produces each exhibit in the two live documents, and
how confident that mapping is. This is the prerequisite for any future archiving
decision — not the decision itself.

## Live documents

| Document | Path | Floats |
|---|---|---|
| Paper | `UnionSpill-paper/Draft.tex` | 13 tables, 6 figures |
| Replication | `UnionSpill-paper/Replication/Replication_Wages vs Hourly.tex` | 19 unique table fragments, 22 figures |

Two further replication trees exist and are **not** covered here:
`quality_reports/replication/hourly_variant/` and `.../hourly_variant_currentconn/`.
The latter holds the `frag/` fragments the live replication doc inlines, so it is
partly covered by transitivity; `hourly_variant/` is untraced.

## Confidence grades

| Grade | Meaning |
|---|---|
| **HIGH** | Producer named by an explicit marker, an exact write-target string, or a byte-identical file hash. |
| **MEDIUM** | Producer inferred from naming plus matching content; a sibling script could also have produced it. |
| **LOW** | Plausible producer only. Do not act on this row. |

Method: figures matched by MD5 against every PDF in the repo, then by embedded
plot text and page geometry where no hash matched. Tables matched by inlining
markers in the replication doc, and by 6-number coefficient signatures for the
paper. Upstream Stata located by grepping exact `file open` / `export delimited`
write targets, not by filename resemblance.

---

## A. Paper tables — `UnionSpill-paper/Draft.tex`

Draft.tex has no `\input` for tables; every table is pasted LaTeX. The map below
is therefore reconstructed from coefficient signatures, not from a build step.

| Label | Matching output | Generator | Upstream estimator | Conf. |
|---|---|---|---|---|
| `tab:direct_connectivity_robust` | `Tables/main_results/t_direct.tex` | `main_results/5010_table_direct.py` | `4012_pct_tfpw.do` + `conn_margins/4022_direct_sample_coef_test.do` | HIGH |
| `tab:spill_main_4tf_out` | `Tables/main_results/t_spill.tex` | `main_results/5020_table_spill.py` | `4012_pct_tfpw.do` | HIGH |
| `tab:spill_clause_decomp` | `Tables/clause_types/t_clause.tex` | `clause_types/5040_table_clause.py` | `clause_types/4032_clause_types.do` + `cba_value/4042_cba_value.do` | HIGH |
| `tab:rob_logwages` | `frag/t_rob_hw.tex` | `robustness/5060_table_rob_logwages.py` | `robustness/4062_micro_ind_q.do` | HIGH |
| `tab:spill_union_4tfpe_4out` | `Tables/robustness/t_union_hw.tex` | `robustness/5050_table_union.py` | `robustness/4072_union_controls.do` | HIGH |
| `tab:composition` | `Tables/composition/t_composition.tex` | `main_results/5030_table_twopanel.py` | `composition/4092_composition.do` | HIGH |
| `tab:layer_desc_full` | `Tables/layer_connectivity/07_within_firm/t_layerdesc{,_hw}.tex` | `layer_connectivity/07_within_firm/5090_table_within_firm.py` | see §D2 | HIGH gen / MED source |
| `tab:turnover` | `frag/t_turnover.tex` | `main_results/5030_table_twopanel.py` | `turnover/4082_turnover.do` | MED — see §D1 |
| `tab:resid_raw_base` | `Tables/residuals/t_resid_hw_currentconn_age_fullrais_rb.tex` | `residuals/5070_table_resid.py` | `residuals/4112_mincer.do` with `$results_suffix = _currentconn_age_fullrais_rb` | MED |
| `tab:group_specs` | `t_groupspecs*.tex` — 4 variants match equally | `layer_connectivity/07_within_firm/5090_table_within_firm.py` | see §D2 | MED |
| `tab:horse_race` | no fragment matched; only the assembled doc | `layer_connectivity/07_within_firm/5090_table_within_firm.py` | see §D2 | MED |
| `tab:descriptive_stats` | `Tables/descriptives/table_descriptives_pretreat.tex` **or** `..._2011.tex` | `descriptives/5220_table_descriptives.py` | `descriptives/4102_sample_descriptives.do` | MED — which suffix is published is unresolved |

**`tab:rob_logwages` and `tab:spill_union_4tfpe_4out` display the _hw (hourly)
variant.** The other paper tables carry both wage columns. Anything that treats
"hourly = appendix only" is wrong.

## B. Replication-doc tables

The replication doc carries `% BEGIN inlined <stem>.tex` markers, and
`layer_connectivity/07_within_firm/5100_inline_into_replication.py` holds the
authoritative stem → source-directory map. **All HIGH by construction.**

| Fragment stem | Source dir | Generator |
|---|---|---|
| `t_direct`, `t_spill` | `Tables/main_results/` | `main_results/generate_{direct,spill}_replication_table.py` |
| `t_clause` | `Tables/clause_types/` | `clause_types/5040_table_clause.py` |
| `t_union`, `t_union_hw` | `Tables/robustness/` | `robustness/5050_table_union.py` |
| `t_composition` | `Tables/composition/` | `main_results/5030_table_twopanel.py` |
| `t_rob`, `t_rob_hw` | `quality_reports/replication/hourly_variant_currentconn/frag/` | `robustness/5060_table_rob_logwages.py` |
| `t_layerdesc{,_hw}`, `t_groupspecs{,_hw}`, `t_horserace{,_hw}` | `Tables/layer_connectivity/07_within_firm/` | `layer_connectivity/07_within_firm/5090_table_within_firm.py` |
| `t_resid`, `t_resid_hw` | written into the doc directly | `residuals/5070_table_resid.py` |
| `t_pairwise_appendix` | `.../frag/` | `conn_descriptives/5080_table_pairwise_appendix.py` |
| `t_turnover` | **not in the map** | see §D1 |
| `t_desc` | **producer not found** | see §D3 |

## C. Figures

`UnionSpill-paper/Replication/Figures/` is populated by hand-copy with renaming;
no script writes into it. Draft.tex references the same directory.

Hash-exact (byte-identical source found in repo) — **HIGH**:

| Figure | Source | Producer |
|---|---|---|
| `bilateral_coefplot.pdf` | `Graphs/connectivity/coefplot_bilateral_combined.pdf` | `conn_descriptives/5110_figure_bilateral_coefplot.py` |
| `distro_region.pdf` | `Graphs/descriptives/distro_region.pdf` | `descriptives/5120_figure_distributions.py` |
| `distro_industry.pdf` | `Graphs/descriptives/distro_broad_industry.pdf` | `descriptives/5120_figure_distributions.py` |
| `distro_month.pdf` | `Graphs/descriptives/distro_mode_base_month.pdf` | `descriptives/5120_figure_distributions.py` |
| `m_dir_es.pdf` | `Graphs/pct_tfpw_cc/es_lr_remdezr_w_directA__1_Aug_2026.pdf` | `4011_pct_tfpw.do` → `4012_pct_tfpw.do` |
| `m_spill_es.pdf` | `Graphs/pct_tfpw_cc/es_lr_remdezr_w_spill__1_Aug_2026.pdf` | same |
| `h_dir_es.pdf` | `Graphs/pct_tfpw_cc/es_lr_remdezr_h_w_directA__1_Aug_2026.pdf` | same |
| `h_spill_es.pdf` | `Graphs/pct_tfpw_cc/es_lr_remdezr_h_w_spill__1_Aug_2026.pdf` | same |

No hash match — matched on plot text and geometry — **MEDIUM**, and see §D4:

| Figure | Nearest repo file | Producer |
|---|---|---|
| `m_honest_direct.pdf` | `Graphs/honest_did/honest_did_rm_direct_lr_remdezr_w.pdf` | `honest_did/honest_did_rm_2x2.py` |
| `m_honest_spill.pdf` | `..._rm_spillover_lr_remdezr_w.pdf` | same |
| `h_honest_direct.pdf` | `..._rm_direct_lr_remdezr_h_w.pdf` | same |
| `h_honest_spill.pdf` | `..._rm_spillover_lr_remdezr_h_w.pdf` | same |
| `m_recentered_spill.pdf` | `Graphs/rand_inference/es_spill_lr_remdezr_w.pdf` | `rand_inference/5152_recentered_eventstudy.do` |
| `m_recentered_cf.pdf` | `Graphs/rand_inference/es_counterfactual_lr_remdezr_w.pdf` | same |
| `h_recentered_spill.pdf`, `h_recentered_cf.pdf` | none | `5152_recentered_eventstudy.do` hardcodes `lr_remdezr_w`; the hourly pair cannot be reproduced by the committed script as written |
| `binscatter_{wage,hwage,emp,clauses}.pdf` | `Graphs/rand_inference/binscatter_*_raw.pdf` | `rand_inference/5130_figure_binscatter.py` — same axis label, different figsize |
| `conn_hist.pdf` | `Graphs/conn_descriptives/hist_connectivity.pdf` | `conn_descriptives/5140_figure_conn_hist.py` — different axis label and page size; may be a different vintage or a different script |

---

## D. Hazards found while building this map

**D1 — `t_turnover` is deliberately excluded from the inline map.**
`5100_inline_into_replication.py:54` says re-running the turnover generator does not
reproduce the published coefficients, so inlining it would silently change
published numbers. `tab:turnover` in the paper is therefore **not currently
reproducible from `Programs/`**. This is the single most important open item here.

**D2 — within-firm v1/v2 write-target collision, confirmed.**
`01_within_firm_estimates.do` and `01b_within_firm_estimates.do` both write
`a6_group.csv`, `a6_partition.csv`, `a7.csv`, `a8.csv` when `$table_suffix` is
empty, and `_run_within_firm_v2.do` sets it empty. Same for the `_hw` pair.
Whichever ran last owns the CSVs. Published exhibits are believed to be v2 (`01b`),
but the artifacts do not record which produced them. Affects
`tab:layer_desc_full`, `tab:group_specs`, `tab:horse_race`.

**D3 — `t_desc` has no located generator.** It is inlined twice in the replication
doc and is absent from `SOURCES` in `5100_inline_into_replication.py`. Closest
candidate is `descriptives/5220_table_descriptives.py`, which writes
`ftable_descriptives_{suffix}.tex` — no file of that name exists in `Tables/`.

**D4 — the replication figures are a different vintage from `Graphs/`.**
The four honest-DiD figures in the paper are dated 2026-07-27; the corresponding
files in `Graphs/honest_did/` are dated 2026-07-05 and differ numerically
(direct-effect breakdown M = 1.76 published vs 1.77 on disk; hourly 1.40 vs 1.41).
Same pattern for the recentered event studies (0.0050 vs 0.0051). The published
figures came from runs whose output was never written back to `Graphs/`.

**D5 — turnover variants do *not* collide** (checked, contrary to first
impression): `Main_Results_turnover{,_scale,_log,_loglevel,_firmscale,_firmscale_ll}.do`
each write a distinctly suffixed CSV.

---

## E. Directory roll-up

"Traced" = the directory contains at least one script established above as
producing a live exhibit. It does **not** mean every script in it is live.

| Directory | Scripts | Status |
|---|---|---|
| `main_results/` | 20 | traced |
| `layer_connectivity/` | 111 | traced (via `07_within_firm/`) |
| `robustness/` | 31 | traced |
| `clause_types/` | 14 | traced |
| `composition/` | 10 | traced |
| `residuals/` | 21 | traced |
| `turnover/` | 31 | traced, but see D1 |
| `descriptives/` | 14 | traced |
| `conn_descriptives/` | 25 | traced |
| `rand_inference/` | 19 | traced (figures) |
| `honest_did/` | 14 | traced (figures) |
| `cba_value/` | 10 | traced (feeds `t_clause`) |
| `conn_margins/` | 52 | traced (`4022_direct_sample_coef_test.do` only) |
| *(Programs root)* | 111 | traced (`4012_pct_tfpw.do`, `4011_pct_tfpw.do`) |
| `cba_similarity/` | 124 | **no traced exhibit** |
| `Gui_coding/` | 42 | **no traced exhibit** |
| `max_clause_row/` | 17 | **no traced exhibit** |
| `entry_exit/` | 20 | **no traced exhibit** |
| `numb_clauses_outliers/` | 13 | **no traced exhibit** |
| `direction_convergence/` | 11 | **no traced exhibit** |
| `results/` | 14 | **no traced exhibit** |
| `within_firm_final/` | 9 | **no traced exhibit** — duplicates `07_within_firm/` generators |
| `main_data_pipeline{,_duckdb}/` | 14 | no exhibit — data build, keep regardless |
| `sample_nesting/`, `exit/`, `iv_late_conn_early_conn/`, `aipw_robust/`, `avg_within_firm_cdf/`, `worker_wages/`, `educ_premia_fullrais/`, `Python/`, `connectivity_diagram/` | 22 | **no traced exhibit** |
| `Old/` | 51 | already archived |

## F. What this inventory does not establish

- **"No traced exhibit" ≠ dead.** These directories were not investigated for
  robustness arms that a referee may demand, for scripts feeding *other* documents
  (slides, memos, the two untraced replication trees), or for build dependencies.
- **No reachability analysis was run.** Data-build stages (`011_*`, `05_*`, the
  MATLAB connectivity scripts) produce no exhibit but every live script depends on
  their output. `0000_master.do` flags are all `0` in the steady state; that is not
  evidence of death.
- **Cross-script dependencies are untraced.** Stata `do`/`include`, `shell` calls
  into MATLAB and Python, and hardcoded absolute paths were not enumerated. Moving
  any file may break a caller silently.
- **MEDIUM rows are not safe to act on.** They are where a wrong archive decision
  would be invisible until re-estimation.



## G. Barebones list of scripts:

### Estimation

Programs/4011_pct_tfpw.do                      -> Programs/4012_pct_tfpw.do
Programs/conn_margins/4021_direct_sample_coef_test.do-> Programs/conn_margins/4022_direct_sample_coef_test.do
Programs/clause_types/4031_clause_types.do           -> Programs/clause_types/4032_clause_types.do
Programs/cba_value/4041_cba_value.do                 -> Programs/cba_value/4042_cba_value.do
Programs/robustness/4051_robustness_bins.do               -> Programs/robustness/4052_robustness_bins.do
Programs/robustness/4061_micro_ind_q.do              -> Programs/robustness/4062_micro_ind_q.do
Programs/robustness/4071_union_controls.do        -> Programs/robustness/4072_union_controls.do
Programs/turnover/4081_turnover.do                   -> Programs/turnover/4082_turnover.do
Programs/composition/4091_composition.do             -> Programs/composition/4092_composition.do
Programs/descriptives/4101_sample_descriptives.do    -> Programs/descriptives/4102_sample_descriptives.do
Programs/main_results/4111_mincer.do -> Programs/residuals/4112_mincer.do
Programs/layer_connectivity/07_within_firm/4121_within_firm.do    -> 4122_within_firm.do
Programs/layer_connectivity/07_within_firm/4131_within_firm_hourly.do -> 4132_within_firm_hourly.do

### Table Generators

Programs/main_results/5010_table_direct.py      -> t_direct
Programs/main_results/5020_table_spill.py       -> t_spill
Programs/main_results/5030_table_twopanel.py   -> t_turnover, t_composition
Programs/clause_types/5040_table_clause.py      -> t_clause
Programs/robustness/5050_table_union.py         -> t_union, t_union_hw
Programs/robustness/5060_table_rob_logwages.py               -> t_rob, t_rob_hw
Programs/residuals/5070_table_resid.py         -> t_resid, t_resid_hw
Programs/conn_descriptives/5080_table_pairwise_appendix.py  -> t_pairwise_appendix
Programs/layer_connectivity/07_within_firm/5090_table_within_firm.py -> t_layerdesc/groupspecs/horserace {,_hw}
Programs/layer_connectivity/07_within_firm/5100_inline_into_replication.py  (inlines into the doc)


2. Deletion — confirm before I touch anything
Do not delete yet. Your premise is inverted: the obsolete scripts are in git; the canonical ones are not.


4122_within_firm.do        ** UNTRACKED **   <- canonical
4132_within_firm_hourly.do     ** UNTRACKED **   <- canonical
4121_within_firm.do              ** UNTRACKED **   <- canonical
4131_within_firm_hourly.do           ** UNTRACKED **   <- canonical
_run_within_firm_v3ml.do            ** UNTRACKED **
_run_within_firm_hw_v3ml.do         ** UNTRACKED **
01_within_firm_estimates{,_hw}.do   TRACKED           <- obsolete
01b_within_firm_estimates{,_hw}.do  TRACKED           <- obsolete
_run_within_firm{,_hw}.do           TRACKED           <- obsolete
_run_within_firm{,_hw}_v2.do        TRACKED           <- obsolete
Commit the v3 files first. Until then the paper's canonical estimator exists only in the working tree.

Proposed deletion set (8 files) — mean-of-log, cannot reproduce the published tables:


01_within_firm_estimates.do        01_within_firm_estimates_hw.do
01b_within_firm_estimates.do       01b_within_firm_estimates_hw.do
_run_within_firm.do                _run_within_firm_hw.do
_run_within_firm_v2.do             _run_within_firm_hw_v2.do
Blocker: _run_tenure.do and _run_tenure_hw.do both call 01_within_firm_estimates{,_hw}.do. Deleting 01 breaks them. 01c covers all three partitions including ten2, so tenure looks superseded — but that's your call. Options: delete the tenure wrappers too, retarget them to 01c, or keep 01 alone.

Also flagging: _run_within_firm{,_hw}_v3ml.do are the mean-of-log arm of 01c. They didn't generate anything wrongly — they're a legitimate robustness variant of the canonical script. I'd keep them unless you want the size-control question closed permanently.

Separate fix worth doing: v3 writes _hlogic-suffixed files, but 5090_table_within_firm.py reads unsuffixed names, so publishing currently depends on a manual copy that no script records. That copy is what misled me. Giving v3 an empty table_suffix would remove the trap entirely.
