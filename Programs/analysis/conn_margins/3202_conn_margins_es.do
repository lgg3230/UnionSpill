/*
================================================================================
3202_conn_margins_es.do — Spillover DiD with an extensive-margin term:
Post x 1{conn > 0} plus Post x conn, with event studies of both components

Run through the wrapper 3201_conn_margins_es.do, which sets the globals
($rais_firm, $rais_aux, $tables, $graphs, $logs, $programs).

Revives "Exercise 3 / Saturated model" of archive/Programs/conn_margins/
conn_margins.do, which wrote pooled coefficients and pre-trend F-tests only,
and adds event-study figures for both components.

SPECIFICATION
    Y_it = a_i + FE + d0 * Post_t * 1{conn_i > 0} + d1 * Post_t * conn_i + e_it

  conn     = totaltreat_pw_norm (totaltreat_pw_n scaled so that 1 = p90 among
             untreated establishments in 2009)
  pos_conn = 1{totaltreat_pw_n > 0}. conn x pos_conn = conn identically, so the
             model has no triple term: d0 is the jump at any connection, d1 the
             slope in connectivity. The effect at conn = c > 0 is d0 + d1 * c.

  Calendar outcomes (lr_remdezr_w, lr_remdezr_h_w, l_firm_emp):
    reghdfe Y i.pos_conn##i.treat_year c.conn##i.treat_year if s_spill,
      absorb(identificad i.industry1#i.year i.mode_base_month#i.year
             i.microregion#i.year ib0.Y_pre4#i.year ib0.l_firm_emp_pre4#i.year
             ib0.totalflows_pw_pre_07_114#i.year) vce(cluster identificad)
    placebo: placebo_year in place of treat_year, if year <= 2011
    event study: i.pos_conn##ib2011.year c.conn##ib2011.year
  numb_clauses: cba_period in place of year in every FE interaction,
    post_treat_cba / pre_treat_cba (placebo if cba_period <= 2), event study
    with ib2.cba_period, sample s_spill & !missing(cba_period).
  Sample, FEs and clustering are those of 3012_pct_tfpw.do PART D.

  Data prep (Sections 1-2) is copied from 3142_linearity_twfe.do (itself a
  verbatim copy of 3012 without the turnover merge, union controls and
  percentile outcomes), plus placebo_year and pre_treat_cba from 3012.

BENCHMARK TEST (Section 3, runs before the new spec)
  Re-estimates the standard spillover equation of 3012 PART D and compares it
  with the published table (UnionSpill_paper/Draft.tex, tab:spill_main_4tf_out):
  coefficients and SEs to 4 decimals, means to 3, counts exactly; pre-trend
  F-test p-values against Tables/pct_tfpw_cc/results_spill_tfpw_07_11_pct.csv
  (the Draft does not print them). Any mismatch stops the run (exit 9).

TABLE PANELS (Section 4, besides the saturated model "ex3")
  ex1 (Panel A): Post x 1{conn > 0} alone, full spillover sample
  ex2 (Panel B): Post x conn alone, establishments with totaltreat_pw_n > 0
  Each with its placebo and event-study pre-trend F-test, as in archive
  Exercises 1-2.

Output:
  $tables/benchmark_spill_check.csv        outcome,stat,published,replicated,match
  $tables/results_conn_margins_es.csv      project CSV schema, sections ex1-ex3
  $tables/conn_margins_es_wages.tex        wage table, Panels A-C (written by
                                           4300_table_conn_margins_latex.py)
  $graphs/es_<outcome>_connpos_<date>.pdf  event study of d0 (Post x 1{conn>0})
  $graphs/es_<outcome>_connlin_<date>.pdf  event study of d1 (Post x conn)
  $graphs/conn_margins_es_figure.tex       standalone 4x2 preview figure
================================================================================
*/

version 17.0
set more off
set varabbrev off

* Paths come from the wrapper 3201_conn_margins_es.do.

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
cap mkdir "$logs"
cap mkdir "$tables"
cap mkdir "$graphs"
log using "$logs/conn_margins_es_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"

