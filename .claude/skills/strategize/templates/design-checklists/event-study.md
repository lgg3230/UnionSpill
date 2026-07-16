# Design Checklist: Event Study

## Setup
- [ ] **Event definition:** What constitutes the event? When does it occur?
- [ ] **Treatment timing:** Is there a single event date or staggered adoption?
- [ ] **Leads/lags:** How many pre-treatment and post-treatment periods?
- [ ] **Reference period:** Which period is normalized to zero? (Typically t=-1)

## Specification

Standard event study:
$$
Y_{it} = \alpha_i + \gamma_t + \sum_{e \neq -1} \delta_e \cdot \mathbf{1}[t - G_i = e] + X_{it}'\beta + \varepsilon_{it}
$$

- [ ] Unit fixed effects ($\alpha_i$)
- [ ] Time fixed effects ($\gamma_t$)
- [ ] Relative time indicators ($e$): leads and lags
- [ ] Reference period omitted (e.g., $e = -1$)
- [ ] Controls ($X_{it}$) if any

## Staggered Treatment

If treatment timing varies across units, a heterogeneity-robust estimator is required:

| Estimator | Approach | R Package |
|-----------|----------|-----------|
| Callaway-Sant'Anna (2021) | Group-time ATT, aggregate to event time | `did::att_gt()` + `aggte(type = "dynamic")` |
| Sun-Abraham (2021) | Interaction-weighted | `fixest::sunab()` |
| Borusyak-Jaravel-Spiess (2024) | Imputation | `didimputation` |

**Never use naive TWFE event study with staggered treatment** -- it produces contaminated estimates (pre-treatment coefficients can be non-zero even if parallel trends holds).

## Endpoint Binning
- [ ] Bin distant leads: combine $e \leq -L$ into a single indicator
- [ ] Bin distant lags: combine $e \geq K$ into a single indicator
- [ ] Binning avoids multicollinearity and stabilizes estimates at extremes
- [ ] Report which periods are binned

## Pre-Trends Assessment
- [ ] **Visual:** Are pre-period coefficients close to zero?
- [ ] **Formal test:** Joint F-test that all pre-period coefficients = 0
- [ ] **Interpretation:** Pre-trends failure invalidates parallel trends assumption
- [ ] **Nuance:** Absence of pre-trends does not prove parallel trends (power concern)
- [ ] **Rambachan-Roth (2023) sensitivity analysis:** honest confidence intervals under violations of parallel trends. R: `HonestDiD`

## Post-Treatment Dynamics
- [ ] Are effects immediate or gradual?
- [ ] Is there a level shift or a trend change?
- [ ] Do effects persist, fade, or grow over time?
- [ ] Interpretation depends on the mechanism

## Inference
- [ ] Cluster at unit level (or treatment assignment level)
- [ ] Wild cluster bootstrap if <50 clusters
- [ ] Simultaneous confidence bands (sup-t, Rambachan-Roth) for joint inference across event-time coefficients

## Presentation
- [ ] Plot: point estimates with 95% CIs by event time
- [ ] Horizontal line at zero
- [ ] Vertical line at treatment onset (between $e=-1$ and $e=0$)
- [ ] Clear axis labels: "Periods Relative to Treatment" on x-axis

## Robustness Checks
- [ ] Alternative reference period (e.g., $e=-2$ instead of $e=-1$)
- [ ] Alternative number of leads/lags
- [ ] Alternative estimator (if staggered: CS vs. SA vs. BJS)
- [ ] Placebo event: fake treatment timing
- [ ] Rambachan-Roth honest CIs under trend violations
- [ ] Exclude always-treated units
- [ ] Alternative comparison group (never-treated vs. not-yet-treated)
