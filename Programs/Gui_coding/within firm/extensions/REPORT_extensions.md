---
title: "Group-Specific Connectivity: Measurement, Incidence, and Margins"
subtitle: "Extension analyses for Section 6.2 — Outside Options and Collective Bargaining Spillovers"
author: "Prepared for Guilherme Neri & Luis de Azevedo Gomes"
date: "July 2026"
geometry: margin=1in
fontsize: 11pt
header-includes:
  - \usepackage{booktabs}
  - \usepackage{float}
---

# Summary

This note reports six extension exercises built on the group-level ("layer") connectivity data underlying Section 6.2. Two findings materially change how the within-firm evidence should be read, one strengthens the paper's headline result, and three are informative nulls or data-quality verdicts.

1. **The within-firm identifying variation is mostly measurement noise.** The split-half reliability of the within-firm connectivity gap — computed from the four pre-period year-pair flow measures — is 0.00–0.17 (Pearson) across the five worker partitions — essentially zero for race, 0.06–0.08 for education, gender, and occupation, 0.17 for tenure, versus roughly 0.16–0.40 for the between-firm variation the headline estimate uses. A split-sample IV within firms fails (first-stage F $\approx$ 2). Consequence: Table A7's within-firm null cannot distinguish "firms do not tailor relative pay" from "group-specific exposure cannot be measured reliably at this grain." The claim in the text should be softened accordingly.
2. **A split-sample IV magnitude correction for the headline estimate was attempted and fails an economic admissibility check.** Instrumenting late pre-period firm connectivity with the early pre-period measure yields 0.0430 (0.0190) versus 0.0050 OLS — but 0.043 exceeds the paper's *direct* effect (0.0262), implying over-full pass-through, which no outside-options mechanism delivers. The decomposition shows why: a small, genuinely positive reduced form (early-half connectivity predicts post-2012 wage growth: 0.0025, SE 0.0011) is divided by a tiny first stage (0.058) — the time-split halves share almost no persistent within-industry-region component, so the IV attributes the entire effect to a sliver of the variation and explodes. The constructive readings: (i) the measure contains real signal (the reduced form); (ii) OLS is plausibly conservative, but this design cannot quantify by how much; (iii) the proper correction — used by Caldwell & Harmon (2019) and Bassier (2024) — splits *workers*, not *years*, producing parallel same-period measures; that requires microdata on the server.
3. **Incidence is (statistically) equal across groups.** When the firm-level shock hits, wages of education, gender, and race groups within the same firm respond with no detectable differential — though the confidence intervals allow meaningful asymmetries.
4. **All significant within-firm *employment* estimates are mirror-image reversion patterns.** Across five partitions, every starred employment coefficient is accompanied by a placebo of similar size and opposite sign. Within-firm employment results in this design — including Table A8's low-skill employment effect — should be treated as mean reversion until proven otherwise.
5. **The firm-level margin variables (stayer/switcher wages, quits, hiring) cannot support causal conclusions.** The turnover rates fail their pre-trend tests outright; the stayer/switcher wages pass pre-trend tests but produce an internally inconsistent pattern, and the switcher-wage variable has a missingness discontinuity exactly at the post-period. The stayer/new-hire decomposition requires reconstruction from microdata.
6. **The "fairness multiplier" prediction (wage response increasing in exposed-group size) is directionally supported for wages, mixed for employment, and underpowered throughout**; the common-vs-idiosyncratic decomposition is consistent with firms transmitting only the common component of group exposure, but this is partly mechanical given finding 1.

# Data, samples, and conventions

All exercises use the layer files in the replication package (`firm_layer_outcomes_*` and `firm_layer_connectivity_*` for edu2, gender, race, occ4, ten2; the Lagos firm panel; pre-period total-flow files). The estimation machinery is an R re-implementation validated against the coauthor's Stata outputs: it reproduces the bundled CSVs and the paper's published Tables A7/A8 and Table 2 to the fourth decimal (see `gui_check/REPORT.md`).

