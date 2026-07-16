# Verification Report — Draft.tex

**Date:** 2026-07-16
**Mode:** Standard (invoked via `/paper-review`)
**Target:** `/gpfs/kellogg/proj/lgg3230/UnionSpill/UnionSpill-paper/Draft.tex` (1,273 lines)
**Overall: PARTIAL** — static checks performed; compilation not performable in this environment.

---

## Scope Limitation (read first)

**No LaTeX toolchain exists in this environment.** Independently confirmed via `command -v`:

| Binary | Status |
|--------|--------|
| latexmk, xelatex, pdflatex, lualatex, biber, bibtex, tex | ALL ABSENT |

Consequently **Check 1 (LaTeX compilation) was NOT PERFORMED — neither PASS nor FAIL.**
Any compile verdict would be fabrication. Everything below is static source analysis.

Corroborating context: `Draft.tex` has **no build artifacts whatsoever** (no `.aux`, `.pdf`,
`.log`, `.bbl`, `.toc`), whereas sibling `Main_Results.tex` has a full set dated 07-15. Draft.tex
appears never to have been compiled in this working tree, so no compiler has ever validated its
references. This raises rather than lowers the value of the static checks below.

---

## Check Results

| # | Check | Status | Details |
|---|-------|--------|---------|
| 1 | LaTeX compilation | **NOT PERFORMABLE** | No toolchain present. Not scored. |
| 2 | Script execution | NOT IN SCOPE | Standard-mode paper review |
| 3 | Figure integrity | **PASS** | 15 live `\includegraphics`, 15 resolve, 0 missing |
| 4 | Citation integrity | **PASS** | 60 unique keys, 0 undefined against 98 bib entries |
| 5 | Cross-reference integrity | **FAIL** | 1 orphan `\ref` → would render `??` |
| 6 | Label hygiene | **PASS** | 40 labels, 0 duplicates |
| 7 | Environment balance | **PASS** | 104 `\begin` / 104 `\end`, nesting order clean |
| 8 | Table inputs | **N/A (vacuous)** | Zero `\input`/`\include` — Draft is self-contained |
| 9 | Output freshness | **PASS w/ advisory** | 0 stale copies; 2 headline figures untraceable |
| — | INV-9 (biblatex+biber) | **FAIL** | Uses natbib + bibtex |
| — | INV-10 (hyperref/cleveref) | **FAIL** | hyperref not second-to-last; cleveref absent |

---

## FAIL 1 — Orphan cross-reference (`tab:spillover`)

**This is the one actionable defect that would visibly corrupt the compiled PDF.**

- **Location:** `Draft.tex` line 988, inside the notes block of the group-specifications table.
- **Text:** `Columns (1) and (4) report the full-sample firm-level spillover of Table~\ref{tab:spillover}, identical across panels.`
- **Problem:** No `\label{tab:spillover}` exists anywhere in `Draft.tex`. Draft.tex has zero
  `\input`/`\include`, so it is self-contained — the label cannot be supplied from elsewhere.
  `Main_Results.tex` does not define it either (checked: 0 occurrences).
- **Effect:** Renders as `Table ??` in the PDF.
- **Likely intended target:** `\label{tab:spill_main_4tf_out}` (line 420), the main spillover table.
  **Not auto-corrected — requires author confirmation.**

The 12 table labels actually defined are: `tab:direct_connectivity_robust` (327),
`tab:spill_main_4tf_out` (420), `tab:spill_clause_decomp` (530), `tab:spill_union_4tfpe_4out` (585),
`tab:descriptive_stats` (697), `tab:rob_logwages` (739), `tab:turnover` (788), `tab:composition` (834),
`tab:resid_raw_base` (875), `tab:layer_desc_full` (907), `tab:group_specs` (936), `tab:horse_race` (996).

---

## FAIL 2 — INV-9: bibliography engine

Required: `biblatex` + `biber`. Actual: `natbib` + `bibtex`.

- `Packages/lgag_eesp-paper.sty:39` → `\usepackage{natbib}`
- `Packages/lgag_eesp-paper.sty:40` → `% \usepackage[backend=biber]{biblatex}` (commented out)
- `Draft.tex:24` → `\bibliographystyle{Packages/ecca}`; `Draft.tex:679` → `\bibliography{bib}`

**Characterization:** this is a standards deviation, not a breakage. The natbib/`ecca.bst` stack is
internally consistent and compiles fine on Overleaf. Flagged because INV-9 enforcement is mandatory
for this agent. Remediation is a deliberate authorial choice, not a mechanical fix.

## FAIL 3 — INV-10: hyperref / cleveref

- `hyperref` loads at line 22 of `lgag_eesp-paper.sty`, with ~30 packages loaded **after** it
  (inputenc, fontenc, natbib, mathtools, xcolor, caption, mdframed, fancyhdr, libertine, tcolorbox…).
  INV-10 requires it second-to-last.
