# EGAP Pre-Analysis Plan Template

**Registry:** [EGAP Registry](https://egap.org/registry/)
**Focus:** Development economics and political science.
**Requirements:** Emphasizes heterogeneous effects, governance context, and ethics.

---

## 1. Background and Context

### Research question
[What is the central question?]

### Motivation
[Why is this question important? What policy relevance does it have?]

### Theoretical framework
[What theory or mechanism motivates the hypotheses? Keep brief but specific.]

### Governance / institutional context
[Describe the political/institutional setting. EGAP requires this context.]

---

## 2. Hypotheses

Number each hypothesis. For each:
- **Statement:** [precise, falsifiable]
- **Direction:** [positive / negative / two-sided]
- **Mechanism:** [what channel generates this prediction]
- **Priority:** [primary / secondary / exploratory]

1. **H1 (Primary):** [hypothesis]
2. **H2 (Primary):** [hypothesis]
3. **H3 (Secondary):** [hypothesis]

---

## 3. Research Design

### Design type
[RCT / cluster-RCT / natural experiment / regression discontinuity / etc.]

### Treatment arms
| Arm | Description | N (planned) |
|-----|-------------|-------------|
| Control | [description] | [N] |
| Treatment 1 | [description] | [N] |
| Treatment 2 (if applicable) | [description] | [N] |

### Randomization
- **Unit:** [individual / household / village / district]
- **Method:** [public lottery / computer-generated / stratified]
- **Stratification variables:** [list]
- **Blocking:** [describe if used]

### Implementing partners
[Who implements the intervention? Describe their role and capacity.]

### Field conditions
[Relevant logistical, political, or environmental factors that may affect implementation.]

---

## 4. Data and Measurement

### Data sources
| Source | Variables | Timing | Access |
|--------|-----------|--------|--------|
| [Baseline survey] | [list] | [date] | [own collection] |
| [Administrative data] | [list] | [ongoing] | [partner access] |
| [Endline survey] | [list] | [date] | [own collection] |

### Primary outcomes
| Variable | Measurement | Expected direction | MDE |
|----------|-------------|-------------------|-----|
| [Y1] | [how measured, scale] | [positive / negative] | [size] |
| [Y2] | [how measured, scale] | [positive / negative] | [size] |

### Secondary outcomes
[Same format as primary]

### Heterogeneous treatment effects
EGAP emphasizes pre-specification of heterogeneity:

| Dimension | Justification | Expected pattern |
|-----------|---------------|-----------------|
| [Gender] | [theory-based reason] | [larger for women because...] |
| [Baseline outcome] | [diminishing returns argument] | [larger for low-baseline units] |
| [Political affiliation] | [governance-specific reason] | [differential by party] |

---

## 5. Estimation

### Primary specification
$$
Y_{it} = \alpha + \beta T_i + S_i'\gamma + \varepsilon_{it}
$$

- $T_i$: treatment indicator
- $S_i$: stratification variables (always included)
- Clustering: [at randomization unit level]

### Heterogeneous effects specification
$$
Y_{it} = \alpha + \beta_1 T_i + \beta_2 T_i \times H_i + \beta_3 H_i + S_i'\gamma + \varepsilon_{it}
$$

### Estimation method
[OLS / ANCOVA / Poisson / logistic / etc.]

### Standard errors
[Clustered at {level} / robust / randomization inference]

---

## 6. Power Analysis

| Parameter | Value | Source |
|-----------|-------|--------|
| Significance ($\alpha$) | 0.05 | |
| Power ($1-\beta$) | 0.80 | |
| MDE | [value, in SD units and natural units] | |
| Baseline mean/proportion | [value] | [source] |
| ICC (if clustered) | [value] | [source or prior studies] |
| Take-up rate (if applicable) | [value] | [pilot or prior] |
| Attrition rate (expected) | [value] | [prior studies] |

### Sensitivity
Show MDE for alternative assumptions:
- At 90% power: MDE = [value]
- With 20% attrition: MDE = [value]
- With lower take-up: MDE = [value]

---

## 7. Multiple Testing

- **Number of primary hypotheses:** [N]
- **Family structure:** [which hypotheses are grouped]
- **Correction method:** [Romano-Wolf (preferred for EGAP) / Bonferroni / BH]
- **Pre-analysis plan for exploratory outcomes:** [clearly labeled, no correction applied]

---

## 8. Threats and Mitigation

| Threat | Likelihood | Mitigation |
|--------|-----------|-----------|
| Attrition | [low/med/high] | [Lee bounds / IPW / follow-up protocol] |
| Non-compliance | [low/med/high] | [ITT as primary, IV for LATE] |
| Spillovers | [low/med/high] | [geographic buffer / measurement] |
| Political interference | [low/med/high] | [partner agreement / contingency] |
| Hawthorne effects | [low/med/high] | [blinding / control group design] |

---

## 9. Ethics

- **IRB approval:** [institution, number, date]
- **Informed consent:** [procedure]
- **Data protection:** [anonymization, storage, access]
- **Harm assessment:** [potential harms and protections]
- **Community engagement:** [how communities are involved in design]

---

## 10. Timeline

| Milestone | Date |
|-----------|------|
| EGAP registration | [date] |
| Baseline | [date] |
| Intervention | [start -- end] |
| Endline | [date] |
| Analysis and write-up | [date] |

---

## 11. Deviations Log

| Date | Deviation | Reason | Impact |
|------|-----------|--------|--------|
| | [to be filled post-registration] | | |
