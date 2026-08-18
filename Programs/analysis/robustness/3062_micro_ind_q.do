********************************************************************************
* ROBUSTNESS: LOCAL (INDUSTRY x MICROREGION) EXPOSURE -- QUARTILE CONTROLS
*                                             + MATCHING DIRECT-EFFECT COLUMNS
*
* New file (not an edit of archive/Programs/robustness/Main_Results_micro_ind.do) per the house rule that a
* significant logic change gets its own script.
*
* Two changes relative to archive/Programs/robustness/Main_Results_micro_ind.do:
*
*   (1) The local-exposure controls enter as QUARTILE BINS interacted with year
*       FE, replacing the linear `c.mi_exp_*_n#i.year` controls. This matches
*       how every other control in the paper is handled (l_firm_emp_pre4,
*       <outcome>_pre4, totalflows_pw_pre_07_114 are all ib0.<bin>#i.year).
*
*       BIN CONSTRUCTION DECISION: bins are cut on the firm's 2009 value of the
*       cell exposure measure and held FIXED over time, then interacted with
*       year. The linear control was time-varying. Fixing the bin at the
*       pre-period matches the house `_pre4` convention and avoids absorbing
*       post-reform variation in local exposure, which is itself an outcome of
*       the reform. Bins are cut on the estimation sample of the column.
*
*   (2) Direct-effect columns estimated on the DIRECT sample (treated + zero-
*       connectivity untreated) with that sample's own controls, rather than by
*       adding a local-exposure regressor to the spillover regression. These
*       supply the denominator that the spillover/direct ratio previously had to
*       borrow from the main specification (the dagger footnote).
*
* Specs written:
*   mif_q     spillover + firm-share exposure quartiles x year      -> col (5)
*   miw_q     spillover + worker-share exposure quartiles x year    -> col (6)
*   dir_mif_q direct    + firm-share exposure quartiles x year      -> col (7)
*   dir_miw_q direct    + worker-share exposure quartiles x year    -> col (8)
*   dir_base  direct    baseline, no exposure control  (ratio cross-check)
*
* Parameters (set by the wrapper):
*   $OUTVAR  outcome variable   (lr_remdezr_w | lr_remdezr_h_w)
*   $OUTSUF  csv suffix         (""           | "_hw")
*
* Output: $tables/robustness/results_micro_ind_q$OUTSUF.csv
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/robustness/Main_Results_micro_ind_q$OUTSUF`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
di "Outcome: $OUTVAR   Suffix: $OUTSUF"
di "Panel source: $rais_firm"

********************************************************************************
* SECTION 1: DATA  (identical to archive/Programs/robustness/Main_Results_micro_ind.do)
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

di as result "Sample size: " _N

********************************************************************************
* SECTION 2: VARIABLE CREATION
********************************************************************************

local s_spill    "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"
local s_exposure "lagos_sample_avg==1 & in_balanced_panel==1"
local s_direct   "(treat_ultra==0 & totaltreat_pw_n==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"

cap drop placebo_year
gen byte placebo_year = (year < 2011)
label var placebo_year "Pre-treatment period"

cap drop treat_year
gen byte treat_year = (year >= 2012)
label var treat_year "Post-treatment period"

* ── Connectivity scaled to 90th pctile among untreated firms ─────────────────
* NOTE: totaltreat_pw_norm is REBUILT here from totaltreat_pw_n. The current-
* connectivity overlay ships a stale totaltreat_pw_norm carrying the legacy p90
* divisor; rebuilding is mandatory. The p90 used is printed below.

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
quietly sum totaltreat_pw_n if `s_spill' & year == 2009, detail
local p90_conn = r(p90)
gen totaltreat_pw_n_p90 = `p90_conn'
gen totaltreat_pw_norm  = totaltreat_pw_n / totaltreat_pw_n_p90
label var totaltreat_pw_norm "Connectivity scaled to 90th pctile among untreated firms"

di as result "REBUILT totaltreat_pw_norm. p90(totaltreat_pw_n) = " %12.8f `p90_conn'

local conn "totaltreat_pw_norm"

* ── Pre-treatment firm employment ────────────────────────────────────────────

cap drop firm_emp_pre_o
cap drop firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre   = min(firm_emp_pre_o)
	drop firm_emp_pre_o
}

