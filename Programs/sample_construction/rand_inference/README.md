# Randomization inference — dataset construction and engine

Restored from `archive/` on 2026-08-16. `Programs/analysis/rand_inference/` held only
the exhibits (`4130_figure_binscatter.py`, `4151`/`4152_recentered_eventstudy.do`)
while the engine that produces what they plot lived outside the chain.

Run in numeric order (2090 -> 2106). `2090`-`2091` build the inputs, `2092`
validates against the headline estimate, `2093` is the permutation engine, and
`2094`-`2106` are diagnostics and reporting (including the direct-counterfactual
placebo, `2104`-`2106`).

The design permutes the *identity* of the treated set and re-estimates the
spillover; connectivity is exactly linear in the destination set. The reshuffle is
inside-sample CEM, cardinality 13,202.

## Size and wage cells (Referee 3)

Referee 3 asks to reshuffle also within size and wage bins. `run_ri_bins.sh` (SLURM)
runs the chain; set `REBUILD_FRAME=1` to rerun `2091` first.

- `2107_export_bin_keys.do` — pre-treatment bins per firm (`firm_bins_pre.csv`): log
  mean employment and mean log hourly wage, 2009–2011, cut at 4/10/20 groups on 2009
  balanced-panel firms, as the main-specification quartiles and `3052`. Asserts that
  the quartiles equal `l_firm_emp_pre4` / `lr_remdezr_h_w_pre4`.
- `2108_expected_exposure_bins.py` — counterfactual connectivity for `ind_month` and
  `ind_month_{size,wage}{4,10,20}` (`expected_exposure_bins.dta`, cell counts in
  `expected_exposure_bins_meta.json`). Stops if W does not reproduce the frame's
  connectivity; reports whether `ind_month` equals `2098`'s `expected_exposure.dta`.
- `2093_permutation_engine.py --coarseness ind_month_size4` (etc.) — RI p-values in
  the same cells; `2109_perm_bins_table.py` writes `Tables/rand_inference/perm_bins.tex`.
- `Programs/analysis/rand_inference/4153_recentered_bins.do` — `4152` event studies
  for each scheme (`Graphs/rand_inference/bins/`) and `recentered_bins.{csv,tex}` (`4154`).
