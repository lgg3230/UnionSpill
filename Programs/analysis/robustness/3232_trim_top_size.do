/*
================================================================================
3232_trim_top_size.do — Main direct and spillover effects after trimming the
LARGEST establishments, within group

Run through the wrapper 3231_trim_top_size.do, which sets the globals
($rais_firm, $rais_aux, $tables, $graphs, $logs, $programs).

MOTIVATION
  Zero-connectivity controls are small: the largest has pre-period mean
  employment of 885, while a few percent of treated establishments are larger
  and hold a large share of treated employment. Trimming the top of the size
  distribution makes treated and comparison establishments more alike.

SIZE AND GROUPS
  Size = firm_emp_pre, mean employment over 2009-2011 (as in 3012/3162),
  taken once at the firm level (year == 2009) on the estimation sample
  (lagos_sample_avg == 1 & in_balanced_panel == 1). Three groups:
    treated   treat_ultra == 1                          (direct sample)
    zero      treat_ultra == 0 & totaltreat_pw_n == 0   (direct + spillover)
    pos       treat_ultra == 0 & totaltreat_pw_n > 0    (spillover sample)

VARIANTS (each a separate estimation sample; whole firms are dropped)
  base    no trimming; must reproduce the published Panel A and spillover
          estimates (Tables/pct_tfpw_cc/, 3012): the run STOPS (exit 9) after
          the baseline if any number differs
  cap     drop every firm in every group with firm_emp_pre > the largest
          zero-connectivity firm (885)
  top5    within each group, drop firms above the group's own 95th percentile
  top10   ... 90th percentile
  top20   ... 80th percentile
  Percentiles from _pctile at the firm level; firms exactly at a cutoff kept.
  Only the sample changes: the _pre4 outcome, size and flow bins and the p90
  that normalizes connectivity are built on the full untrimmed panel (as in
  3012) and NOT rebuilt per variant. (3222_trim_firmsize.do trims both tails
  on pooled percentiles; it is the code template, not the trimming rule.)

SPECIFICATIONS (per variant and outcome), exactly as in 3012_pct_tfpw.do
    direct_A  Y = a_i + FE + b * Post_t * T_i       treated + zero-connectivity untreated
    spill     Y = a_i + FE + g * Post_t * conn_i    untreated (zero + positive)
  post, placebo (year <= 2011) and event study (ib2011.year; pre-trend F-test
  on 2009-2010); numb_clauses in CBA periods (ib2.cba_period, F-test on
  period 1). absorb(identificad i.industry1#i.T i.mode_base_month#i.T
  i.microregion#i.T ib0.Y_pre4#i.T ib0.l_firm_emp_pre4#i.T
  ib0.totalflows_pw_pre_07_114#i.T), vce(cluster identificad).

Output ($tables = Tables/trim_top_size/, $graphs = Graphs/trim_top_size/):
  trim_top_size_groups.csv        variant,group,cutoff,n_total,n_kept,
                                  share_dropped,mean,p50,emp_share_dropped
  trim_top_size.csv               spec,section,outcome,row_type,value (long,
                                  full precision, no stars; spec = variant)
  trim_top_size_es.csv            variant,section,outcome,tvar,period,base,
                                  b,se,pre_pval (dynamic coefficients)
  benchmark_base_check.csv        baseline vs published, cell by cell
  es_trim_top_size_<direct|spill>_<lr_remdezr_h_w|lr_remdezr_w>.pdf/.png
                                  event studies, five variants overlaid (Stata)
  -> 4330_trim_top_size_latex.py: descriptive and estimates tables, the two
     event-study LaTeX wrappers, a summary CSV and a preview PDF
================================================================================
*/

version 17.0
set more off
set varabbrev off

* Paths come from the wrapper 3231_trim_top_size.do.

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
cap mkdir "$logs"
cap mkdir "$tables"
cap mkdir "$graphs"
log using "$logs/trim_top_size_`d'_`t'.log", replace text

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
* SECTION 3: GROUPS, VARIANTS AND THEIR SIZE CUTOFFS
********************************************************************************

local variants "base cap top5 top10 top20"
local groups   "treated zero pos"
local s_firm   "lagos_sample_avg == 1 & in_balanced_panel == 1 & year == 2009"
local g_treated "treat_ultra == 1"
local g_zero    "treat_ultra == 0 & totaltreat_pw_n == 0"
local g_pos     "treat_ultra == 0 & totaltreat_pw_n > 0 & !missing(totaltreat_pw_n)"

quietly count if `s_firm' & missing(firm_emp_pre)
assert r(N) == 0
quietly count if `s_firm' & treat_ultra == 0 & missing(totaltreat_pw_n)
assert r(N) == 0

* Cap: the largest zero-connectivity firm. Stored as a scalar so the
* comparison with the float firm_emp_pre is exact.
quietly sum firm_emp_pre if `s_firm' & `g_zero'
scalar cut_cap = r(max)
di as result "Cap = largest zero-connectivity firm: " %9.4f scalar(cut_cap)

