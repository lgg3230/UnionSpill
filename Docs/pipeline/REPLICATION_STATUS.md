# Replication status — per exhibit

**Built 2026-08-09.** What reproduces, what does not, and what was actually executed to
find out. Companion to `REPLICATION_DAG.md` (the dependency graph) and `INVENTORY.md`
(exhibit → producing script).

Scope: the exhibits in `UnionSpill-paper/Draft.tex` — **12 table floats and 7 figure
floats (13 `\includegraphics`)**. `INVENTORY.md`'s "13 tables, 6 figures" is wrong.

---

## Verdict legend

| Verdict | Meaning |
|---|---|
| **VERIFIED** | Regenerated this session and compared against the published artifact |
| **REPRODUCIBLE** | Chain intact and unblocked, but not re-executed here |
| **BLOCKED** | Cannot be produced from `Programs/` today |

Everything below rests on the frozen analysis panel, a **protected input** — see
`REPLICATION_DAG.md` tier B. "REPRODUCIBLE" means reproducible *from that panel down*.

---

## The load-bearing result

**Tier C is VERIFIED, and it was the blocker for everything else.** Until 2026-08-09 no
script in `Programs/` built the current-connectivity overlay panel, so every published
number rested on a 194 MB binary of unrecorded provenance (`sample_provenance.md` H1).
Two new scripts now rebuild it, and both reproduce their published artifacts
**value-identically**:

| Artifact | Rebuilt by | Check |
|---|---|---|
| `currentconn_overlay_totaltreat.dta` | `3010_build_currentconn_ingredient.do` | `cf _all` silent |
| overlay panel (140,773 × 551) | `3020_build_currentconn_overlay_panel.do` | `cf _all` silent, all 551 vars |

A negative control (perturb one cell, re-run `cf`) confirms the comparison would have
reported a difference, so the silence is meaningful rather than vacuous. The p90
diagnostics reproduce exactly too: legacy 0.02932389, current 0.02925788.

---

## Tables

| Exhibit | Verdict | Evidence |
|---|---|---|
| `tab:turnover` | **VERIFIED** | All four estimator CSVs byte-identical to the published ones — see below |
| `tab:direct_connectivity_robust` | REPRODUCIBLE | Tier C verified; estimator + generator unblocked |
| `tab:spill_main_4tf_out` | REPRODUCIBLE | as above |
| `tab:spill_clause_decomp` | REPRODUCIBLE | as above |
| `tab:rob_logwages` | REPRODUCIBLE | as above |
| `tab:spill_union_4tfpe_4out` | REPRODUCIBLE | as above |
| `tab:composition` | REPRODUCIBLE | as above |
| `tab:resid_raw_base` | REPRODUCIBLE | as above |
| `tab:layer_desc_full` | REPRODUCIBLE | canonical v3 estimators now tracked (`7b2a49f`) |
| `tab:group_specs` | REPRODUCIBLE | as above |
| `tab:horse_race` | REPRODUCIBLE | as above |
| `tab:descriptive_stats` | REPRODUCIBLE, **ambiguous** | `_pretreat` vs `_2011` suffix still unresolved — `INVENTORY.md §A` |

### `tab:turnover` — INVENTORY D1 is closed

`INVENTORY.md` D1 calls this "the single most important open item" and states the table is
"**not currently reproducible from `Programs/`**". That is stale. The exclusion note in
`5100_inline_into_replication.py:54-61` was **updated on 2026-08-02**, after INVENTORY was
built, and records that t_turnover was re-run and inlined by decision: the specification
reproduced exactly (same absorb list, same n=113,112, same p90 divisor .0292579) with point
estimates differing by ≤ 0.094 SE — convergence slack from demeaning `microregion#year`
(3,560 categories) on top of 14,139 firm effects. One qualitative change was accepted: the
Panel A churn pre-trend crossed into significance (−0.0498 → −0.0528*).

Re-running `turnover/4081_turnover.do` in a **fresh Stata process** on 2026-08-09
produced all four CSVs **byte-identical** to the published
`Tables/currentconn_full/turnover/`:

```
IDENTICAL  results_direct_panelA_turnover.csv
IDENTICAL  results_direct_panelB_turnover.csv
IDENTICAL  results_direct_panelC_turnover.csv
IDENTICAL  results_spill_turnover.csv
```

