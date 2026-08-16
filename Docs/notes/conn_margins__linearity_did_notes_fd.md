# First-Difference Linearity Defense (canonical)

**Date:** 2026-06-08
**Files:** `linearity_did_fd.do`, `linearity_did_fd_figure.py`,
`generate_linearity_did_fd_latex.py`

## What this defends

The headline spillover DiD (Main_Results PART D / conn_margins) is, on the
spillover sample `s_spill` (untreated firms in the balanced panel):

```
Y_jt = beta*(Conn_j x Post_t) + firm FE + group-by-year FE + controls + e_jt
```

The linear specification imposes that the dose-response `f(Conn) = beta*Conn`.
This pipeline tests that null with the Cattaneo, Crump, Farrell & Feng (2024)
sup-norm `binstest`, applied **directly** with internal covariate adjustment —
no pre-residualization (their "Problem 1").

## Why a first difference (and why it is exact)

Firm fixed effects make the internal-`w` covariate adjustment infeasible in the
panel (~8,000 dummies; `binstest` ran >40 min/outcome). The first difference
removes them analytically. Define, per firm,

```
dY_j = mean(Y, 2012-2016) - mean(Y, 2009-2011)
```

For a balanced panel the within-firm/within-year residualized treatment is
`(Conn_j - Conn_bar)(Post_t - Pbar)`, and the post/pre weights cancel, so the
two-way-FE coefficient **equals the OLS slope of `dY_j` on `Conn_j`** (with a
constant). The panel's group-by-year FEs reduce, after differencing, to plain
group dummies. So the linearity test runs on a one-row-per-firm cross-section
with only ~510 covariates, passed to binsreg/binstest as `w`.

### Validation (Main_Results PART D, replicated in Stata)

| outcome | panel beta | FD beta | diff | se ratio |
|---|---:|---:|---:|---:|
| lr_remdezr_w | 0.005070 | 0.005089 | -1.8e-05 | 1.001 |
| lr_remdezr_h_w | 0.006636 | 0.006668 | -3.2e-05 | 1.001 |
| l_firm_emp | 0.000412 | 0.000412 | +1.6e-09 | 1.000 |

Point estimates match to machine precision (employment) / ~1e-5 (wages, from a
few firm-years missing in the wage panel). **Standard errors agree to the third
decimal**: because `Conn_j` is time-invariant, the within-firm serial
correlation the panel `vce(cluster)` handles is fully captured by the collapse,
so the cluster-robust panel SE equals the cross-sectional robust SE.

**Gotcha that cost an afternoon:** the FD must use mean-of-logs on both ends.
`l_firm_emp_pre` had been overwritten to `ln(mean(firm_emp))` (log-of-mean) for
use as a bin control; subtracting that from `mean(l_firm_emp)` (mean-of-logs)
broke the employment match (diff 1e-3). The do-file builds dedicated
`_fdpre`/`_fdpost` means straight from the outcome to avoid reusing controls.

## Results (full spillover sample, internal-w binstest)

| Outcome | N | bins | sup-$t$ | $p$ |
|---|---:|---:|---:|---:|
| Log Dec. wage | 4,188 | 28 | 2.15 | 0.132 |
| Log hourly wage | 4,188 | 28 | 1.76 | 0.271 |
| Log employment | 4,195 | 28 | 0.88 | 0.802 |
| # CBA clauses | 3,977 | 29 | 1.46 | 0.449 |

All fail to reject linearity. Bins drop 50 -> ~28 because connectivity has a
mass at 0 (unconnected firms); `masspoints(nolocalcheck)` handles it, and the
figure uses the same option so its bin count matches the test.

## Figure

`linearity_did_fd_<outcome>.pdf`: covariate-adjusted binscatter of `dY_j` on
connectivity (95% uniform CB) with the OLS line overlaid. The OLS slope equals
the panel spillover coefficient by construction (0.0051 for log wage). The
annotated p-value is the Stata `binstest` on the identical cross-section.

## Reproduce

```bash
module load stata/17
stata-mp -b do Programs/conn_margins/linearity_did_fd.do          # ~1 min
~/.conda/envs/venv_python312/bin/python Programs/conn_margins/linearity_did_fd_figure.py
~/.conda/envs/venv_python312/bin/python Programs/conn_margins/generate_linearity_did_fd_latex.py
```

## Relationship to other files

- Supersedes the residualized Part A formerly in `linearity_did.do` (now a
  pointer note) and the deleted `linearity_did_figure.py` /
  `generate_linearity_did_latex.py` / `linearity_did_<outcome>.pdf`.
- `linearity_did.do` PART B (linear vs binned event study) is unchanged and
  still valid (panel `reghdfe`, not a binscatter).
