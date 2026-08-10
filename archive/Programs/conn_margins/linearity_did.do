/*
================================================================================
linearity_did.do — Panel DiD linearity defense (NCA-style)
Cattaneo, Crump, Farrell, Feng (2024)

Tests whether the IDENTIFYING relationship used in the main continuous DiD spec
(conn_margins.do, Exercise 2) is adequately approximated by a linear function of
treatment intensity, after removing exactly the variation used for identification.

Main spec being defended (conn_margins.do, Ex2, intensive margin):
    reghdfe Y c.totaltreat_pw_norm##i.treat_year if `s_spill_pos',
        absorb(base_fe + Y_pre4#year + l_firm_emp_pre4#year + extra_year)
        vce(cluster identificad)

  The linear DiD imposes  E[Y | D, FE, X] = beta * D,   D = Conn x Post.
  We test linearity of  E[Ytilde | Dtilde]  where ~ denotes FWL residualization
  on the SAME firm FE + year/x-year FE + controls and the i.treat_year main effect.

Because of the ~4,000 firm fixed effects, the Cattaneo internal-w covariate
adjustment is infeasible (cannot pass 4k firm dummies as w), so we residualize
both Y and D via reghdfe (FWL) and run binstest on the residuals — exactly the
procedure used in the NCA enforceability paper.

PART A: pooled residualized linearity test (binstest) + residual scatter export
PART B: linear vs binned (nonparametric-in-connectivity) event study

Sample: s_spill_pos  (lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1
        & totaltreat_pw_n>0) — the intensive-margin / dose-response sample.

Outputs (Tables/conn_margins/):
  linearity_did_test.csv               pooled binstest results (4 outcomes)
  linearity_did_resid_<outcome>.csv    residualized (yres,dres) for the figure
  linearity_did_es_linear_<outcome>.csv   continuous event-study coefs
  linearity_did_es_binned_<outcome>.csv   binned event-study coefs (bin x year)
  linearity_did_dose_<outcome>.csv        pooled binned post-effects + linear beta
================================================================================
*/

version 17.0
set more off
set varabbrev off

* ── Paths ─────────────────────────────────────────────────────────────────────

global main      "/kellogg/proj/lgg3230/UnionSpill"
global rais_firm "$main/Data/CBA_RAIS_firm_level"
global rais_aux  "$main/Data/RAIS_aux"
global tables    "$main/Tables"
global logs      "$main/Logs"

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
cap mkdir "$logs/conn_margins"
log using "$logs/conn_margins/linearity_did_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"

cap which binstest
if _rc != 0 {
	di "Installing binsreg from SSC..."
	ssc install binsreg, replace
}

* ── Load data ─────────────────────────────────────────────────────────────────

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

* ── Merge totalflows ─────────────────────────────────────────────────────────

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

* ── Variable creation (mirrors conn_margins.do Ex2) ───────────────────────────

local s_spill     "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"
local s_spill_pos "`s_spill' & totaltreat_pw_n > 0"

* Numeric firm ID for clustering in binstest (no string clusters allowed)
cap drop firm_num
encode identificad, gen(firm_num)

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

* Connectivity scaling (p90 among spillover sample in 2009)
cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen double totaltreat_pw_n_p90 = r(p90)
gen double totaltreat_pw_norm  = totaltreat_pw_n / totaltreat_pw_n_p90

* Running variables: D = connectivity x post indicator
cap drop conn_x_post
cap drop conn_x_post_cba
gen double conn_x_post     = totaltreat_pw_norm * treat_year
gen double conn_x_post_cba = totaltreat_pw_norm * post_treat_cba

* Pre-treatment employment mean
cap drop firm_emp_pre_o
cap drop firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre   = min(firm_emp_pre_o)
	drop firm_emp_pre_o
}