Unless noted: sample = **untreated establishments in the balanced panel** (the paper's spillover sample); connectivity scaled so **1 = the 90th percentile** among that sample in 2009 (pooled across groups within a partition); treatment = year $\geq$ 2012; **pre-trend rows** report the paper's placebo convention (2009–10 relative to 2011, estimated on pre-period data only) plus, where indicated, the p-value of the joint event-study test that the 2009 and 2010 coefficients are zero ("ES pre-F"); standard errors clustered by establishment; reghdfe-style singleton dropping; *** p<0.01, ** p<0.05, * p<0.10.

**Variable audit** (details in `checks/variable_audit.txt`). Layer employment sums to firm employment (corr 0.996–0.999; the race partition covers only white/nonwhite-declared workers, median 97% of employment). Group wage levels are plausible (managers R\$6,479 > high-skill R\$3,065 > bureaucratic R\$2,306 > low-skill R\$1,710). The connectivity `_n` measures equal the mean of available year-pair measures exactly. Three flags: (i) `lr_remdezr_switchers` missingness jumps from 20–27% (2009–12) to ~41% (2013–16) — a construction artifact that contaminates post-period comparisons; (ii) turnover rates have extreme outliers (quits max = 216), winsorized below at the pre-period p99; (iii) about 20% of ten2 firm-years lack one of the two tenure cells, so tenure regressions lean on the subset of firm-years employing both groups.

# E1. How reliable is group-specific connectivity? (measurement)

**Motivation.** The within-firm design identifies from differences in connectivity across groups *inside* a firm. Connectivity is built from four year-pair flow counts (2007–08 … 2010–11); group-level cells are small (median 8–21 workers in the two-group partitions; managers in occ4: 2), so flows are lumpy. If the within-firm gap is dominated by idiosyncratic flow realizations rather than persistent group-specific market ties, the within-firm regression is attenuated toward zero mechanically. The four year-pair measures allow a direct test: split them into halves and correlate.

**Method.** For each firm, compute the within-firm connectivity gap (or, for multi-group partitions, deviations from the employment-weighted firm mean) separately from early pairs (07–08, 08–09) and late pairs (09–10, 10–11); correlate across firms. Spearman–Brown converts the split-half correlation r into the reliability of the 4-pair average: 2r/(1+r). An odd/even split (07–08+09–10 vs 08–09+10–11) guards against secular drift. As benchmarks, the same computation for the raw cell-level measure ("levels") and for the employment-weighted firm-level aggregate ("between-firm").

**Results.**

| Partition | Within-firm dev. (Pearson) | Spearman | SB 4-pair reliability | Firm-level (Pearson / winsorized / Spearman) |
|---|---|---|---|---|
| edu2 | 0.070 | 0.278 | 0.13 | 0.18 / 0.35 / 0.50 |
| gender | 0.074 | 0.249 | 0.14 | 0.16 / 0.34 / 0.50 |
| race | 0.002 | 0.160 | 0.00 | — |
| occ4 | 0.069 | 0.259 | 0.13 | — |
| ten2 | 0.166 | 0.432 | 0.29 | — |

The odd/even split gives similarly low numbers (edu2 gap: 0.081 vs 0.060 early/late; gender: 0.139 vs 0.077), ruling out secular drift as the main explanation: the within-firm gap simply does not persist across pre-period years. The race partition's within-firm variation is statistically pure noise. Sample sizes are 3,183–3,766 firms (one gap observation per firm; for multi-group partitions the cell-level deviations are firm-linked, so firms — not cells — are the effective unit). Two mild biases work against each other: ~6% of early halves rest on a single year-pair (biasing the split-half correlation down), while adjacent year-pairs share a boundary year (biasing it up); neither changes the order of magnitude.

The regression counterpart: a split-sample IV of the within-firm specification (late-half connectivity × Post instrumented by early-half connectivity × Post) has first-stage F $\approx$ 1.6 (edu2) and 2.1 (gender) — too weak to use. The IV point estimates are uninformative (e.g., wages, edu2: −0.092 with SE 0.109).

**Takeaway.** The raw split-half numbers, if anything, overstate the reliability of the variation the regression actually uses: after partialling out the fixed effects, the first-stage slope between the two halves in the firm-level exercise below is only ~0.06 — the persistent shared component of the measure is far smaller than the raw correlations suggest. Under classical measurement error, the within-firm wage estimate of −0.004 (0.004) with reliability $\approx$ 0.13 is consistent with true effects anywhere in roughly [−0.09, +0.03] — an interval that comfortably contains the firm-level effect (0.005) and several multiples of it. **The within-firm test, as currently constructed, cannot establish that firms do not differentiate pay within the firm.** Two readings are observationally equivalent: (a) firms ignore group-specific pressure; (b) persistent group-specific pressure differences within firms are too small/poorly measured to detect. Note that reading (b) has its own economic content: if true within-firm differences in exposure are largely transitory, firms *rationally* would not tailor structural pay to them.

# E1c. Is the headline spillover attenuated? A cautionary split-sample IV

**Motivation.** The same logic applies at the firm level, where reliability is higher (0.18 Pearson, 0.50 Spearman) but far from 1. Caldwell & Harmon (2019) and Bassier (2024) address measurement error in flow-based exposure with split-sample IV. One important design difference upfront: they split *workers* into random halves (two parallel measures of the same period); the packaged data only permit splitting *years* (early vs late year-pairs), which confounds measurement error with genuine time-variation in exposure. The exercise below shows this matters decisively.

**Method.** Firm-level early/late connectivity built as the employment-weighted average of the group-level year-pair measures (this aggregate matches the official firm measure with R² = 0.94). Table 2's exact specification (establishment FE; year FE × industry, microregion, negotiation-month; quartile-bin × year controls; full spillover sample); late measure × Post instrumented by early measure × Post.

**Results** (wages; employment in parentheses where relevant):

| | Coef. | SE | N | Firms |
|---|---|---|---|---|
| OLS, official measure (Table 2 spec, IV sample) | 0.0050** | (0.0023) | 32,479 | 4,082 |
| OLS, late-half measure | 0.0033 | (0.0026) | 32,479 | 4,082 |
| IV, late ← early | 0.0430** | (0.0190) | 32,479 | 4,082 |
| first-stage F | 8.8 | | | |
| Anderson–Rubin 95% CI (weak-ID robust) | [0.007, 0.110] | | | |
| Pre-trend, OLS (placebo) | 0.0020 | (0.0025) | | |
| Pre-trend, IV (placebo) | 0.0087 | (0.0207) | | |

Employment: IV −0.002 (0.059) — the employment null survives correction. The IV placebo is clean.

**Decomposition and admissibility check.** In the just-identified case the IV equals the reduced form over the first stage: reduced form (wages on early-half connectivity × Post) = 0.0025 (0.0011); first stage (late on early, within the full FE structure) = 0.058 (0.020); 0.0025/0.058 = 0.043. And 0.043 **fails an economic admissibility check**: it exceeds the paper's direct effect on wages (0.0262***, Table 1), implying competitors respond *more* than the treated firms themselves — over-full pass-through that no outside-options mechanism delivers.

**Takeaway: do not use this IV as a magnitude correction.** The failure is informative about the measure, not the spillover. After the fixed effects absorb the industry/region/size components, the two time-halves share only ~6% of their variation; the classical measurement-error model then requires the *entire* wage effect to load on that persistent sliver — if instead the transitory part of flow-based exposure also carries true signal (likely: yearly flows are genuine realizations of outside options, not pure noise), or if the halves share a persistent denominator component (firm employment), the IV overshoots mechanically. What survives: (i) the reduced form is a real, precisely estimated fact — connectivity measured from 2007–09 flows alone predicts post-2012 wage growth — so the measure contains signal and OLS attenuation is plausible; (ii) the weak-ID-robust Anderson–Rubin set [0.007, 0.110], intersected with the economic bound that spillovers cannot exceed the direct effect (0.026), leaves [0.007, 0.026] — consistent with OLS sitting at the *bottom* of the plausible range, but not evidence of any specific larger magnitude; (iii) the version worth doing splits **workers** rather than years (Caldwell–Harmon/Bassier design), which requires rebuilding flow counts from microdata on the server.

# E2. Incidence: who captures the firm-wide raise?

**Motivation.** Even if relative pay within firms does not respond to *group-specific* pressure, the firm-wide raise documented in Table 2 must be distributed across coworkers. Does it go disproportionately to men? To the more educated? To white workers? This flips Table A8's question: the shock is the *firm-level* exposure (well measured, per E1), and the outcome is group-level — so it does not inherit the within-firm measurement problem on the regressor side.

**Method.** Group-level outcome on firm-level connectivity × Post × 1[group = G2], with group×firm FE, **firm×year FE**, group×year FE, and the group-level bin×year controls. The coefficient is the differential response of G2 vs G1 within the same firm-year. G2 = has-HS / male / white.

**Results** (differential response, G2 minus G1):

| Partition (G2) | Wages | Pre-trend | ES pre-F | Employment | Pre-trend | N | Firms |
|---|---|---|---|---|---|---|---|
| Education (has-HS) | 0.0013 (0.0042) | 0.0088** (0.0039) | 0.113 | 0.0023 (0.0113) | 0.0032 (0.0114) | 53,248 | 3,701 |
| Gender (male) | 0.0038 (0.0031) | −0.0033 (0.0042) | 0.393 | −0.0032 (0.0068) | −0.0007 (0.0088) | 56,448 | 3,836 |
| Race (white) | −0.0012 (0.0041) | −0.0008 (0.0043) | 0.069 | −0.0167* (0.0091) | −0.0196 (0.0125) | 49,902 | 3,602 |

**Takeaway.** No evidence of differential incidence: the point estimates are small relative to the firm-level effect and statistically zero. This is consistent with equal-treatment pay policies — notable because monopsony logic predicts firms *should* concentrate raises on high-quit-elasticity groups. Caveats: (i) power — the gender differential's CI [−0.002, 0.010] cannot exclude the entire raise accruing to men; (ii) the education wage placebo (0.0088**) flags differential pre-dynamics, and the race wage column's joint pre-test is marginal (p = 0.069), so both columns should be read cautiously; (iii) the race employment cell has a same-signed pre-trend of the same size as the estimate (−0.0196 vs −0.0167*) — a continuing pre-trend, so that cell is not interpretable. The defensible claim: **"we find no evidence that the spillover raise is concentrated on any demographic group, though modest asymmetries cannot be ruled out."**

# E3. The within-firm null across five partitions

**Motivation.** If the within-firm null reflects internal-equity constraints, it should *break* where differentiation is legitimate: across occupational layers (managers vs production workers) and by tenure (firms set new-hire wages freely). The package includes two unused partitions — occ4 and ten2 — that speak to this.

**Method.** The paper's within-firm specification (group×firm FE, firm×year FE, group×year FE, bin×year controls), full sample, one partition at a time.

**Results.**

| Partition | Wages | Pre-trend | ES pre-F | Employment | Pre-trend | ES pre-F | N |
|---|---|---|---|---|---|---|---|
| edu2 | −0.0041 (0.0043) | 0.0046 (0.0054) | 0.025 | −0.0200** (0.0099) | 0.0195* (0.0118) | 0.138 | 52,458 |
| gender | −0.0006 (0.0030) | −0.0010 (0.0050) | 0.898 | −0.0001 (0.0049) | −0.0054 (0.0098) | 0.025 | 55,358 |
| race | −0.0028 (0.0036) | −0.0032 (0.0037) | 0.715 | 0.0223*** (0.0069) | −0.0148 (0.0111) | 0.541 | 48,498 |
| occ4 | −0.0053*** (0.0021) | 0.0027 (0.0025) | 0.121 | 0.0069** (0.0034) | −0.0073* (0.0039) | 0.433 | 92,539 |
| ten2 | −0.0008 (0.0042) | 0.0063 (0.0058) | 0.642 | −0.0124 (0.0091) | −0.0171 (0.0122) | 0.220 | 56,318 |

**Takeaways.**

- **Wages:** the null is uniform across demographic partitions and — against the "legitimate differentiation" hypothesis — also for tenure. Two caveats on the nulls themselves: the edu2 wage cell and the gender employment cell fail the joint event-study pre-trend test (p = 0.025 each), so those two zeros are not clean quasi-experimental nulls. The one starred wage cell (occ4, −0.0053***) is computationally sound and has a clean pre-trend (placebo +0.0027, ES pre-F 0.121); we still would not promote it, because its identifying variation has reliability $\approx$ 0.13 (E3b), under which the implied true effect ($\approx$ −0.04, a 4% relative wage decline at P90) is economically implausible — pointing to non-classical noise (e.g., composition shifts across occupation layers) rather than a causal response. It is worth one follow-up with microdata rather than a claim.
- **Employment: every significant cell has a mirror-image placebo** (edu2 −0.0200** vs +0.0195*; race +0.0223*** vs −0.0148; occ4 +0.0069** vs −0.0073*). This is the signature of mean reversion, and it has a mechanical source: group employment appears in the *denominator* of group connectivity, so transitory employment dips inflate measured connectivity and revert (division bias). **Within-firm employment estimates in this design should not be interpreted causally** — which also retroactively supports treating Table A8's low-skill employment result as reversion, and neutralizes the −0.0200 "wrinkle" in the group×year-FE version of Table A7.

# E4. Firm-level margins: stayers, new hires, turnover

**Motivation.** Where does the firm-level raise land — incumbent pay or hiring wages? And does retention (quits) respond?

**Method.** Table-2-style firm-level specification on: average wage (anchor), stayer wage, switcher (new-hire) wage, and quits/layoffs/hiring rates winsorized at the pre-period (2009–11) 99th percentile of the estimation sample (an initial version that pooled post-period years into the threshold was caught in code review and corrected; the hiring coefficient lost its marginal star under the corrected threshold).

**Results.**

| Outcome | Coef. | Pre-trend | ES pre-F | N | Firms |
|---|---|---|---|---|---|
| Average wage (anchor = Table 2) | 0.0051** (0.0023) | 0.0020 (0.0025) | 0.728 | 32,498 | 4,085 |
| Stayer wage | 0.0003 (0.0028) | 0.0061* (0.0036) | 0.209 | 30,468 | 3,914 |
| Switcher (new-hire) wage | 0.0006 (0.0058) | −0.0039 (0.0042) | 0.634 | 22,271 | 3,585 |
| Switcher wage, always-reporting firms$^{\dagger}$ | 0.0022 (0.0101) | −0.0021 (0.0070) | 0.822 | 12,192 | 1,524 |
| Quits rate (w) | −0.0029** (0.0012) | −0.0066** (0.0027) | 0.000 | 32,704 | 4,088 |
| Layoffs rate (w) | −0.0001 (0.0026) | −0.0088** (0.0037) | 0.052 | 32,704 | 4,088 |
| Hiring rate (w) | −0.0069 (0.0042) | −0.0118** (0.0060) | 0.049 | 32,704 | 4,088 |

$^{\dagger}$Diagnostic only: conditioning on reporting switcher wages in all eight years selects on post-treatment hiring behavior.

**Takeaway: these variables cannot answer the question.** The turnover outcomes fail their pre-trend tests (ES pre-F: quits 0.000, hiring 0.049, layoffs 0.052; placebos larger than the "effects"). The stayer/switcher wages pass pre-trend tests but produce a puzzle — the average wage rises while neither subgroup's wage does — which, combined with the switcher-missingness discontinuity found in the audit, points to construction problems in these inherited variables rather than economics. We recommend rebuilding group-level hire/stayer wages and separation/hire counts directly from RAIS microdata before using this margin; as it stands, no claim should enter the paper from E4.

# E5–E6. Size interaction and common/idiosyncratic decomposition

**E5 (fairness multiplier).** If pay moves for everyone or no one, the wage response to group-g pressure should increase with the group's employment share (raising the whole wage bill to retain a small group is not worth it), and the employment response should be worst for small exposed groups. Adding C×Post×(share−mean) to the group-level specification: the WAGE interaction is positive in all four variants, as predicted (edu2: +0.0097 (0.0061) overall FE, +0.0084 (0.0066) within-firm FE; gender: +0.0065 (0.0051) overall, +0.0006 (0.0056) within); the EMPLOYMENT interactions are mixed — edu2 +0.0231* (0.0126) overall as predicted, but gender goes the wrong way (−0.0081 (0.0121) overall, −0.0156 (0.0123) within, both n.s.). Nothing is significant at the 5% level, and the within-firm edu2 wage version has a placebo flag (pre-interaction 0.0178**, larger than the post estimate; no joint event-study pre-test was run for the interaction terms). **Suggestive, not evidence.** Worth one robustness paragraph only if the within-firm section survives; the well-powered version needs the microdata mobility outcomes.

**E6 (Mundlak decomposition).** Splitting group connectivity into its employment-weighted firm mean ("common") and the within-firm deviation ("idiosyncratic") and entering both: wages load on the common component (edu2 0.0025 (0.0026); gender 0.0032 (0.0025) — magnitudes consistent with the firm-level effect in these units, though individually n.s.) and not at all on the idiosyncratic deviation (−0.0011 (0.0051); −0.0001 (0.0031)). This is the cleanest *presentation* of Section 6.2's message — "firms transmit the common component of outside-option shocks and ignore the idiosyncratic component" — but given E1, the zero on the idiosyncratic term is partly mechanical (its signal content is ~13%), so it should be presented as a description, not as an independent test. Two further caveats: the decomposition requires both groups' connectivity, restricting the sample to two-group firms; and algebraically the deviation is largest for the smaller group — whose connectivity is measured from the fewest workers — so the idiosyncratic coefficient is identified disproportionately from the noisiest cells. The employment version shows the same reversion artifact as E3 (idio −0.0237** with placebo +0.0218*).

# What the current data cannot do (and is worth doing)

The three highest-value follow-ups all need worker-level RAIS construction, not new methods:

1. **Group-level separations to treated establishments, post-period** — the within-firm *mobility* first stage. Workers are not bound by the firm's equity constraint; if group-specific outside options are real and persistent, exposed groups should move more even where pay does not respond. This simultaneously validates the within-firm variation (or confirms E1's verdict that it is noise).
2. **Group-level new-hire vs incumbent wages** — the margin E4's inherited variables could not deliver.
3. **Firm-level year-pair treated-flow counts** — to run the E1c IV on the official measure with Anderson–Rubin inference, turning the attenuation result into a publishable robustness estimate.

