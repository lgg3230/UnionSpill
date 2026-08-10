/*
================================================================================
linearity_did_fd_cba_match.do — retrieve the 0.0180 clause spillover slope
with a weighted first difference.

The two-way FE DiD with treatment c_i * post_it (post binary) equals a WEIGHTED
OLS of the firm-level difference dY_i = mean(Y|post) - mean(Y|pre) on c_i, with
weight  w_i = n_pre,i * n_post,i / (n_pre,i + n_post,i)  (the within-firm variance
of the post indicator). For the balanced wage/employment panels w_i is constant,
so the unweighted FD matched exactly. The clause panel is unbalanced (n_post
varies), so the unweighted FD is off and the weighted FD should recover the slope.

Mirrors 4012_pct_tfpw.do PART D numb_clauses spillover (line ~657):
  reghdfe numb_clauses c.conn##post_treat_cba if s_spill & !missing(cba_period),
      absorb(firm + group#cba_period + bins#cba_period) vce(cluster identificad)
================================================================================
*/

version 17.0
set more off
set varabbrev off

global main      "/kellogg/proj/lgg3230/UnionSpill"
global rais_firm "$main/Data/CBA_RAIS_firm_level"
global rais_aux  "$main/Data/RAIS_aux"
global logs      "$main/Logs"

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/conn_margins/linearity_did_fd_cba_match_`d'_`t'.log", replace text

