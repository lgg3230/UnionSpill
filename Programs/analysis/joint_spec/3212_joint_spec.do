/*
================================================================================
3212_joint_spec.do — Direct effect and connectivity spillover in ONE regression,
with event studies of both terms next to the paper's main specifications

Run through the wrapper 3211_joint_spec.do, which sets the globals
($rais_firm, $rais_aux, $tables, $graphs, $logs, $programs).

SPECIFICATIONS (per outcome)
  Main specifications, exactly as in 3012_pct_tfpw.do:
    direct_A  Y = a_i + FE + b * Post_t * T_i       treated + zero-connectivity untreated (paper headline)
    direct_C  Y = a_i + FE + b * Post_t * T_i       treated + all untreated
    spill     Y = a_i + FE + g * Post_t * conn_i    untreated only
  Joint specification:
    joint     Y = a_i + FE + b * Post_t * T_i + g * Post_t * conn_joint_i
              on treated + all untreated (the direct_C sample), where
              conn_joint = totaltreat_pw_norm for untreated, 0 for treated, so
              g is identified only from untreated establishments and b compares
              treated establishments with untreated ones at zero connectivity
              (linear in connectivity).

  conn     = totaltreat_pw_norm (totaltreat_pw_n scaled so that 1 = p90 among
             untreated establishments in 2009)
  Calendar outcomes (lr_remdezr_w, lr_remdezr_h_w, l_firm_emp):
    post: <terms>##i.treat_year; placebo: <terms>##i.placebo_year if year <= 2011;
    event study: <terms>##ib2011.year, pre-trend F-test on 2009 and 2010.
    absorb(identificad i.industry1#i.year i.mode_base_month#i.year
           i.microregion#i.year ib0.Y_pre4#i.year ib0.l_firm_emp_pre4#i.year
           ib0.totalflows_pw_pre_07_114#i.year), vce(cluster identificad)
  numb_clauses: cba_period in place of year in every FE interaction,
    post_treat_cba / pre_treat_cba (placebo if cba_period <= 2), event study
    with ib2.cba_period (base = the 2010-2012 period), sample & !missing(cba_period).

  Data prep (Sections 1-2) is copied from 3202_conn_margins_es.do (itself a
  copy of 3012 without the turnover merge, union controls and percentile
  outcomes), plus conn_joint.

BENCHMARK
  The three main specifications are compared with the 3012 output in
  Tables/pct_tfpw_cc/ (b, SE, placebo b and SE, pre-trend p-value, pre-period
  mean to 4 decimals; N and establishments exactly). Any mismatch stops the run
  before the table and figures are built (exit 9).

Output:
  $tables/benchmark_main_check.csv       section,outcome,stat,published,replicated,match
  $tables/results_joint_spec.csv         project CSV schema; sections direct_A,
                                         direct_C, spill, joint_direct, joint_spill
  $tables/joint_spec_es_coefs.csv        event-study coefficients, same sections
  $tables/joint_spec_table.tex           joint specification only (4310)
  $tables/joint_spec_tables.tex          main vs joint, direct and spillover tables (4310)
  $graphs/es_direct_<outcome>.pdf        main vs joint direct effect (coefplot,
                                         style of fig:rob_logwages_recentered)
  $graphs/es_spill_<outcome>.pdf         main vs joint spillover (same style)
  $graphs/joint_spec_es_figure.tex       standalone preview of both figures,
                                         laid out like fig:rob_logwages_recentered
================================================================================
*/

version 17.0
set more off
set varabbrev off

* Paths come from the wrapper 3211_joint_spec.do.

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
cap mkdir "$logs"
cap mkdir "$tables"
cap mkdir "$graphs"
log using "$logs/joint_spec_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"

********************************************************************************
* HELPERS
********************************************************************************