# Suggested additions to the paper (calibrated)

**High confidence — recommend adding:**

1. *Reframe the within-firm claim (Section 6.2, Table A7).* Replace "we find no evidence that firms tailor relative pay…" as a conclusion about firm behavior with a two-part statement: (i) the within-firm estimates are precise zeros under the paper's specification; (ii) the identifying variation has split-half reliability of ~0.1, so the design cannot rule out within-firm pass-through as large as the firm-level effect. Keep the section's main message on the *measurement* lesson (Column 3 logic), which E1 actively strengthens: group-level exposure is noisy, and matching measurement to the wage-setting level is exactly what a noisy-disaggregation argument implies. Add the reliability table (or its two headline numbers) to the Table A6 descriptives or a footnote.
2. *Drop or heavily caveat all group-level employment results* (A7 columns 5–6 under any spec, A8 employment columns). Across every partition and specification, significant group-employment estimates come with mirror-image placebos, consistent with division-bias mean reversion (group employment enters the connectivity denominator). A one-sentence footnote explaining the mechanical reversion channel would pre-empt referee reconstruction.

**Medium confidence — recommend adding after the noted upgrades:**

3. *A measurement-error robustness for Table 2 — but only in the worker-split design.* The year-split IV runnable from the packaged data produces an economically inadmissible point estimate (0.043 > the direct effect 0.026) and should **not** go in the paper. What can be said now, if anything, is one sentence: connectivity built from 2007–09 flows alone predicts post-2012 wage growth (reduced form 0.0025, SE 0.0011), suggesting the OLS spillover is, if anything, conservative. The publishable correction is a Caldwell–Harmon/Bassier-style IV splitting *workers* into random halves within the full pre-period — buildable only from microdata on the server.
4. *Incidence result (E2) as a short subsection or table*: "the spillover raise is spread evenly across coworker groups" — with the power caveat stated, and excluding the education column or flagging its placebo. This is a genuinely new, referee-attractive fact about *within-firm distribution* of spillovers, and its regressor (firm-level connectivity) does not suffer the E1 problem.

