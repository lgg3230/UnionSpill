/*
================================================================================
3172_linearity_fd.do — First-difference linearity test with the SAME bins as
the TWFE test (3142), side by side with that TWFE test, on one panel.

Purpose: 3142 (TWFE, rebuilt panel) gave employment p = 0.062 while the old
first-difference test (archive/.../linearity_did_fd.do: nbins(50) over ALL
connectivity, masspoints(nolocalcheck)) gave p ~ 0.79. For a balanced panel the
binned TWFE fit is a linear DiD on Post x [b(conn) - b(0)], so with identical
bins both should estimate the same curve. This file removes the configuration
differences and runs both tests on the vintage panel:
  - panel: set by the wrapper 3171_linearity_fd.do (July 2026 currentconn
    overlay, the panel behind the published spillover table)
  - bins: exactly 3142's rule. J from binsregselect on the TWFE equation
    (deriv(1) bins(1 1) binspos(es) randcut(1), DPI with ROT fallback); inner
    knots at quantiles of D = conn x Post among positive D in the reghdfe
    estimation sample. The SAME J and knots are passed to both tests.
  - mass-point / degrees-of-freedom checks ON (default masspoints) in both
  - slope test, testmodelpoly(1) deriv(1) (H0: mu' constant, i.e. mu linear;
    the article's recommended linearity test), nsims(2000) simsgrid(50)
    simsseed(12345). The first run (2026-10-06 01:07) used the level test
    (deriv(0)): TWFE and FD disagreed for every outcome; with deriv(1) they
    agree for the balanced outcomes.
TWFE test: binstest Y D if e(sample), absorb(full 3012 FE), vce(cluster firm)
FD test:   binstest dY conn W if firm in e(sample) & year == 2009, vce(robust)
           dY = mean(Y, post) - mean(Y, pre) (mean of logs on both ends);
           W  = industry, negotiation month, microregion, outcome pre4 bin,
                firm-size pre4 bin, flows pre4 bin (the differenced group x
                year FE, as in linearity_did_fd.do)
CAVEAT numb_clauses: the CBA-period panel is unbalanced, so the unweighted FD
does not reproduce the 6-period DiD (see project notes); its FD and TWFE tests
need not agree even with identical bins.

Data prep (Sections 1-2) is copied verbatim from 3142 (= 3012). The FD
construction is copied from archive/Programs/conn_margins/linearity_did_fd.do.

Output ($tables = Tables/linearity/):
  linearity_fd.csv   one row per outcome: pooled DiD, J, both tests
================================================================================
*/

version 17.0
set more off
set varabbrev off

* Paths come from the wrapper 3171_linearity_fd.do.

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
cap mkdir "$logs"
cap mkdir "$tables"
log using "$logs/linearity_fd_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
di "Panel: $rais_firm"

********************************************************************************
* SECTION 1: DATA (verbatim from 3012, turnover merge omitted)
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
* SECTION 2: VARIABLE CREATION (verbatim from 3012)
********************************************************************************

* ── a) Treatment & CBA period indicators ──────────────────────────────────────

cap drop treat_year
gen byte treat_year = (year >= 2012)

cap drop cba_period
cap drop post_treat_cba
gen cba_period = .
replace cba_period = 1 if avg_file_date == earliest2009_avg - 1 & !missing(avg_file_date)
replace cba_period = 2 if avg_file_date == second_cba_avg & !missing(avg_file_date)
replace cba_period = 3 if inrange(avg_file_date, mdy(1,1,2013), mdy(12,31,2013)) & cba_period == .
replace cba_period = 4 if inrange(avg_file_date, mdy(1,1,2014), mdy(12,31,2014)) & cba_period == .
replace cba_period = 5 if inrange(avg_file_date, mdy(1,1,2015), mdy(12,31,2015)) & cba_period == .
replace cba_period = 6 if inrange(avg_file_date, mdy(1,1,2016), mdy(12,31,2016)) & cba_period == .
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

* ── First differences (copied from archive/.../linearity_did_fd.do) ──────────
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


* Numeric firm id: binstest rejects string cluster variables
cap drop firm_num
egen long firm_num = group(identificad)

********************************************************************************
* SECTION 3: POOLED DiD, BINS, AND BOTH TESTS
********************************************************************************

local conn "totaltreat_pw_norm"
local csv  "$tables/linearity_fd.csv"

tempname fh
file open `fh' using "`csv'", write replace
file write `fh' "outcome,beta_did,se_did,n_obs_did,n_estab_did,nbins_selected,j_method,n_knots,"
file write `fh' "twfe_status,twfe_nbins,twfe_n,twfe_nclust,twfe_stat,twfe_pval,"
file write `fh' "fd_status,fd_nbins,fd_n,fd_stat,fd_pval" _n
file close `fh'

local outcomes "lr_remdezr_w lr_remdezr_h_w l_firm_emp"
capture confirm variable numb_clauses
if _rc == 0 local outcomes "`outcomes' numb_clauses"