* Benchmark cell: compare published and replicated values at format `fmt'.
cap program drop _bench_cmp
program define _bench_cmp
	args section outcome stat pub rep fmt
	local pub_s = strtrim(string(`pub', "`fmt'"))
	local rep_s = strtrim(string(`rep', "`fmt'"))
	local ok = cond("`pub_s'" == "`rep_s'", "yes", "NO")
	if "`ok'" == "NO" global BENCH_FAIL = $BENCH_FAIL + 1
	tempname fh
	file open `fh' using "$BENCH_CSV", write append
	file write `fh' "`section',`outcome',`stat',`pub_s',`rep_s',`ok'" _n
	file close `fh'
	di as text "  `section' `outcome' `stat': published `pub_s'  replicated `rep_s'  [`ok']"
end

* One row of the results CSV (3012 schema).
cap program drop _wrow
program define _wrow
	args section outcome rowtype value fmt stars
	tempname fh
	file open `fh' using "$RES_CSV", write append
	file write `fh' `""joint_spec";"`section'";"`outcome'";"`rowtype'";"' `fmt' (`value') `"`stars'""' _n
	file close `fh'
end

* Event-study coefficients of one term of the current estimates, one row per
* period. The base period is written with b = se = 0 and base = 1.
*   term(dir):  1.treat_ultra#<l>.<tvar>
*   term(conn): <l>.<tvar>#c.<var>
cap program drop _es_export
program define _es_export
	syntax , section(string) outcome(string) tvar(name) term(string) [var(name)]
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
		file write `fh' "`section',`outcome',`tvar',`l',`isbase'," %14.10f (`bb') "," %14.10f (`ss') _n
	}
	file close `fh'
end

* Event-study overlay of the main and joint specifications for one effect, in
* the style of the paper's fig:rob_logwages_recentered
* (rand_inference/4152_recentered_eventstudy.do): coefplot, Main = navy
* diamonds, Joint = maroon squares, offsets -/+0.12, pooled Post estimates as
* in-plot text at the top left, legend inside at the bottom, pre-trend F-test
* p-values in the note, 4 x 3 canvas.
*   term(dir):  1.treat_ultra#<l>.<tvar> in both models
*   term(conn): <l>.<tvar>#c.totaltreat_pw_norm (main) and
*               <l>.<tvar>#c.conn_joint (joint, renamed to the main name so the
*               two series share the x positions; both names go in keep())
*   bm/sem/pm, bj/sej/pj: pooled Post coefficient, SE and pre-trend F-test p of
*               the main and joint series
* The y range spans every plotted 95% CI. The text sits inside the top of that
* range when the intervals under it leave room, else in added headroom.
cap program drop _es_overlay
program define _es_overlay
	syntax , main(name) joint(name) term(string) tvar(name) ///
		bm(real) sem(real) pm(real) bj(real) sej(real) pj(real) file(string)

	* txtlevs: periods the in-plot text spans horizontally (it starts at x = xt).
	* With only six CBA periods the text would cross the reform line, so there
	* it starts just right of the line instead of at the left edge.
	if "`tvar'" == "cba_period" {
		local levels  "1 2 3 4 5 6"
		local txtlevs "3 4"
		local xl      2.5
		local xt      2.6
	}
	else {
		local levels  "2009 2010 2011 2012 2013 2014 2015 2016"
		local txtlevs "2009 2010 2011"
		local xl      3.75
		local xt      1.1
	}

	local keep ""
	local labs ""
	local ren  ""
	foreach l of local levels {
		if "`term'" == "dir" {
			local cn_`l' "1.treat_ultra#`l'.`tvar'"
			local cj_`l' "`cn_`l''"
		}
		else {
			local cn_`l' "`l'.`tvar'#c.totaltreat_pw_norm"
			local cj_`l' "`l'.`tvar'#c.conn_joint"
			local ren `ren' `cj_`l'' = `cn_`l''
			* coefplot applies keep() to the names BEFORE rename(), so the
			* joint model's original names must be kept too
			local keep `keep' `cj_`l''
		}
		if "`tvar'" == "cba_period" {
			if `l' == 1      local lab "2009"
			else if `l' == 2 local lab "2010-2012"
			else             local lab = string(2010 + `l')
		}
		else local lab "`l'"
		local keep `keep' `cn_`l''
		local labs `"`labs' `cn_`l'' = "`lab'""'
	}
	local renopt ""
	if "`ren'" != "" local renopt "rename(`ren')"

	* y range over both series' CIs (the base period sits at 0)
	local ymax = 0
	local ymin = 0
	local txthi = 0
	foreach m in main joint {
		estimates restore ``m''
		foreach l of local levels {
			local nm = cond("`m'" == "main", "`cn_`l''", "`cj_`l''")
			local bb = .
			local ss = .
			capture {
				local bb = _b[`nm']
				local ss = _se[`nm']
			}
			if mi(`bb') | mi(`ss') continue
			local hi = `bb' + 1.96*`ss'
			local lo = `bb' - 1.96*`ss'
			if `hi' > `ymax' local ymax = `hi'
			if `lo' < `ymin' local ymin = `lo'
			if strpos(" `txtlevs' ", " `l' ") & `hi' > `txthi' local txthi = `hi'
		}
	}
	local span = `ymax' - `ymin'
	if `span' <= 0 local span = 0.01
	local ylo = `ymin' - 0.12*`span'
	local t1  = `ymax' - 0.06*`span'
	local t2  = `ymax' - 0.16*`span'
	local yhi = `ymax' + 0.03*`span'
	if `txthi' > `t2' - 0.06*`span' {
		local t1  = `ymax' + 0.22*`span'
		local t2  = `ymax' + 0.12*`span'
		local yhi = `ymax' + 0.28*`span'
	}

	local bms  = strtrim(string(`bm',  "%9.4f"))
	local sems = strtrim(string(`sem', "%9.4f"))
	local bjs  = strtrim(string(`bj',  "%9.4f"))
	local sejs = strtrim(string(`sej', "%9.4f"))
	local pms  = strtrim(string(`pm',  "%5.3f"))
	local pjs  = strtrim(string(`pj',  "%5.3f"))

	coefplot ///
		(`main',  offset(-0.12) msymbol(diamond) mcolor(navy)   ciopts(recast(rcap) color(navy))   label("Main")) ///
		(`joint', offset(0.12)  msymbol(square)  mcolor(maroon) ciopts(recast(rcap) color(maroon)) label("Joint") `renopt'), ///
		keep(`keep') vert omitted baselevels yline(0) xline(`xl', lpattern(dash)) ///
		coeflabels(`labs') ///
		yscale(range(`ylo' `yhi')) ylabel(#6, labsize(small)) ///
		ytitle("Dynamic DiD coefficient", size(small)) ///
		note("Joint F-test p-values: main = `pms', joint = `pjs'", size(small)) ///
		graphregion(color(white)) bgcolor(white) ///
		legend(ring(0) position(6) rows(1) size(small) region(lcolor(none))) ///
		text(`t1' `xt' "Main: `bms' (`sems')", color(navy) size(small) placement(e)) ///
		text(`t2' `xt' "Joint: `bjs' (`sejs')", color(maroon) size(small) placement(e)) ///
		xsize(4) ysize(3)
	graph export "$graphs/`file'", as(pdf) replace
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

* Joint-specification regressor: connectivity for untreated establishments, 0
* for treated ones, so Post x conn_joint is identified only from untreated
* establishments. Untreated establishments with missing connectivity drop out
* of the joint regression (counted below).
cap drop conn_joint
gen double conn_joint = cond(treat_ultra == 1, 0, totaltreat_pw_norm) if !missing(treat_ultra)
label var conn_joint "Connectivity (p90-normalized) for untreated, 0 for treated"
di as text "Base-sample establishments in 2011 by treatment status, and untreated with missing connectivity:"
count if lagos_sample_avg == 1 & in_balanced_panel == 1 & year == 2011 & treat_ultra == 1
count if lagos_sample_avg == 1 & in_balanced_panel == 1 & year == 2011 & treat_ultra == 0
count if lagos_sample_avg == 1 & in_balanced_panel == 1 & year == 2011 & treat_ultra == 0 & missing(totaltreat_pw_norm)

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
* SECTION 3: ESTIMATION
********************************************************************************

local conn     "totaltreat_pw_norm"
local outcomes "lr_remdezr_h_w lr_remdezr_w l_firm_emp numb_clauses"

local s_direct_A "(treat_ultra==0 & totaltreat_pw_n==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_direct_C "(treat_ultra==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_spill    "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"
local s_joint    "`s_direct_C'"

* Published values (Tables/pct_tfpw_cc/, written by 3012 via 3011). Order:
* b_post se_post b_pre se_pre pre_pval mean_pre n_obs n_estab.
local pub_direct_A_lr_remdezr_h_w "0.0285 0.0050 -0.0013 0.0054 0.7044 2.6479 112695 14136"
local pub_direct_A_lr_remdezr_w   "0.0262 0.0049 -0.0002 0.0046 0.7275 7.7666 112695 14136"
local pub_direct_A_l_firm_emp     "-0.0013 0.0152 0.0156 0.0101 0.0158 3.3198 113112 14139"
local pub_direct_A_numb_clauses   "1.5544 0.3044 0.1465 0.3484 0.7105 32.3162 73181 14178"
local pub_direct_C_lr_remdezr_h_w "0.0202 0.0033 0.0048 0.0035 0.1822 2.6134 130708 16398"
local pub_direct_C_lr_remdezr_w   "0.0178 0.0032 0.0042 0.0030 0.1959 7.7433 130708 16398"
local pub_direct_C_l_firm_emp     "0.0024 0.0111 -0.0012 0.0076 0.4932 3.4844 131232 16404"
local pub_direct_C_numb_clauses   "1.3481 0.2350 0.2660 0.2471 0.3105 31.5864 84080 16444"
local pub_spill_lr_remdezr_h_w    "0.0065 0.0023 0.0014 0.0026 0.7989 2.3537 32495 4084"
local pub_spill_lr_remdezr_w      "0.0050 0.0022 0.0018 0.0025 0.7651 7.5514 32495 4084"
local pub_spill_l_firm_emp        "0.0009 0.0081 -0.0015 0.0063 0.8791 3.5466 32704 4088"
local pub_spill_numb_clauses      "0.0227 0.1175 0.3256 0.2014 0.0995 27.9349 19693 4142"
local stats "b_post se_post b_pre se_pre pre_pval mean_pre n_obs n_estab"
local fmts  "%9.4f %9.4f %9.4f %9.4f %9.4f %9.4f %12.0f %12.0f"

global BENCH_CSV "$tables/benchmark_main_check.csv"
global RES_CSV   "$tables/results_joint_spec.csv"
global ES_CSV    "$tables/joint_spec_es_coefs.csv"
global BENCH_FAIL 0
tempname fh
file open `fh' using "$BENCH_CSV", write replace
file write `fh' "section,outcome,stat,published,replicated,match" _n
file close `fh'
file open `fh' using "$RES_CSV", write replace
file write `fh' "spec,section,outcome,row_type,value" _n
file close `fh'
file open `fh' using "$ES_CSV", write replace
file write `fh' "section,outcome,tvar,period,base,b,se" _n
file close `fh'

foreach outcome of local outcomes {

	* ── Outcome-specific time structure ───────────────────────────────────────
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

	* ── Main specifications (3012), one term each ─────────────────────────────
	foreach sec in direct_A direct_C spill {
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
			local samp      "`s_`sec''"
			local term_post "i.treat_ultra##i.`post'"
			local coef_post "1.treat_ultra#1.`post'"
			local term_plac "i.treat_ultra##i.`plac'"
			local coef_plac "1.treat_ultra#1.`plac'"
			local term_es   "i.treat_ultra##`base'.`tvar'"
			local test_es   "1.treat_ultra#i(`prelev').`tvar'"
			local esterm    "dir"
		}

		di _newline "============================================================"
		di "MAIN SPEC `sec': `outcome'"
		di "============================================================"

		reghdfe `outcome' `term_post' if `samp'`xs', ///
			absorb(`absorb') vce(cluster identificad)
		local r_b_post  = _b[`coef_post']
		local r_se_post = _se[`coef_post']
		local p_post    = 2*ttail(e(df_r), abs(`r_b_post'/`r_se_post'))
		local r_n_obs   = e(N)
		local r_n_estab = e(N_clust)
		quietly sum `outcome' if e(sample) & inrange(year, 2009, 2011)
		local r_mean_pre = r(mean)

		reghdfe `outcome' `term_plac' if `samp'`xs_p', ///
			absorb(`absorb') vce(cluster identificad)
		local r_b_pre  = _b[`coef_plac']
		local r_se_pre = _se[`coef_plac']
		local p_pre    = 2*ttail(e(df_r), abs(`r_b_pre'/`r_se_pre'))

		reghdfe `outcome' `term_es' if `samp'`xs', ///
			absorb(`absorb') vce(cluster identificad)
		testparm `test_es'
		local r_pre_pval = r(p)
		_es_export, section(`sec') outcome(`outcome') tvar(`tvar') term(`esterm') var(`conn')
		estimates store es_`sec'

		_stars `p_post'
		local st_post "`r(s)'"
		_stars `p_pre'
		local st_pre "`r(s)'"
		_wrow `sec' `outcome' main     `r_b_post'   %9.4f   `st_post'
		_wrow `sec' `outcome' main_se  `r_se_post'  %9.4f
		_wrow `sec' `outcome' pre      `r_b_pre'    %9.4f   `st_pre'
		_wrow `sec' `outcome' pre_se   `r_se_pre'   %9.4f
		_wrow `sec' `outcome' pre_pval `r_pre_pval' %9.4f
		_wrow `sec' `outcome' n_obs    `r_n_obs'    %12.0fc
		_wrow `sec' `outcome' n_estab  `r_n_estab'  %12.0fc
		_wrow `sec' `outcome' mean_pre `r_mean_pre' %9.4f

		local pubs "`pub_`sec'_`outcome''"
		forvalues k = 1/8 {
			local s : word `k' of `stats'
			local f : word `k' of `fmts'
			local p : word `k' of `pubs'
			_bench_cmp `sec' `outcome' `s' `p' `r_`s'' `f'
		}
		local n_`sec' = `r_n_obs'
		local pb_`sec'  = `r_b_post'
		local pse_`sec' = `r_se_post'
		local ppv_`sec' = `r_pre_pval'
	}

	* ── Joint specification: Post x Treatment + Post x conn_joint ─────────────
	di _newline "============================================================"
	di "JOINT SPEC: `outcome'"
	di "============================================================"

	reghdfe `outcome' i.treat_ultra##i.`post' c.conn_joint##i.`post' if `s_joint'`xs', ///
		absorb(`absorb') vce(cluster identificad)
	local b_post_dir   = _b[1.treat_ultra#1.`post']
	local se_post_dir  = _se[1.treat_ultra#1.`post']
	local p_post_dir   = 2*ttail(e(df_r), abs(`b_post_dir'/`se_post_dir'))
	local b_post_conn  = _b[1.`post'#c.conn_joint]
	local se_post_conn = _se[1.`post'#c.conn_joint]
	local p_post_conn  = 2*ttail(e(df_r), abs(`b_post_conn'/`se_post_conn'))
	local n_obs        = e(N)
	local n_estab      = e(N_clust)
	quietly sum `outcome' if e(sample) & inrange(year, 2009, 2011)
	local mean_pre = r(mean)
	quietly count if e(sample) & treat_ultra == 0
	local n_obs_untr = r(N)

	reghdfe `outcome' i.treat_ultra##i.`plac' c.conn_joint##i.`plac' if `s_joint'`xs_p', ///
		absorb(`absorb') vce(cluster identificad)
	local b_pre_dir   = _b[1.treat_ultra#1.`plac']
	local se_pre_dir  = _se[1.treat_ultra#1.`plac']
	local p_pre_dir   = 2*ttail(e(df_r), abs(`b_pre_dir'/`se_pre_dir'))
	local b_pre_conn  = _b[1.`plac'#c.conn_joint]
	local se_pre_conn = _se[1.`plac'#c.conn_joint]
	local p_pre_conn  = 2*ttail(e(df_r), abs(`b_pre_conn'/`se_pre_conn'))

	reghdfe `outcome' i.treat_ultra##`base'.`tvar' c.conn_joint##`base'.`tvar' if `s_joint'`xs', ///
		absorb(`absorb') vce(cluster identificad)
	testparm 1.treat_ultra#i(`prelev').`tvar'
	local pval_dir = r(p)
	testparm c.conn_joint#i(`prelev').`tvar'
	local pval_conn = r(p)
	testparm 1.treat_ultra#i(`prelev').`tvar' c.conn_joint#i(`prelev').`tvar'
	local pval_both = r(p)
	_es_export, section(joint_direct) outcome(`outcome') tvar(`tvar') term(dir)
	_es_export, section(joint_spill)  outcome(`outcome') tvar(`tvar') term(conn) var(conn_joint)
	estimates store es_joint

	foreach x in post_dir post_conn pre_dir pre_conn {
		_stars `p_`x''
		local st_`x' "`r(s)'"
	}
	foreach x in dir conn {
		local sec = cond("`x'" == "dir", "joint_direct", "joint_spill")
		_wrow `sec' `outcome' main          `b_post_`x''  %9.4f   `st_post_`x''
		_wrow `sec' `outcome' main_se       `se_post_`x'' %9.4f
		_wrow `sec' `outcome' pre           `b_pre_`x''   %9.4f   `st_pre_`x''
		_wrow `sec' `outcome' pre_se        `se_pre_`x''  %9.4f
		_wrow `sec' `outcome' pre_pval      `pval_`x''    %9.4f
		_wrow `sec' `outcome' pre_pval_both `pval_both'   %9.4f
		_wrow `sec' `outcome' n_obs         `n_obs'       %12.0fc
		_wrow `sec' `outcome' n_estab       `n_estab'     %12.0fc
		_wrow `sec' `outcome' n_obs_untr    `n_obs_untr'  %12.0fc
		_wrow `sec' `outcome' mean_pre      `mean_pre'    %9.4f
	}

	di "  joint: b = " %9.4f `b_post_dir' " (" %6.4f `se_post_dir' ")   g = " %9.4f `b_post_conn' ///
		" (" %6.4f `se_post_conn' ")   N = `n_obs' (untreated `n_obs_untr')  estab = `n_estab'"
	di "  main direct_C N = `n_direct_C'   main spill N = `n_spill'"

	* ── Event-study figures: main vs joint, one per effect ────────────────────
	_es_overlay, main(es_direct_A) joint(es_joint) term(dir) tvar(`tvar') ///
		bm(`pb_direct_A') sem(`pse_direct_A') pm(`ppv_direct_A') ///
		bj(`b_post_dir') sej(`se_post_dir') pj(`pval_dir') ///
		file(es_direct_`outcome'.pdf)
	_es_overlay, main(es_spill) joint(es_joint) term(conn) tvar(`tvar') ///
		bm(`pb_spill') sem(`pse_spill') pm(`ppv_spill') ///
		bj(`b_post_conn') sej(`se_post_conn') pj(`pval_conn') ///
		file(es_spill_`outcome'.pdf)
	estimates drop es_direct_A es_direct_C es_spill es_joint
}

di _newline "======================================================="
di "RESULTS: $RES_CSV"
di "======================================================="
type "$RES_CSV"

if $BENCH_FAIL > 0 {
	di as error _newline "BENCHMARK FAILED: $BENCH_FAIL cell(s) differ from the 3012 output."
	di as error "See $BENCH_CSV. Table and figures were not built."
	type "$BENCH_CSV"
	log close
	exit 9
}
di as result _newline "Benchmark passed: the main specifications match the 3012 output."

********************************************************************************
* SECTION 4: LATEX FIGURES AND TABLES
********************************************************************************

* ── LaTeX figures, laid out like fig:rob_logwages_recentered in Draft.tex ─────
* One figure per effect, four outcome panels (0.49\textwidth subfigures), notes
* in a \scriptsize minipage. The file is a standalone preview: compile it in
* $graphs (e.g. tectonic joint_spec_es_figure.tex); the two figure blocks can be
* pasted into the paper with the paths adjusted.

local oname_lr_remdezr_h_w "Log Hourly Wages"
local oname_lr_remdezr_w   "Log Wages"
local oname_l_firm_emp     "Log Employment"
local oname_numb_clauses   "Number of Clauses"
local osuf_lr_remdezr_h_w  "hw"
local osuf_lr_remdezr_w    "w"
local osuf_l_firm_emp      "emp"
local osuf_numb_clauses    "cl"

local cap_direct "Direct Effects: Main and Joint Specifications"
local cap_spill  "Spillover Effects: Main and Joint Specifications"
local lab_direct "jsd"
local lab_spill  "jss"

local nt_direct1 "Event-study estimates of the direct effect of the 2012 ultractivity reform. Each panel plots the coefficients on treatment \(\times\) year from the paper's main specification (\emph{Main}), whose control group is untreated establishments with zero connectivity to treated establishments, and from the joint specification (\emph{Joint}), which adds connectivity \(\times\) year to the same regression and is estimated on treated and all untreated establishments, with connectivity set to zero for treated establishments."
local nt_direct2 "In-plot text reports the pooled treatment \(\times\)~Post estimate in each specification, with standard errors in parentheses."
local nt_spill1  "Event-study estimates of the spillover effect of the 2012 ultractivity reform. Each panel plots the coefficients on connectivity to treated firms \(\times\) year from the paper's main specification (\emph{Main}), estimated on untreated establishments only, and from the joint specification (\emph{Joint}), which adds treatment \(\times\) year to the same regression and is estimated on treated and all untreated establishments, with connectivity set to zero for treated establishments. Connectivity is normalized so that 1 is the 90th percentile among untreated establishments in 2009."
local nt_spill2  "In-plot text reports the pooled connectivity \(\times\)~Post estimate in each specification, with standard errors in parentheses."
local nt_common  "Reported joint \(F\)-test \(p\)-values are for the null that the 2009 and 2010 coefficients are jointly zero; for the number of clauses, time is measured in CBA periods, the base is the 2010--2012 agreement, and the test is for the 2009 coefficient. Bars are \(95\%\) confidence intervals from standard errors clustered at the establishment level."

local texf "$graphs/joint_spec_es_figure.tex"
tempname tf
file open `tf' using "`texf'", write replace
file write `tf' "% Event studies: main vs joint specification (direct effect and connectivity in one regression)." _n
file write `tf' "% Panels from Programs/analysis/joint_spec/3212_joint_spec.do (run via 3211), `c(current_date)'." _n
file write `tf' "% Standalone preview: compile in this folder (e.g. tectonic joint_spec_es_figure.tex)." _n
file write `tf' "\documentclass[12pt]{article}" _n
file write `tf' "\usepackage[left=1.0in,right=1.0in,top=1.0in,bottom=1.0in]{geometry}" _n
file write `tf' "\usepackage{lmodern}" _n
file write `tf' "\usepackage[T1]{fontenc}" _n
file write `tf' "\usepackage{amsmath}" _n
file write `tf' "\usepackage{graphicx, subcaption}" _n
file write `tf' "\usepackage{caption}" _n
file write `tf' "\captionsetup{font=small, labelfont=bf, justification=justified}" _n
file write `tf' "\pagestyle{empty}" _n _n
file write `tf' "\begin{document}" _n _n
foreach eff in direct spill {
	file write `tf' "\begin{figure}[!tbp]" _n
	file write `tf' "\centering" _n
	file write `tf' "\caption{`cap_`eff''}" _n
	file write `tf' "\label{fig:joint_spec_`eff'}" _n
	local k 0
	foreach outcome of local outcomes {
		local ++k
		file write `tf' "\begin{subfigure}[t]{0.49\textwidth}" _n
		file write `tf' "\centering" _n
		file write `tf' "\includegraphics[width=\textwidth]{es_`eff'_`outcome'.pdf}" _n
		file write `tf' "\caption{`oname_`outcome''}" _n
		file write `tf' "\label{fig:`lab_`eff''_`osuf_`outcome''}" _n
		file write `tf' "\end{subfigure}" _n
		if mod(`k', 2) == 1 file write `tf' "\hfill" _n
		else                file write `tf' _n
	}
	file write `tf' "\begin{minipage}{\linewidth}" _n
	file write `tf' "\scriptsize\vspace{4pt}" _n
	file write `tf' "\textit{Notes:} `nt_`eff'1'" _n
	file write `tf' "`nt_`eff'2'" _n
	file write `tf' "`nt_common'" _n
	file write `tf' "\end{minipage}" _n
	file write `tf' "\end{figure}" _n
	file write `tf' "\clearpage" _n _n
}
file write `tf' "\end{document}" _n
file close `tf'
di "Figure file written: `texf'"

* ── Tables from the results CSV ───────────────────────────────────────────────
if "$python_exe" == "" global python_exe "python3"
shell $python_exe "$programs/analysis/joint_spec/4310_table_joint_spec_latex.py" "$tables"
di "Tables:  $tables/joint_spec_tables.tex"
di "Figures: $graphs/es_{direct,spill}_<outcome>.pdf, $graphs/joint_spec_es_figure.tex"
di "Finished: `c(current_date)' `c(current_time)'"
capture log close