- `cleveref` is **absent from the entire project** (grepped Draft.tex + all `Packages/*.sty`).
  The paper uses manual `Table~\ref{}` / `equation~(\ref{})` throughout, consistent with its own
  house style but not with INV-10.

**Same characterization as INV-9:** deviation from invariant, not a compile blocker. Reordering
`hyperref` in a mature, working `.sty` carries real regression risk and should not be done casually.

---

## PASS details

### Figure integrity (Check 3) — reconciles your count of 21
Your report of "21 referenced, 0 missing" is **confirmed on the bottom line, refined on the count**:

- 21 raw `\includegraphics` occurrences.
- **6 are inside commented-out blocks** (lines 1242–1271, all `Archive/Figures/WS/…`) and are
  therefore dead. (Spot-checked: those Archive PDFs do exist on disk anyway, so they would resolve
  even if uncommented.)
- **15 live calls; all 15 resolve** to real files under `UnionSpill-paper/Figures/`. **0 missing.**

### Citation integrity (Check 4)
- 64 `\cite*` commands → 60 unique keys; `bib.bib` holds 98 entries. **0 undefined keys.**
- 38 bib entries are never cited. Harmless under bibtex (only cited entries print). Informational only.

### Environment balance (Check 7)
All 11 environment types balanced across 104 begin/end pairs. A stack-based pass found **0 nesting
order errors** (no interleaved or unclosed environments). Comment-stripped, so commented-out
environments correctly excluded.

### Output freshness (Check 9)
`UnionSpill-paper/Figures/` holds *copies* of what `Programs/` writes into `Graphs/`, so the live
risk is a silently stale copy. Compared mtimes for all 15 live figures against the newest
same-named file in `Graphs/`: **0 stale copies.** 13/15 trace to a `Graphs/` source with the paper
copy at or newer than source.

**Advisory — 2 headline figures have no traceable generator:**

| Figure | Draft line | Finding |
|--------|-----------|---------|
| `Figures/Main/es_lr_remdezr_w_directA_pct.pdf` | 306 | No `Graphs/` counterpart; no script in `Programs/` references this filename; file exists only in the paper repo |
| `Figures/Main/es_lr_remdezr_w_spill_pct.pdf` | 403 | Same |

Both are dated 2026-03-20 16:00 (a timestamp shared with several unrelated files — consistent with
a bulk copy/checkout rather than a generation event). The closest in-repo relatives are
`Graphs/es_lr_remdezr_w_directA_11_Mar_2026.pdf` (non-`_pct`, 2026-03-11), associated with
`Programs/extpre_eventstudy_export.do`.

**Not over-claimed:** I cannot determine whether the `_pct` files are rescaled variants of those,
were produced by an ad hoc/off-cluster process, or were hand-renamed. They exist and will render
correctly. This is a **traceability gap, not a defect** — but it concerns the paper's two central
event-study exhibits, and it is exactly what INV-22 / submission Check 9 would block on later.

---

## Code invariants (INV-14/15/16/19) — bounded spot-check

Outside the stated scope of this paper review; sampled for completeness. **Not exhaustive, and not
the basis for this report's verdict.**

- **INV-19:** violations found only in legacy/contributed trees — `Programs/Old/results_1.R:1`
  (`install.packages`), `Programs/Gui_coding/*.R:1` (`rm(list = ls())`, 6 files),
  `Programs/final_withinfirm_replication_extracted/…/run_all.R:27,30` (`setwd`). **None are in the
  scripts generating this Draft's figures.**
- **INV-16:** absolute paths are pervasive in Stata via `$klc`-style globals (e.g.
  `Programs/rand_inference/16_recentered_eventstudy.do:16-18`). This is an **explicitly documented
  project convention in CLAUDE.md** and conflicts with INV-16 by design. Escalate as a policy
  question; do not silently "fix".
- **INV-14:** `np.random.seed(42)` appears twice in `Programs/conn_margins/linearity_fig3_spline.py`
  (lines 62, 97) — INV-14 requires exactly once at top. That script does not feed this Draft.
- **INV-15:** `Programs/conn_descriptives/hist_connectivity.py` — imports correctly at top (line 20+,
  after the module docstring). Compliant.

---

## Summary

- **Checks performable:** 7 of 8 in-scope static checks (+2 mandated paper invariants).
- **Passed:** figure integrity, citation integrity, label hygiene, environment balance, freshness.
- **Failed:** 1 orphan cross-reference (`tab:spillover`); INV-9; INV-10.
- **Not performable:** LaTeX compilation — no toolchain. Overfull-hbox count, undefined-citation
  confirmation at compile time, and PDF generation are all unverifiable here.
- **Overall: PARTIAL.**

**Highest-value action:** fix `\ref{tab:spillover}` at Draft.tex:988 (almost certainly →
`tab:spill_main_4tf_out`). Since Draft.tex has never been compiled, a real compile pass on Overleaf
is strongly recommended and may surface additional issues invisible to static analysis.

**No files were edited. Read-only inspection.**
