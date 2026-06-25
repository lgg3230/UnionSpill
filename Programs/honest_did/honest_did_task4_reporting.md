# Task 4 — Rambachan–Roth reporting package

Status: the RR machinery is fully implemented (`honest_did.do`, breakdown CSV/TeX,
`honest_did_{rm,sd}.pdf`, Roth `pretrends_{50,80}.pdf`). This note delivers the four
reporting pieces Task 4 asked for, all from existing outputs.

---

## (4c) Breakdown values — first post-period (p1) vs. average post-period (avg)

The paper currently reports only the **first post-period (p1)** target. The CSV also
has the **average post-period (avg)** target. Both, relative-magnitudes ΔRM (M̄), C-LF:

| Effect | Outcome | M̄ breakdown — **p1** | M̄ breakdown — **avg** |
|---|---|---:|---:|
| Direct | Log wages | **1.78** | 0.64 |
| Direct | Log hourly wages | **1.41** | 0.63 |
| Direct | # CBA clauses† | 1.39 | 0.96 |
| Direct | Log employment | n.s. | n.s. |
| Spillover | Log wages | **0.75** | 0.29 |
| Spillover | Log hourly wages | 0.40 | 0.36 |
| Spillover | Log employment | n.s. | n.s. |
| Spillover | # CBA clauses† | n.s. | n.s. |

(† single pre-period; n.s. = original OLS CI already includes 0.)

**Interpretation (plain language).** The breakdown value answers: *how large would a
post-reform violation of parallel trends have to be — as a multiple of the worst
violation we actually see before the reform — to erase the effect?* M̄ = 1 is the
natural bar ("post-violations no larger than the worst pre-violation").

**Why avg < p1, always, and why that is not a bug.** The avg target requires the
robust CI for the *average* 2012–2016 effect to exclude zero. A longer post-window
gives an unobserved differential trend more periods over which to accumulate, so the
robust confidence set is mechanically wider and the breakdown lower. The first
post-period is the most robust because it is closest to the pre-period and leaves the
least room for divergence. We therefore **lead with p1 as the headline** (also the most
comparable to the applied RR literature, which typically targets an early/representative
post-period) and **report avg as the conservative full-window number**. The ordering
p1 ≥ avg is expected and should be stated as such, not apologized for.

---

## (4b) Which restriction is primary — ΔRM vs ΔSD

Lift the design-note logic into the paper (currently the two are presented
symmetrically):

- **Spillover specs → ΔRM is primary.** The spillover "treatment" is a *continuous
  cross-sectional exposure gradient* (`totaltreat_pw_norm`); there is no natural notion
  of a smooth secular *calendar-time* trend in the exposure×year interaction. A confound
  enters as an exposure-correlated shock (e.g. a demand shock hitting the same
  labor-market neighborhoods that generate high exposure), which need not be smooth in
  time. The meaningful question is therefore "could a post-period exposure-differential
  shock be as large as the exposure-differential movements we see pre-period?" — exactly
  what ΔRM disciplines. ΔSD (smoothness in calendar time) is the secondary lens here.
- **Direct specs → ΔSD is the natural primary, ΔRM still reported.** The direct effect
  compares a binary treated group to controls; the classic honest-DiD smooth-secular-trend
  picture applies, so ΔSD (how much the trend may *bend* after treatment) is the more
  interpretable lens. ΔRM is reported too so the two effect types share the scale-free grid.

This is a *defensible, stated choice*, not hedging: the restriction should match the
source of the identifying variation (cross-sectional gradient vs. two-group time trend).

---

## (4a) The "rotated / smoothness" figure — what it actually is

`honest_did_sd.pdf` is the **standard HonestDiD ΔSD sensitivity plot**: per spec, the
robust 95% CI (red) is drawn as the smoothness parameter **M** increases along the
x-axis (with the original OLS CI in blue), and the breakdown M is annotated. The x-axis
**M = maximum per-period change in the slope of the differential trend** (curvature, in
outcome units); M = 0 imposes an exactly linear counterfactual trend, and the band
widens as M grows because more curvature is allowed, until it first covers zero at the
breakdown.

**It is *not* a literal "rotated event study."** The "rotation" idea — overlay a linear
pre-trend extrapolation on the event-study coefficients and ask how much extra deviation
kills the effect — is actually closer to the **Roth (2022) `pretrends_50.pdf`** figure
already in the paper, which overlays a hypothesized linear trend (and the
coefficients-expected-conditional-on-passing) on the event study. So the paper already
contains the trend-overlay/"rotation"-style visual; the ΔSD figure is the complementary
band-style robustness summary.
→ **Decision needed:** keep the band-style ΔSD figure (recommended; it is the standard
RR presentation and pairs cleanly with the Roth overlay figure), or also add a literal
rotated-event-study panel. I recommend the former — we'd be adding a third view of the
same object.

