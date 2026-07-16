# AEA RCT Registry -- Pre-Analysis Plan Template

**Registry:** [AEA RCT Registry](https://www.socialscienceregistry.org/)
**Requirement:** Must be registered BEFORE intervention begins.
**Format:** Most structured format. All fields required.

---

## 1. Title and Authors

**Title:** [Study title]
**Authors:** [Full author list with affiliations]
**Registration date:** [YYYY-MM-DD]
**Pre-analysis plan date:** [YYYY-MM-DD]

---

## 2. Study Information

**Abstract:** [150 words or fewer describing the study]
**Registration category:** [RCT / Cluster-RCT / Natural experiment]
**Keywords:** [list]
**JEL codes:** [list]

**IRB information:**
- IRB institution: [name]
- IRB approval number: [number]
- IRB approval date: [date]

**Funding sources:** [list all]
**Acknowledging or original data:** [describe data sources]

---

## 3. Hypotheses

### Primary hypotheses
1. **H1:** [precise, falsifiable statement]
2. **H2:** [precise, falsifiable statement]

### Secondary hypotheses
3. **H3:** [precise, falsifiable statement]
4. **H4:** [precise, falsifiable statement]

---

## 4. Design

### Experimental design
- **Treatment arms:** [describe each arm]
- **Randomization method:** [individual / cluster / stratified / blocked]
- **Randomization unit:** [individual / household / village / firm]
- **Blocking/stratification variables:** [list]
- **Assignment mechanism:** [lottery / random number generator / other]

### Sample
- **Target population:** [description]
- **Sample size:** [N per arm, total N]
- **Eligibility criteria:** [inclusion/exclusion rules]
- **Recruitment:** [how participants are recruited]

---

## 5. Outcomes

### Primary outcomes
| Variable | Measurement | Data source | Timing |
|----------|-------------|-------------|--------|
| [Y1] | [how measured] | [survey / admin / other] | [when measured] |
| [Y2] | [how measured] | [survey / admin / other] | [when measured] |

### Secondary outcomes
| Variable | Measurement | Data source | Timing |
|----------|-------------|-------------|--------|
| [Y3] | [how measured] | [survey / admin / other] | [when measured] |

### Mechanism variables
| Variable | Measurement | Channel tested |
|----------|-------------|---------------|
| [M1] | [how measured] | [which mechanism] |

---

## 6. Estimating Equations

**Primary specification:**
$$
Y_{it} = \alpha + \beta T_i + X_i'\gamma + \varepsilon_{it}
$$

- $Y_{it}$: [outcome]
- $T_i$: [treatment indicator]
- $X_i$: [controls / stratification variables]
- Clustering: [level]
- Standard errors: [robust / clustered at {level}]

**Heterogeneous effects:**
$$
Y_{it} = \alpha + \beta_1 T_i + \beta_2 T_i \times H_i + \beta_3 H_i + X_i'\gamma + \varepsilon_{it}
$$

- $H_i$: [heterogeneity dimension -- gender, baseline value, etc.]

---

## 7. Subgroup Analyses

| Subgroup | Justification | Pre-specified? |
|----------|---------------|---------------|
| [Gender] | [theoretical reason] | Yes |
| [Baseline outcome] | [heterogeneity in treatment effects] | Yes |

---

## 8. Multiple Testing

- **Number of primary outcomes:** [N]
- **Correction method:** [Bonferroni / Benjamini-Hochberg / Romano-Wolf]
- **Family structure:** [which outcomes are grouped into families]
- **Adjusted significance level:** [if Bonferroni: 0.05/N]

---

## 9. Power Calculations

| Parameter | Value | Source |
|-----------|-------|--------|
| Significance level ($\alpha$) | 0.05 | Standard |
| Power ($1-\beta$) | 0.80 | Standard |
| Minimum detectable effect (MDE) | [value] | [calibration source] |
| Baseline mean | [value] | [data source] |
| Baseline SD | [value] | [data source] |
| ICC (if clustered) | [value] | [data source] |
| Sample size per arm | [N] | |
| Total sample size | [N] | |

**Sensitivity:** MDE at power 0.80 for alternative sample sizes:
| N per arm | MDE |
|-----------|-----|
| [N1] | [MDE1] |
| [N2] | [MDE2] |

---

## 10. Data and Analysis

- **Software:** [R / Python / Julia]
- **Analysis scripts:** [will be deposited at {location}]
- **Data availability:** [public / restricted / embargoed until {date}]
- **Attrition handling:** [bounds / Lee bounds / inverse probability weighting]
- **Outlier treatment:** [winsorize at {percentile} / trim / robust regression]
- **Missing data:** [listwise deletion / imputation method]

---

## 11. Timeline

| Milestone | Date |
|-----------|------|
| Registration | [date] |
| Baseline data collection | [date] |
| Intervention start | [date] |
| Intervention end | [date] |
| Endline data collection | [date] |
| Analysis | [date] |

---

## 12. Deviations Log

| Date | Deviation | Reason | Impact |
|------|-----------|--------|--------|
| | [empty -- to be filled post-registration] | | |
