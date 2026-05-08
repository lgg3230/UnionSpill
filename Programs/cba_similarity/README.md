# cba_similarity

Pipeline for the CBA-content-similarity exercises that test whether untreated
firms with stronger pre-treatment worker-flow ties to treated firms end up with
more similar CBA content post-reform — a content-diffusion mechanism for
spillovers. Includes a mirrored treated-side test (`mechanism_test`) that asks
whether treated firms specifically expand in clause types where their connected
untreated partners had more clauses pre-treatment.

The four similarity exercises share:

- Sample: `lagos_sample_avg==1`, untreated, balanced panel.
- `cba_period` structure (1=earliest pre, 2=second pre, 3-6=2013-2016).
- Outcomes: `cosine`, `bray_curtis`, `total_variation`, `ruzicka`, plus their
  log transforms (zeros dropped).
- Connectivity: `totaltreat_pw_norm` = `totaltreat_pw_n` divided by the
  spillover-sample 90th percentile in 2009.
- Fixed effects: `identificad`, `industry1#cba_period`,
  `mode_base_month#cba_period`, `microregion#cba_period`, with optional
  `mode_union#cba_period`. Pre-bins for `outcome_pre4`, `l_firm_emp_pre4`,
  `totalflows_pw_pre_07_114` interacted with `cba_period`.
- SE clustered on `identificad`.

## Exercises

| Wrapper | Reference vector each untreated firm is compared against | Variation |
|---|---|---|
| `_run_cba_similarity.do` | Flow-weighted average of *connected treated* firms (per untreated × cba_period) | Continuous connectivity, levels and logs |
| `_run_cba_similarity_avg.do` | Simple unweighted average of *all treated* firms (per cba_period) — every untreated firm gets a reference | Continuous connectivity, levels and logs, ± `mode_union#cba_period` |
| `_run_cba_similarity_avg_pos_conn.do` | Same simple-avg reference | Replaces continuous connectivity with a binary "any positive flow to treated" dummy |
| `_run_cba_similarity_sample_check.do` | Both references | Restricts the avg-treated regression to the bilateral sample to disentangle "union FE matters" from "bilateral sample selection drives it" |
| `_run_treated_cba_similarity.do` | **Reciprocal**: each *treated* firm vs. flow-weighted average of *connected untreated* firms | Continuous connectivity, levels and logs |

### Mirror exercise (treated-side)

`_run_mechanism_test.do` runs the content-diffusion test from the **treated** side. For each treated firm `i` and each clause type `c`, it builds:

- `gap_ic     = max(0, conn-weighted avg cl_c of untreated partners − own pre-treatment cl_c)` — connected partners had more
- `surplus_ic = max(0, own − conn-weighted avg)` — own had more
- `raw_gap_ic = gap − surplus = (partner_avg − own)` — signed mismatch

then estimates `cl_count_ict = β (X_ic × post_t) + α_ic + α_t + ε` on the treated balanced panel reshaped long over clause types. `α_ic` is firm × clause-type FE (absorbs the time-invariant level of `X_ic`), `α_t` varies by FE structure. Connectivity weights come from the same pre-treatment `bilateral_connectivity_2007_2011.csv` as the similarity exercises.

The do-file runs **24 regressions** (4 RHS specs × 3 FE structures × 2 samples):

| RHS spec | Description |
|---|---|
| `gap_post` alone | β > 0 if treated firms expand where partners had more |
| `surplus_post` alone | falsification: β ≈ 0 under pure diffusion |
| `raw_gap_post` alone | signed slope (single coefficient) |
| `gap_post + surplus_post` jointly | recovers both slopes; symmetry test β_gap = −β_surplus |

| FE structure | What it absorbs |
|---|---|
| `firm_clause + year` | firm × clause level + common time trends |
| `firm_clause + clause × year` | + clause-specific secular trends |
| `firm_clause + mode_union × year` | + union-specific time trends |

| Sample | Definition |
|---|---|
| `main` | `cba_period ∈ {1..6}`, `post = 1{cba_period ≥ 3}` |
| `placebo` | `cba_period ∈ {1, 2}`, `placebo_post = 1{cba_period == 2}` (pretrend test) |

## Files

### Wrappers (set globals, call the main do-file)
- `_run_cba_similarity.do`
- `_run_cba_similarity_avg.do`
- `_run_cba_similarity_avg_pos_conn.do`
- `_run_cba_similarity_sample_check.do`
- `_run_treated_cba_similarity.do` — reciprocal: treated firms compared to connected untreated.
- `_run_mechanism_test.do` — runs `mechanism_gap_prep.py` then `mechanism_test.do`.

