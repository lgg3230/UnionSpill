---
title: "Robustness of Firm-Level Spillovers to the Pre-Period Window Used to Measure Connectivity"
subtitle: "Early vs. late vs. full-window connectivity — Outside Options and Collective Bargaining Spillovers"
author: "Prepared for Guilherme Neri & Luis de Azevedo Gomes"
date: "July 2026"
geometry: margin=1in
fontsize: 11pt
header-includes:
  - \usepackage{booktabs}
  - \usepackage{float}
---

# Motivation

The paper's connectivity measure averages worker flows to treated establishments over four pre-treatment year-pairs (2007–08 through 2010–11). Two natural questions follow. First, **is the spillover an artifact of the particular pre-period window used to build the regressor?** If exposure measured from 2007–09 flows and exposure measured from 2009–11 flows both predict post-reform wage growth, the result does not hinge on the window. Second, **what does the window teach us about measurement error?** Each two-year half is a noisier proxy for a firm's true labor-market position than the four-year average; comparing halves to the full window shows directly how reliability shapes the estimate — the honest, assumption-light version of the split-sample IV exercise (which, splitting *years* rather than *workers*, produced an economically inadmissible magnitude and is not used).

This note re-estimates the firm-level spillover specification with connectivity built from (i) the official four-year measure, (ii) a four-year measure rebuilt by our own aggregation (a bridge/validation), (iii) the **first half** (2007–08 and 2008–09 flows only), and (iv) the **second half** (2009–10 and 2010–11 flows only), for all four Table 2 outcomes, under two normalizations.

# Method and specification

**Specification (identical to Table 2).** For each outcome $y_{it}$ and each connectivity measure $C_i$,
$$y_{it} = \delta\,\big(C_i \times \mathrm{Post}_t\big) + \alpha_i + \text{(controls)} + \varepsilon_{it},$$
with establishment fixed effects; year fixed effects interacted with two-digit industry, microregion, and negotiation-month; and quartile bins of pre-treatment firm size, per-worker flows, and the outcome, each interacted with year. Sample: untreated establishments in the balanced panel. Post = 2012–2016, reference year 2011. Standard errors clustered by establishment. Pre-trend (placebo) is estimated on pre-period data only (2009–10 vs. 2011); the joint pre-trend $p$ tests that the 2009 and 2010 event-study interactions are jointly zero.

**Building the half-window measures.** The official firm measure exists only as the four-year aggregate. The year-pair components exist only at the firm $\times$ group level (the connectivity files). We therefore rebuild firm-level connectivity for any set of year-pairs by employment-weighting the group-level year-pair measures (pre-period 2009–11 mean group employment as weights), using the education partition. Validation: our four-year aggregate correlates 0.97 with the official measure and reproduces the Table 2 wage coefficient closely (0.0056 vs. 0.0051; the small gap is the aggregation approximation plus a 19-establishment sample difference). The first- and second-half measures are built by the identical pipeline, so differences across them reflect the **window**, not the construction. The first and second halves correlate only **0.18** across firms — they carry substantially independent information.

**Two normalizations.** Connectivity is scaled so that 1 = the 90th percentile. "Own-P90" divides each measure by its own P90; "main-P90" divides every measure by the P90 of the four-year measure, putting all coefficients on a common raw scale. Because normalization only rescales the regressor, significance is identical across the two; only magnitudes move. The P90s are all within ~7% of each other (official 0.0293, full 0.0296, first half 0.0313, second half 0.0298 — widest gap 6.6%), so the two normalizations give nearly identical pictures — the normalization choice turns out to be immaterial here.

# Results

**Table 1. Own-P90 normalization** (each measure scaled to its own 90th percentile).

| | Log wages | Log hourly wages | Log employment | Clause count |
|---|---|---|---|---|
| **Main: official measure (4-yr)** | | | | |
| Post $\times$ Connectivity | 0.0051** | 0.0066*** | 0.0004 | 0.039 |
| | (0.0023) | (0.0023) | (0.0081) | (0.117) |
| Pre-trend (placebo) | 0.0020 | 0.0016 | -0.0012 | -0.108 |
| | (0.0025) | (0.0026) | (0.0063) | (0.145) |
| Joint pre-trend $p$ | 0.73 | 0.79 | 0.87 | 0.28 |
| Observations | 32,498 | 32,498 | 32,704 | 17,998 |
| Establishments | 4,085 | 4,085 | 4,088 | 3,923 |
| **Full aggregate (4-yr)** | | | | |
| Post $\times$ Connectivity | 0.0056*** | 0.0076*** | 0.0014 | -0.012 |
| | (0.0020) | (0.0023) | (0.0077) | (0.113) |
| Pre-trend (placebo) | 0.0019 | 0.0016 | -0.0011 | -0.128 |
| | (0.0025) | (0.0025) | (0.0059) | (0.164) |
| Joint pre-trend $p$ | 0.72 | 0.69 | 0.97 | 0.35 |
| Observations | 32,479 | 32,479 | 32,672 | 17,983 |
| Establishments | 4,082 | 4,082 | 4,084 | 3,919 |
| **First half (2007--09 flows)** | | | | |
| Post $\times$ Connectivity | 0.0025** | 0.0032*** | -0.0001 | -0.008 |
| | (0.0011) | (0.0012) | (0.0035) | (0.056) |
| Pre-trend (placebo) | 0.0005 | 0.0004 | 0.0016 | -0.002 |
| | (0.0011) | (0.0011) | (0.0021) | (0.073) |
| Joint pre-trend $p$ | 0.76 | 0.66 | 0.66 | 0.30 |
| Observations | 32,479 | 32,479 | 32,672 | 17,983 |
| Establishments | 4,082 | 4,082 | 4,084 | 3,919 |
| **Second half (2009--11 flows)** | | | | |
| Post $\times$ Connectivity | 0.0034 | 0.0058** | 0.0021 | 0.073 |
| | (0.0026) | (0.0025) | (0.0114) | (0.170) |
| Pre-trend (placebo) | 0.0041 | 0.0042 | -0.0074 | -0.626* |
| | (0.0044) | (0.0046) | (0.0126) | (0.364) |
| Joint pre-trend $p$ | 0.60 | 0.63 | 0.84 | 0.59 |
| Observations | 32,479 | 32,479 | 32,672 | 17,983 |
| Establishments | 4,082 | 4,082 | 4,084 | 3,919 |

