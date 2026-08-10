********************************************************************************
* Program:  es_mincer.do
* Purpose:  Event study plots for Mincer-residualized log December wages.
*           Produces year-by-year DiD coefficients for:
*             (1) Direct effect — Panel A (treated vs zero-connectivity controls)
*             (2) Spillover effect (connectivity × year interactions)
*           Saves coefficients + metadata to CSVs, then calls Python to plot.
* Outcome:  lr_remdezr_resid only (no hourly wage)
* Date:     2026-03-19
********************************************************************************

version 17.0
clear all
set more off
set varabbrev off

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/residuals/es_mincer_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"

********************************************************************************
* SECTION 1: DATA SETUP (mirrors 4112_mincer.do)
********************************************************************************

* ── Load main firm-year dataset ──────────────────────────────────────────────

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

* ── Merge Mincer residuals ────────────────────────────────────────────────────

preserve
	import delimited "$rais_firm/mincer_residuals_firm_year.csv", clear
	tostring identificad, replace format(%014.0f) force
	keep identificad year lr_remdezr_resid
	tempfile mincer
	save `mincer'
restore

merge 1:1 identificad year using `mincer', keep(master match) nogen
label var lr_remdezr_resid "Mincer-residualized log December wage"

* ── Merge totalflows data ────────────────────────────────────────────────────

preserve
	import delimited "$rais_aux/totalflows_wide_2007_2011.csv", clear
	tostring identificad, replace format(%014.0f) force
	tempfile totalflows_wide
	save `totalflows_wide'
restore

merge m:1 identificad using `totalflows_wide', keep(master match) nogen

