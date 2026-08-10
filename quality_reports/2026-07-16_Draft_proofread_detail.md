# Proofread Report (line-level) — UnionSpill (`Draft.tex`)

**Date:** 2026-07-16
**Agent:** writer-critic (standalone `--proofread`, via `/paper-review`)
**Score: 74/100** — proofread-only (categories 4, 5, 6, 8). Not comparable to the full 8-category review.
**Companion:** `2026-07-16_Draft_proofread_report.md` (comprehensive, 52/100), `2026-07-16_Draft_strategy_review.md`

> **Provenance.** Critic is read-only; report returned inline and persisted by the orchestrator.
> **Orchestrator verification** of the two highest-stakes claims is annotated inline as **[VERIFIED]**.

---

## HEADLINE: one confirmed data error

### V12 — `tab:turnover` Panel A "Log Hours" mean is the **spillover** panel's value
**[VERIFIED — orchestrator traced to source CSVs, 2026-07-16]**

The critic flagged `7.2869` appearing identically at line 799 (Panel A, 14,137 establishments) and
line 811 (Panel B, 4,088 establishments) as "not credible across disjoint samples". Confirmed, and
the mechanism is now pinned:

| column | draft Panel A | `results_direct_panelA_turnover.csv` | draft Panel B | `results_spill_turnover.csv` |
|---|---:|---:|---:|---:|
| **Log Hours** | **7.2869** | **6.1516** ← **MISMATCH** | 7.2869 | 7.2869 ✓ |
| Retention | 0.7473 | 0.7473 ✓ | 0.7317 | 0.7317 ✓ |
| Hiring | 0.5370 | 0.5370 ✓ | 0.5812 | 0.5812 ✓ |
| Sep. | 0.4736 | 0.4736 ✓ | 0.5194 | 0.5194 ✓ |
| Quit | 0.0976 | 0.0976 ✓ | 0.1182 | 0.1182 ✓ |
| Layoff | 0.2299 | 0.2299 ✓ | 0.2600 | 0.2600 ✓ |
| Churn | 1.0106 | 1.0106 ✓ | 1.1006 | 1.1006 ✓ |

**13 of 14 cells are correct. Exactly one is wrong:** Panel A Log Hours should be **6.1516**; the
printed 7.2869 is Panel B's (spillover) value. Error magnitude: 1.14 log points ≈ 3.1× in levels.

**Root cause:** `5210_table_turnover_latex.py` emits Panel A/B/C as three *direct* specifications
(zero-conn / ≤1% conn / all untreated — lines 287–301). The draft's `tab:turnover` instead pairs
**Panel A = direct** with **Panel B = spillover**, a layout the generator does not produce. The table
was therefore hand-assembled from `results_direct_panelA_turnover.csv` + `results_spill_turnover.csv`,
and one cell picked up the wrong panel's number. Violates INV-11.

**Fix:** line 799, `7.2869` → `6.1516`. Then extend the generator to emit the direct+spillover layout
so the table stops being hand-assembled.

---

## 1. TABLE NOTES CONSISTENCY

### 1.0 Ground truth from the code
**[VERIFIED — orchestrator confirmed the absorb string, 2026-07-16]**

`4082_turnover.do:300-301,360`, `4092_composition.do:251-252,311`,
`4112_mincer.do:239-240,304`:

```stata
local base_fe    "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local extra_year "ib0.totalflows_pw_pre_07_114#i.year"
local absorb "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"
```

**Canonical baseline: establishment FE + year × {2-digit industry, negotiation month, microregion}
+ year × quartile bins of {pre-treatment OUTCOME, firm size, per-worker flows}.** The outcome bins
are present in *every* specification, including turnover and composition.

### 1.1 Verdicts

- **V1 — lines 821 and 866 are WRONG; lines 364/441/567/899 are RIGHT.** [VERIFIED] Notes at 821/866
  say "quartile-bin controls for pre-treatment **per-worker flows and establishment size**", omitting
  the outcome bins that `4082_turnover.do:360` and `4092_composition.do:311` both
  include. Line 364 correctly says "quartile bins of pre-treatment firm size, per-worker flows,
  **and the outcome**". **Fix:** adopt T1/T2's exact sentence at 821 and 866 so all eight notes are
  byte-identical.
- **V2 — `% VERIFY` at line 821: RESOLVED — YES.** Outcome bins are included, exactly as in eq. (3). Delete the comment.
- **V3 — `% VERIFY` at line 866: RESOLVED — YES.** Same. Delete the comment.
- **V4 — `% VERIFY` at line 1087 ("negotiation month: start date vs filing date"): RESOLVED — NEITHER.**
  `Programs/1030_clean_cba.do:337` states: *"negotiation month (paper text) = base_month (lagos dataset)"*;
  lines 340–341 take `mode(base_month), minmode`. So negotiation month = **the establishment's modal
  `base_month` ("data-base" month) from the Lagos CBA registry, ties broken to the earliest month** —
  derived from neither filing date nor contract start date.
  ⚠️ The repo holds three inconsistent constructions: `minmode` (`1030_clean_cba.do:341`, live path),
  `maxmode` (`Programs_2025.05.03/03_clean_cba.do:289`), `egen max()` (`Programs_2025.05.03/1040_merge_cba_rais.do:128`).
