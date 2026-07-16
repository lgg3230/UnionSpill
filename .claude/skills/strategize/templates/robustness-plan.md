# Robustness Plan Template

**Purpose:** Ordered checklist of robustness checks, from most threatening to least threatening. The strategist-critic checks ordering. The coder implements every item.

---

## Template

```markdown
# Robustness Plan: [Project Name]

**Design:** [DiD / IV / RDD / SC / Event Study / Structural / Descriptive]
**Date:** [YYYY-MM-DD]

## Ordered Checks (Most Threatening First)

### Priority 1: Assumption-Threatening
Tests that directly challenge the identification assumptions.

| # | Check | Assumption Tested | Implementation | Expected Result |
|---|-------|-------------------|----------------|-----------------|
| 1 | [e.g., Pre-trends test] | [Parallel trends] | [Event study pre-period] | [Coefficients near zero] |
| 2 | [e.g., McCrary density test] | [No manipulation] | [rddensity at cutoff] | [No density discontinuity] |
| 3 | [e.g., First-stage F] | [Instrument relevance] | [F-statistic from first stage] | [F >> 10] |

### Priority 2: Specification Sensitivity
Tests that check whether results survive reasonable changes.

| # | Check | What Changes | Implementation | Expected Result |
|---|-------|-------------|----------------|-----------------|
| 4 | [Alternative controls] | [Control set] | [Add/remove covariates] | [Similar magnitude] |
| 5 | [Alternative sample] | [Sample composition] | [Drop outliers / subperiod] | [Similar results] |
| 6 | [Alternative estimator] | [Estimation method] | [CS vs. SA vs. BJS] | [Similar magnitude] |

### Priority 3: Inference Robustness
Tests that check whether statistical significance is robust.

| # | Check | What Changes | Implementation | Expected Result |
|---|-------|-------------|----------------|-----------------|
| 7 | [Alternative clustering] | [SE computation] | [State vs. county clusters] | [Similar significance] |
| 8 | [Wild cluster bootstrap] | [Inference method] | [boottest with few clusters] | [Similar p-values] |
| 9 | [Multiple testing correction] | [p-value thresholds] | [Bonferroni / BH / Romano-Wolf] | [Key results survive] |

### Priority 4: Placebo and Falsification
Tests where you should find NO effect.

| # | Check | Logic | Implementation | Expected Result |
|---|-------|-------|----------------|-----------------|
| 10 | [Placebo outcome] | [Unaffected variable] | [Same spec, different Y] | [No significant effect] |
| 11 | [Placebo timing] | [Fake treatment date] | [Shift treatment earlier] | [No significant effect] |
| 12 | [Placebo treatment] | [Wrong treatment group] | [Randomly assign treatment] | [No significant effect] |

### Priority 5: Sensitivity Analysis
Formal bounds and sensitivity diagnostics.

| # | Check | What It Measures | Implementation | Expected Result |
|---|-------|-----------------|----------------|-----------------|
| 13 | [Oster (2019) bounds] | [Selection on unobservables] | [sensemakr or manual] | [delta > 1] |
| 14 | [Rambachan-Roth] | [Pre-trends sensitivity] | [HonestDiD package] | [CIs include main estimate] |
| 15 | [Leave-one-out] | [Influential observations] | [Drop each unit/cohort] | [Stable estimates] |
```

---

## Design-Specific Defaults

### DiD
Pre-trends, placebo outcome, alternative estimator (CS vs SA), alternative comparison group, Bacon decomposition, leave-one-cohort-out, alternative clustering.

### IV
First-stage F, reduced form, LIML vs 2SLS, subset of instruments, placebo instrument, Anderson-Rubin CIs.

### RDD
Bandwidth sensitivity (0.5x to 1.5x), donut hole, polynomial order, placebo cutoffs, density test, covariate balance.

### Event Study
Pre-trends formal test, Rambachan-Roth, alternative leads/lags, alternative reference period, placebo event timing.

### Structural
Alternative functional forms, alternative estimation method, subsample stability, counterfactual sensitivity to parameters, comparison to reduced-form.

### Descriptive
Alternative construction choices, alternative data sources, temporal stability, sensitivity to outliers, subgroup consistency.
