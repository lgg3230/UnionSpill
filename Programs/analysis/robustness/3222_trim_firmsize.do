/*
================================================================================
3222_trim_firmsize.do — Main direct and spillover effects on samples trimmed by
pre-treatment establishment size

Run through the wrapper 3221_trim_firmsize.do, which sets the globals
($rais_firm, $rais_aux, $tables, $graphs, $logs, $programs).

TRIMMING
  Size = firm_emp_pre, mean employment over 2009-2011 (as in 3012).
  Cutoffs are computed ONCE, on the pooled establishment-level sample
  (lagos_sample_avg == 1 & in_balanced_panel == 1, year == 2009, treated and
  untreated together), with _pctile (same definition as summarize, detail).
  For p in {1, 2.5, 5, 10, 20}, every establishment-year of an establishment with
  firm_emp_pre below the p-th or above the (100-p)-th percentile is dropped;
  establishments at a cutoff are kept, so ties can make the share dropped
  smaller than 2p percent (the counts are written to the cutoffs CSV). The
  same cutoffs apply to the direct and the spillover samples. p = 0 is the
  untrimmed benchmark.
  Everything else keeps its full-sample definition: the quartile bins
  (Y_pre4, l_firm_emp_pre4, totalflows_pw_pre_07_114) and the p90 used to
  scale connectivity are NOT rebuilt on the trimmed sample, so only the
  estimation sample changes and coefficients stay in the same units.

SPECIFICATIONS (per trim level and outcome), exactly as in 3012_pct_tfpw.do
    direct_A  Y = a_i + FE + b * Post_t * T_i       treated + zero-connectivity untreated (paper headline)
    spill     Y = a_i + FE + g * Post_t * conn_i    untreated only
  conn = totaltreat_pw_norm (totaltreat_pw_n scaled so that 1 = p90 among
         untreated establishments in 2009)
  Calendar outcomes (lr_remdezr_w, lr_remdezr_h_w, l_firm_emp):
    post: <term>##i.treat_year; placebo: <term>##i.placebo_year if year <= 2011;
    event study: <term>##ib2011.year, pre-trend F-test on 2009 and 2010.
    absorb(identificad i.industry1#i.year i.mode_base_month#i.year
           i.microregion#i.year ib0.Y_pre4#i.year ib0.l_firm_emp_pre4#i.year
           ib0.totalflows_pw_pre_07_114#i.year), vce(cluster identificad)
  numb_clauses: cba_period in place of year in every FE interaction,
    post_treat_cba / pre_treat_cba (placebo if cba_period <= 2), event study
    with ib2.cba_period (base = the 2010-2012 period), sample & !missing(cba_period).

  Data prep (Sections 1-2) is copied from 3212_joint_spec.do (itself a copy of
  3012 without the turnover merge, union controls and percentile outcomes),
  without its conn_joint.

Output:
  $tables/trim_cutoffs.csv               trim,p,lo,hi and establishment counts
  $graphs/size_hist_untreated_conn.pdf   size histograms: zero-connectivity untreated vs positive-
  $graphs/size_hist_treated_zeroconn.pdf connectivity untreated, and vs directly treated
  $graphs/size_hist_*_levels.pdf         same two comparisons in levels, top-coded at 300
  $tables/trim_size_by_group.csv         mean / SD / median pre-treatment size of treated,
                                         spillover and zero-connectivity establishments
  $tables/results_trim_firmsize.csv      project CSV schema; spec = trim_<tag>,
                                         sections direct_A, spill
  $tables/trim_firmsize_es_coefs.csv     event-study coefficients
  $graphs/trim_es_<section>_<outcome>.pdf  event study per section and outcome,
                                         untrimmed, 5% and 10% overlaid (Section 5)
  Then 4320_trim_firmsize_report.py builds the tables and
  $tables/trim_firmsize_report.tex (+ .pdf if tectonic or pdflatex is found),
  and checks the untrimmed results against Tables/pct_tfpw_cc/ (3012).
================================================================================
*/

version 17.0
set more off
set varabbrev off