Two things follow. The table is reproducible. And the pipeline is **deterministic across
processes** for this estimator — the sixth-digit `reghdfe` session-state drift that
motivates one-process-per-exercise does not appear when each exercise gets a clean process,
which is exactly what `0000_master.do` tier D now guarantees.

---

## Figures

Assessed by md5 against the paper's `Replication/Figures/`, via
`main_results/6010_copy_figures_to_paper.py` (dry run).

| Published name | Verdict | Note |
|---|---|---|
| `bilateral_coefplot.pdf` | **VERIFIED** | hash-exact |
| `distro_region.pdf` | **VERIFIED** | hash-exact |
| `distro_industry.pdf` | **VERIFIED** | hash-exact |
| `distro_month.pdf` | **VERIFIED** | hash-exact |
| `h_dir_es.pdf` | **VERIFIED** | hash-exact vs `es_lr_remdezr_h_w_directA__3_Aug_2026.pdf` |
| `h_spill_es.pdf` | **VERIFIED** | hash-exact |
| `m_dir_es.pdf` | **VERIFIED** | hash-exact (not cited in Draft.tex; monthly counterpart) |
| `m_spill_es.pdf` | **VERIFIED** | hash-exact (not cited) |
| `h_recentered_spill.pdf` | **NOW PRODUCIBLE** | was impossible; see below |
| `h_recentered_cf.pdf` | **NOW PRODUCIBLE** | was impossible; see below |
| `binscatter_wage.pdf` | DRIFT | source differs from paper |
| `binscatter_hwage.pdf` | DRIFT | source differs |
| `binscatter_emp.pdf` | DRIFT | source differs |
| `binscatter_clauses.pdf` | DRIFT | source differs |
| `conn_hist.pdf` | DRIFT | source differs |
| `m_recentered_spill.pdf` | DRIFT | source differs (not cited in Draft.tex) |
| `m_recentered_cf.pdf` | DRIFT | source differs (not cited) |

**8 hash-exact, 7 drifted, 2 recovered.** The drift is the `INVENTORY.md` D4 pattern: the
published figures came from runs whose output was never written back to `Graphs/`. Per the
approved plan the chain regenerates these; `6010_copy_figures_to_paper.py` reports every
replacement with both md5s and writes nothing without `--apply`.

### The hourly recentered pair was unproducible

Draft.tex cites `h_recentered_spill.pdf` and `h_recentered_cf.pdf` at lines 493 and 500.
`rand_inference/5152_recentered_eventstudy.do` set `local out "lr_remdezr_w"` at line 30 but
hardcoded the outcome into all four export filenames, so the local was inert and no
invocation could produce the hourly figures. Parameterized 2026-08-09; verified by
generating both PDFs for `lr_remdezr_h_w`, pooled main 0.0066 (0.0023) against the
documented 0.0065 hourly spillover benchmark.

### Honest-DiD figures are not paper figures

`INVENTORY.md §C` and D4 list four honest-DiD figures among the paper's figures.
`grep -i honest UnionSpill-paper/Draft.tex` returns nothing. They are phase-2 material and
are deliberately absent from the tier-F copy map.

---

## What is still blocked

**One thing, and it is upstream of everything.** The frozen analysis panel cannot be
rebuilt: `lagos_sample_sep24_pct_unionexp.dta` and
`worker_year_pre_new_vs_nonnew_dec26.dta` are absent from disk and written by no script
(`sample_provenance.md` H2, independently found by `main_data_pipeline/PIPELINE_STATUS.md`
in April 2026). Tier B of `0000_master.do` is fenced behind a second opt-in flag for this
reason.

So the honest summary is: **the chain runs end-to-end in two verifiable halves joined by one
protected input.** Raw RAIS → firm panel → connectivity is runnable; frozen panel → overlay
→ estimates → tables → figures is verifiable and partly verified. The join between them is
the remaining hole, and closing it means reconstructing those two datasets — which would
rebuild rather than reproduce the panel, and would move every published number.

Also unresolved and smaller: which descriptives suffix (`_pretreat` vs `_2011`) is the
published one.
