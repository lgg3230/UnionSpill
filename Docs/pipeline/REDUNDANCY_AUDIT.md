# Redundancy audit — analysis-sample construction

**Opened 2026-08-16.** Three adversarial rounds over tier A (1010-1070) and tier B
(2010-2050). Each finding is stated with its location, the proof that it is
genuinely redundant rather than load-bearing, and what breaks if it is removed.

Companion to `TIER_A_DEFECTS.md`, which covers defects that block execution rather
than waste it.

---

## Summary

| # | Redundancy | Location | Cost | Confidence |
|---|---|---|---|---|
| R1 | Raw RAIS is read and cleaned three separate times | 1010, 1060, 1050 | 2 of 3 full passes | Certain |
| R2 | 1010 and 1060 are the same 500-line script | 1010, 1060 | ~500 duplicated lines | Certain |
| R3 | 1060 computes 74 variables and keeps 11 | 1060 | 63 discarded | Certain |
| R4 | Worker-spell selection implemented three times | 1010:346, 1060, 1050:33 | 3 copies of one rule | Certain |
| R5 | The same wage percentiles are computed twice | 2020, 2030 | 1 duplicate worker-panel pass | Certain |
| R6 | Inert `by` prefixes force full re-sorts | 1010:476,481,486 | 3 gratuitous sorts | Certain |
| R7 | `lr_remdezr_h` discarded, then re-derived downstream | 1060 -> 2020:13 | trivial compute, real confusion | Certain |

---

## Round 1 — data flow and collapse/expand round trips

### R1. Raw RAIS is read three times

| Script | Years | What it takes |
|---|---|---|
| `1010_rais_to_firm.do` | 2007-2016 | full clean, firm-level collapse |
| `1060_rais_worker_panel.do` | 2009-2016 | same clean, worker panel |
| `1050_yearly_employers.do` | 2007-2011 | `PIS identificad empem3112 tempempr horascontr remdezr`, worker transitions |

Each opens `$rais_raw_dir/RAIS_{y}.dta` independently. The 2011 file alone is
17.6 GB and 70,971,125 rows.

**Load-bearing?** No. All three need the same object: one spell per worker-firm,
selected by the same rule (R4). 1050's extra requirement, a second selection of one
firm per worker by longest tenure, operates on the output of that same first stage.

**What breaks if merged:** 1050 needs 2007-2008, which the worker panel does not
currently cover, so the merged pass must extend the worker panel to 2007-2016.
1050 also needs `empem3112` and raw `remdezr`/`horascontr`, which are already in the
worker-panel keep list.

### R2. 1010 and 1060 are the same script

`diff` reports differences at only three places across 658 and 542 lines:

1. `1010:294` had `r_remdezr_h` as a log (tier A defect A2, now fixed).
2. The turnover block. 1010 dedups separations to one spell per worker under
   `seed 54321` and adds fixed-contract, safety, leave and education measures.
   1060 keeps an older raw spell count and has none of the extras.
3. The tail. 1010 collapses to firm level; 1060 saves the worker panel.

Difference 2 is not a real divergence in output, because of R3.

**What breaks if merged:** nothing, once both branches read one cleaned object.
The two tails become two `save` statements on one pass.

### R3. 1060 computes 74 variables and keeps 11

Measured directly against 1060's own keep list:

```
survive into worker_estab_*: dtadmissao_stata, dtnascimento, dtnascimento_stata,
                             idade, lr_remdezr, lr_remmedr, r_remdezr,
                             r_remdezr_h, r_remmedr, r_remmedr_h, year
computed then discarded    : 63 variables
```

Roughly a dozen of the 63 are load-bearing intermediates (`empdec_lagos`,
`final_rank`, `rank1`, `rank2`, `random`, `remdezr_h`, `remmedr_h`, the age
scratch variables). The rest is an entire firm-level outcome block that is built and
thrown away: `turnover`, `separations`, `layoffs`, `quits`, `lay_count`,
`qui_count`, `retention`, `hiring`, `hired_count`, `firm_emp`, `firm_emp_jan`,
`l_firm_emp`, `avg_tenure`, `male_prop`, `white_prop`, `prop_below_30`,
`prop_30_40`, `prop_above_40`, `pub_firm`, and the whole `salcontr` percentile
family.

