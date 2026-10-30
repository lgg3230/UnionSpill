/*
================================================================================
3167_stacked_test_pure_control_cutoff.do — Stacked tests: each cutoff estimate
vs the All Untreated estimate (fine cutoff set)

For each cutoff sample s (c = 0, P5, P10, ..., P95; the fixed c = 0.01 is not
tested) and each outcome, tests beta_s = beta_ref, where beta_ref is the
direct effect with all untreated firms as the comparison group (sample "all"
of 3162; Panel B of tab:direct_connectivity_robust). The samples are nested and
share the treated firms, so the estimates are correlated; the test accounts for
the covariance with the stacked regression of
conn_margins/3022_direct_sample_coef_test.do (not changed): two copies of the
data (copy 0 = sample s, copy 1 = all untreated), each with its own complete
set of fixed effects (samp#FE), the DiD term interacted with the copy
indicator, and SEs clustered on the firm, so a firm in both copies is one
cluster. The triple interaction is beta_ref - beta_s; we report
    delta_s = beta_s - beta_ref = -(triple-interaction coefficient),
its SE, the p-value of delta_s = 0 (test), and delta_s +/- 1.96 SE.
Clause count uses the CBA-period structure (3022's _stacktest_cba).

Panel, sample and specification are those of 3162_pure_control_cutoff.do
(Sections 1-2 copied verbatim; cutoffs recomputed with _pctile, nq(20)).

CHECKS (the run stops, before the figure, if either fails):
  1. delta_s equals beta_s - beta_ref from 3162's pure_control_cutoff.csv, and
     the stacked beta_s equals 3162's beta_s (tolerance 1e-6).
  2. The c = 0 p-values equal the published Panel A = Panel B p-values of
     tab:direct_connectivity_robust: 0.012, 0.009, 0.741, 0.386 (log hourly
     wages, log wages, log employment, clause count), to 3 decimals.

Called by 3162 (fine set) after estimation; also runs on its own (globals unset
-> project root found from the working directory). With global
pcc_stacked_reuse = 1 it skips the 80 stacked regressions and redoes the
checks and the figure from an existing pure_control_cutoff_stacked.csv.

Input:  $rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta,
        $rais_aux/totalflows_wide_2007_2011.csv,
        $tables/pure_control_cutoff.csv   (check 1)
Output: $tables/pure_control_cutoff_stacked.csv
          sample,outcome,cutoff,b_s,b_ref,delta,se,p,ci_lo,ci_hi,n_obs
        $tables/verify_stacked.txt
        $graphs/pure_control_cutoff_diff_<outcome>.pdf (+ .png)
  -> decile table brackets: 4271_table_pure_control_cutoff_deciles_latex.py
  -> figure wrapper:        4283_figure_diff_pure_control_cutoff.py
================================================================================
*/

version 17.0
set more off
set varabbrev off