- **V5 — line 988's control description is WRONG for the employment columns.**
  `layer_connectivity/07_within_firm/01_within_firm_estimates.do:297-298`: group **wage** bins enter
  only when the outcome is wages; columns (5)–(6) (Log Employment) have none.
  **Fix:** "quartile bins of the pre-treatment **group outcome**, group employment, and group per-worker flows".
- **V6 — Significance stars: CONSISTENT across all 10 regression tables** (identical string at 364, 441,
  568, 614, 775, 822, 867, 899, 988, 1042). **Sole deviation: line 1130** uses math-mode superscripts.
- **V7 — Clustering: CONSISTENT in all 10.** Deviations: line 315 "establishment**-**level" (spurious
  hyphen, only instance); line 233 no vcov stated despite reporting 95% CIs; line 1130 no vcov despite stars.
- **V8 — Sample naming: 3 variants** for `s_spill` (`lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1`):
  "the full sample of untreated establishments" (7×), "untreated, balanced-panel establishments" (988, the
  only complete one), "the sample of untreated establishments" (1042), "untreated **firms**" (374).
- **V9 — Zero-connectivity control group: 4 variants** (364 / 775 / 821,866,899 / 730 "$C_i=0$").
- **V10 — Notes container: 4 `threeparttable` vs 16 `minipage` at 5 different widths.** INV-1 met in
  substance; mechanism not uniform. Lines 699/732 have `threeparttable` commented out — half-migrated float.
- **V11 — `\%` headers carry proportions, not percentages.** Lines 712–714 (`\% High School Degree` → 0.73),
  838 (`\% Male` → 0.5859) vs lines 921–923 which use true percentages (85.8\%). Rescale or relabel to "Share".
- **V13 — Row label differs between panels of the same table:** line 799 `Mean (2009--2011)` vs line 811 `Mean`.
  (Generator emits `Mean (2009--2011)` for both — further evidence of hand-assembly.)
- **V14 — `tab:group_specs` col (1) N contradicts the table it cites.** Line 988 says cols (1)/(4) reproduce
  `tab:spillover`; line 952 reports 32,498 / 4,085 while `tab:spill_main_4tf_out` reports 32,495 / 4,084.
  The 32,498/4,085 figures are the *residualized* sample. Coefficient matches; N does not.
- **V15 — Treatment definition stated slightly wrong in two places.** `1030_clean_cba.do:475`:
  `file_date_stata<=mdy(9,25,2012)`. Lines 190 and 364 say "filed **before** September 25, 2012" →
  should be "filed **on or before**".
- **V16 — Row-label drift:** `Establishments` (T1–T9) vs `Firms` (T11:954, T12:1015).
- **V17 — Interaction order reversed** in `tab:group_specs` (947, 949, 959, 961, 971, 973): `Connectivity $\times$ Post`
  vs `Post $\times$ Connectivity` everywhere else.
- **V18 — Minus signs:** `$-$` everywhere except bare ASCII `-` in `tab:horse_race` (1007, 1021, 1029, 1030).
- **V19 — Thousands separators:** `{,}` everywhere except plain commas in `tab:descriptive_stats` (708, 709,
  719, 720) and `tab:layer_desc_full` (917).

---

## 2. GRAMMAR AND TYPOS

### 2.1 Errors (must fix)

