# Section 6.2 (Within-Firm) — Code Check of `Luis_og` vs. Paper Tables A7 & A8

*Guilherme — prepared by Claude, 9 July 2026. All numbers independently re-estimated; see "Method" at the end.*

## TL;DR

1. **The code Luis handed over does not produce the tables in the paper.** Both published tables are reproducible from the bundled *data*, but only after undoing specification changes that are hard-coded in the bundled *scripts*. The bundled `output/*.csv` (from Luis's 13 May 2026 cluster run of this exact package) confirm this: they disagree with the published numbers.
2. **Table A7** (group-level spillovers): the published table is the **full untreated balanced-panel sample with no group×year FE**. The bundled `01a_layer_spillover.do` instead (a) restricts to firms with **above-median pre-treatment employment** and (b) adds **group×year FE**. With those two changes undone, I match every published coefficient, SE, placebo, N, and firm count to the 4th decimal.
3. **Table A8** (low- vs high-skill horse race): the published table uses **firm(-cell) FE + year FE + quartile-bin×year controls only**. The bundled `02a_horse_race_edu2.do` additionally includes **industry×year, microregion×year, and negotiation-month×year FE**. Dropping those reproduces every published number exactly.
4. **That last difference is substantively important**: the paper's main Table 2 baseline *does* include industry/microregion/negotiation-month×year FE. Adding them to the A8 regressions (as the bundled code does) makes the two headline results vanish — High-Skill wage 0.0066** → 0.0019 (n.s.); Low-Skill employment −0.0209** → −0.0100 (n.s.). It is the fixed effects, not the associated sample change, that absorb the effect.
5. **The published "Groups × firms" row in Table A7 is wrong** (an undercount) due to a sort-order bug in the do-file's cell counting. Correct: 7,160 (edu, within), published: 6,273. Estimates are unaffected — it's a display statistic only.

---

## 1. Reproduction map

| Published cell | Published value | Bundled code output | Reproduced when |
|---|---|---|---|
| A7 within-firm wage, edu (col 2) | −0.0023 (0.0044), N=52,458, 3,580 firms | −0.0129* (0.0069), N=31,670, 2,048 firms | full sample, **no** group×year FE |
| A7 within-firm emp, edu (col 5) | −0.0023 (0.0108) | −0.0129 (0.0152) | same |
| A7 overall wage, edu (col 3) | 0.0029 (0.0025), N=59,391 | −0.0004 (0.0045), N=32,493 | same |
| A7 within-firm wage, gender | 0.0001 (0.0030), N=55,358 | −0.0004 (0.0049), N=32,634 | same |
| A8 wage, No-HS col: Low / High | −0.0015 / 0.0062 | 0.0003 / 0.0013 | **drop** ind./micro/mode×year FE |
| A8 wage, HS+ col: High | 0.0066** (0.0028) | 0.0019 (0.0029) | same |
| A8 wage, firm col: High | 0.0058** (0.0026), N=29,095 | 0.0022 (0.0023), N=28,227 | same |
| A8 emp, No-HS col: Low | −0.0209** (0.0093) | −0.0100 (0.0107) | same |

Under the "reproduced when" settings, **every** coefficient, SE, placebo, N, firm count in A7 (both panels) and A8 (all 6 columns) matches to 4 decimals. So: same data, unambiguous identification of what changed. Note the paper's Table A7 column (1)/(4) "Firm-level" is just the Table 2 baseline (0.0051**) re-printed; it is not produced by this package (the package's `firmrestr` spec is a different, layer-restricted exercise that appears nowhere in the paper).

**Action item:** ask Luis which is intended. Either the paper tables are stale relative to his current preferred specs (abvmed cut, group×year FE, baseline-consistent FE in the horse race), or the handed-over package contains post-paper explorations that shouldn't be in the replication kit. Right now the "replication package" does not replicate the paper.

## 2. Is the published specification the right one? (controls)

