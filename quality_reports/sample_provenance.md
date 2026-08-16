# Sample Provenance Audit

**Built 2026-08-06. Audit only — nothing was created, moved, or modified.**

Companion to `Docs/pipeline/INVENTORY.md`, which maps *exhibit → producing script*.
This file maps *exhibit → analysis sample → definition site*, and records every
place two scripts define the same sample differently.

Scope: the 13 canonical estimators named in `INVENTORY.md §G`, plus the
data-build chain, `max_clause_row/`, `rand_inference/`, `honest_did/`, and the
within-firm layer estimator.

---

## 1. Headline result

**The sample layer is in far better shape than the exhibit layer.** There are
five sample definitions in the whole paper, they are written as literal Stata
condition strings, and those strings are **byte-identical across every canonical
estimator**. No estimator invents its own restriction, reorders a filter in a way
that changes membership, or silently drops observations that a sibling keeps.

The risk is not divergent definitions. It is that **the dataset those definitions
are applied to has no producer in `Programs/`** — see §4, H1.

---

## 2. The sample lattice

Every canonical estimator performs the same three-step open:

```stata
use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear   // base panel
merge m:1 identificad using `totalflows_wide', keep(master match) nogen
keep if year >= 2009
keep if lagos_sample_avg == 1
```

and then selects an estimation sample with one of five conditions:

| ID | Name | Condition | Used by |
|---|---|---|---|
| **S0** | Loaded panel | base panel & `year>=2009` & `lagos_sample_avg==1` | all 13 |
| **S1** | Spillover | `S0` & `treat_ultra==0` & `in_balanced_panel==1` | 11 |
| **S2** | Direct A (strict) | `S0` & `in_balanced_panel==1` & `(treat_ultra==0 & totaltreat_pw_n==0 \| treat_ultra==1)` | 4 |
| **S3** | Direct B (loose) | as S2 with `totaltreat_pw_n<=0.01` | 2 |
| **S4** | Direct C (all) | `S0` & `in_balanced_panel==1` (both treatment arms, no purity filter) | 2 |

### Verified-identical definition sites

`S1` — string `"lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"`,
character-for-character, at:

```
4012_pct_tfpw.do:138, :329
clause_types/4032_clause_types.do:151
cba_value/4042_cba_value.do:106, :186
turnover/4082_turnover.do:146, :308
composition/4092_composition.do:113, :259
residuals/4112_mincer.do:122, :255
robustness/4052_robustness_bins.do:124, :381
robustness/4062_micro_ind_q.do:86
robustness/4072_union_controls.do:85
max_clause_row/max_clause_row.do:155
```

`S2` — string
`"(treat_ultra==0 & totaltreat_pw_n==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"`
at `4012_pct_tfpw.do:326` (`s_direct_A`),
`conn_margins/4022_direct_sample_coef_test.do:139` (`$s_A`),
`robustness/4062_micro_ind_q.do:88` (`s_direct`),
`max_clause_row/max_clause_row.do:234`.

`S3` at `4012_pct_tfpw.do:327` and `4022_direct_sample_coef_test.do:140`.
`S4` at `4012_pct_tfpw.do:328`, `4022_direct_sample_coef_test.do:141`
(`$s_C`), `max_clause_row/max_clause_row.do:235`.

**No conflicts found.** Only cosmetic reordering, in
`descriptives/4102_sample_descriptives.do:102`
(`lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0`), which is S1 with
the conjuncts permuted — logically identical.

### Upstream definitions of the three sample variables

| Variable | Defined at | Definition |
|---|---|---|
| `treat_ultra` | `1040_merge_cba_rais.do:161` | `bys identificad: egen treat_ultra = max(treat_cba)` — treated in any year ⇒ treated in all |
| `in_balanced_panel` | `1040_merge_cba_rais.do:198` | present in 2009 & 2010 & … (`cond(...)`) |
| `lagos_sample_avg` | `1040_merge_cba_rais.do:117` | `(cba_pre2012_avg==1 & cba_post2012_avg==1 & pos_emp==1)`, via the `filedate` loop |

All three are mirrored byte-identically in
`main_data_pipeline/40_041_merge_cba_rais.do` — that folder holds copies, not
forks.

---

## 3. The base panel is the overlay, everywhere

`$rais_firm` is set by the wrapper, and **all 13 canonical wrappers point at the
current-connectivity overlay**, not the frozen panel:

```
Data/CBA_RAIS_firm_level_currentconn_overlay/     ← every published exhibit
Data/CBA_RAIS_firm_level/                         ← frozen; legacy runs only
```

Verified for `4011_pct_tfpw.do`, `conn_margins/4021_direct_sample_coef_test.do`,
`clause_types/4031_clause_types.do`, `cba_value/4041_cba_value.do`,
`robustness/_run_{robustness_cc,micro_ind_q_hw,union_controls_hw_cc}.do`,
`turnover/4081_turnover.do`, `composition/4091_composition.do`,
`descriptives/4101_sample_descriptives.do`,
`main_results/4111_mincer.do`,
`layer_connectivity/07_within_firm/_run_within_firm{,_hw}_v3.do`.

The overlay directory is a symlink farm. Every entry is a symlink back to
`CBA_RAIS_firm_level/` **except one real file**:

```
194,764,349 B  2026-07-27 01:24  lagos_sample_sep24_pct_unionexp_ext_df2.dta
```

against the frozen `194,200,617 B  2026-03-02 17:09`. That single 564 KB
difference is the entire current-connectivity treatment, and it is the file every
published number rests on.

---

## 4. Hazards

### H1 — The published base panel has no producer in `Programs/`. **Blocking.**

No script in `Programs/` writes
`Data/CBA_RAIS_firm_level_currentconn_overlay/lagos_sample_sep24_pct_unionexp_ext_df2.dta`.
Searched: every `.do` and `.py` for `save`/`export`/`to_stata` against that path
or that filename. The only writer of the filename is
`2030_get_wage_pctiles_df2.do:47`, which saves to `$rais_firm/` — so it *would*
write the overlay if invoked with `$rais_firm` set to the overlay dir, but no
committed wrapper does that, and its own input is missing (H2).

Consequence: the sample definitions in §2 are fully reproducible; the dataset
they filter is not. **Every exhibit in the paper currently depends on a 194 MB
binary of unrecorded provenance.** This is the sample-side analogue of
`INVENTORY.md D1`, and strictly larger in blast radius — D1 costs one table,
this costs all of them.

### H2 — The upstream link into the base panel is missing on disk.

`main_data_pipeline/PIPELINE_STATUS.md` records that
`Data/CBA_RAIS_firm_level/lagos_sample_sep24_pct_unionexp.dta` — the direct input
to `2030_get_wage_pctiles_df2.do` — does not exist, along with
`rais_firm_{2007,2008}.dta`. So even the *frozen* panel cannot be rebuilt today.
The chain is broken at two independent points: raw → frozen (H2), frozen →
overlay (H1).

### H3 — The overlay changes sample **membership**, not just the regressor.

`S2` and `S3` filter on `totaltreat_pw_n`, and `totaltreat_pw_n` is exactly the
variable the overlay replaces. Swapping panels therefore moves firms in and out
of the direct-effect samples — it is not a pure change of right-hand-side
variable. Any statement of the form "the overlay only renormalizes the
regressor" is true for `S1` and false for `S2`/`S3`.

This compounds the known `totaltreat_pw_norm` trap (memory:
`project_currentconn_overlay_trap`): each estimator rebuilds
`totaltreat_pw_norm = totaltreat_pw_n / p90(totaltreat_pw_n)` in-script
(`4012_pct_tfpw.do:141–146`, and again at
`4102_sample_descriptives.do:128–131`, `13_pctiles_specs.do:38–41`), so the
regressor's *scale* is a function of which panel was loaded and which sample the
p90 was taken over.

### H4 — Three lineages bypass the lattice.

| Consumer | Base | Note |
|---|---|---|
| `rand_inference/5152_recentered_eventstudy.do:21` | `$randdir/spill_frame.dta` | a frozen derived sample, not S0–S4; its own build step is untraced here |
| `honest_did/honest_did_rm_2x2.py:28` | `honest_did_results{,_fine}.csv` | consumes estimates, never a panel — inherits whatever sample produced the CSVs |
| `layer_connectivity/07_within_firm/01c_*.do:211` | base panel, own restriction order | see H5 |

### H5 — The within-firm estimator builds its own panel.

`4122_within_firm.do` opens the base panel at :211 but restricts with
`keep if lagos_sample_avg == 1 & year >= 2009` (:214) after a `keep` of a fixed
variable list, then layers on restrictions absent from S0–S4:
`keep if !mi(microregion_num)` (:183), a crosswalk cut
`keep if treat_ultra==0 & in_balanced_panel==1 & year==2009 & !mi(totaltreat_pw_n)`
(:248), `keep if s_base==1 & inrange(year,2009,2011)` (:385), `keep if __ng >= 2`
(:412), `keep if __nl==2` (:475), `keep if inboth==1` (:499). `s_base` is not
defined as a literal condition string anywhere in the file — it is a variable
built during the run. This is the one estimator whose sample cannot be read off
a single line.

### H6 — `_extpre` is a fourth panel variant.

`extpre_build.do:128` writes `...ext_df2_extpre.dta`, consumed by
`Main_Results_pct_tfpw_07_11_extpre.do`, `extpre_eventstudy_export.do`, and
`descriptives/balance_table_task2.do`. Not traced to a published exhibit in
`INVENTORY.md`; flagged so it is not mistaken for the headline panel.

---

## 5. Exhibit → sample map

| Exhibit | Sample(s) | Panel |
|---|---|---|
| `tab:spill_main_4tf_out` | S1 | overlay |
| `tab:direct_connectivity_robust` | S2, S3, S4 | overlay |
| `tab:spill_clause_decomp` | S1 | overlay |
| `tab:rob_logwages` | S1, S2 | overlay |
| `tab:spill_union_4tfpe_4out` | S1 | overlay |
| `tab:composition` | S1 | overlay |
| `tab:turnover` | S1 | overlay — but see `INVENTORY.md D1`, not reproducible |
| `tab:resid_raw_base` | S1 | overlay |
| `tab:descriptive_stats` | S1 + group cuts on `totaltreat_pw_n` (`4102_sample_descriptives.do:213–228`) | overlay |
| `tab:layer_desc_full`, `tab:group_specs`, `tab:horse_race` | H5 (own lattice) | overlay |
| event-study figures `{m,h}_{dir,spill}_es.pdf` | S2 / S1 | overlay |
| honest-DiD figures | inherited via CSV — H4 | — |
| recentered figures | `spill_frame.dta` — H4 | — |

---

## 6. What a canonical sample codebase has to do

Ordered by what actually blocks reproduction:

1. **Close H1.** Establish how the overlay panel was built and commit the
   script. Until this exists, no refactor can be validated, because there is
   nothing to validate against. This is the whole job's critical path.
2. **Close H2** or declare the frozen panel a protected input with a documented
   hash, and scope the replication package to start there.
3. **Promote the lattice to one file.** The five conditions are already
   consistent; the work is mechanical. A single `Programs/samples.doh` defining
   `$S1`–`$S4` (plus the S0 open) that all estimators `include` would make the
   consistency structural rather than coincidental, and would make H3 visible at
   the point of use.
4. **Normalize `totaltreat_pw_norm` once**, in the panel build rather than in
   nine estimators, or document that its scale is sample-dependent by design.
5. **Leave H4/H5 alone for now.** The within-firm and randomization-inference
   lineages are genuinely different designs, not drift. Forcing them into the
   lattice would be a rewrite, not a consolidation.

## 7. What this audit does not establish

- Whether the overlay panel is *correct* — only that its construction is
  unrecorded.
- The build of `spill_frame.dta` (H4) and of `s_base` (H5) were not traced.
- `Gui_coding/`, `within_firm_final/`, `results/`, `Old/`, and the two untraced
  replication trees were not examined.
- No script was executed. Every claim here is from source text, file metadata,
  and symlink structure.
