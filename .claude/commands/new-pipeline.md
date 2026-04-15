# New UnionSpill Regression Pipeline

Scaffold a new regression pipeline for this project. The pipeline name is: $ARGUMENTS

## Pipeline structure

Every exercise follows this layout:

```
Programs/<name>/
    _run_<name>.do          ← wrapper with stage flags + globals
    prep_<name>_data.do     ← build/clean the analysis dataset
    results_<name>.do       ← regressions → CSVs
    generate_<name>_latex.py← CSVs → LaTeX tables
Tables/<name>/              ← regression CSVs + .tex files
Graphs/<name>/              ← event-study and coefficient PDFs
Logs/<name>/                ← run logs (gitignored)
```

## ⚠️ MANDATORY FIXED EFFECTS — NO EXCEPTIONS

Every regression in this project **must** absorb `mode_base_month`. There are no exceptions unless the user explicitly says so in the current message.

The canonical locals — copy these verbatim into every `results_*.do`:

```stata
* Fixed effects: always include mode_base_month.
* Event-study regressions use tolerance(1e-2) for MWFE convergence speed.
local base_fe     "identificad i.industry1#i.year i.microregion#i.year i.mode_base_month#i.year"
local base_fe_cba "identificad i.industry1#i.cba_period i.microregion#i.cba_period i.mode_base_month#i.cba_period"
local extra_year  "ib0.totalflows_pw_pre_07_114#i.year"
local extra_cba   "ib0.totalflows_pw_pre_07_114#i.cba_period"
```

Never create `base_fe_es` or `base_fe_cba_es` variants that drop `mode_base_month`.
Use `tolerance(1e-2)` on event-study regressions instead.

## Regression spec pattern

```stata
* Absorb for year-based outcomes
local absorb "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

* Main DiD
reghdfe `outcome' treat_ultra##i.treat_year if `s_use', ///
    absorb(`absorb') vce(cluster identificad)

* Placebo
reghdfe `outcome' treat_ultra##i.placebo_year if `s_use' & year <= 2011, ///
    absorb(`absorb') vce(cluster identificad)

* Event-study pre-trend F-test — MUST use tolerance(1e-2)
reghdfe `outcome' i.treat_ultra##ib2011.year if `s_use', ///
    absorb(`absorb') vce(cluster identificad) tolerance(1e-2)
testparm 1.treat_ultra#i(2009 2010).year
local pre_ftest_pval = r(p)
```

For CBA-period outcomes (e.g. `numb_clauses`), substitute `base_fe_cba` and `extra_cba`.

## Pre-treatment bins (prep do-file)

For each outcome `X`, create:
```stata
* Pre-treatment mean
cap drop X_pre_o
cap drop X_pre
quietly {
    bys identificad: egen X_pre_o = mean(X) if inrange(year,2009,2011)
    bys identificad: egen X_pre   = min(X_pre_o)
    drop X_pre_o
}

* Quartile bins
cap drop X_pre4_o
cap drop X_pre4
quietly {
    egen X_pre4_o = cut(X_pre) if year == 2009, group(4)
    bys identificad: egen X_pre4 = min(X_pre4_o)
    drop X_pre4_o
    replace X_pre4 = 0 if missing(X_pre4)
}
```

Add `X_pre` and `X_pre4` to the fill-forward loop after `fillin`.

## cap drop rule

`cap drop x y z` silently fails — only drops the first variable. ONE variable per cap drop line, always.

## CSV output format

```stata
file write `fh' "spec,section,outcome,row_type,value" _n   // header
// rows: semicolon-delimited, value has trailing quote
file write `fh' `""`spec'";"`section'";"`outcome'";"main";"' %9.4f (`b_post') `"`stars'""' _n
```

## Wrapper globals

```stata
global main    "/kellogg/proj/lgg3230"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global programs  "$main/UnionSpill/Programs"
global tables  "$main/UnionSpill/Tables/<name>"
global graphs  "$main/UnionSpill/Graphs/<name>"
global logs    "$main/UnionSpill/Logs/<name>"
```

## Notifications

End every long-running job with:
```stata
shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "Done" "description"
```

## LaTeX generator (Python)

```python
root       = Path(__file__).resolve().parent.parent.parent   # UnionSpill/
tables_in  = root / "Tables" / "<name>"
tables_out = tables_in

# Table format: [H], \scriptsize, notes open with "This table ..."
# Outcomes column header: \shortstack{Log\\employment} etc.
```

## Flow outcomes (totalflows / outflows / inflows)

If the outcome is a flow variable, it gets absorbed by firm FE + pre4 bins → R²=1.
Always exclude `extra_year` from absorb for those outcomes and wrap testparm:
```stata
capture testparm ...
local pre_ftest_pval = cond(_rc==0, r(p), .)
```
