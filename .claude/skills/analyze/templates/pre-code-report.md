# Pre-Code Report Template

**Purpose:** The coder produces this report before writing any code. It proves the strategy memo, domain profile, and coding standards were loaded. The naming map is established here, not invented mid-script.

---

## Template

```markdown
## Pre-Code Report

**Date:** [YYYY-MM-DD]
**Project:** [project name]

### Inputs Read
**Strategy memo:** [path or "not found"]
**Domain profile:** [loaded / not found]
**Coding standards:** [R / Python / Julia — loaded from .claude/references/coding-standards-{lang}.md]
**Language:** [R / Python / Julia — from CLAUDE.md, default R]
**Paper type:** [reduced-form / structural / theory+empirics / descriptive]

### Strategic Alignment
**Research question:** [one sentence from strategy memo]
**Identification strategy:** [one sentence — e.g., "staggered DiD using Callaway-Sant'Anna"]
**Estimand:** [ATT / ATE / LATE / CATE / structural parameter — from memo]

### Variable Mapping
| Paper Symbol | Code Name | Description | Source |
|-------------|-----------|-------------|--------|
| $Y_{it}$ | [name] | [outcome] | [dataset/column] |
| $D_{it}$ | [name] | [treatment] | [how constructed] |
| $X_{it}$ | [name] | [controls] | [columns] |
| $\alpha_i$ | [name] | [unit FE] | [absorbed] |
| $\gamma_t$ | [name] | [time FE] | [absorbed] |

**Naming map confirms:** [yes / no — do planned code names match paper notation?]

### Data Assessment
**Data source:** [path or description]
**Expected dimensions:** [N units x T periods, or N observations]
**Key variables available:** [list confirmed variables]
**Missing variables:** [list any variables in memo not found in data]
**Sample restrictions from memo:** [list each restriction]

### Estimation Plan
**Estimator:** [from strategy memo — e.g., "Callaway-Sant'Anna att_gt()"]
**R packages required:** [list with versions if critical]
**Clustering level:** [from memo]
**Fixed effects:** [from memo]

### Robustness Checks Required
1. [check from memo]
2. [check from memo]
3. [check from memo]

### Output Plan
**Tables:** [list planned tables with filenames]
**Figures:** [list planned figures with filenames]
**Output directory:** [Tables/ and Graphs/ — confirm by-script or by-purpose from CLAUDE.md]

### Feasibility Assessment
**Blockers:** [any issues that prevent implementation — missing data, unavailable packages, unclear spec]
**Assumptions made:** [any decisions not in the memo that require judgment]

Proceeding to implementation.
```

---

## Rules

1. **This report is mandatory.** The coder-critic checks for its existence.
2. **If strategy memo is missing**, proceed with user's description but flag: "No memo found. Strategic alignment checks (coder-critic categories 1-3) cannot be verified."
3. **If data is missing or inaccessible**, stop and report the blocker. Do not generate placeholder analysis.
4. **The variable mapping becomes the naming map** in `01_setup.R`. No deviations allowed downstream.
5. **Feasibility issues are reported here**, not discovered mid-implementation.