* ── Load + prep (mirror Main_Results) ─────────────────────────────────────────

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear
preserve
	import delimited "$rais_aux/totalflows_wide_2007_2011.csv", clear
	tostring identificad, replace format(%014.0f) force
	tempfile tf
	save `tf'
restore
merge m:1 identificad using `tf', keep(master match) nogen
gen double totalflows_pw_pre_07_11 = 0
gen tfc = 0
foreach yp in totalflows_pw_07_08 totalflows_pw_08_09 totalflows_pw_09_10 totalflows_pw_10_11 {
	replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 + `yp' if !missing(`yp')
	replace tfc = tfc + (!missing(`yp'))
}
replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11/tfc if tfc>0
replace totalflows_pw_pre_07_11 = . if tfc==0
drop tfc
keep if year >= 2009
keep if lagos_sample_avg == 1

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"
local conn    "totaltreat_pw_norm"

cap drop cba_period
gen cba_period = .
replace cba_period = 1 if avg_file_date == earliest2009_avg - 1 & !missing(avg_file_date)
replace cba_period = 2 if avg_file_date == second_cba_avg        & !missing(avg_file_date)
replace cba_period = 3 if inrange(avg_file_date, mdy(1,1,2013), mdy(12,31,2013)) & cba_period == .
replace cba_period = 4 if inrange(avg_file_date, mdy(1,1,2014), mdy(12,31,2014)) & cba_period == .
replace cba_period = 5 if inrange(avg_file_date, mdy(1,1,2015), mdy(12,31,2015)) & cba_period == .
replace cba_period = 6 if inrange(avg_file_date, mdy(1,1,2016), mdy(12,31,2016)) & cba_period == .
cap drop post_treat_cba
gen byte post_treat_cba = cond(cba_period >= 3, 1, 0) if !missing(cba_period)

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen double totaltreat_pw_n_p90 = r(p90)
gen double totaltreat_pw_norm  = totaltreat_pw_n / totaltreat_pw_n_p90

cap drop firm_emp_pre_o
cap drop firm_emp_pre
cap drop l_firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year,2009,2011)
	bys identificad: egen firm_emp_pre   = min(firm_emp_pre_o)
	drop firm_emp_pre_o
	gen double l_firm_emp_pre = ln(firm_emp_pre)
}
cap drop numb_clauses_pre_o
cap drop numb_clauses_pre
quietly {
	bys identificad: egen numb_clauses_pre_o = mean(numb_clauses) if inrange(cba_period,1,2)
	bys identificad: egen numb_clauses_pre   = min(numb_clauses_pre_o)
	drop numb_clauses_pre_o
}
cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
cap drop numb_clauses_pre4_o
cap drop numb_clauses_pre4
cap drop totalflows_pw_pre_07_114_o
cap drop totalflows_pw_pre_07_114
quietly {
	egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) if year==2009 & in_balanced_panel==1, group(4)
	bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
	drop l_firm_emp_pre4_o
	egen numb_clauses_pre4_o = cut(numb_clauses_pre) if year==2009 & in_balanced_panel==1, group(4)
	bys identificad: egen numb_clauses_pre4 = min(numb_clauses_pre4_o)
	drop numb_clauses_pre4_o
	replace numb_clauses_pre4 = 0 if missing(numb_clauses_pre4)
	egen totalflows_pw_pre_07_114_o = cut(totalflows_pw_pre_07_11) if year==2009 & in_balanced_panel==1, group(4)
	bys identificad: egen totalflows_pw_pre_07_114 = min(totalflows_pw_pre_07_114_o)
	drop totalflows_pw_pre_07_114_o
	replace totalflows_pw_pre_07_114 = 0 if missing(totalflows_pw_pre_07_114)
}

* ── Restrict to the panel's clause sample (firm x year, unchanged) ────────────

keep if `s_spill' & !missing(cba_period) & !missing(numb_clauses)

* ── (0) Reproduce the panel DiD (target ~0.0180) ─────────────────────────────

local base_fe_cba "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period"
local extra_cba   "ib0.totalflows_pw_pre_07_114#i.cba_period"
local absorb_cba  "`base_fe_cba' ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

di _newline "==== (0) PANEL DiD (their spec, firm x year, x cba_period FE) ===="
reghdfe numb_clauses c.`conn'##post_treat_cba if `s_spill' & !missing(cba_period), ///
	absorb(`absorb_cba') vce(cluster identificad)
local b_panel = _b[1.post_treat_cba#c.`conn']
di as result "PANEL beta (target ~0.0180) = " %9.6f `b_panel'

* Same DiD but with PRE/POST-level FEs (2-level) instead of cba_period (6-level).
* A first difference is a 2-period object, so the weighted FD reproduces THIS exactly.
local absorb_pp "identificad i.industry1#i.post_treat_cba i.mode_base_month#i.post_treat_cba i.microregion#i.post_treat_cba ib0.numb_clauses_pre4#i.post_treat_cba ib0.l_firm_emp_pre4#i.post_treat_cba ib0.totalflows_pw_pre_07_114#i.post_treat_cba"
di _newline "==== (0b) PANEL DiD with pre/post-level FEs (2-level) ===="
reghdfe numb_clauses c.`conn'##post_treat_cba if `s_spill' & !missing(cba_period), ///
	absorb(`absorb_pp') vce(cluster identificad)
local b_panel_pp = _b[1.post_treat_cba#c.`conn']
di as result "PANEL (pre/post FE) beta = " %9.6f `b_panel_pp'

* ── Build firm-level first difference + FWL weight ───────────────────────────
* n_pre/n_post = firm-year counts of post_treat_cba 0/1 (the panel's weighting)

cap drop n_pre
cap drop n_post
bys identificad: egen n_pre  = total(post_treat_cba==0)
bys identificad: egen n_post = total(post_treat_cba==1)

cap drop cl_pre_o
cap drop cl_pre
cap drop cl_post_o
cap drop cl_post
quietly {
	bys identificad: egen cl_pre_o  = mean(numb_clauses) if post_treat_cba==0
	bys identificad: egen cl_pre     = min(cl_pre_o)
	drop cl_pre_o
	bys identificad: egen cl_post_o = mean(numb_clauses) if post_treat_cba==1
	bys identificad: egen cl_post    = min(cl_post_o)
	drop cl_post_o
}
cap drop clauses_fd
gen double clauses_fd = cl_post - cl_pre

cap drop w_fwl
gen double w_fwl = (n_pre*n_post)/(n_pre+n_post)

* one row per firm
preserve
	bys identificad: keep if _n == 1

	local Wc "ib0.numb_clauses_pre4 ib0.l_firm_emp_pre4 ib0.totalflows_pw_pre_07_114"
	local Ac "industry1 mode_base_month microregion"

	di _newline "==== (1) UNWEIGHTED first difference ===="
	reghdfe clauses_fd c.`conn' `Wc' if !missing(clauses_fd), absorb(`Ac') vce(robust)
	local b_unw = _b[`conn']
	di as result "UNWEIGHTED FD beta = " %9.6f `b_unw'

	di _newline "==== (2) WEIGHTED first difference  [aw = n_pre*n_post/(n_pre+n_post)] ===="
	reghdfe clauses_fd c.`conn' `Wc' [aw=w_fwl] if !missing(clauses_fd), absorb(`Ac') vce(robust)
	local b_w = _b[`conn']
	di as result "WEIGHTED FD beta = " %9.6f `b_w'

	di _newline "================= COMPARISON ================="
	di as result "panel, cba_period FE (published) = " %9.6f `b_panel'
	di as result "panel, pre/post FE              = " %9.6f `b_panel_pp'
	di as result "unweighted FD                   = " %9.6f `b_unw'
	di as result "weighted FD                     = " %9.6f `b_w'
	di "---- weighted FD vs pre/post-FE panel (should be EXACT) ----"
	di as result "  diff = " %9.2e (`b_panel_pp'-`b_w')
	di "---- weighted FD vs published cba_period-FE panel ----"
	di as result "  diff = " %9.2e (`b_panel'-`b_w')
	di "============================================="
restore

capture log close
shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && ///
	notify "clause match done" "weighted FD vs panel comparison complete"
