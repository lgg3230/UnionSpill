# Tier A defect register

**Opened 2026-08-16.** Tier A (1010-1070) had never been executed end to end; the
outputs on disk come from several different vintages of several different script
versions. This register lists every defect that blocks or corrupts a from-scratch
run, the evidence, and the fix applied.

Handoff items 4, 5 and 6 are A4, A5 and A6 below.

---

## A1 - 1010 aborts on the first iteration

**`Programs/1010_rais_to_firm.do:568`**

```stata
     lr_remdezr lr_remmedr r_remmedr r_remmedr_h r_remdezr r_remdezr_h ///
save "$rais_aux/worker_estab_`i'.dta", replace
```

The trailing `///` continues the `keep` onto the next line, so Stata parses
`keep ... r_remdezr_h save "..." , replace`. Reproduced in isolation:

```
keep a b ///
save "TESTOUT.dta", replace
variable save not found
r(111);
```

The do-file aborts on year 2009 and never reaches its own `collapse`, so **1010
produces nothing**. `1060_rais_worker_panel.do` carries the same block without the
stray `///`, which is why `worker_estab_*.dta` exists on disk (Apr 2026, from 1060)
while `rais_firm_*.dta` is much older (Oct 2025, from a prior version of 1010).

**Fix:** the whole block is removed with A4 below, since 1060 owns the worker panel.
That resolves A1 by deletion rather than repair.

---

## A2 - `r_remdezr_h` holds a log, not a level

**`Programs/1010_rais_to_firm.do:294`**

```stata
gen  lr_remdezr_h = .
replace lr_remdezr_h = log(remdezr_h/`deflator')   // correct

** Deflated December hourly earnings
gen  r_remdezr_h = .
replace r_remdezr_h = log(remdezr_h/`deflator')    // BUG: should be a level
```

Every sibling variable in the same block follows `r_` = deflated level, `lr_` = log
of that level (`r_salcontr_h`, `r_remmedr`, `r_remmedr_h`, `r_remdezr`). Only
`r_remdezr_h` deviates, and its own comment calls it "Deflated December hourly
earnings". `1060:294` has the correct level form.

This is the origin of the log/level trap documented in `2050:22-24`: because 1010
and 1060 write the same file (A4), the meaning of `r_remdezr_h` downstream depended
on which script ran last.

**Fix:** `replace r_remdezr_h = remdezr_h/`deflator''.
**Convention, confirmed by the author 2026-08-16 and applied downstream:**
`r_remdezr_h` is the real hourly wage, deflated only. `lr_remdezr_h` is its log.

---

## A3 - year-range mismatch between 1010 and 1040

`1010:17` loops `forvalues i=2009/2016` and writes `rais_firm_{i}.dta`.
`1040:9-11` loops `forvalues y = 2007/2016` and opens `rais_firm_{y}.dta`.

`rais_firm_2007.dta` and `rais_firm_2008.dta` are written by nothing and are absent
from disk, so a from-scratch 1040 fails on its first iteration. 1040 expects them:
its own comment reads "Slice CBA to the same year (empty for 2007-2008, which is
fine)", and the appended output is named `cba_rais_firm_2007_2016.dta`.

The deflator already supports those years. `local pos = `i' - 2006` indexes
`local ipca` (line 13), whose first entry is the 2007 value, so `i=2007` resolves to
word 1 and `i=2015` to word 9, which is 1 as required.

**Fix:** loop `2007/2016` in 1010. The worker-level `worker_estab_{i}.dta` save is
guarded to `i >= 2009` so that the modal industry and municipality, which are
computed over the appended worker years, keep their current 2009-2016 support.

---

## A4 - 1010 and 1060 both own `worker_estab_*` (handoff item 4)

Both scripts write `worker_estab_{i}.dta` and `worker_estab_all_years.dta` to the
same paths, and the two are otherwise 95% identical: same 500 lines of worker-level
cleaning, differing only at A2, at the turnover block (1010 dedups separations to
one spell per worker under `seed 54321` and adds fixed-contract, safety, leave and
education measures; 1060 has none of that), and at the tail, where 1010 collapses to
firm level and 1060 does not.

Before A2 this was a correctness bug, not just waste: the two write **different**
values for `r_remdezr_h`, so the last writer silently redefined it downstream.

Note that 1010's mode-and-append tail is dead code for 1010's own output: the block
that would merge modal municipality and industry back into `rais_firm_{i}.dta` is
commented out at 1010:624-657, so the modes 1010 computes feed only
`worker_estab_all_years.dta`, which is 1060's product.

