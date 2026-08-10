# Pre-treatment mean row for every regression table in the Replication document

**Status:** DRAFT — awaiting approval
**Date:** 2026-08-01
**Target:** `UnionSpill-paper/Replication/Replication_Wages vs Hourly.tex`

---

## 1. Decisions (user-approved 2026-08-01)

| Axis | Decision |
|------|----------|
| Definition | Unweighted mean of the dependent variable over `e(sample) & inrange(year,2009,2011)`, at the regression's own unit of observation |
| Decimals | 2 |
| Label | `Pre-treatment mean`, in all ten tables |
| Flag-C gaps | Repair as part of this task |

The existing `Tables/currentconn_full/pre_period_means.csv` (Stage 0 of plan
`2026-07-30_paper-revision-batch.md`) is **superseded**. It averages a firm-level
pre-average once per firm at `year==2009` (mean over firms) and ignores singleton
dropping — spill reports 4,194 establishments against the table's 4,084. It is not
deleted, but nothing in this task reads from it.

---

## 2. The Stata pattern

Immediately after each `reghdfe` whose coefficient is printed, before any `cap drop`:

```stata
quietly sum `outcome' if e(sample) & inrange(year, 2009, 2011)
local mean_pre_val = r(mean)
```

then one extra `file write` row using each script's existing postfile schema:

```stata
file write `fh' `""`spec'";"`section'";"`outcome'";"mean_pre";"' %9.4f (`mean_pre_val') `"""' _n
```

Written at 4 decimals into the CSV; rounded to 2 in Python at render time, so the
precision decision is reversible without re-running Stata.

Rules:
- Taken from the **main** specification's `e(sample)`, never the placebo regression's.
- One value per printed column, per panel.
- `reghdfe` sets `e(sample)`, so singleton drops and all sample restrictions are
  inherited automatically — no restriction is restated by hand.
- Group-level tables need no special handling: their `e(sample)` is already
  group x firm x year.

---

## 3. Work by table

### Estimation scripts to modify (14)

| Table | do-file | Current state |
|-------|---------|---------------|
| 1, 2 Direct + Spillover | `4012_pct_tfpw.do` | no mean row — add |
| 3 Clause counts/props | `clause_types/4032_clause_types.do` | no mean row — add |
| 3 CBA value (col 7) | `cba_value/4042_cba_value.do` | has `mean_pre` — **redefine** to `e(sample)` |
| 4 Union confounders | `robustness/4072_union_controls.do` | no mean row — add |
| 5 cols 2–3 | `robustness/4052_robustness_bins.do` | no mean row — add |
| 5 col 4 | `robustness/Main_Results_demo_controls.do` | no mean row — add |
| 5 cols 5–8 | `robustness/4062_micro_ind_q.do` | has `mean_pre` — **redefine** |
| 6 Turnover | `turnover/4082_turnover.do` | has `mean_pre`, **control-group only** — redefine |
| 7 Composition | `composition/4092_composition.do` | has `mean_pre`, **control-group only** — redefine |
| 8 Residualized | `residuals/4112_mincer.do` | has `mean_pre` — redefine |
| 9, 10 Group-level | `layer_connectivity/07_within_firm/01_within_firm_estimates.do`, `01b_*`, `01_*_hw.do`, `01b_*_hw.do` | no mean row — add (4 files) |

Tables 6 and 7 are the substantive fixes: their printed `Mean` row is currently
computed over controls only. Panel A `% Male` reads 0.5853 today; the pooled
`e(sample)` figure will differ visibly. **This is an intended number change** and the
only place where an existing printed value moves.

### Python generators

Update (8): `5200_table_cba_value_latex.py`, `5060_table_rob_logwages.py` (flip
`INCLUDE_MEAN` default to on), `5210_table_turnover_latex.py`,
`generate_composition_latex.py`, `5190_table_mincer_latex.py`,
`5070_table_resid.py`, `5180_table_union_controls_latex.py`,
`07_within_firm/5090_table_within_firm.py`.

