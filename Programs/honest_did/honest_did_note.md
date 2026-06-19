# Honest-DiD sensitivity analysis (Rambachan–Roth 2023) — design note

## What this does

For each of the 8 main event studies — {direct, spillover} × {`lr_remdezr_w`,
`lr_remdezr_h_w`, `l_firm_emp`, `numb_clauses`} — we take the **existing**
event-study coefficient vector and its **establishment-clustered VCV** (the same
specs as the headline tables, estimated standalone, nothing re-derived) and run
the Rambachan–Roth robust-CI procedure under two restrictions on the unobserved
differential trend:

- **ΔRM (relative magnitudes), parameter M̄.** Bounds the post-treatment
  differential trend by M̄ times the *largest pre-treatment* differential
  trend. M̄ = 1 says "post-treatment violations of parallel trends are no larger
  than the largest violation we actually see pre-treatment." Scale-free, so the
  grid `M̄ ∈ {0, 0.25, …, 2}` is **identical and comparable across all 8 specs**.

- **ΔSD (smoothness), parameter M.** Bounds the *curvature* (second difference)
  of the differential trend by M, i.e. the differential trend can deviate from
  linearity by at most M per period. M is in **outcome units** (log points for
  the wage/employment outcomes; clause counts for `numb_clauses`), so the M grid
  is **not comparable across outcomes** — we scale it per outcome to 4×RMS of the
  post-period coefficient standard errors.

We report, per spec, the **breakdown value** (smallest M̄ / M at which the robust
CI first contains zero) and a sensitivity plot (robust CI band vs M̄/M with the
original OLS CI overlaid). All robust CIs use the **C-LF (conditional
least-favorable) method**. (The FLCI method is unavailable on this cluster: its
OSQP solver plugin requires GLIBC 2.34, newer than el8's 2.28; C-LF runs on the
ECOS plugin and is a valid RR method for both restrictions.)

## Which restriction is more appropriate where

**Spillover specs → ΔRM is the primary restriction.**
The spillover "treatment" is *continuous network exposure* to the reform
(`totaltreat_pw_norm`), and the event-study coefficients trace the differential
evolution of more- vs. less-exposed firms. There is no natural notion of a
smooth secular *time* trend in the exposure–year interaction: exposure is a
cross-sectional gradient, and confounds would enter as exposure-correlated
shocks that need not be smooth in calendar time (e.g. a demand shock hitting the
same labor-market neighborhoods that generate high exposure). The economically
meaningful question is therefore *"could a post-period exposure-differential
shock be as large as the exposure-differential movements we see pre-period?"* —
which is exactly what ΔRM disciplines. ΔRM also keeps the M̄ grid comparable
across the spillover outcomes. We report ΔSD as a complementary check, but it is
the secondary lens for spillovers.

**Direct specs → ΔSD is the natural complement, ΔRM still reported.**
The direct specs compare a binary treated group (`treat_ultra`) to controls.
Here the classic honest-DiD intuition applies cleanly: if treated and control
groups were on smoothly diverging secular trends, the pre-period coefficients
identify the slope and ΔSD bounds how much the trend can *bend* after treatment.
ΔSD is the restriction Rambachan–Roth motivate with exactly this
two-group/smooth-trend picture, so it is the more interpretable primary lens for
the direct effects. We still report ΔRM for the direct specs so the two effect
types can be compared on the common scale-free grid.

## Caveats to flag

1. **Thin pre-periods.** The year-based specs have only **2 pre-periods**
   (2009, 2010; 2011 = reference). ΔRM and ΔSD are feasible but rest on limited
   pre-treatment information; breakdown values should be read accordingly.

2. **`numb_clauses` has a single pre-period.** Its CBA-period event study
   (`ib(2).cba_period`: period 1 pre, period 2 reference, periods 3–6 post) has
   **one** pre-period coefficient. RR is still computable via C-LF, but the
   "largest pre-period violation" (ΔRM) and the pre-trend slope (ΔSD) are each
   pinned by a *single* coefficient. We compute and report it, marked `†`, but
   do not treat it as a load-bearing robustness check. If a stronger clauses
   check is wanted, estimate the clauses event study on the year structure
   (`ib2011.year`), which yields 2 pre-periods at the cost of departing from the
   headline CBA-period specification.

3. **ΔSD at M = 0 under C-LF.** Unlike FLCI, the C-LF interval at M = 0 (exactly
   linear differential trend) can already include zero for some specs; this is a
   property of the conditional method, not evidence of fragility per se. Read SD
   breakdowns alongside the full sensitivity plot.

## Companion diagnostic: Roth (2022) pre-trends power (`pretrends`)

HonestDiD (above) asks *"how large a PT violation overturns the result?"*. The
complementary **Roth (2022)** diagnostic asks *"is the pre-trends test even
powered enough that passing it is informative — and what is the bias from
conditioning on having passed?"*. This is the presentation used in the
bargaining-council spillover literature (e.g. Bassier), drawn in the same
coefficient space as the event study, so we report it as the **primary
robustness figure** with HonestDiD as the secondary/quantitative backstop.

For each of the 8 specs we compute, from the same `betahat`/`sigma`:

- the slope of a **linear pre-trend the pre-test would reject with 50% and 80%
  probability** (`slope_for_power`); and
- the **expected event-study coefficients conditional on passing** the pre-test
  under that trend.

The figure (`pretrends_{50,80}.pdf`) overlays, per spec: estimated coefficients
(+CIs), the hypothesized trend, and the conditional-on-passing coefficients.
Reading: if the trend a *well-powered* (80%) test would catch is small relative
to the estimated post-effect — and the coefficients you'd *expect* conditional on
passing fall well short of the estimates — then a passed pre-test is meaningful
and the effect is unlikely to be an artifact of an undetected linear pre-trend.

Same caveats carry over: 2 pre-periods for the year specs (thin), and
**numb_clauses has a single pre-period**, which makes its slope/power diagnostic
degenerate (flagged `†`, not load-bearing).

## Files

- `honest_did.do` — runs each of the 8 event studies once, extracts b/V, and
  feeds them to BOTH honestdid (RR) and pretrends (Roth). Run via
  `_run_honest_did_cluster.do`.
- `ado/honestdid.ado` — patched copy (OSQP gate removed; adopath-prepended).
- `honest_did_plot.py` — RR breakdown table + sensitivity plots.
- `pretrends_plot.py` — Roth power-slope table + Bassier-style event-study figures.
- Outputs:
  - RR: `Tables/honest_did/honest_did_results.csv`, `honest_did_breakdown.{csv,tex}`,
    `Graphs/honest_did/honest_did_{rm,sd}.{pdf,png}`.
  - Roth: `Tables/honest_did/pretrends_results.csv`, `pretrends_slopes.{csv,tex}`,
    `Graphs/honest_did/pretrends_{50,80}.{pdf,png}`.