| Line | Issue | Fix |
|---|---|---|
| **56** | Abstract: "Wages increase…**and are larger** where competition runs through costlier-to-replace workers" — subject "Wages" governs "are larger", saying wage *levels* are larger; the paper means the *response* is larger | "…and the increases are larger where…" |
| **56** | "raise only wages, **by** one-fifth as much" — "one-fifth as much" is a ratio | "…raise only wages, one-fifth as much." |
| **107** | Broken antecedent: "whether **the more-exposed group** experiences larger wage gains than its coworkers. **They do not**" | "It does not:" |
| **112** | `\cite{park2025betterlabor} provides` → renders "Park et al. (2025)" (3 authors) | "provide" |
| **118** | `\cite{fortin2021labor}` "**frames its** evidence… **it acknowledges**" → "Fortin et al. (2021)" | "frame their evidence… they acknowledge" |
| **503** | `\cite{derenoncourt2025thousands} documents` → "Derenoncourt et al. (2025)" (4 authors) | "document" |
| **180** | **Portuguese misspellings in a data-source heading:** `Relacão Anual de Informacões Sociais` — both missing cedillas | `Rela\c{c}ão Anual de Informa\c{c}ões Sociais`. Same at 1220 (commented) |
| **184** | Dangling modifier: "…agreements between unions and firms **extracted from** \textit{Sistema Mediador}" — reads as firms being extracted | "web-scraped information, extracted from \textit{Sistema Mediador}, on the universe of…" |
| **260** | Possessive "the **analysis'** control group" (CMOS 7.17) | "the control group" |
| **260, 520, 580** | Raw Unicode en-dashes | `--` |
| **474** | LaTeX quote bug: ``` ``breakdown value" ``` | ``` ``breakdown value'' ``` |
| **152** | "requires **parties** to renegotiate" | "requires **the** parties" |
| **156** | Restrictive `which`: "registry of CBA texts **which includes**" | "**that** includes" |
| **166** | "The timing of **when** unions first benefit" — redundant | "When unions first benefit… creates" |
| **447** | "these characteristics shape **firms' response**" | "firms' response**s**" |
| **479** | Non-word "**expectedly**" | "as expected" |
| **203** | "Neither **choice** has a principled **answer**" | "Neither question has a principled answer." |
| **92** | Ambiguous pronoun: "divide **it** by **its** workforce size" | "divide the count by the firm's workforce size" |
| **988** | Orphan `\ref{tab:spillover}` (known) | `tab:spill_main_4tf_out` |

### 2.2 Punctuation / LaTeX hygiene

- **220** comma outside quotes: ``` ``local industry'', ``` → ``` ``local industry,'' ```
- **73, 92, 116, 200, 203** `(e.g. \citealp{...})` triggers inter-sentence spacing → `e.g.,` or `e.g.\ `
  (author already uses `vs.\ ` at 358, 649 and `Avg.\ ` at 650, 916, 928)
