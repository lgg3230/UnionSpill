# Draft Review — Consolidated Issue List

**Paper:** Union Spillovers (de Azevedo-Gomes & Neri)
**Snapshot reviewed:** `quality_reports/draft_snapshots/Draft_2026-08-03_87f13b2.tex` (Overleaf commit `87f13b2`)
**Date:** 2026-08-03
**Reviewers:** strategist-critic (62/100, MAJOR ISSUES) · writer-critic (56/100; 61 with house-style waiver) · verifier (FAIL)

Items marked **[V]** were independently verified against the data, code, or logs — not taken on a reviewer's word.

---

## A. BLOCKING — the paper does not compile cleanly

The committed `Draft.pdf` renders, but the log carries **62 errors, 6 warnings, 2 undefined**. **[V]**

| # | Issue | Location | Fix |
|---|---|---|---|
| A1 | `tablenotes` body text before any `\item` → `! LaTeX Error: Something's wrong--perhaps a missing \item` (×2) | Draft.tex L332–334 (`fig:dir_lw`), L429–431 (`fig:spill_lw`) | Insert `\item` before `\textit{Notes:}`, matching the correct pattern at L247–250 **[V]** |
| A2 | `S` column type used but `siunitx` never loaded → 60 × `! Package array Error: Illegal pream-token (S)`. Table A8 silently loses decimal alignment and renders negatives as short hyphens instead of `$-$` | Draft.tex L1097; `Packages/lgag_eesp-paper.sty:60` has `%\usepackage{siunitx}` commented out | Uncomment line 60, or convert Table A8 to `c` columns with `$-$` **[V]** |
| A3 | `abowd1999` renders as undefined citation — key exists in `bib.bib` but is cited only inside the `bibunit` (Data Appendix), whose `bu1.bbl` was never regenerated | Draft.tex L1446 | Run `bibtex bu1` before final passes |
| A4 | `Label(s) may have changed. Rerun to get cross-references right` — committed PDF is one pass stale | — | Extra `pdflatex` pass |

---

## B. CRITICAL — substantive

### B1. The "40% attenuation" claim is quantitatively inconsistent with the paper's own spillover estimate **[V]**

Sits under the abstract, intro (L104), §4.1 (L340), and conclusion (L717).

The paper argues the Panel A vs Panel B gap is caused by spillovers contaminating Panel B's controls. Its own model implies that gap should equal `δ × E[C]/C_p90`. Measured directly on the estimation sample:

| Quantity | Value |
|---|---|
| Untreated establishments | 4,196 (matches Table A1) |
| mean `C_i` | 0.01241 |
| p90 `C_i` (the divisor) | 0.02926 |
| **mean/p90** | **0.424** |
| Implied gap `0.0065 × 0.424` | **0.0028** |
| Observed gap `0.0285 − 0.0202` | **0.0083** |

The spillover estimate explains **about one third** of the attenuation. Two thirds is unaccounted for. The sentence at L340 — "Since the directly treated sample is identical across specifications, the attenuation ... implies that connected untreated firms themselves experience positive wage spillovers" — is a non sequitur: holding the treated group fixed does not make the two control groups exchangeable. Panel B adds 2,265 controls that are systematically larger and better-networked (Table A1).

**Fix:** report `δ × E[C]/C_p90` against the observed 0.0083 and attribute the residual (composition is the leading candidate), or rewrite the abstract, L340 and L717 to claim only what the arithmetic supports. Caveat: 0.424 is the raw 2009 mean; the regression-weighted average will differ somewhat, so treat the factor of ~3 as indicative, not exact.

### B2. Adverse parallel-trends sensitivity evidence exists in the repo and is absent from the paper **[V]**

`Tables/honest_did/honest_did_breakdown.csv`:

| effect | outcome | breakdown M̄ | flag |
|---|---|---|---|
| spill | `lr_remdezr_h_w` (**headline**) | **0.4177** | `VERY FRAGILE` |
| spill | `lr_remdezr_w` | 0.7462 | `fragile` |
| direct | `lr_remdezr_h_w` | 1.6412 | ok |