* Pre-treatment outcome means
foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {
	cap drop `outcome'_pre_o
	cap drop `outcome'_pre
	quietly {
		bys identificad: egen `outcome'_pre_o = mean(`outcome') if inrange(year, 2009, 2011)
		bys identificad: egen `outcome'_pre   = min(`outcome'_pre_o)
		drop `outcome'_pre_o
	}
}

cap drop l_firm_emp_pre
gen double l_firm_emp_pre = ln(firm_emp_pre)

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

* Time-invariant firm connectivity + quintile bins (positive-conn sample)
cap drop conn_firm_b
bys identificad: egen conn_firm_b = mean(totaltreat_pw_norm) if `s_spill_pos'
cap drop conn_q
cap drop connbin
quietly {
	xtile conn_q = conn_firm_b if `s_spill_pos' & year == 2009, nq(5)
	bys identificad: egen connbin = min(conn_q)
}

* ── FE macros (mirror conn_margins.do exactly) ───────────────────────────────

local base_fe     "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local extra_year  "ib0.totalflows_pw_pre_07_114#i.year"
local base_fe_cba "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period"
local extra_cba   "ib0.totalflows_pw_pre_07_114#i.cba_period"

local conn "totaltreat_pw_norm"

********************************************************************************
* PART A — SUPERSEDED
*
* The pooled residualized binstest that used to live here pre-residualized the
* outcome and the treatment before binning, which is exactly the distortion
* Cattaneo et al. (2024, "Problem 1") warn against. It has been replaced by the
* validated first-difference test in  linearity_did_fd.do, which passes the
* controls to binsreg/binstest INTERNALLY (no pre-residualization) on the
* firm-level first-difference cross-section. See linearity_did_notes_fd.md.
*
* Only PART B (event study) remains in this file.
********************************************************************************

********************************************************************************
* PART B — LINEAR vs BINNED (NONPARAMETRIC-IN-CONNECTIVITY) EVENT STUDY
*   Calendar-year outcomes only (numb_clauses uses CBA-period structure).
********************************************************************************

foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {

	di _newline "============================================================"
	di "PART B event study: `outcome'"
	di "============================================================"

	local absorb "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

	* ── (1) Linear continuous event study (reference year 2011) ──────────────
	reghdfe `outcome' c.`conn'##ib2011.year if `s_spill_pos', ///
		absorb(`absorb') vce(cluster identificad)

	tempname fl
	file open `fl' using "$tables/conn_margins/linearity_did_es_linear_`outcome'.csv", write replace
	file write `fl' "year,coef,se" _n
	foreach yr in 2009 2010 2011 2012 2013 2014 2015 2016 {
		if `yr' == 2011 {
			file write `fl' "`yr',0,0" _n
		}
		else {
			local b  = _b[`yr'.year#c.`conn']
			local se = _se[`yr'.year#c.`conn']
			file write `fl' "`yr',`b',`se'" _n
		}
	}
	file close `fl'

	* ── (2) Binned event study: ib1.connbin x year (bin 1 & 2011 reference) ──
	reghdfe `outcome' ib1.connbin##ib2011.year if `s_spill_pos', ///
		absorb(`absorb') vce(cluster identificad)

	tempname fb
	file open `fb' using "$tables/conn_margins/linearity_did_es_binned_`outcome'.csv", write replace
	file write `fb' "bin,year,coef,se" _n
	forval b = 2/5 {
		foreach yr in 2009 2010 2011 2012 2013 2014 2015 2016 {
			if `yr' == 2011 {
				file write `fb' "`b',`yr',0,0" _n
			}
			else {
				local cf = _b[`b'.connbin#`yr'.year]
				local sf = _se[`b'.connbin#`yr'.year]
				file write `fb' "`b',`yr',`cf',`sf'" _n
			}
		}
	}
	file close `fb'

	* ── (3) Pooled binned post-effects + linear slope, for dose-response plot ─
	* Continuous pooled DiD slope (the linear restriction)
	reghdfe `outcome' c.`conn'##i.treat_year if `s_spill_pos', ///
		absorb(`absorb') vce(cluster identificad)
	local beta_lin = _b[1.treat_year#c.`conn']
	local se_lin   = _se[1.treat_year#c.`conn']

	* Binned pooled DiD: post-effect per bin relative to bin 1
	reghdfe `outcome' ib1.connbin##i.treat_year if `s_spill_pos', ///
		absorb(`absorb') vce(cluster identificad)

	tempname fd
	file open `fd' using "$tables/conn_margins/linearity_did_dose_`outcome'.csv", write replace
	file write `fd' "bin,conn_mean,theta,se,beta_lin,se_lin" _n
	forval b = 1/5 {
		quietly sum conn_firm_b if connbin == `b' & year == 2009 & `s_spill_pos'
		local cm = r(mean)
		if `b' == 1 {
			file write `fd' "`b',`cm',0,0,`beta_lin',`se_lin'" _n
		}
		else {
			local th = _b[`b'.connbin#1.treat_year]
			local st = _se[`b'.connbin#1.treat_year]
			file write `fd' "`b',`cm',`th',`st',`beta_lin',`se_lin'" _n
		}
	}
	file close `fd'

	di as result "  Part B `outcome' done."
}

* ── Summary ───────────────────────────────────────────────────────────────────

di _newline "======================================================="
di "LINEARITY DID RESULTS"
di "See: $tables/conn_margins/linearity_did_test.csv"
di "======================================================="
type "$tables/conn_margins/linearity_did_test.csv"

capture log close

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && ///
	notify "linearity_did done" "Part A binstest + Part B binned event study complete"
