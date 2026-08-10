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
  `4032_clause_types.do:221` uses `i.cba_period`; (4) Table 3's note attributes the clause column's
  establishment count to CBA-filing coverage, which predicts the wrong direction
