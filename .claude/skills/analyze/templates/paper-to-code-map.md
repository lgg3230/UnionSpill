# Paper-to-Code Naming Map

**Purpose:** Establish a 1:1 mapping between the paper's mathematical notation and the code's variable names. Every symbol in the manuscript has exactly one code name. This map is produced in the Pre-Code Report, included as a comment block in `01_setup.R`, and reproduced in `results_summary.md`.

---

## Template

Copy this into `01_setup.R` as a comment block and fill in project-specific entries:

```r
# ============================================================
# Paper-to-Code Naming Map
# ============================================================
# Paper Symbol       | Code Name        | Description                | Source
# ----------------------------------------------------------------
# $Y_{it}$           | outcome          | [outcome variable]         | [dataset/column]
# $D_{it}$           | treatment        | [treatment indicator 0/1]  | [how constructed]
# $X_{it}$           | controls         | [control vector]           | [columns]
# $\alpha_i$         | fe_unit          | Unit fixed effect           | [absorbed]
# $\gamma_t$         | fe_time          | Time fixed effect           | [absorbed]
# $\hat{\beta}$      | beta_hat         | [main coefficient of interest] | [estimated]
# $ATT(g,t)$         | att_gt           | Group-time ATT             | [estimated]
# $G_i$              | group            | Treatment cohort year       | [constructed from]
# $\varepsilon_{it}$ | —                | Error term (not in code)    | —
# ============================================================
```

---

## Rules

1. **Every symbol that appears in the paper's equations gets a row.** Error terms can be marked "not in code."
2. **Code names use snake_case.** No camelCase, no dots-in-names.
3. **The Source column documents provenance.** Where does this variable come from? Raw data column? Constructed how?
4. **Match is exact.** If the paper calls it $D_{it}$, the code variable is `treatment` (or `treat` — pick one and stick with it). Never `treated`, `Treatment`, `is_treated`, and `treat` in different scripts.
5. **The map is established in the Pre-Code Report** before any code is written. Mid-script name invention is a coder-critic deduction.
6. **Include in results summary.** The writer agent reads this map to connect code output to paper claims.

---

## Design-Specific Extensions

### DiD / Event Study
| Paper Symbol | Code Name | Description |
|-------------|-----------|-------------|
| $G_i$ | `group` | Treatment cohort (year of first treatment) |
| $C$ | `never_treated` | Never-treated indicator |
| $ATT(g,t)$ | `att_gt` | Group-time average treatment effect |
| $\delta_e$ | `es_coef` | Event-study coefficient at relative time $e$ |

### IV
| Paper Symbol | Code Name | Description |
|-------------|-----------|-------------|
| $Z_i$ | `instrument` | Instrument variable |
| $\hat{D}_i$ | `d_hat` | Predicted treatment from first stage |
| $\beta_{2SLS}$ | `beta_2sls` | 2SLS estimate |
| $\beta_{RF}$ | `beta_rf` | Reduced-form estimate |

### RDD
| Paper Symbol | Code Name | Description |
|-------------|-----------|-------------|
| $X_i$ | `running_var` | Running variable |
| $c$ | `cutoff` | RDD cutoff value |
| $h$ | `bandwidth` | Bandwidth (MSE-optimal or CER-optimal) |
| $\tau_{RD}$ | `tau_rd` | RD treatment effect at cutoff |

### Structural
| Paper Symbol | Code Name | Description |
|-------------|-----------|-------------|
| $\theta$ | `theta` | Structural parameter vector |
| $u(\cdot)$ | `utility_fn` | Utility function |
| $\pi(\cdot)$ | `profit_fn` | Profit function |
| $m(\theta)$ | `model_moments` | Model-predicted moments |
| $\hat{m}$ | `data_moments` | Data moments |
