/*
================================================================================
3292_trim_conn.do — Log hourly wage spillover effects after trimming or
winsorizing the left, right, or both tails of the connectivity distribution

Run through a wrapper, which sets the globals ($rais_firm, $rais_aux, $tables,
$graphs, $logs, $programs) and the mode:
  3291_trim_conn.do    $CONN_MODE = "trim"    drop the exposed firms beyond
                       the cutoffs (file stem trim_conn)
  3293_winsor_conn.do  $CONN_MODE = "winsor"  keep every firm and set their
                       connectivity to the cutoff instead (file stem
                       winsor_conn); zero connectivity stays zero

CONNECTIVITY AND CUTOFFS
  Connectivity = totaltreat_pw_n (per-worker flows to treated firms,
  2007-2011). Cutoffs are percentiles computed ONCE among the EXPOSED firms of
  the spillover sample: one row per firm (year == 2009), lagos_sample_avg == 1
  & in_balanced_panel == 1 & treat_ultra == 0 & totaltreat_pw_n > 0.
  Zero-connectivity firms (46% of the spillover sample) are always kept: they
  are the comparison group, and percentiles over the whole spillover sample
  would put P5-P20 at zero, which leaves the left tail undefined. Firms exactly
  at a cutoff are kept; whole firms are dropped.

VARIANTS (each a separate estimation sample)
  base     no trimming; must reproduce the published spillover estimates in
           Tables/pct_tfpw_cc/ (3012): the run STOPS (exit 9) if not
  left5    drop exposed firms below P5    left10 ... below P10   left20 ... below P20
  right5   drop exposed firms above P95   right10 ... above P90  right20 ... above P80
  both5    below P5 or above P95          both10  below P10 / above P90
                                          both20  below P20 / above P80
  Only the sample changes: the _pre4 outcome, size and flow bins and the p90
  that scales connectivity (totaltreat_pw_norm) are built on the untrimmed
  panel (as in 3012) and NOT rebuilt per variant, so every coefficient is per
  unit of the same scaled connectivity.

ESTIMATES (log hourly wages, lr_remdezr_h_w), specification as in 3012
    spill     untreated only, Post x totaltreat_pw_norm
  post: c.conn##i.treat_year; placebo: c.conn##i.placebo_year if year <= 2011;
  event study: c.conn##ib2011.year, pre-trend F-test on 2009 and 2010.
  absorb(identificad i.industry1#i.year i.mode_base_month#i.year
         i.microregion#i.year ib0.Y_pre4#i.year ib0.l_firm_emp_pre4#i.year
         ib0.totalflows_pw_pre_07_114#i.year), vce(cluster identificad)

Output ($tables = Tables/<stem>/, $graphs = Graphs/<stem>/; trim_conn shown):
  trim_conn_cutoffs.csv         percentiles among exposed firms (P5 ... P95)
  trim_conn_groups.csv          variant,lo,hi,n_exposed,n_exposed_kept,n_zero,
                                mean_conn,p50_conn,mean_emp,p50_emp (kept exposed)
  trim_conn.csv                 spec,section,outcome,row_type,value (long, full
                                precision, no stars; spec = variant)
  trim_conn_es.csv              variant,section,outcome,tvar,period,base,b,se,
                                pre_pval (dynamic coefficients)
  benchmark_base_check.csv      baseline vs published, cell by cell
  es_trim_conn_spill_<left|right|both>.pdf/.png
                                event studies: baseline (hollow), 5%, 10%
  -> 4390_trim_conn_latex.py: table fragment, summary CSV, preview PDF
================================================================================
*/

version 17.0
set more off
set varabbrev off

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
cap mkdir "$logs"
cap mkdir "$tables"
cap mkdir "$graphs"
if "$CONN_MODE" == "" global CONN_MODE "trim"
if !inlist("$CONN_MODE", "trim", "winsor") {
	di as error "CONN_MODE must be trim or winsor"
	exit 198
}
global CONN_STEM = cond("$CONN_MODE" == "winsor", "winsor_conn", "trim_conn")
log using "$logs/${CONN_STEM}_`d'_`t'.log", replace text
di as result "Mode: $CONN_MODE"

di "Started: `c(current_date)' `c(current_time)'"

********************************************************************************
* HELPERS (as in 3242_trim_sides.do)
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

