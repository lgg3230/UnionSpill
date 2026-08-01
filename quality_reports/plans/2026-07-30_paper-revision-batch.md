# UnionSpill paper-revision batch (6 tasks, parallel execution)

**Status:** DRAFT — awaiting approval
**Date:** 2026-07-30

---

## Repo context (verified — do not re-derive)

### Target document

**ALL edits land in `UnionSpill-paper/Replication/Replication_Wages vs Hourly.tex`.**
`UnionSpill-paper/Draft.tex` and the other Overleaf `.tex` files (`Main_Results.tex`,
`Connectivity.tex`, `Robustness.tex`) are **READ-ONLY** this round — read them for conventions and
wording precedent, never write to them.

Two structural facts about the target file:

1. **It is a two-part document.** Part I = "Current Paper: Log Monthly Wages" (L53–L608);
   Part II = "Variant: Log Hourly Wages" (L609–L1164). Almost every table appears **twice**. Any
   table change must be applied to **both** parts, with the Part II version using the hourly
   estimates. Table-by-table anchors:

   | Object | Part I (monthly) | Part II (hourly) |
   |---|---|---|
   | Robustness of Wage Effects | L267, `% BEGIN inlined t_rob.tex` | L823, `t_rob_hw.tex` |
   | Sample Descriptives | L225, `t_desc.tex` (4,196 at L239) | L781, `t_desc.tex` (4,196 at L795) |
   | Pairwise connectivity fig | L57, `bilateral_coefplot.pdf` | L613, same PDF |
   | Distribution of estabs fig | L570 | L1126 |
   | Group-level spillover | L457, `t_groupspecs.tex` | L1013, `t_groupspecs_hw.tex` |

2. **Tables are inlined fragments.** Blocks are delimited by
   `% BEGIN inlined <name>.tex` / `% END inlined <name>.tex`. Source fragments live in
   `quality_reports/replication/hourly_variant_currentconn/frag/` (`t_rob.tex`, `t_rob_hw.tex`,
   `t_spill.tex`, `t_direct.tex`, `t_resid.tex`, `t_composition.tex`, `t_turnover.tex`,
   `t_union.tex`, `t_clause.tex`, `t_groupspecs*.tex`). `t_desc.tex`, `t_layerdesc.tex`, and
   `t_horserace.tex` are inlined only, with no fragment file.
   **Rule: edit the fragment file AND the inlined block, keeping them byte-identical.** If a
   fragment file does not exist for a table you touch, create it and note that you did.

3. **There is a Status note at L1165** ("Status note --- current-connectivity variant") listing
   which objects were re-estimated with current connectivity vs inherited. Every workstream that
   re-estimates or adds an object **must update this note**. Do not leave it stale.

Figures for this document live in `UnionSpill-paper/Replication/Figures/` as PDFs with document-local
names (`distro_region.pdf`, `distro_industry.pdf`, `distro_month.pdf`, `bilateral_coefplot.pdf`).
Regenerating a figure in `Graphs/` is only half the job — you must also refresh the PDF copy in
`Replication/Figures/` under its existing filename.

### Upstream code

| Thing | Location |
|---|---|
| Local-industry robustness estimates | `Programs/robustness/Main_Results_micro_ind.do` → `Tables/robustness/results_micro_ind_test.csv` → `Programs/robustness/generate_micro_ind_latex.py` (`tab:spill_micro_ind`). **Verify** this is what feeds cols 5–6 of the Robustness of Wage Effects table; it may be hand-assembled from several `Programs/robustness/*` runs. |
| Pairwise-connectivity coefficients | consumed by `Programs/conn_descriptives/06_bilateral_coefplot_combined.py` |
| Distribution figure | `Programs/descriptives/distribution_plots.py` |
| Current-connectivity outputs | `Tables/currentconn_full/{robustness,composition,turnover,residuals,clause_types,cba_value}` |

---

## NON-NEGOTIABLE CONDITIONS

**N1 — Current connectivity everywhere.** Wherever connectivity enters an estimation, use the
**current recomputable** measure, not the frozen legacy column.

- Panel: `Data/CBA_RAIS_firm_level_currentconn_overlay/`, built by
  `Programs/main_results/build_currentconn_overlay_panel.do`. That script replaces
  `totaltreat_pw_n` with the current measure and renames the legacy column to
  `totaltreat_pw_n_frozen`.
