********************************************************************************
* main_logclauses.do
* Standalone table builder requested by Luis: the traditional main outcomes
* PLUS log clause count, for the direct effects (Panels A, B, C) and the
* spillover effect, and a final clause-type section with log clauses added.
*
* Outcomes (Table 1, main):
*   lr_remdezr_w     log December earnings        (year structure)
*   lr_remdezr_h_w   log hourly December earnings (year structure)
*   l_firm_emp       log December employment      (year structure)
*   numb_clauses     CBA clause count             (CBA-period structure)
*   l_numb_clauses   log clause count = ln(1+numb_clauses) (CBA-period structure)
*
* Table 2 (final section, direct effects only): clause-type counts
*   numb_clauses | wage_clauses | emp_clauses | other_clauses | l_numb_clauses
*
* Specs are copied verbatim from 4012_pct_tfpw.do (year + CBA
* structures, samples A/B/C, spillover) and 4032_clause_types.do (clause-type
* construction), so the shared columns reproduce the existing headline tables.
* l_numb_clauses uses the SAME controls as numb_clauses (numb_clauses_pre4 bins).
*
* Output (Tables/logclauses/):
*   main_logclauses.csv               Table 1 (sections direct_A/B/C, spill)
*   clausetypes_logclauses_direct.csv Table 2 (sections direct_A/B/C)
*   logclauses_obs_accounting.csv     obs/firm counts: zeros, missing, log loss
********************************************************************************

version 17.0
set more off
set varabbrev off

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
cap mkdir "$logs/main_results"
log using "$logs/main_results/main_logclauses_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
cap mkdir "$tables/logclauses"

********************************************************************************
* SECTION 1: LOAD AND MERGE   (verbatim from 4012_pct_tfpw.do)
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
* SECTION 2: CLAUSE-TYPE COUNTS   (verbatim from 4032_clause_types.do Section 2)
********************************************************************************

cap drop wage_clauses
cap drop emp_clauses
cap drop other_clauses
gen int wage_clauses  = 0
gen int emp_clauses   = 0
gen int other_clauses = 0