* Paths come from the wrapper 3221_trim_firmsize.do.

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
cap mkdir "$logs"
cap mkdir "$tables"
cap mkdir "$graphs"
log using "$logs/trim_firmsize_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"

********************************************************************************
* HELPERS
********************************************************************************

* One row of the results CSV (3012 schema; spec = trim tag).
cap program drop _wrow
program define _wrow
	args spec section outcome rowtype value fmt stars
	tempname fh
	file open `fh' using "$RES_CSV", write append
	file write `fh' `""`spec'";"`section'";"`outcome'";"`rowtype'";"' `fmt' (`value') `"`stars'""' _n
	file close `fh'
end

* Event-study coefficients of the current estimates, one row per period. The
* base period is written with b = se = 0 and base = 1.
*   term(dir):  1.treat_ultra#<l>.<tvar>
*   term(conn): <l>.<tvar>#c.<var>
cap program drop _es_export
program define _es_export
	syntax , trim(string) section(string) outcome(string) tvar(name) term(string) [var(name)]
	if "`tvar'" == "cba_period" {
		local levels "1 2 3 4 5 6"
		local baselev 2
	}
	else {
		local levels "2009 2010 2011 2012 2013 2014 2015 2016"
		local baselev 2011
	}
	tempname fh
	file open `fh' using "$ES_CSV", write append
	foreach l of local levels {
		if "`term'" == "dir" local cn "1.treat_ultra#`l'.`tvar'"
		else                 local cn "`l'.`tvar'#c.`var'"
		local bb = 0
		local ss = 0
		capture local bb = _b[`cn']
		capture local ss = _se[`cn']
		local isbase = (`l' == `baselev')
		file write `fh' "`trim',`section',`outcome',`tvar',`l',`isbase'," %14.10f (`bb') "," %14.10f (`ss') _n
	}
	file close `fh'
end

* Stars from a p-value.
cap program drop _stars
program define _stars, rclass
	args p
	return local s = cond(`p' < 0.01, "***", cond(`p' < 0.05, "**", cond(`p' < 0.10, "*", "")))
end

********************************************************************************
* SECTION 1: DATA (from 3202, turnover merge omitted)
********************************************************************************

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

preserve
	import delimited "$rais_aux/totalflows_wide_2007_2011.csv", clear
	tostring identificad, replace format(%014.0f) force
	tempfile totalflows_wide
	save `totalflows_wide'
restore
merge m:1 identificad using `totalflows_wide', keep(master match) nogen

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

********************************************************************************
* SECTION 2: VARIABLE CREATION (from 3142, plus placebo_year / pre_treat_cba)
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

* industry1 is stored as a string in the rebuilt panel; i.industry1 needs numeric
capture confirm string variable industry1
if _rc == 0 {
	destring industry1, replace force
}

* ── Connectivity scaling ──────────────────────────────────────────────────────

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen totaltreat_pw_n_p90 = r(p90)
gen totaltreat_pw_norm = (totaltreat_pw_n / totaltreat_pw_n_p90)


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

capture confirm variable numb_clauses
if _rc == 0 {
	cap drop numb_clauses_pre_o
	cap drop numb_clauses_pre
	quietly {
		bys identificad: egen numb_clauses_pre_o = mean(numb_clauses) if inrange(cba_period, 1, 2)
		bys identificad: egen numb_clauses_pre = min(numb_clauses_pre_o)
		drop numb_clauses_pre_o
	}
}

* Log pre-treatment employment (overwrite mean(l_firm_emp) with ln(mean(firm_emp)))
cap drop l_firm_emp_pre
gen double l_firm_emp_pre = ln(firm_emp_pre)

* ── 4-bin controls ────────────────────────────────────────────────────────────

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
* SECTION 3: TRIMMING BY PRE-TREATMENT ESTABLISHMENT SIZE
********************************************************************************

* Trim levels (percent cut at EACH tail) and their tags; 0 = untrimmed.
local trims "0 1 2.5 5 10 20"
local tags  "0 1 2p5 5 10 20"

local s_firm "lagos_sample_avg == 1 & in_balanced_panel == 1 & year == 2009"

di _newline as result "Pre-treatment establishment size (firm_emp_pre), pooled 2009 balanced-panel establishments:"
sum firm_emp_pre if `s_firm', detail

* Percentiles in pairs: (1, 99), (2.5, 97.5), (5, 95), (10, 90), (20, 80) are
* r(r1)/r(r10), r(r2)/r(r9), r(r3)/r(r8), r(r4)/r(r7), r(r5)/r(r6). Stored as
* scalars so the comparison with the float firm_emp_pre is exact.
_pctile firm_emp_pre if `s_firm', percentiles(1 2.5 5 10 20 80 90 95 97.5 99)
scalar lo_1   = r(r1)
scalar hi_1   = r(r10)
scalar lo_2p5 = r(r2)
scalar hi_2p5 = r(r9)
scalar lo_5   = r(r3)
scalar hi_5   = r(r8)
scalar lo_10  = r(r4)
scalar hi_10  = r(r7)
scalar lo_20  = r(r5)
scalar hi_20  = r(r6)

global CUT_CSV "$tables/trim_cutoffs.csv"
tempname fh
file open `fh' using "$CUT_CSV", write replace
file write `fh' "trim,p,lo,hi,n_estab,n_kept,n_drop_low,n_drop_high,n_drop_treated,n_drop_untreated,n_drop_zeroconn" _n
file close `fh'

forvalues k = 1/6 {
	local p   : word `k' of `trims'
	local tag : word `k' of `tags'
	cap drop keep_`tag'
	if "`tag'" == "0" {
		gen byte keep_`tag' = 1
		local lo = .
		local hi = .
		local low  "0"
		local high "0"
	}
	else {
		gen byte keep_`tag' = (firm_emp_pre >= scalar(lo_`tag') & firm_emp_pre <= scalar(hi_`tag'))
		local lo = scalar(lo_`tag')
		local hi = scalar(hi_`tag')
		local low  "firm_emp_pre < scalar(lo_`tag')"
		local high "firm_emp_pre > scalar(hi_`tag')"
	}
	label var keep_`tag' "Kept after trimming `p'% of pre-treatment size at each tail"

	quietly count if `s_firm'
	local n_estab = r(N)
	quietly count if `s_firm' & keep_`tag' == 1
	local n_kept = r(N)
	quietly count if `s_firm' & `low'
	local n_low = r(N)
	quietly count if `s_firm' & `high'
	local n_high = r(N)
	quietly count if `s_firm' & keep_`tag' == 0 & treat_ultra == 1
	local n_dt = r(N)
	quietly count if `s_firm' & keep_`tag' == 0 & treat_ultra == 0
	local n_du = r(N)
	quietly count if `s_firm' & keep_`tag' == 0 & treat_ultra == 0 & totaltreat_pw_n == 0
	local n_dz = r(N)

	file open `fh' using "$CUT_CSV", write append
	file write `fh' "trim_`tag',`p'," %12.4f (`lo') "," %12.4f (`hi') ",`n_estab',`n_kept',`n_low',`n_high',`n_dt',`n_du',`n_dz'" _n
	file close `fh'
	di as text "  trim `p'%: keep [" %9.4f `lo' ", " %9.4f `hi' "]  kept `n_kept' of `n_estab'" ///
		"  (dropped low `n_low', high `n_high'; treated `n_dt', untreated `n_du', zero-conn `n_dz')"
}