- ⚠️ **The overlay does NOT regenerate `totaltreat_pw_norm`.** It still carries the legacy p90
  divisor (0.02932389 vs the correct 0.02925788). After pointing any pipeline at the overlay you
  **must** rebuild `totaltreat_pw_norm = totaltreat_pw_n / p90(totaltreat_pw_n)` on the spillover
  sample at 2009 before estimating. Skipping this silently puts regressors on different yardsticks
  and produces no visible breakage. Confirm in your report that you rebuilt it, and print the p90
  you used.
- Outputs go under `Tables/currentconn_full/<pipeline>/`, matching the existing convention.
- Numbers you should reproduce if current connectivity is wired correctly (from the L1165 status
  note): direct effects 0.0262\*\*\* (monthly) / 0.0285\*\*\* (hourly); spillover 0.0050\*\*
  (monthly) / 0.0065\*\*\* (hourly). If your baseline column disagrees, you are on the wrong panel
  or the wrong normalization — stop and diagnose before proceeding.

**N2 — House conventions** (`CLAUDE.md` + memory):
- Stata writes **CSV only**; LaTeX tables are written by Python generators.
- `cap drop` — one variable per line, always. No exceptions.
- Never omit `i.mode_base_month#i.year` from absorb; use `tolerance(1e-2)` on event studies rather
  than dropping it.
- Reuse existing variable definitions verbatim (e.g. `pre_treat_cba` from
  `Main_Results_pct_tfpw_07_11.do`); don't reinvent.
- Significant logic change → new file (`06b_*`), don't edit in place.
- Append `notify` to every long-running Stata/Python job
  (`source Programs/notify.sh && notify "..." "..."`).
- No em-dashes in paper prose.
- LaTeX tables: `[H]` float, `\scriptsize`/`\footnotesize`, notes open "This table ...",
  `\shortstack` for multi-line headers.

---

## Concurrency contract (READ FIRST)

1. **Nobody edits `Replication_Wages vs Hourly.tex` during parallel work.** Each workstream writes
   a self-contained fragment to
   `quality_reports/replication/hourly_variant_currentconn/frag/<name>.tex` and records, in its
   report, the exact splice target: the `% BEGIN inlined <name>.tex` / `% END` block, and whether it
   applies to Part I, Part II, or both. A single serial INTEGRATE step applies all splices.
2. File-write ownership is exclusive per workstream (listed below). If you need to touch a file
   another workstream owns, stop and report it as a conflict instead of editing.
3. STAGE 0 must complete before A, B, D start. C is fully independent and starts immediately.

---

## STAGE 0 — canonical pre-period means (blocking; do this first, alone)

Write one script, `Programs/<appropriate pipeline>/pre_period_means.do` (+ CSV export), that
produces `Tables/currentconn_full/pre_period_means.csv` with columns:

```
sample_id, outcome_var, mean, sd, n_obs, n_estabs, pre_window
```

- Mean is over **treated and control observations pooled**, restricted to the **pre period**.
- Pre window: **2009–2011** by default. For clause-count outcomes that run on CBA negotiation
  periods rather than calendar years, use the matching pre-period definition already in the code and
  record it in the `pre_window` column. Do not silently mix conventions.
- Built on the **current-connectivity overlay panel** per N1, with `totaltreat_pw_norm` rebuilt.
- `sample_id` must cover every estimation sample used by A, B, and D — at minimum: direct-effect
  zero-connectivity sample, direct-effect all-untreated sample, spillover sample, and the
  local-industry-control sample. Produce means for both the monthly and hourly wage outcomes, since
  every table exists in both parts.
- Sanity-check and report: log wage means in the plausible log-BRL range implied by the descriptives
  table (mean wage ≈ R$2,600–3,600), log employment consistent with median firm size, clause count
  ≈ 27–32. **Flag anything off, do not quietly ship it.**

Output: the CSV + a one-paragraph sanity note. A/B/D consume the CSV; they do not recompute means.

---

## WORKSTREAM A — local-industry table: quartile controls + direct-effect columns
*(original tasks 3 and 4 — one unit, because they rewrite the same table)*

**Owns:** `Programs/robustness/Main_Results_micro_ind*.do`,
`Programs/robustness/generate_micro_ind_latex.py`, `Tables/currentconn_full/robustness/*micro_ind*`,
and the fragments `frag/t_rob.tex` + `frag/t_rob_hw.tex`.

**A1 — quartile controls (was task 3).** In cols 5–6 of the Robustness of Wage Effects table
(L267 Part I, L823 Part II), replace the **linear** local-exposure controls (share of treated firms;
share of employment in treated firms, within industry × microregion cell) with **quartile-bin**
versions of the same two variables, interacted with year FE exactly as the linear versions were.
Everything else in the specification is unchanged. Rationale: match the rest of the paper, which
handles these controls in bins.
- Quartiles computed over which population? Default: the estimation sample of that column. State
  your choice explicitly.
