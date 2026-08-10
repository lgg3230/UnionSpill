********************************************************************************
* ROBUSTNESS: INDUSTRY × MICROREGION TREATMENT EXPOSURE CONTROLS
* Purpose: Test spillover estimates against local (industry×microregion)
*          treatment exposure confounders.
*
*          FE spec identical to 4012_pct_tfpw.do:
*            absorb = base_fe + outcome_pre4×year + l_firm_emp_pre4×year
*                     + totalflows_pw_pre_07_114×year
*
*          9 specifications:
*            base     – Baseline (no local exposure control)
*            mi_fe_yr – + i.micro_ind × year FE
*            mi_fe_tr – + i.micro_ind × treat_year / placebo_year FE
*            mif_yr   – + c.mi_exp_f_n × year (firm-share exposure, time-varying)
*            mif_tr   – + mi_exp_f_n × treat_year / placebo_year (interacted)
*            mif_tr_b – mi_exp_f_n × treat_year alone (no connectivity)
*            miw_yr   – + c.mi_exp_w_n × year (worker-share exposure, time-varying)
*            miw_tr   – + mi_exp_w_n × treat_year / placebo_year (interacted)
*            miw_tr_b – mi_exp_w_n × treat_year alone (no connectivity)
*
* Output: Tables/robustness/results_micro_ind_test.csv
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/robustness/Main_Results_micro_ind_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
di "Stata version: `c(stata_version)'"

********************************************************************************
* SECTION 1: DATA
********************************************************************************

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

* ── Merge totalflows (per-worker, 2007-2011) ─────────────────────────────────

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
label var totalflows_pw_pre_07_11 "Avg yearly per-worker pairwise flows 2007-2011"

keep if year >= 2009
keep if lagos_sample_avg == 1

di as result "Sample size: " _N

********************************************************************************
* SECTION 2: VARIABLE CREATION
********************************************************************************

* ── Sample definitions ────────────────────────────────────────────────────────

local s_spill    "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"
local s_exposure "lagos_sample_avg==1 & in_balanced_panel==1"

* ── Treatment indicators ──────────────────────────────────────────────────────

cap drop placebo_year
gen byte placebo_year = (year < 2011)
label var placebo_year "Pre-treatment period"

cap drop treat_year
gen byte treat_year = (year >= 2012)
label var treat_year "Post-treatment period"

* ── Connectivity scaled to 90th pctile among untreated firms ─────────────────

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
quietly sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen totaltreat_pw_n_p90 = r(p90)
gen totaltreat_pw_norm  = totaltreat_pw_n / totaltreat_pw_n_p90
label var totaltreat_pw_norm "Connectivity scaled to 90th pctile among untreated firms"

local conn "totaltreat_pw_norm"

* ── Pre-treatment firm employment ────────────────────────────────────────────

cap drop firm_emp_pre_o
cap drop firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre   = min(firm_emp_pre_o)
	drop firm_emp_pre_o
}
label var firm_emp_pre "Pre-treatment firm employment (average 2009-2011)"

cap drop l_firm_emp_pre
gen double l_firm_emp_pre = ln(firm_emp_pre)
label var l_firm_emp_pre "Log pre-treatment firm employment"

* ── Pre-treatment outcome average ────────────────────────────────────────────

local outcome "lr_remdezr_w"

cap drop `outcome'_pre_o
cap drop `outcome'_pre
quietly {
	bys identificad: egen `outcome'_pre_o = mean(`outcome') if inrange(year, 2009, 2011)
	bys identificad: egen `outcome'_pre   = min(`outcome'_pre_o)
	drop `outcome'_pre_o
}

* ── 4-bin quantile controls ───────────────────────────────────────────────────

cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
quietly {
	egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) ///
		if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
	drop l_firm_emp_pre4_o
}

cap drop `outcome'_pre4_o
cap drop `outcome'_pre4
quietly {
	egen `outcome'_pre4_o = cut(`outcome'_pre) ///
		if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen `outcome'_pre4 = min(`outcome'_pre4_o)
	drop `outcome'_pre4_o
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

* ── Industry × microregion cell ──────────────────────────────────────────────

cap drop micro_ind
egen micro_ind = group(microregion industry)
label var micro_ind "Industry × microregion cell indicator"

* ── Local (industry×microregion) exposure measures ───────────────────────────

* Proportion of treated firms in cell
cap drop mi_exp_f
bys micro_ind year: egen mi_exp_f = mean(treat_ultra) if `s_exposure'

