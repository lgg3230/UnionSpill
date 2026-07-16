# Design Checklist: Descriptive / Measurement

## What You're Measuring
- [ ] **Concept:** What are you measuring? (inequality, concentration, discrimination, mobility, etc.)
- [ ] **Why existing measures are inadequate:** What's wrong with what exists?
- [ ] **Your measure's value-add:** What does it capture that others don't?
- [ ] **Measurement vs. proxy:** Be honest about the gap between concept and measure

## Construction Methodology
- [ ] **Data sources:** List all, with coverage and access details
- [ ] **Linking strategy:** If multiple sources, how are they merged? (merge keys, rates)
- [ ] **Construction steps:** Reproducible, documented, in order
- [ ] **Key decisions and justification:**
  - Thresholds (why this cutoff?)
  - Imputations (why this method?)
  - Weights (why this weighting?)
  - Aggregation level (why this unit?)
- [ ] **Sample restrictions:** Document every restriction with counts

## Validation Plan

### Internal Validation
- [ ] Consistency checks (e.g., monotonicity, bounds, accounting identities)
- [ ] Face validity: does the measure make sense for known cases?
- [ ] Distribution: any suspicious outliers, heaping, gaps?

### External Validation
- [ ] Correlation with established measures
- [ ] Expert assessment (if feasible)
- [ ] Known-group validity: does the measure distinguish groups it should?

### Benchmark Comparison
- [ ] How does your measure compare to existing ones on known cases?
- [ ] Where do measures agree? Where do they diverge? Why?
- [ ] If your measure tells a different story, is that the contribution or a problem?

### Sensitivity
- [ ] How do results change with alternative construction choices?
- [ ] Which decisions matter most for the final measure?
- [ ] Document the decision-sensitivity frontier

## Analysis Plan

### What Variation Are You Documenting?
- [ ] Cross-section (across units at a point in time)
- [ ] Time series (within units over time)
- [ ] Within-unit (panel variation)
- [ ] Combination

### Decomposition Methods
- [ ] Variance decomposition (between vs. within)
- [ ] Oaxaca-Blinder (explained vs. unexplained)
- [ ] Shift-share / Kitagawa-Oaxaca (composition vs. rates)
- [ ] Custom decomposition (document methodology)

### Conditional Correlations
- [ ] What predicts your measure? (cross-sectional correlates)
- [ ] How does the measure change over time? (trends)
- [ ] Multivariate analysis: partial correlations

### Language Discipline
- [ ] **No causal language** unless you have a design
- [ ] "associated with" not "causes"
- [ ] "predicts" not "determines"
- [ ] "correlated with" not "leads to"

## Robustness Checks
- [ ] Alternative construction choices (thresholds, weights, imputation)
- [ ] Alternative data sources (if available)
- [ ] Temporal stability (does the measure behave consistently over time?)
- [ ] Subgroup consistency (does it work similarly for different populations?)
- [ ] Sensitivity to outliers

## Referee Objections to Anticipate
- "This is just descriptive" -- explain why the facts matter (revise beliefs, enable future research)
- "Your measure is noisy / biased" -- validation evidence
- "Why not [alternative measure]?" -- comparison
- "So what?" -- implications for theory or policy