- Note the open size-control inconsistency in memory
  (`project_size_control_standard_review`) — do **not** try to resolve it here. Keep the existing
  convention of the script you edit and say which one it uses.

**A2 — direct-effect columns (was task 4).** Expand the table 6 → 8 columns. New cols 7–8 report
**direct effects**, estimated on the **direct-effect sample** (zero-connectivity untreated control
group) with that sample's own controls — **not** by adding a local-exposure regressor to the
spillover regression. Include the quartile-control variant for the direct spec where applicable.
- Panel A currently shows `---` in cols 5–6 because the local-exposure control is spillover-specific.
  Cols 7–8 are what fill that gap; make the panel/column logic and the notes reflect that.
- The note currently reads "These controls address a confound specific to the spillover design, so
  Panel~A is not re-estimated in those columns." Rewrite it.
- The `Spillover / direct effect` row currently carries `$^\dagger$` in cols 5–6, flagging that the
  main direct estimate is used as the denominator. With cols 7–8 supplying real direct estimates on
  the matching sample, revisit whether the dagger convention still applies and state your decision.
- LaTeX mechanics: `\begin{tabular}{lcccccc}` → 8 columns; update `\cmidrule` groupings, the
  `(1)…(8)` numbering row, and every `\multicolumn{7}{l}` panel header to `\multicolumn{9}{l}`.

**A3.** Add the Stage-0 pre-period mean row to this table.

**Both parts.** Part I uses monthly log wages; Part II uses log hourly wages. Same structural
change, different estimates. `t_rob.tex` and `t_rob_hw.tex` must move together.

**Reruns:** state which Stata jobs you reran and their runtime.

---

## WORKSTREAM B — variable means in the remaining regression tables
*(original task 6, minus the robustness table which A owns)*

**Owns:** the Python table generators feeding `frag/t_direct.tex`, `t_spill.tex`, `t_clause.tex`,
`t_composition.tex`, `t_turnover.tex`, `t_resid.tex`, `t_resid_hw.tex`, `t_union.tex`,
`t_union_hw.tex`, `t_groupspecs*.tex` — and those fragment files.

- Add a `Mean` row (pre-period, treated+control pooled, from
  `Tables/currentconn_full/pre_period_means.csv`) to each regression table, per panel, matching each
  panel's own estimation sample.
- Precedent wording exists in `Draft.tex:837` (read-only reference): "Mean reports the pre-treatment
  (2009--2011) average across establishments in each panel's estimation sample." Match that wording
  and placement.
- Update each table's notes to define the mean.
- Apply to both Part I and Part II fragments. Where a `_hw` fragment exists, the mean must be the
  hourly-wage mean, not a copy of the monthly one — this is the most likely place to introduce a
  silent error, so verify it explicitly.
- First produce a short inventory of which tables get a mean row and which are excluded (and why),
  then implement.

---

## WORKSTREAM C — appendix table for pairwise connectivity (fully independent, start now)
*(original task 5)*

**Owns:** `Programs/conn_descriptives/` (new generator script),
`Tables/conn_descriptives/pairwise_conn_appendix.tex`, and a new
`frag/t_pairwise_appendix.tex`.

Build a **new appendix table** from the **already-estimated** coefficients behind
`bilateral_coefplot.pdf` (referenced at L57 and L615). Do not re-estimate. Locate the coefficient
CSVs consumed by `Programs/conn_descriptives/06_bilateral_coefplot_combined.py` and read them.
The figure is visually confusing; the table exists to put the numbers on the page clearly.

**Structure (ambiguity now resolved — implement exactly this):**
- Two **column groups**, one per outcome measure: **connectivity** and **late connectivity**.
- Within each group, **two columns**: **univariate** and **multivariate** regressions.
  → 4 columns total, plus the row-label column.
- Two **panels**: **Panel A** = continuous measure; **Panel B** = the alternative / "without"
  version currently used in the results.
- Each cell: point estimate, standard error in parentheses, significance stars.
- Rows are the proximity measures and dummies. Use the established labels from `CLAUDE.md`
  (Spatial, Size, Wage, % Female, % Non-white, % Higher ed., % High school, # CBA clauses,
  Microregion, Union, Industry, Industry × microregion).
- Report R² and N per column if available in the source CSVs.

**Aesthetics are explicitly low priority** — correct, readable numbers first.