- **272, 273, 313, 314, 381, 382** stray `\` + newline inside display math → injects spurious space in 3 equations
- **110** missing Oxford comma + broken parallelism
- **124, 200, 393** double spaces
- **616, 869** dead markup (`\footnotesize` after `\end{minipage}`)
- **699, 732** `threeparttable` commented out
- **455, 1161, 1167, 1108** math-mode wrapping of plain numbers (`$95\%$`) vs text mode elsewhere
- **387 / 580 / 220fn** `$\sim$3\%` vs "approximately 10\%" vs "approximately 0.22"

---

## 3. TERMINOLOGY AND CROSS-REFERENCE

- **3.1 — 26 missing non-breaking spaces.** `Table \ref` / `Figure \ref` / `Section \ref` at 124(×6), 220,
  240, 262, 264, 290, 295(×2), 322, 374, 378, 393(×3), 447, 472(×2), 630, 633, 640, 642. Roughly 50/50
  against the correct `~\ref`. **Line 378 worst:** `equation \ref{eq:dir_spec}` missing both tilde and
  parens (8 other equation refs use `equation~(\ref{...})`).
  *(Orchestrator's independent grep: `Table~\ref` 12 vs `Table \ref` 11; `Figure~\ref` 8 vs `Figure \ref` 6 — concurs.)*
- **3.2 — `\cite` (11×) vs `\citet` (15×)** render identically under natbib; standardize on `\citet`.
  **Line 458 is the only remaining `\citet` misused parenthetically** — all 64 citation calls checked.
  *(Orchestrator independently found line 493 opens a sentence with `\citep{freeman1981impact,...}` → should be `\citet`.)*
  Advisory: bib keys carry stale years (`bassier2022collective` → `year={2024}`; `jager2022substitutable` → `2024`);
  two transliterations of Jäger across keys.
- **3.3 — Hyphenation.** ⚠️ **`collectively-bargained` (8×) is WRONG; the single `collectively bargained`
  (line 56) is right** — CMOS 7.86: -ly adverbs are never hyphenated to a participle. Same for
  `demographically-similar` (220). `establishment-level` (315) sole error vs 12 correct. `fixed-effects` (277)
  sole error. `labor-market` (73, 114) vs `labor market` (~20). `industry-microregion` / `industry--microregion`
  / `industry $\times$ microregion` / `industry-by-negotiation-month` — 5 forms for related objects.
  ✅ **Correct and consistent, no action:** `zero-connectivity` / `zero connectivity`, `worker-flow` /
  `worker flows`, `outside-option` / `outside options` — all correctly split attributive vs noun.
- **3.4 — Capitalization.** Line 623 `\section{How do Firms Adjust?}` is the only sentence-case section →
  "How **Do** Firms Adjust?". Paragraph headings 654, 658 sentence-case outliers. Captions 935, 1115, 1137.
  Appendix headings 692 "Appendix: Tables" vs 1055 "Appendix Figures" (colon in one); both under `\appendix`
  so they render "A Appendix: Tables" — redundant. Line 686 hardcodes `\thefigure = A\arabic{figure}`, so
  appendix section **B** figures are still numbered A1–A6.
- **3.5 — Panel/column reference style.** "Panel A" (220, 240, 295, 472) vs "Panel (A)" (233, same object)
  vs "Panel~(a)" (1156…). Columns parenthesized in notes except line 775, which mixes both inside one note.
- **3.6 — Naming.** "Súmula 277" appears **once** (line 162), never in title/abstract/intro.
  *(Orchestrator note: this is correct academic practice — properly introduced at 162, "the reform" 36×
  thereafter. Flagged as advisory discoverability only, NOT a defect.)*
  Firm vs establishment (374 vs 441; 580 vs 613; row labels). Amenity outcome has 5 names.
- **3.7 — Tense.** Systematic split: direct effects past ("increased", 96, 295), spillover present
  ("experience", 98, 393), often adjacent. Pick present throughout.
- **3.8 — Number formatting.** Same spillover estimate at two precisions: 0.5\% (98) vs 0.51\% (393). Same
  direct estimate: 2.6\% (96, 295, 393) vs 2.62\% (642). **Line 580 "approximately 10\%"** — actual is
  32,495→28,714 = **11.6%**. Line 525 log points vs percent.
  ✅ Verified correct: 46.0% = 1,931/4,196; 4.9% = 1.5568/31.9; 0.19 = 0.0051/0.0262; 0.23 = 0.0066/0.0287;
  "four-fifths" = 0.0040/0.0051; "nearly half" = 0.0262/0.0178.
- **3.9 — Establishment counts don't reconcile with `tab:descriptive_stats`.** T5: 12,276 + 1,931 = **14,207**
  vs T1 Panel A's 14,134/14,137/14,176. T5: 12,276 + 4,196 = **16,472** vs T1 Panel B's 16,398/16,404/16,444.
  Plausibly non-missing-outcome attrition, but no note says so.
- **3.10 — Orphaned float.** **Figure A3 `fig:binscatter` (1116) is never referenced in the text.** With
  `flafter` + `placeins` active (12–13), an uncited float has no anchor. Also unreferenced labels:
  `sec:mediation` (485), `fig:distro_region` (1065), `fig:distro_industry` (1072), `fig:distro_month` (1079),
  `fig:honest_lw` (1178), `fig:rlwr_spill` (1143), `fig:rlwr_cf` (1150).
- **3.11 — Notation (INV-7).** ✅ `$Y_{it}$`, `$C_i$`, `$C_{ij}$`, `$\delta_k$`, `$\mu_i$`, `$\bar{M}$`
  consistent; no collisions. **Line 279 contradicts its own equation:** eq. (3) at 273 writes
  `\Gamma_k (X_i \times \mathds{1}_{t=k})`, line 279 writes "$X_i \times (\mathds{1}_{t=k})$".
  Three orderings of the interaction: `$\mu_i \times$ Post` (456/464), `Post $\times$ Connectivity` (tables),
  `Connectivity $\times$ Post` (group_specs).

---

## SCORE: 74/100

| Deduction | |
|---|---|
| Table notes factually wrong re: controls (821, 866, 988 — contradicted by code) | −8 |
| Numerical/traceability: Log Hours mean (799); group_specs N ≠ Table 2 N; "approximately 10\%" vs 11.6%; 0.5 vs 0.51; 2.6 vs 2.62 | −7 |
| Grammar: abstract subject (56), antecedent (107), 3× subject–verb (112, 118, 503), dangling modifier (184), Portuguese misspellings (180), possessive (260), +8 | −9 |
| LaTeX: quote bug (474), 3 raw en-dashes, stray `\`+EOL in 3 equations, `e.g.` spacing ×5, dead markup | −5 |
| Cross-reference: 26 missing `~`, `equation \ref` (378), `\citet` misuse (458), orphan Figure A3 | −4 |
| Consistency: containers, `\%` proportions, minus/separator drift, row labels, interaction order, capitalization, hyphenation, sample naming | −8 |

**What holds up:** star wording byte-identical across all 10 regression tables; clustering uniform in all 10;
`\toprule\toprule` / `\textit{Notes:}` uniform; no `\hline` (INV-3 ✅); every table and figure has a note
(INV-1/INV-2 ✅); abstract exactly 100 words (INV-5 ✅); notation internally consistent (INV-7 ✅); all
quantitative claims checkable against T1/T2/T5/T6 reconcile.

**Highest-value fixes, in order:**
1. **Line 799 `7.2869` → `6.1516`** (confirmed wrong; wrong panel's value)
2. **Lines 821, 866, 988 controls sentences** (confirmed wrong against the code)
3. Line 56 abstract "and are larger"
4. Lines 112 / 118 / 503 subject–verb
5. Line 180 "Relação / Informações"