**Why it matters beyond compute:** this is the block where 1010 and 1060 disagree
(R2 difference 2). Since none of it survives 1060's `keep`, the disagreement has no
effect on any output, which is why it went unnoticed.

**What breaks if removed:** nothing. The proof is the keep list itself.

---

## Round 2 — merges, sorts, and discarded work

### R4. The worker-spell selection is implemented three times

`1010:346-359`, the identical block in 1060, and `1050:33-55`. All three: rank by
`horascontr`, then by log hourly December wage, then `set seed 12345` and
`runiform()`.

1050 ranks on `l_remdezr_h = ln(remdezr/(horascontr*4.348))`, undeflated, while 1010
ranks on `lr_remdezr_h = log(remdezr_h/deflator)`. Within a year the deflator is a
constant, so the two differ by an additive shift and the `max` is identical.
`empdec_lagos = empem3112*(tempempr>1)` is character-for-character the same in both.

**Consequence beyond duplication:** the tie-break defect documented in
`DIFF_TRACE_2026-08-16.md` (seeded `runiform()` assigned in physical row order) is
replicated in all three copies, so any fix has to be applied three times or the
copies will disagree with each other.

### R5. The same wage percentiles are computed twice

2020 reads `lagos_sample_workers.dta` and builds `p10 p20 p25 p50 p75 p80 p90` for
`lr_remdezr`, `lr_remmedr`, `lr_remdezr_h`, `lr_remmedr_h`, plus `_avg` tail means
and within-firm standard deviations, then collapses to `cnpj_year`.

2030 reads `worker_year_pre_new_vs_nonnew_dec26.dta` and builds the same seven
percentiles for the same four variables under `_w` names, then collapses to
`cnpj_year`.

`2040_build_worker_panel_w.do` establishes that the second input is a rename of the
first: the `_w` panel is `lagos_sample_workers.dta` with four columns renamed. So
both passes read the same rows and compute the same statistics.

**What breaks if merged:** the `_w` names are load-bearing downstream and the two
passes do differ in scope, 2020 also producing the stayers/switchers means and the
`sd_*` family. The merge is a single pass emitting both name sets, not a deletion of
2030.

### R6. Inert `by` prefixes force full re-sorts

```stata
1010:476  bysort identificad PIS: gen tag_nhs = cond(no_hs_c==1 & final_rank==1, 1, 0)
1010:481  bysort identificad PIS: gen tag_hs  = cond(hs_c==1   & final_rank==1, 1, 0)
1010:486  bysort identificad PIS: gen tag_sup = cond(sup_c==1  & final_rank==1, 1, 0)
```

None of the three expressions references `_n` or `_N`, so each is row-wise and the
`by` prefix changes nothing except to force a sort of the full dataset.

Contrast `1010:522/529/534`, which use `cond(_n==1 & ...)` and are load-bearing.

Separately, 1010 alternates between `identificad` and `identificad PIS` as by-keys
19 times. Sorting by `identificad PIS` also satisfies `by identificad:`, so a single
sort at the top would serve every one of the 36 by-operations; the interleaving
forces roughly 8 avoidable re-sorts of 71M rows.

### R7. `lr_remdezr_h` is computed, discarded, then re-derived

1060 computes `lr_remdezr_h = log(remdezr_h/deflator)` and drops it at the keep
(R3). `2020:13` then does `gen lr_remdezr_h = log(r_remdezr_h)` from the level that
did survive.

The compute cost is trivial. The cost is comprehension: this is the round trip that
made the `r_remdezr_h` log/level collision (defect A2) so damaging, because
`log(r_remdezr_h)` silently becomes `log(log(w))` if the upstream convention flips.

---

## Round 3 — challenging rounds 1 and 2

Each finding above was re-examined for a hidden reason to keep it.

