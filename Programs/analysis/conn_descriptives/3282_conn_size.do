********************************************************************************
* UNION SPILLOVERS — CONNECTIVITY AND ESTABLISHMENT SIZE (CROSS-SECTION)
* Purpose: How strongly is pre-reform connectivity to treated firms related to
*          establishment size among the untreated establishments of the
*          spillover sample?
* Sample:  spillover sample, one row per establishment:
*          lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1
*          (as s_spill in 3012_pct_tfpw.do; before outcome-specific drops).
* Dose:    totaltreat_pw_n (per-worker flows to treated firms, 2007-2011) and
*          totaltreat_pw_norm (scaled to its 2009 p90 among untreated firms,
*          the regressor of the main spillover regressions).
* Size:    l_firm_emp_pre = ln(mean employment 2009-2011), and its quartile
*          l_firm_emp_pre4 (the paper's size control); ln(employment 2009) as
*          an alternative.
* Output:  $tables/conn_size_stats.csv     correlations and regressions
*          $tables/conn_size_deciles.csv   connectivity by size decile
*          $graphs/conn_size_binned.pdf    share exposed and connectivity by size
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/conn_size_`d'_`t'.log", replace text

********************************************************************************
* SECTION 1: DATA (variable construction as in 3012_pct_tfpw.do)
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

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

* Connectivity scaled to the 2009 p90 among untreated firms.
cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
quietly sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen totaltreat_pw_n_p90 = r(p90)
gen totaltreat_pw_norm = totaltreat_pw_n / totaltreat_pw_n_p90

* Pre-reform size: ln(mean employment 2009-2011), and its quartile among
* balanced firms in 2009 (treated and untreated, as in the paper).
cap drop firm_emp_pre_o
cap drop firm_emp_pre
bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
bys identificad: egen firm_emp_pre = min(firm_emp_pre_o)
drop firm_emp_pre_o
cap drop l_firm_emp_pre
gen double l_firm_emp_pre = ln(firm_emp_pre)

cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) if year == 2009 & in_balanced_panel == 1, group(4)
bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
drop l_firm_emp_pre4_o

cap drop totalflows_pw_pre_07_114_o
cap drop totalflows_pw_pre_07_114
egen totalflows_pw_pre_07_114_o = cut(totalflows_pw_pre_07_11) ///
	if year == 2009 & in_balanced_panel == 1, group(4)
bys identificad: egen totalflows_pw_pre_07_114 = min(totalflows_pw_pre_07_114_o)
drop totalflows_pw_pre_07_114_o
replace totalflows_pw_pre_07_114 = 0 if missing(totalflows_pw_pre_07_114)

* One row per establishment of the spillover sample (2009 values).
keep if `s_spill' & year == 2009
isid identificad

gen double l_emp_2009 = ln(firm_emp)
gen double conn     = totaltreat_pw_norm
gen double conn_raw = totaltreat_pw_n
gen byte   exposed  = (conn > 0) if !missing(conn)
gen double l_conn   = ln(conn) if conn > 0
label var conn     "Connectivity, scaled to the 2009 p90"
label var conn_raw "Per-worker flows to treated firms, 2007-2011"
label var l_firm_emp_pre "Log mean employment 2009-2011"
label var exposed  "Positive connectivity"

quietly count
local N = r(N)
quietly count if exposed == 1
di as result "Spillover sample: `N' establishments, `r(N)' with positive connectivity"

********************************************************************************
* SECTION 2: STATISTICS
********************************************************************************

tempname fh
file open `fh' using "$tables/conn_size_stats.csv", write replace
file write `fh' "block;sample;stat;size_var;controls;b;se;p;n;r2" _n
file close `fh'

capture program drop _w
program define _w
	args block sample stat sizev ctrl b se p n r2
	tempname fh
	file open `fh' using "$tables/conn_size_stats.csv", write append
	file write `fh' "`block';`sample';`stat';`sizev';`ctrl';" %15.8g (`b') ";" %15.8g (`se') ";" ///
		%10.6f (`p') ";`n';" %8.4f (`r2') _n
	file close `fh'
end

* ── (a) Correlations ───────────────────────────────────────────────────────
* all: connectivity in levels (zeros included); exposed: levels and logs.
foreach sz in l_firm_emp_pre l_emp_2009 {
	foreach smp in all exposed {
		local if = cond("`smp'" == "all", "1", "exposed == 1")
		quietly pwcorr conn `sz' if `if', sig
		_w corr `smp' pearson_conn `sz' none `=r(rho)' . `=el(r(sig),2,1)' `=r(N)' .
		quietly spearman conn `sz' if `if'
		_w corr `smp' spearman_conn `sz' none `=r(rho)' . `=r(p)' `=r(N)' .
	}
	quietly pwcorr l_conn `sz' if exposed == 1, sig
	_w corr exposed pearson_logconn `sz' none `=r(rho)' . `=el(r(sig),2,1)' `=r(N)' .
}