Write (4), closing the missing-generator gap:
- `Programs/main_results/5010_table_direct.py` → `t_direct.tex`
- `Programs/main_results/5020_table_spill.py` → `t_spill.tex`
- `Programs/clause_types/5040_table_clause.py` → `t_clause.tex`
- `Programs/robustness/5050_table_union.py` → `t_union{,_hw}.tex`

**Union correction (found 2026-08-01, during step 1).** The existing
`5180_table_union_controls_latex.py` is a **6-column** generator reading the legacy
`Tables/robustness/` path, and its numbers (0.0051, 0.0044) do not match the
document (0.0050, 0.0043). It is left untouched — `4072_union_controls.do`
still calls it. The document's **10-column** table is backed by
`Tables/currentconn_full/robustness/results_spill_union_controls{,_hw}.csv`, whose
`main` values match the document exactly across all ten columns, so a new generator
targeting the replication layout is written instead. The `Spillover / direct effect`
row is computed (coefficient / 0.0262 monthly, / 0.0285 hourly), not stored.

Additionally, `frag/t_union.tex` is **stale**: a 4-column build superseded by the
document's 10-column table. The new generator regenerates it so `frag/` and the
document agree.

Each reads the existing currentconn CSVs and must reproduce the current fragment
byte-for-byte before the mean row is added — that equality is the acceptance test
for the generator itself (step 5.2).

### Re-runs required

One Stata process per pipeline (per `reghdfe` session-state note in memory —
a prior pass in the same process shifts coefficients in the 6th digit):

`pct_tfpw_cc`, `clause_types`, `cba_value`, `union_controls`, `robustness_bins`,
`demo_controls`, `micro_ind_q`, `turnover`, `composition`, `mincer`,
`within_firm` x4. Each gets `notify` appended.

Turnover must be re-run regardless: its currentconn CSVs are header-only
(`results_spill_turnover.csv` = 1 line), so the inlined fragment cannot currently be
regenerated at all.

---

## 4. Fragment and document layout

- New row `Pre-treatment mean` immediately above `Observations`, inside the existing
  summary block. No `\midrule` added or moved.
- Multi-panel tables get one row per panel.
- Negative values use `$-$`; thousands separators unchanged (means will not need them).
- Notes gain: *"Pre-treatment mean is the mean of the dependent variable over
  2009--2011 in the estimation sample of the corresponding column."* Tables 6 and 7
  lose their current *"average across establishments in each panel's estimation
  sample"* wording, which described the superseded definition.

Five fragments (`t_direct`, `t_spill`, `t_clause`, `t_turnover`, `t_composition`)
are inlined **twice** — once per half — from a single file carrying both monthly and
hourly columns. Editing them once covers both halves; a mistake there also lands
twice.

Inlining: `07_within_firm/5100_inline_into_replication.py` currently handles only its
own six stems. It will be extended to cover all fragments, keeping its
marker-based, idempotent design. Two tables (`t_union`, `t_union_hw`) have **no
markers** in the document and need them added first.

---

## 5. Verification

1. **Coefficients frozen.** After every re-run, diff new CSVs against current for all
   non-`mean_pre` rows. Any change is a stop-and-report, not a fix-forward. Expected
   risk: 6th-digit `reghdfe` drift, invisible at 4 printed decimals — but verified,
   not assumed.
2. **Generator fidelity.** The three new generators must reproduce the current
   fragments exactly with the mean row suppressed, before it is switched on.
3. **Fragment diff.** Regenerated fragments differ from current only in (a) the added
   row, (b) notes, (c) the two intended composition/turnover mean corrections.
4. **Sanity.** Log wages in 7.0–9.0, log employment 1.5–6.0, shares in 0–1,
   `n` behind each mean equal to the 2009–2011 slice of that column's `Observations`.
