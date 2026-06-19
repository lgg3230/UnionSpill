********************************************************************************
* honest_did.do
* Rambachan-Roth (2023) honest-DiD sensitivity analysis for the 8 main event
* studies: {direct, spillover} x {lr_remdezr_w, lr_remdezr_h_w, l_firm_emp,
* numb_clauses}. Each spec is estimated standalone (its own event-study
* coefficient vector + cluster-robust VCV), exactly as in the paper:
*   - direct   : i.treat_ultra ## ib2011.year  (wages/emp) ; ib(2).cba_period (clauses)
*   - spillover : c.totaltreat_pw_norm ## ib2011.year (wages/emp) ; ib(2).cba_period (clauses)
* Estimation (sample, FE, clustering) is copied verbatim from
*   Programs/main_results/main_results.do  and
*   Programs/main_results/panelC_and_spill_numb_clauses.do
* so coefficients reproduce the headline specs.
*
* Restrictions:
*   Delta^RM (relative magnitudes) : Mbar grid 0(0.25)2, identical across all 8 (scale-free).
*   Delta^SD (smoothness)          : M grid 0..sd_ub per outcome (sd_ub data-scaled; M is in
*                                    outcome units, so it is NOT comparable across outcomes).
* Method: C-LF (conditional least-favorable, ECOS solver). FLCI is unavailable on this
* cluster (OSQP plugin needs GLIBC_2.34 > el8's 2.28); see ado/honestdid.ado patch note.
*
* numb_clauses has only 1 pre-period (period 1; period 2 = reference), so Delta^RM /
* Delta^SD may be infeasible -- those calls are wrapped in -capture- and flagged.
*
* Output:
*   Tables/honest_did/honest_did_results.csv  (long: effect,outcome,restriction,m,lb,ub,is_original)
*   Then auto-runs the Python summary/plot script.
********************************************************************************

version 17.0
set more off
set varabbrev off

adopath ++ "$programs/honest_did/ado"   // patched honestdid (OSQP gate removed)

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
cap mkdir "$logs/honest_did"
log using "$logs/honest_did/honest_did_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
cap mkdir "$tables/honest_did"
cap mkdir "$graphs/honest_did"

********************************************************************************
* SECTION 1: LOAD AND MERGE   (verbatim from panelC_and_spill_numb_clauses.do)
********************************************************************************

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

preserve
	import delimited "$rais_aux/totalflows_wide_2007_2011.csv", clear
	tostring identificad, replace format(%014.0f) force
	tempfile totalflows_wide
	save `totalflows_wide'
restore
merge m:1 identificad using `totalflows_wide', keep(master match) nogen

gen double totalflows_pw_pre_07_11     = 0
gen        totalflows_pw_pre_07_11_cnt = 0
foreach yp in totalflows_pw_07_08 totalflows_pw_08_09 totalflows_pw_09_10 totalflows_pw_10_11 {
	replace totalflows_pw_pre_07_11     = totalflows_pw_pre_07_11 + `yp' if !missing(`yp')
	replace totalflows_pw_pre_07_11_cnt = totalflows_pw_pre_07_11_cnt + (!missing(`yp'))
}
replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 / totalflows_pw_pre_07_11_cnt ///
	if totalflows_pw_pre_07_11_cnt > 0
replace totalflows_pw_pre_07_11 = . if totalflows_pw_pre_07_11_cnt == 0
drop totalflows_pw_pre_07_11_cnt

keep if year >= 2009
keep if lagos_sample_avg == 1

di as result "Sample size after restrictions: " _N

********************************************************************************
* SECTION 2: VARIABLES   (verbatim from panelC_and_spill_numb_clauses.do)
********************************************************************************

cap drop treat_year
gen byte treat_year = (year >= 2012)

cap drop placebo_year
gen byte placebo_year = (year < 2011)

cap drop cba_period
cap drop pre_treat_cba
cap drop post_treat_cba
gen cba_period = .
replace cba_period = 1 if avg_file_date == earliest2009_avg - 1 & !missing(avg_file_date)
replace cba_period = 2 if avg_file_date == second_cba_avg       & !missing(avg_file_date)
replace cba_period = 3 if inrange(avg_file_date, mdy(1,1,2013), mdy(12,31,2013)) & cba_period == .
replace cba_period = 4 if inrange(avg_file_date, mdy(1,1,2014), mdy(12,31,2014)) & cba_period == .
replace cba_period = 5 if inrange(avg_file_date, mdy(1,1,2015), mdy(12,31,2015)) & cba_period == .
replace cba_period = 6 if inrange(avg_file_date, mdy(1,1,2016), mdy(12,31,2016)) & cba_period == .
gen pre_treat_cba  = cond(cba_period < 2,  1, 0)
gen post_treat_cba = cond(cba_period >= 3, 1, 0) if !missing(cba_period)

* ── Connectivity (same normalization as headline) ──────────────────────────
local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen double totaltreat_pw_n_p90 = r(p90)
gen double totaltreat_pw_norm  = totaltreat_pw_n / totaltreat_pw_n_p90

* ── Pre-treatment means ─────────────────────────────────────────────────────
cap drop firm_emp_pre_o
cap drop firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre   = min(firm_emp_pre_o)
	drop firm_emp_pre_o
}

cap drop l_firm_emp_pre
gen double l_firm_emp_pre = ln(firm_emp_pre)

foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {
	cap drop `outcome'_pre_o
	cap drop `outcome'_pre
	quietly {
		bys identificad: egen `outcome'_pre_o = mean(`outcome') if inrange(year, 2009, 2011)
		bys identificad: egen `outcome'_pre   = min(`outcome'_pre_o)
		drop `outcome'_pre_o
	}
}

cap drop numb_clauses_pre_o
cap drop numb_clauses_pre
quietly {
	bys identificad: egen numb_clauses_pre_o = mean(numb_clauses) if inrange(cba_period, 1, 2)
	bys identificad: egen numb_clauses_pre   = min(numb_clauses_pre_o)
	drop numb_clauses_pre_o
}

* ── 4-bin controls ──────────────────────────────────────────────────────────
cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
quietly {
	egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) ///
		if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
	drop l_firm_emp_pre4_o
}

foreach v in lr_remdezr_w lr_remdezr_h_w numb_clauses {
	cap drop `v'_pre4_o
	cap drop `v'_pre4
	quietly {
		egen `v'_pre4_o = cut(`v'_pre) ///
			if year == 2009 & in_balanced_panel == 1, group(4)
		bys identificad: egen `v'_pre4 = min(`v'_pre4_o)
		drop `v'_pre4_o
	}
}

cap drop totalflows_pw_pre_07_114_o
cap drop totalflows_pw_pre_07_114
quietly {
	egen totalflows_pw_pre_07_114_o = cut(totalflows_pw_pre_07_11) ///
		if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen totalflows_pw_pre_07_114 = min(totalflows_pw_pre_07_114_o)
	drop totalflows_pw_pre_07_114_o
	replace totalflows_pw_pre_07_114 = 0 if missing(totalflows_pw_pre_07_114)
}

di as result "All variables created."

********************************************************************************
* HELPERS
********************************************************************************

* Resolve a factor-interaction coefficient name regardless of operand order.
capture program drop _hd_cn
program define _hd_cn, rclass
	args p1 p2
	tempname b
	matrix `b' = e(b)
	local c1 = colnumb(`b', "`p1'#`p2'")
	if (`c1' < . & `c1' > 0) return local cn "`p1'#`p2'"
	else                     return local cn "`p2'#`p1'"
end

* Build ordered b/V (persistent matrices HDB 1xk, HDV kxk) from the active
* e(b)/e(V) for the coefficient names in global HDID_CN (space separated, in
* chronological pre-then-post order). These shared matrices are consumed by BOTH
* _hd_run (honestdid) and _pt_run (pretrends), so each regression is run once.
capture program drop _bv_extract
program define _bv_extract
	local cnames "$HDID_CN"
	local k : word count `cnames'
	tempname bf Vf
	matrix `bf' = e(b)
	matrix `Vf' = e(V)
	matrix HDB = J(1, `k', .)
	matrix HDV = J(`k', `k', .)
	local i = 0
	foreach cn of local cnames {
		local ++i
		local ci = colnumb(`bf', "`cn'")
		matrix HDB[1,`i'] = `bf'[1,`ci']
		local j = 0
		foreach cm of local cnames {
			local ++j
			local cj = colnumb(`bf', "`cm'")
			matrix HDV[`i',`j'] = `Vf'[`ci',`cj']
		}
	}
	matrix colnames HDB = `cnames'
	matrix colnames HDV = `cnames'
	matrix rownames HDV = `cnames'
end

* Run honestdid (Delta^RM and Delta^SD) on the shared HDB/HDV and append CI rows.
*   args: effect outcome numpre
capture program drop _hd_run
program define _hd_run
	args effect outcome numpre
	local k = colsof(HDB)

	* data-scaled SD grid: 4 * RMS of post-period coef SEs, in 20 steps
	local np1 = `numpre' + 1
	local sumsq = 0
	local cnt   = 0
	forvalues p = `np1'/`k' {
		local sumsq = `sumsq' + HDV[`p',`p']
		local ++cnt
	}
	local sd_ub  = 4 * sqrt(`sumsq'/`cnt')
	local sd_stp = `sd_ub' / 20

	di as result "=== honestdid `effect' `outcome' : numpre=`numpre', k=`k', sd_ub=`sd_ub' ==="

	* ── Delta^RM (relative magnitudes), fixed grid 0(0.25)2 ──────────────────
	capture noisily honestdid, b(HDB) vcov(HDV) numpre(`numpre') ///
		delta(rm) mvec(0(0.25)2) method(C-LF)
	if (_rc == 0) {
		local obj `s(HonestEventStudy)'
		tempname CI
		mata: st_matrix("`CI'", `obj'.CI)
		_hd_writeci `CI' "`effect'" "`outcome'" "rm"
	}
	else {
		di as error ">>> RM FAILED for `effect' `outcome' (rc=`=_rc') -- flag"
		_hd_writefail "`effect'" "`outcome'" "rm"
	}

	* ── Delta^SD (smoothness), data-scaled grid, C-LF (FLCI unavailable) ─────
	capture noisily honestdid, b(HDB) vcov(HDV) numpre(`numpre') ///
		delta(sd) mvec(0(`sd_stp')`sd_ub') method(C-LF)
	if (_rc == 0) {
		local obj `s(HonestEventStudy)'
		tempname CI
		mata: st_matrix("`CI'", `obj'.CI)
		_hd_writeci `CI' "`effect'" "`outcome'" "sd"
	}
	else {
		di as error ">>> SD FAILED for `effect' `outcome' (rc=`=_rc') -- flag"
		_hd_writefail "`effect'" "`outcome'" "sd"
	}
end

* Run pretrends (Roth 2022) on shared HDB/HDV at 50% and 80% power; append the
* event-study + hypothesized-trend + conditional-on-passing rows to the CSV.
*   ES cols: 1 time, 2 coef, 3 ci_lo, 4 ci_hi, 5 trend, 6 E[coef|passed test]
*   args: effect outcome numpre
capture program drop _pt_run
program define _pt_run
	args effect outcome numpre
	di as result "=== pretrends `effect' `outcome' : numpre=`numpre' ==="
	foreach pw in 50 80 {
		local plev = `pw'/100
		capture noisily pretrends, b(HDB) vcov(HDV) numpre(`numpre') ///
			power(`plev') nocoefplot
		if (_rc == 0) {
			local slope = r(slope)
			local obj `r(PreTrendsResults)'
			tempname ES
			mata: st_matrix("`ES'", `obj'.ES)
			_pt_writees `ES' "`effect'" "`outcome'" "`pw'" `slope'
		}
		else {
			di as error ">>> pretrends p`pw' FAILED for `effect' `outcome' (rc=`=_rc')"
			tempname fh
			file open `fh' using "$tables/honest_did/pretrends_results.csv", write append
			file write `fh' "`effect',`outcome',`pw',,,,,,,FAILED" _n
			file close `fh'
		}
	}
end

capture program drop _pt_writees
program define _pt_writees
	args ESmat effect outcome power slope
	local nr = rowsof(`ESmat')
	tempname fh
	file open `fh' using "$tables/honest_did/pretrends_results.csv", write append
	forvalues r = 1/`nr' {
		file write `fh' "`effect',`outcome',`power'," ///
			%9.0g (`ESmat'[`r',1]) "," %12.0g (`ESmat'[`r',2]) "," ///
			%12.0g (`ESmat'[`r',3]) "," %12.0g (`ESmat'[`r',4]) "," ///
			%12.0g (`ESmat'[`r',5]) "," %12.0g (`ESmat'[`r',6]) "," ///
			%12.0g (`slope') _n
	}
	file close `fh'
end

* Append CI matrix rows (col1=M [.=Original], col2=lb, col3=ub) to the CSV.
capture program drop _hd_writeci
program define _hd_writeci
	args CImat effect outcome restriction
	local nr = rowsof(`CImat')
	tempname fh
	file open `fh' using "$tables/honest_did/honest_did_results.csv", write append
	forvalues r = 1/`nr' {
		local m  = `CImat'[`r',1]
		local lb = `CImat'[`r',2]
		local ub = `CImat'[`r',3]
		local isorig = cond(missing(`m'), 1, 0)
		local mstr = cond(missing(`m'), "", "`=`m''")
		file write `fh' "`effect',`outcome',`restriction',`mstr'," ///
			%12.0g (`lb') "," %12.0g (`ub') ",`isorig'" _n
	}
	file close `fh'
end

capture program drop _hd_writefail
program define _hd_writefail
	args effect outcome restriction
	tempname fh
	file open `fh' using "$tables/honest_did/honest_did_results.csv", write append
	file write `fh' "`effect',`outcome',`restriction',,,,FAILED" _n
	file close `fh'
end

********************************************************************************
* INITIALIZE RESULTS CSV
********************************************************************************

capture erase "$tables/honest_did/honest_did_results.csv"
tempname fh
file open `fh' using "$tables/honest_did/honest_did_results.csv", write replace
file write `fh' "effect,outcome,restriction,m,lb,ub,is_original" _n
file close `fh'

capture erase "$tables/honest_did/pretrends_results.csv"
tempname fh
file open `fh' using "$tables/honest_did/pretrends_results.csv", write replace
file write `fh' "effect,outcome,power,time,coef,ci_lo,ci_hi,trend,cond_mean,slope" _n
file close `fh'

********************************************************************************
* SECTION 3: YEAR-BASED SPECS (lr_remdezr_w, lr_remdezr_h_w, l_firm_emp)
*   pre-periods 2009,2010 ; reference 2011 ; post 2012-2016  -> numpre=2
********************************************************************************

local conn        "totaltreat_pw_norm"
local base_fe     "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local extra_year  "ib0.totalflows_pw_pre_07_114#i.year"
local s_direct_C  "(treat_ultra==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local yrs_es      "2009 2010 2012 2013 2014 2015 2016"

foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {

	local absorb "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

	* ── SPILLOVER : c.conn ## ib2011.year ───────────────────────────────────
	reghdfe `outcome' c.`conn'##ib2011.year if `s_spill', ///
		absorb(`absorb') vce(cluster identificad)
	global HDID_CN ""
	foreach yr of local yrs_es {
		_hd_cn "`yr'.year" "c.`conn'"
		global HDID_CN "$HDID_CN `r(cn)'"
	}
	_bv_extract
	_hd_run "spill" "`outcome'" 2
	_pt_run "spill" "`outcome'" 2

	* ── DIRECT : i.treat_ultra ## ib2011.year ───────────────────────────────
	reghdfe `outcome' i.treat_ultra##ib2011.year if `s_direct_C', ///
		absorb(`absorb') vce(cluster identificad)
	global HDID_CN ""
	foreach yr of local yrs_es {
		_hd_cn "1.treat_ultra" "`yr'.year"
		global HDID_CN "$HDID_CN `r(cn)'"
	}
	_bv_extract
	_hd_run "direct" "`outcome'" 2
	_pt_run "direct" "`outcome'" 2
}

********************************************************************************
* SECTION 4: numb_clauses (CBA-period structure)
*   pre period 1 ; reference period 2 ; post periods 3-6  -> numpre=1
*   (only 1 pre-period: RM/SD may be infeasible -- handled by capture + flag)
********************************************************************************

local base_fe_cba "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period"
local extra_cba   "ib0.totalflows_pw_pre_07_114#i.cba_period"
local absorb_cba  "`base_fe_cba' ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"
local cba_es      "1 3 4 5 6"

* ── SPILLOVER : c.conn ## ib(2).cba_period ──────────────────────────────────
reghdfe numb_clauses c.`conn'##ib(2).cba_period ///
	if `s_spill' & !missing(cba_period), ///
	absorb(`absorb_cba') vce(cluster identificad)
global HDID_CN ""
foreach p of local cba_es {
	_hd_cn "`p'.cba_period" "c.`conn'"
	global HDID_CN "$HDID_CN `r(cn)'"
}
_bv_extract
_hd_run "spill" "numb_clauses" 1
_pt_run "spill" "numb_clauses" 1

* ── DIRECT : i.treat_ultra ## ib(2).cba_period ──────────────────────────────
reghdfe numb_clauses i.treat_ultra##ib(2).cba_period ///
	if `s_direct_C' & !missing(cba_period), ///
	absorb(`absorb_cba') vce(cluster identificad)
global HDID_CN ""
foreach p of local cba_es {
	_hd_cn "1.treat_ultra" "`p'.cba_period"
	global HDID_CN "$HDID_CN `r(cn)'"
}
_bv_extract
_hd_run "direct" "numb_clauses" 1
_pt_run "direct" "numb_clauses" 1

di as result "All 8 specs done."

********************************************************************************
* SECTION 5: PYTHON SUMMARY + PLOTS
********************************************************************************
if "`c(username)'" == "lgg3230" {
	local py ~/.conda/envs/venv_python312/bin/python
}
else {
	local py python3
}
shell `py' "$programs/honest_did/honest_did_plot.py"
shell `py' "$programs/honest_did/pretrends_plot.py"

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && ///
	notify "Stata done" "honest_did.do finished"

log close