| Finding | Challenge | Verdict |
|---|---|---|
| R1 | Does 1050 need pre-selection spells that the worker panel drops? | **Survives.** 1050 applies the same `keep if final_rank==1` before it does anything else. It needs 2007-2008 coverage, which is a scope extension, not a reason to re-read. |
| R2 | Does the firm collapse need variables the worker panel lacks? | **Survives.** The collapse runs before either save in a merged pass, so both branches see the full variable set. |
| R3 | Is any of the 63 read by a later 1060 statement? | **Survives.** Verified programmatically against the keep list; the survivors are exactly the 11 listed. `modeind`/`modemun`/`cnpj_year` are created after the per-year keep, in the append tail, and are unaffected. |
| R4 | Do the three selections actually agree? | **Survives, with a caveat.** They agree in effect today. They are not guaranteed to agree after any change to row order, because each carries its own copy of the seeded `runiform()` defect. That argues for merging them, not against. |
| R5 | Is 2030 reading genuinely different rows? | **Survives.** 2050 constructs the `_w` panel as a rename of 2010's output. Same rows. But 2030 additionally applies `keep if year>=2009`, so a merged pass must preserve that restriction. |
| R6 | Does Stata already skip these sorts? | **Survives.** Stata skips a sort only when the requested key list is a prefix of `c(sortedby)`. Going from `identificad` to `identificad PIS` is a refinement, not a prefix, so it does re-sort. |
| R7 | Is the downstream log taken from a different variable? | **Survives.** `2020:13` reads `r_remdezr_h`, the same quantity 1060 logged and discarded. |

One candidate was **rejected** in round 3: the `preserve`/`restore` around 1040's
CBA slice looked redundant, but the slice is a per-year `tempfile` built from a file
the loop does not otherwise hold open, and removing the `preserve` would discard the
RAIS master. Load-bearing; left alone.

---

## Defects found during the audit but not redundancies

**D1. `leaves` is a worker-level rate presented as a firm-level one.**

```stata
1010:468  bysort identificad PIS: egen leave_c = total(cond(causafast1 != -1, 1, 0))
1010:469  gen leaves = leave_c / firm_emp
```

The comment says "count per estab", and both neighbouring rates use
`bysort identificad:` (`fixed_count` at :459, `safety_c` at :464). Grouping by
`identificad PIS` makes `leave_c` a per-worker count, so after
`collapse (firstnm)` the firm's `leaves` is one arbitrary worker's leave count
divided by firm employment.

`leaves` is carried into the analysis panel by `1050:621`, but no tier-D estimator
reads it, so no published number is affected. Latent, not active.

---

## D2. 1010's output depends on its sort history, not only on its data

**This is the finding that governs everything else, including whether any refactor
can be validated.**

### The experiment

Take the exact script that produced the on-disk firm panel (`ecf87cd`). Insert one
statement immediately before the age-group block:

```stata
bysort identificad PIS: egen __inert = max(horascontr)
drop __inert
```

It computes nothing. The variable is dropped on the next line. Same script, same
input file, same seed, same everything else. Result on the 2011 establishment
sample, 71,516 firms:

```
DIFFERS  avg_tenure       (43 rows)      DIFFERS  total_below_30  (1429 rows)
DIFFERS  white_prop       (15 rows)      DIFFERS  total_30_40     ( 880 rows)
DIFFERS  prop_hs          (23 rows)      DIFFERS  total_above_40  ( 753 rows)
DIFFERS  prop_nhs         (16 rows)      DIFFERS  retention       ( 211 rows)
DIFFERS  prop_sup         ( 9 rows)      DIFFERS  lr_remmedr      (  61 rows)
...                                       26 variables differ
```

### Two independent mechanisms

**(a) Seeded `runiform()` is assigned in physical row order.** `1010:354-359` sets
the seed and draws, then resolves ties for `final_rank`. The draw-to-row mapping
depends on the row order at that moment, so any earlier sort changes which spell
each worker contributes.

**(b) `_n==1` inside a by-group with a non-unique key.** `1010:522/529/534` use

```stata
bysort identificad PIS: gen tag_below_30 = cond(_n == 1 & d_below_30==1 & ...)
```

A worker-firm pair can hold several spells. Stata does not guarantee the order of
tied observations, and `bysort` skips the sort entirely when the data is already
sorted by a prefix of the key, so the tied order is inherited from whichever earlier
sort established it. `_n==1` therefore selects an arbitrary spell, and the age
distribution follows the sort history. This is the mechanism behind the 1429-row
column, the largest in the table.

### What is safe, and why