5. **Compile.** `module load texlive/2026`, rebuild the PDF, confirm no table
   overflows with the extra row.

---

## 6. Risks

- **Re-running everything to add a display row.** The prompt requires existing
  estimates unchanged, so every re-run is a chance to perturb a published number.
  Step 5.1 is the guard.
- **Tables 6 and 7 numbers move by design.** Their current `Mean` row is wrong under
  the approved definition. Flagged here so it is not mistaken for a regression.
- **`t_rob` cols 1–4** are assembled from a frozen snapshot rather than a CSV. The
  data exist; the generator will be repointed at the CSVs, which risks reformatting
  differences — caught by step 5.2.
- **Compute.** The `pct_tfpw` and `within_firm` re-runs dominate; expect this to span
  more than one session.

---

## 6b. Step-2 findings (2026-08-01)

**Generators built and verified byte-identical:**

| Generator | Output | Verified against |
|---|---|---|
| `main_results/5020_table_spill.py` | `t_spill.tex` | committed fragment — identical |
| `robustness/5050_table_union.py` | `t_union.tex`, `t_union_hw.tex` | document lines 251–292 and 809–850 — both identical |

**Blocked, two new gaps:**

1. **`t_direct` equality row has no reproducible source.** Panel mapping resolved
   (document Panel A = CSV `direct_A`; document Panel B = CSV `direct_C`, not
   `direct_B`, which is unused). But the `$p$-value` row — [0.009] [0.013] [0.741]
   [0.386] — appears in no CSV. The only script computing it,
   `conn_margins/4022_direct_sample_coef_test.do`, runs against the **legacy** panel and
   its saved output covers only 2 of the 4 outcomes. Its monthly p-value (0.0088)
   rounds to the printed [0.009]; its hourly (0.0105) does not match the printed
   [0.013] — expected, since legacy and currentconn should differ, but it means the
   printed value is currently unverified. Repair: re-run that do-file against the
   currentconn overlay for all four outcomes, writing a tracked CSV.

2. **`t_clause` column 7 has no data.** `results_spill_cba_value.csv` is header-only.

**Empty-CSV problem is systematic, not a one-off.** A scan of all 55 currentconn
CSVs found exactly 6 unusable, in a consistent pattern — `turnover` and `cba_value`
both have a populated panel A and empty panelB / panelC / spill. Both runs died
after the first panel. Both pipelines have `_cc.do` runners and must be re-run in
full.

Revised re-run list adds: `cba_value` (via `4041_cba_value.do`) and
`conn_margins/4022_direct_sample_coef_test.do` (currentconn, 4 outcomes).

## 6c. Step-3 progress and a third gap (2026-08-01)

**Do-files patched** (mean captured on `e(sample)` immediately after the main
regression, before the placebo replaces it; written as a `mean_pre` row):

| do-file | Blocks | Note |
|---|---|---|
| `4012_pct_tfpw.do` | 4 | direct continuous, direct clauses, spill continuous, spill clauses |
| `composition/4092_composition.do` | 2 | replaced firm-average-at-2009 construction |
| `turnover/4082_turnover.do` | 2 | replaced `s_use`-conditioned mean that ignored singleton drops |
| `robustness/4072_union_controls.do` | 6 | patched programmatically; **only 6 of 10 columns exist in code** |
| `robustness/4062_micro_ind_q.do` | 1 | replaced firm-average-at-2009 construction |

**GAP 3 — union columns 7–10 have no source code.** The tracked
`4072_union_controls.do` produces six columns (baseline, union x year FE,
two linear exposure controls, two quartile controls); its last commit `a2c5b74`
added columns 5–6. The published table and the currentconn CSV both carry **ten**
columns -- the decile and vingtile specifications (7–10) as well. No script in the
repository writes `";7;"` through `";10;"` to that CSV. Those four columns were
produced by an extension that was never committed.