Roth (2022) 80%-power slope for the spillover hourly pre-test: **0.00462/yr** (`pretrends_slopes.csv`). Over 2012–16 that accumulates to roughly double the estimated pooled effect of 0.0065 — a trend the two-coefficient pre-test would miss 20% of the time.

The paper's entire parallel-trends defense is "the placebo pre-trend tests are flat" (L413). `rambachan2023more` and `roth2022pretest` are both in `bib.bib` and cited **zero** times. **[V]** Switching the headline outcome from monthly to hourly moved to the strictly more fragile of the two.

**Fix:** restore a sensitivity subsection reporting breakdown values and power slopes; state plainly that the spillover wage result does not survive M̄ = 1.

### B3. The continuous-dose estimand is asserted, not identified **[V]**

L409 interprets `δ` as "the effect of moving from zero connectivity to the 90th percentile" — a **level** contrast. L413 assumes only weak conditional parallel trends, which identifies a weighted average of causal *response* (slope) parameters, not that level. Every ratio in the paper (0.23, 0.19, "one-quarter as much") is built on the level reading.

`Callaway2023` (Callaway, Goodman-Bacon & Sant'Anna, *DiD with a Continuous Treatment*) is in `bib.bib`, cited zero times, **and its entry is malformed — no `year` field, no venue, so it will not render.** **[V]**

The project's own linearity evidence (`Programs/conn_margins/linearity_did_fd.do`; all outcomes fail to reject linearity) — exactly the defense the level interpretation needs — appears nowhere in the draft.

**Fix:** state strong parallel trends explicitly, cite and repair `Callaway2023`, and move the binstest linearity results into the robustness section.

---

## C. HIGH — main text contradicts the new Data Appendix

The merged Data Appendix disagrees with the body in four places.

| # | Issue | Locations |
|---|---|---|
| C1 | **Connectivity divisor.** Eqs (1)–(2) use a fixed `1/4 Σ`; appendix L1454–56 says the average is taken "over the pairs in which it does appear rather than over four." Different estimators — if the appendix is right, the printed equations are wrong | L229, L261 vs L1454 |
| C2 | **Clause pre-periods.** Main text L302 reads as one pre-period ("its first CBA renewal after 2009"); appendix L1340 describes two. Two are required — all three clause tables report a placebo pre-trend | L302 vs L1340 |
| C3 | **Sample restriction 3.** Appendix requires an agreement "filed on or after 1 Jan 2012 that was in force at the end of 2012"; L208 defines untreated as having no active CBA on 25 Sept 2012. As written, every untreated establishment must have filed in a 14-week post-reform window. Main text L205 states it far more loosely. This is also **conditioning on a post-treatment outcome** | L205, L208 vs L1325 |
| C4 | **Spell-selection unit.** L1278 says "one spell per worker per year"; L1358 and L632 say "per worker-establishment pair." The first is wrong | L1278 |

---

## D. HIGH — inference

| # | Issue | Detail |
|---|---|---|
| D1 | **Clustering is at the wrong level.** SEs cluster on establishment, but the paper's own Appendix §C.1.2 says agreements are signed at the **8-digit company** level and headquarters negotiate for subsidiaries. Treatment is assigned at the agreement level. Spillover t = 2.83; a modest correction puts it at the 5% boundary | All tables |
| D2 | **No multiple-testing control across ~25 outcomes.** Table A8's tenure equality test (p = 0.010) is the sole significant result among 6 tests and is elevated to an abstract claim. Bonferroni over that family is 0.0083 — it does not survive | Table A8, abstract |
| D3 | **Missing per-worker-flow data silently pooled into the bottom quartile.** `3012_pct_tfpw.do:216`: `replace totalflows_pw_pre_07_114 = 0 if missing(...)`. Undisclosed in every table note, and contrary to the project's own no-zero-fill rule. The zero-connectivity controls are exactly the small, low-flow firms most likely to be missing **[V]** | Code |
| D4 | **Nulls over-read.** Employment spillover 0.0009 (0.0081) → CI ≈ [−0.015, +0.017]; the upper bound is 2.6× the wage effect. Cannot say employment is "unaffected." Clause-count null has a pre-trend (0.3256) 14× the post estimate, yet carries the "no union mediation" claim | Abstract, L415, L627 |
| D5 | **Quit-rate footnote uses the wrong benchmark.** Post −0.0027* vs pre-trend −0.0072** — same direction, 2.7× larger. The footnote compares the estimate to the pre-treatment *mean*, not the pre-trend, then uses the result substantively at L627 | L627 |
| D6 | **Table 3 col (7) treats estimated Lagos weights as known**, with a pretest (insignificant subgroups zeroed). The reported SE understates uncertainty, so "rule out gains above 0.2%" is not supported at the stated precision | L555 |
| D7 | **2012 coded as post** despite a 25 September ruling and December outcomes — roughly one quarter of exposure **[V]** | `3012_pct_tfpw.do:114` |

---

## E. MEDIUM — design validity

| # | Issue |
|---|---|
| E1 | **SUTVA invoked then violated.** The paper's premise is that connected untreated firms are contaminated controls; it then assumes the `C_i = 0` group is clean, though those firms connect to *other* untreated firms that connect to treated ones. Second-degree exposure never mentioned |
| E2 | **`C_i = 0` may measure firm size, not exposure.** Zero-connectivity controls average 23.3 employees vs 143.4 treated, and 9.7 network partners vs 47.6. For a 23-worker firm, observing zero treated flows is largely a small-sample event |
| E3 | **Connectivity window overlaps the outcome pre-period.** Two of four flow pairs (2009–10, 2010–11) come from the same establishment-years that produce the pre-trend test, so the test has no power against reverse causality |
| E4 | **Magnitude unaddressed.** p90 exposure ≈ 3% of workforce flows; treated firms raised wages 2.8%. Naive incidence gives ≈0.08%; the estimate is 0.65% — 8× larger, implying 23% pass-through from a 3% overlap. Not fatal (consistent with `C_i` being a noisy proxy) but never stated |
| E5 | **Tenure horse-race has an untested alternative.** Short-tenure flows are ~5× larger (0.5208 vs 0.1083), so long-tenure connectivity may simply be the cleaner signal of durable competitive overlap — predicting the same pattern with no replacement-cost content |
| E6 | **Survival conditioning** (balanced panel through 2016) not diagnosed |
| E7 | **Borusyak–Hull `μ_i`** assumes industry × negotiation-month exhausts predictable treatment variation; Table A1 shows treated firms are much larger, so size likely predicts treatment within cells |

---

## F. MEDIUM — presentation and reconciliation

| # | Issue |
|---|---|
| F1 | **Table notes contradict the estimating equation.** Clause regressions are CBA-period indexed but Tables 1, 2 and 3 notes describe "2012–2016" and "2009–2010 relative to 2011." Column (4) has no such years |
| F2 | **Establishment counts don't reconcile.** Table A1 implies 14,207 / 16,472 / 4,196; tables report 14,136 / 16,398 / 4,084. The clause column has *more* establishments than the wage column despite far fewer observations |
| F3 | **Clause-type effects don't sum to the total** (0.0312 vs 0.0227, a 37% gap) while L550 claims no offsetting movements. Likely outcome-specific pre-treatment bins — needs a note |
| F4 | **`$C_i$` denotes two different quantities** — raw in eq. (2) and Table A1, normalized in eq. (4) and L409 |
| F5 | **Data Appendix is orphaned.** `app:sample` and `app:dictionary` are never referenced from the main text |
| F6 | **Section 3 duplicated** in the appendix in six passages, including a verbatim URL footnote |
| F7 | **Rows labelled "%" report proportions** — "% Male = 0.621". `tab:layer_desc_full` uses true percentages, so the paper is inconsistent with itself |
| F8 | **Unflagged significant pre-trends** in `tab:spill_clause_decomp` col (3) (0.2268*) and `tab:group_specs` Panel C col (3) (0.0048*), while turnover gets a footnote |
| F9 | **Estimand never named** in either identification paragraph |
| F10 | **Six orphan numeric claims** with no table, figure, or citation: R² = 0.22 (L240), "only half share an industry–microregion cell" (L240), "91% share a union" (L546), "more than six thousand unions" (L162), "membership ≈15%" (L162), "~3% of workforce" (L409) |
| F11 | **No claim-source map** (`quality_reports/claim_source_map_*.md` absent) — INV-22. Consequence: cannot tell from the paper whether Table 4's residuals are the age-only or age+tenure Mincer spec |

---

## G. LOW — copy edits

- **Em-dashes in prose** (house style violation): L129, L201, L299 (two literal Unicode em-dashes)
- **Typos:** L250 missing period ("regressions Filled red markers"); L1278 "tiest" → "ties"; L1297 "web-scrapping" → "web-scraping"; L1265 malformed enumeration; L1276 "active in December 31" → "on"
- **Editorial leftovers to delete:** L1188 `% VERIFY:` comment; L1450 stale merge instruction; L69 commented-out abstract saying "one-fifth" (contradicts the live "one-quarter"); L771/L804 commented `threeparttable`; L890/L987 stray `\footnotesize`; L141–143 red to-dos
- **L679** hard-codes "equation (2)" instead of `\ref{eq:conn}`
- **Advisory:** `\toprule\toprule` doubled in all 12 tables; four float placement specifiers; three multi-line-header mechanisms; `subcaption` loaded twice
- **INV-4 conflict:** L58 comments "(100 words, AEA)" but all 12 tables carry significance stars, which AEA style prohibits

---

## H. Format deviations (waivable)

The paper uses a coherent house preamble that predates the project format rule: `natbib`/`bibtex` rather than `biblatex`/`biber`, `hyperref` loaded 22nd rather than second-to-last, no `cleveref`, no `microtype`, `\setstretch{1.4}` rather than `\doublespacing`, JEL/keywords inside the abstract environment. Compliant on `booktabs`, `threeparttable`, `fancyhdr`, 1in geometry, 12pt article. Flagged for a waiver decision rather than treated as defects.

---

## What is verified correct

- **All 27 headline numbers in the prose match their tables exactly** (INV-11 satisfied). Independently, the draft's tables now agree cell-for-cell with the replication document, and every replication number reproduces byte-identically from re-runnable code (48/48 pipeline outputs re-run this session). **[V]**
- Abstract exactly 100 words (INV-5); JEL + keywords present (INV-6); zero `\hline` and zero vertical rules (INV-3); all 66 `\ref` targets resolve, no multiply-defined labels; all 61 cite keys exist in `bib.bib`; all 13 referenced figures exist; every table and figure carries notes (INV-1, INV-2)
- No AI-writing tells; prose is dry and varied
- **The stacked Panel A = Panel B equality test is implemented correctly** — fully saturated in the copy indicator, clustered so an establishment in both copies forms one cluster. The `Weesie (1999)` / `Wooldridge (2010 §7.3)` citations are apt
- **The Borusyak–Hull counterfactual-exposure exercise is the right tool, correctly framed** — control function over recentering, with the correct justification
- **§3's defense of the connectivity measure is genuinely careful** and is where the paper most clearly earns its place
- **Coefficient stability is real**: direct 0.0262–0.0298 across six specifications, spillover 0.0061–0.0073, plus five union-control variants

---

## Suggested fix order

1. **A1, A2, A3** — restore a clean build and correct Table A8 formatting (three one-liners)
2. **B1** — reconcile or rewrite the 40% claim; it drives the abstract and conclusion
3. **B2** — restore the honest-DiD section; the results already exist
4. **B3, C1** — the estimand statement and the divisor discrepancy; C1 is the only finding that changes a printed estimator
5. **C2, C3, C4, F1** — appendix/main-text reconciliation and table notes
6. **D1, D2, D3** — re-cluster, Romano–Wolf, un-zero-fill the missing bin
7. **D4, D5** — restate nulls with CIs; fix the quit-rate footnote
8. **F4, F5, F9** — notation, appendix pointers, estimand naming
9. **G** — copy-edit pass
10. **F11** — build the claim-source map

Neither critic recommends re-drafting any section. Every finding is a targeted, localized fix; the argument, evidence, and numbers are sound.
