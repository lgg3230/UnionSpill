# Manuscript Review — UnionSpill (`Draft.tex`)

**Date:** 2026-07-16
**Agent:** writer-critic (standalone, via `/paper-review UnionSpill-paper/Draft.tex`)
**Target:** `UnionSpill-paper/Draft.tex` (1,273 lines)
**Paper type:** Reduced-form causal inference (DiD/event study + continuous-exposure spillover)
**Severity:** HIGH (Execution phase)
**Score: 52/100** — categories 4, 5, 6, 8 scored

> **Provenance note.** The writer-critic agent is read-only (Read/Grep/Glob) by design —
> separation of powers, per `.claude/rules/agents.md`. But `skills/paper-review/SKILL.md`
> instructs the critic to "Save report to quality_reports/...". It cannot. The report was
> returned inline and persisted here by the orchestrator. See "Pipeline defect" at the bottom.

---

## Scores

| # | Category | Verdict | Deduction |
|---|---|---|---|
| 1–3 | Structure / Claims / Identification | NOT SCORED (standalone mode) | — |
| 4 | Writing Quality | House-rule violations; AI tells minimal | −4 |
| 5 | LaTeX and Format | NON-COMPLIANT | −26 |
| 6 | Compilation | NOT VERIFIABLE (static defects found) | −8 |
| 7 | Voice Fidelity | NOT SCORED — style guide is a template | — |
| 8 | Notation Consistency | INCONSISTENCIES | −10 |

## Read the score before acting on it

The 48 lost points are three different problems and should not be treated as one:

- **−21 pre-existing house-format baseline** (`natbib`/`bibtex`, no `cleveref`, no `microtype`,
  `\setstretch{1.4}`, `hyperref` load order, manual `Table \ref{}`). This is the preamble in
  `Packages/lgag_eesp-paper.sty` the paper has always had. A one-time migration decision,
  **not a regression from a recent edit**.
- **−22 real, fixable drafting defects.**
- **−5 house prose rule** (em-dashes + one copula avoidance).

Fixing the real defects alone → ~74. Plus the prose rule → ~79. The preamble migration is what
gets past 95.

## What is genuinely good

All 17 headline numbers traced to their tables, **zero mismatches** (2.6%/2.9%; 1.6 clauses =
4.9% of 31.9; 1.8%/2.0%; p=0.009/0.011; 0.51%/0.66%; ratio 0.195/0.230; breakdown M̄=0.75/1.77;
residualized 0.40% = 78% of 0.51%; 46.0% = 1931/4196). All 60 `\cite` keys resolve against
`bib.bib`. No `\label` collisions; environments balanced. Writing is human and varied — no
significance inflation, no filler, no vague attributions.

---

## Top 5 issues

### 1. `siunitx` commented out but `S` column type used — CONFIRMED, would fail to build
`Draft.tex:999` declares `{l S[table-format=-1.4] ...}` (×4) for `tab:horse_race`, while
`Packages/lgag_eesp-paper.sty:60` has `%\usepackage{siunitx}`.

**Orchestrator verification (2026-07-16), static:**
- `Draft.tex:2` loads exactly `Packages/lgag_eesp-paper` — the `.sty` where siunitx is commented out
- `siunitx` is live only in `Packages/lgag_nw-slides.sty:69`, which `Draft.tex` does not load
- no `\newcolumntype{S}` fallback exists anywhere in the repo

Engine-independent `Illegal pream-token (S)` error. The critic deducted −5 rather than −20 because
it could not compile; the static evidence supports the defect being real. **If a build confirms,
this is −20 and the score drops to 37. Fix this first.**

### 2. Undefined reference `\ref{tab:spillover}` (`Draft.tex:988`) — CONFIRMED
No such label among the document's labels. Renders **"Table ??"**. Intended target is almost
certainly `tab:spill_main_4tf_out` (defined line 420, correctly referenced at line 1042).
**Independently flagged by the verifier agent.** Left uncorrected — needs author confirmation. (−3)

### 3. Table notes contradict the specification
Lines 821, 866, 1087. Notes for `tab:turnover` / `tab:composition` describe controls as
"per-worker flows and establishment size", while `tab:direct_connectivity_robust` /
`tab:spill_main_4tf_out` / `tab:resid_raw_base` describe the *same* baseline as including
"**and the outcome**" bins. One specification, two descriptions — a referee magnet. The author's
own `% VERIFY` flags are unresolved. (−3)

### 4. 14 em-dashes — violates the zero-tolerance domain-profile prose rule
Lines 73, 76×2, 118, 120, 184×2, 282×2, 660, 675, 935, 988×2. (−3)

### 5. Missing JEL codes and keywords (INV-6)
Nothing between `\end{abstract}` (65) and `\section{Introduction}` (72). (−5)

## Also

- Raw Unicode `×` at line 428 where all 11 other tables use `$\times$` (−2, plus texlive-2015 portability risk)
- Hardcoded `equation (2)` at line 649 instead of `\ref{eq:conn}` (−2)
- Abstract missing `\noindent` / `\singlespacing` (−2)

## Passing

12pt article ✓ · no `\textbf` title ✓ · no `\and` ✓ · `fancyhdr` footer ✓ · no `\hline` ✓ ·
all 9 tables and 7 figures have notes ✓ (INV-1/INV-2) · abstract ~100 words ✓ (INV-5) ·
$Y_{it}$ and all symbols consistent ✓ (INV-7)

---

## Scope limits honored

- **Compilation:** no toolchain on the cluster; **no `latexmkrc` anywhere in the repo** (contrary
  to `MEMORY.md` / `working-paper-format.md`, which claim `UnionSpill-paper/latexmkrc` configures
  XeLaTeX); no `Draft.pdf`. No claim made either way; −20 not applied; static checks only.
- **Voice fidelity:** not scored — `.claude/references/personal-style-guide.md` is an unfilled
  template. No standard invented.
- **INV-22:** no `quality_reports/claim_source_map*` exists. Not scored (category 2 excluded in
  standalone), but flagged: `/paper-review --all` or Peer Review entry applies −15. Given all 17
  numbers traced by hand, the map is bookkeeping, not discovery.
- **No files edited.**

---

## Pipeline defect found by this run (not a paper issue)

`skills/paper-review/SKILL.md` tells the writer-critic, coder-critic, and strategist-critic to
save their own reports. Per `.claude/rules/agents.md` and the agent definitions, those critics are
read-only (Read/Grep/Glob) and have no Write tool. Upstream clo-author has the same inconsistency.
Report-saving must be done by the orchestrator (the skill invoker), not the critic. Until the SKILL
is amended, critic reports arrive inline and must be persisted by hand or they are lost.