### Main estimation
- `cba_similarity.do` — flow-weighted reference, runs `cba_similarity_prep.py` then regressions.
- `cba_similarity_avg.do` — simple-average reference, runs `cba_similarity_avg_prep.py` then regressions.
- `cba_similarity_avg_pos_conn.do` — pos_conn dummy variant on simple-avg reference.
- `cba_similarity_sample_check.do` — bilateral-sample restricted variant on simple-avg reference.
- `mechanism_test.do` — treated-firm-side gap regression with surplus falsification.

### Reference-vector prep (Python, called from Stata via `shell`)
- `cba_similarity_prep.py` — flow-weighted reference using `bilateral_connectivity_2007_2011.csv` and `cba_clauses_by_period.dta`. Writes `Data/RAIS_aux/cba_similarity_panel.dta`.
- `cba_similarity_avg_prep.py` — simple-average reference. Writes `Data/RAIS_aux/cba_similarity_avg_panel.dta`.
- `mechanism_gap_prep.py` — for each treated firm × clause type, computes `gap` and `surplus` against the conn-weighted average of connected untreated partners. Writes `Data/CBA_RAIS_firm_level/mechanism_gaps.dta` and `mechanism_clause_map.csv`.

### LaTeX generators (called from each main do-file at the end)
- `generate_similarity_latex.py`            → `cba_similarity_table.tex`
- `generate_ln_similarity_latex.py`         → `ln_cba_similarity_table.tex`
- `generate_similarity_avg_latex.py`        → `cba_similarity_avg_table.tex`
- `generate_ln_similarity_avg_latex.py`     → `ln_cba_similarity_avg_table.tex`
- `generate_similarity_avg_pos_conn_latex.py` → `cba_similarity_avg_pos_conn_table.tex`
- `generate_sample_check_latex.py`          → `cba_similarity_sample_check_table.tex`
- `generate_mechanism_test_latex.py`        → `mechanism_test_table.tex` (two-panel, 24 specs; reads master CSV + parses symmetry p-values from latest log)

### Documentation
- `cba_similarity_measures.md` — formal definitions and references for the four similarity measures.
- `mechanism_test_explained.md` — informal walkthrough of the mechanism test (gap/surplus/raw/joint, placebo).
- `Tables/cba_similarity/mechanism_test_methodology.tex` — formal methodology section, ready to `\input{}` in the paper.

## Outputs

```
Tables/cba_similarity/
  results_spill_cba_similarity_tfpw_07_11.csv
  results_spill_ln_cba_similarity_tfpw_07_11.csv
  results_spill_cba_similarity_avg_tfpw_07_11.csv
  results_spill_ln_cba_similarity_avg_tfpw_07_11.csv
  results_spill_cba_similarity_avg_pos_conn.csv
  results_sample_check_cba_similarity.csv
  cba_similarity_table.tex
  ln_cba_similarity_table.tex
  cba_similarity_avg_table.tex
  ln_cba_similarity_avg_table.tex
  cba_similarity_avg_pos_conn_table.tex
  cba_similarity_sample_check_table.tex
  similarity_measures_description.tex
  mechanism_test_results_all.csv         (master: 30 rows, all 24 specs)
  mechanism_test_gap.csv                 (legacy: gap, year FE)
  mechanism_test_gap_clausexyear.csv     (legacy: gap, clause × year FE)
  mechanism_test_surplus.csv             (legacy: surplus, year FE)
  mechanism_test_surplus_clausexyear.csv (legacy: surplus, clause × year FE)

Logs/cba_similarity/
  cba_similarity_<date>_<time>.log  (etc.)
```

## Running

From the cluster:

```bash
module load stata/17
stata-mp -b do Programs/cba_similarity/_run_cba_similarity.do
stata-mp -b do Programs/cba_similarity/_run_cba_similarity_avg.do
stata-mp -b do Programs/cba_similarity/_run_cba_similarity_avg_pos_conn.do
stata-mp -b do Programs/cba_similarity/_run_cba_similarity_sample_check.do
stata-mp -b do Programs/cba_similarity/_run_mechanism_test.do
```

The four similarity do-files write a clause snapshot to `Data/RAIS_aux/cba_clauses_by_period.dta`, then `shell` out to the Python prep script, then load the resulting similarity panel and run the spillover regressions. `_run_mechanism_test.do` runs `mechanism_gap_prep.py` first to build `Data/CBA_RAIS_firm_level/mechanism_gaps.dta`, then `mechanism_test.do` reshapes the treated panel long over clause types and runs the gap and surplus regressions.
