# Strategy Memo Template

**Purpose:** The primary output of the strategist. Contains the full identification strategy specification. Must include all five required sections: Estimand, Specification, Assumptions, Robustness Plan, Threats.

---

## Template

```markdown
# Strategy Memo: [Project Name]

**Date:** [YYYY-MM-DD]
**Paper type:** [reduced-form / structural / theory+empirics / descriptive]
**Primary design:** [DiD / IV / RDD / SC / Event Study / Selection-on-Observables / Structural / Descriptive]

---

## 1. Estimand

**What are we estimating?**
- Formal estimand: [e.g., $ATT(g,t) = E[Y_t(1) - Y_t(0) | G_i = g]$]
- In words: [e.g., "The average effect of treatment on the treated, for units first treated in period g, at time t"]
- Population: [who does this apply to?]
- If LATE: characterize the compliers

## 2. Specification

**Primary specification:**
$$
Y_{it} = \alpha_i + \gamma_t + \beta D_{it} + X_{it}'\delta + \varepsilon_{it}
$$

**Variables:**
| Symbol | Name | Definition | Source |
|--------|------|-----------|--------|
| $Y_{it}$ | [outcome] | [precise definition] | [data source] |
| $D_{it}$ | [treatment] | [precise definition -- when switches on, for whom] | [constructed how] |
| $X_{it}$ | [controls] | [list each control variable] | [data source] |
| $\alpha_i$ | [unit FE] | [unit fixed effects] | [absorbed] |
| $\gamma_t$ | [time FE] | [time fixed effects] | [absorbed] |

**Estimator:** [e.g., Callaway-Sant'Anna att_gt() with never-treated as comparison]
**Clustering:** [level and justification]
**Sample:** [inclusion/exclusion criteria]

**Pseudo-code:**
```r
# [Implementation sketch -- not production code, but precise enough for the coder]
model <- att_gt(
  yname = "outcome",
  tname = "year",
  idname = "unit_id",
  gname = "group",
  data = df,
  control_group = "nevertreated"
)
```

## 3. Assumptions

For each assumption:
- **Statement:** [formal or semi-formal]
- **Interpretation:** [what it rules out in plain language]
- **Testable implication:** [how to check, or "not directly testable"]
- **Credibility:** [why we believe this holds in our setting]

### Assumption 1: [e.g., Parallel Trends]
- Statement: $E[Y_t(0) - Y_{t-1}(0) | G_i = g] = E[Y_t(0) - Y_{t-1}(0) | G_i = \infty]$ for all $g, t$
- Interpretation: Absent treatment, treated and control units would have followed parallel outcome paths
- Testable implication: Pre-treatment trends should be parallel (event study pre-period coefficients)
- Credibility: [institutional argument for why this holds]

### Assumption 2: [e.g., No Anticipation]
- Statement: [formal]
- Interpretation: [plain language]
- Testable implication: [how to check]
- Credibility: [why believable]

### Assumption 3: [e.g., SUTVA / No Spillovers]
- Statement: [formal]
- Interpretation: [plain language]
- Testable implication: [how to check]
- Credibility: [why believable]

## 4. Robustness Plan

Ordered from most threatening to least threatening:

| Priority | Check | What It Tests | Expected Result |
|----------|-------|---------------|-----------------|
| 1 | [Pre-trends test] | [Parallel trends assumption] | [Pre-period coefficients near zero] |
| 2 | [Placebo outcome] | [Spurious correlation] | [No effect on unaffected outcome] |
| 3 | [Alternative estimator] | [Sensitivity to method] | [Similar magnitude] |
| 4 | [Alternative clustering] | [Inference robustness] | [Similar significance] |
| 5 | [Alternative sample] | [Sample composition effects] | [Similar results] |

## 5. Threats

**Top 5 referee objections and pre-planned responses:**

1. **[Objection]:** [what a referee would say]
   - **Response:** [test or argument]
   - **Pre-planned analysis:** [specific robustness check]

2. **[Objection]:** [what a referee would say]
   - **Response:** [test or argument]

3. ...
4. ...
5. ...

---

## Secondary Analyses

### Heterogeneity
- [Subgroup 1]: [justification for this split]
- [Subgroup 2]: [justification]

### Mechanism / Channel
- [Mechanism test 1]: [what it shows]
- [Mechanism test 2]: [what it shows]
```