ds cl_*
local clause_vars `r(varlist)'
foreach v of local clause_vars {
	if substr("`v'", 4, 1) == "1" {
		replace wage_clauses = wage_clauses + cond(missing(`v'), 0, `v')
	}
	else if inlist(substr("`v'", 4, 1), "3", "4") {
		replace emp_clauses = emp_clauses + cond(missing(`v'), 0, `v')
	}
	else if inlist(substr("`v'", 4, 1), "2", "5", "6", "7", "8", "9") {
		replace other_clauses = other_clauses + cond(missing(`v'), 0, `v')
	}
}
label var wage_clauses  "Count of wage-related clauses"
label var emp_clauses   "Count of employment clauses"
label var other_clauses "Count of other clauses"

********************************************************************************
* SECTION 3: VARIABLE CREATION
********************************************************************************

cap drop placebo_year
gen byte placebo_year = (year < 2011)
cap drop treat_year
gen byte treat_year = (year >= 2012)

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

* ── log clause count: ln(numb_clauses) (drops zero-clause firm-periods) ───────
cap drop l_numb_clauses
gen double l_numb_clauses = ln(numb_clauses)
label var l_numb_clauses "Log clause count, ln(numb_clauses)"

* ── Connectivity ──────────────────────────────────────────────────────────────
local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"
cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen double totaltreat_pw_n_p90 = r(p90)
gen double totaltreat_pw_norm  = totaltreat_pw_n / totaltreat_pw_n_p90

* ── Pre-treatment means & log emp ─────────────────────────────────────────────
cap drop firm_emp_pre_o
cap drop firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre   = min(firm_emp_pre_o)
	drop firm_emp_pre_o
}
foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {
	cap drop `outcome'_pre_o
	cap drop `outcome'_pre
	quietly {
		bys identificad: egen `outcome'_pre_o = mean(`outcome') if inrange(year, 2009, 2011)
		bys identificad: egen `outcome'_pre   = min(`outcome'_pre_o)
		drop `outcome'_pre_o
	}
}

* Overwrite l_firm_emp_pre with ln(mean(firm_emp)) AFTER the loop above
* (the loop transiently sets it to mean(l_firm_emp); canonical uses ln-of-mean).
cap drop l_firm_emp_pre
gen double l_firm_emp_pre = ln(firm_emp_pre)

* clause-type pre means (CBA-period 1-2 based, like Main_Results / clause_types)
foreach v in numb_clauses wage_clauses emp_clauses other_clauses {
	cap drop `v'_pre_o
	cap drop `v'_pre
	quietly {
		bys identificad: egen `v'_pre_o = mean(`v') if inrange(cba_period, 1, 2)
		bys identificad: egen `v'_pre   = min(`v'_pre_o)
		drop `v'_pre_o
	}
}

* ── 4-bin pre-treatment controls ──────────────────────────────────────────────
cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
quietly {
	egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
	drop l_firm_emp_pre4_o
}

foreach v in lr_remdezr_w lr_remdezr_h_w numb_clauses wage_clauses emp_clauses other_clauses {
	cap drop `v'_pre4_o
	cap drop `v'_pre4
	quietly {
		egen `v'_pre4_o = cut(`v'_pre) if year == 2009 & in_balanced_panel == 1, group(4)
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
* SPEC / FE GLOBALS (visible to estimation program)
********************************************************************************

global conn         "totaltreat_pw_norm"
global base_fe      "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
global base_fe_cba  "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period"
global extra_year   "ib0.totalflows_pw_pre_07_114#i.year"
global extra_cba    "ib0.totalflows_pw_pre_07_114#i.cba_period"

global s_direct_A "(treat_ultra==0 & totaltreat_pw_n==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
global s_direct_B "(treat_ultra==0 & totaltreat_pw_n<=0.01 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
global s_direct_C "(treat_ultra==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
global s_spill    "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

********************************************************************************
* HELPERS
********************************************************************************

capture program drop _stars
program define _stars, rclass
	args p
	local s ""
	if      `p' < 0.01 local s "***"
	else if `p' < 0.05 local s "**"
	else if `p' < 0.10 local s "*"
	return local stars "`s'"
end

* Estimate one cell and append the 7 rows (main, main_se, pre, pre_se,
* pre_pval, n_obs, n_estab) to `csv'.
*   args: csv section outcome struct mode prebin samp
*     struct = year | cba
*     mode   = direct | spill
*     prebin = base name of the *_pre4 control for this outcome
*     samp   = the sample restriction expression (text)
capture program drop _cell
program define _cell
	args csv section outcome struct mode prebin samp

	if "`struct'" == "year" {
		local absorb "$base_fe ib0.`prebin'_pre4#i.year ib0.l_firm_emp_pre4#i.year $extra_year"

		if "`mode'" == "direct" {
			reghdfe `outcome' treat_ultra##i.treat_year if `samp', ///
				absorb(`absorb') vce(cluster identificad)
			local b_post  = _b[1.treat_ultra#1.treat_year]
			local se_post = _se[1.treat_ultra#1.treat_year]
			local df_post = e(df_r)
			local n_obs   = e(N)
			local n_estab = e(N_clust)

			reghdfe `outcome' treat_ultra##i.placebo_year if `samp' & year <= 2011, ///
				absorb(`absorb') vce(cluster identificad)
			local b_pre  = _b[1.treat_ultra#1.placebo_year]
			local se_pre = _se[1.treat_ultra#1.placebo_year]
			local df_pre = e(df_r)

			reghdfe `outcome' i.treat_ultra##ib2011.year if `samp', ///
				absorb(`absorb') vce(cluster identificad)
			testparm 1.treat_ultra#i(2009 2010).year
			local prepval = r(p)
		}
		else {
			reghdfe `outcome' c.$conn##i.treat_year if `samp', ///
				absorb(`absorb') vce(cluster identificad)
			local b_post  = _b[1.treat_year#c.$conn]
			local se_post = _se[1.treat_year#c.$conn]
			local df_post = e(df_r)
			local n_obs   = e(N)
			local n_estab = e(N_clust)

			reghdfe `outcome' c.$conn##i.placebo_year if `samp' & year <= 2011, ///
				absorb(`absorb') vce(cluster identificad)
			local b_pre  = _b[1.placebo_year#c.$conn]
			local se_pre = _se[1.placebo_year#c.$conn]
			local df_pre = e(df_r)

			reghdfe `outcome' c.$conn##ib2011.year if `samp', ///
				absorb(`absorb') vce(cluster identificad)
			testparm c.$conn#i(2009 2010).year
			local prepval = r(p)
		}
	}
	else {
		local absorb "$base_fe_cba ib0.`prebin'_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period $extra_cba"

		if "`mode'" == "direct" {
			reghdfe `outcome' i.treat_ultra##post_treat_cba ///
				if `samp' & !missing(cba_period), ///
				absorb(`absorb') vce(cluster identificad)
			local b_post  = _b[1.treat_ultra#1.post_treat_cba]
			local se_post = _se[1.treat_ultra#1.post_treat_cba]
			local df_post = e(df_r)
			local n_obs   = e(N)
			local n_estab = e(N_clust)

			reghdfe `outcome' i.treat_ultra##pre_treat_cba ///
				if `samp' & !missing(cba_period) & cba_period <= 2, ///
				absorb(`absorb') vce(cluster identificad)
			local b_pre  = _b[1.treat_ultra#1.pre_treat_cba]
			local se_pre = _se[1.treat_ultra#1.pre_treat_cba]
			local df_pre = e(df_r)

			reghdfe `outcome' i.treat_ultra##ib2.cba_period ///
				if `samp' & !missing(cba_period), ///
				absorb(`absorb') vce(cluster identificad)
			testparm 1.treat_ultra#1.cba_period
			local prepval = r(p)
		}
		else {
			reghdfe `outcome' c.$conn##post_treat_cba ///
				if `samp' & !missing(cba_period), ///
				absorb(`absorb') vce(cluster identificad)
			local b_post  = _b[1.post_treat_cba#c.$conn]
			local se_post = _se[1.post_treat_cba#c.$conn]
			local df_post = e(df_r)
			local n_obs   = e(N)
			local n_estab = e(N_clust)

			reghdfe `outcome' c.$conn##pre_treat_cba ///
				if `samp' & !missing(cba_period) & cba_period <= 2, ///
				absorb(`absorb') vce(cluster identificad)
			local b_pre  = _b[1.pre_treat_cba#c.$conn]
			local se_pre = _se[1.pre_treat_cba#c.$conn]
			local df_pre = e(df_r)

			reghdfe `outcome' c.$conn##ib2.cba_period ///
				if `samp' & !missing(cba_period), ///
				absorb(`absorb') vce(cluster identificad)
			testparm c.$conn#1.cba_period
			local prepval = r(p)
		}
	}

	local p_post = 2*ttail(`df_post', abs(`b_post'/`se_post'))
	local p_pre  = 2*ttail(`df_pre',  abs(`b_pre'/`se_pre'))
	_stars `p_post'
	local stars_post "`r(stars)'"
	_stars `p_pre'
	local stars_pre "`r(stars)'"

	tempname fh
	file open `fh' using "`csv'", write append
	file write `fh' `""`section'";"`outcome'";"main";"'    %9.4f (`b_post')  `"`stars_post'""' _n
	file write `fh' `""`section'";"`outcome'";"main_se";"' %9.4f (`se_post') `"""'             _n
	file write `fh' `""`section'";"`outcome'";"pre";"'     %9.4f (`b_pre')   `"`stars_pre'""'  _n
	file write `fh' `""`section'";"`outcome'";"pre_se";"'  %9.4f (`se_pre')  `"""'             _n
	file write `fh' `""`section'";"`outcome'";"pre_pval";"' %9.4f (`prepval') `"""'            _n
	file write `fh' `""`section'";"`outcome'";"n_obs";"'   %12.0fc (`n_obs')   `"""'           _n
	file write `fh' `""`section'";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""'           _n
	file close `fh'
end

********************************************************************************
* TABLE 1: MAIN OUTCOMES + LOG CLAUSES  (direct A/B/C + spillover)
********************************************************************************

local t1 "$tables/logclauses/main_logclauses.csv"
capture erase "`t1'"
tempname fh
file open `fh' using "`t1'", write replace
file write `fh' "section;outcome;row_type;value" _n
file close `fh'

* year-structure outcomes: prebin = own pre4 ; cba-structure clause outcomes:
* prebin = numb_clauses_pre4 for BOTH numb_clauses and l_numb_clauses.
foreach panel in A B C {
	local samp "${s_direct_`panel'}"
	local sec  "direct_`panel'"
	di as result "--- Table 1 direct `panel' ---"
	_cell "`t1'" "`sec'" "lr_remdezr_w"   "year" "direct" "lr_remdezr_w"   "`samp'"
	_cell "`t1'" "`sec'" "lr_remdezr_h_w" "year" "direct" "lr_remdezr_h_w" "`samp'"
	_cell "`t1'" "`sec'" "l_firm_emp"     "year" "direct" "l_firm_emp"     "`samp'"
	_cell "`t1'" "`sec'" "numb_clauses"   "cba"  "direct" "numb_clauses"   "`samp'"
	_cell "`t1'" "`sec'" "l_numb_clauses" "cba"  "direct" "numb_clauses"   "`samp'"
}

di as result "--- Table 1 spillover ---"
local samp "${s_spill}"
_cell "`t1'" "spill" "lr_remdezr_w"   "year" "spill" "lr_remdezr_w"   "`samp'"
_cell "`t1'" "spill" "lr_remdezr_h_w" "year" "spill" "lr_remdezr_h_w" "`samp'"
_cell "`t1'" "spill" "l_firm_emp"     "year" "spill" "l_firm_emp"     "`samp'"
_cell "`t1'" "spill" "numb_clauses"   "cba"  "spill" "numb_clauses"   "`samp'"
_cell "`t1'" "spill" "l_numb_clauses" "cba"  "spill" "numb_clauses"   "`samp'"

di as result "Table 1 done."

********************************************************************************
* TABLE 2: CLAUSE TYPES + LOG CLAUSES  (direct A/B/C)
*   columns: numb_clauses wage_clauses emp_clauses other_clauses l_numb_clauses
********************************************************************************

local t2 "$tables/logclauses/clausetypes_logclauses_direct.csv"
capture erase "`t2'"
tempname fh
file open `fh' using "`t2'", write replace
file write `fh' "section;outcome;row_type;value" _n
file close `fh'

foreach panel in A B C {
	local samp "${s_direct_`panel'}"
	local sec  "direct_`panel'"
	di as result "--- Table 2 direct `panel' ---"
	_cell "`t2'" "`sec'" "numb_clauses"   "cba" "direct" "numb_clauses"   "`samp'"
	_cell "`t2'" "`sec'" "wage_clauses"   "cba" "direct" "wage_clauses"   "`samp'"
	_cell "`t2'" "`sec'" "emp_clauses"    "cba" "direct" "emp_clauses"    "`samp'"
	_cell "`t2'" "`sec'" "other_clauses"  "cba" "direct" "other_clauses"  "`samp'"
	_cell "`t2'" "`sec'" "l_numb_clauses" "cba" "direct" "numb_clauses"   "`samp'"
}

di as result "Table 2 done."

********************************************************************************
* SECTION: OBS / FIRM ACCOUNTING FOR THE LOG TRANSFORM
*   For each clause-regression sample, report (on the CBA-period estimation
*   universe, i.e. !missing(cba_period) & !missing(numb_clauses)):
*     n_obs, n_firms                       — the numb_clauses / l_numb_clauses sample
*     n_obs_zero, n_firms_zero             — firms with numb_clauses==0
*     n_obs_missing                        — numb_clauses missing (dropped by reghdfe)
*   ln(1+numb_clauses) keeps the zeros (lost nothing vs level);
*   plain ln(numb_clauses) would drop exactly the zero rows.
********************************************************************************

local acc "$tables/logclauses/logclauses_obs_accounting.csv"
capture erase "`acc'"
tempname fh
file open `fh' using "`acc'", write replace
file write `fh' "sample;n_obs;n_firms;n_obs_zero;n_firms_zero;n_obs_missing;n_firms_anyzero" _n
file close `fh'

foreach s in A B C spill {
	if "`s'" == "spill" local samp "${s_spill}"
	else                 local samp "${s_direct_`s'}"

	* estimation universe for numb_clauses / l_numb_clauses
	local uni "`samp' & !missing(cba_period) & !missing(numb_clauses)"

	count if `uni'
	local n_obs = r(N)
	count if `uni' & numb_clauses == 0
	local n_obs_zero = r(N)
	count if `samp' & !missing(cba_period) & missing(numb_clauses)
	local n_obs_missing = r(N)

	cap drop _tagf
	egen _tagf = tag(identificad) if `uni'
	count if _tagf == 1
	local n_firms = r(N)
	cap drop _tagf

	cap drop _tagfz
	egen _tagfz = tag(identificad) if `uni' & numb_clauses == 0
	count if _tagfz == 1
	local n_firms_zero = r(N)
	cap drop _tagfz

	* firms that ever have a zero-clause period in the universe
	cap drop _anyzero
	cap drop _tagaz
	bys identificad: egen _anyzero = max(numb_clauses == 0) if `uni'
	egen _tagaz = tag(identificad) if `uni' & _anyzero == 1
	count if _tagaz == 1
	local n_firms_anyzero = r(N)
	cap drop _anyzero
	cap drop _tagaz

	di as result "Sample `s': N=`n_obs' firms=`n_firms' | zero-clause obs=`n_obs_zero' firms=`n_firms_zero' | missing-clause obs=`n_obs_missing'"

	tempname fh
	file open `fh' using "`acc'", write append
	file write `fh' "`s';`n_obs';`n_firms';`n_obs_zero';`n_firms_zero';`n_obs_missing';`n_firms_anyzero'" _n
	file close `fh'
}

di as result "Obs accounting done. All done."
log close
