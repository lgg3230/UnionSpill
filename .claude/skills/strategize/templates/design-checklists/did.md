# Design Checklist: Difference-in-Differences

## Classification
- [ ] **Classic (two-period, two-group)** or **Staggered (multiple adoption times)?**
- [ ] If staggered: is treatment timing plausibly exogenous?
- [ ] If staggered: is there a never-treated group?

## Estimator Selection (Staggered)

| Estimator | When to Use | R Package |
|-----------|-------------|-----------|
| Callaway-Sant'Anna (2021) | Group-time ATT, heterogeneous effects | `did::att_gt()` |
| Sun-Abraham (2021) | Interaction-weighted, event studies | `fixest::sunab()` |
| Borusyak-Jaravel-Spiess (2024) | Imputation, efficient under homogeneity | `didimputation` |
| de Chaisemartin-D'Haultfoeuille (2020) | Heterogeneity-robust | `DIDmultiplegt` |
| Gardner (2022) | Two-stage DiD | `did2s` |

**Never use naive TWFE with staggered treatment** unless the memo explicitly justifies it. TWFE with heterogeneous effects and staggered timing produces biased estimates (negative weights).

## Comparison Group
- [ ] **Never-treated** vs. **not-yet-treated**: which and why?
- Never-treated: cleaner comparison, but may be compositionally different
- Not-yet-treated: more similar, but may suffer from anticipation

## Aggregation
- [ ] Simple average across (g,t) cells
- [ ] Group-size weighted
- [ ] Calendar-time aggregation
- [ ] Event-time aggregation (for event study)

## Parallel Trends
- [ ] Visual: pre-treatment trends plot for treatment and control groups
- [ ] Event study: pre-period coefficients (should be near zero)
- [ ] Formal test: joint significance of pre-treatment leads
- [ ] If trends diverge: can you control for differential trends? (risky)
- [ ] How many pre-periods available? (more = more credible)

## No Anticipation
- [ ] Is there reason to believe units react before treatment?
- [ ] Check: event study coefficient at t=-1 (should be zero)
- [ ] Institutional argument: was treatment timing predictable?

## SUTVA / No Spillovers
- [ ] Can treatment of unit i affect outcomes of unit j?
- [ ] Geographic proximity: are treated and control units near each other?
- [ ] Market-level spillovers: do they share labor/product markets?
- [ ] If spillovers likely: consider donut-hole or cluster-level treatment

## Treatment Timing
- [ ] Is treatment an absorbing state (once treated, always treated)?
- [ ] Any treatment reversals? If so, standard methods may not apply.
- [ ] Treatment intensity variation? Consider continuous DiD.

## Inference
- [ ] Cluster at treatment assignment level (typically unit or group)
- [ ] How many clusters? If <50, consider wild cluster bootstrap
- [ ] Consider randomization inference for small number of treated units

## Robustness Checks
- [ ] Alternative comparison group (never-treated vs. not-yet-treated)
- [ ] Alternative estimator (CS vs. SA vs. BJS)
- [ ] Placebo outcome (variable that should not be affected)
- [ ] Placebo treatment timing (fake earlier treatment date)
- [ ] Bacon decomposition (for TWFE: where are the weights?)
- [ ] Goodman-Bacon (2021) diagnostic
- [ ] Leave-one-out: drop each treated cohort
- [ ] Alternative clustering levels
