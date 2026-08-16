# clause_types

Pipeline for direct and spillover effects on clause-count outcomes.

## Current design

- Direct-effects panels: the same A/B/C samples used in `4012_pct_tfpw.do`.
- Spillover sample: untreated establishments in the Lagos balanced-panel sample.
- Count outcomes: `numb_clauses`, `wage_clauses`, `emp_clauses`, `other_clauses`.
- Clause-type share outcomes: `wage_clause_prop`, `emp_clause_prop`, `other_clause_prop`, defined as each type's count divided by `numb_clauses`.
- Specification: same clause-count design as `Programs/4012_pct_tfpw.do`, using `cba_period`, `post_treat_cba`, `pre_treat_cba`, and `totalflows_pw_pre_07_114`.
- Grouped counts generated in the pipeline:
  - `wage_clauses`: sum of all `cl_*` variables with `x = 1` in `cl_xywww_www`
  - `other_clauses`: sum of all `cl_*` variables with `x ∈ {2,5,6,7,8,9}`
  - `emp_clauses`: sum of all `cl_*` variables with `x ∈ {3,4}`

## Files

- `_run_clause_types.sh`: local runner for the full pipeline.
- `_run_clause_types.do`: path wrapper for Stata.
- `4032_clause_types.do`: estimation script for the clause-count and clause-share outcomes.
- `generate_clause_count_latex.py`: builds the direct and spillover LaTeX tables for counts and shares.
- `numb_clause_spill_pretrend_diagnostics.csv`: sensitivity checks for the `numb_clauses` spillover pre-trend coefficient under connectivity, clause-count, and pre-period-change trimming.
- `numb_clause_spill_pretrend_top_connectivity.csv`, `numb_clause_spill_pretrend_top_delta.csv`, `numb_clause_spill_pretrend_top_influence_candidates.csv`: firm-level inspection lists for the `numb_clauses` spillover pre-trend.

## How to extend

1. Modify the grouped clause-count definitions in `4032_clause_types.do` if you want different clause partitions.
2. Adjust table text or formatting in `generate_clause_count_latex.py`.
3. If one count category looks interesting, build a follow-up event-study around that outcome.

## See also

- `Programs/cba_similarity/`: separate pipeline that compares pre- vs. post-reform CBA content vectors (cosine, Bray-Curtis, total variation, Jaccard) between untreated firms and a connected/average treated reference. Mirrors the panel spec in `4032_clause_types.do`.
