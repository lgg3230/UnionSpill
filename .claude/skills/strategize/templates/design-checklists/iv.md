# Design Checklist: Instrumental Variables

## Instrument Specification
- [ ] **Instrument(s):** [name and definition]
- [ ] **Institutional motivation:** Why does Z affect D? What's the story?
- [ ] **Is the instrument binary, discrete, or continuous?**
- [ ] **Single instrument or multiple?** If multiple: overidentification testing required

## First Stage
- [ ] Specification: $D_i = \pi_0 + \pi_1 Z_i + X_i'\gamma + \nu_i$
- [ ] First-stage F-statistic: target >> 10 (Stock-Yogo critical values)
- [ ] **Effective F** (Montiel Olea-Pflueger, 2013): more appropriate than standard F for heteroskedasticity
- [ ] Plot: visualize the first-stage relationship
- [ ] Is the first stage economically sensible? (sign, magnitude)

## Relevance (Assumption 1)
- [ ] $Cov(Z_i, D_i) \neq 0$ -- instrument predicts treatment
- [ ] First-stage F: rule of thumb F > 10, but report effective F
- [ ] If weak: Anderson-Rubin confidence intervals (robust to weak instruments)
- [ ] If weak: LIML instead of 2SLS (less finite-sample bias)

## Exclusion Restriction (Assumption 2)
- [ ] $Cov(Z_i, \varepsilon_i) = 0$ -- instrument affects outcome ONLY through treatment
- [ ] **This is not directly testable.** Make the institutional argument.
- [ ] Consider: are there other channels through which Z affects Y?
- [ ] Reduced form as supporting evidence: $Y_i = \alpha + \beta Z_i + X_i'\delta + e_i$
- [ ] If reduced form is significant, exclusion restriction is more plausible

## Monotonicity (Assumption 3, for LATE)
- [ ] No defiers: Z shifts D in the same direction for everyone
- [ ] Is this reasonable given the instrument's mechanism?
- [ ] Characterize compliers: who changes treatment status when Z changes?

## LATE Interpretation
- [ ] 2SLS estimates LATE, not ATE -- interpret accordingly
- [ ] **Who are the compliers?** Use Abadie (2003) or Angrist-Pischke characterization
- [ ] Is the LATE policy-relevant? (Would a policy change affect a similar subpopulation?)

## Specifications to Report
- [ ] **Reduced form:** $Y_i$ on $Z_i$ (and controls)
- [ ] **First stage:** $D_i$ on $Z_i$ (and controls)
- [ ] **2SLS:** $Y_i$ on $\hat{D}_i$ (and controls)
- [ ] **OLS:** $Y_i$ on $D_i$ (and controls) -- for comparison
- [ ] All four in one table is standard

## Overidentification (Multiple Instruments)
- [ ] Hansen J test / Sargan test
- [ ] Test sensitivity to dropping each instrument
- [ ] Report 2SLS with each instrument separately

## Inference
- [ ] Cluster at appropriate level
- [ ] If weak instruments: Anderson-Rubin (2SLS), or CLR (conditional likelihood ratio)
- [ ] Report confidence intervals, not just point estimates

## Robustness Checks
- [ ] Alternative instrument(s)
- [ ] Subset of instruments (if multiple)
- [ ] Reduced-form evidence
- [ ] LIML vs. 2SLS comparison
- [ ] Sensitivity to control variables
- [ ] Placebo instrument: Z should not predict placebo outcomes
- [ ] Falsification test: Z should not predict pre-treatment outcomes
