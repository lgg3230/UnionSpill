/*
================================================================================
3242_trim_sides.do — Log hourly wage effects after trimming the left, right,
or both tails of the pooled firm-size distribution

Run through the wrapper 3241_trim_sides.do, which sets the globals
($rais_firm, $rais_aux, $tables, $graphs, $logs, $programs).

SIZE AND CUTOFFS
  Size = firm_emp_pre, mean employment over 2009-2011 (as in 3012). Cutoffs
  are percentiles computed ONCE on the pooled analysis sample: one row per
  firm (year == 2009), lagos_sample_avg == 1 & in_balanced_panel == 1,
  treated and untreated together (not within groups). Firms exactly at a
  cutoff are kept; whole firms are dropped.

VARIANTS (each a separate estimation sample)
  base     no trimming; must reproduce the published estimates in
           Tables/pct_tfpw_cc/ (3012): the run STOPS (exit 9) if not
  left5    drop firms below P5          left10   ... below P10    left20   ... below P20
  right5   drop firms above P95         right10  ... above P90    right20  ... above P80
  both5    below P5 or above P95        both10   below P10 / above P90
                                        both20   below P20 / above P80
  Only the sample changes: the _pre4 outcome, size and flow bins and the p90
  that normalizes connectivity are built on the untrimmed panel (as in 3012)
  and NOT rebuilt per variant. The both5/both10/both20 samples equal 3222's
  trim_5 / trim_10 / trim_20 (pooled two-tail trims), so those rows double as a check.

ESTIMATES (log hourly wages, lr_remdezr_h_w, only), specification as in 3012
    direct_A  treated vs zero-connectivity untreated   (published Panel A)
    direct_C  treated vs all untreated                 (published Panel B)
    spill     untreated only, Post x totaltreat_pw_norm
    AvsC      test of beta(direct_A) = beta(direct_C): stacked regression of the
              two overlapping samples with sample-specific fixed effects, as in
              conn_margins/3022_direct_sample_coef_test.do (base gated against
              its published p-value)
  post: <term>##i.treat_year; placebo: <term>##i.placebo_year if year <= 2011;
  event study: <term>##ib2011.year, pre-trend F-test on 2009 and 2010.
  absorb(identificad i.industry1#i.year i.mode_base_month#i.year
         i.microregion#i.year ib0.Y_pre4#i.year ib0.l_firm_emp_pre4#i.year
         ib0.totalflows_pw_pre_07_114#i.year), vce(cluster identificad)

Output ($tables = Tables/trim_sides/, $graphs = Graphs/trim_sides/):
  trim_sides_cutoffs.csv        pooled percentiles (P5 P10 P20 P80 P90 P95)
  trim_sides_groups.csv         variant,group,lo,hi,n_total,n_kept,mean,p50
                                (groups: treated, untreated, zero)
  trim_sides.csv                spec,section,outcome,row_type,value (long,
                                full precision, no stars; spec = variant)
  trim_sides_es.csv             variant,section,outcome,tvar,period,base,b,se,
                                pre_pval (dynamic coefficients)
  benchmark_base_check.csv      baseline vs published, cell by cell
  es_trim_sides_<direct_A|direct_C|spill>_<left|right|both>.pdf/.png
                                event studies: baseline (hollow), 5%, 10%
  -> 4340_trim_sides_latex.py: size and estimates tables, one 1x3 LaTeX
     wrapper per estimate, a summary CSV and a preview PDF
================================================================================
*/

version 17.0
set more off
set varabbrev off

* Paths come from the wrapper 3241_trim_sides.do.

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
cap mkdir "$logs"
cap mkdir "$tables"
cap mkdir "$graphs"
log using "$logs/trim_sides_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"

********************************************************************************
* HELPERS
********************************************************************************