**Fix:** split ownership. 1010 keeps the firm-level collapse and drops both its
`worker_estab_{i}` save and its mode-and-append tail. 1060 owns the worker panel end
to end. The remaining duplication of the 500-line cleaning body is left in place
deliberately; removing it is the redundancy work, not the repair.

---

## A5 - filename mismatches around the MATLAB step (handoff item 5)

Mismatched on both sides:

| Producer | Writes | Consumer | Reads |
|---|---|---|---|
| `1040:298` | `1_cba_treat.csv` | `1054:10` | `one_cba_treat.csv` |
| `1040:310` | `0_cba_treat.csv` | `1055:9` | `zero_cba_treat.csv` |
| `1054:167` | `connectivity_onecba_2007_2011.csv` | `1050:207` | `connectivity_one_2007_2011.csv` |
| `1055:152` | `connectivity_zerocba_2007_2011.csv` | `1050:207` | `connectivity_zero_2007_2011.csv` |

Both conventions exist on disk as different vintages. The `one_`/`zero_` files are
Jul 2025 and are what actually fed the published chain; the `onecba`/`zerocba`
connectivity files are Jan 2026 orphans that nothing ever consumed.

The `one_`/`zero_` spelling is the coherent one: it matches the Stata variable names
`one_cba_treat`/`zero_cba_treat`, matches the CSV column headers, and matches the
pattern that already works for the treat and control arms, where `1052`/`1053` write
`connectivity_{treat,control}_2007_2011.csv` and `1050`'s
`foreach dataset in treat control one zero` reads exactly those names.

**Fix:** 1040 exports `one_cba_treat.csv` / `zero_cba_treat.csv`; 1054 and 1055
write `connectivity_one_2007_2011.csv` / `connectivity_zero_2007_2011.csv`.

---

## A6 - 1040 overwrites the one-CBA file with the zero-CBA file (handoff item 6)

**`Programs/1030_merge_cba_rais.do:295` and `:307`**

```stata
collapse (first) one_cba_treat,  by(identificad)
save "$rais_aux/1_cba_treat.dta", replace     // line 295
...
collapse (first) zero_cba_treat, by(identificad)
save "$rais_aux/1_cba_treat.dta", replace     // line 307  <- same path
export delimited "$rais_aux/0_cba_treat.csv", replace
```

`1_cba_treat.dta` ends up holding `zero_cba_treat`, and no `0_cba_treat.dta` is ever
written. The CSV exports on both branches are correct, and nothing in `Programs/`
reads either `.dta`, so the published chain was not affected.

**Fix:** line 307 saves to `zero_cba_treat.dta` (with the A5 renaming).

---

## A7 - output depended on sort history, not only on data

Found while verifying A1-A6 and fixed the same day. Inserting a single inert
`bysort identificad PIS: egen __inert = max(horascontr)` into the script that built
the on-disk panel changed 26 variables, including the age distribution on 1,429 of
71,516 firms. Two mechanisms: the seeded `runiform()` at `1010:354` assigns draws in
physical row order, and `cond(_n==1 & ...)` inside a `bysort identificad PIS` group
picks an arbitrary tied spell.

**Fix:** one canonical sort at the top of 1010 and 1060, two in 1050, on a key
containing every variable any order-sensitive statistic reads. Verified: the same
probe now leaves all 62 variables identical.

Full statement of the defect, the key, the Stata behaviours it relies on, the
verification and the one-time change to the affected columns:
`REDUNDANCY_AUDIT.md` D2.

---

## A8 - 1051 read column names that 1040 does not export

`1041_connectivity_full_lagos.m` failed with `Unrecognized table variable name
'identificad1'` and produced no `connectivity_2007_2011.csv`, so `1050:132` then
died with r(601). Two stale references:

| 1051 read | `lagos_sample.csv` actually has | 1052-1055 pattern |
|---|---|---|
| `lagos.identificad1` | `identificad` | `.identificad` |
| `lagos.lagos_sample` | `lagos_sample_avg` | `.lagos_treat` etc. |

`1040:253-256` collapses `lagos_sample_avg` and renames `identificad1` to
`identificad` before exporting, and the production CSV on disk has the same header,
so this was not introduced by the tier-A repair. 1051 was simply the only one of the
five MATLAB scripts still on the old column names; 1052 through 1055 were already
consistent with what 1040 writes.

The **output** column stays `identificad1`, which is what `1050:134` imports.

