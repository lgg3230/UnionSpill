# OSF Pre-Registration Template

**Registry:** [OSF Registries](https://osf.io/registries/)
**Format:** Flexible. Good for observational studies, natural experiments, and archival research.
**Versioning:** Supports iterative updates with version history.

---

## 1. Study Information

### Title
[Study title]

### Authors
[Full author list]

### Description
[Abstract: what you plan to do and why. 300 words or fewer.]

### Hypotheses
List each hypothesis with a number. Specify direction (one-sided or two-sided).

1. **H1:** [hypothesis]
   - Direction: [positive / negative / two-sided]
   - Rationale: [brief justification]

2. **H2:** [hypothesis]
   - Direction: [positive / negative / two-sided]
   - Rationale: [brief justification]

---

## 2. Design Plan

### Study type
- [ ] Experiment (including field and lab)
- [ ] Observational study
- [ ] Natural experiment / quasi-experiment
- [ ] Meta-analysis
- [ ] Other: [specify]

### Is this research blinded?
[No blinding / Single-blind / Double-blind]

### Study design
[Describe the research design: between-subjects, within-subjects, mixed, etc. For observational: describe the data structure and comparison strategy.]

### Randomization (if applicable)
[How treatment is assigned. For observational studies: describe the source of exogenous variation.]

---

## 3. Sampling Plan

### Existing data
- [ ] Registration prior to creation of data
- [ ] Registration prior to any human observation of the data
- [ ] Registration prior to accessing the data
- [ ] Registration prior to analysis of the data
- [ ] Registration after analysis of the data (explain rationale)

### Data collection procedures
[How data will be collected / accessed. For archival: describe the dataset, coverage, and access procedure.]

### Sample size
[Planned sample size and justification]

### Sample size rationale
[Power analysis or other justification. Include assumptions.]

### Stopping rule
[When will data collection stop? For archival: what determines the sample boundary?]

---

## 4. Variables

### Manipulated / treatment variables
[For experiments: what is manipulated. For observational: what is the treatment or exposure.]

### Measured / outcome variables
[List all outcome variables with measurement details.]

| Variable | Measurement | Type |
|----------|-------------|------|
| [Y1] | [how measured] | Primary |
| [Y2] | [how measured] | Secondary |

### Control variables
[List all control variables and justification for inclusion.]

### Indices / constructed variables
[If you plan to construct composite measures: describe the construction method.]

---

## 5. Analysis Plan

### Statistical models
[For each hypothesis, specify the statistical test or model.]

**H1 test:**
$$
Y_i = \alpha + \beta D_i + X_i'\gamma + \varepsilon_i
$$
- Estimator: [OLS / 2SLS / DiD / RDD / etc.]
- Standard errors: [robust / clustered at {level}]
- Fixed effects: [list]

**H2 test:**
[same structure]

### Identification strategy (observational studies)
- Source of variation: [describe]
- Key assumption: [state]
- Why credible: [justify]
- Threats: [list]

### Transformations
[Any planned variable transformations: log, standardize, winsorize, etc.]

### Inference criteria
- Significance threshold: [0.05 / 0.01 / other]
- Multiple testing correction: [method, if applicable]
- One-sided vs. two-sided: [specify for each hypothesis]

### Exclusion criteria
[Rules for excluding observations from analysis. Specify before seeing data.]

### Missing data
[How missing data will be handled: listwise deletion, imputation, bounds.]

### Exploratory analysis
[Any analyses that are NOT pre-specified. Label clearly as exploratory.]

---

## 6. Observational Study Adaptations

*(Include this section for non-experimental designs)*

### Source of exogenous variation
[What creates the "as-if random" variation in treatment?]

### Comparison group
[Who is compared to whom and why?]

### Identification assumptions
| Assumption | Statement | Credibility | Test |
|-----------|-----------|-------------|------|
| [A1] | [formal/informal] | [why believable] | [how to check] |

### Placebo and falsification tests
| Test | Logic | Expected result |
|------|-------|-----------------|
| [Placebo outcome] | [should not be affected] | [null effect] |
| [Placebo timing] | [fake treatment date] | [null effect] |

### Pre-committed specification choices
- Bandwidth: [value or selection method]
- Functional form: [linear / polynomial / nonparametric]
- Sample restrictions: [list, committed before seeing results]

---

## 7. Deviations Log

| Date | Deviation | Reason | Impact |
|------|-----------|--------|--------|
| | [to be filled post-registration] | | |