* One row of the results CSV (long, full precision).
cap program drop _wrow
program define _wrow
	args spec section outcome rowtype value
	tempname fh
	file open `fh' using "$RES_CSV", write append
	file write `fh' "`spec',`section',`outcome',`rowtype'," %20.15g (`value') _n
	file close `fh'
end

* Event-study coefficients of the current estimates, one row per period. The
* base period is written with b = se = 0 and base = 1.
*   term(dir):  1.treat_ultra#<l>.<tvar>
*   term(conn): <l>.<tvar>#c.<var>
cap program drop _es_export
program define _es_export
	syntax , variant(string) section(string) outcome(string) tvar(name) term(string) ///
		pval(real) [var(name)]
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
		file write `fh' "`variant',`section',`outcome',`tvar',`l',`isbase'," ///
			%20.15g (`bb') "," %20.15g (`ss') "," %20.15g (`pval') _n
	}
	file close `fh'
end

* Benchmark cell: published vs replicated at format `fmt'.
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
* SECTION 3: POOLED CUTOFFS, VARIANTS AND GROUP SIZES
********************************************************************************

local variants "base left5 left10 left20 right5 right10 right20 both5 both10 both20"
local s_firm   "lagos_sample_avg == 1 & in_balanced_panel == 1 & year == 2009"
local g_treated   "treat_ultra == 1"
local g_untreated "treat_ultra == 0"
local g_zero      "treat_ultra == 0 & totaltreat_pw_n == 0"

quietly count if `s_firm' & missing(firm_emp_pre)
assert r(N) == 0

* Pooled percentiles (treated + untreated), stored as scalars so the
* comparison with the float firm_emp_pre is exact.
_pctile firm_emp_pre if `s_firm', percentiles(5 10 20 80 90 95)
scalar p5  = r(r1)
scalar p10 = r(r2)
scalar p20 = r(r3)
scalar p80 = r(r4)
scalar p90 = r(r5)
scalar p95 = r(r6)
di as result "Pooled size percentiles: P5 = " %9.4f scalar(p5) "  P10 = " %9.4f scalar(p10) ///
	"  P20 = " %9.4f scalar(p20) "  P80 = " %9.4f scalar(p80) ///
	"  P90 = " %9.4f scalar(p90) "  P95 = " %9.4f scalar(p95)