* Within-group top percentiles (firm level).
foreach g of local groups {
	_pctile firm_emp_pre if `s_firm' & `g_`g'', percentiles(80 90 95)
	scalar cut_top20_`g' = r(r1)
	scalar cut_top10_`g' = r(r2)
	scalar cut_top5_`g'  = r(r3)
	di as text "  `g': p80 = " %9.2f r(r1) "  p90 = " %9.2f r(r2) "  p95 = " %9.2f r(r3)
}

* Keep flags (constant within firm: size, treatment and connectivity are).
cap drop keep_base
gen byte keep_base = 1
cap drop keep_cap
gen byte keep_cap = (firm_emp_pre <= scalar(cut_cap))
foreach v in top5 top10 top20 {
	cap drop keep_`v'
	gen byte keep_`v' = ((`g_treated') & firm_emp_pre <= scalar(cut_`v'_treated)) | ///
	                    ((`g_zero')    & firm_emp_pre <= scalar(cut_`v'_zero))    | ///
	                    ((`g_pos')     & firm_emp_pre <= scalar(cut_`v'_pos))
}

* Descriptives per variant x group: cutoff, firms kept, share dropped,
* mean / median size of the kept firms, share of the group's pre-period
* employment held by the dropped firms.
global GRP_CSV "$tables/trim_top_size_groups.csv"
tempname fh
file open `fh' using "$GRP_CSV", write replace
file write `fh' "variant,group,cutoff,n_total,n_kept,share_dropped,mean,p50,emp_share_dropped" _n
file close `fh'
foreach v of local variants {
	foreach g of local groups {
		if "`v'" == "base"     local cut = .
		else if "`v'" == "cap" local cut = scalar(cut_cap)
		else                   local cut = scalar(cut_`v'_`g')
		quietly sum firm_emp_pre if `s_firm' & `g_`g''
		local n_tot = r(N)
		local e_tot = r(sum)
		quietly sum firm_emp_pre if `s_firm' & `g_`g'' & keep_`v' == 1, detail
		local n_kept = r(N)
		local mn     = r(mean)
		local med    = r(p50)
		local e_kept = r(sum)
		file open `fh' using "$GRP_CSV", write append
		file write `fh' "`v',`g'," %20.15g (`cut') ",`n_tot',`n_kept'," ///
			%20.15g (1 - `n_kept'/`n_tot') "," %20.15g (`mn') "," %20.15g (`med') "," ///
			%20.15g (1 - `e_kept'/`e_tot') _n
		file close `fh'
	}
}
type "$GRP_CSV"

********************************************************************************
* SECTION 4: ESTIMATION
********************************************************************************

local conn     "totaltreat_pw_norm"
local outcomes "lr_remdezr_h_w lr_remdezr_w l_firm_emp numb_clauses"

local s_direct_A "(treat_ultra==0 & totaltreat_pw_n==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_spill    "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

* Published values (Tables/pct_tfpw_cc/, written by 3012 via 3011), as in
* 3212_joint_spec.do. Order: b_post se_post b_pre se_pre pre_pval mean_pre
* n_obs n_estab.
local pub_direct_A_lr_remdezr_h_w "0.0285 0.0050 -0.0013 0.0054 0.7044 2.6479 112695 14136"
local pub_direct_A_lr_remdezr_w   "0.0262 0.0049 -0.0002 0.0046 0.7275 7.7666 112695 14136"
local pub_direct_A_l_firm_emp     "-0.0013 0.0152 0.0156 0.0101 0.0158 3.3198 113112 14139"
local pub_direct_A_numb_clauses   "1.5544 0.3044 0.1465 0.3484 0.7105 32.3162 73181 14178"
local pub_spill_lr_remdezr_h_w    "0.0065 0.0023 0.0014 0.0026 0.7989 2.3537 32495 4084"
local pub_spill_lr_remdezr_w      "0.0050 0.0022 0.0018 0.0025 0.7651 7.5514 32495 4084"
local pub_spill_l_firm_emp        "0.0009 0.0081 -0.0015 0.0063 0.8791 3.5466 32704 4088"
local pub_spill_numb_clauses      "0.0227 0.1175 0.3256 0.2014 0.0995 27.9349 19693 4142"
local stats "b_post se_post b_pre se_pre pre_pval mean_pre n_obs n_estab"
local fmts  "%9.4f %9.4f %9.4f %9.4f %9.4f %9.4f %12.0f %12.0f"

global RES_CSV   "$tables/trim_top_size.csv"
global ES_CSV    "$tables/trim_top_size_es.csv"
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
			di "VARIANT `v'  `sec': `outcome'"
			di "============================================================"

			reghdfe `outcome' `term_post' if `samp'`xs'`ks', ///
				absorb(`absorb') vce(cluster identificad)
			local r_b_post  = _b[`coef_post']
			local r_se_post = _se[`coef_post']
			local p_post    = 2*ttail(e(df_r), abs(`r_b_post'/`r_se_post'))
			local r_n_obs   = e(N)
			local r_n_estab = e(N_clust)
			quietly sum `outcome' if e(sample) & inrange(year, 2009, 2011)
			local r_mean_pre = r(mean)

			reghdfe `outcome' `term_plac' if `samp'`xs_p'`ks', ///
				absorb(`absorb') vce(cluster identificad)
			local r_b_pre  = _b[`coef_plac']
			local r_se_pre = _se[`coef_plac']
			local p_pre    = 2*ttail(e(df_r), abs(`r_b_pre'/`r_se_pre'))

			reghdfe `outcome' `term_es' if `samp'`xs'`ks', ///
				absorb(`absorb') vce(cluster identificad)
			testparm `test_es'
			local r_pre_pval = r(p)
			_es_export, variant(`v') section(`sec') outcome(`outcome') tvar(`tvar') ///
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
				local pubs "`pub_`sec'_`outcome''"
				forvalues k = 1/8 {
					local s : word `k' of `stats'
					local f : word `k' of `fmts'
					local p : word `k' of `pubs'
					_bench_cmp `sec' `outcome' `s' `p' `r_`s'' `f'
				}
			}
		}
	}

	* ── Gate: the baseline must reproduce the published estimates ────────────
	if "`v'" == "base" {
		type "$BENCH_CSV"
		if $BENCH_FAIL > 0 {
			di as error _newline "BASELINE CHECK FAILED: $BENCH_FAIL cell(s) differ from the published 3012 output."
			di as error "See $BENCH_CSV. Trimmed variants were not estimated."
			log close
			exit 9
		}
		di as result _newline "Baseline check passed: all 64 cells match the published 3012 output."
	}
}

di _newline "======================================================="
di "RESULTS: $RES_CSV"
di "======================================================="

********************************************************************************
* SECTION 5: WAGE EVENT-STUDY FIGURES (style of 3165)
********************************************************************************
* {direct, spillover} x {log hourly wages, log wages}: the five variants
* overlaid, dodged within each year; the untrimmed baseline hollow in the
* project blue, the trims in a fixed categorical order, each with its own
* marker shape; 2011 omitted; 95% CIs; dashed line between 2011 and 2012.

preserve
import delimited using "$ES_CSV", clear varnames(1)
keep if tvar == "year"
gen byte k = .
local K : word count `variants'
forvalues j = 1/`K' {
	local v : word `j' of `variants'
	replace k = `j' if variant == "`v'"
}
gen double hi = b + 1.96*se
gen double lo = b - 1.96*se
gen double x  = period - 0.28 + 0.56*(k - 1)/max(`K' - 1, 1)

local blue   "33 102 172"
local colors `""`blue'" "235 104 52" "27 175 122" "237 161 0" "232 123 164""'
local syms   "Oh S T D X"
local leg1 "Untrimmed (baseline)"
local leg2 "Cap at `=string(scalar(cut_cap), "%9.0f")' employees"
local leg3 "Top 5% trimmed"
local leg4 "Top 10% trimmed"
local leg5 "Top 20% trimmed"

foreach sec in direct_A spill {
	local secname = cond("`sec'" == "direct_A", "direct", "spill")
	foreach o in lr_remdezr_h_w lr_remdezr_w {
		local plots ""
		local order ""
		forvalues j = 1/`K' {
			local c : word `j' of `colors'
			local m : word `j' of `syms'
			local msz = cond(`j' == 1, "medium", "small")
			local plots `"`plots' (rcap hi lo x if section == "`sec'" & outcome == "`o'" & k == `j', lcolor("`c'") lwidth(thin))"'
			local plots `"`plots' (scatter b x if section == "`sec'" & outcome == "`o'" & k == `j', msymbol(`m') mcolor("`c'") msize(`msz'))"'
			local order `"`order' `=2*`j'' `"`leg`j''"'"'
		}
		twoway `plots', ///
			xline(2011.5, lcolor(gs8) lpattern(dash) lwidth(thin)) ///
			yline(0, lcolor(gs10) lwidth(thin)) ///
			xlabel(2009(1)2016, labsize(small) nogrid) ///
			ylabel(, angle(horizontal) grid glcolor(gs15)) ///
			xtitle("Year") ytitle("Coefficient") ///
			legend(order(`order') cols(2) position(6) size(small) region(lcolor(white))) ///
			graphregion(color(white)) bgcolor(white) ///
			xsize(4) ysize(3.5)
		graph export "$graphs/es_trim_top_size_`secname'_`o'.pdf", as(pdf) replace
		graph export "$graphs/es_trim_top_size_`secname'_`o'.png", as(png) width(1600) replace
	}
}
restore

log close
di as result "Finished: `c(current_date)' `c(current_time)'"

********************************************************************************
* SECTION 6: TABLES, LATEX WRAPPERS AND PREVIEW
********************************************************************************

if "$python_exe" == "" global python_exe "python3"
shell $python_exe "$programs/analysis/robustness/4330_trim_top_size_latex.py" "$tables" "$graphs" --preview
di as result "Tables and figure wrappers written to $tables and $graphs"

********************************************************************************
* END OF DO-FILE
********************************************************************************