cap drop l_firm_emp_pre
gen double l_firm_emp_pre = ln(firm_emp_pre)

* ── Pre-treatment outcome average ────────────────────────────────────────────

local outcome "$OUTVAR"

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

* ── Industry x microregion cell ──────────────────────────────────────────────

cap drop micro_ind
egen micro_ind = group(microregion industry)

* ── Local exposure measures (levels, as in archive/Programs/robustness/Main_Results_micro_ind.do) ────────

cap drop mi_exp_f
bys micro_ind year: egen mi_exp_f = mean(treat_ultra) if `s_exposure'

cap drop mi_workers
cap drop mi_workers_t
cap drop mi_exp_w
bys micro_ind year: egen mi_workers   = total(firm_emp)               if `s_exposure'
bys micro_ind year: egen mi_workers_t = total(firm_emp * treat_ultra) if `s_exposure'
gen mi_exp_w = mi_workers_t / mi_workers

* ── LINEAR exposure, normalized to p90 among SPILLOVER firms ─────────────────
* Copied from archive/Programs/robustness/Main_Results_micro_ind.do (lines 173-187). DECISION (2026-07-31):
* the spillover-sample p90 divisor is used for BOTH panels, including the
* direct-sample columns. Do not renormalize on the direct sample -- keeping one
* divisor puts the direct and spillover linear coefficients on the same scale so
* the spillover/direct ratio within a column is meaningful.

sum mi_exp_f if `s_spill' & year == 2009, detail
local p90_exp_f = r(p90)
di as result "P90 of mi_exp_f among spillover firms: `p90_exp_f'"

sum mi_exp_w if `s_spill' & year == 2009, detail
local p90_exp_w = r(p90)
di as result "P90 of mi_exp_w among spillover firms: `p90_exp_w'"

cap drop mi_exp_f_n
cap drop mi_exp_w_n
gen mi_exp_f_n = mi_exp_f / `p90_exp_f'
gen mi_exp_w_n = mi_exp_w / `p90_exp_w'
label var mi_exp_f_n "Local exposure (firm share), normalized to spillover P90"
label var mi_exp_w_n "Local exposure (worker share), normalized to spillover P90"

* ── QUARTILE BINS of local exposure, fixed at 2009, per estimation sample ────
* Spillover-sample bins (used by cols 5-6) and direct-sample bins (cols 7-8).
* Normalization is irrelevant for bins (monotone), so bins are cut on levels.

* Spillover sample
cap drop mi_exp_f4_s_o
cap drop mi_exp_f4_s
quietly {
	egen mi_exp_f4_s_o = cut(mi_exp_f) if year == 2009 & `s_spill', group(4)
	bys identificad: egen mi_exp_f4_s = min(mi_exp_f4_s_o)
	drop mi_exp_f4_s_o
	replace mi_exp_f4_s = 0 if missing(mi_exp_f4_s)
}

cap drop mi_exp_w4_s_o
cap drop mi_exp_w4_s
quietly {
	egen mi_exp_w4_s_o = cut(mi_exp_w) if year == 2009 & `s_spill', group(4)
	bys identificad: egen mi_exp_w4_s = min(mi_exp_w4_s_o)
	drop mi_exp_w4_s_o
	replace mi_exp_w4_s = 0 if missing(mi_exp_w4_s)
}