* Proportion of workers in treated firms in cell
cap drop mi_workers
cap drop mi_workers_t
cap drop mi_exp_w
bys micro_ind year: egen mi_workers   = total(firm_emp)             if `s_exposure'
bys micro_ind year: egen mi_workers_t = total(firm_emp * treat_ultra) if `s_exposure'
gen mi_exp_w = mi_workers_t / mi_workers

* Normalize to 90th pctile among spillover firms in base year
sum mi_exp_f if `s_spill' & year == 2009, detail
local p90_exp_f = r(p90)
di "P90 of mi_exp_f among spillover firms: `p90_exp_f'"

sum mi_exp_w if `s_spill' & year == 2009, detail
local p90_exp_w = r(p90)
di "P90 of mi_exp_w among spillover firms: `p90_exp_w'"

cap drop mi_exp_f_n
cap drop mi_exp_w_n
gen mi_exp_f_n = mi_exp_f / `p90_exp_f'
gen mi_exp_w_n = mi_exp_w / `p90_exp_w'
label var mi_exp_f_n "Local exposure (firm share), normalized to P90"
label var mi_exp_w_n "Local exposure (worker share), normalized to P90"

di as result "All variables created."

********************************************************************************
* SECTION 3: FE SPEC (identical to 4012_pct_tfpw.do)
********************************************************************************

local base_fe    "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local extra_year "ib0.totalflows_pw_pre_07_114#i.year"
local absorb_base "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

********************************************************************************
* SECTION 4: INITIALIZE OUTPUT CSV
********************************************************************************

capture erase "$tables/robustness/results_micro_ind_test.csv"
tempname fh
file open `fh' using "$tables/robustness/results_micro_ind_test.csv", write replace
file write `fh' "spec;outcome;row_type;value" _n
file close `fh'

local csv "$tables/robustness/results_micro_ind_test.csv"

********************************************************************************
* SECTION 5: REGRESSIONS
********************************************************************************

* ────────────────────────────────────────────────────────────────────────────
* SPEC 1: Baseline (no local exposure control)
* ────────────────────────────────────────────────────────────────────────────

di as result _newline "SPEC 1: Baseline"

reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
	absorb(`absorb_base') vce(cluster identificad)