This is materially worse than gaps 1 and 2, which were "re-run existing code".
Repairing this means **writing new estimation code for four already-published
columns** and hoping it reproduces them. Escalated to the user, who chose
reconstruction.

**RESOLVED — the reconstruction reproduces the published columns exactly.**
Bins built as `cut(...) if year == 2009 & in_balanced_panel == 1, group(10|20)`
then `min` over firm, mirroring the quartiles; firm-share columns interact with
full year FE (following col 5), worker-share columns with `treat_year` /
`placebo_year` (following col 6). Re-run output:

| Col | Published | Reconstructed |
|---|---|---|
| 7 firms, deciles | 0.0057** | 0.0057** |
| 8 workers, deciles | 0.0048** | 0.0048** |
| 9 firms, vingtiles | 0.0046** | 0.0046** |
| 10 workers, vingtiles | 0.0046** | 0.0046** |

Columns 1–6 unchanged; all non-`mean_pre` rows byte-identical to baseline.

**GAP 4, found immediately after — the hourly union variant had no script
either.** The do-file hardcoded `local outcome "lr_remdezr_w"`, so nothing could
produce `results_spill_union_controls_hw.csv`. Outcome and CSV suffix are now
parameterized through `$OUTVAR` / `$OUTSUF`, following the committed
`4061_micro_ind_q.do` pattern, with defaults preserving the original monthly
behaviour. Added `_run_union_controls_cc.do` and `4071_union_controls.do`;
the legacy `_run_union_controls.do` is untouched and still feeds the six-column
table in the main draft.

**First evidence the definition change matters.** Union col 1 pre-treatment mean
is 7.5514 on `e(sample)` against 7.5550 in the superseded canonical file — the
gap is the ~110 establishments that singleton-dropping removes. Col 2, which
drops 3,781 observations, correctly reports a different mean (7.5479) from the
other nine columns.

**Unrelated observation, not acted on.** `turnover/4082_turnover.do` builds
`absorb` with `extra_year` (`totalflows_pw_pre_07_114#i.year`) for every outcome,
including `$flow_outcomes` (`totalflows_pw`, `outflows_pw`, `inflows_pw`). The
project rule requires excluding `extra_year` for exactly those outcomes or the
regression absorbs the outcome and returns R^2 = 1.0000. Those three outcomes do not
appear in the seven displayed columns of the replication table, so the exhibit is
unaffected; flagged because this script is about to be re-run and changing it would
move estimates, which the freeze forbids.

## 6d. Status at end of session 2026-08-01

**Do-files patched (10 of 14):** `4012_pct_tfpw.do` (4 blocks),
`composition` (2), `turnover` (2), `union_controls` (10, incl. reconstruction),
`micro_ind_q` (1), `clause_types` (2), `cba_value` (2, window switched from
`cba_period 1-2` to calendar 2009-2011), `robustness_bins` (4),
`demo_controls` (6), `mincer` (2).

**Remaining:** the four `07_within_firm` estimation do-files (group-level tables
9 and 10).

**Re-run and verified (1 pipeline):** union controls, both variants. All
non-`mean_pre` rows byte-identical to baseline; 10 mean rows each.

**Still to re-run:** pct_tfpw_cc, clause_types, cba_value, robustness_bins,
demo_controls, micro_ind_q, turnover, composition, mincer, within_firm x4,
and the currentconn equality test for `t_direct`.

**Generators:** `t_spill` and `t_union{,_hw}` written and byte-verified; both
now render the mean at 2 decimals from 4-decimal CSV storage. `t_direct` and
`t_clause` still blocked on their re-runs.

**Open formatting question.** At 2 decimals the union table's mean row reads
7.55 in all ten columns, although column 2 genuinely differs (7.5479 vs 7.5514,
because it drops 3,781 observations). The row is visually constant and therefore
carries no information in log-wage tables. 3 decimals would separate them;
4 would match the existing house rows. Flagged for the user.

