/*
================================================================================
linearity_did_poly.do — Polynomial linearity test for the spillover DiD

Alternative to the Cattaneo et al. (2024) sup-norm binstest. Augments the
headline spillover DiD (Main_Results PART D / conn_margins) with quadratic and
cubic terms in connectivity (each interacted with Post), then reports a joint
F-test that the quadratic AND cubic coefficients are jointly zero. Failure to
reject supports the linear functional form.

Headline spec (per outcome), reproduced EXACTLY from Main_Results PART D:
  Calendar outcomes (lr_remdezr_w, lr_remdezr_h_w, l_firm_emp):
    reghdfe Y c.conn##i.treat_year , absorb(base_fe + pre4 bins + extra_year)
                                     vce(cluster identificad)   on s_spill
  numb_clauses (CBA-period structure):
    reghdfe numb_clauses c.conn##post_treat_cba , absorb(base_fe_cba + ...)

Polynomial augmentation adds, for the SAME Post interaction:
    + Post#c.conn#c.conn          (quadratic)
    + Post#c.conn#c.conn#c.conn   (cubic)
Joint test: H0 quad = cube = 0  (linear functional form).

conn = totaltreat_pw_norm (raw, scaled to p90 of the spillover sample in 2009).

Data prep (load, totalflows merge, connectivity scaling, pre4 bin controls) is
copied verbatim from linearity_did_fd.do so the linear term reproduces the
published spillover coefficient by construction.

Output (Tables/conn_margins/):
  linearity_did_poly_test.csv   long format: outcome, row_type, value
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
log using "$logs/conn_margins/linearity_did_poly_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"

* ── Load + merge totalflows (copied from linearity_did_fd.do) ─────────────────

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

* Connectivity scaling (p90 among spillover sample in 2009)
cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen double totaltreat_pw_n_p90 = r(p90)
gen double totaltreat_pw_norm  = totaltreat_pw_n / totaltreat_pw_n_p90

* Powers of connectivity (for the polynomial DiD)
cap drop conn2
cap drop conn3
gen double conn2 = totaltreat_pw_norm^2
gen double conn3 = totaltreat_pw_norm^3

* Pre-treatment employment mean -> log(mean) for the BIN control
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

* ── FE / spec macros (mirror Main_Results PART D) ─────────────────────────────

local base_fe     "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local base_fe_cba "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period"
local extra_year  "ib0.totalflows_pw_pre_07_114#i.year"
local extra_cba   "ib0.totalflows_pw_pre_07_114#i.cba_period"

* ── Output CSV ────────────────────────────────────────────────────────────────

cap mkdir "$tables/conn_margins"
local csv "$tables/conn_margins/linearity_did_poly_test.csv"
capture erase "`csv'"
tempname fh
file open `fh' using "`csv'", write replace
file write `fh' "outcome,row_type,value" _n
file close `fh'

* ── Helper program: write one key,value row ───────────────────────────────────

capture program drop _wr
program define _wr
	args csv outcome row_type value fmt
	if "`fmt'" == "" local fmt "%12.6f"
	tempname fh
	file open `fh' using "`csv'", write append
	file write `fh' `""`outcome'","`row_type'","' `fmt' (`value') _n
	file close `fh'
end

********************************************************************************
* PART 1 — Calendar outcomes (treat_year Post)
********************************************************************************

foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {

	di _newline(1)
	di as result "=== Polynomial DiD: `outcome' ==="

	local absorb "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

	* Linear-only headline (reference) ----------------------------------------
	reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
		absorb(`absorb') vce(cluster identificad)
	local b_lin0  = _b[1.treat_year#c.`conn']
	local se_lin0 = _se[1.treat_year#c.`conn']

	* Polynomial spec ----------------------------------------------------------
	* Explicit Post interactions (factor notation would also build the pre-period
	* power terms, which are collinear with the firm FE and get omitted).
	cap drop conn_post
	cap drop conn2_post
	cap drop conn3_post
	gen double conn_post  = `conn' * treat_year
	gen double conn2_post = conn2  * treat_year
	gen double conn3_post = conn3  * treat_year

	reghdfe `outcome' conn_post conn2_post conn3_post ///
		if `s_spill', absorb(`absorb') vce(cluster identificad)

	local b_lin   = _b[conn_post]
	local se_lin  = _se[conn_post]
	local b_quad  = _b[conn2_post]
	local se_quad = _se[conn2_post]
	local b_cube  = _b[conn3_post]
	local se_cube = _se[conn3_post]
	local n_obs   = e(N)
	local n_estab = e(N_clust)

	* Joint F-test: quad = cube = 0 -------------------------------------------
	test conn2_post conn3_post
	local jF  = r(F)
	local jdf = r(df)
	local jp  = r(p)

	di as text "  linear (poly)   = " %9.5f `b_lin'  "  (" %9.5f `se_lin'  ")"
	di as text "  linear (only)   = " %9.5f `b_lin0' "  (" %9.5f `se_lin0' ")"
	di as text "  quadratic       = " %9.5f `b_quad' "  (" %9.5f `se_quad' ")"
	di as text "  cubic           = " %9.5f `b_cube' "  (" %9.5f `se_cube' ")"
	di as text "  joint F(" `jdf' ", .)  = " %7.3f `jF' "   p = " %6.4f `jp'

	_wr "`csv'" "`outcome'" "b_lin0"   `b_lin0'
	_wr "`csv'" "`outcome'" "se_lin0"  `se_lin0'
	_wr "`csv'" "`outcome'" "b_lin"    `b_lin'
	_wr "`csv'" "`outcome'" "se_lin"   `se_lin'
	_wr "`csv'" "`outcome'" "b_quad"   `b_quad'
	_wr "`csv'" "`outcome'" "se_quad"  `se_quad'
	_wr "`csv'" "`outcome'" "b_cube"   `b_cube'
	_wr "`csv'" "`outcome'" "se_cube"  `se_cube'
	_wr "`csv'" "`outcome'" "joint_F"  `jF'
	_wr "`csv'" "`outcome'" "joint_df" `jdf' "%6.0f"
	_wr "`csv'" "`outcome'" "joint_p"  `jp'
	_wr "`csv'" "`outcome'" "n_obs"    `n_obs'   "%14.0f"
	_wr "`csv'" "`outcome'" "n_estab"  `n_estab' "%14.0f"
}

********************************************************************************
* PART 2 — numb_clauses (CBA-period Post)
********************************************************************************

capture confirm variable numb_clauses
if _rc == 0 {

	di _newline(1)
	di as result "=== Polynomial DiD: numb_clauses (CBA periods) ==="

	local absorb_cba "`base_fe_cba' ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

	* Linear-only headline (reference) ----------------------------------------
	reghdfe numb_clauses c.`conn'##post_treat_cba ///
		if `s_spill' & !missing(cba_period), ///
		absorb(`absorb_cba') vce(cluster identificad)
	local b_lin0  = _b[1.post_treat_cba#c.`conn']
	local se_lin0 = _se[1.post_treat_cba#c.`conn']

	* Polynomial spec ----------------------------------------------------------
	cap drop conn_postc
	cap drop conn2_postc
	cap drop conn3_postc
	gen double conn_postc  = `conn' * post_treat_cba
	gen double conn2_postc = conn2  * post_treat_cba
	gen double conn3_postc = conn3  * post_treat_cba

	reghdfe numb_clauses conn_postc conn2_postc conn3_postc ///
		if `s_spill' & !missing(cba_period), ///
		absorb(`absorb_cba') vce(cluster identificad)

	local b_lin   = _b[conn_postc]
	local se_lin  = _se[conn_postc]
	local b_quad  = _b[conn2_postc]
	local se_quad = _se[conn2_postc]
	local b_cube  = _b[conn3_postc]
	local se_cube = _se[conn3_postc]
	local n_obs   = e(N)
	local n_estab = e(N_clust)

	test conn2_postc conn3_postc
	local jF  = r(F)
	local jdf = r(df)
	local jp  = r(p)

	di as text "  linear (poly)   = " %9.5f `b_lin'  "  (" %9.5f `se_lin'  ")"
	di as text "  linear (only)   = " %9.5f `b_lin0' "  (" %9.5f `se_lin0' ")"
	di as text "  quadratic       = " %9.5f `b_quad' "  (" %9.5f `se_quad' ")"
	di as text "  cubic           = " %9.5f `b_cube' "  (" %9.5f `se_cube' ")"
	di as text "  joint F(" `jdf' ", .)  = " %7.3f `jF' "   p = " %6.4f `jp'

	_wr "`csv'" "numb_clauses" "b_lin0"   `b_lin0'
	_wr "`csv'" "numb_clauses" "se_lin0"  `se_lin0'
	_wr "`csv'" "numb_clauses" "b_lin"    `b_lin'
	_wr "`csv'" "numb_clauses" "se_lin"   `se_lin'
	_wr "`csv'" "numb_clauses" "b_quad"   `b_quad'
	_wr "`csv'" "numb_clauses" "se_quad"  `se_quad'
	_wr "`csv'" "numb_clauses" "b_cube"   `b_cube'
	_wr "`csv'" "numb_clauses" "se_cube"  `se_cube'
	_wr "`csv'" "numb_clauses" "joint_F"  `jF'
	_wr "`csv'" "numb_clauses" "joint_df" `jdf' "%6.0f"
	_wr "`csv'" "numb_clauses" "joint_p"  `jp'
	_wr "`csv'" "numb_clauses" "n_obs"    `n_obs'   "%14.0f"
	_wr "`csv'" "numb_clauses" "n_estab"  `n_estab' "%14.0f"
}

di _newline(1)
di as result "Done. Results -> `csv'"

capture log close

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "Stata done" "linearity_did_poly.do finished"
