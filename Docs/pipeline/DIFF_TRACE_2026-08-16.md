# Tracing the 11 differing output files

**Built 2026-08-16.** Follow-up to `HANDOFF_2026-08-16.md` open item 1. All eleven
files are now accounted for. Three of them are not differences at all; the other
eight reduce to **two mechanisms**, neither of which touches a published number at
the precision the paper reports.

Baselines compared: the published CSVs under `Tables/`, against the rebuilt-panel
re-run in the previous session's scratch harness
(`scratchpad/full/<estimator>/tables/`, driver `full/driver2.sh`, results in
`full/comparison.txt`).

---

## Summary

| Files | Cause | Substantive? |
|---|---|---|
| `4031` × 3 `*_pretrend_top_*` | Column order: `industry1` and `mode_base_month` swapped | **No — values bit-identical** |
| `4131` `a7_hw`, `a8_hw` | `lr_remdezr_h_w` stored `double` (rebuilt) vs `float` (frozen) | No — coefficient shifts ≤ 2.1e-9 |
| `4051` Panel A (1 cell) | Same as above | No — one p-value 0.1947 → 0.1946 |
| `4091` × 4, `4101` × 2 | Random tie-break reassignment in `1010`'s `final_rank` | Small but real: `avg_tenure` on 141 of 140,773 rows |

---

## Mechanism 1 — the 4031 diagnostics are not different

`numb_clause_spill_pretrend_top_{delta,connectivity,influence_candidates}.csv`
were reported as "102 lines" of difference each. That is the whole file being
replaced, because columns 3 and 4 are transposed:

```
pub  identificad,microregion,industry1,mode_base_month,...
reb  identificad,microregion,mode_base_month,industry1,...
```

Swap those two columns in the published file and `diff` against the rebuilt file
returns **0 lines** for all three. The variable order in the rebuilt panel differs;
the values do not. Nothing to fix beyond noting it.

---

## Mechanism 2 — `lr_remdezr_h_w` is a double in the rebuilt panel

This is the explanation the handoff was looking for, and it also explains why
`3121_within_firm` (monthly) is byte-identical while its hourly twin `4131` is not.
The two scripts are textually the same modulo the wage variable, so the divergence
had to be in the data.

`describe` on the two panels:

| Column | Frozen | Rebuilt |
|---|---|---|
| `lr_remdezr_w` | float | float |
| `lr_remdezr_h_w` | float | **double** |
| `lr_remmedr_h_w` | float | float |
| `r_remdezr_h_w` | float | float |

`lr_remdezr_h_w` is the only column whose storage type changed. It comes from
`2040_build_worker_panel_w.do:59`:

```stata
gen double r_remdezr_h_w = ln(r_remdezr_h) if r_remdezr_h > 0 & !mi(r_remdezr_h)
```

`2030:17` renames it to `lr_remdezr_h_w` and `2030:38` carries it into the panel via
`collapse (mean)`, which preserves `double`. The legacy path supplied the same
quantity already log-transformed and stored as `float`, so each worker's log was
rounded to float **before** the within-firm mean was taken. Averaging float-rounded
logs and averaging double logs are not the same number.

Measured across the 140,773 panel rows:

| Column | Rows differing | Max abs diff | Max rel diff |
|---|---|---|---|
| `lr_remdezr_w` | **0** | 0 | 0 |
| `lr_remdezr_h_w` | 139,951 | 4.93e-07 | 1.13e-07 |
| `r_remdezr_h_w` | 35,119 | 6.1e-05 | ~6e-06 |
| `lr_remmedr_h_w` | 123 | 0.0755 | see below |

Correlation between the frozen and rebuilt `lr_remdezr_h_w` is 1.0000.

### What it does downstream

`a7_hw_hlogic.csv` and `a8_hw_hlogic.csv` differ **only on rows with
`outcome == wage`**. Every `emp` row is identical, and `n` and `firms` match exactly
on every row, so the estimation samples are unchanged. The largest movements:

```
b     .0065343350853713  ->  .0065343346423931     (rel 6.8e-10)
bpre  .0013996390236142  ->  .0013996369794418     (abs 2.0e-09)
peq   .5595158307861359  ->  .5595163224872406     (rel 8.8e-07)
```

`4051`'s single differing cell is the same story: a `pre_pval` on the hourly outcome
`lr_remdezr_h_w_p80`, sitting on a 4th-decimal rounding boundary (0.1947 vs 0.1946).

### Recommendation

