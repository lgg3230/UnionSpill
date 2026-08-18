# Mincer residuals — dataset construction

Produces the residual files that `Programs/analysis/residuals/3112_mincer.do`
imports. Restored from `archive/` and from orphaned git objects on 2026-08-16.

**The published run uses the whole-RAIS variant.** `3111_mincer.do:31` sets
`resid_csv_name = mincer_residuals_firm_year_age_fullrais_rb.csv`, produced by
`2085_residualize_fullrais.py`.

## Two independent branches

Numbering is dependency order. The two branches do not depend on each other; they
are ordered Lagos-first only for readability.

### Lagos-sample branch (earlier variant, still referenced as 3112's default)

| script | reads | writes |
|---|---|---|
| `2080_mincer_residuals.py` | `worker_panel_lagos.parquet` | `mincer_residuals_firm_year.csv` |
| `2081_mincer_residuals_pyfixest.py` | `worker_panel_lagos.parquet` | `..._firm_year_python.csv` (cross-check of 2080) |
| `2082_mincer_export.py` | `worker_panel_lagos.parquet` | `worker_panel_mincer.dta` |
| `2083_mincer_residuals.do` | **`worker_panel_mincer.dta`** | `mincer_residuals_firm_year.csv` (Stata route) |

`2080`, `2081` and `2082` all read the parquet directly and are siblings. Only
`2083` has a real predecessor: it consumes `2082`'s `.dta`, which is why it sits
after it.

### Whole-RAIS branch (published)

| script | reads | writes |
|---|---|---|
| `2084_build_panel_fullrais.py` | raw RAIS 2009-2016 | `fullrais_panel/worker_panel_fullrais_{year}.parquet` |
| `2085_residualize_fullrais.py` | those parquets | `mincer_residuals_firm_year_age_fullrais_rb.csv` |
| `2086_safeguards_fullrais.py` | both | validation |

`2084` is the same construction as `2051_worker_panel_lagos.py` **without** the
sample-establishment filter, so the residual cells are estimated over the whole
national labour market. Its own docstring states this.

The comparison table that used to live here is an exhibit, not sample
construction; it is now `analysis/residuals/4230_table_resid_tenure_comparison.py`.

## Verification, 2026-08-16

`2085` run over `2084`'s output reproduces the published residual file:

```
rows 139,951 vs 139,951 | keys: 139,951 both, 0 either-only
n_workers_lr_remdezr / _lr_hourly : 0 rows differing
lr_remdezr_mean / lr_hourly_mean  : 0 rows above 1e-6 (max rel 3.6e-16)
lr_remdezr_resid : median abs diff 1.75e-06, corr 0.99999976
```

The sample is bit-identical. The residuals differ at ~4e-06 of the published
series' own standard deviation, tracing to 10,504 rows of 44.4M (0.024%) where the
rebuilt panel differs from the copy on disk — the `tempempr`-recovered-from-
`dtadmissao` step is the main suspect, since it touches 895,460 rows.

⚠ Rescale age/50 and tenure/120 before taking powers. Without it the design matrix
conditions at ~2e11 and the residual mean comes out 0.054 rather than 0;
`2086_safeguards_fullrais.py` catches this. `min_obs = 10` for the 9-parameter
model, 6 for the 5-parameter `--mode age` used in the published run.