if `"$tables"' == "" | `"$graphs"' == "" | `"$rais_firm"' == "" {
	if `"$root"' == "" {
		local _d = subinstr(`"`c(pwd)'"', "\", "/", .)
		while `"`_d'"' != "" & !fileexists(`"`_d'/Programs/0000_master.do"') {
			local _d = substr(`"`_d'"', 1, max(strrpos(`"`_d'"', "/") - 1, 0))
		}
		global root `"`_d'"'
	}
	if !fileexists(`"$root/Programs/0000_master.do"') {
		di as error "Project root not found: run from inside the project or set the globals."
		exit 601
	}
	global rais_aux  "$root/Data/RAIS_aux"
	global rais_firm "$root/Data/CBA_RAIS_firm_level"
	global tables    "$root/Tables/pure_control_cutoff_fine"
	global graphs    "$root/Graphs/pure_control_cutoff_fine"
}
cap mkdir "$graphs"

local outcomes "lr_remdezr_h_w lr_remdezr_w l_firm_emp numb_clauses"

* 3162's estimates (check 1): local b_<sample>_<outcome>.
import delimited using "$tables/pure_control_cutoff.csv", clear varnames(1) stringcols(_all)
keep if row_type == "main"
forvalues i = 1/`=_N' {
	local b_`=section[`i']'_`=outcome[`i']' = real(value[`i'])
}

********************************************************************************
* SECTION 1: DATA (from 3012, turnover merge omitted)
********************************************************************************

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

preserve
	import delimited "$rais_aux/totalflows_wide_2007_2011.csv", clear
	tostring identificad, replace format(%014.0f) force
	tempfile totalflows_wide
	save `totalflows_wide'
restore
merge m:1 identificad using `totalflows_wide', keep(master match) nogen

* Average per-worker pairwise flows 2007-2011 (missing-safe: average over
* non-missing year pairs only; NaN means zero flows, not truly missing).
gen double totalflows_pw_pre_07_11 = 0
gen totalflows_pw_pre_07_11_cnt = 0
foreach yp in totalflows_pw_07_08 totalflows_pw_08_09 totalflows_pw_09_10 totalflows_pw_10_11 {
	replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 + `yp' if !missing(`yp')
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
* SECTION 2: VARIABLE CREATION (from 3012)
********************************************************************************

* ── a) Treatment & CBA period indicators ──────────────────────────────────────

cap drop placebo_year
gen byte placebo_year = (year < 2011)

cap drop treat_year
gen byte treat_year = (year >= 2012)

cap drop cba_period
cap drop pre_treat_cba
cap drop post_treat_cba

gen cba_period = .
replace cba_period = 1 if avg_file_date == earliest2009_avg - 1 & !missing(avg_file_date)
replace cba_period = 2 if avg_file_date == second_cba_avg & !missing(avg_file_date)
replace cba_period = 3 if inrange(avg_file_date, mdy(1,1,2013), mdy(12,31,2013)) & cba_period == .
replace cba_period = 4 if inrange(avg_file_date, mdy(1,1,2014), mdy(12,31,2014)) & cba_period == .
replace cba_period = 5 if inrange(avg_file_date, mdy(1,1,2015), mdy(12,31,2015)) & cba_period == .
replace cba_period = 6 if inrange(avg_file_date, mdy(1,1,2016), mdy(12,31,2016)) & cba_period == .

gen pre_treat_cba = cond(cba_period < 2, 1, 0)
gen post_treat_cba = cond(cba_period >= 3, 1, 0) if !missing(cba_period)

* industry1 is numeric in the overlay panel but a string in the rebuilt one;
* i.industry1 needs numeric. No-op on the overlay.
capture confirm string variable industry1
if _rc == 0 {
	destring industry1, replace force
}

* ── b) Pre-treatment means ────────────────────────────────────────────────────

cap drop firm_emp_pre_o
cap drop firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre = min(firm_emp_pre_o)
	drop firm_emp_pre_o
}

foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {
	cap drop `outcome'_pre_o
	cap drop `outcome'_pre
	quietly {
		bys identificad: egen `outcome'_pre_o = mean(`outcome') if inrange(year, 2009, 2011)
		bys identificad: egen `outcome'_pre = min(`outcome'_pre_o)
		drop `outcome'_pre_o
	}
}

cap drop numb_clauses_pre_o
cap drop numb_clauses_pre
quietly {
	bys identificad: egen numb_clauses_pre_o = mean(numb_clauses) if inrange(cba_period, 1, 2)
	bys identificad: egen numb_clauses_pre = min(numb_clauses_pre_o)
	drop numb_clauses_pre_o
}

* Log pre-treatment employment (overwrite mean(l_firm_emp) with ln(mean(firm_emp)))
cap drop l_firm_emp_pre
gen double l_firm_emp_pre = ln(firm_emp_pre)

* ── c) 4-bin controls (full balanced panel, fixed across samples) ─────────────

cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
quietly {
	egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
	drop l_firm_emp_pre4_o
}

foreach v in lr_remdezr_w lr_remdezr_h_w numb_clauses {
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


********************************************************************************
* SECTION 3: SAMPLES
********************************************************************************

cap drop firm_id
egen firm_id = group(identificad)
keep if lagos_sample_avg == 1 & in_balanced_panel == 1
keep firm_id year treat_ultra treat_year cba_period post_treat_cba totaltreat_pw_n ///
	industry1 mode_base_month microregion totalflows_pw_pre_07_114 l_firm_emp_pre4 ///
	lr_remdezr_w lr_remdezr_h_w l_firm_emp numb_clauses ///
	lr_remdezr_w_pre4 lr_remdezr_h_w_pre4 numb_clauses_pre4

* Cutoffs as in 3162: vingtiles of positive connectivity among untreated firms.
quietly _pctile totaltreat_pw_n if treat_ultra == 0 & year == 2009 & totaltreat_pw_n > 0 & !missing(totaltreat_pw_n), nq(20)
local quantiles ""
forvalues k = 1/19 {
	local q = "p" + string(5*`k', "%02.0f")
	scalar c_`q' = r(r`k')
	local quantiles "`quantiles' `q'"
}
scalar c_zero = 0
local cond_zero "totaltreat_pw_n == 0"
foreach q of local quantiles {
	local cond_`q' "totaltreat_pw_n <= scalar(c_`q')"
}

tempfile base allpart
save `base'
gen byte samp = 1
save `allpart'

********************************************************************************
* SECTION 4: STACKED TESTS
********************************************************************************

local cal_fe "i.samp#i.firm_id i.samp#i.industry1#i.year i.samp#i.mode_base_month#i.year i.samp#i.microregion#i.year i.samp#i.l_firm_emp_pre4#i.year i.samp#i.totalflows_pw_pre_07_114#i.year"
local cba_fe "i.samp#i.firm_id i.samp#i.industry1#i.cba_period i.samp#i.mode_base_month#i.cba_period i.samp#i.microregion#i.cba_period i.samp#i.numb_clauses_pre4#i.cba_period i.samp#i.l_firm_emp_pre4#i.cba_period i.samp#i.totalflows_pw_pre_07_114#i.cba_period"

* Published c = 0 vs All p-values (tab:direct_connectivity_robust), check 2.
local pub_lr_remdezr_h_w 0.012
local pub_lr_remdezr_w   0.009
local pub_l_firm_emp     0.741
local pub_numb_clauses   0.386

local csv "$tables/pure_control_cutoff_stacked.csv"
if "$pcc_stacked_reuse" != "1" {
tempname fh
file open `fh' using "`csv'", write replace
file write `fh' "sample,outcome,cutoff,b_s,b_ref,delta,se,p,ci_lo,ci_hi,n_obs" _n
file close `fh'

foreach s in zero `quantiles' {
	use `base', clear
	keep if treat_ultra == 1 | (treat_ultra == 0 & `cond_`s'')
	gen byte samp = 0
	append using `allpart'

	foreach o of local outcomes {
		di as text "  Stacked test: `o', `s' vs all"
		if "`o'" == "numb_clauses" {
			reghdfe `o' i.treat_ultra##i.post_treat_cba##i.samp if !missing(cba_period), ///
				absorb(`cba_fe') vce(cluster firm_id)
			local dd "1.treat_ultra#1.post_treat_cba"
		}
		else {
			reghdfe `o' i.treat_ultra##i.treat_year##i.samp, ///
				absorb(`cal_fe' i.samp#i.`o'_pre4#i.year) vce(cluster firm_id)
			local dd "1.treat_ultra#1.treat_year"
		}
		local b_s   = _b[`dd']
		local delta = -_b[`dd'#1.samp]
		local se    = _se[`dd'#1.samp]
		local n_obs = e(N)
		quietly test `dd'#1.samp = 0
		local p = r(p)

		local b_ref = `b_all_`o''
		local c = cond("`s'" == "zero", 0, scalar(c_`s'))
		file open `fh' using "`csv'", write append
		file write `fh' "`s',`o'," %20.15g (`c') "," %20.15g (`b_s') "," %20.15g (`b_ref') "," ///
			%20.15g (`delta') "," %20.15g (`se') "," %20.15g (`p') "," ///
			%20.15g (`delta' - 1.96*`se') "," %20.15g (`delta' + 1.96*`se') ",`n_obs'" _n
		file close `fh'
	}
}
}

********************************************************************************
* SECTION 4b: CHECKS (from the results CSV)
********************************************************************************

import delimited using "`csv'", clear varnames(1) stringcols(1 2)
local fails ""
if _N != 80 local fails "`fails' rows:`=_N'"
forvalues i = 1/`=_N' {
	local s = sample[`i']
	local o = outcome[`i']
	* Check 1: same estimates as 3162, and delta_s = beta_s - beta_ref.
	if abs(b_s[`i'] - `b_`s'_`o'') > 1e-6 | ///
		abs(delta[`i'] - (`b_`s'_`o'' - `b_all_`o'')) > 1e-6 {
		local fails "`fails' check1:`s':`o'"
	}
	* Check 2: c = 0 p-values as published.
	if "`s'" == "zero" & abs(p[`i'] - `pub_`o'') > 0.0005 {
		local fails "`fails' check2:`o'"
	}
}
local result = cond("`fails'" == "", "RESULT: PASS", "RESULT: FAIL:`fails'")

tempname fv
file open `fv' using "$tables/verify_stacked.txt", write replace
file write `fv' "Stacked tests vs All Untreated: checks" _n
file write `fv' "  1. delta_s = beta_s - beta_ref and stacked beta_s = 3162 beta_s (tol 1e-6), 80 regressions" _n
file write `fv' "  2. c = 0 p-values = published 0.012 / 0.009 / 0.741 / 0.386" _n
file write `fv' "`result'" _n
file close `fv'
type "$tables/verify_stacked.txt"
if "`fails'" != "" {
	di as error "Stacked-test checks failed:`fails'. Figure not drawn."
	exit 9
}

********************************************************************************
* SECTION 5: FIGURE (difference from All Untreated, by cutoff)
********************************************************************************

import delimited using "`csv'", clear varnames(1) stringcols(1 2)
* The reference point: All at zero, no confidence interval.
local n1 = _N + 1
set obs `n1'
replace sample = "all" in `n1'
replace delta = 0 in `n1'
gen double sortc = cond(sample == "all", ., cutoff)
gen lab = cond(sample == "zero", "0", cond(sample == "all", "All", ///
	"P" + string(real(substr(sample, 2, .)))))

local blue "33 102 172"
foreach o of local outcomes {
	preserve
	keep if outcome == "`o'" | sample == "all"
	sort sortc
	gen x = _n
	local n = _N
	local xl ""
	forvalues i = 1/`n' {
		local xl `"`xl' `i' "`=lab[`i']'""'
	}
	quietly sum ci_lo, meanonly
	local ymin = min(r(min), 0)
	quietly sum ci_hi, meanonly
	local ymax = max(r(max), 0)
	_natscale `ymin' `ymax' 5
	local ylab "`r(min)'(`r(delta)')`r(max)'"

	twoway ///
		(rcap ci_hi ci_lo x if sample != "all", lcolor("`blue'") lwidth(medthin)) ///
		(scatter delta x if sample != "all", msymbol(O) mcolor("`blue'") msize(small)) ///
		(scatter delta x if sample == "all", msymbol(Oh) mcolor("`blue'") msize(medium) mlwidth(medthick)), ///
		yline(0, lcolor(gs8) lwidth(thin)) ///
		xlabel(`xl', angle(90) labsize(small) nogrid) xscale(range(0.4 `=`n' + 0.6')) ///
		ylabel(`ylab', angle(horizontal) grid glcolor(gs15)) ///
		xtitle("Connectivity cutoff {it:c}") ytitle("Difference from All Untreated") ///
		legend(off) graphregion(color(white)) bgcolor(white) ///
		xsize(4) ysize(3)

	graph export "$graphs/pure_control_cutoff_diff_`o'.pdf", as(pdf) replace
	graph export "$graphs/pure_control_cutoff_diff_`o'.png", as(png) width(1600) replace
	restore
}