**Keep the `double`.** Reverting `2050:59` to a bare `gen` would chase byte-identity
with the less accurate legacy artifact, and it would not fully restore it anyway.
Nothing the paper prints at 3 or 4 decimals moves, except the one p-value above,
which is a rounding boundary rather than a change in the estimate.

### Incidental finding: `lr_remmedr_h_w`

123 rows differ by up to 0.0755, which is far too large to be float noise. It is
also inert: no script in `Programs/` reads `lr_remmedr_h_w` or any of its
`lr_remmedr_h_w_p*` percentiles. Only `lr_remdezr_h_w_p*` is consumed
(`4012`, `4052`, `4132`, `5160`). Recorded, not chased.

---

## Mechanism 3 — random tie-break reassignment in tier A

`3091_composition` and `3101_sample_descriptives` differ because `avg_tenure` and
the demographic proportions differ. `1010_rais_to_firm.do:354-359` selects one spell
per worker-firm:

```stata
set seed 12345
gen random = runiform() if rank2==1
bysort identificad PIS: egen max_random = max(random * rank2)
gen final_rank = (random == max_random & rank2==1)
```

`set seed` fixes the stream, but `runiform()` assigns draws in the dataset's
**current physical row order**, and there is no `sort` on a unique key beforehand.
If the input arrives in a different row order, ties resolve to a different spell.

The panel comparison matches that signature exactly:

| Column | Rows differing (of 140,773) |
|---|---|
| `firm_emp` | **0** |
| `lr_remdezr_w` | **0** |
| `avg_tenure` | 141 |
| `prop_hs` | 15 |
| `white_prop` | 10 |
| `prop_sup` | 10 |
| `prop_nhs` | 9 |
| `male_prop` | 3 |

This is the fingerprint of a tie-break swap and of nothing else. The tie is defined
on `horascontr` and `lr_remdezr_h`, so two tied spells carry the **same** hours and
the same hourly wage, hence the same monthly wage; and exactly one is kept either
way, so the headcount is unchanged. `firm_emp` and `lr_remdezr_w` are therefore
invariant by construction, which is what we observe. The attributes that are *not*
part of the tie — tenure, gender, race, education — are free to differ between the
two tied spells, and they are the only ones that move. Tenure moves most because it
is continuous and two spells almost never share it; the categorical proportions move
rarely because tied spells usually agree on them.

Correcting the handoff: this is **141 rows across 120 distinct firms**, not 141 rows
of a single firm. Mean absolute difference on the differing rows is 0.55 months
against a level of ~52.8; the maximum is 7.83.

Effect on the exhibits is fourth-decimal:

```
avg_tenure  spill main      -0.2206  ->  -0.2204
avg_tenure  spill pre        0.6677** ->  0.6675**
avg_tenure  spill mean_pre  57.8494  ->  57.8492
white_prop  spill pre_pval   0.3972  ->   0.3971
```

`descriptive_stats_pretreat_estsample.csv` moves one cell (mean treated connections,
26.92 → 26.93) and `descriptive_stats_2011_estsample.csv` two more. Significance
stars are unchanged everywhere.

### Why this appeared without re-running tier A

Tier A was not executed in the previous session. The rebuilt panel was built from
whatever `1010`/`1060` outputs were already on disk, and those are a **different
vintage** from the run that produced the March 2026 frozen panel. The tie-break
divergence therefore predates this work; it was surfaced by the comparison, not
introduced by it.

### The open defect

`set seed` without a preceding deterministic sort is not reproducible across input
orderings. Making it so means sorting on a unique key before `runiform()`, for
example `sort identificad PIS <spell key>`. Note that this is a **behavioural
change**: it would re-draw every tie-break and move `avg_tenure` and the
demographic proportions again, to a third set of values. It also interacts with open
item 4 in the handoff, since `1010` and `1060` both write `worker_estab_*.dta` to the
same paths and `1060:475` carries the identical `avg_tenure` construction. Resolve
the path collision first, then decide the tie-break.

---

## Status of handoff open item 1

| Was | Now |
|---|---|
| `4031` × 3 — "not examined" | Not a difference. Column order only. |
| `4131` `a7_hw`/`a8_hw` — "unexplained, most interesting" | Explained. Storage type, `2050:59`. |
| `4051` Panel A — "unexplained" | Explained. Same cause. |
| `4091`, `4101` — "most likely explained" | Confirmed. Tie-break reassignment, `1010:354`. |

No file among the eleven changes a published estimate, standard error, or
significance marking at the precision the paper reports.