********************************************************************************
* HELPERS
********************************************************************************

* Benchmark cell: compare published and replicated values at format `fmt'.
cap program drop _bench_cmp
program define _bench_cmp
	args outcome stat pub rep fmt
	local pub_s = strtrim(string(`pub', "`fmt'"))
	local rep_s = strtrim(string(`rep', "`fmt'"))
	local ok = cond("`pub_s'" == "`rep_s'", "yes", "NO")
	if "`ok'" == "NO" global BENCH_FAIL = $BENCH_FAIL + 1
	tempname fh
	file open `fh' using "$BENCH_CSV", write append
	file write `fh' "`outcome',`stat',`pub_s',`rep_s',`ok'" _n
	file close `fh'
	di as text "  `outcome' `stat': published `pub_s'  replicated `rep_s'  [`ok']"
end

* One row of the results CSV (3012 schema).
cap program drop _wrow
program define _wrow
	args section outcome rowtype value fmt stars
	tempname fh
	file open `fh' using "$ES_CSV", write append
	file write `fh' `""conn_margins_es";"`section'";"`outcome'";"`rowtype'";"' `fmt' (`value') `"`stars'""' _n
	file close `fh'
end

* Event-study plot of one component, in the style of 3012 PART D.
*   pre/suf: coefficient-name prefix/suffix around "<level>.<tvar>"
*            d0: pre(1.pos_conn#)            d1: suf(#c.totaltreat_pw_norm)
*   mode:    cal (2009-2016, base 2011) or cba (periods 1-6, base 2)
*   b/se/p:  pooled post coefficient, its SE, and the component's pre-trend p
*   file:    file name inside $graphs
cap program drop _es_plot
program define _es_plot
	syntax , est(name) tvar(name) mode(string) b(real) se(real) p(real) ///
		file(string) [pre(string) suf(string)]

	estimates restore `est'

	if "`mode'" == "cba" {
		local levels "1 2 3 4 5 6"
		local xl  2.5
		local sym square
		local xt  5
	}
	else {
		local levels "2009 2010 2011 2012 2013 2014 2015 2016"
		local xl  3.75
		local sym diamond
		local xt  6
	}

	* Labels and data-driven y range (the base period sits at 0, so the range
	* always includes 0).
	local labs ""
	local ymax_ci = 0
	local ymin_ci = 0
	foreach l of local levels {
		if "`mode'" == "cba" {
			if `l' == 1      local lab "2009"
			else if `l' == 2 local lab "2010-2012"
			else             local lab = string(2010 + `l')
		}
		else local lab "`l'"
		local labs `"`labs' `pre'`l'.`tvar'`suf' = "`lab'""'

		local bb = .
		local ss = .
		capture {
			local bb = _b[`pre'`l'.`tvar'`suf']
			local ss = _se[`pre'`l'.`tvar'`suf']
		}
		if !mi(`bb') & !mi(`ss') {
			local hi = `bb' + 1.96*`ss'
			local lo = `bb' - 1.96*`ss'
			if `hi' > `ymax_ci' local ymax_ci = `hi'
			if `lo' < `ymin_ci' local ymin_ci = `lo'
		}
	}
	local yspan = `ymax_ci' - `ymin_ci'
	if `yspan' <= 0 local yspan = 0.01
	* The b (se) label sits in a strip below the lowest CI (bottom right), so it
	* never overlaps a bar or the zero line. 3012's placement (15% of the span
	* ABOVE the lowest CI) crossed the bars in several of these panels.
	local ylo   = `ymin_ci' - 0.15*`yspan'
	local yhi   = `ymax_ci' + 0.05*`yspan'
	local ytext = `ymin_ci' - 0.075*`yspan'

	local bs = strtrim(string(`b',  "%9.4f"))
	local ss = strtrim(string(`se', "%9.4f"))
	local ps = strtrim(string(`p',  "%9.3f"))

	coefplot `est', ///
		keep(`pre'*.`tvar'`suf') ///
		msymbol(`sym') ///
		coeflabels(`labs') ///
		vert omitted baselevels yline(0) xline(`xl', lpattern(dash)) ///
		yscale(range(`ylo' `yhi')) ///
		ytitle("Dynamic DiD coefficients", size(small)) ///
		note("Joint pre-trend F-test p-value = `ps'") ///
		graphregion(color(white)) bgcolor(white) ///
		ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) ///
		text(`ytext' `xt' "`bs' (`ss')", color(blue) size(small) placement(w))

	graph export "$graphs/`file'", as(pdf) replace
end

********************************************************************************
* SECTION 1: DATA (from 3142, turnover merge omitted)
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

* ── Connectivity scaling + extensive-margin indicator ─────────────────────────

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen totaltreat_pw_n_p90 = r(p90)
gen totaltreat_pw_norm = (totaltreat_pw_n / totaltreat_pw_n_p90)

cap drop pos_conn
gen byte pos_conn = (totaltreat_pw_n > 0) if !missing(totaltreat_pw_n)
label var pos_conn "Any connectivity to treated firms (totaltreat_pw_n > 0)"

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
* SECTION 3: BENCHMARK — standard spillover equation vs the published table
********************************************************************************

local conn     "totaltreat_pw_norm"
local outcomes "lr_remdezr_w lr_remdezr_h_w l_firm_emp numb_clauses"

* Published values: Draft.tex tab:spill_main_4tf_out (b, se, placebo b and se,
* mean, N, establishments); pre_pval from Tables/pct_tfpw_cc/
* results_spill_tfpw_07_11_pct.csv. Order: b_post se_post b_pre se_pre
* pre_pval mean_pre n_obs n_estab.
local pub_lr_remdezr_w   "0.0050 0.0022  0.0018 0.0025 0.7651  7.551 32495 4084"
local pub_lr_remdezr_h_w "0.0065 0.0023  0.0014 0.0026 0.7989  2.354 32495 4084"
local pub_l_firm_emp     "0.0009 0.0081 -0.0015 0.0063 0.8791  3.547 32704 4088"
local pub_numb_clauses   "0.0227 0.1175  0.3256 0.2014 0.0995 27.935 19693 4142"
local stats "b_post se_post b_pre se_pre pre_pval mean_pre n_obs n_estab"
local fmts  "%9.4f %9.4f %9.4f %9.4f %9.4f %9.3f %12.0f %12.0f"

global BENCH_CSV  "$tables/benchmark_spill_check.csv"
global BENCH_FAIL 0
tempname fh
file open `fh' using "$BENCH_CSV", write replace
file write `fh' "outcome,stat,published,replicated,match" _n
file close `fh'

foreach outcome of local outcomes {

	* ── Outcome-specific time structure ───────────────────────────────────────
	if "`outcome'" == "numb_clauses" {
		local tvar   "cba_period"
		local post   "post_treat_cba"
		local plac   "pre_treat_cba"
		local samp   "`s_spill' & !missing(cba_period)"
		local samp_p "`s_spill' & !missing(cba_period) & cba_period <= 2"
		local base   "ib2"
		local prelev "1"
	}
	else {
		local tvar   "year"
		local post   "treat_year"
		local plac   "placebo_year"
		local samp   "`s_spill'"
		local samp_p "`s_spill' & year <= 2011"
		local base   "ib2011"
		local prelev "2009 2010"
	}
	local absorb "identificad i.industry1#i.`tvar' i.mode_base_month#i.`tvar' i.microregion#i.`tvar' ib0.`outcome'_pre4#i.`tvar' ib0.l_firm_emp_pre4#i.`tvar' ib0.totalflows_pw_pre_07_114#i.`tvar'"

	di _newline "============================================================"
	di "BENCHMARK (3012 PART D): `outcome'"
	di "============================================================"

	reghdfe `outcome' c.`conn'##i.`post' if `samp', ///
		absorb(`absorb') vce(cluster identificad)
	local r_b_post  = _b[1.`post'#c.`conn']
	local r_se_post = _se[1.`post'#c.`conn']
	local r_n_obs   = e(N)
	local r_n_estab = e(N_clust)
	local bench_n_`outcome'     = e(N)
	local bench_estab_`outcome' = e(N_clust)
	quietly sum `outcome' if e(sample) & inrange(year, 2009, 2011)
	local r_mean_pre = r(mean)

	reghdfe `outcome' c.`conn'##i.`plac' if `samp_p', ///
		absorb(`absorb') vce(cluster identificad)
	local r_b_pre  = _b[1.`plac'#c.`conn']
	local r_se_pre = _se[1.`plac'#c.`conn']

	reghdfe `outcome' c.`conn'##`base'.`tvar' if `samp', ///
		absorb(`absorb') vce(cluster identificad)
	testparm c.`conn'#i(`prelev').`tvar'
	local r_pre_pval = r(p)

	local pubs "`pub_`outcome''"
	forvalues k = 1/8 {
		local s : word `k' of `stats'
		local f : word `k' of `fmts'
		local p : word `k' of `pubs'
		_bench_cmp `outcome' `s' `p' `r_`s'' `f'
	}
}

if $BENCH_FAIL > 0 {
	di as error _newline "BENCHMARK FAILED: $BENCH_FAIL cell(s) differ from the published table."
	di as error "See $BENCH_CSV. The new specification was not run."
	type "$BENCH_CSV"
	log close
	exit 9
}
di as result _newline "Benchmark passed: all cells match the published table."

********************************************************************************
* SECTION 4: EXTENSIVE + INTENSIVE MARGIN SPEC AND EVENT STUDIES
********************************************************************************

global ES_CSV "$tables/results_conn_margins_es.csv"
tempname fh
file open `fh' using "$ES_CSV", write replace
file write `fh' "spec,section,outcome,row_type,value" _n
file close `fh'

foreach outcome of local outcomes {

	if "`outcome'" == "numb_clauses" {
		local tvar   "cba_period"
		local post   "post_treat_cba"
		local plac   "pre_treat_cba"
		local samp   "`s_spill' & !missing(cba_period)"
		local samp_p "`s_spill' & !missing(cba_period) & cba_period <= 2"
		local base   "ib2"
		local prelev "1"
		local mode   "cba"
	}
	else {
		local tvar   "year"
		local post   "treat_year"
		local plac   "placebo_year"
		local samp   "`s_spill'"
		local samp_p "`s_spill' & year <= 2011"
		local base   "ib2011"
		local prelev "2009 2010"
		local mode   "cal"
	}
	local absorb "identificad i.industry1#i.`tvar' i.mode_base_month#i.`tvar' i.microregion#i.`tvar' ib0.`outcome'_pre4#i.`tvar' ib0.l_firm_emp_pre4#i.`tvar' ib0.totalflows_pw_pre_07_114#i.`tvar'"

	di _newline "============================================================"
	di "CONNECTIVITY MARGINS: `outcome'"
	di "============================================================"

	* ── Panels A and B of the table: each margin on its own ───────────────────
	*   ex1: Post x 1{conn > 0} alone, full spillover sample
	*   ex2: Post x conn alone, positive-connectivity establishments only
	foreach ex in ex1 ex2 {
		if "`ex'" == "ex1" {
			local term_post "i.pos_conn##i.`post'"
			local coef_post "1.pos_conn#1.`post'"
			local term_plac "i.pos_conn##i.`plac'"
			local coef_plac "1.pos_conn#1.`plac'"
			local term_es   "i.pos_conn##`base'.`tvar'"
			local test_es   "1.pos_conn#i(`prelev').`tvar'"
			local restr     ""
		}
		else {
			local term_post "c.`conn'##i.`post'"
			local coef_post "1.`post'#c.`conn'"
			local term_plac "c.`conn'##i.`plac'"
			local coef_plac "1.`plac'#c.`conn'"
			local term_es   "c.`conn'##`base'.`tvar'"
			local test_es   "c.`conn'#i(`prelev').`tvar'"
			local restr     " & totaltreat_pw_n > 0"
		}

		di _newline "  --- `ex': `outcome' ---"
		reghdfe `outcome' `term_post' if `samp'`restr', ///
			absorb(`absorb') vce(cluster identificad)
		local b_m   = _b[`coef_post']
		local se_m  = _se[`coef_post']
		local p_m   = 2*ttail(e(df_r), abs(`b_m'/`se_m'))
		local n_m   = e(N)
		local ne_m  = e(N_clust)
		quietly sum `outcome' if e(sample) & inrange(year, 2009, 2011)
		local mean_m = r(mean)

		reghdfe `outcome' `term_plac' if `samp_p'`restr', ///
			absorb(`absorb') vce(cluster identificad)
		local b_p  = _b[`coef_plac']
		local se_p = _se[`coef_plac']
		local p_p  = 2*ttail(e(df_r), abs(`b_p'/`se_p'))

		reghdfe `outcome' `term_es' if `samp'`restr', ///
			absorb(`absorb') vce(cluster identificad)
		testparm `test_es'
		local pv = r(p)

		local st_m = cond(`p_m' < 0.01, "***", cond(`p_m' < 0.05, "**", cond(`p_m' < 0.10, "*", "")))
		local st_p = cond(`p_p' < 0.01, "***", cond(`p_p' < 0.05, "**", cond(`p_p' < 0.10, "*", "")))
		_wrow `ex' `outcome' main     `b_m'    %9.4f   `st_m'
		_wrow `ex' `outcome' main_se  `se_m'   %9.4f
		_wrow `ex' `outcome' pre      `b_p'    %9.4f   `st_p'
		_wrow `ex' `outcome' pre_se   `se_p'   %9.4f
		_wrow `ex' `outcome' pre_pval `pv'     %9.4f
		_wrow `ex' `outcome' n_obs    `n_m'    %12.0fc
		_wrow `ex' `outcome' n_estab  `ne_m'   %12.0fc
		_wrow `ex' `outcome' mean_pre `mean_m' %9.4f
	}

	* ── Panel C (ex3): saturated model, pooled post ───────────────────────────
	reghdfe `outcome' i.pos_conn##i.`post' c.`conn'##i.`post' if `samp', ///
		absorb(`absorb') vce(cluster identificad)
	local b_post_pos   = _b[1.pos_conn#1.`post']
	local se_post_pos  = _se[1.pos_conn#1.`post']
	local p_post_pos   = 2*ttail(e(df_r), abs(`b_post_pos'/`se_post_pos'))
	local b_post_conn  = _b[1.`post'#c.`conn']
	local se_post_conn = _se[1.`post'#c.`conn']
	local p_post_conn  = 2*ttail(e(df_r), abs(`b_post_conn'/`se_post_conn'))
	local n_obs        = e(N)
	local n_estab      = e(N_clust)
	quietly sum `outcome' if e(sample) & inrange(year, 2009, 2011)
	local mean_pre = r(mean)

	* ── Placebo ───────────────────────────────────────────────────────────────
	reghdfe `outcome' i.pos_conn##i.`plac' c.`conn'##i.`plac' if `samp_p', ///
		absorb(`absorb') vce(cluster identificad)
	local b_pre_pos   = _b[1.pos_conn#1.`plac']
	local se_pre_pos  = _se[1.pos_conn#1.`plac']
	local p_pre_pos   = 2*ttail(e(df_r), abs(`b_pre_pos'/`se_pre_pos'))
	local b_pre_conn  = _b[1.`plac'#c.`conn']
	local se_pre_conn = _se[1.`plac'#c.`conn']
	local p_pre_conn  = 2*ttail(e(df_r), abs(`b_pre_conn'/`se_pre_conn'))

	* ── Event study + pre-trend F-tests ───────────────────────────────────────
	reghdfe `outcome' i.pos_conn##`base'.`tvar' c.`conn'##`base'.`tvar' if `samp', ///
		absorb(`absorb') vce(cluster identificad)
	matrix list e(b)
	testparm 1.pos_conn#i(`prelev').`tvar'
	local pval_pos = r(p)
	testparm c.`conn'#i(`prelev').`tvar'
	local pval_conn = r(p)
	testparm 1.pos_conn#i(`prelev').`tvar' c.`conn'#i(`prelev').`tvar'
	local pval_joint = r(p)
	estimates store es_tmp

	* ── CSV ───────────────────────────────────────────────────────────────────
	foreach x in post_pos post_conn pre_pos pre_conn {
		local st_`x' = cond(`p_`x'' < 0.01, "***", cond(`p_`x'' < 0.05, "**", cond(`p_`x'' < 0.10, "*", "")))
	}
	_wrow ex3 `outcome' main_pos       `b_post_pos'   %9.4f   `st_post_pos'
	_wrow ex3 `outcome' main_pos_se    `se_post_pos'  %9.4f
	_wrow ex3 `outcome' main_conn      `b_post_conn'  %9.4f   `st_post_conn'
	_wrow ex3 `outcome' main_conn_se   `se_post_conn' %9.4f
	_wrow ex3 `outcome' pre_pos        `b_pre_pos'    %9.4f   `st_pre_pos'
	_wrow ex3 `outcome' pre_pos_se     `se_pre_pos'   %9.4f
	_wrow ex3 `outcome' pre_conn       `b_pre_conn'   %9.4f   `st_pre_conn'
	_wrow ex3 `outcome' pre_conn_se    `se_pre_conn'  %9.4f
	_wrow ex3 `outcome' pre_pval_pos   `pval_pos'     %9.4f
	_wrow ex3 `outcome' pre_pval_conn  `pval_conn'    %9.4f
	_wrow ex3 `outcome' pre_pval_joint `pval_joint'   %9.4f
	_wrow ex3 `outcome' n_obs          `n_obs'        %12.0fc
	_wrow ex3 `outcome' n_estab        `n_estab'      %12.0fc
	_wrow ex3 `outcome' mean_pre       `mean_pre'     %9.4f

	di "  d0 = " %9.4f `b_post_pos' " (" %6.4f `se_post_pos' ")   d1 = " %9.4f `b_post_conn' ///
		" (" %6.4f `se_post_conn' ")   N = `n_obs'  estab = `n_estab'"
	local same = cond(`n_obs' == `bench_n_`outcome'' & `n_estab' == `bench_estab_`outcome'', "yes", "NO")
	di "  benchmark N = `bench_n_`outcome''  estab = `bench_estab_`outcome''  |  same sample: `same'"

	* ── Event-study plots ─────────────────────────────────────────────────────
	_es_plot, est(es_tmp) tvar(`tvar') mode(`mode') pre(1.pos_conn#) ///
		b(`b_post_pos') se(`se_post_pos') p(`pval_pos') ///
		file(es_`outcome'_connpos_`d'.pdf)
	_es_plot, est(es_tmp) tvar(`tvar') mode(`mode') suf(#c.`conn') ///
		b(`b_post_conn') se(`se_post_conn') p(`pval_conn') ///
		file(es_`outcome'_connlin_`d'.pdf)
	estimates drop es_tmp
}

di _newline "======================================================="
di "RESULTS: $ES_CSV"
di "======================================================="
type "$ES_CSV"

********************************************************************************
* SECTION 5: PREVIEW FIGURE (standalone LaTeX, 4 x 2 grid)
********************************************************************************

local texf "$graphs/conn_margins_es_figure.tex"
tempname tf
file open `tf' using "`texf'", write replace
file write `tf' "% Event studies of the extensive + intensive margin spillover DiD." _n
file write `tf' "% Panels from Programs/analysis/conn_margins/3202_conn_margins_es.do (run via 3201), `c(current_date)'." _n
file write `tf' "% Standalone preview: compile in this folder (e.g. tectonic conn_margins_es_figure.tex)." _n
file write `tf' "\documentclass[11pt]{article}" _n
file write `tf' "\usepackage[left=0.75in,right=0.75in,top=0.6in,bottom=0.6in]{geometry}" _n
file write `tf' "\usepackage{lmodern}" _n
file write `tf' "\usepackage[T1]{fontenc}" _n
file write `tf' "\usepackage{microtype}" _n
file write `tf' "\usepackage{amsmath}" _n
file write `tf' "\usepackage{graphicx, subcaption}" _n
file write `tf' "\usepackage[flushleft]{threeparttable}" _n
file write `tf' "\usepackage{caption}" _n
file write `tf' "\captionsetup{font=small, labelfont=bf, justification=justified}" _n
file write `tf' "\pagestyle{empty}" _n _n
file write `tf' "\begin{document}" _n _n
file write `tf' "\begin{figure}[!htbp]" _n
file write `tf' "\centering" _n
file write `tf' "\caption{Spillover Event Studies: Any Connection and Connectivity}" _n
file write `tf' "\label{fig:conn_margins_es}" _n
file write `tf' "\begin{threeparttable}" _n

local oname_lr_remdezr_w   "Log wages"
local oname_lr_remdezr_h_w "Log hourly wages"
local oname_l_firm_emp     "Log employment"
local oname_numb_clauses   "Number of clauses"
local first 1
foreach outcome of local outcomes {
	if !`first' file write `tf' _n "    \vspace{0.2em}" _n _n
	local first 0
	file write `tf' "    \begin{subfigure}[t]{0.37\textwidth}" _n
	file write `tf' "        \centering" _n
	file write `tf' "        \caption{`oname_`outcome'': Post \(\times\) any connection}" _n
	file write `tf' "        \includegraphics[width=\textwidth]{es_`outcome'_connpos_`d'.pdf}" _n
	file write `tf' "    \end{subfigure}" _n
	file write `tf' "    \hfill" _n
	file write `tf' "    \begin{subfigure}[t]{0.37\textwidth}" _n
	file write `tf' "        \centering" _n
	file write `tf' "        \caption{`oname_`outcome'': Post \(\times\) connectivity}" _n
	file write `tf' "        \includegraphics[width=\textwidth]{es_`outcome'_connlin_`d'.pdf}" _n
	file write `tf' "    \end{subfigure}" _n
}

file write `tf' _n "    \begin{tablenotes}[flushleft]" _n
file write `tf' "        \scriptsize" _n
file write `tf' "        \item \textit{Notes:} This figure shows event-study estimates of the spillover specification" _n
file write `tf' "         with two treatment terms, Post \(\times\) \(\mathbf{1}\{C_i > 0\}\) and Post \(\times\) \(C_i\)," _n
file write `tf' "         each interacted with period indicators. The left column plots the coefficients on the" _n
file write `tf' "         indicator for any connection to treated establishments; the right column plots the" _n
file write `tf' "         coefficients on connectivity \(C_i\), normalized so that a value of 1 corresponds to the" _n
file write `tf' "         90th percentile among untreated establishments. The implied effect at connectivity" _n
file write `tf' "         \(c > 0\) is the sum of the indicator coefficient and \(c\) times the connectivity coefficient." _n
file write `tf' "         The sample consists of all untreated establishments. The base period is 2011; for the" _n
file write `tf' "         number of clauses, time is measured in CBA periods and the base is the 2010--2012 period." _n
file write `tf' "         Vertical bars are 95\% confidence intervals. The number in each panel is the pooled" _n
file write `tf' "         Post coefficient of that term, with its standard error in parentheses, and the note" _n
file write `tf' "         reports the joint pre-trend \(F\)-test p-value for that term. All regressions include the" _n
file write `tf' "         fixed effects and controls of the main spillover specification. Standard errors are" _n
file write `tf' "         clustered at the establishment level." _n
file write `tf' "    \end{tablenotes}" _n
file write `tf' "\end{threeparttable}" _n
file write `tf' "\end{figure}" _n _n
file write `tf' "\end{document}" _n
file close `tf'

di "Preview figure written: `texf'"

* ── Wage table (Panels A-C) from the results CSV ───────────────────────────────
if "$python_exe" == "" global python_exe "python3"
shell $python_exe "$programs/analysis/conn_margins/4300_table_conn_margins_latex.py" "$tables"
di "Wage table written: $tables/conn_margins_es_wages.tex"
di "Finished: `c(current_date)' `c(current_time)'"
capture log close