* Event-study coefficients of the current estimates (connectivity terms
* <l>.year#c.<var>), one row per year; 2011 written with b = se = 0, base = 1.
cap program drop _es_export
program define _es_export
	syntax , variant(string) section(string) outcome(string) var(name) pval(real)
	tempname fh
	file open `fh' using "$ES_CSV", write append
	foreach l in 2009 2010 2011 2012 2013 2014 2015 2016 {
		local bb = 0
		local ss = 0
		capture local bb = _b[`l'.year#c.`var']
		capture local ss = _se[`l'.year#c.`var']
		local isbase = (`l' == 2011)
		file write `fh' "`variant',`section',`outcome',year,`l',`isbase'," ///
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
* SECTION 1: DATA (verbatim from 3242_trim_sides.do)
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
* SECTION 2: VARIABLE CREATION (verbatim from 3242_trim_sides.do)
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
* SECTION 3: CUTOFFS AMONG EXPOSED FIRMS, VARIANTS AND GROUP SIZES
********************************************************************************

local variants "base left5 left10 left20 right5 right10 right20 both5 both10 both20"
local s_firm   "lagos_sample_avg == 1 & in_balanced_panel == 1 & treat_ultra == 0 & year == 2009"

quietly count if `s_firm' & missing(totaltreat_pw_n)
assert r(N) == 0

* Percentiles of connectivity among exposed spillover firms, stored as scalars
* so the comparison with the float totaltreat_pw_n is exact.
_pctile totaltreat_pw_n if `s_firm' & totaltreat_pw_n > 0, percentiles(5 10 20 80 90 95)
scalar p5  = r(r1)
scalar p10 = r(r2)
scalar p20 = r(r3)
scalar p80 = r(r4)
scalar p90 = r(r5)
scalar p95 = r(r6)
di as result "Connectivity percentiles among exposed firms (raw per-worker flows): P5 = " %9.6f scalar(p5) ///
	"  P10 = " %9.6f scalar(p10) "  P20 = " %9.6f scalar(p20) "  P80 = " %9.6f scalar(p80) ///
	"  P90 = " %9.6f scalar(p90) "  P95 = " %9.6f scalar(p95)
di as result "  in p90-scaled units (the regressor): divide by " %9.6f totaltreat_pw_n_p90[1]
tempname fh
file open `fh' using "$tables/${CONN_STEM}_cutoffs.csv", write replace
file write `fh' "percentile,value_raw,value_scaled" _n
foreach q in 5 10 20 80 90 95 {
	file write `fh' "p`q'," %20.15g (scalar(p`q')) "," %20.15g (scalar(p`q') / totaltreat_pw_n_p90[1]) _n
}
file close `fh'

* Lower / upper cutoff per variant (missing = no cut on that side).
local lo_base = .
local hi_base = .
foreach q in 5 10 20 {
	local qq = 100 - `q'
	local lo_left`q'  = scalar(p`q')
	local hi_left`q'  = .
	local lo_right`q' = .
	local hi_right`q' = scalar(p`qq')
	local lo_both`q'  = scalar(p`q')
	local hi_both`q'  = scalar(p`qq')
}