gen double totalflows_pw_pre_07_11     = 0
gen        totalflows_pw_pre_07_11_cnt = 0
foreach yp in totalflows_pw_07_08 totalflows_pw_08_09 totalflows_pw_09_10 totalflows_pw_10_11 {
	replace totalflows_pw_pre_07_11     = totalflows_pw_pre_07_11 + `yp'    if !missing(`yp')
	replace totalflows_pw_pre_07_11_cnt = totalflows_pw_pre_07_11_cnt + (!missing(`yp'))
}
replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 / totalflows_pw_pre_07_11_cnt ///
	if totalflows_pw_pre_07_11_cnt > 0
replace totalflows_pw_pre_07_11 = . if totalflows_pw_pre_07_11_cnt == 0
drop totalflows_pw_pre_07_11_cnt

* ── Sample restrictions ───────────────────────────────────────────────────────

keep if year >= 2009
keep if lagos_sample_avg == 1

********************************************************************************
* SECTION 2: VARIABLE CREATION
********************************************************************************

* ── Treatment indicators ──────────────────────────────────────────────────────

cap drop placebo_year
gen byte placebo_year = (year < 2011)

cap drop treat_year
gen byte treat_year = (year >= 2012)

* ── Connectivity scaling ──────────────────────────────────────────────────────

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen totaltreat_pw_n_p90 = r(p90)
gen totaltreat_pw_norm  = (totaltreat_pw_n / totaltreat_pw_n_p90)
label var totaltreat_pw_norm "Connectivity scaled to 90th pctile among untreated firms"

* ── Pre-treatment means ───────────────────────────────────────────────────────

cap drop firm_emp_pre_o
cap drop firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre   = min(firm_emp_pre_o)
	drop firm_emp_pre_o
}

cap drop l_firm_emp_pre
gen double l_firm_emp_pre = ln(firm_emp_pre)

cap drop lr_remdezr_resid_pre_o
cap drop lr_remdezr_resid_pre
quietly {
	bys identificad: egen lr_remdezr_resid_pre_o = mean(lr_remdezr_resid) if inrange(year, 2009, 2011)
	bys identificad: egen lr_remdezr_resid_pre   = min(lr_remdezr_resid_pre_o)
	drop lr_remdezr_resid_pre_o
}

* ── 4-bin controls ───────────────────────────────────────────────────────────

cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
quietly {
	egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
	drop l_firm_emp_pre4_o
}

cap drop lr_remdezr_resid_pre4_o
cap drop lr_remdezr_resid_pre4
quietly {
	egen lr_remdezr_resid_pre4_o = cut(lr_remdezr_resid_pre) ///
		if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen lr_remdezr_resid_pre4 = min(lr_remdezr_resid_pre4_o)
	drop lr_remdezr_resid_pre4_o
	replace lr_remdezr_resid_pre4 = 0 if missing(lr_remdezr_resid_pre4)
}

* lr_remdezr_w pre-treatment mean and bins (raw log December wage)
cap drop lr_remdezr_w_pre_o
cap drop lr_remdezr_w_pre
quietly {
	bys identificad: egen lr_remdezr_w_pre_o = mean(lr_remdezr_w) if inrange(year, 2009, 2011)
	bys identificad: egen lr_remdezr_w_pre   = min(lr_remdezr_w_pre_o)
	drop lr_remdezr_w_pre_o
}

cap drop lr_remdezr_w_pre4_o
cap drop lr_remdezr_w_pre4
quietly {
	egen lr_remdezr_w_pre4_o = cut(lr_remdezr_w_pre) ///
		if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen lr_remdezr_w_pre4 = min(lr_remdezr_w_pre4_o)
	drop lr_remdezr_w_pre4_o
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
* SECTION 3: SPEC MACROS
********************************************************************************

local outcome    "lr_remdezr_resid"
local conn       "totaltreat_pw_norm"
local base_fe    "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local extra_year "ib0.totalflows_pw_pre_07_114#i.year"
local absorb     "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

local s_direct_A "(treat_ultra==0 & totaltreat_pw_n==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_direct_A_pre "treat_ultra==0 & totaltreat_pw_n==0 & lagos_sample_avg==1 & in_balanced_panel==1"
local s_spill    "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

* Save working dataset so we can restore it between sections
tempfile main_data
save `main_data'

********************************************************************************
* SECTION 4: EVENT STUDY — DIRECT EFFECTS (PANEL A)
********************************************************************************

di _newline(2) as result "=== DIRECT EFFECTS (Panel A) event study ==="

* Full event study regression (ib2011 = base year)
reghdfe `outcome' i.treat_ultra##ib2011.year if `s_direct_A', ///
	absorb(`absorb') vce(cluster identificad)

* Pre-trend F-test (years 2009, 2010)
capture testparm 1.treat_ultra#i(2009 2010).year
local pre_pval = cond(_rc == 0, r(p), .)
local n_obs    = e(N)
local n_estab  = e(N_clust)

* Post-treatment DiD (for annotation)
reghdfe `outcome' treat_ultra##i.treat_year if `s_direct_A', ///
	absorb(`absorb') vce(cluster identificad)
local b_post  = _b[1.treat_ultra#1.treat_year]
local se_post = _se[1.treat_ultra#1.treat_year]

* Baseline mean (untreated control, 2009-2011)
quietly sum `outcome' if `s_direct_A_pre' & inrange(year, 2009, 2011)
local mean_pre = r(mean)

* Re-run event study to recover stored estimates
reghdfe `outcome' i.treat_ultra##ib2011.year if `s_direct_A', ///
	absorb(`absorb') vce(cluster identificad)

* Save year-by-year coefficients to CSV
tempname ph
tempfile pf
postfile `ph' year coef se ci_lo ci_hi using `pf'

foreach yr in 2009 2010 2012 2013 2014 2015 2016 {
	local b  = _b[1.treat_ultra#`yr'.year]
	local se = _se[1.treat_ultra#`yr'.year]
	post `ph' (`yr') (`b') (`se') (`b' - 1.96*`se') (`b' + 1.96*`se')
}
* Base year 2011 = 0 by normalization
post `ph' (2011) (0) (0) (0) (0)

postclose `ph'
use `pf', clear
sort year
export delimited "$tables/residuals/es_mincer_direct_coefs.csv", replace

* Save scalars to metadata CSV
tempname mh
tempfile mf
postfile `mh' str30 key double val using `mf'
post `mh' ("pre_pval")  (`pre_pval')
post `mh' ("post_coef") (`b_post')
post `mh' ("post_se")   (`se_post')
post `mh' ("n_obs")     (`n_obs')
post `mh' ("n_estab")   (`n_estab')
post `mh' ("mean_pre")  (`mean_pre')
postclose `mh'
use `mf', clear
export delimited "$tables/residuals/es_mincer_direct_meta.csv", replace

di as result "Direct event study saved."

* Restore main dataset for spillover section
use `main_data', clear

********************************************************************************
* SECTION 5: EVENT STUDY — SPILLOVER
********************************************************************************

di _newline(2) as result "=== SPILLOVER event study ==="

* Full event study regression
reghdfe `outcome' c.`conn'##ib2011.year if `s_spill', ///
	absorb(`absorb') vce(cluster identificad)

capture testparm c.`conn'#i(2009 2010).year
local pre_pval_sp = cond(_rc == 0, r(p), .)
local n_obs_sp    = e(N)
local n_estab_sp  = e(N_clust)

* Post-treatment DiD (for annotation)
reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
	absorb(`absorb') vce(cluster identificad)
local b_post_sp  = _b[1.treat_year#c.`conn']
local se_post_sp = _se[1.treat_year#c.`conn']

* Baseline mean (spillover sample, 2009-2011)
quietly sum `outcome' if `s_spill' & inrange(year, 2009, 2011)
local mean_pre_sp = r(mean)

* Re-run event study to recover stored estimates
reghdfe `outcome' c.`conn'##ib2011.year if `s_spill', ///
	absorb(`absorb') vce(cluster identificad)

* Save year-by-year coefficients
tempname ph2
tempfile pf2
postfile `ph2' year coef se ci_lo ci_hi using `pf2'

foreach yr in 2009 2010 2012 2013 2014 2015 2016 {
	local b  = _b[`yr'.year#c.`conn']
	local se = _se[`yr'.year#c.`conn']
	post `ph2' (`yr') (`b') (`se') (`b' - 1.96*`se') (`b' + 1.96*`se')
}
post `ph2' (2011) (0) (0) (0) (0)

postclose `ph2'
use `pf2', clear
sort year
export delimited "$tables/residuals/es_mincer_spill_coefs.csv", replace

* Save metadata
tempname mh2
tempfile mf2
postfile `mh2' str30 key double val using `mf2'
post `mh2' ("pre_pval")  (`pre_pval_sp')
post `mh2' ("post_coef") (`b_post_sp')
post `mh2' ("post_se")   (`se_post_sp')
post `mh2' ("n_obs")     (`n_obs_sp')
post `mh2' ("n_estab")   (`n_estab_sp')
post `mh2' ("mean_pre")  (`mean_pre_sp')
postclose `mh2'
use `mf2', clear
export delimited "$tables/residuals/es_mincer_spill_meta.csv", replace

di as result "Spillover event study saved."

********************************************************************************
* SECTION 6: EVENT STUDY — RAW WAGE (lr_remdezr_w), DIRECT (PANEL A)
********************************************************************************

use `main_data', clear

di _newline(2) as result "=== RAW WAGE — DIRECT (Panel A) event study ==="

local outcome_raw "lr_remdezr_w"
local absorb_raw  "`base_fe' ib0.`outcome_raw'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

reghdfe `outcome_raw' i.treat_ultra##ib2011.year if `s_direct_A', ///
	absorb(`absorb_raw') vce(cluster identificad)

capture testparm 1.treat_ultra#i(2009 2010).year
local pre_pval_rd = cond(_rc == 0, r(p), .)
local n_obs_rd    = e(N)
local n_estab_rd  = e(N_clust)

reghdfe `outcome_raw' treat_ultra##i.treat_year if `s_direct_A', ///
	absorb(`absorb_raw') vce(cluster identificad)
local b_post_rd  = _b[1.treat_ultra#1.treat_year]
local se_post_rd = _se[1.treat_ultra#1.treat_year]

quietly sum `outcome_raw' if `s_direct_A_pre' & inrange(year, 2009, 2011)
local mean_pre_rd = r(mean)

reghdfe `outcome_raw' i.treat_ultra##ib2011.year if `s_direct_A', ///
	absorb(`absorb_raw') vce(cluster identificad)

tempname ph3
tempfile pf3
postfile `ph3' year coef se ci_lo ci_hi using `pf3'
foreach yr in 2009 2010 2012 2013 2014 2015 2016 {
	local b  = _b[1.treat_ultra#`yr'.year]
	local se = _se[1.treat_ultra#`yr'.year]
	post `ph3' (`yr') (`b') (`se') (`b' - 1.96*`se') (`b' + 1.96*`se')
}
post `ph3' (2011) (0) (0) (0) (0)
postclose `ph3'
use `pf3', clear
sort year
export delimited "$tables/residuals/es_mincer_raw_direct_coefs.csv", replace

tempname mh3
tempfile mf3
postfile `mh3' str30 key double val using `mf3'
post `mh3' ("pre_pval")  (`pre_pval_rd')
post `mh3' ("post_coef") (`b_post_rd')
post `mh3' ("post_se")   (`se_post_rd')
post `mh3' ("n_obs")     (`n_obs_rd')
post `mh3' ("n_estab")   (`n_estab_rd')
post `mh3' ("mean_pre")  (`mean_pre_rd')
postclose `mh3'
use `mf3', clear
export delimited "$tables/residuals/es_mincer_raw_direct_meta.csv", replace

di as result "Raw wage direct event study saved."

********************************************************************************
* SECTION 7: EVENT STUDY — RAW WAGE (lr_remdezr_w), SPILLOVER
********************************************************************************

use `main_data', clear

di _newline(2) as result "=== RAW WAGE — SPILLOVER event study ==="

reghdfe `outcome_raw' c.`conn'##ib2011.year if `s_spill', ///
	absorb(`absorb_raw') vce(cluster identificad)

capture testparm c.`conn'#i(2009 2010).year
local pre_pval_rs = cond(_rc == 0, r(p), .)
local n_obs_rs    = e(N)
local n_estab_rs  = e(N_clust)

reghdfe `outcome_raw' c.`conn'##i.treat_year if `s_spill', ///
	absorb(`absorb_raw') vce(cluster identificad)
local b_post_rs  = _b[1.treat_year#c.`conn']
local se_post_rs = _se[1.treat_year#c.`conn']

quietly sum `outcome_raw' if `s_spill' & inrange(year, 2009, 2011)
local mean_pre_rs = r(mean)

reghdfe `outcome_raw' c.`conn'##ib2011.year if `s_spill', ///
	absorb(`absorb_raw') vce(cluster identificad)

tempname ph4
tempfile pf4
postfile `ph4' year coef se ci_lo ci_hi using `pf4'
foreach yr in 2009 2010 2012 2013 2014 2015 2016 {
	local b  = _b[`yr'.year#c.`conn']
	local se = _se[`yr'.year#c.`conn']
	post `ph4' (`yr') (`b') (`se') (`b' - 1.96*`se') (`b' + 1.96*`se')
}
post `ph4' (2011) (0) (0) (0) (0)
postclose `ph4'
use `pf4', clear
sort year
export delimited "$tables/residuals/es_mincer_raw_spill_coefs.csv", replace

tempname mh4
tempfile mf4
postfile `mh4' str30 key double val using `mf4'
post `mh4' ("pre_pval")  (`pre_pval_rs')
post `mh4' ("post_coef") (`b_post_rs')
post `mh4' ("post_se")   (`se_post_rs')
post `mh4' ("n_obs")     (`n_obs_rs')
post `mh4' ("n_estab")   (`n_estab_rs')
post `mh4' ("mean_pre")  (`mean_pre_rs')
postclose `mh4'
use `mf4', clear
export delimited "$tables/residuals/es_mincer_raw_spill_meta.csv", replace

di as result "Raw wage spillover event study saved."

********************************************************************************
* SECTION 8: CALL PYTHON TO PLOT
********************************************************************************

log close

shell ~/.conda/envs/venv_python312/bin/python "$programs/residuals/es_mincer_plot.py"
shell ~/.conda/envs/venv_python312/bin/python "$programs/residuals/es_mincer_overlay_plot.py"

shell source "$programs/notify.sh" && notify "es_mincer done" "Event study plots complete"

********************************************************************************
* END
********************************************************************************