* ── (b) Regressions of connectivity on log size ─────────────────────────────
* Controls build up to the paper's absorbed spillover controls (except the
* outcome's own pre-period quartile, which varies by outcome):
*   none | geo_ind_month: microregion + industry1 + base month
*   + size_q: the paper's size quartile bins (is there size variation in
*     connectivity WITHIN the bins the paper controls for?)
*   + flows_q: the paper's 2007-11 total-flows quartile bins
local c_none          ""
local c_geo_ind_month "microregion industry1 mode_base_month"
local c_size_q        "microregion industry1 mode_base_month l_firm_emp_pre4"
local c_flows_q       "microregion industry1 mode_base_month l_firm_emp_pre4 totalflows_pw_pre_07_114"

foreach dep in conn exposed l_conn {
	local smp = cond("`dep'" == "l_conn", "exposed", "all")
	foreach c in none geo_ind_month size_q flows_q {
		if "`c'" == "none" quietly regress `dep' l_firm_emp_pre, vce(robust)
		else               quietly reghdfe `dep' l_firm_emp_pre, absorb(`c_`c'') vce(robust)
		local p = 2 * ttail(e(df_r), abs(_b[l_firm_emp_pre] / _se[l_firm_emp_pre]))
		local r2 = cond("`c'" == "none", e(r2), e(r2_within))
		_w reg `smp' `dep' l_firm_emp_pre `c' `=_b[l_firm_emp_pre]' `=_se[l_firm_emp_pre]' `p' `=e(N)' `r2'
	}
}

* Extensive margin as a logit (average marginal effect of log size).
quietly logit exposed l_firm_emp_pre, vce(robust)
quietly margins, dydx(l_firm_emp_pre)
local b  = el(r(b), 1, 1)
local se = sqrt(el(r(V), 1, 1))
_w reg all exposed_logit_ame l_firm_emp_pre none `b' `se' `=2*normal(-abs(`b'/`se'))' `e(N)' .

* ── (c) Connectivity by size decile ────────────────────────────────────────
xtile size_dec = l_firm_emp_pre, nquantiles(10)
preserve
	gen double conn_pos = conn if exposed == 1
	gen n_firms = 1
	collapse (sum) n_firms (min) emp_min = firm_emp_pre (max) emp_max = firm_emp_pre ///
		(median) emp_med = firm_emp_pre (mean) share_exposed = exposed mean_conn = conn ///
		mean_conn_exposed = conn_pos (median) med_conn_exposed = conn_pos ///
		(mean) mean_lsize = l_firm_emp_pre, by(size_dec)
	export delimited using "$tables/conn_size_deciles.csv", delimiter(";") replace
	list size_dec n_firms emp_med share_exposed mean_conn mean_conn_exposed med_conn_exposed, noobs clean abbreviate(17)

	* Figure: share exposed (left) and mean connectivity among exposed (right),
	* by decile of pre-reform size (x-axis at the decile's median employment).
	twoway (connected share_exposed emp_med, lcolor("33 102 172") mcolor("33 102 172") msymbol(O)), ///
		xscale(log) xlabel(5 10 20 50 100 200 500 1000) ///
		ytitle("Share with positive connectivity") xtitle("Median employment 2009-2011 in size decile (log scale)") ///
		graphregion(color(white)) bgcolor(white) legend(off) name(g1, replace) nodraw
	twoway (connected mean_conn_exposed emp_med, lcolor("178 24 43") mcolor("178 24 43") msymbol(D)) ///
		(connected med_conn_exposed emp_med, lcolor("178 24 43") mcolor(white) mlcolor("178 24 43") msymbol(D) lpattern(dash)), ///
		xscale(log) xlabel(5 10 20 50 100 200 500 1000) ///
		ytitle("Connectivity among exposed (p90-scaled)") xtitle("Median employment 2009-2011 in size decile (log scale)") ///
		legend(order(1 "Mean" 2 "Median") rows(1) position(6) region(lcolor(white))) ///
		graphregion(color(white)) bgcolor(white) name(g2, replace) nodraw
	graph combine g1 g2, cols(2) graphregion(color(white)) xsize(10) ysize(4.5)
	graph export "$graphs/conn_size_binned.pdf", as(pdf) replace
restore

********************************************************************************
* SECTION 3: SUMMARY IN THE LOG
********************************************************************************

di _newline as result "Correlations and regressions (conn_size_stats.csv):"
preserve
	import delimited "$tables/conn_size_stats.csv", delimiter(";") clear varnames(1)
	format b se %9.4f
	list block sample stat size_var controls b se p n, noobs clean abbreviate(16)
restore

log close
di as result "Finished: `c(current_date)' `c(current_time)'"

********************************************************************************
* END OF DO-FILE
********************************************************************************
