/*
================================================================================
linearity_did_fd.do — First-difference linearity test (validated approach)
Cattaneo, Crump, Farrell, Feng (2024) sup-norm binstest

Defends the linear functional form of the headline spillover DiD
(Main_Results PART D / conn_margins): Y_jt = beta*(Conn_j x Post_t) + firm FE
+ group-by-year FE + controls, on the spillover sample s_spill.

VALIDATED EQUIVALENCE (see linearity_did_notes_fd.md):
  The panel DiD coefficient on c.conn#1.treat_year equals the OLS slope of the
  firm-level first difference  dY_j = mean(Y, 2012-16) - mean(Y, 2009-11)  on
  Conn_j, controlling for the differenced (group-dummy) versions of the panel's
  group-by-year FE. Match is machine-precision for employment and ~1e-5 for
  wages; standard errors agree to the third decimal (firm FE is differenced out,
  so the panel cluster-robust SE collapses to the cross-sectional robust SE).

Because the firm FE is removed by differencing, the linearity test runs on a
one-row-per-firm CROSS-SECTION: binsreg/binstest can adjust for the remaining
controls INTERNALLY via w (Cattaneo eq. 3, no pre-residualization), with only
~510 covariates instead of ~8,000 firm dummies.

SAMPLE (2026-10-05): before each test the pooled spillover DiD of 3012 PART D
(reghdfe Y c.conn##i.treat_year, full FE set; c.conn##post_treat_cba with
CBA-period FE for numb_clauses) is estimated, and binstest runs on the firms
with at least one firm-year in its e(sample). The test's establishment count
therefore matches the spillover table (reghdfe singleton drops excluded).

Outputs (Tables/conn_margins/):
  linearity_did_fd_test.csv            binstest results (per outcome), plus the
                                       pooled DiD: beta_did, se_did, n_obs_did,
                                       n_estab_did
  linearity_did_fd_<outcome>.csv       firm-level cross-section for the figure
================================================================================
*/

version 17.0
set more off
set varabbrev off

* ── Paths ─────────────────────────────────────────────────────────────────────

global main      "/kellogg/proj/lgg3230/UnionSpill"
* Panel vintage: the published spillover table (Draft.tex: 0.0050 / 0.0065 /
* 0.0009 / 0.0227) was built on the July 2026 current-connectivity overlay, not
* on the Sep-14 panel rebuilt from raw RAIS ("$main/Data/CBA_RAIS_firm_level").
* totaltreat_pw_norm is rebuilt below from this panel's own p90, which avoids
* the overlay's stale legacy-divisor column.
global rais_firm "$main/archive/Data/CBA_RAIS_firm_level_currentconn_overlay"
global rais_aux  "$main/Data/RAIS_aux"
global tables    "$main/Tables"
global logs      "$main/Logs"

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
cap mkdir "$logs/conn_margins"
log using "$logs/conn_margins/linearity_did_fd_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"

cap which binstest
if _rc != 0 {
	di "Installing binsreg from SSC..."
	ssc install binsreg, replace
}

* ── Load + merge totalflows ───────────────────────────────────────────────────

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

* ── Variable creation (mirrors Main_Results PART D) ───────────────────────────

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"
local conn    "totaltreat_pw_norm"

cap drop treat_year
gen byte treat_year = (year >= 2012)

cap drop cba_period
cap drop post_treat_cba
gen cba_period = .
replace cba_period = 1 if avg_file_date == earliest2009_avg - 1 & !missing(avg_file_date)
replace cba_period = 2 if avg_file_date == second_cba_avg        & !missing(avg_file_date)
replace cba_period = 3 if inrange(avg_file_date, mdy(1,1,2013), mdy(12,31,2013)) & cba_period == .
replace cba_period = 4 if inrange(avg_file_date, mdy(1,1,2014), mdy(12,31,2014)) & cba_period == .
replace cba_period = 5 if inrange(avg_file_date, mdy(1,1,2015), mdy(12,31,2015)) & cba_period == .
replace cba_period = 6 if inrange(avg_file_date, mdy(1,1,2016), mdy(12,31,2016)) & cba_period == .
gen byte post_treat_cba = cond(cba_period >= 3, 1, 0) if !missing(cba_period)


* destring industry1:

destring industry1, replace force

* Connectivity scaling (p90 among spillover sample in 2009)
cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen double totaltreat_pw_n_p90 = r(p90)
gen double totaltreat_pw_norm  = totaltreat_pw_n / totaltreat_pw_n_p90

* Pre-treatment employment mean -> log(mean) for the BIN control (not the FD)
cap drop firm_emp_pre_o
cap drop firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre   = min(firm_emp_pre_o)
	drop firm_emp_pre_o
}
cap drop l_firm_emp_pre
gen double l_firm_emp_pre = ln(firm_emp_pre)