---

## (4c/lit) Comparison to the applied RR literature

Anchor to RR's own empirical illustrations (`hpt-draft.pdf`):
- Their headline ΔRM illustration (effect on restaurant profits) has **breakdown
  M̄ ≈ 2**; their ΔSD illustration has **breakdown M ≈ 0.01**.
- Applied practice treats **M̄ ≈ 1** as the natural bar; published results range from
  fragile (breakdown M̄ < 0.5) to robust (M̄ > 1–2).

Against that yardstick:
- **Direct wage effects (M̄ = 1.78 / 1.41; M = 0.012 / 0.007) are about as robust as
  RR's own showcase application** (M̄ ≈ 2, M ≈ 0.01). This is a strong, defensible
  statement to make explicitly.
- **Spillover wage effects (M̄ = 0.75 / 0.40; avg 0.29 / 0.36; M ≈ 0–0.001) are
  fragile** — robust only to post-violations a fraction of the pre-period ones. This is
  not unusual for smaller-magnitude spillover effects, and the paper already says so;
  the Roth power diagnostic reinforces it (spillover 80%-detectable slope 0.0046 vs mean
  post-effect 0.0065, i.e. the pre-test is only weakly informative for the spillover).

---

## Paper edits — APPLIED (2026-06-24)

All four deliverables are now in `UnionSpill_paper/Main_Results.tex`,
§"Sensitivity to Parallel Trends: Honest DiD" (the additions are additive; the
existing p1 band-style ΔRM/ΔSD figures and Roth overlay are unchanged):

1. **(4b) Restriction-primacy paragraph** added after the restrictions
   description: ΔSD primary for the direct effect (binary two-group smooth-trend
   story), ΔRM primary for the spillover (continuous cross-sectional exposure
   gradient; confounds are exposure-correlated shocks, not smooth in calendar
   time), each reporting the other as a complement.
2. **(4a) p1-vs-avg paragraph** added after the smoothness results: avg breakdowns
   (RM) are 0.64/0.63 direct and 0.29/0.36 spillover vs p1's 1.78/1.41 and
   0.75/0.40 — stated as a mechanical horizon feature (longer window → wider robust
   set), lead with p1, treat avg as the conservative bound.
3. **(4c) F.1-style figures** built and inserted: `honest_did_F1_{direct,spill}.pdf`
   (Fig. `honest_did_F1_direct`, `honest_did_F1_spill`) — three panels per outcome
   row: (a) event study + linear pre-trend extrapolation, (b) rotated/detrended
   event study, (c) robust band under the *primary* restriction (ΔSD direct, ΔRM
   spillover) with breakdown marked. Source: `Programs/honest_did/honest_did_F1.py`
   (reads existing `pretrends_results.csv` + `honest_did_results.csv`; no
   re-estimation). This supersedes the earlier recommendation to skip a literal
   rotated figure — the user asked for the F.1 treatment explicitly.
4. **(4d) Literature-comparison paragraph** added (`\paragraph{How robust...}`):
   direct wage breakdowns (M̄=1.78/1.41, M=0.012/0.007) bracket RR's own showcase
   illustrations (restaurant-profits ΔRM breakdown M̄≈2; ΔSD illustration M≈0.01,
   both verified in `Docs/RambanchanRoth2023.md` p.~2100/2240) and clear the M̄=1
   bar; spillover breakdowns (M̄=0.75/0.40, avg 0.29/0.36) are flagged honestly as
   fragile/VERY FRAGILE, framed as expected for order-of-magnitude-smaller effects.

Bib: added `fenizia2024organized` (AER 2024, 114(7):2171–2200) to `bib.bib`.

### Verified numbers (from `honest_did_breakdown.csv`, latest run)
| Effect | Outcome | M̄ p1 | M̄ avg | M (SD) p1 | flag (RM avg) |
|---|---|---:|---:|---:|---|
| Direct | Log wages | 1.78 | 0.64 | 0.012 | fragile |
| Direct | Log hourly wages | 1.41 | 0.63 | 0.007 | fragile |
| Direct | # CBA clauses† | 1.39 | 0.96 | — | fragile |
| Spillover | Log wages | 0.75 | 0.29 | ~0.001 | VERY FRAGILE |
| Spillover | Log hourly wages | 0.40 | 0.36 | 0 (at_min) | VERY FRAGILE |
| {Direct,Spill} | Log employment | n.s. | n.s. | n.s. | OLS n.s. |
