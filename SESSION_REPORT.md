# Session Report — UnionSpill

## 2026-07-31 21:50 — CBA-period sample structure: nesting diagnosis and max-clause-row robustness

**Operations:**
- `Programs/sample_nesting/check_sample_nesting.do` (via Codex rescue) — 4×4 estimation-sample
  set comparison for Table 3 columns
- `Programs/sample_nesting/diagnose_clause_extra_firms.do` — H1 (partial wage missingness) vs
  H2 (singleton cascade) for the 58 extra establishments
- `Programs/sample_nesting/diagnose_within_period_variation.do` — within-cell variation in
  `numb_clauses` for multi-row firm × `cba_period` cells
- `Programs/max_clause_row/max_clause_row.do` — baseline and filtered arms in one Stata process
- `Programs/max_clause_row/pretrend_sample_sizes.do` — placebo-only N and exact t p-values
- `Programs/max_clause_row/exact_pretrend_pval.do` — threshold check on two borderline p-values
- `Programs/max_clause_row/generate_max_clause_latex.py` — CSV → LaTeX → PDF
- Outputs in `Tables/sample_nesting/` and `Tables/max_clause_row/` (gitignored)

**Decisions:**
- Consolidated the three source scripts into one do-file rather than copying each — verified
  their prep, `cba_period` construction, and `base_fe_cba` are identical
- Filter applied AFTER control construction — the p90 normalization reads `year == 2009` rows and
  `_pre4` bins read `cba_period` 1–2 rows, so filtering earlier would confound the row
  restriction with a control redefinition
- Both arms in one Stata process — avoids `reghdfe` session-state drift
- Switched to the currentconn overlay panel after the baseline gate caught a coefficient mismatch
- Kept the legacy-panel run as `max_clause_comparison_legacypanel.csv` (filter behaves identically)

**Results:**
- Table 3 samples are cleanly nested: wages (4,084) ⊆ employment (4,088) ⊆ clause count (4,142).
  0 establishments in wages-not-clauses; 58 in clauses-not-wages
- 54 of those 58 are removed by `reghdfe`'s singleton cascade; 53 have all 8 wage-years complete.
  Driver is `i.year` (861 singletons dropped) vs `i.cba_period` (576)
- 1,914 of 17,742 firm × `cba_period` cells hold >1 row; 1,252 have a constant clause count and
  962 an identical `avg_file_date` — the same agreement counted twice
- Max-clause-row restriction: **zero sign flips, zero significance changes** across direct effects
  (A and C), clause-count spillover, six composition outcomes, and CBA value. Direct effects fall
  ~5–8% and stay p<0.01; spillovers stay insignificant; SEs rise ~4%
- Baseline gate reproduces published Table 3 exactly: 0.0227 (0.1175), 19,693 obs, 4,142 estabs

**Commits:**
- `0ec5c23` Commit all uncommitted analysis scripts — swept in both new pipelines (not made by
  this session; `Tables/` outputs remain gitignored)

**Status:**
- Done: nesting diagnosis, duplicate-row quantification, max-clause-row robustness table (PDF at
  `Tables/max_clause_row/max_clause_standalone.pdf`)
- Pending: (1) within-cell **mean** collapse arm as a companion to the max rule — proposed, not
  run; (2) the `[H]` fragment needs a landscape page in the paper (overflows letter portrait);
  (3) the replication `.tex` note for the composition table says "year fixed effects" but
  `3032_clause_types.do:221` uses `i.cba_period`; (4) Table 3's note attributes the clause column's
  establishment count to CBA-filing coverage, which predicts the wrong direction

## 2026-10-05 15:05 — Repo cleanup; TWFE binstest linearity test; 3012 rerun on current data

**Operations:**
- Committed + pushed sample-gap / recovered-sample investigations and Docs/pipeline untracking; then
  gitignored `Logs/full_rerun_2026-09-06/`, `Submission_AER_ Aug26/`, `Docs/reference_papers/`
- Created `archive/Programs/conn_margins/linearity_did_twfe.do` (untracked): Cattaneo binstest on the
  TWFE spillover equation with native `absorb()` (full 3012 FE), no residualization; user ran it 5 times
  (logs `Logs/conn_margins/linearity_did_twfe__5_Oct_2026_*.log`, table `Tables/conn_margins/linearity_did_twfe_diag.csv`)
- Sandboxed rerun of 3012 on current data (scratchpad copy + `destring industry1`; repo files untouched)
- Read Cattaneo-Crump-Farrell-Feng (2025) Stata Journal 25(1) and arXiv 2407.15276 assumptions
- User edited `linearity_binstest.do` (+7) and `linearity_did_fd.do` (+5) — not touched by Claude

**Decisions:**
- No pre-residualization (Cattaneo Problem 1); FE in `absorb()` — user
- Bin edges at quantiles of D among D>0 (`binspos(numlist)`); J from `binsregselect ..., randcut(1)` (DPI, ROT
  fallback) — default quantile knots stack at the 66% atom at D=0; binstest's own J selection uses an unseeded
  subsample
- Level test (user removed `deriv(1)`); selection switched to `deriv(0) bins(0 0)` → `testmodel(1 1)` (not yet run)
- Same `if` restriction as reghdfe, not `e(sample)`; full 3012 FE set only — user

**Results:**
- Bin collapse (10→5, 20→8, 50→18) identical under firm+time FE and full FE → cause is the atom at 0, not FE count
- Full 3012 FE: linearity never rejected (deriv(1) run p = .153/.701/.418/.396; level run .469/.182/.394/.261 for
  wage/hourly/emp/clauses); firm+time FE only mostly rejects (p .007–.084)
- 3012 on current data = TWFE benchmark exactly; vs published CSV (2 Aug): clauses .0209 vs .0180, emp .0003 vs
  .0004, wage .0050 vs .0051; identical N. Repo 3012 fails on string `industry1` (r(109))
- The positive-quantile-knot method is a heuristic: violates continuous-x assumption (atom), quasi-uniformity
  unchecked, J chosen under es placement. Theory-clean candidate: FD cross-section restricted to conn>0 firms

**Commits:**
- `f543d4b` Add sample-gap and recovered-sample investigations; untrack Docs/pipeline notes
- `6580b96` Ignore full-rerun logs, AER submission notes and reference papers

**Status:**
- Done: TWFE test runs and is reproducible; diagnosis of the atom; 3012 drift quantified
- Pending: (1) re-run `linearity_did_twfe.do` after the `deriv(0) bins(0 0)` selection change; (2) header still cites
  the article as if the method follows it — reword as heuristic; (3) check bin width ratio (quasi-uniformity);
  (4) FD test restricted to conn>0 firms; (5) user literature search (continuous-dose DiD, mass at zero, FE);
  (6) fix 3012 `industry1` (destring in 3012 or upstream `1030_merge_cba_rais.do`); (7) paper cites clause
  spillover .0180 — stale on current data