* Pre-treatment outcome means (mean of the outcome) for the BIN controls
foreach outcome in lr_remdezr_w lr_remdezr_h_w {
	cap drop `outcome'_pre_o
	cap drop `outcome'_pre
	quietly {
		bys identificad: egen `outcome'_pre_o = mean(`outcome') if inrange(year, 2009, 2011)
		bys identificad: egen `outcome'_pre   = min(`outcome'_pre_o)
		drop `outcome'_pre_o
	}
}

capture confirm variable numb_clauses
if _rc == 0 {
	cap drop numb_clauses_pre_o
	cap drop numb_clauses_pre
	quietly {
		bys identificad: egen numb_clauses_pre_o = mean(numb_clauses) if inrange(cba_period, 1, 2)
		bys identificad: egen numb_clauses_pre   = min(numb_clauses_pre_o)
		drop numb_clauses_pre_o
	}
}

* 4-bin controls
cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
quietly {
	egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
	drop l_firm_emp_pre4_o
}
foreach v in lr_remdezr_w lr_remdezr_h_w {
	cap drop `v'_pre4_o
	cap drop `v'_pre4
	quietly {
		egen `v'_pre4_o = cut(`v'_pre) if year == 2009 & in_balanced_panel == 1, group(4)
		bys identificad: egen `v'_pre4 = min(`v'_pre4_o)
		drop `v'_pre4_o
	}
}
capture confirm variable numb_clauses
if _rc == 0 {
	cap drop numb_clauses_pre4_o
	cap drop numb_clauses_pre4
	quietly {
		egen numb_clauses_pre4_o = cut(numb_clauses_pre) if year == 2009 & in_balanced_panel == 1, group(4)
		bys identificad: egen numb_clauses_pre4 = min(numb_clauses_pre4_o)
		drop numb_clauses_pre4_o
		replace numb_clauses_pre4 = 0 if missing(numb_clauses_pre4)
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

* ── FIRST DIFFERENCE (mean-of-logs, computed directly from the outcome) ───────
* Calendar outcomes: post = 2012-16, pre = 2009-11.
foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {
	cap drop `outcome'_fdpre_o
	cap drop `outcome'_fdpre
	cap drop `outcome'_fdpost_o
	cap drop `outcome'_fdpost
	quietly {
		bys identificad: egen `outcome'_fdpre_o  = mean(`outcome') if inrange(year, 2009, 2011)
		bys identificad: egen `outcome'_fdpre    = min(`outcome'_fdpre_o)
		drop `outcome'_fdpre_o
		bys identificad: egen `outcome'_fdpost_o = mean(`outcome') if inrange(year, 2012, 2016)
		bys identificad: egen `outcome'_fdpost   = min(`outcome'_fdpost_o)
		drop `outcome'_fdpost_o
	}
	cap drop `outcome'_fd
	gen double `outcome'_fd = `outcome'_fdpost - `outcome'_fdpre
}

* numb_clauses: pre = CBA periods 1-2, post = CBA periods 3-6.
capture confirm variable numb_clauses
if _rc == 0 {
	cap drop numb_clauses_fdpre_o
	cap drop numb_clauses_fdpre
	cap drop numb_clauses_fdpost_o
	cap drop numb_clauses_fdpost
	quietly {
		bys identificad: egen numb_clauses_fdpre_o  = mean(numb_clauses) if inrange(cba_period, 1, 2)
		bys identificad: egen numb_clauses_fdpre    = min(numb_clauses_fdpre_o)
		drop numb_clauses_fdpre_o
		bys identificad: egen numb_clauses_fdpost_o = mean(numb_clauses) if inrange(cba_period, 3, 6)
		bys identificad: egen numb_clauses_fdpost   = min(numb_clauses_fdpost_o)
		drop numb_clauses_fdpost_o
	}
	cap drop numb_clauses_fd
	gen double numb_clauses_fd = numb_clauses_fdpost - numb_clauses_fdpre
}

* ── Output CSV header ─────────────────────────────────────────────────────────

