# Tier-B bridge: build the analysis panel from 1050/1060

**Status: STAGE 1 IN PROGRESS.** Investigation complete, both hypotheses resolved,
build not yet run. Stage 2 (switchover) is gated on review of the fidelity table.

## Goal

Run the main analysis from raw RAIS with no dependency on
`Data/CBA_RAIS_firm_level/lagos_sample_sep24_pct_unionexp_ext_df2.dta`, so the
paper can state that every number derives from code in this repository. The
frozen panel stays on disk as the comparison baseline; only the *dependency* goes.

## What the investigation established

**Both missing links are reconstructible, and every input is already on disk.**

| Link | Resolution | Evidence |
|---|---|---|
| `lagos_sample_sep24_pct_unionexp.dta` | `lagos_sample_sep24_pct.dta` (which `2020` itself writes at :343) joined to `union_treat_exp_sep24.dta` on `mode_union` | the join target exists (80 KB, `Data/RAIS_aux/`), built by `archive/Programs/union_treat_exp.do` from `cba_rais_firm_2007_2016.dta`, a `1040` output |
| `worker_year_pre_new_vs_nonnew_dec26.dta` | a `_w`-suffixed vintage of `lagos_sample_workers.dta`, not a distinct object | `2020` and `2030` compute the *same* percentiles by `cnpj_year`; `2020` uses bare names, `2030` uses `_w` names. Memory `reference_w_suffix_workers_panel` confirms `_w` = "built from sample workers panel" |

Inputs, all present:

```
lagos_sample_sep24.dta          320M   frozen Lagos firm panel
lagos_sample_sep24_test.dta     319M   1050's reproducible counterpart
worker_estab_all_years.dta       60G   1060 output, 357.8M obs, 38 vars
union_treat_exp_sep24.dta        80K   union exposure by mode_union
cba_rais_firm_2007_2016.dta      37G   1040 output
```

`worker_estab_all_years.dta` carries `lr_remdezr`, `lr_remmedr`, `r_remdezr_h`,
`r_remmedr_h`, `PIS`, `cnpj_year`, `identificad`, `year` -- exactly the set `2020`
keeps and the set `2030` needs under `_w` names.

## The column contract

The panel has 550 columns; the 13 estimators and the table generators reference
**59**. That set, not the 550, is what the rebuild must satisfy. Derived by
parsing the scripts with comment lines stripped.

Core (referenced by 3+ scripts):

```
year microregion industry lr_remdezr_w lr_remdezr_h_w l_firm_emp treat_ultra
in_balanced_panel lagos_sample_avg totaltreat_pw_n identificad mode_base_month
industry1 firm_emp numb_clauses totaltreat_pw_norm treat_year placebo_year
totaltreat_pw_n_p90 turnover cba_period treat_union_exp_all avg_file_date
earliest2009_avg post_treat_cba pre_treat_cba second_cba_avg totalflows
lr_remdezr_w_p{10,25,50,75,90} lr_remdezr_h_w_p{10,25,50,75,90}
separations male_prop white_prop
```

Tail (1-2 scripts): `_merge avg_tenure big_industry big_region hiring
lr_remdezr_h_w_p{20,80} lr_remdezr_w_p{20,80} mode_union prop_hs prop_nhs
prop_sup r_remdezr totalflows_pw totaltreat totaltreat_n union_emp_exp`

`treat_union_exp_all` being in the core set confirms the union-exposure join is
load-bearing, not decorative.

## The build

```
1050 -> lagos_sample_sep24_test.dta      (reproducible Lagos firm panel)
1060 -> worker_estab_all_years.dta
2010 -> lagos_sample_workers.dta         runnable today; output merely absent
2020 -> lagos_sample_sep24_pct.dta
NEW  -> lagos_sample_sep24_pct_unionexp.dta = _pct JOIN union_treat_exp_sep24
2030 -> analysis panel                   input = lagos_sample_workers with _w renames
```

New scripts get numbers in the existing scheme: `2040` for the unionexp join,
`2050` for the `_w` rename shim if it cannot live inside `2030`.

### One transformation to get right

`2030` treats `r_remdezr_h_w` as a **log** (`rename r_remdezr_h_w lr_remdezr_h_w`
then `gen r_remdezr_h_w = exp(...)`) but treats `r_remmedr_h_w` as a **level**
(`gen lr_remmedr_h_w = log(r_remmedr_h_w)`). The two hourly variables carry
opposite conventions under similar names. The worker panel supplies levels, so
the shim must log one and not the other. This is the single most likely place for
the rebuild to diverge silently.

## Acceptance

**Stage 1 -- fidelity.** Build to a scratch path. Compare against the frozen panel
on the 59 contract columns: row count, key set, and per-column value agreement.
Produce a table reading identical / differs (with the distribution of the
difference) / absent. **Stop there for review.**

**Stage 2 -- switchover.** Only after review. Repoint `3010`/`3020` and the tier-D
wrappers at the rebuilt panel, re-run the 13 estimators, and report every
published coefficient old vs new with the delta in standard errors. Numbers will
move; the deliverable is the magnitude, not a claim of equality.