tempname fh
file open `fh' using "$tables/trim_sides_cutoffs.csv", write replace
file write `fh' "percentile,value" _n
foreach q in 5 10 20 80 90 95 {
	file write `fh' "p`q'," %20.15g (scalar(p`q')) _n
}
file close `fh'

* Lower / upper cutoff per variant (missing = no cut on that side).
local lo_base   = .
local hi_base   = .
local lo_left5  = scalar(p5)
local hi_left5  = .
local lo_left10 = scalar(p10)
local hi_left10 = .
local lo_right5  = .
local hi_right5  = scalar(p95)
local lo_right10 = .
local hi_right10 = scalar(p90)
local lo_both5  = scalar(p5)
local hi_both5  = scalar(p95)
local lo_both10 = scalar(p10)
local hi_both10 = scalar(p90)
local lo_left20  = scalar(p20)
local hi_left20  = .
local lo_right20 = .
local hi_right20 = scalar(p80)
local lo_both20  = scalar(p20)
local hi_both20  = scalar(p80)

* Keep flags (constant within firm). The cutoff side is compared with the
* scalar itself, not the macro copy, so ties are kept exactly.
cap drop keep_base
gen byte keep_base = 1
foreach q in 5 10 20 {
	local qq = 100 - `q'
	cap drop keep_left`q'
	gen byte keep_left`q'  = (firm_emp_pre >= scalar(p`q'))
	cap drop keep_right`q'
	gen byte keep_right`q' = (firm_emp_pre <= scalar(p`qq'))
	cap drop keep_both`q'
	gen byte keep_both`q'  = (firm_emp_pre >= scalar(p`q') & firm_emp_pre <= scalar(p`qq'))
}

* Group sizes per variant: firms kept, mean and median pre-period employment.
global GRP_CSV "$tables/trim_sides_groups.csv"
file open `fh' using "$GRP_CSV", write replace
file write `fh' "variant,group,lo,hi,n_total,n_kept,mean,p50" _n
file close `fh'
foreach v of local variants {
	foreach g in treated untreated zero {
		quietly count if `s_firm' & `g_`g''
		local n_tot = r(N)
		quietly sum firm_emp_pre if `s_firm' & `g_`g'' & keep_`v' == 1, detail
		file open `fh' using "$GRP_CSV", write append
		file write `fh' "`v',`g'," %20.15g (`lo_`v'') "," %20.15g (`hi_`v'') ",`n_tot',`r(N)'," ///
			%20.15g (r(mean)) "," %20.15g (r(p50)) _n
		file close `fh'
	}
}
type "$GRP_CSV"

********************************************************************************
* SECTION 4: ESTIMATION (log hourly wages)
********************************************************************************

local conn    "totaltreat_pw_norm"
local outcome "lr_remdezr_h_w"
local absorb  "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year ib0.totalflows_pw_pre_07_114#i.year"

local s_direct_A "(treat_ultra==0 & totaltreat_pw_n==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_direct_C "(treat_ultra==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_spill    "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

* Published values (Tables/pct_tfpw_cc/, written by 3012 via 3011), as in
* 3212_joint_spec.do. Order: b_post se_post b_pre se_pre pre_pval mean_pre
* n_obs n_estab.
local pub_direct_A "0.0285 0.0050 -0.0013 0.0054 0.7044 2.6479 112695 14136"
local pub_direct_C "0.0202 0.0033 0.0048 0.0035 0.1822 2.6134 130708 16398"
local pub_spill    "0.0065 0.0023 0.0014 0.0026 0.7989 2.3537 32495 4084"
local stats "b_post se_post b_pre se_pre pre_pval mean_pre n_obs n_estab"
* Published A-vs-C equality test (Tables/conn_margins/
* direct_sample_coef_test_currentconn.csv, 3022 via 3021): diff = beta_C -
* beta_A, its SE, and the p-value.
local pub_AvsC "-0.0083 0.0033 0.0125"
local stats_AvsC "d_b d_se d_p"

* Numeric firm id for the stacked test's sample-specific fixed effects.
cap drop firm_id
egen long firm_id = group(identificad)
local absorb_stk "i.samp#i.firm_id i.samp#i.industry1#i.year i.samp#i.mode_base_month#i.year i.samp#i.microregion#i.year i.samp#i.`outcome'_pre4#i.year i.samp#i.l_firm_emp_pre4#i.year i.samp#i.totalflows_pw_pre_07_114#i.year"
local fmts  "%9.4f %9.4f %9.4f %9.4f %9.4f %9.4f %12.0f %12.0f"

global RES_CSV   "$tables/trim_sides.csv"
global ES_CSV    "$tables/trim_sides_es.csv"
global BENCH_CSV "$tables/benchmark_base_check.csv"
global BENCH_FAIL 0
file open `fh' using "$RES_CSV", write replace
file write `fh' "spec,section,outcome,row_type,value" _n
file close `fh'
file open `fh' using "$ES_CSV", write replace
file write `fh' "variant,section,outcome,tvar,period,base,b,se,pre_pval" _n
file close `fh'
file open `fh' using "$BENCH_CSV", write replace
file write `fh' "section,outcome,stat,published,replicated,match" _n
file close `fh'

foreach v of local variants {
	local ks " & keep_`v' == 1"

	foreach sec in direct_A direct_C spill {
		if "`sec'" == "spill" {
			local term_post "c.`conn'##i.treat_year"
			local coef_post "1.treat_year#c.`conn'"
			local term_plac "c.`conn'##i.placebo_year"
			local coef_plac "1.placebo_year#c.`conn'"
			local term_es   "c.`conn'##ib2011.year"
			local test_es   "c.`conn'#i(2009 2010).year"
			local esterm    "conn"
		}
		else {
			local term_post "i.treat_ultra##i.treat_year"
			local coef_post "1.treat_ultra#1.treat_year"
			local term_plac "i.treat_ultra##i.placebo_year"
			local coef_plac "1.treat_ultra#1.placebo_year"
			local term_es   "i.treat_ultra##ib2011.year"
			local test_es   "1.treat_ultra#i(2009 2010).year"
			local esterm    "dir"
		}
		local samp "`s_`sec''"

		di _newline "============================================================"
		di "VARIANT `v'  `sec': `outcome'"
		di "============================================================"

		reghdfe `outcome' `term_post' if `samp'`ks', ///
			absorb(`absorb') vce(cluster identificad)
		local r_b_post  = _b[`coef_post']
		local r_se_post = _se[`coef_post']
		local p_post    = 2*ttail(e(df_r), abs(`r_b_post'/`r_se_post'))
		local r_n_obs   = e(N)
		local r_n_estab = e(N_clust)
		quietly sum `outcome' if e(sample) & inrange(year, 2009, 2011)
		local r_mean_pre = r(mean)

		reghdfe `outcome' `term_plac' if `samp' & year <= 2011`ks', ///
			absorb(`absorb') vce(cluster identificad)
		local r_b_pre  = _b[`coef_plac']
		local r_se_pre = _se[`coef_plac']
		local p_pre    = 2*ttail(e(df_r), abs(`r_b_pre'/`r_se_pre'))

		reghdfe `outcome' `term_es' if `samp'`ks', ///
			absorb(`absorb') vce(cluster identificad)
		testparm `test_es'
		local r_pre_pval = r(p)
		_es_export, variant(`v') section(`sec') outcome(`outcome') tvar(year) ///
			term(`esterm') var(`conn') pval(`r_pre_pval')

		_wrow `v' `sec' `outcome' main     `r_b_post'
		_wrow `v' `sec' `outcome' main_se  `r_se_post'
		_wrow `v' `sec' `outcome' main_p   `p_post'
		_wrow `v' `sec' `outcome' pre      `r_b_pre'
		_wrow `v' `sec' `outcome' pre_se   `r_se_pre'
		_wrow `v' `sec' `outcome' pre_p    `p_pre'
		_wrow `v' `sec' `outcome' pre_pval `r_pre_pval'
		_wrow `v' `sec' `outcome' mean_pre `r_mean_pre'
		_wrow `v' `sec' `outcome' n_obs    `r_n_obs'
		_wrow `v' `sec' `outcome' n_estab  `r_n_estab'

		di "  b = " %9.4f `r_b_post' " (" %6.4f `r_se_post' ")  placebo = " %9.4f `r_b_pre' ///
			" (" %6.4f `r_se_pre' ")  pre-trend p = " %6.4f `r_pre_pval' "  N = `r_n_obs'  estab = `r_n_estab'"

		if "`v'" == "base" {
			forvalues k = 1/8 {
				local s : word `k' of `stats'
				local f : word `k' of `fmts'
				local p : word `k' of `pub_`sec''
				_bench_cmp `sec' `outcome' `s' `p' `r_`s'' `f'
			}
		}
	}

	* ── Equality test, direct_A vs direct_C (stacked, as in 3022) ───────────
	* The zero-connectivity controls are a subset of all untreated, so the two
	* coefficients come from overlapping samples and are correlated. Two
	* copies of the variant's data (A and C), each with its own fixed effects
	* (samp#FE); treat#post#samp = beta_C - beta_A; SEs clustered on the firm,
	* which appears in both stacks.
	preserve
		keep if (`s_direct_C')`ks'
		gen byte samp = 1
		tempfile cpart
		save `cpart'
	restore
	preserve
		keep if (`s_direct_A')`ks'
		gen byte samp = 0
		append using `cpart'
		reghdfe `outcome' i.treat_ultra##i.treat_year##i.samp, ///
			absorb(`absorb_stk') vce(cluster firm_id)
		local r_d_bA = _b[1.treat_ultra#1.treat_year]
		local r_d_b  = _b[1.treat_ultra#1.treat_year#1.samp]
		local r_d_se = _se[1.treat_ultra#1.treat_year#1.samp]
		test 1.treat_ultra#1.treat_year#1.samp = 0
		local r_d_p  = r(p)
	restore
	_wrow `v' AvsC `outcome' b_A  `r_d_bA'
	_wrow `v' AvsC `outcome' diff `r_d_b'
	_wrow `v' AvsC `outcome' diff_se `r_d_se'
	_wrow `v' AvsC `outcome' diff_p  `r_d_p'
	di "  A vs C: beta_A = " %9.4f `r_d_bA' "  diff (C - A) = " %9.4f `r_d_b' " (" %6.4f `r_d_se' ")  p = " %6.4f `r_d_p'
	if "`v'" == "base" {
		forvalues k = 1/3 {
			local s : word `k' of `stats_AvsC'
			local p : word `k' of `pub_AvsC'
			_bench_cmp AvsC `outcome' `s' `p' `r_`s'' %9.4f
		}
	}

	* ── Gate: the baseline must reproduce the published estimates ────────────
	if "`v'" == "base" {
		type "$BENCH_CSV"
		if $BENCH_FAIL > 0 {
			di as error _newline "BASELINE CHECK FAILED: $BENCH_FAIL cell(s) differ from the published 3012 / 3022 output."
			di as error "See $BENCH_CSV. Trimmed variants were not estimated."
			log close
			exit 9
		}
		di as result _newline "Baseline check passed: all 27 cells match the published 3012 / 3022 output."
	}
}

********************************************************************************
* SECTION 5: EVENT-STUDY FIGURES (style of 3165)
********************************************************************************
* One PDF per estimate x side (left, right, both): the untrimmed baseline
* (hollow, project blue) and the 5% and 10% trims of that side (the 20% trims are in
* the tables only), dodged within
* each year; 2011 omitted; 95% CIs; dashed line between 2011 and 2012.

preserve
import delimited using "$ES_CSV", clear varnames(1)
gen double hi = b + 1.96*se
gen double lo = b - 1.96*se

local blue   "33 102 172"
local col1 "`blue'"
local col2 "235 104 52"
local col3 "27 175 122"
local col4 "237 161 0"
local sym1 "Oh"
local sym2 "S"
local sym3 "T"
local sym4 "D"

foreach side in left right both {
	cap drop k
	gen byte k = cond(variant == "base", 1, cond(variant == "`side'5", 2, ///
		cond(variant == "`side'10", 3, .)))
	cap drop x
	gen double x = period + (k - 2) * 0.2
	foreach sec in direct_A direct_C spill {
		local plots ""
		local order ""
		forvalues j = 1/3 {
			local msz = cond(`j' == 1, "medium", "small")
			local plots `"`plots' (rcap hi lo x if section == "`sec'" & k == `j', lcolor("`col`j''") lwidth(thin))"'
			local plots `"`plots' (scatter b x if section == "`sec'" & k == `j', msymbol(`sym`j'') mcolor("`col`j''") msize(`msz'))"'
		}
		* The trimmed side is named by the panel's subcaption, so the legend
		* only gives the level; two columns keep it to two rows.
		local order `"2 "Untrimmed (baseline)" 4 "5% trimmed" 6 "10% trimmed""'
		twoway `plots', ///
			xline(2011.5, lcolor(gs8) lpattern(dash) lwidth(thin)) ///
			yline(0, lcolor(gs10) lwidth(thin)) ///
			xlabel(2009(1)2016, labsize(small) nogrid) ///
			ylabel(, angle(horizontal) grid glcolor(gs15)) ///
			xtitle("Year") ytitle("Coefficient") ///
			legend(order(`order') cols(2) colgap(*0.6) position(6) size(small) region(lcolor(white))) ///
			graphregion(color(white)) bgcolor(white) ///
			xsize(4) ysize(3.8)
		graph export "$graphs/es_trim_sides_`sec'_`side'.pdf", as(pdf) replace
		graph export "$graphs/es_trim_sides_`sec'_`side'.png", as(png) width(1600) replace
	}
}
restore

log close
di as result "Finished: `c(current_date)' `c(current_time)'"

********************************************************************************
* SECTION 6: TABLES, LATEX WRAPPERS AND PREVIEW
********************************************************************************

if "$python_exe" == "" global python_exe "python3"
shell $python_exe "$programs/analysis/robustness/4340_trim_sides_latex.py" "$tables" "$graphs" --preview
di as result "Tables and figure wrappers written to $tables and $graphs"

********************************************************************************
* END OF DO-FILE
********************************************************************************
