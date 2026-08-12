********************************************************************************
* PROJECT: UNION SPILLOVERS
* PROGRAM: BUILD lagos_sample_sep24_pct_unionexp.dta
*
* Closes the first of the two tier-B gaps. This file is the direct input to
* 2020 (at its second mmerge) and to 2030, and it was absent from disk with no
* producer -- one of the two datasets that made the analysis panel
* unreconstructible (sample_provenance.md H2).
*
* It is not a lost dataset. It is the firm-level percentile panel that 2020
* writes itself, carrying the mode-union exposure measures alongside:
*
*     lagos_sample_sep24_pct.dta        (2020 writes this at its first mmerge)
*   JOIN union_treat_exp_sep24.dta      on mode_union
*   ->  lagos_sample_sep24_pct_unionexp.dta
*
* union_treat_exp_sep24.dta is 4,324 rows, uniquely keyed on mode_union, and
* carries treat_union_exp_all and union_emp_exp -- both in the column contract
* the estimators read. It is built by union_treat_exp.do (now archived) from
* cba_rais_firm_2007_2016.dta, a 1040 output, so the whole chain is reproducible.
********************************************************************************

version 17.0
set more off
set varabbrev off

if "$main" == "" global main "/kellogg/proj/lgg3230"
if "$rais_firm" == "" global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
if "$rais_aux"  == "" global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
if "$pct_in"    == "" global pct_in    "$rais_firm/lagos_sample_sep24_pct.dta"
if "$unionexp_out" == "" ///
    global unionexp_out "$rais_firm/lagos_sample_sep24_pct_unionexp.dta"

local union "$rais_aux/union_treat_exp_sep24.dta"

foreach f in "$pct_in" "`union'" {
    capture confirm file "`f'"
    if _rc {
        di as error "MISSING input: `f'"
        exit 601
    }
}

di as result _newline "2040_build_pct_unionexp.do"
di as text "  pct panel  : $pct_in"
di as text "  union exp  : `union'"
di as text "  out        : $unionexp_out"

use "$pct_in", clear
local n_in = _N
isid identificad year
di as text "[in] `n_in' obs, `c(k)' vars"

capture confirm variable mode_union
if _rc {
    di as error "mode_union absent from $pct_in -- cannot attach union exposure."
    exit 459
}

* m:1 -- many firm-years share a mode_union. Unmatched firm-years are kept and
* reported rather than dropped: a firm with no union match is still in the
* sample, it simply has no exposure measure.
merge m:1 mode_union using "`union'", keep(master match) generate(_mg_union)
assert _N == `n_in'

quietly count if _mg_union == 1
local nomatch = r(N)
di as text "[union] `nomatch' of `n_in' firm-years had no mode_union match"
drop _mg_union

save "$unionexp_out", replace
di as result _newline "SAVED: $unionexp_out"
di as text "  `=_N' obs, `c(k)' vars"