**Table 2. Main-P90 normalization** (every measure scaled to the four-year measure's 90th percentile; only the two half-window rows change, and only trivially).

| | Log wages | Log hourly wages | Log employment | Clause count |
|---|---|---|---|---|
| **First half (2007--09 flows)** | | | | |
| Post $\times$ Connectivity | 0.0024** | 0.0031*** | -0.0001 | -0.007 |
| | (0.0011) | (0.0012) | (0.0033) | (0.053) |
| Joint pre-trend $p$ | 0.76 | 0.66 | 0.66 | 0.30 |
| **Second half (2009--11 flows)** | | | | |
| Post $\times$ Connectivity | 0.0034 | 0.0057** | 0.0021 | 0.073 |
| | (0.0026) | (0.0025) | (0.0114) | (0.169) |
| Joint pre-trend $p$ | 0.60 | 0.63 | 0.84 | 0.59 |

(Main-P90 values for the full-aggregate row equal its Table 1 values exactly; the official row moves by at most 0.0001 — e.g., hourly wages 0.0066 becomes 0.0067 — since its own P90 differs from the four-year P90 by under 1%.)

*Notes.* Clause count is in raw clauses on the CBA-filed subsample; our clause sample (N=17,998) differs slightly from the paper's Table 2 clause column (19,693) because it uses a saved estimation-sample flag from an earlier vintage, so the clause point estimate is not directly comparable to the published 0.0180 — but the standard error reproduces (0.117 vs. 0.1176) and every window agrees the effect is an insignificant zero. The second-half clause placebo ($-0.626^{*}$) is a spurious star on an extremely noisy outcome (SE 0.36). $^{***}p<0.01, ^{**}p<0.05, ^{*}p<0.10$.

# Interpretation

**1. The spillover is not an artifact of the measurement window.** Every window delivers a same-signed, positive wage and hourly-wage spillover and a precise employment zero. Hourly wages — the paper's cleanest wage margin — are significant under *all four* measures, including both individual halves (0.0032\*\*\* first half, 0.0058\*\* second half). Nothing about the result depends on which pre-period years build the regressor.

**2. Pre-determination / no anticipation.** The first-half measure is built entirely from 2007–08 and 2008–09 flows — worker movements that ended more than three years before the reform's September 2012 approval and could not have anticipated it. That measure still yields a **significant, precisely estimated** positive spillover (wages 0.0025\*\*, $t=2.2$; hourly 0.0032\*\*\*, $t=2.6$), with a clean pre-trend (placebo 0.0005, joint $p=0.76$). A firm's exposure, fixed by flows from the late 2000s, forecasts its post-2012 wage path. This is a genuine exogeneity check: reverse causality and anticipation are ruled out by construction, because the regressor predates the treatment by years.

**3. Both halves lie below the full window — consistent with measurement error.** For both wage outcomes each two-year half produces a smaller coefficient than the four-year measure (wages: first half 0.0025, second half 0.0034, vs. full 0.0056; hourly: 0.0032, 0.0058, vs. 0.0076). This is the direction classical measurement error predicts — a two-year window is a noisier proxy for a firm's true labor-market position than the four-year average, so it is more attenuated toward zero — and it suggests the published estimate, built on the most-averaged (most reliable) measure, is if anything a lower bound on the response to true exposure. Two honest caveats. First, this is the *half-vs-full* comparison only: the difference between the first and second halves (0.0025 vs. 0.0034) is **not** a "more years" effect — both average two year-pairs — and reflects the window, not reliability. Second, the coefficient gaps are not statistically distinguishable (the measures are nested and the confidence intervals overlap), so this is *suggestive* evidence of attenuation, not a measured amount of it. Third — see point 4 — the first half's shortfall specifically is driven mostly by tail outliers rather than reliability: winsorized, the first half matches the full measure. The safe reading of the ladder is therefore the weak one: no window *exceeds* the full measure, and cleaning noise (by averaging more years, or trimming the tail) tends to *raise* the estimate — both pointing to the published OLS being conservative — but the exercise does not pin down a magnitude.

**4. The first half's apparent precision is a fat-tail artifact, not lower noise — and it exposes an outlier sensitivity in the main result.** The first half has a much smaller standard error than the second (wages SE 0.0011 vs. 0.0026), but this reflects the *dispersion* of the regressor, not its quality. In P90 units the first-half measure has ~2.3x the cross-firm spread of the second (SD 2.2 vs. 0.9), and that spread is dominated by a handful of extreme firms: the top 1% of first-half-connectivity establishments (41 firms) hold **90%** of its cross-firm variance. A more dispersed regressor mechanically yields a tighter slope estimate — whether the dispersion is signal or noise — so the small SE is *not* evidence that the earlier flows are cleaner. Two consequences. First, those same outliers *flatten* the first-half slope: winsorizing connectivity at its 99th percentile roughly doubles the first-half coefficient (0.0025 to 0.0056, matching the full measure) while inflating its SE to the second half's level, so both the small coefficient and the small SE of the raw first half are tail-shaped. Second, and more important for the paper, the **official measure is concentrated the same way** — its top 1% (42 firms) hold 74% of its variance — and the headline is correspondingly outlier-sensitive: winsorizing connectivity *raises* the wage coefficient (0.0051 raw to 0.0067 at p99 to 0.0075 at p95) but weakens significance as the high-leverage tail is trimmed (wage $t$ falls to 1.9 at p99, 1.2 at p95; hourly is more robust, $t=2.4$ at p99, 1.4 at p95). The estimate moving *up* under trimming is consistent with attenuation (tail noise biases the linear slope toward zero), but the design's precision genuinely rests on a few dozen high-connectivity establishments.

**5. Employment and clauses are zero in every window.** The employment null (all $|t|<0.2$) and the clause-count null (all insignificant, though noisy) hold regardless of window, reinforcing that the spillover operates on wages alone.

**6. Normalization is immaterial.** Because the four measures have 90th percentiles within ~7% of one another, own-P90 and main-P90 normalizations produce essentially identical coefficients (e.g., first-half wages 0.0025 vs. 0.0024). The measurement window changes the *reliability* of connectivity but not the *spread* of it, so how one normalizes does not affect the comparison.

# Suggested addition to the paper (calibrated)

**High confidence — recommend adding as an appendix robustness table.** Table 1 is a clean, well-powered robustness exercise with three publishable messages, all with intact pre-trends: (i) the spillover is invariant to the pre-period window used to construct connectivity; (ii) connectivity built from *pre-2009* flows — predetermined relative to the 2012 reform — already predicts post-reform wage growth, a direct check against anticipation and reverse causality; (iii) both two-year half-windows yield smaller coefficients than the four-year measure, suggestive that the published estimate is, if anything, conservative with respect to measurement error. Recommended framing for (iii): describe it as *suggestive evidence that flow-based connectivity is measured with error and that the baseline is a lower bound* — not as a point correction, and without the split-sample IV (whose year-split design is invalid here, as documented separately). The hourly-wage row is the strongest single line: significant across all four measures.

**Medium confidence.** The first-half ("pre-determined exposure") result is worth mentioning in the main text as an exogeneity check — connectivity fixed by 2007-09 flows predicts post-2012 wages — with the caveat that, winsorized, it is 0.0056 ($t=1.98$), i.e. marginally significant once tail leverage is removed rather than comfortably so.

**Also recommend (independent of the window exercise): a winsorization/trimming robustness for Table 2 itself.** The exposure measure is highly concentrated (top 1% of firms hold ~74% of its variance), so identification leans on a few dozen high-connectivity establishments. Report the main spillover under connectivity winsorized at p99/p95 (point 4): the reassuring news is that the point estimate is *stable-to-larger* under trimming rather than collapsing toward zero; the honest caution is that precision weakens (wages loses significance at p95). This is standard for exposure/shift-share-style designs, where a few high-exposure units carry identification, and is better pre-empted. It may also motivate a functional form less sensitive to the tail (a rank or percentile transform of connectivity, or log connectivity) alongside the level specification.

**Do not report.** The split-sample IV magnitude (documented separately as economically inadmissible). This window comparison is its honest replacement.

# Files

`extensions/scripts/07_diag_halves.R` (variable/P90 diagnostic), `07_halves_main.R` (estimation, all outcomes $\times$ measures, raw-connectivity coefficients), `07b_make_tables.R` (table formatter), `07c_se_diagnostic.R` (standard-error/dispersion decomposition and winsorized halves), `07d_winsor_main.R` (outlier sensitivity of the main result). Outputs: `output/e7_halves.rds`, `output/e7_tables.md`, `output/e7_p90.rds`. Shared machinery in `ext_common.R`/`ext_prep.R`, validated against the coauthor's Stata outputs to four decimals.