**Placement:** one appendix table serving both parts, or one per part — decide from what the source
CSVs actually contain and state your choice. Note that the L1165 status note currently classifies
pairwise-connectivity predictors as **inherited**, not re-estimated with current connectivity; if
that remains true for this table, say so plainly in the table notes and leave the status note's
classification intact.

---

## WORKSTREAM D — label rename + firm-level N correction
*(original tasks 7 and 8 — grouped because both are small and touch disjoint files)*

**Owns:** `Programs/descriptives/distribution_plots.py`, `Graphs/distro_*`,
`UnionSpill-paper/Replication/Figures/distro_{region,industry,month}.pdf`, and the descriptives
table fragment for D2.

**D1 (was task 7).** In `Programs/descriptives/distribution_plots.py`, `GROUP_LABELS` (L61) is
currently `["Treated", "All untreated", "Zero-conn. controls"]`. Rename the third label to
**"Zero connectivity untreated"**. Also update the console string at L95 ("Zero controls:") and the
module docstring (L3, L14) so the wording is consistent everywhere.
- Regenerate all three panels (region, broad industry, negotiation month) and **copy the PDFs into
  `Replication/Figures/` under their existing names** (`distro_region.pdf`, `distro_industry.pdf`,
  `distro_month.pdf`). The figure appears at L570 (Part I) and L1126 (Part II) — check whether the
  surrounding `\caption`/`\caption*` text also says "zero controls" and fix it if so.
- Check the legend still fits at `legend.fontsize: 8` with the longer label; if it wraps or overlaps,
  adjust `ncol`/fontsize and say so.

**D2 (was task 8).** The descriptives table reports **4,196** untreated establishments
(L239 Part I, L795 Part II — `Number of establishments & 12,276 & 4,196 & 1,931`), which overstates
every actual firm-level estimation sample.
- First **verify from current estimation output** what the largest firm-level estimation sample is.
  `4,142` appears in `Tables/numb_clauses_outliers/*.csv` (clause-count spillover sample) and is the
  hypothesis to test; the group-level fragments report 4,085–4,181, and the robustness table reports
  4,084–4,088. Report the number you found, which sample it comes from, and the file it came from.
- Change the reported count to the largest actual firm-level estimation sample, and update the table
  notes so the reader knows the column now reports an estimation-sample count rather than a
  population count. This changes the meaning of the column — say so in the notes.
- Since `4,196` also appears in `Draft.tex` and `Connectivity.tex`, which are read-only this round,
  **list those occurrences in your report as follow-up** rather than editing them.
- **Do not** force the within-firm / group-level analysis
  (`Programs/layer_connectivity/07_within_firm/`) to match if it legitimately uses a larger sample.
  Its firm counts (4,172–4,181) are expected to differ; leave them.

---

## INTEGRATE (serial, after A–D all report)

1. Apply each workstream's fragment into `Replication_Wages vs Hourly.tex`, one at a time,
   replacing the content between the matching `% BEGIN inlined` / `% END inlined` markers. Confirm
   each fragment file and its inlined copy are identical afterwards.
2. Apply Part I and Part II separately, and verify no Part II table accidentally received Part I
   numbers.
3. Insert Workstream C's new appendix table with a new `\section{}` + `\addcontentsline` matching the
   surrounding style.
4. Update the **Status note (L1165)**: move any newly re-estimated object into the
   "re-estimated with current connectivity" list, and update the headline-read paragraph if any
   headline number moved.
5. Recompile (`module load texlive/2026`) and confirm no overfull-hbox blowups on the widened
   8-column table; if it overflows, switch to `\scriptsize` or landscape and say which.
6. Cross-check every number changed against the regenerated fragments (INV-11).

---

## Required report format

Per workstream, in this order:

1. **Files touched** — exact paths, including both the fragment and the inlined block.
2. **What changed** — concretely, per file, and per Part (I / II / both).
3. **Connectivity provenance** — confirm the overlay panel was used and `totaltreat_pw_norm` was
   rebuilt; print the p90 divisor.
4. **Reruns** — which Stata/Python jobs, runtime, log path.
5. **Numbers that moved** — old → new for every coefficient, SE, and N that changed, with a one-line
   read on whether the change is material to the paper's claims.
6. **Assumptions and ambiguities** — every judgment call, stated as a decision, not a hedge. Flag
   anything needing a ruling.
7. **Conflicts** — anything you wanted to edit that another workstream owns, or that lives in a
   read-only file.

If any workstream is blocked, finish the other five completely and report the blocked one explicitly
rather than half-doing everything.
