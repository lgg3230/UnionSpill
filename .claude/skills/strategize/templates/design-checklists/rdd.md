# Design Checklist: Regression Discontinuity Design

## Setup
- [ ] **Running variable:** [name and definition]
- [ ] **Cutoff:** [value and institutional basis]
- [ ] **Sharp or fuzzy?** Sharp: treatment jumps from 0 to 1 at cutoff. Fuzzy: treatment probability jumps.
- [ ] **Is the cutoff known to agents?** If so, manipulation is a concern.

## Bandwidth Selection
- [ ] **MSE-optimal bandwidth** (default): `rdrobust` with `bwselect = "mserd"`
- [ ] **CER-optimal bandwidth** (for confidence intervals): `bwselect = "cerrd"`
- [ ] Report the selected bandwidth and effective sample size
- [ ] Local polynomial order: start with linear (p=1), justify quadratic (p=2) if used

## Manipulation Testing
- [ ] **McCrary (2008) density test** or **Cattaneo, Jansson, Ma (2020) density test**
- [ ] R: `rddensity::rddensity()`
- [ ] Plot the density of the running variable around the cutoff
- [ ] If density discontinuity detected: investigate and discuss (may invalidate design)

## Covariate Balance at Cutoff
- [ ] Run RDD with each pre-determined covariate as the outcome
- [ ] None should show a discontinuity at the cutoff
- [ ] Present in a balance table
- [ ] If imbalance found: include as control or investigate

## Main Estimation
- [ ] `rdrobust` with local polynomial regression
- [ ] Report: point estimate, robust bias-corrected CI, bandwidth, effective N
- [ ] Plot: RD plot with fitted polynomial and confidence band

## Fuzzy RDD (if applicable)
- [ ] First stage: treatment probability jump at cutoff
- [ ] 2SLS with discontinuity as instrument for treatment
- [ ] Report compliance rate: how many units change treatment status at cutoff

## Inference
- [ ] Use bias-corrected robust confidence intervals from `rdrobust`
- [ ] Do NOT use conventional CIs -- they undercover
- [ ] Cluster if there's group structure in the running variable (e.g., age in years)

## Robustness Checks
- [ ] **Alternative bandwidths:** 0.5x, 0.75x, 1.25x, 1.5x of optimal
- [ ] **Donut hole:** exclude observations very close to cutoff (e.g., within 1 unit)
- [ ] **Polynomial order:** linear vs. quadratic
- [ ] **Placebo cutoffs:** run RDD at fake cutoff values (should find no effect)
- [ ] **Covariate inclusion:** results should be similar with and without controls
- [ ] **Alternative kernel:** triangular (default), uniform, Epanechnikov
- [ ] **Sensitivity to running variable measurement** (if discrete or coarsened)

## Packages
- R: `rdrobust`, `rddensity`, `rdlocrand`, `rdplot`
- Python: `rdrobust` (Python version available)

## Common Pitfalls
- Running variable is discrete with few mass points: consider `rdlocrand` (randomization inference)
- Heaping at round numbers: manipulation or measurement artifact?
- Running variable is an index you constructed: document construction transparently
- Observations exactly at the cutoff: drop or assign to treatment? (Document the choice)