type "$CUT_CSV"

* ── Pre-treatment size by group, per trim level ─────────────────────────────
* Establishment level (2009 row of the balanced base sample), before the
* regression-specific drops (singletons, missing outcomes). Groups:
*   treated   treat_ultra == 1
*   spill     treat_ultra == 0                          (spillover sample)
*   zeroconn  treat_ultra == 0 & totaltreat_pw_n == 0   (Panel A controls)

global SIZE_CSV "$tables/trim_size_by_group.csv"
file open `fh' using "$SIZE_CSV", write replace
file write `fh' "trim,group,n_estab,mean,sd,p50" _n
file close `fh'

forvalues k = 1/6 {
	local tag : word `k' of `tags'
	foreach g in treated spill zeroconn {
		if "`g'" == "treated"  local gc "treat_ultra == 1"
		if "`g'" == "spill"    local gc "treat_ultra == 0"
		if "`g'" == "zeroconn" local gc "treat_ultra == 0 & totaltreat_pw_n == 0"
		quietly sum firm_emp_pre if `s_firm' & keep_`tag' == 1 & `gc', detail
		file open `fh' using "$SIZE_CSV", write append
		file write `fh' "trim_`tag',`g',`r(N)'," %12.4f (r(mean)) "," %12.4f (r(sd)) "," %12.4f (r(p50)) _n
		file close `fh'
	}
}

type "$SIZE_CSV"

* ── Size distributions: zero-connectivity controls vs other groups ──────────
* Histograms of firm_emp_pre (log scale, labeled in employees), one row per
* establishment (2009 row of the balanced base sample), untrimmed. Densities,
* so groups of different size are comparable. Zero-connectivity untreated
* establishments (the direct-effect controls, blue) against
*   untreated with positive connectivity  -> size_hist_untreated_conn.pdf
*   directly treated                      -> size_hist_treated_zeroconn.pdf

cap drop ln_size
gen double ln_size = ln(firm_emp_pre) if `s_firm'
quietly count if `s_firm' & treat_ultra == 0 & missing(totaltreat_pw_n)
di as text "Untreated establishments with missing connectivity (excluded from the histograms): `r(N)'"

local cond_zero  "`s_firm' & treat_ultra == 0 & totaltreat_pw_n == 0"
local cond_pos   "`s_firm' & treat_ultra == 0 & totaltreat_pw_n > 0 & !missing(totaltreat_pw_n)"
local cond_treat "`s_firm' & treat_ultra == 1"
local name_zero  "Zero connectivity"
local name_pos   "Positive connectivity"
local name_treat "Directly treated"
foreach g in zero pos treat {
	quietly sum firm_emp_pre if `cond_`g'', detail
	local n_`g'   = string(r(N), "%9.0fc")
	local med_`g' = string(r(p50), "%9.1f")
	local mn_`g'  = string(r(mean), "%9.1f")
	di as text "  `name_`g'': N = `n_`g''  median = `med_`g''  mean = `mn_`g''"
}

local xl ""
foreach v in 1 2 5 10 20 50 100 200 500 1000 2000 5000 10000 {
	local xl `"`xl' `=ln(`v')' "`v'""'
}
foreach pair in "pos untreated_conn" "treat treated_zeroconn" {
	local g    : word 1 of `pair'
	local file : word 2 of `pair'
	twoway (histogram ln_size if `cond_zero', width(0.25) start(0) density ///
	           fcolor("42 120 214%45") lcolor("42 120 214") lwidth(vthin)) ///
	       (histogram ln_size if `cond_`g'', width(0.25) start(0) density ///
	           fcolor("235 104 52%45") lcolor("235 104 52") lwidth(vthin)), ///
		xlabel(`xl', labsize(small)) ylabel(, labsize(small) angle(horizontal) glcolor(gs15) glwidth(vthin)) ///
		xtitle("Pre-treatment employment (mean 2009-2011, log scale)", size(small)) ///
		ytitle("Density", size(small)) ///
		legend(order(1 "`name_zero' untreated (N = `n_zero', median `med_zero', mean `mn_zero')" ///
		             2 "`name_`g'' (N = `n_`g'', median `med_`g'', mean `mn_`g'')") ///
		       rows(2) position(6) size(small) region(lcolor(white))) ///
		graphregion(color(white) lcolor(white) ilcolor(white)) plotregion(color(white)) ///
		xsize(6) ysize(4)
	graph export "$graphs/size_hist_`file'.pdf", as(pdf) replace
}