tempname fh
file open `fh' using "$tables/conn_margins/linearity_did_fd_test.csv", write replace
file write `fh' "outcome,sample,n,nbins,stat_supt,pval,nsims,simsgrid,beta_did,se_did,n_obs_did,n_estab_did" _n
file close `fh'

* ── binstest on the firm-level cross-section (one row per firm) ───────────────
* Covariates passed as othercovs -> internal (Cattaneo) covariate adjustment.

foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {

	di _newline "============================================================"
	di "FD linearity test: `outcome'"
	di "============================================================"

	* ── Pooled DiD (3012 PART D) and its estimation sample ─────────────────
	* The test runs on the firms in this regression's e(sample), so its
	* establishment count matches the spillover table. A firm is in if any of
	* its firm-years is in e(sample) (reghdfe drops singleton observations).
	local absorb "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year ib0.totalflows_pw_pre_07_114#i.year"
	reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
		absorb(`absorb') vce(cluster identificad)
	local b_did  = _b[1.treat_year#c.`conn']
	local se_did = _se[1.treat_year#c.`conn']
	local n_did  = e(N)
	local g_did  = e(N_clust)
	cap drop did_obs
	cap drop did_firm
	gen byte did_obs = e(sample)
	bys identificad: egen byte did_firm = max(did_obs)
	di "  Pooled DiD: beta = " %9.6f `b_did' "  se = " %9.6f `se_did' "  N = `n_did'  establishments = `g_did'"

	local W "i.industry1 i.mode_base_month i.microregion ib0.`outcome'_pre4 ib0.l_firm_emp_pre4 ib0.totalflows_pw_pre_07_114"

	binstest `outcome'_fd `conn' `W' ///
		if did_firm == 1 & year == 2009 & !missing(`outcome'_fd), ///
		testmodelpoly(1) nbins(50) masspoints(nolocalcheck) ///
		nsims(2000) simsgrid(50) simsseed(12345) vce(robust)

	local stat  = e(stat_poly)
	local pval  = e(pval_poly)
	local nbins = e(nbins)
	local n     = e(N)
	di "  N: `n'  |  bins: `nbins'  |  stat: " %6.4f `stat' "  |  p-val: " %6.4f `pval'

	tempname fh
	file open `fh' using "$tables/conn_margins/linearity_did_fd_test.csv", write append
	file write `fh' `"`outcome',did_esample,`n',`nbins',`stat',`pval',2000,50,`b_did',`se_did',`n_did',`g_did'"' _n
	file close `fh'

	* Export firm-level cross-section for the figure
	preserve
		keep if did_firm == 1 & year == 2009 & !missing(`outcome'_fd)
		gen double outcome_fd = `outcome'_fd
		keep identificad outcome_fd totaltreat_pw_norm ///
		     industry1 mode_base_month microregion ///
		     `outcome'_pre4 l_firm_emp_pre4 totalflows_pw_pre_07_114
		rename `outcome'_pre4 outcome_pre4
		export delimited "$tables/conn_margins/linearity_did_fd_`outcome'.csv", replace
	restore
}

* numb_clauses
capture confirm variable numb_clauses
if _rc == 0 {

	di _newline "============================================================"
	di "FD linearity test: numb_clauses"
	di "============================================================"

	* ── Pooled DiD (3012 PART D, CBA periods) and its estimation sample ────
	local absorb_cba "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period ib0.totalflows_pw_pre_07_114#i.cba_period"
	reghdfe numb_clauses c.`conn'##post_treat_cba ///
		if `s_spill' & !missing(cba_period), ///
		absorb(`absorb_cba') vce(cluster identificad)
	local b_did  = _b[1.post_treat_cba#c.`conn']
	local se_did = _se[1.post_treat_cba#c.`conn']
	local n_did  = e(N)
	local g_did  = e(N_clust)
	cap drop did_obs
	cap drop did_firm
	gen byte did_obs = e(sample)
	bys identificad: egen byte did_firm = max(did_obs)
	di "  Pooled DiD: beta = " %9.6f `b_did' "  se = " %9.6f `se_did' "  N = `n_did'  establishments = `g_did'"

	local W "i.industry1 i.mode_base_month i.microregion ib0.numb_clauses_pre4 ib0.l_firm_emp_pre4 ib0.totalflows_pw_pre_07_114"

	binstest numb_clauses_fd `conn' `W' ///
		if did_firm == 1 & year == 2009 & !missing(numb_clauses_fd), ///
		testmodelpoly(1) nbins(50) masspoints(nolocalcheck) ///
		nsims(2000) simsgrid(50) simsseed(12345) vce(robust)

	local stat  = e(stat_poly)
	local pval  = e(pval_poly)
	local nbins = e(nbins)
	local n     = e(N)
	di "  N: `n'  |  bins: `nbins'  |  stat: " %6.4f `stat' "  |  p-val: " %6.4f `pval'

	tempname fh
	file open `fh' using "$tables/conn_margins/linearity_did_fd_test.csv", write append
	file write `fh' `"numb_clauses,did_esample,`n',`nbins',`stat',`pval',2000,50,`b_did',`se_did',`n_did',`g_did'"' _n
	file close `fh'

	preserve
		keep if did_firm == 1 & year == 2009 & !missing(numb_clauses_fd)
		gen double outcome_fd = numb_clauses_fd
		keep identificad outcome_fd totaltreat_pw_norm ///
		     industry1 mode_base_month microregion ///
		     numb_clauses_pre4 l_firm_emp_pre4 totalflows_pw_pre_07_114
		rename numb_clauses_pre4 outcome_pre4
		export delimited "$tables/conn_margins/linearity_did_fd_numb_clauses.csv", replace
	restore
}

di _newline "======================================================="
di "FD LINEARITY TEST RESULTS"
di "======================================================="
type "$tables/conn_margins/linearity_did_fd_test.csv"

capture log close

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && ///
	notify "linearity_did_fd done" "first-difference binstest complete"