**Fix:** 1051 reads `lagos.identificad` and `lagos.lagos_sample_avg`. Verified: the
file is now produced and 1050 completes.

---

## A9 - hardcoded absolute paths in the MATLAB stage

All five MATLAB scripts hardcoded `/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux`
(20 occurrences), and `1050` hardcoded both the MATLAB binary and the script paths
in five `shell` lines. The chain could therefore only run in one place, and any test
run would have written into production data. This is also an INV-16 violation.

**Fix:** the scripts read `UNIONSPILL_AUX` from the environment and fall back to the
production path when it is unset, so a normal run is unchanged:

```matlab
auxdir = getenv('UNIONSPILL_AUX');
if isempty(auxdir)
    auxdir = '/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux';
end
```

1050 now loops over the five scripts and passes the variable through:

```stata
shell UNIONSPILL_AUX="$rais_aux" "$matlab_exe" -nojvm < "$programs/`mscript'.m"
```

with `$matlab_exe` and `$programs` defaulted locally so 1050 still runs standalone.
Confirmed during the verification run that production `Data/RAIS_aux` was untouched:
203 files before, 203 after.

---

## Verification plan

**Closed 2026-08-16.** Tier A runs end to end with no errors: 1010 (10/10 years)
-> 1040 -> 1050 including all five MATLAB scripts, producing
`cba_rais_firm_2009_2016_flows_1.dta` and `lagos_sample_sep24_test.dta`.

Repaired tier A is exercised on an establishment sample of the FULL RAIS files at
`/kellogg/proj/lgg3230/RAIS/output/data/samples/RAIS_sample5_{YYYY}.dta`, which are
~5% of the full files (767 MB vs 15.6 GB for 2009). The samples are worker draws, so
firm-level aggregates are not comparable to published levels; the run is a proof of
executability and an input to the redundancy audit, not a levels check.

---

## A10 - `worker_panel_lagos.parquet` producer was archived, not missing (CLOSED 2026-08-16)

`2061_build_transitions.py`, `2082_mincer_export.py` and `2080_mincer_residuals.py`
read `Data/CBA_RAIS_firm_level/worker_panel_lagos.parquet`. It looked producer-less,
but the builder existed the whole time as `Programs/011c_worker_panel.py`, archived
by `cd49461` ("Programs/: code only") together with its two bin scripts. Found with
`git log --all -S "worker_panel_lagos"`, commit `613311b`.

Restored and renumbered into the chain:

| now | was | does |
|---|---|---|
| `2051_worker_panel_lagos.py` | `011c_worker_panel.py` | builds the panel |
| `2052_worker_panel_bins.py` | `011d_worker_panel_bins.py` | adds bin columns in place |
| `2053_worker_panel_bins2.py` | `011e_worker_panel_bins2.py` | adds the remaining bins |

### What the original does

- sample: `lagos_sample_avg == 1 & in_balanced_panel == 1`, read from
  `cba_rais_firm_2009_2016_flows_1.dta` (16,472 firms, 131,776 firm-years)
- rows: `WHERE empem3112 = 1 AND (tempempr > 1 OR tempempr IS NULL)`
- one spell per `(identificad, PIS)`, ranked `horascontr` DESC, then `remdezr_h`
  DESC, then a **deterministic hash tiebreaker salted "12345"** - a DuckDB `hash()`,
  not Stata's `runiform()`
- wages deflated to December 2015 (IPCA)

### Method note, worth keeping

Before this was found, the panel was reverse-engineered from the existing file and a
Stata reimplementation reached **99.999532%** key agreement on 2011 (2,564,391 of
2,564,403 keys, zero invented rows, all 59 columns present). The 12-row residual is
now explained: the original resolves ties with a deterministic hash while the
reimplementation used Stata's seeded `runiform()`, so tied spells land differently.

**That work was unnecessary.** The earlier search for a producer grepped for the
artifact name and `to_parquet` on the *same line*; in `011c` the path is assigned at
line 37 and written at line 270, so it never matched. Before concluding an artifact
has no producer, run `git log --all -S "<artifact name>"`.

Applying the same search to the other open gap confirms it is genuinely missing: no
builder for `fullrais_panel/worker_panel_fullrais_{year}.parquet` was ever committed.
The `residuals/fullrais/` series begins at `02_residualize_fullrais.py`, and the only
`01_*fullrais*` file in all of history is `01_educ_premia_fullrais.py`, which is
unrelated. That one must still be reconstructed.
