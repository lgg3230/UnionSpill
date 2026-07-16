# Notation Protocol -- Standard Economics Conventions

Notation conventions for consistency across all sections of the paper.

---

## Core Variables

| Symbol | Meaning | Usage |
|--------|---------|-------|
| $Y_{it}$ | Outcome variable | Unit $i$, time $t$ |
| $D_{it}$ | Treatment indicator | Binary or continuous treatment |
| $X_{it}$ | Control variables | Covariate vector |
| $\gamma_i$ | Unit fixed effect | Absorbs time-invariant unit heterogeneity |
| $\delta_t$ | Time fixed effect | Absorbs common time shocks |
| $\varepsilon_{it}$ | Error term | Idiosyncratic shock |

---

## Rules

- **Consistent throughout** -- the same symbol never means two things across sections
- **Define every symbol at first use** -- no implicit notation
- **Match the strategy memo** -- if the coder's naming map uses specific notation, the paper must match
- **Subscripts matter** -- $i$ for units, $t$ for time, $g$ for groups, $j$ for secondary units (firms, markets)
- **Hats for estimates** -- $\hat{\beta}$ for estimated coefficients, $\beta$ for population parameters
- **Bold for vectors/matrices** -- $\mathbf{X}$ for the control matrix, $X_{it}$ for a single observation's controls

---

## Common Estimands

| Estimand | Symbol | Definition |
|----------|--------|------------|
| Average Treatment Effect | $\text{ATE}$ | $E[Y_i(1) - Y_i(0)]$ |
| Average Treatment Effect on the Treated | $\text{ATT}$ | $E[Y_i(1) - Y_i(0) \mid D_i = 1]$ |
| Local Average Treatment Effect | $\text{LATE}$ | $E[Y_i(1) - Y_i(0) \mid \text{compliers}]$ |
| Group-time ATT | $\text{ATT}(g,t)$ | Callaway-Sant'Anna notation |