* Same comparisons in levels: 5-employee bins, sizes above `topc' pooled into
* one "`topc'+" bar (placed at the midpoint of the bin starting at `topc');
* legends also give each group's share above `topc'.
local topc 300
cap drop size_tc
gen double size_tc = cond(firm_emp_pre >= `topc', `topc' + 2.5, firm_emp_pre) if `s_firm'
foreach g in zero pos treat {
	quietly count if `cond_`g''
	local nn = r(N)
	quietly count if `cond_`g'' & firm_emp_pre >= `topc'
	local top_`g' = string(100 * r(N) / `nn', "%4.1f")
}
foreach pair in "pos untreated_conn" "treat treated_zeroconn" {
	local g    : word 1 of `pair'
	local file : word 2 of `pair'
	twoway (histogram size_tc if `cond_zero', width(5) start(0) density ///
	           fcolor("42 120 214%45") lcolor("42 120 214") lwidth(vthin)) ///
	       (histogram size_tc if `cond_`g'', width(5) start(0) density ///
	           fcolor("235 104 52%45") lcolor("235 104 52") lwidth(vthin)), ///
		xlabel(0(50)250 `=`topc' + 2.5' "`topc'+", labsize(small)) ///
		ylabel(, labsize(small) angle(horizontal) glcolor(gs15) glwidth(vthin)) ///
		xtitle("Pre-treatment employment (mean 2009-2011)", size(small)) ///
		ytitle("Density", size(small)) ///
		legend(order(1 "`name_zero' untreated (N = `n_zero', median `med_zero', `top_zero'% at `topc'+)" ///
		             2 "`name_`g'' (N = `n_`g'', median `med_`g'', `top_`g''% at `topc'+)") ///
		       rows(2) position(6) size(small) region(lcolor(white))) ///
		graphregion(color(white) lcolor(white) ilcolor(white)) plotregion(color(white)) ///
		xsize(6) ysize(4)
	graph export "$graphs/size_hist_`file'_levels.pdf", as(pdf) replace
}
drop ln_size size_tc

********************************************************************************
* SECTION 4: ESTIMATION
********************************************************************************

local conn     "totaltreat_pw_norm"
local outcomes "lr_remdezr_w lr_remdezr_h_w l_firm_emp numb_clauses"

local s_direct_A "(treat_ultra==0 & totaltreat_pw_n==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_spill    "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

global RES_CSV "$tables/results_trim_firmsize.csv"
global ES_CSV  "$tables/trim_firmsize_es_coefs.csv"
file open `fh' using "$RES_CSV", write replace
file write `fh' "spec,section,outcome,row_type,value" _n
file close `fh'
file open `fh' using "$ES_CSV", write replace
file write `fh' "trim,section,outcome,tvar,period,base,b,se" _n
file close `fh'

forvalues k = 1/6 {
	local p    : word `k' of `trims'
	local tag  : word `k' of `tags'
	local spec "trim_`tag'"
	local ks   " & keep_`tag' == 1"

	foreach outcome of local outcomes {

		* ── Outcome-specific time structure ───────────────────────────────────
		if "`outcome'" == "numb_clauses" {
			local tvar   "cba_period"
			local post   "post_treat_cba"
			local plac   "pre_treat_cba"
			local xs     " & !missing(cba_period)"
			local xs_p   " & !missing(cba_period) & cba_period <= 2"
			local base   "ib2"
			local prelev "1"
		}
		else {
			local tvar   "year"
			local post   "treat_year"
			local plac   "placebo_year"
			local xs     ""
			local xs_p   " & year <= 2011"
			local base   "ib2011"
			local prelev "2009 2010"
		}
		local absorb "identificad i.industry1#i.`tvar' i.mode_base_month#i.`tvar' i.microregion#i.`tvar' ib0.`outcome'_pre4#i.`tvar' ib0.l_firm_emp_pre4#i.`tvar' ib0.totalflows_pw_pre_07_114#i.`tvar'"

		foreach sec in direct_A spill {
			if "`sec'" == "spill" {
				local samp      "`s_spill'"
				local term_post "c.`conn'##i.`post'"
				local coef_post "1.`post'#c.`conn'"
				local term_plac "c.`conn'##i.`plac'"
				local coef_plac "1.`plac'#c.`conn'"
				local term_es   "c.`conn'##`base'.`tvar'"
				local test_es   "c.`conn'#i(`prelev').`tvar'"
				local esterm    "conn"
			}
			else {
				local samp      "`s_direct_A'"
				local term_post "i.treat_ultra##i.`post'"
				local coef_post "1.treat_ultra#1.`post'"
				local term_plac "i.treat_ultra##i.`plac'"
				local coef_plac "1.treat_ultra#1.`plac'"
				local term_es   "i.treat_ultra##`base'.`tvar'"
				local test_es   "1.treat_ultra#i(`prelev').`tvar'"
				local esterm    "dir"
			}

			di _newline "============================================================"
			di "TRIM `p'%  `sec': `outcome'"
			di "============================================================"

			reghdfe `outcome' `term_post' if `samp'`xs'`ks', ///
				absorb(`absorb') vce(cluster identificad)
			local b_post  = _b[`coef_post']
			local se_post = _se[`coef_post']
			local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
			local n_obs   = e(N)
			local n_estab = e(N_clust)
			quietly sum `outcome' if e(sample) & inrange(year, 2009, 2011)
			local mean_pre = r(mean)

			reghdfe `outcome' `term_plac' if `samp'`xs_p'`ks', ///
				absorb(`absorb') vce(cluster identificad)
			local b_pre  = _b[`coef_plac']
			local se_pre = _se[`coef_plac']
			local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

			reghdfe `outcome' `term_es' if `samp'`xs'`ks', ///
				absorb(`absorb') vce(cluster identificad)
			testparm `test_es'
			local pre_pval = r(p)
			_es_export, trim(`spec') section(`sec') outcome(`outcome') tvar(`tvar') term(`esterm') var(`conn')

			_stars `p_post'
			local st_post "`r(s)'"
			_stars `p_pre'
			local st_pre "`r(s)'"
			_wrow `spec' `sec' `outcome' main     `b_post'   %9.4f   `st_post'
			_wrow `spec' `sec' `outcome' main_se  `se_post'  %9.4f
			_wrow `spec' `sec' `outcome' pre      `b_pre'    %9.4f   `st_pre'
			_wrow `spec' `sec' `outcome' pre_se   `se_pre'   %9.4f
			_wrow `spec' `sec' `outcome' pre_pval `pre_pval' %9.4f
			_wrow `spec' `sec' `outcome' n_obs    `n_obs'    %12.0fc
			_wrow `spec' `sec' `outcome' n_estab  `n_estab'  %12.0fc
			_wrow `spec' `sec' `outcome' mean_pre `mean_pre' %9.4f

			di "  b = " %9.4f `b_post' " (" %6.4f `se_post' ")  placebo = " %9.4f `b_pre' ///
				" (" %6.4f `se_pre' ")  pre-trend p = " %6.4f `pre_pval' "  N = `n_obs'  estab = `n_estab'"
		}
	}
}

di _newline "======================================================="
di "RESULTS: $RES_CSV"
di "======================================================="
type "$RES_CSV"

********************************************************************************
* SECTION 5: EVENT-STUDY FIGURES
********************************************************************************
* One standalone PDF per section (direct_A, spill) and outcome, each with its
* own legend; the report arranges them as 2 x 2 subfigures in LaTeX. Only three
* samples are plotted: untrimmed, 5% and 10% trims (k = 1, 4, 5); the tables
* report all six. Horizontal offsets and 95% CIs as before.
* Colors: untrimmed in neutral gray, trim levels from a one-hue blue ramp,
* lighter -> darker with more trimming (each trim keeps the color it has in the
* full six-sample ramp); marker shapes double-encode the level.
* Reform line placed as in 3012's event-study figures.

local plotk "1 4 5"

preserve
import delimited "$ES_CSV", clear varnames(1)

gen byte k = .
forvalues j = 1/6 {
	local tag : word `j' of `tags'
	replace k = `j' if trim == "trim_`tag'"
}
* position of each plotted sample in the offset sequence (1 = leftmost)
gen byte pos = .
local m = 0
foreach j of local plotk {
	local ++m
	replace pos = `m' if k == `j'
}
local npos = `m'
gen double x  = cond(tvar == "year", period - 2008, period)
gen double xo = x + (pos - (`npos' + 1) / 2) * 0.15
gen double lo = b - 1.96 * se
gen double hi = b + 1.96 * se

local col1 "82 81 78"
local col2 "134 182 239"
local col3 "85 152 231"
local col4 "42 120 214"
local col5 "28 92 171"
local col6 "13 54 107"
local sym1 "O"
local sym2 "S"
local sym3 "T"
local sym4 "D"
local sym5 "X"
local sym6 "+"
* X and + draw smaller than the filled symbols at the same size
forvalues j = 1/6 {
	local msz`j' = cond(`j' >= 5, "medium", "small")
}
local lab1 "Untrimmed"
forvalues j = 2/6 {
	local p : word `j' of `trims'
	local lab`j' "Trim `p'% each tail"
}

local tit_lr_remdezr_w   "Log wages"
local tit_lr_remdezr_h_w "Log hourly wages"
local tit_l_firm_emp     "Log employment"
local tit_numb_clauses   "Number of clauses"

local xlab_year `"1 "2009" 2 "2010" 3 "2011" 4 "2012" 5 "2013" 6 "2014" 7 "2015" 8 "2016""'
local xlab_cba  `"1 "2009" 2 "2010-12" 3 "2013" 4 "2014" 5 "2015" 6 "2016""'

foreach sec in direct_A spill {
	foreach o of local outcomes {
		local cond `"section == "`sec'" & outcome == "`o'""'
		if "`o'" == "numb_clauses" {
			local xlab `"`xlab_cba'"'
			local xl   2.5
			local xr   "0.5 6.5"
		}
		else {
			local xlab `"`xlab_year'"'
			local xl   3.75
			local xr   "0.5 8.5"
		}
		* rcap + scatter per sample; the legend lists the scatters (2, 4, 6)
		local plots ""
		local order ""
		local n = 0
		foreach j of local plotk {
			local plots `"`plots' (rcap hi lo xo if `cond' & k == `j', lcolor("`col`j''") lwidth(thin) msize(vsmall))"'
			local plots `"`plots' (scatter b xo if `cond' & k == `j', mcolor("`col`j''") msymbol(`sym`j'') msize(`msz`j''))"'
			local n = `n' + 2
			local order `"`order' `n' "`lab`j''""'
		}
		twoway `plots', ///
			yline(0, lcolor(gs6) lwidth(thin)) xline(`xl', lpattern(dash) lcolor(gs8) lwidth(thin)) ///
			xlabel(`xlab', labsize(small) notick) xscale(range(`xr')) xtitle("") ///
			ylabel(#6, labsize(small) angle(horizontal) glcolor(gs15) glwidth(vthin)) ///
			ytitle("Dynamic DiD coefficient", size(small)) ///
			title("`tit_`o''", size(medsmall) color(black)) ///
			legend(order(`order') rows(1) position(6) size(small) symxsize(small) keygap(tiny) ///
			       region(lcolor(white))) ///
			graphregion(color(white) lcolor(white) ilcolor(white)) plotregion(color(white)) ///
			xsize(3.6) ysize(2.9)
		graph export "$graphs/trim_es_`sec'_`o'.pdf", as(pdf) replace
	}
}
graph drop _all
restore

log close
di as result "Finished: `c(current_date)' `c(current_time)'"

********************************************************************************
* SECTION 6: TABLES AND PDF REPORT
********************************************************************************

if "$python_exe" == "" global python_exe "python3"
shell $python_exe "$programs/analysis/robustness/4320_trim_firmsize_report.py" "$tables" "$graphs"
di as result "Report written to $tables/trim_firmsize_report.tex (and .pdf if a LaTeX engine was found)"

********************************************************************************
* END OF DO-FILE
********************************************************************************
