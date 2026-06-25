********************************************************************************
* extpre_build.do
* Build 2007-2008 firm-year outcomes from raw RAIS (parquet -> worker panels in
* Python, see extpre/worker_pre_YYYY.dta) and APPEND them to the main-results
* analysis panel, so the event studies / pre-trend tests gain pre-periods 2007-08.
*
* Outcomes are rebuilt with the EXACT live recipe:
*   - worker selection: dec-active (empem3112=1 & tempempr>1), max-hours spell,
*     one spell per worker-firm  -> validated vs live 2009 to machine precision.
*   - deflator: raw remdezr / ipca_y, ipca pos = year-2006 (2007=.607949, 2008=.643835).
*   - firm-year outcomes: (mean) log wages, (egen pctile by cnpj_year) percentiles,
*     (count) employment -- identical method to 121_get_wage_pctiles_df2.do.
*
* Output: $rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2_extpre.dta
********************************************************************************

version 17.0
set more off
set varabbrev off

* ---- globals (local Mac layout; see unionspill-local-stata-run memory) --------
global root     "/Users/luisg/Library/CloudStorage/OneDrive-NorthwesternUniversity/4 - PhD/02_Research/Org_Econ BR/UnionSpillovers/Cluster/UnionSpill"
global rais_firm "$root/Data/CBA_rais_firm_level"
global rais_aux  "$root/Data/RAIS_aux"
global extpre    "$rais_aux/extpre"

local pcts 10 20 25 50 75 80 90
local pctvars ""
foreach yv in lr_remdezr_w lr_remdezr_h_w {
	foreach q of local pcts {
		local pctvars "`pctvars' `yv'_p`q'"
	}
}
di as result "percentile vars: `pctvars'"

* =============================================================================
* STEP 1: collapse worker panels -> firm-year outcomes (2009 for validation; 2007,2008)
* =============================================================================
foreach y in 2009 2007 2008 {

	di as result _newline "=== building firm-year outcomes for `y' ==="
	use "$extpre/worker_pre_`y'.dta", clear

	* percentiles by firm-year (cnpj_year), EXACT 121 method
	foreach yv in lr_remdezr_w lr_remdezr_h_w {
		foreach q of local pcts {
			egen `yv'_p`q' = pctile(`yv'), by(cnpj_year) p(`q')
		}
	}

	collapse (mean) lr_remdezr_w lr_remdezr_h_w ///
	         (firstnm) `pctvars', by(identificad)

	gen int year = `y'
	* firm employment counted over ALL dec-active max-hours workers (incl. zero-wage),
	* matching the live definition (built separately, no remdezr>0 filter)
	merge 1:1 identificad year using "$extpre/firmemp_pre_`y'.dta", keep(master match) nogen
	gen double l_firm_emp = ln(firm_emp)
	order identificad year
	save "$extpre/firmyear_pre_`y'.dta", replace
	di as result "  firms: " _N
}

* =============================================================================
* STEP 2: VALIDATION -- rebuilt 2009 vs live 2009 (must match)
* =============================================================================
di as result _newline "=== VALIDATION: rebuilt 2009 vs live 2009 ==="
use "$extpre/firmyear_pre_2009.dta", clear
foreach v in lr_remdezr_w lr_remdezr_h_w l_firm_emp firm_emp `pctvars' {
	rename `v' `v'__c
}
tempfile calc2009
save `calc2009'

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear
keep if year==2009
keep identificad year lr_remdezr_w lr_remdezr_h_w l_firm_emp firm_emp `pctvars'
merge 1:1 identificad year using `calc2009', keep(match) nogen

di as result "var | corr | mean(live-calc) | sd"
foreach v in lr_remdezr_w lr_remdezr_h_w l_firm_emp `pctvars' {
	qui corr `v' `v'__c
	local c = r(rho)
	qui gen double _d = `v' - `v'__c
	qui sum _d
	di as text %-22s "`v'" "  corr=" %7.5f `c' "  mean(d)=" %9.5f r(mean) "  sd=" %8.5f r(sd)
	drop _d
}

* =============================================================================
* STEP 3: build appended panel (clone 2009 rows -> 2007 & 2008, swap outcomes)
* =============================================================================
di as result _newline "=== STEP 3: constructing appended panel ==="
local outcomes "lr_remdezr_w lr_remdezr_h_w l_firm_emp firm_emp `pctvars'"

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear
tempfile fullpanel
save `fullpanel'

foreach y in 2007 2008 {
	use `fullpanel', clear
	keep if year==2009
	replace year = `y'
	* drop outcome vars so the merge supplies the rebuilt `y' values
	foreach v of local outcomes {
		capture drop `v'
	}
	merge 1:1 identificad year using "$extpre/firmyear_pre_`y'.dta", ///
		keep(master match) nogen
	tempfile pre`y'
	save `pre`y''
}

use `fullpanel', clear
append using `pre2007'
append using `pre2008'
sort identificad year

* sanity: year coverage
di as result "year coverage of extended panel:"
tab year

* mark the rebuilt pre rows for transparency
cap drop extpre_row
gen byte extpre_row = inlist(year,2007,2008)
label var extpre_row "Row rebuilt from raw RAIS (2007-08 pre-period extension)"

save "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2_extpre.dta", replace
di as result _newline "SAVED: $rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2_extpre.dta"
di as result "Done."