* Direct sample
cap drop mi_exp_f4_d_o
cap drop mi_exp_f4_d
quietly {
	egen mi_exp_f4_d_o = cut(mi_exp_f) if year == 2009 & `s_direct', group(4)
	bys identificad: egen mi_exp_f4_d = min(mi_exp_f4_d_o)
	drop mi_exp_f4_d_o
	replace mi_exp_f4_d = 0 if missing(mi_exp_f4_d)
}

cap drop mi_exp_w4_d_o
cap drop mi_exp_w4_d
quietly {
	egen mi_exp_w4_d_o = cut(mi_exp_w) if year == 2009 & `s_direct', group(4)
	bys identificad: egen mi_exp_w4_d = min(mi_exp_w4_d_o)
	drop mi_exp_w4_d_o
	replace mi_exp_w4_d = 0 if missing(mi_exp_w4_d)
}

di as result "Exposure quartile bins built. Distributions:"
tab mi_exp_f4_s if year == 2009 & `s_spill'
tab mi_exp_w4_s if year == 2009 & `s_spill'
tab mi_exp_f4_d if year == 2009 & `s_direct'
tab mi_exp_w4_d if year == 2009 & `s_direct'

********************************************************************************
* SECTION 3: FE SPEC
********************************************************************************

local base_fe    "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local extra_year "ib0.totalflows_pw_pre_07_114#i.year"
local absorb_base "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

********************************************************************************
* SECTION 4: OUTPUT CSV
********************************************************************************

