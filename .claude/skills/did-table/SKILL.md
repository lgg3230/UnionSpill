---
name: did-table
description: This skill should be used when building, formatting, or regenerating a DiD/event-study regression table for the UnionSpill paper — triggered by "make a table for these results", "format this as a DiD table", "regenerate the tables", "add the placebo to the table", "put this in the paper format", or any request to turn spillover/direct regression output into LaTeX. It encodes the house layout (outcomes as columns; Post/Pre x Connectivity rows), the Stata->CSV->Python->LaTeX contract, and the cell-formatting rules.
version: 0.1.0
---

# UnionSpill DiD Table Skill

Canonical layout and build pipeline for difference-in-differences regression tables
in the UnionSpill paper. Use it whenever regression output must become a LaTeX table.

## The hard rule: Stata never writes LaTeX

**Stata writes a CSV. Python writes the LaTeX.** Never `esttab`/`outreg2` into a
`.tex`, and never hand-write a table you intend to keep. Hand-built tables drift from
the estimates the moment a spec changes.

```
Main_Results_<x>.do  ->  Tables/<pipeline>/results_spill_<x>.csv
generate_<x>_latex.py ->  Tables/<pipeline>/<x>_tables.tex
```

The `.tex` is then `\input` by the paper or a memo. Regenerating is one command, so a
re-run of the do-file always propagates.

## Data contract

Prefer the **wide** schema (one row per outcome). Stata writes it with `file write`:

```
outcome,coef,se,pval,pre_coef,pre_se,pre_pval,mean_pre,n_obs,n_estab
```

- `coef`,`se`,`pval` — the `Post x Connectivity` interaction (`c.conn##i.treat_year`).
- `pre_coef`,`pre_se` — the **pre-treatment placebo** (`c.conn##i.placebo_year`, `year<=2011`).
  Always capture `_se`, not just `_b`; the table needs it.
- `pre_pval` — joint pre-trend F-test from the event study
  (`testparm c.conn#i(2009 2010).year`), wrapped in `capture` with
  `cond(_rc==0, r(p), .)`.
- `mean_pre` — outcome mean on the estimation sample, 2009--2011.
- `n_obs`,`n_estab` — `e(N)`, `e(N_clust)`.

An older **long** schema also exists (`spec;section;outcome;row_type;value` with
`row_type` in {main, main_se, pre, pre_se, pre_pval, mean_pre, n_obs, n_estab}); see
`4210_table_turnover_latex.py` for its parser. Use wide for new work.

## Layout

**Outcomes are columns, not rows.** Row order is fixed:

```
Post $\times$ Connectivity      coef with stars
                                (se)
                                [blank spacer row]
Pre $\times$ Connectivity       placebo coef with stars
                                (se)
Pre-trend $F$-test $p$-value    [bracketed]
                                [blank spacer row]
Mean (2009--2011)
Observations
Establishments
```

Multiple specs/samples become **panels** (`\multicolumn{n+1}{l}{\textit{Panel A. ...}}`),
each carrying its own full block including its own Mean/Obs/Establishments, since those
differ across panels.

## Cell formatting

| Rule | Form |
|---|---|
| Float wrapper | `\begin{table}[]` (not `[H]`) |
| Rules | `\toprule\toprule` at top, `\midrule`, `\bottomrule` |
| Size | `\scriptsize` (twice: table body and tablenotes) |
| Wrapper | `\begin{threeparttable}` + `\begin{tablenotes}` |
| Column headers | `\begin{tabular}[c]{@{}c@{}}Line1\\Line2\end{tabular}` |
| Column numbers | a `(1) & (2) & ...` row under the headers |
| Negative numbers | `$-$0.0257` (math minus, not hyphen) |
| Thousands | `32{,}704` |
| Std. errors | `(0.0114)` |
| p-values | `[0.0852]` |
| Not applicable | `--` |
| Stars | `*** p<0.01, ** p<0.05, * p<0.10` |
| Decimals | 4 for coefficients/SEs |

Stars: from `pval` where available; for the placebo, derive from `|pre_coef/pre_se|`
against 1.645 / 1.960 / 2.576.

## Notes

Open with **"This table ..."**. State, in order: what is estimated; how each panel or
column differs; how the exposure/connectivity measure is defined and normalized; the
sample restriction; that `Post x Connectivity` is the 2012--2016 effect and
`Pre x Connectivity` is a placebo on 2009--2011; the full FE and control set; the
clustering level; the star legend. Prose style: no em-dashes, no colloquialisms.

Flag honestly in the notes anything a reader would otherwise misread: a control that is
itself an outcome (descriptive, not causal), a split that halves power, an
ill-defined denominator.

## Reference implementations

- `Programs/turnover/4210_table_turnover_latex.py` — long schema, direct + spillover, panels.
- `Programs/turnover/generate_flows_latex.py` — wide schema, multi-panel; copy this for new work.

Both share the helpers `hdr()`, `table_preamble()`, `table_postamble()`, and value
formatters. Copy them rather than importing, so each generator stays self-contained.

## Checklist

1. Do-file emits the wide CSV, including `pre_se`.
2. Generator reads only from `Tables/`; no hard-coded numbers.
3. Outcomes as columns; placebo rows present; pre-trend p bracketed.
4. Panels carry their own Mean/Obs/Establishments.
5. Notes open "This table ..." and name the FE, sample, clustering, stars.
6. Regenerate and recompile after any spec change.
