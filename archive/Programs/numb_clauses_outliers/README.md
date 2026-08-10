# numb_clauses_outliers

Focused pipeline for the `numb_clauses` spillover pre-trend outlier question.

## Definition

- Sample used to define outliers: untreated establishments in the Lagos balanced-panel spillover sample, restricted to the `cba_period == 1` cross-section.
- Firm-level outlier score: `numb_clauses` in `cba_period == 1`.
- Top 1% outlier flag: firms with `cba_period == 1` `numb_clauses` at or above the 99th percentile of that cross-sectional distribution.
- Prefix check: the first 8 digits of `identificad`.

## Outputs

- `Tables/numb_clauses_outliers/top1_numb_clause_firms.csv`: top-1% firms.
- `Tables/numb_clauses_outliers/top1_numb_clause_prefix_summary.csv`: first-8-digit concentration among top-1% firms.
- `Tables/numb_clauses_outliers/spillover_clause_count_outlier_results.csv`: baseline and trimmed spillover coefficients for total, wage, employment, and other clause counts.
- `Tables/numb_clauses_outliers/prefix_10877926_firms.csv`: spillover firms whose `identificad` starts with `10877926`.
- `Tables/numb_clauses_outliers/period1_clause_share_gt1pct_firms.csv`: spillover firms whose `cba_period == 1` `numb_clauses` is more than 1% of all period-1 clauses.
- `Tables/numb_clauses_outliers/numb_clause_outlier_prefixes.tex`: publication-style prefix concentration table.
- `Tables/numb_clauses_outliers/numb_clause_outlier_firms.tex`: publication-style top outlier firm table.
- `Tables/numb_clauses_outliers/numb_clause_outlier_spillover_results.tex`: publication-style baseline, top-1% trimmed, and prefix-trimmed spillover coefficient table.
- `Tables/numb_clauses_outliers/labor_prefix_direct_results.csv`: direct panels A-C for labor outcomes after excluding prefix `10877926`.
- `Tables/numb_clauses_outliers/labor_prefix_spill_results.csv`: spillover effects for labor outcomes after excluding prefix `10877926`.
- `Tables/numb_clauses_outliers/labor_prefix_direct_effects.tex`: publication-style direct-effects table for labor outcomes after excluding prefix `10877926`.
- `Tables/numb_clauses_outliers/labor_prefix_spillover_effects.tex`: publication-style spillover-effects table for labor outcomes after excluding prefix `10877926`.
- `Tables/numb_clauses_outliers/labor_top1_spill_results.csv`: baseline and top-1% period-1 clause-count restricted spillover estimates for monthly wages, hourly wages, and employment.
- `Tables/numb_clauses_outliers/labor_top1_spillover_results.tex`: publication-style baseline vs top-1% restricted spillover table for labor outcomes.

## Run

```bash
bash Programs/numb_clauses_outliers/_run_numb_clauses_outliers.sh
```