**Low confidence — do not add now:**

5. E5's size interaction and E6's decomposition: directionally consistent, underpowered, partly mechanical. Revisit after the microdata mobility outcomes exist.
6. Anything from E4's inherited stayer/switcher/turnover variables.

# Verification

All scripts were independently reviewed by two separate code reviewers with data access. Both reproduced the headline numbers from raw data (the edu2 gap reliability to five decimals; the firm-IV inputs and Table 2 anchor exactly) and found no critical coding errors; their findings — a winsorization threshold that improperly pooled post-period data (corrected, results updated), weak-instrument inference for the firm IV (added: the Anderson–Rubin set above), the race-partition reliability of zero, and several pre-trend caveats — are incorporated in this version. A subsequent coauthor review caught that the year-split IV point estimate exceeds the paper's direct effect; Section E1c was rewritten from a magnitude-correction claim to a cautionary result with the decomposition and admissibility analysis above.

# Files

`extensions/scripts/`: `00_variable_audit.R`, `01_reliability_iv.R`, `01b_reliability_robust.R`, `01c_firm_iv.R`, `01d_ar_ci.R`, `02_incidence.R`, `03_partitions.R`, `03b_reliability_all_partitions.R`, `04_firm_margins.R`, `05_size_interaction.R`, `06_mundlak.R`, shared machinery in `ext_common.R`/`ext_prep.R`. Numeric outputs in `extensions/output/`; audit log in `extensions/checks/`. All scripts run start-to-finish from the packaged data.