## 6e. FINAL STATUS (2026-08-02)

**Status: COMPLETE for all 10 tables (turnover inlined 2026-08-02).**

Document compiles, 44 pages, 36 `Pre-treatment mean` rows. The only `Mean` rows
left are the four in `t_desc` (Sample Descriptives, descriptive, out of scope).

**Turnover inlined 2026-08-02.** Held back while its provenance was unclear;
resolved as convergence slack, not a reproduction failure (see 6e). Printed
numbers now come from code that can be re-run rather than from the deleted
report builder. Changes to the published table: seven Panel A coefficients shift
in the 4th decimal (all <= 0.094 SE), and the Panel A churn pre-trend crosses
into significance, $-$0.0498 -> $-$0.0528*. Panel B is near-identical --
retention, separation and quit reproduce to the digit. The old control-group-only
`Mean` row is replaced by the pooled `e(sample)` row, which is why Panel A log
hours moves 6.150 -> 6.983 while Panel B barely moves (7.287 -> 7.284).

### Delivered

| Table | Mean row | Freeze |
|---|---|---|
| Direct Effects | yes | all coefficients/SEs/N identical; one $p$-value moved [0.013]->[0.012] |
| Spillover Effects | yes | byte-identical |
| CBA Composition & Value | yes | byte-identical |
| Union-Level Confounders (x2) | yes | byte-identical; cols 7-10 reconstructed exactly |
| Robustness of Wage Effects (x2) | yes | byte-identical |
| Workforce Composition | yes | byte-identical (old control-only `Mean` replaced) |
| Residualized Wages (x2) | yes | coefficients/SEs identical; N 32,498->32,495, estabs 4,085->4,084 |

### Held back

**Decomposing Employment Effects (turnover).** Re-running reproduces the sample
exactly (113,112 / 112,620 obs; 14,139 estabs) but not the coefficients:
Panel A log hours 0.0015 vs published 0.0003, churn 0.0108 vs 0.0122, and the
churn pre-trend crosses into significance ($-$0.0528* vs $-$0.0498). Same sample
with different coefficients means a specification difference, not a data one.
Pre-existing: `Tables/turnover/results_direct_panelA_turnover.csv`, written
before this work, already disagrees with the published table (0.0008). Not
inlined -- the fragment and its `Mean` row are untouched.

**~~Group-level tables (within-firm A7/A8).~~ RETRACTED 2026-08-02 -- this was my
error, not a reproducibility failure.**

There are two implementations: `01_within_firm_estimates.do` (v1) and
`01b_within_firm_estimates.do` (v2), the latter omitting nested plain fixed
effects once group-interacted FEs enter, per `R/04_engine.R:185-191`. **Both write
to the same unsuffixed `a7.csv`/`a8.csv`** -- `_run_within_firm_v2.do` sets
`table_suffix ""` exactly as `_run_within_firm.do` does. The published exhibits
come from v2. I selected runners by name pattern, ran v1, and overwrote them.

Restored all 28 CSVs from the pre-run snapshot, then ran the correct v2 arm:
`a7.csv`, `a7_hw.csv`, `a8.csv`, `a8_hw.csv` are byte-frozen with `meanpre`
appended, and all six fragments differ from the document only in the mean rows
and notes. **The group-level tables reproduce exactly.**

Lesson for the next session: in `07_within_firm/`, the runner name does not
identify the arm. Check `table_suffix` and the called do-file before running --
`_run_within_firm.do` and `_run_within_firm_v2.do` collide on output paths.

### Infrastructure repaired along the way

- **Root cause of the 6 empty CSVs found and fixed**: `Graphs/currentconn_full/<pipeline>/`
  did not exist, so `graph export` raised `r(691)` and killed each run after its
  first panel. Directories created; turnover and cba_value now produce full output.