`firm_emp`, `l_firm_emp`, `lr_remdezr`, `r_remdezr`, `lr_remdezr_h` and
`r_remdezr_h` do **not** move. The tie-break is defined on `horascontr` and the log
hourly December wage, so tied spells carry identical hours and identical December
pay by construction, and exactly one spell is kept either way. Only attributes
outside the tie-break can differ: tenure, gender, race, education, age, and
`remmedr`, which is annual average earnings and is not part of the tie.

This is the same signature recorded in `DIFF_TRACE_2026-08-16.md`, where the frozen
and rebuilt analysis panels differed on `avg_tenure` across 120 firms while
`firm_emp` and `lr_remdezr_w` differed on zero rows. That episode had the same cause.

### Consequences

1. **Exact comparison cannot validate a refactor of 1010.** Any change that adds,
   removes or reorders a `bysort` moves these 26 columns. A parallel pipeline will
   differ from the original even when it is correct, so the decision rule in the
   task specification needs the order-dependent columns carved out and judged
   distributionally rather than cell by cell.
2. **The determinism defect should be fixed before the redundancy work**, not after.
   Otherwise every refactor step is unverifiable.
3. **The affected published exhibits are `tab:composition` and
   `tab:descriptive_stats`.** The headline employment and wage results are not
   affected, for the reason given above.

### The fix

Establish a unique, content-derived sort key once, before any random draw or any
`_n`-dependent statement, and sort on it:

```stata
sort identificad PIS <spell-identifying variables>
```

so that tied rows have a defined order. Then the seed reproduces and `_n==1` is
well defined. Note that this **changes the current numbers** for the columns above:
it replaces an arbitrary-but-unknown pick with an arbitrary-but-stated one.

---

## D2 — FIXED 2026-08-16

A single canonical sort was added to `1010`, `1060` (both at the top, immediately
after the variable `keep`/`order`) and `1050` (two sorts, because it selects first
on `identificad PIS` and then on `PIS` alone, so one prefix cannot serve both).

```stata
sort identificad PIS dtadmissao tpvinculo ocup2002 horascontr remdezr ///
     remmedr salcontr ultrem tempempr grinstrucao genero raca_cor ///
     dtnascimento idade causadesli mesdesli causafast1 clascnae20 municipio
```

### Why this key

It contains **every variable that any order-sensitive statistic reads** — the
tie-break inputs, plus tenure, gender, race, education, age, the separation codes,
every wage series that is averaged after selection, and `clascnae20`/`municipio`,
which are carried into the worker panel and feed the modal-industry and
modal-municipality pass. Those last two were missing from the first version of the
key and were caught by the parallel-pipeline comparison: three workers at one
establishment that files spells under two industry codes. Rows still tied under it are
therefore identical on everything the script computes, so which one is kept cannot
change a value. On the 2011 establishment sample that is **158 tied rows out of
1,031,907** spells with `empdec_lagos==1`.

Two Stata behaviours were verified directly before relying on them:

- After `sort x y z`, a later `bysort x y:` leaves `c(sortedby)` at `x y z` and does
  **not** re-sort, so the fine order survives every subsequent by-operation.
- Dropping a sort variable degrades `c(sortedby)` to the surviving prefix but leaves
  the physical row order untouched, so sorting before a `keep` is safe.

Because `identificad PIS` is a prefix of the key, this also eliminates the repeated
full-file re-sorts of R6 as a side effect.

### Verification

The probe was re-run against the fixed script — same inert
`bysort identificad PIS: egen __inert = max(horascontr)` inserted before the
age-group block:

```
DETERMINISM FIX: canonical sort, with vs without an inert extra sort
matched firms: 71516
  ALL 62 COMMON VARIABLES IDENTICAL
```

Before the fix the identical probe moved 26 variables, including 1,429 firms' age
distribution. The output is now a function of the data alone.

### The one-time move

Fixing the defect replaces an arbitrary-but-unknown tie order with a stated one, so
the affected columns change once. Measured on the 2011 establishment sample,
71,516 firms, repaired-only versus repaired-plus-determinism:

| Column group | Firms moved | Share |
|---|---|---|
| Age distribution (`total_below_30`, `total_30_40`, `total_above_40` and props) | 1,446 / 966 / 768 | ~2.0% |
| `lay_count`/`layoffs`, `qui_count`/`quits`, `other_sep_count`/`other_sep` | 304 / 265 / 239 | ~0.4% |
| `firm_emp_jan`, `retention` | 226 | 0.3% |
| Average-earnings family (`lr_remmedr`, `r_remmedr`, `remmedr_h`, `salcontr_*`) | 67-70 | 0.1% |
| `avg_tenure` | 50 | 0.07% |
| `prop_hs`, `prop_nhs`, `prop_sup`, `white_prop`, `male_prop` | 29 and below | <0.05% |

**Unchanged, on zero rows:** `firm_emp`, `l_firm_emp`, `lr_remdezr`, `r_remdezr`,
`lr_remdezr_h`, `r_remdezr_h`, `separations`, `turnover`.

The pattern is the expected one. The tie-break is defined on hours and hourly
December pay, so tied spells share those and every December wage series is invariant.
`separations` is a count of deduplicated separations and is invariant for the same
reason, while its *classification* into layoffs, quits and other moves, because that
reads `causadesli` from whichever spell is kept.

So the exhibits that move are `tab:composition`, `tab:descriptive_stats`, and the
layoff/quit decomposition inside `tab:turnover`. The headline employment and wage
results do not move.

---

## The parallel pipeline

Built in `Programs/parallel/`. Originals untouched.

| Script | Replaces | Change |
|---|---|---|
| `1010_rais_clean.do` | `1010` + `1060` | One pass over raw RAIS. Clean, deflate, select and build firm outcomes once, then branch: worker panel to `worker_estab_{y}`, firm panel to `rais_firm_{y}`. Worker files now written for 2007-2016 so 1050p can consume them; the modal-industry append stays on 2009-2016, unchanged. |
| `1040_yearly_employers.do` | `1050` | Reads `worker_estab_{y}` instead of opening raw RAIS a third time. Its per-firm selection block is deleted, because the worker panel is already the output of exactly that rule. Its stage-2 worker selection is unchanged. |

Raw RAIS is read **once** instead of three times (R1), the duplicated 500-line body
is gone (R2), 1060's 63 discarded variables are never computed (R3), and one copy of
the spell-selection rule remains instead of three (R4).

### Equivalence

| Artifact | Test | Result |
|---|---|---|
| `rais_firm_2007` | all common variables, 57,200 firms | **all 62 identical** |
| `rais_firm_2011` | all common variables, 71,516 firms | **all 62 identical** |
| `rais_firm_2016` | all common variables, 79,567 firms | **all 62 identical** |
| `worker_estab_2009` | `cf _all`, 34 vars, 894,538 rows | **passed** |
| `worker_estab_all_years` | row count | 8,303,006 both |

### What the comparison caught

The first version of the canonical sort key omitted `clascnae20` and `municipio`.
They are carried into the worker panel and feed the modal-industry and
modal-municipality pass, so they are order-sensitive, and `cf` found exactly three
cells differing out of 894,538 rows: three workers at establishment
`01454407000151`, which files spells under both `86101` and `41204`. Adding both
variables to the key closed it, and `cf _all` then passed.

This is the verification doing its job. It is also a reminder that the key's
guarantee is only as good as its coverage: any variable that survives into a saved
artifact and can differ between tied spells belongs in it.

### Timing

On the 2.3% establishment sample, sequential wall clock as the master would run it:

| Stage | Original | Parallel |
|---|---|---|
| clean / firm / worker | 1010 5m50 + 1060 4m20 | 1010p 7m02 |
| CBA merge | 1040 38s | 1040 38s |
| flows + MATLAB | 1050 2m52 | 1050p 2m38 |
| **total** | **13m40** | **10m18** |

**24.6% faster.** The saving is smaller than the "one pass instead of three" framing
suggests, because the MATLAB connectivity stage dominates 1050 and is untouched, and
because 1010p writes ten worker-year files where 1010 wrote none.

### Not yet promoted

The timing run and the `rais_firm` / `worker_estab_all_years` comparisons were made
**before** `clascnae20` and `municipio` were added to the key. Those need one more
full run and comparison, including `cba_rais_firm_2009_2016_flows_1.dta`, before the
decision rule can be applied. Everything measured so far points to promote.