capture erase "$tables/robustness/results_micro_ind_q$OUTSUF.csv"
tempname fh
file open `fh' using "$tables/robustness/results_micro_ind_q$OUTSUF.csv", write replace
file write `fh' "spec;outcome;row_type;value" _n
file close `fh'

local csv "$tables/robustness/results_micro_ind_q$OUTSUF.csv"

********************************************************************************
* SECTION 5: REGRESSIONS
********************************************************************************

local speclist "mif_lin miw_lin mif_q miw_q dir_mif_lin dir_miw_lin dir_mif_q dir_miw_q dir_base"

foreach spec of local speclist {

	* ── Route the spec ───────────────────────────────────────────────────────
	if "`spec'" == "mif_lin" {
		local mode "spill"
		local samp "`s_spill'"
		local xtra ""
		local cov  "c.mi_exp_f_n#i.year"
	}
	if "`spec'" == "miw_lin" {
		local mode "spill"
		local samp "`s_spill'"
		local xtra ""
		local cov  "c.mi_exp_w_n#i.year"
	}
	if "`spec'" == "dir_mif_lin" {
		local mode "direct"
		local samp "`s_direct'"
		local xtra ""
		local cov  "c.mi_exp_f_n#i.year"
	}
	if "`spec'" == "dir_miw_lin" {
		local mode "direct"
		local samp "`s_direct'"
		local xtra ""
		local cov  "c.mi_exp_w_n#i.year"
	}
	if "`spec'" == "mif_q" {
		local cov  ""
		local mode "spill"
		local samp "`s_spill'"
		local xtra "ib0.mi_exp_f4_s#i.year"
	}
	if "`spec'" == "miw_q" {
		local cov  ""
		local mode "spill"
		local samp "`s_spill'"
		local xtra "ib0.mi_exp_w4_s#i.year"
	}
	if "`spec'" == "dir_mif_q" {
		local cov  ""
		local mode "direct"
		local samp "`s_direct'"
		local xtra "ib0.mi_exp_f4_d#i.year"
	}
	if "`spec'" == "dir_miw_q" {
		local cov  ""
		local mode "direct"
		local samp "`s_direct'"
		local xtra "ib0.mi_exp_w4_d#i.year"
	}
	if "`spec'" == "dir_base" {
		local cov  ""
		local mode "direct"
		local samp "`s_direct'"
		local xtra ""
	}

	di as result _newline "==================================================="
	di as result "SPEC: `spec'   (mode=`mode')"
	di as result "==================================================="

	* ── Post regression ──────────────────────────────────────────────────────
	if "`mode'" == "spill" {
		reghdfe `outcome' c.`conn'##i.treat_year `cov' if `samp', ///
			absorb(`absorb_base' `xtra') vce(cluster identificad)
		local b_post  = _b[1.treat_year#c.`conn']
		local se_post = _se[1.treat_year#c.`conn']
	}
	else {
		reghdfe `outcome' treat_ultra##i.treat_year `cov' if `samp', ///
			absorb(`absorb_base' `xtra') vce(cluster identificad)
		local b_post  = _b[1.treat_ultra#1.treat_year]
		local se_post = _se[1.treat_ultra#1.treat_year]
	}
	local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
	local n_obs   = e(N)
	local n_estab = e(N_clust)

	* ── Pre-treatment mean on this column's estimation sample ────────────────
	* Plan 2026-08-01. Taken here, before the placebo regression below replaces
	* e(sample), so singleton drops and covariate missingness are inherited.
	quietly sum `outcome' if e(sample) & inrange(year, 2009, 2011)
	local mean_pre_val = r(mean)

	* ── Placebo regression ───────────────────────────────────────────────────
	if "`mode'" == "spill" {
		reghdfe `outcome' c.`conn'##i.placebo_year `cov' if `samp' & year <= 2011, ///
			absorb(`absorb_base' `xtra') vce(cluster identificad)
		local b_pre  = _b[1.placebo_year#c.`conn']
		local se_pre = _se[1.placebo_year#c.`conn']
	}
	else {
		reghdfe `outcome' treat_ultra##i.placebo_year `cov' if `samp' & year <= 2011, ///
			absorb(`absorb_base' `xtra') vce(cluster identificad)
		local b_pre  = _b[1.treat_ultra#1.placebo_year]
		local se_pre = _se[1.treat_ultra#1.placebo_year]
	}
	local p_pre = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

	* (Pre-treatment mean is computed above, on e(sample) of the post
	* regression. It superseded a firm-average-at-2009 construction that did
	* not account for singleton dropping.)

	* ── Stars ────────────────────────────────────────────────────────────────
	local stars_post ""
	if `p_post' < 0.01                          local stars_post "***"
	else if (`p_post' < 0.05 & `p_post' > 0.01) local stars_post "**"
	else if (`p_post' < 0.10 & `p_post' > 0.05) local stars_post "*"

	local stars_pre ""
	if `p_pre' < 0.01                         local stars_pre "***"
	else if (`p_pre' < 0.05 & `p_pre' > 0.01) local stars_pre "**"
	else if (`p_pre' < 0.10 & `p_pre' > 0.05) local stars_pre "*"

	* ── Write ────────────────────────────────────────────────────────────────
	tempname fh
	file open `fh' using "`csv'", write append
	file write `fh' `""`spec'";"`outcome'";"main";"'     %9.4f (`b_post')        `"`stars_post'""' _n
	file write `fh' `""`spec'";"`outcome'";"main_se";"'  %9.4f (`se_post')       `"""'             _n
	file write `fh' `""`spec'";"`outcome'";"pre";"'      %9.4f (`b_pre')         `"`stars_pre'""'  _n
	file write `fh' `""`spec'";"`outcome'";"pre_se";"'   %9.4f (`se_pre')        `"""'             _n
	file write `fh' `""`spec'";"`outcome'";"n_obs";"'    %12.0fc (`n_obs')       `"""'             _n
	file write `fh' `""`spec'";"`outcome'";"n_estab";"'  %12.0fc (`n_estab')     `"""'             _n
	file write `fh' `""`spec'";"`outcome'";"mean_pre";"' %9.4f (`mean_pre_val')  `"""'             _n
	file write `fh' `""`spec'";"`outcome'";"mode";"`mode'""' _n
	file close `fh'

	di as result "`spec': b=" %9.4f `b_post' " se=" %9.4f `se_post' " N=" `n_obs' " estabs=" `n_estab'
}

di as result _newline "Results saved to: `csv'"
di as result "p90(totaltreat_pw_n) used for normalization: " %12.8f `p90_conn'

log close
di as result "Finished: `c(current_date)' `c(current_time)'"