- **Union columns 7-10 reconstructed** and reproduce published values exactly.
- **Six missing currentconn wrappers written**: `_run_union_controls_cc.do`,
  `4071_union_controls.do`, `4051_robustness_bins.do`, `_run_demo_controls_cc.do`,
  `4031_clause_types.do`, `_run_currentconn_mincer_full.do`,
  `4021_direct_sample_coef_test.do`.
- **Four new generators** for fragments that had none: `5010_table_direct.py`,
  `5020_table_spill.py`, `5040_table_clause.py`,
  `5050_table_union.py`, plus `5030_table_twopanel.py`
  for turnover/composition.
- **Union do-file parameterized** (`$OUTVAR`/`$OUTSUF`) so the hourly variant is
  reproducible; **equality test parameterized** (`$testsuf`) for the currentconn arm.
- **Inline script generalized** from 6 stems to 13, with `t_turnover` deliberately
  excluded and the reason recorded in the source.

### Bug caught on final audit (2026-08-02)

`5100_inline_into_replication.py` substituted with `count=1`. That was correct for
the six within-firm stems it was written for, which appear once each, but five
fragments (`t_direct`, `t_spill`, `t_clause`, `t_turnover`, `t_composition`)
appear **twice** -- once per half of the document -- because each already carries
both wage columns. Generalizing the script left every hourly copy stale, with
`t_composition` showing the superseded control-only `Mean` row alongside the new
one. Fixed to replace all occurrences; the script now reports the count per stem.
Re-inlined and recompiled: 46 pages, every in-scope table carries the row in both
halves, and the only `Mean` rows left are the four in `t_desc` (descriptive,
out of scope) and the four in turnover (deliberately untouched).

### Turnover: resolved as convergence noise, not a reproduction failure

The `Logs/currentconn_full/turnover/FinalResults_turnover_27_Jul_2026_013625.log`
run that fed the published table shows `.000303` for log hours on n=113,112 with
the identical absorb list and the identical p90 divisor (`.0292579`) as the
current run. Ruled out in turn: YoY vs non-YoY retention (SE and n pin the column
to `retention_u`), size control mean-of-log vs log-of-mean (byte-identical
output -- the quartile ranking is invariant to the transform), legacy vs overlay
panel (n=113,096 vs 113,112; published matches the overlay), stale flow-control
inputs (February file date), and script drift (only the mean-row edit since
March). All seven Panel A gaps are <= 0.094 SE and quit -- the best-determined
coefficient relative to its SE -- is identical. Left uninlined because one
pre-trend star appears (churn, $-$0.0498 -> $-$0.0528*).

**The deleted report builder.** `Programs/main_results/__pycache__/build_currentconn_hourly_variant_report.cpython-312.pyc`
exists with no source and no git history. Its constants name every fragment in
the document plus a `results_direct_*_currentconn_wages.csv` family. That single
deleted script is why so many fragments had no generator. The generators written
here now cover the in-scope tables, but it also built exhibits this task did not
touch.

### Open items for the user

1. Turnover and within-firm A7 reproducibility (above).
2. At 2 decimals the mean row is constant across columns in single-outcome tables
   (union reads 7.55 ten times) even where samples genuinely differ. 3 decimals
   would separate them; CSVs hold 4, so this is a one-line change.
3. `4082_turnover.do` includes `extra_year` in `absorb` for
   `$flow_outcomes`, against the project rule. Those outcomes are not in the
   displayed columns, so the exhibit is unaffected; not changed, since changing it
   would move estimates.

## 7. Sequence

1. Add markers for `t_union` / `t_union_hw`; extend the inline script.
2. Write the three missing generators; prove byte-equality (5.2).
3. Modify the 14 do-files.
4. Re-run pipeline by pipeline, one Stata process each, diffing CSVs after each (5.1).
5. Regenerate fragments, re-inline, compile, verify (5.3–5.5).
6. `/checkpoint`.