foreach outcome of local outcomes {

	if "`outcome'" == "numb_clauses" {
		local tvar "cba_period"
		local post "post_treat_cba"
		local samp "`s_spill' & !missing(cba_period)"
	}
	else {
		local tvar "year"
		local post "treat_year"
		local samp "`s_spill'"
	}

	local absorb_full "identificad i.industry1#i.`tvar' i.mode_base_month#i.`tvar' i.microregion#i.`tvar' ib0.`outcome'_pre4#i.`tvar' ib0.l_firm_emp_pre4#i.`tvar' ib0.totalflows_pw_pre_07_114#i.`tvar'"
	local absorb_bt : subinstr local absorb_full "identificad" "firm_num"
	local W "i.industry1 i.mode_base_month i.microregion ib0.`outcome'_pre4 ib0.l_firm_emp_pre4 ib0.totalflows_pw_pre_07_114"

	di _newline "============================================================"
	di "Linearity, TWFE vs FD with identical bins: `outcome'"
	di "============================================================"

	* ── Pooled DiD (3012 PART D) and its estimation sample ───────────────────
	reghdfe `outcome' c.`conn'##i.`post' if `samp', ///
		absorb(`absorb_full') vce(cluster identificad)
	local b_did  = _b[1.`post'#c.`conn']
	local se_did = _se[1.`post'#c.`conn']
	local n_did  = e(N)
	local g_did  = e(N_clust)

	cap drop test_sample
	gen byte test_sample = e(sample)
	cap drop did_firm
	bys identificad: egen byte did_firm = max(test_sample)
	di "  Pooled DiD: beta = " %9.6f `b_did' "  se = " %9.6f `se_did' "  N = `n_did'  establishments = `g_did'"

	cap drop D
	gen double D = `conn' * `post'

	* ── Bins: 3142's rule ─────────────────────────────────────────────────────
	local J        = .
	local j_method "none"
	ereturn clear
	capture noisily binsregselect `outcome' D if test_sample, ///
		absorb(`absorb_bt') deriv(1) bins(1 1) binspos(es) ///
		randcut(1) vce(cluster firm_num)
	if _rc == 0 {
		capture local J = e(nbinsdpi)
		if !missing(`J') {
			local j_method "dpi"
		}
		else {
			capture local J = e(nbinsrot_regul)
			if !missing(`J') local j_method "rot"
		}
	}

	local knots ""
	local n_knots = 0
	if !missing(`J') & `J' >= 2 {
		_pctile D if test_sample & D > 0, nq(`J')
		local prev = 0
		forvalues k = 1/`=`J'-1' {
			local q = r(r`k')
			if `q' > `prev' {
				local knots "`knots' `q'"
				local prev = `q'
				local ++n_knots
			}
		}
	}
	di "  J = `J' (`j_method'), `n_knots' inner knots"

	* ── TWFE test (= 3142) ───────────────────────────────────────────────────
	local t_stat = .
	local t_p    = .
	local t_nb   = .
	local t_n    = .
	local t_g    = .
	local t_status "not_run"
	if "`knots'" != "" {
		ereturn clear
		capture noisily binstest `outcome' D if test_sample, ///
			absorb(`absorb_bt') testmodelpoly(1) deriv(1) binspos(`knots') ///
			nsims(2000) simsgrid(50) simsseed(12345) vce(cluster firm_num)
		local rc = _rc
		if `rc' == 0 {
			capture local t_stat = e(stat_poly)
			capture local t_p    = e(pval_poly)
			capture local t_nb   = e(nbins)
			capture local t_n    = e(N)
			capture local t_g    = e(Nclust)
		}
		local t_status = cond(`rc' != 0, "error", cond(missing(`t_stat'), "no_result", "ok"))
	}
	di "  TWFE: `t_status' | bins `t_nb' | N `t_n' | stat " %6.3f `t_stat' " | p " %6.4f `t_p'

	* ── FD test, same knots ──────────────────────────────────────────────────
	local f_stat = .
	local f_p    = .
	local f_nb   = .
	local f_n    = .
	local f_status "not_run"
	if "`knots'" != "" {
		ereturn clear
		capture noisily binstest `outcome'_fd `conn' `W' ///
			if did_firm == 1 & year == 2009 & !missing(`outcome'_fd), ///
			testmodelpoly(1) deriv(1) binspos(`knots') ///
			nsims(2000) simsgrid(50) simsseed(12345) vce(robust)
		local rc = _rc
		if `rc' == 0 {
			capture local f_stat = e(stat_poly)
			capture local f_p    = e(pval_poly)
			capture local f_nb   = e(nbins)
			capture local f_n    = e(N)
		}
		local f_status = cond(`rc' != 0, "error", cond(missing(`f_stat'), "no_result", "ok"))
	}
	di "  FD:   `f_status' | bins `f_nb' | N `f_n' | stat " %6.3f `f_stat' " | p " %6.4f `f_p'

	file open `fh' using "`csv'", write append
	file write `fh' "`outcome',`b_did',`se_did',`n_did',`g_did',`J',`j_method',`n_knots',"
	file write `fh' "`t_status',`t_nb',`t_n',`t_g',`t_stat',`t_p',"
	file write `fh' "`f_status',`f_nb',`f_n',`f_stat',`f_p'" _n
	file close `fh'
}

di _newline "======================================================="
di "TWFE vs FD LINEARITY TESTS (identical bins)"
di "======================================================="
type "`csv'"

di "Finished: `c(current_date)' `c(current_time)'"
capture log close

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && ///
	notify "3172_linearity_fd done" "TWFE vs FD linearity tests complete"