Known already: `lagos_sample_sep24_test.dta` differs from the frozen
`lagos_sample_sep24.dta` on connectivity columns (`avg_flowtreat_pf`, 3,624 of
174,110 rows on first inspection). That is expected -- it is the same
legacy-vs-current split the tier-C overlay exists to handle -- but the full
per-column comparison must confirm the differences are *confined* to connectivity.

## Guards

- Never overwrite the frozen panel, the published overlay, or anything under
  `UnionSpill-paper/`.
- Keep a master flag selecting which panel tier C consumes (rebuilt vs frozen) so
  both paths stay runnable and the comparison stays reproducible.
- Test anything touching the 60 GB worker panel on a subset first.
- `notify` on every long job.

---

# STAGE 1 RESULT — 2026-08-11

**The tier-B gap is closed. The analysis panel is rebuilt from 1050/1060 output
and no longer depends on the frozen binary.**

## What was built

| Artifact | Size | By |
|---|---|---|
| `lagos_sample_workers.dta` | 4.8 GB, 20.3M worker-year rows | `2010` (from `1050`+`1060`) |
| `lagos_sample_sep24_pct.dta` | 374 MB | `2020` |
| `lagos_sample_sep24_pct_unionexp.dta` | 375 MB | `2040` (new) |
| `worker_year_pre_new_vs_nonnew_dec26.dta` | 698 MB | `2050` (new) |
| rebuilt analysis panel | 140,773 rows | `2030` |

Neither "missing" dataset was lost. `lagos_sample_sep24_pct_unionexp.dta` is the
percentile panel `2020` writes itself, joined to `union_treat_exp_sep24.dta` on
`mode_union`. `worker_year_pre_new_vs_nonnew_dec26.dta` is a `_w`-suffixed
rename of `lagos_sample_workers.dta`.

## Fidelity vs the frozen panel, on the columns the estimators read

Rows: **140,773 in both**, matching year by year.

- **42 columns identical**
- **6 derived in-estimator** (`cba_period`, `pre_treat_cba`, `post_treat_cba`,
  `placebo_year`, ...) — `4012:122-126` does `cap drop` then rebuilds them from
  `avg_file_date` / `earliest2009_avg` / `second_cba_avg`, all identical
- **3 connectivity columns differ from the frozen panel — and that is correct**

### Connectivity: the rebuild is right and the frozen panel is stale

```
rebuilt totaltreat_pw_n vs the OVERLAY   ->      0 differing of 140,773
rebuilt totaltreat_pw_n vs frozen panel  ->  2,196 differing
```

The rebuilt panel carries the **current** measure natively. The overlay exists
only to swap that measure into a frozen panel that could not be rebuilt, so
**tier C is redundant on the rebuild path** — `3010`/`3020` are unnecessary when
building from `1050`.

### Residual differences: 188 rows of 140,773 (0.13%)

| Column | Rows | Max abs | Reading |
|---|---|---|---|
| `avg_tenure` | 141 | 7.83 | a single firm; untraced |
| `prop_hs`, `prop_sup` | 15, 10 | 0.0909 = 1/11 | one worker in a small firm |
| `prop_nhs`, `white_prop` | 9, 10 | 0.0833 = 1/12 | same |
| `male_prop` | 3 | 0.0013 | negligible |

## Questions answered

**Missing workers — ignore, permanently.** The 33,337 unmatched firm-years are
entirely 2007-2008 (16,253 + 17,084), zero in 2009-2016. The worker panel starts
in 2009 and so does the analysis window; the published panel excludes them too.
Decided structurally, not by coefficient comparison.

**industry1 must be int.** `reghdfe` absorbs it, and `1040:172` builds it as
`"1" + industry` precisely so the int conversion cannot eat leading zeros. The
three non-numeric `"1CLA"` codes going missing under `force` is the intended
trade. Removing `force` was wrong: the published analysis panel carries
`industry1` as **int**, and the Lagos firm panel's `str4` is an artifact of
`destring` silently declining to convert. Reverted; rationale now in `1050`.

## Still open

**The estimators have not been run against the rebuilt panel.** Every check says
the inputs match; nothing yet demonstrates the coefficients reproduce. That needs
the 13 tier-D estimators pointed at the rebuilt panel and checked against
direct 0.0262 / 0.0285 and spillover 0.0050 / 0.0065.

`avg_tenure`'s 141-row deviation is untraced.

## Code changes

New: `2040_build_pct_unionexp.do`, `2050_build_worker_panel_w.do`.
Overridable inputs (historical behaviour remains the default): `$lagos_firm_panel`
in `2010`/`2020`, `$stop_after_pct` in `2020` (breaks a real circularity -- its
tail needs a file `2040` derives from its own output), `$panel_out` in `2030`
(which otherwise overwrites the frozen panel).
`mmerge` -> native `merge 1:1` in `2020`/`2030`: mmerge aborts with a glibc
"corrupted size vs. prev_size" heap corruption on this data. Both sides carry
`_merge`, so the merge runs under a temp flag and renames, reproducing mmerge's
overwrite semantics.