* Keep flags (constant within firm). Zero-connectivity firms are always kept;
* the cutoff side is compared with the scalar itself, so ties are kept exactly.
cap drop keep_base
gen byte keep_base = 1
foreach q in 5 10 20 {
	local qq = 100 - `q'
	cap drop keep_left`q'
	gen byte keep_left`q'  = (totaltreat_pw_n == 0 | totaltreat_pw_n >= scalar(p`q'))
	cap drop keep_right`q'
	gen byte keep_right`q' = (totaltreat_pw_n == 0 | totaltreat_pw_n <= scalar(p`qq'))
	cap drop keep_both`q'
	gen byte keep_both`q'  = (totaltreat_pw_n == 0 | ///
		(totaltreat_pw_n >= scalar(p`q') & totaltreat_pw_n <= scalar(p`qq')))
}

* Regressor per variant, in p90-scaled units. Trim: the scaled connectivity
* itself (the sample changes through keep_*). Winsorize: every firm is kept and
* positive connectivity beyond a cutoff is set to the cutoff; zeros stay zero.
foreach v of local variants {
	cap drop conn_`v'
	gen double conn_`v' = totaltreat_pw_norm
	if "$CONN_MODE" == "winsor" {
		quietly replace keep_`v' = 1
		if !missing(`lo_`v'') quietly replace conn_`v' = `lo_`v'' / totaltreat_pw_n_p90 ///
			if totaltreat_pw_n > 0 & totaltreat_pw_n < `lo_`v''
		if !missing(`hi_`v'') quietly replace conn_`v' = `hi_`v'' / totaltreat_pw_n_p90 ///
			if totaltreat_pw_n > `hi_`v''
	}
}

* Group sizes per variant: exposed firms kept, their scaled connectivity and
* pre-period employment; zero-connectivity firms (always kept).
global GRP_CSV "$tables/${CONN_STEM}_groups.csv"
file open `fh' using "$GRP_CSV", write replace
file write `fh' "variant,lo,hi,n_exposed,n_exposed_kept,n_zero,mean_conn,p50_conn,mean_emp,p50_emp" _n
file close `fh'
quietly count if `s_firm' & totaltreat_pw_n > 0
local n_exp = r(N)
quietly count if `s_firm' & totaltreat_pw_n == 0
local n_zero = r(N)
foreach v of local variants {
	quietly sum conn_`v' if `s_firm' & totaltreat_pw_n > 0 & keep_`v' == 1, detail
	local n_kept = r(N)
	local m_c = r(mean)
	local p_c = r(p50)
	quietly sum firm_emp_pre if `s_firm' & totaltreat_pw_n > 0 & keep_`v' == 1, detail
	file open `fh' using "$GRP_CSV", write append
	file write `fh' "`v'," %20.15g (`lo_`v'') "," %20.15g (`hi_`v'') ",`n_exp',`n_kept',`n_zero'," ///
		%20.15g (`m_c') "," %20.15g (`p_c') "," %20.15g (r(mean)) "," %20.15g (r(p50)) _n
	file close `fh'
}
type "$GRP_CSV"

********************************************************************************
* SECTION 4: ESTIMATION (spillover, log hourly wages)
********************************************************************************

local outcome "lr_remdezr_h_w"
local absorb  "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year ib0.totalflows_pw_pre_07_114#i.year"
local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

* Published values (Tables/pct_tfpw_cc/, written by 3012 via 3011), as in
* 3242_trim_sides.do. Order: b_post se_post b_pre se_pre pre_pval mean_pre
* n_obs n_estab.
local pub_spill "0.0065 0.0023 0.0014 0.0026 0.7989 2.3537 32495 4084"
local stats "b_post se_post b_pre se_pre pre_pval mean_pre n_obs n_estab"
local fmts  "%9.4f %9.4f %9.4f %9.4f %9.4f %9.4f %12.0f %12.0f"

global RES_CSV   "$tables/${CONN_STEM}.csv"
global ES_CSV    "$tables/${CONN_STEM}_es.csv"
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
	local conn "conn_`v'"
	local sec "spill"

	di _newline "============================================================"
	di "VARIANT `v'  `sec': `outcome'"
	di "============================================================"

	reghdfe `outcome' c.`conn'##i.treat_year if `s_spill'`ks', ///
		absorb(`absorb') vce(cluster identificad)
	local r_b_post  = _b[1.treat_year#c.`conn']
	local r_se_post = _se[1.treat_year#c.`conn']
	local p_post    = 2*ttail(e(df_r), abs(`r_b_post'/`r_se_post'))
	local r_n_obs   = e(N)
	local r_n_estab = e(N_clust)
	quietly sum `outcome' if e(sample) & inrange(year, 2009, 2011)
	local r_mean_pre = r(mean)
	quietly count if e(sample) & year == 2011 & totaltreat_pw_n > 0
	local r_n_exp_est = r(N)

	reghdfe `outcome' c.`conn'##i.placebo_year if `s_spill' & year <= 2011`ks', ///
		absorb(`absorb') vce(cluster identificad)
	local r_b_pre  = _b[1.placebo_year#c.`conn']
	local r_se_pre = _se[1.placebo_year#c.`conn']
	local p_pre    = 2*ttail(e(df_r), abs(`r_b_pre'/`r_se_pre'))

	reghdfe `outcome' c.`conn'##ib2011.year if `s_spill'`ks', ///
		absorb(`absorb') vce(cluster identificad)
	testparm c.`conn'#i(2009 2010).year
	local r_pre_pval = r(p)
	_es_export, variant(`v') section(`sec') outcome(`outcome') var(`conn') pval(`r_pre_pval')

	_wrow `v' `sec' `outcome' main      `r_b_post'
	_wrow `v' `sec' `outcome' main_se   `r_se_post'
	_wrow `v' `sec' `outcome' main_p    `p_post'
	_wrow `v' `sec' `outcome' pre       `r_b_pre'
	_wrow `v' `sec' `outcome' pre_se    `r_se_pre'
	_wrow `v' `sec' `outcome' pre_p     `p_pre'
	_wrow `v' `sec' `outcome' pre_pval  `r_pre_pval'
	_wrow `v' `sec' `outcome' mean_pre  `r_mean_pre'
	_wrow `v' `sec' `outcome' n_obs     `r_n_obs'
	_wrow `v' `sec' `outcome' n_estab   `r_n_estab'
	_wrow `v' `sec' `outcome' n_exposed `r_n_exp_est'

	di "  b = " %9.4f `r_b_post' " (" %6.4f `r_se_post' ")  placebo = " %9.4f `r_b_pre' ///
		" (" %6.4f `r_se_pre' ")  pre-trend p = " %6.4f `r_pre_pval' "  N = `r_n_obs'  estab = `r_n_estab'"

	* ── Gate: the baseline must reproduce the published estimates ────────────
	if "`v'" == "base" {
		forvalues k = 1/8 {
			local s : word `k' of `stats'
			local f : word `k' of `fmts'
			local p : word `k' of `pub_spill'
			_bench_cmp `sec' `outcome' `s' `p' `r_`s'' `f'
		}
		type "$BENCH_CSV"
		if $BENCH_FAIL > 0 {
			di as error _newline "BASELINE CHECK FAILED: $BENCH_FAIL cell(s) differ from the published 3012 output."
			di as error "See $BENCH_CSV. Trimmed variants were not estimated."
			log close
			exit 9
		}
		di as result _newline "Baseline check passed: all 8 cells match the published 3012 output."
	}
}

********************************************************************************
* SECTION 5: EVENT-STUDY FIGURES (style of 3242_trim_sides.do)
********************************************************************************
* One PDF per trimmed side (left, right, both): the untrimmed baseline (hollow,
* project blue) and the 5% and 10% trims of that side (the 20% trims are in the
* table only), dodged within each year; 2011 omitted; 95% CIs; dashed line
* between 2011 and 2012.

preserve
import delimited using "$ES_CSV", clear varnames(1)
gen double hi = b + 1.96*se
gen double lo = b - 1.96*se

local col1 "33 102 172"
local col2 "235 104 52"
local col3 "27 175 122"
local sym1 "Oh"
local sym2 "S"
local sym3 "T"

foreach side in left right both {
	cap drop k
	gen byte k = cond(variant == "base", 1, cond(variant == "`side'5", 2, ///
		cond(variant == "`side'10", 3, .)))
	cap drop x
	gen double x = period + (k - 2) * 0.2
	local plots ""
	forvalues j = 1/3 {
		local msz = cond(`j' == 1, "medium", "small")
		local plots `"`plots' (rcap hi lo x if base == 0 & k == `j', lcolor("`col`j''") lwidth(thin))"'
		local plots `"`plots' (scatter b x if base == 0 & k == `j', msymbol(`sym`j'') mcolor("`col`j''") msize(`msz'))"'
	}
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
	graph export "$graphs/es_${CONN_STEM}_spill_`side'.pdf", as(pdf) replace
	graph export "$graphs/es_${CONN_STEM}_spill_`side'.png", as(png) width(1600) replace
}
restore

log close
di as result "Finished: `c(current_date)' `c(current_time)'"

********************************************************************************
* SECTION 6: TABLE AND PREVIEW
********************************************************************************

if "$python_exe" == "" global python_exe "python3"
shell $python_exe "$programs/analysis/robustness/4390_trim_conn_latex.py" "$tables" "$CONN_MODE"
di as result "Table written to $tables"

********************************************************************************
* END OF DO-FILE
********************************************************************************
