# Pre-Strategy Report Template

**Purpose:** The strategist produces this report before proposing any strategy. It proves the discovery inputs (research spec, literature review, data assessment, domain profile) were loaded. If an input is missing, flag it -- do not silently assume.

---

## Template

```markdown
## Pre-Strategy Report

**Date:** [YYYY-MM-DD]
**Project:** [project name]

### Inputs Read
**Research spec:** [path or "not found"]
**Literature review:** [path or "not found"]
**Data assessment:** [path or "not found"]
**Domain profile:** [loaded / not found]

### Research Question
[One sentence from spec]

### Key Findings from Literature
- [What methods have been used for this question]
- [What gaps remain]
- [Key references for identification]

### Available Data
- [Dataset name] -- [key variables, coverage, access]
- [Variation available for identification]: [describe]
- [Panel structure]: [units x time periods, or cross-section]
- [Known data limitations]: [missingness, measurement error, coverage gaps]

### Candidate Designs
Based on data and domain profile, the following designs are feasible:
1. [Design 1] -- [why feasible, what variation exploited]
2. [Design 2] -- [why feasible, what variation exploited]
3. [Design 3] -- [why feasible or why not]

### Missing Inputs
- [List any missing inputs with impact on strategy design]
- [Mark ASSUMED placeholders where proceeding without input]

Proceeding to strategy design.
```

---

## Rules

1. **This report is mandatory.** The strategist-critic checks for its existence.
2. **If research spec, literature review, or data assessment are missing**, proceed with ASSUMED placeholders but flag each clearly.
3. **The candidate designs list must be honest.** Don't list designs that the data can't support.
4. **Data limitations must be stated upfront.** They constrain which designs are feasible.