**Table A7, within-firm columns — missing group×year FE.** The published within-firm spec has firm×year FE but *no group×year FE*. Within a firm-year, the more-connected group is systematically the high-skill / male group (Table A6: connectivity 0.0148 vs 0.0095 by education). So any economy-wide group-specific post-2012 trend (e.g., Brazil's large minimum-wage increases compressing the no-HS/HS wage gap) loads directly on the coefficient. Luis's newer code adds group×year FE, which I think is clearly right. Reassuringly, the headline *wage* conclusion survives: −0.0023 → −0.0041 (se 0.0043) for education, 0.0001 → −0.0006 for gender — still ≈0. But **within-firm employment for education flips to marginally significant negative with group×year FE on the full sample: −0.0200 (0.0099)**, with a mirror-image placebo (+0.0195). The paper currently claims "employment shows no within-firm response either" — that claim is spec-sensitive.

**Table A8 — less saturated than the paper's own baseline.** Table 2's notes say all specifications include establishment FE and year FE interacted with industry, microregion, and negotiation-month. Table A8 omits those (its notes honestly say "firm and year fixed effects and group-level controls", but a reader will assume baseline-consistent controls). A referee who adds the baseline FE will kill both headline A8 results. My decomposition shows it is not the singleton-induced sample change: running the published spec on the FE-restricted sample gives −0.0204 (0.0093) — essentially unchanged — while adding the FE gives −0.0100 (0.0107). The A8 effects are identified off cross-industry/region/negotiation-month variation in group connectivity, exactly the variation the baseline design says it doesn't want to use.

**Which FE does the killing** (`run_a8_source.R`, adding one block at a time to the published spec): for the High-Skill *wage* result (0.0066**), industry×year alone halves it (→0.0033) and microregion×year alone takes it to 0.0040; negotiation-month×year is innocuous (0.0058). For the Low-Skill *employment* result (−0.0209**), microregion×year is the main absorber (→ −0.0137; and it cuts the High-Skill employment coefficient +0.0144 → +0.0055), industry×year barely matters. Consistent with this, the group connectivity measures have a large geographic/industry footprint: microregion FE alone explain 19–21% of the cross-firm variance in c_no_hs/c_has_hs, industry 7–10%, all three ~27–30%.

**Mean-reversion / pre-trend warning on A8** (consistent with the concern already flagged for the connectivity DiD design). The published A8 no-HS column shows placebo coefficients that mirror the estimated effects: employment pre +0.0133 (Low) / −0.0154* (High) vs. post −0.0209** / +0.0144*; wage pre −0.0080* (High). The event study makes it stark — 2009 coefficients are +0.0216 (Low) and −0.0214 (High), almost exactly minus the post effects, and the "effect" grows monotonically to 2016 like a continuing trend. With only two pre-years (2009, 2010 vs. ref 2011), a reversion pattern and a causal effect are hard to distinguish. I would be cautious building the "firms shed low-skill workers instead of raising their wages" narrative on this cell.

**Controls otherwise look sensible.** Quartile bins of pre-treatment outcome, group size, and group flows interacted with year FE are a reasonable, standard conditioning set; the layer-level composition variables in the data (mean hours, age, share female, share fixed-term) are correctly *not* included as controls (they're post-treatment outcomes — bad controls).

## 3. Clustering

Everything is clustered at the firm (`identificad`) level. This is appropriate and, for the within-firm specs, the conservative choice (it allows arbitrary correlation across the two group cells and over time within a firm). I checked the two obvious alternatives on the published A8 firm-level wage spec:

- cluster by microregion (316 clusters): High = 0.0058 (0.0025) vs. firm-clustered (0.0026)
- cluster by industry (228 clusters): (0.0028)

Essentially unchanged, so there is no hidden fragility along observable dimensions. Two things you could mention if a referee pushes: (i) connectivity is a network-exposure regressor, so a design-based inference argument (Adão–Kolesár–Morales / Borusyak–Hull–Jaggi style) is the theoretically right benchmark; (ii) firms connected to the *same* treated establishments share exposure shocks — clustering by dominant treated-partner or by labor-market cell would be the stress test. Given (d) above I doubt it changes anything.

## 4. Code quirks worth fixing (none affect estimates except as noted)

1. **`n_cells` sort bug (affects the published table).** In `01a_layer_spillover.do` (~line 328) and `03a`: `bys identificad layer_id (in_samp): gen cell_first = (_n==1 & in_samp==1)`. Ascending sort puts out-of-sample rows first, so a cell is counted only if *all* its rows are in the estimation sample. Published "Groups × firms" 6,273 (edu, within) matches this buggy count exactly; the correct count is 7,160 (= 2 × 3,580, as it must be, since singleton dropping removes one-group firm-years). Fix: `(_n==_N & in_samp==1)`, or just count `egen tag(identificad layer_id) if in_samp`.
2. **`in_layer_balanced_panel` is computed and never used**, while the Section 2i comment claims the restricted set is "layer-balanced panel AND above-median". The actual regression conditions only on the firm-level `in_balanced_panel`. Dead code + misleading comment — decide which sample you mean.
3. **Inconsistent P90 anchors within the bundle**: layer connectivity is scaled to the P90 of the above-median subsample, while the `firmrestr` firm connectivity is scaled to the full-sample P90. If you keep the abvmed variant, anchor both the same way.
4. **"Scaled so that 1 = the 90th percentile" (table notes) is imprecise**: both group measures are divided by the *pooled* P90 of group-level connectivity across the two groups (P90: pooled 0.0312, no-HS 0.0210, HS+ 0.0378). Pooled scaling is actually the right choice for a horse race (keeps the two coefficients per-unit-comparable), but the note should say so.
5. **Bin construction details**: quartile bins are computed on year-2009 balanced-panel observations *including treated firms*, and cells with no 2009 observation are assigned to bin 0 rather than a separate "missing" bin. Both harmless (they're absorbed controls), but a separate missing bin would be cleaner.
6. **Placebo convention**: `placebo_year = (year < 2011)` on the ≤2011 sample estimates 2009–10 *relative to* 2011, so a positive placebo means outcomes were *higher* before 2011 (i.e., a *declining* pre-path into the reference year). The table note states this correctly, but keep the sign convention in mind when reading "mirror image" patterns.
7. **README drift**: README says Exercise 1's within-firm spec is the "main spec" and documents the abvmed sample, with no hint that the paper's table is the full sample. Whoever picks this up next will run the wrong thing (as the May 13 cluster run did).

## 5. Suggestions / brainstorming

- **The corrected A8 is coherent with Table 2 — present it via sum and difference** (`run_a8_sum.R`). Firm connectivity is nearly spanned by the two group measures (weights 0.25/0.58, R²=0.83; scale anchors comparable, pooled-group P90 0.0312 vs firm P90 0.0293), so the horse-race coefficients are *partial* effects and the comparable object to the 0.0051 baseline is their **sum**: 0.0029 + 0.0022 = **0.0050** on the A8 sample with baseline FE. Nothing is lost by splitting connectivity — the total effect is preserved, just divided across two correlated (ρ=0.45), individually noisy components. A corrected A8 should therefore report (i) the sum ≈ firm-level effect (coherence with Table 2) and (ii) the test of β_Low = β_High (the actual asymmetry question, which does not reject). The defensible claim becomes "the wage response cannot be attributed to a particular skill segment," which supports rather than undermines the firm-wide wage-setting message.
- **The A8 sample itself carries a weaker headline effect** (`run_t2_sample.R`). Re-running the Table 2 baseline (single firm-level connectivity, full FE structure) restricted to the A8 sample (firms with both education groups measurable, 3,546 vs 4,085 firms) gives a wage effect of **0.0036 (0.0026)** — ~30% below the 0.0051** headline and insignificant (placebo clean: 0.0005). Employment: 0.0057 (0.0109), null on both samples. Validation: the same code on the full sample reproduces Table 2 exactly (0.0051, 0.0023, N=32,498, F=4,085). Implication: any corrected A8 should benchmark against 0.0036 (its own-sample total effect), and the case for a stand-alone skill-decomposition subsection weakens further — it would dissect an aggregate effect that is not itself significant on that subsample.
- **Reconcile versions first.** Decide, with Luis, which spec is *the* spec for A7/A8, then regenerate tables and notes from one code path. My take: A7 with group×year FE (full sample) is the more defensible within-firm spec, and it *strengthens* the wage message; report abvmed as robustness. For A8, either add the baseline FE and accept the null (which actually reinforces Section 6.2's broader "firms don't differentiate below the firm level" message), or keep the sparse spec but pre-empt the referee: show the FE-saturated version and explain what variation identifies each.
- **If the A8 asymmetry story stays, it needs shoring up**: the effect is identified across industries/regions, has mirror-image placebos, and a trend-like event study. Options: randomization-inference on connectivity permutations within industry×region cells; matching on pre-*levels* (not just quartile bins); showing 2007–2008 outcomes (you have flows from 2007, and RAIS goes back further) to extend the pre-period.
- **Within-firm employment (edu, group×year FE) at −0.0200 (0.0099)** with mirror placebo +0.0195: same reversion signature. Worth an event-study figure before deciding whether to mention it.
- **The within-firm null is your friend.** It's consistent across partitions, specs, and samples (wage estimates range −0.004 to +0.000, always n.s.). The Section 6.2 interpretation ("measure exposure at the level where wages are set") is well-supported. Consider adding the occ4 partition (code exercises 3–4 already exist) to show the null isn't an artifact of coarse two-group partitions — managers vs. low-skill within a firm is where you'd most expect differentiated outside options.
- **Small framing point**: ~90% of firms have both groups but only 29–34% of connectivity variance is within-firm (Table A6). The within-firm design throws away ~2/3 of the variation, so col (2)'s larger SEs are expected; the paper's Column (3) discussion already handles this nicely.

## Method (what was actually verified, and how)

Stata's local license has expired (13 Jun 2026), so I re-implemented the full pipeline — sample construction, Stata-convention percentiles (`summarize, detail` type-2), `egen cut, group(4)` bins, reghdfe-style iterative singleton dropping, and cluster-SE small-sample conventions — in R (`fixest`), in `gui_check/scripts/`:

- `prep_layer.R` — data construction shared by all runs
- `run_spill2.R` — Table A7 variants (abvmed × group×year-FE grid)
- `run_horse.R` — Table A8 variants (FE set × scaling grid)
- `run_diag.R` — cell-count bug check, event studies, collinearity, clustering
- `run_fe_vs_sample.R` — FE-vs-sample decomposition of the A8 sensitivity

Validation: the R pipeline reproduces Luis's bundled Stata CSV outputs (his 13 May 2026 cluster run of this package) **exactly** — every coefficient, SE, placebo, N, firm count to 4 decimals, for both exercises. The same pipeline with the spec changes described above reproduces the published tables with the same exactness. corr(c_no_hs, c_has_hs) = 0.45 across the 3,654 horse-race firms, so multicollinearity is not a concern for A8.