local b_post  = _b[1.treat_year#c.`conn']
local se_post = _se[1.treat_year#c.`conn']
local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
local n_obs   = e(N)
local n_estab = e(N_clust)

reghdfe `outcome' c.`conn'##i.placebo_year if `s_spill' & year <= 2011, ///
	absorb(`absorb_base') vce(cluster identificad)

local b_pre  = _b[1.placebo_year#c.`conn']
local se_pre = _se[1.placebo_year#c.`conn']
local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

local stars_post ""
if `p_post' < 0.01                           local stars_post "***"
else if (`p_post' < 0.05 & `p_post' > 0.01) local stars_post "**"
else if (`p_post' < 0.10 & `p_post' > 0.05) local stars_post "*"

local stars_pre ""
if `p_pre' < 0.01                            local stars_pre "***"
else if (`p_pre' < 0.05 & `p_pre' > 0.01)   local stars_pre "**"
else if (`p_pre' < 0.10 & `p_pre' > 0.05)   local stars_pre "*"

tempname fh
file open `fh' using "`csv'", write append
file write `fh' `""base";"`outcome'";"main";"'   %9.4f (`b_post') `"`stars_post'""' _n
file write `fh' `""base";"`outcome'";"main_se";"' %9.4f (`se_post') `"""'           _n
file write `fh' `""base";"`outcome'";"pre";"'    %9.4f (`b_pre')  `"`stars_pre'""'  _n
file write `fh' `""base";"`outcome'";"pre_se";"'  %9.4f (`se_pre')  `"""'           _n
file write `fh' `""base";"`outcome'";"n_obs";"'   %12.0fc (`n_obs')   `"""'         _n
file write `fh' `""base";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""'         _n
file close `fh'

* ────────────────────────────────────────────────────────────────────────────
* SPEC 2: + i.micro_ind × year FE
* ────────────────────────────────────────────────────────────────────────────

di as result _newline "SPEC 2: + i.micro_ind#i.year"

reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
	absorb(`absorb_base' i.micro_ind#i.year) vce(cluster identificad)

local b_post  = _b[1.treat_year#c.`conn']
local se_post = _se[1.treat_year#c.`conn']
local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
local n_obs   = e(N)
local n_estab = e(N_clust)

reghdfe `outcome' c.`conn'##i.placebo_year if `s_spill' & year <= 2011, ///
	absorb(`absorb_base' i.micro_ind#i.year) vce(cluster identificad)

local b_pre  = _b[1.placebo_year#c.`conn']
local se_pre = _se[1.placebo_year#c.`conn']
local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

local stars_post ""
if `p_post' < 0.01                           local stars_post "***"
else if (`p_post' < 0.05 & `p_post' > 0.01) local stars_post "**"
else if (`p_post' < 0.10 & `p_post' > 0.05) local stars_post "*"

local stars_pre ""
if `p_pre' < 0.01                            local stars_pre "***"
else if (`p_pre' < 0.05 & `p_pre' > 0.01)   local stars_pre "**"
else if (`p_pre' < 0.10 & `p_pre' > 0.05)   local stars_pre "*"

tempname fh
file open `fh' using "`csv'", write append
file write `fh' `""mi_fe_yr";"`outcome'";"main";"'   %9.4f (`b_post') `"`stars_post'""' _n
file write `fh' `""mi_fe_yr";"`outcome'";"main_se";"' %9.4f (`se_post') `"""'           _n
file write `fh' `""mi_fe_yr";"`outcome'";"pre";"'    %9.4f (`b_pre')  `"`stars_pre'""'  _n
file write `fh' `""mi_fe_yr";"`outcome'";"pre_se";"'  %9.4f (`se_pre')  `"""'           _n
file write `fh' `""mi_fe_yr";"`outcome'";"n_obs";"'   %12.0fc (`n_obs')   `"""'         _n
file write `fh' `""mi_fe_yr";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""'         _n
file close `fh'

* ────────────────────────────────────────────────────────────────────────────
* SPEC 3: + i.micro_ind × treat_year / i.micro_ind × placebo_year FE
* ────────────────────────────────────────────────────────────────────────────

di as result _newline "SPEC 3: + i.micro_ind#treat_year / #placebo_year FE"

reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
	absorb(`absorb_base' i.micro_ind#i.treat_year) vce(cluster identificad)

local b_post  = _b[1.treat_year#c.`conn']
local se_post = _se[1.treat_year#c.`conn']
local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
local n_obs   = e(N)
local n_estab = e(N_clust)

reghdfe `outcome' c.`conn'##i.placebo_year if `s_spill' & year <= 2011, ///
	absorb(`absorb_base' i.micro_ind#i.placebo_year) vce(cluster identificad)

local b_pre  = _b[1.placebo_year#c.`conn']
local se_pre = _se[1.placebo_year#c.`conn']
local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

local stars_post ""
if `p_post' < 0.01                           local stars_post "***"
else if (`p_post' < 0.05 & `p_post' > 0.01) local stars_post "**"
else if (`p_post' < 0.10 & `p_post' > 0.05) local stars_post "*"

local stars_pre ""
if `p_pre' < 0.01                            local stars_pre "***"
else if (`p_pre' < 0.05 & `p_pre' > 0.01)   local stars_pre "**"
else if (`p_pre' < 0.10 & `p_pre' > 0.05)   local stars_pre "*"

tempname fh
file open `fh' using "`csv'", write append
file write `fh' `""mi_fe_tr";"`outcome'";"main";"'   %9.4f (`b_post') `"`stars_post'""' _n
file write `fh' `""mi_fe_tr";"`outcome'";"main_se";"' %9.4f (`se_post') `"""'           _n
file write `fh' `""mi_fe_tr";"`outcome'";"pre";"'    %9.4f (`b_pre')  `"`stars_pre'""'  _n
file write `fh' `""mi_fe_tr";"`outcome'";"pre_se";"'  %9.4f (`se_pre')  `"""'           _n
file write `fh' `""mi_fe_tr";"`outcome'";"n_obs";"'   %12.0fc (`n_obs')   `"""'         _n
file write `fh' `""mi_fe_tr";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""'         _n
file close `fh'

* ────────────────────────────────────────────────────────────────────────────
* SPEC 4: + c.mi_exp_f_n × year (firm-share, time-varying covariate)
* ────────────────────────────────────────────────────────────────────────────

di as result _newline "SPEC 4: + c.mi_exp_f_n#i.year"

reghdfe `outcome' c.`conn'##i.treat_year c.mi_exp_f_n#i.year if `s_spill', ///
	absorb(`absorb_base') vce(cluster identificad)

local b_post  = _b[1.treat_year#c.`conn']
local se_post = _se[1.treat_year#c.`conn']
local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
local n_obs   = e(N)
local n_estab = e(N_clust)

reghdfe `outcome' c.`conn'##i.placebo_year c.mi_exp_f_n#i.year if `s_spill' & year <= 2011, ///
	absorb(`absorb_base') vce(cluster identificad)

local b_pre  = _b[1.placebo_year#c.`conn']
local se_pre = _se[1.placebo_year#c.`conn']
local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

local stars_post ""
if `p_post' < 0.01                           local stars_post "***"
else if (`p_post' < 0.05 & `p_post' > 0.01) local stars_post "**"
else if (`p_post' < 0.10 & `p_post' > 0.05) local stars_post "*"

local stars_pre ""
if `p_pre' < 0.01                            local stars_pre "***"
else if (`p_pre' < 0.05 & `p_pre' > 0.01)   local stars_pre "**"
else if (`p_pre' < 0.10 & `p_pre' > 0.05)   local stars_pre "*"

tempname fh
file open `fh' using "`csv'", write append
file write `fh' `""mif_yr";"`outcome'";"main";"'   %9.4f (`b_post') `"`stars_post'""' _n
file write `fh' `""mif_yr";"`outcome'";"main_se";"' %9.4f (`se_post') `"""'           _n
file write `fh' `""mif_yr";"`outcome'";"pre";"'    %9.4f (`b_pre')  `"`stars_pre'""'  _n
file write `fh' `""mif_yr";"`outcome'";"pre_se";"'  %9.4f (`se_pre')  `"""'           _n
file write `fh' `""mif_yr";"`outcome'";"n_obs";"'   %12.0fc (`n_obs')   `"""'         _n
file write `fh' `""mif_yr";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""'         _n
file close `fh'

* ────────────────────────────────────────────────────────────────────────────
* SPEC 5: + mi_exp_f_n × treat_year / placebo_year (interacted control)
* ────────────────────────────────────────────────────────────────────────────

di as result _newline "SPEC 5: + mi_exp_f_n#treat_year / #placebo_year"

cap drop mief_n_post
cap drop mief_n_plac
gen mief_n_post = mi_exp_f_n * treat_year
gen mief_n_plac = mi_exp_f_n * placebo_year

reghdfe `outcome' c.`conn'##i.treat_year mief_n_post if `s_spill', ///
	absorb(`absorb_base') vce(cluster identificad)

local b_post     = _b[1.treat_year#c.`conn']
local se_post    = _se[1.treat_year#c.`conn']
local p_post     = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
local n_obs      = e(N)
local n_estab    = e(N_clust)
local b_ctrl     = _b[mief_n_post]
local se_ctrl    = _se[mief_n_post]
local p_ctrl     = 2*ttail(e(df_r), abs(`b_ctrl'/`se_ctrl'))

reghdfe `outcome' c.`conn'##i.placebo_year mief_n_plac if `s_spill' & year <= 2011, ///
	absorb(`absorb_base') vce(cluster identificad)

local b_pre       = _b[1.placebo_year#c.`conn']
local se_pre      = _se[1.placebo_year#c.`conn']
local p_pre       = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))
local b_ctrl_pre  = _b[mief_n_plac]
local se_ctrl_pre = _se[mief_n_plac]
local p_ctrl_pre  = 2*ttail(e(df_r), abs(`b_ctrl_pre'/`se_ctrl_pre'))

local stars_post ""
if `p_post' < 0.01                           local stars_post "***"
else if (`p_post' < 0.05 & `p_post' > 0.01) local stars_post "**"
else if (`p_post' < 0.10 & `p_post' > 0.05) local stars_post "*"

local stars_pre ""
if `p_pre' < 0.01                            local stars_pre "***"
else if (`p_pre' < 0.05 & `p_pre' > 0.01)   local stars_pre "**"
else if (`p_pre' < 0.10 & `p_pre' > 0.05)   local stars_pre "*"

local stars_ctrl ""
if `p_ctrl' < 0.01                           local stars_ctrl "***"
else if (`p_ctrl' < 0.05 & `p_ctrl' > 0.01) local stars_ctrl "**"
else if (`p_ctrl' < 0.10 & `p_ctrl' > 0.05) local stars_ctrl "*"

local stars_ctrl_pre ""
if `p_ctrl_pre' < 0.01                               local stars_ctrl_pre "***"
else if (`p_ctrl_pre' < 0.05 & `p_ctrl_pre' > 0.01) local stars_ctrl_pre "**"
else if (`p_ctrl_pre' < 0.10 & `p_ctrl_pre' > 0.05) local stars_ctrl_pre "*"

tempname fh
file open `fh' using "`csv'", write append
file write `fh' `""mif_tr";"`outcome'";"main";"'        %9.4f (`b_post')      `"`stars_post'""'     _n
file write `fh' `""mif_tr";"`outcome'";"main_se";"'     %9.4f (`se_post')     `"""'                 _n
file write `fh' `""mif_tr";"`outcome'";"pre";"'         %9.4f (`b_pre')       `"`stars_pre'""'      _n
file write `fh' `""mif_tr";"`outcome'";"pre_se";"'      %9.4f (`se_pre')      `"""'                 _n
file write `fh' `""mif_tr";"`outcome'";"ctrl_main";"'   %9.4f (`b_ctrl')      `"`stars_ctrl'""'     _n
file write `fh' `""mif_tr";"`outcome'";"ctrl_main_se";"' %9.4f (`se_ctrl')    `"""'                 _n
file write `fh' `""mif_tr";"`outcome'";"ctrl_pre";"'    %9.4f (`b_ctrl_pre')  `"`stars_ctrl_pre'""' _n
file write `fh' `""mif_tr";"`outcome'";"ctrl_pre_se";"' %9.4f (`se_ctrl_pre') `"""'                 _n
file write `fh' `""mif_tr";"`outcome'";"n_obs";"'       %12.0fc (`n_obs')     `"""'                 _n
file write `fh' `""mif_tr";"`outcome'";"n_estab";"'     %12.0fc (`n_estab')   `"""'                 _n
file close `fh'

* ────────────────────────────────────────────────────────────────────────────
* SPEC 5b: mi_exp_f_n × treat_year alone (no connectivity — pure control check)
* ────────────────────────────────────────────────────────────────────────────

di as result _newline "SPEC 5b: mi_exp_f_n#treat_year / #placebo_year, no connectivity"

cap drop mief_n_post
cap drop mief_n_plac
gen mief_n_post = mi_exp_f_n * treat_year
gen mief_n_plac = mi_exp_f_n * placebo_year

reghdfe `outcome' mief_n_post if `s_spill', ///
	absorb(`absorb_base') vce(cluster identificad)

local n_obs       = e(N)
local n_estab     = e(N_clust)
local b_ctrl      = _b[mief_n_post]
local se_ctrl     = _se[mief_n_post]
local p_ctrl      = 2*ttail(e(df_r), abs(`b_ctrl'/`se_ctrl'))

reghdfe `outcome' mief_n_plac if `s_spill' & year <= 2011, ///
	absorb(`absorb_base') vce(cluster identificad)

local b_ctrl_pre  = _b[mief_n_plac]
local se_ctrl_pre = _se[mief_n_plac]
local p_ctrl_pre  = 2*ttail(e(df_r), abs(`b_ctrl_pre'/`se_ctrl_pre'))

local stars_ctrl ""
if `p_ctrl' < 0.01                           local stars_ctrl "***"
else if (`p_ctrl' < 0.05 & `p_ctrl' > 0.01) local stars_ctrl "**"
else if (`p_ctrl' < 0.10 & `p_ctrl' > 0.05) local stars_ctrl "*"

local stars_ctrl_pre ""
if `p_ctrl_pre' < 0.01                               local stars_ctrl_pre "***"
else if (`p_ctrl_pre' < 0.05 & `p_ctrl_pre' > 0.01) local stars_ctrl_pre "**"
else if (`p_ctrl_pre' < 0.10 & `p_ctrl_pre' > 0.05) local stars_ctrl_pre "*"

tempname fh
file open `fh' using "`csv'", write append
file write `fh' `""mif_tr_b";"`outcome'";"ctrl_main";"'   %9.4f (`b_ctrl')      `"`stars_ctrl'""'     _n
file write `fh' `""mif_tr_b";"`outcome'";"ctrl_main_se";"' %9.4f (`se_ctrl')    `"""'                 _n
file write `fh' `""mif_tr_b";"`outcome'";"ctrl_pre";"'    %9.4f (`b_ctrl_pre')  `"`stars_ctrl_pre'""' _n
file write `fh' `""mif_tr_b";"`outcome'";"ctrl_pre_se";"' %9.4f (`se_ctrl_pre') `"""'                 _n
file write `fh' `""mif_tr_b";"`outcome'";"n_obs";"'       %12.0fc (`n_obs')     `"""'                 _n
file write `fh' `""mif_tr_b";"`outcome'";"n_estab";"'     %12.0fc (`n_estab')   `"""'                 _n
file close `fh'

* ────────────────────────────────────────────────────────────────────────────
* SPEC 6: + c.mi_exp_w_n × year (worker-share, time-varying covariate)
* ────────────────────────────────────────────────────────────────────────────

di as result _newline "SPEC 6: + c.mi_exp_w_n#i.year"

reghdfe `outcome' c.`conn'##i.treat_year c.mi_exp_w_n#i.year if `s_spill', ///
	absorb(`absorb_base') vce(cluster identificad)

local b_post  = _b[1.treat_year#c.`conn']
local se_post = _se[1.treat_year#c.`conn']
local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
local n_obs   = e(N)
local n_estab = e(N_clust)

reghdfe `outcome' c.`conn'##i.placebo_year c.mi_exp_w_n#i.year if `s_spill' & year <= 2011, ///
	absorb(`absorb_base') vce(cluster identificad)

local b_pre  = _b[1.placebo_year#c.`conn']
local se_pre = _se[1.placebo_year#c.`conn']
local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

local stars_post ""
if `p_post' < 0.01                           local stars_post "***"
else if (`p_post' < 0.05 & `p_post' > 0.01) local stars_post "**"
else if (`p_post' < 0.10 & `p_post' > 0.05) local stars_post "*"

local stars_pre ""
if `p_pre' < 0.01                            local stars_pre "***"
else if (`p_pre' < 0.05 & `p_pre' > 0.01)   local stars_pre "**"
else if (`p_pre' < 0.10 & `p_pre' > 0.05)   local stars_pre "*"

tempname fh
file open `fh' using "`csv'", write append
file write `fh' `""miw_yr";"`outcome'";"main";"'   %9.4f (`b_post') `"`stars_post'""' _n
file write `fh' `""miw_yr";"`outcome'";"main_se";"' %9.4f (`se_post') `"""'           _n
file write `fh' `""miw_yr";"`outcome'";"pre";"'    %9.4f (`b_pre')  `"`stars_pre'""'  _n
file write `fh' `""miw_yr";"`outcome'";"pre_se";"'  %9.4f (`se_pre')  `"""'           _n
file write `fh' `""miw_yr";"`outcome'";"n_obs";"'   %12.0fc (`n_obs')   `"""'         _n
file write `fh' `""miw_yr";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""'         _n
file close `fh'

* ────────────────────────────────────────────────────────────────────────────
* SPEC 7: + mi_exp_w_n × treat_year / placebo_year (interacted control)
* ────────────────────────────────────────────────────────────────────────────

di as result _newline "SPEC 7: + mi_exp_w_n#treat_year / #placebo_year"

cap drop miew_n_post
cap drop miew_n_plac
gen miew_n_post = mi_exp_w_n * treat_year
gen miew_n_plac = mi_exp_w_n * placebo_year

reghdfe `outcome' c.`conn'##i.treat_year miew_n_post if `s_spill', ///
	absorb(`absorb_base') vce(cluster identificad)

local b_post     = _b[1.treat_year#c.`conn']
local se_post    = _se[1.treat_year#c.`conn']
local p_post     = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
local n_obs      = e(N)
local n_estab    = e(N_clust)
local b_ctrl     = _b[miew_n_post]
local se_ctrl    = _se[miew_n_post]
local p_ctrl     = 2*ttail(e(df_r), abs(`b_ctrl'/`se_ctrl'))

reghdfe `outcome' c.`conn'##i.placebo_year miew_n_plac if `s_spill' & year <= 2011, ///
	absorb(`absorb_base') vce(cluster identificad)

local b_pre       = _b[1.placebo_year#c.`conn']
local se_pre      = _se[1.placebo_year#c.`conn']
local p_pre       = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))
local b_ctrl_pre  = _b[miew_n_plac]
local se_ctrl_pre = _se[miew_n_plac]
local p_ctrl_pre  = 2*ttail(e(df_r), abs(`b_ctrl_pre'/`se_ctrl_pre'))

local stars_post ""
if `p_post' < 0.01                           local stars_post "***"
else if (`p_post' < 0.05 & `p_post' > 0.01) local stars_post "**"
else if (`p_post' < 0.10 & `p_post' > 0.05) local stars_post "*"

local stars_pre ""
if `p_pre' < 0.01                            local stars_pre "***"
else if (`p_pre' < 0.05 & `p_pre' > 0.01)   local stars_pre "**"
else if (`p_pre' < 0.10 & `p_pre' > 0.05)   local stars_pre "*"

local stars_ctrl ""
if `p_ctrl' < 0.01                           local stars_ctrl "***"
else if (`p_ctrl' < 0.05 & `p_ctrl' > 0.01) local stars_ctrl "**"
else if (`p_ctrl' < 0.10 & `p_ctrl' > 0.05) local stars_ctrl "*"

local stars_ctrl_pre ""
if `p_ctrl_pre' < 0.01                               local stars_ctrl_pre "***"
else if (`p_ctrl_pre' < 0.05 & `p_ctrl_pre' > 0.01) local stars_ctrl_pre "**"
else if (`p_ctrl_pre' < 0.10 & `p_ctrl_pre' > 0.05) local stars_ctrl_pre "*"

tempname fh
file open `fh' using "`csv'", write append
file write `fh' `""miw_tr";"`outcome'";"main";"'        %9.4f (`b_post')      `"`stars_post'""'     _n
file write `fh' `""miw_tr";"`outcome'";"main_se";"'     %9.4f (`se_post')     `"""'                 _n
file write `fh' `""miw_tr";"`outcome'";"pre";"'         %9.4f (`b_pre')       `"`stars_pre'""'      _n
file write `fh' `""miw_tr";"`outcome'";"pre_se";"'      %9.4f (`se_pre')      `"""'                 _n
file write `fh' `""miw_tr";"`outcome'";"ctrl_main";"'   %9.4f (`b_ctrl')      `"`stars_ctrl'""'     _n
file write `fh' `""miw_tr";"`outcome'";"ctrl_main_se";"' %9.4f (`se_ctrl')    `"""'                 _n
file write `fh' `""miw_tr";"`outcome'";"ctrl_pre";"'    %9.4f (`b_ctrl_pre')  `"`stars_ctrl_pre'""' _n
file write `fh' `""miw_tr";"`outcome'";"ctrl_pre_se";"' %9.4f (`se_ctrl_pre') `"""'                 _n
file write `fh' `""miw_tr";"`outcome'";"n_obs";"'       %12.0fc (`n_obs')     `"""'                 _n
file write `fh' `""miw_tr";"`outcome'";"n_estab";"'     %12.0fc (`n_estab')   `"""'                 _n
file close `fh'

* ────────────────────────────────────────────────────────────────────────────
* SPEC 7b: mi_exp_w_n × treat_year alone (no connectivity — pure control check)
* ────────────────────────────────────────────────────────────────────────────

di as result _newline "SPEC 7b: mi_exp_w_n#treat_year / #placebo_year, no connectivity"

cap drop miew_n_post
cap drop miew_n_plac
gen miew_n_post = mi_exp_w_n * treat_year
gen miew_n_plac = mi_exp_w_n * placebo_year

reghdfe `outcome' miew_n_post if `s_spill', ///
	absorb(`absorb_base') vce(cluster identificad)

local n_obs       = e(N)
local n_estab     = e(N_clust)
local b_ctrl      = _b[miew_n_post]
local se_ctrl     = _se[miew_n_post]
local p_ctrl      = 2*ttail(e(df_r), abs(`b_ctrl'/`se_ctrl'))

reghdfe `outcome' miew_n_plac if `s_spill' & year <= 2011, ///
	absorb(`absorb_base') vce(cluster identificad)

local b_ctrl_pre  = _b[miew_n_plac]
local se_ctrl_pre = _se[miew_n_plac]
local p_ctrl_pre  = 2*ttail(e(df_r), abs(`b_ctrl_pre'/`se_ctrl_pre'))

local stars_ctrl ""
if `p_ctrl' < 0.01                           local stars_ctrl "***"
else if (`p_ctrl' < 0.05 & `p_ctrl' > 0.01) local stars_ctrl "**"
else if (`p_ctrl' < 0.10 & `p_ctrl' > 0.05) local stars_ctrl "*"

local stars_ctrl_pre ""
if `p_ctrl_pre' < 0.01                               local stars_ctrl_pre "***"
else if (`p_ctrl_pre' < 0.05 & `p_ctrl_pre' > 0.01) local stars_ctrl_pre "**"
else if (`p_ctrl_pre' < 0.10 & `p_ctrl_pre' > 0.05) local stars_ctrl_pre "*"

tempname fh
file open `fh' using "`csv'", write append
file write `fh' `""miw_tr_b";"`outcome'";"ctrl_main";"'   %9.4f (`b_ctrl')      `"`stars_ctrl'""'     _n
file write `fh' `""miw_tr_b";"`outcome'";"ctrl_main_se";"' %9.4f (`se_ctrl')    `"""'                 _n
file write `fh' `""miw_tr_b";"`outcome'";"ctrl_pre";"'    %9.4f (`b_ctrl_pre')  `"`stars_ctrl_pre'""' _n
file write `fh' `""miw_tr_b";"`outcome'";"ctrl_pre_se";"' %9.4f (`se_ctrl_pre') `"""'                 _n
file write `fh' `""miw_tr_b";"`outcome'";"n_obs";"'       %12.0fc (`n_obs')     `"""'                 _n
file write `fh' `""miw_tr_b";"`outcome'";"n_estab";"'     %12.0fc (`n_estab')   `"""'                 _n
file close `fh'

* ── Clean up ──────────────────────────────────────────────────────────────────

drop mief_n_post
drop mief_n_plac
drop miew_n_post
drop miew_n_plac

********************************************************************************
* DONE
********************************************************************************

di _newline
di as result "Results saved to: $tables/robustness/results_micro_ind_test.csv"
di as result "P90 of mi_exp_f: `p90_exp_f'"
di as result "P90 of mi_exp_w: `p90_exp_w'"
di "Finished: `c(current_date)' `c(current_time)'"

capture log close

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "Stata done" "Main_Results_micro_ind.do finished"
