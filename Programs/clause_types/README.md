# clause_types

Pipeline for direct and spillover effects on clause-count outcomes.

## Current design

- Direct-effects panels: the same A/B/C samples used in `Main_Results_pct_tfpw_07_11.do`.
- Spillover sample: untreated establishments in the Lagos balanced-panel sample.
- Outcomes: `numb_clauses`, `wage_clauses`, `emp_clauses`, `other_clauses`.
- Specification: same clause-count design as `Programs/Main_Results_pct_tfpw_07_11.do`, using `cba_period`, `post_treat_cba`, `pre_treat_cba`, and `totalflows_pw_pre_07_114`.
- Grouped counts generated in the pipeline:
  - `wage_clauses`: sum of all `cl_*` variables with `x = 1` in `cl_xywww_www`
  - `other_clauses`: sum of all `cl_*` variables with `x ∈ {2,5,6,7,8,9}`
  - `emp_clauses`: sum of all `cl_*` variables with `x ∈ {3,4}`

## Files

- `_run_clause_types.sh`: local runner for the full pipeline.
- `_run_clause_types.do`: path wrapper for Stata.
- `clause_types.do`: estimation script for the four clause-count outcomes.
- `generate_clause_count_latex.py`: builds the direct and spillover LaTeX tables.

## How to extend

1. Modify the grouped clause-count definitions in `clause_types.do` if you want different clause partitions.
2. Adjust table text or formatting in `generate_clause_count_latex.py`.
3. If one count category looks interesting, build a follow-up event-study around that outcome.
