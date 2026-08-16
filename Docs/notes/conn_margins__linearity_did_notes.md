# Panel DiD Linearity Defense (NCA-style)

**Date:** 2026-06-05
**Files:** `linearity_did.do`, `linearity_did_figure.py`,
`linearity_did_eventstudy_plot.py`, `generate_linearity_did_latex.py`

## Motivation

The earlier linearity exercise (`linearity_binstest.do`, `linearity_fig3_binsreg_corrected.py`)
tested the wrong object: a cross-section of the 2011 wage **level** on connectivity.
The main estimand is a DiD, so the relevant null is linearity of the *treatment
effect* in connectivity, after removing the same variation used for identification
— the analogue of the linearity test in the non-compete (NCA) enforceability paper.

Baseline spec being defended (`conn_margins.do`, Exercise 2, intensive margin):

```
reghdfe Y c.totaltreat_pw_norm##i.treat_year if s_spill_pos,
    absorb(firm + industry#year + mode#year + microregion#year
           + Y_pre4#year + l_firm_emp_pre4#year + totalflows_pre4#year)
    vce(cluster identificad)
```

The linear DiD imposes `E[Y | D, FE, X] = beta * D` with `D = Conn x Post`.

## Method (Part A)

Frisch–Waugh–Lovell residualization (firm FE forbids passing ~4,000 firm dummies
to binsreg as `w`, so the Cattaneo internal-`w` route is infeasible; residualize
instead, as the NCA paper does):

1. Residualize `Y` on `i.treat_year` + the full main-spec absorb → `yres`.
2. Residualize `D = conn_x_post` on the same → `dres`.
3. `binstest yres dres, vce(cluster firm_num) testmodelpoly(1) nsims(2000)`.

Sample is `s_spill_pos` (positively connected firms): the intensive-margin /
dose-response sample. The extensive margin (zero vs positive) is a separate binary
jump captured by `pos_conn`, not a linearity question.

### Results — all four outcomes fail to reject linearity

| Outcome | N | sup-$t$ | $p$ |
|---|---:|---:|---:|
| Log Dec. wage | 17,008 | 3.01 | 0.244 |
| Log hourly wage | 17,008 | 2.26 | 0.852 |
| Log employment | 17,120 | 2.45 | 0.711 |
| # CBA clauses | 10,273 | 2.54 | 0.664 |

Log employment moved from $p=0.083$ in the flawed 2011-level cross-section to
$p=0.711$ here: the level cross-section was conflating baseline curvature, which
the within-firm DiD object removes.

## Method (Part B) — binned vs linear event study

- Linear event study: `c.conn##ib2011.year` (ref 2011).
- Binned event study: `ib1.connbin##ib2011.year`, `connbin` = connectivity
  quintiles among positive-connectivity firms (ref Q1, ref 2011).
- Dose-response: pooled `ib1.connbin##i.treat_year` post-effects per quintile
  vs bin-mean connectivity, overlaid with the linear restriction
  `theta(c) = beta_lin * (c - c_1)`.

The binned post-effects sit within ~1 SE of the linear line; paths are anchored at
2011 with no significant divergence. The intensive-margin dose-response is weak and
noisy on this sample, but the linear functional form is not rejected.

## Reproduce

```bash
module load stata/17
stata-mp -b do Programs/conn_margins/linearity_did.do          # Parts A+B, ~2 min
~/.conda/envs/venv_python312/bin/python Programs/conn_margins/linearity_did_figure.py
~/.conda/envs/venv_python312/bin/python Programs/conn_margins/linearity_did_eventstudy_plot.py
~/.conda/envs/venv_python312/bin/python Programs/conn_margins/generate_linearity_did_latex.py
```

## Outputs

| File | Contents |
|---|---|
| `Tables/conn_margins/linearity_did_test.csv` | Part A binstest results |
| `Tables/conn_margins/linearity_did_table.tex` | LaTeX table |
| `Graphs/conn_margins/linearity_did_<outcome>.pdf` | Part A residualized binscatter |
| `Graphs/conn_margins/linearity_did_eventstudy_<outcome>.pdf` | Part B two-panel figure |

`linearity_did_lr_remdezr_w.pdf` supersedes the old
`linearity_fig3_binsreg_corrected.pdf` as the headline linearity figure.
The old `linearity_binstest.do` / `*_panel.csv` (2011 cross-section of levels)
are retained for history but should not be cited.
