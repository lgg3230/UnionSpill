********************************************************************************
* LAYER CONNECTIVITY — DIAGNOSTIC: Firm-level DiD on each layer's estimation sample
*
* Solution 1 from user request:
*   For each occ4 layer, restrict to the exact set of firms used in the
*   per-layer cross-firm regression (saved by 01_univariate_per_layer_occ4.do),
*   then run the standard firm-level DiD with totaltreat_pw_n as the connectivity
*   measure and the usual fixed effects.
*
* Interpretation:
*   - If firm-level connectivity is ALSO negative for the manager sample
*     → sample selection (those firms are different regardless of layer)
*   - If firm-level connectivity is zero/positive for the manager sample
*     → the manager-specific channel is genuinely different, not sample artifact
*
* Requires: firms_samp_{lv}.dta in Tables/layer_connectivity/06_diagnostics/
*           (produced by 01_univariate_per_layer_occ4.do)
*
* Output: Tables/layer_connectivity/06_diagnostics/results_firmcheck_occ4.csv
********************************************************************************

global main      "/kellogg/proj/lgg3230"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
global tables    "$main/UnionSpill/Tables"
global logs      "$main/UnionSpill/Logs"

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/layer_connectivity/06_diagnostics/firmcheck_occ4_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"

local layer_vals "1_mgr 23_high 4_bur 5p_low"

* ── Initialize CSV ────────────────────────────────────────────────────────────
local csv_out "$tables/layer_connectivity/06_diagnostics/results_firmcheck_occ4.csv"
capture erase "`csv_out'"
tempname fh
file open  `fh' using "`csv_out'", write replace
file write `fh' "spec;section;outcome;row_type;value" _n
file close `fh'

* ── Load totalflows wide (pre-treatment flow controls) ────────────────────────
tempfile tfwide
import delimited "$rais_aux/totalflows_wide_2007_2011.csv", stringcols(1) clear
save `tfwide'

********************************************************************************
* LOOP OVER LAYERS
********************************************************************************

foreach lv in `layer_vals' {

	di _newline(2)
	di as result "===== Firm-level check — Layer sample: `lv' ====="

	* ── Load firm panel ───────────────────────────────────────────────────────
	use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear
	keep if year >= 2009

	* ── Restrict to this layer's estimation firms ────────────────────────────
	merge m:1 identificad using ///
		"$tables/layer_connectivity/06_diagnostics/firms_samp_`lv'.dta", ///
		keep(match) nogen

	count
	di as result "  Firms in this layer's sample: `r(N)' obs"

	* ── Merge pre-treatment totalflows ───────────────────────────────────────
	merge m:1 identificad using `tfwide', keep(master match) nogen

	* ── Encode FE variables ──────────────────────────────────────────────────
	cap drop firm_id
	egen firm_id = group(identificad)

	capture confirm string variable industry1
	if !_rc encode industry1,         gen(industry1_num)
	else     gen industry1_num       = industry1

	capture confirm string variable mode_base_month
	if !_rc encode mode_base_month,   gen(mode_base_month_num)
	else     gen mode_base_month_num = mode_base_month

	capture confirm string variable microregion
	if !_rc encode microregion,       gen(microregion_num)
	else     gen microregion_num     = microregion

	cap drop treat_year
	gen byte treat_year   = (year >= 2012)
	cap drop placebo_year
	gen byte placebo_year = (year < 2011)

	local s_spill "treat_ultra==0 & in_balanced_panel==1"

	* ── Scale firm connectivity to P90 of this subsample at 2009 ─────────────
	cap drop totaltreat_pw_norm
	sum totaltreat_pw_n if `s_spill' & year == 2009, detail
	gen double totaltreat_pw_norm = totaltreat_pw_n / r(p90)
	label var totaltreat_pw_norm "Firm connectivity (scaled to P90 of this layer's subsample)"

	* ── Pre-treatment outcome bins ────────────────────────────────────────────
	foreach v in lr_remdezr_w l_firm_emp {
		cap drop `v'_pre_o
		cap drop `v'_pre
		cap drop `v'_pre4_o
		cap drop `v'_pre4
		bys identificad: egen `v'_pre_o = mean(`v') if inrange(year, 2009, 2011)
		bys identificad: egen `v'_pre   = min(`v'_pre_o)
		drop `v'_pre_o
		egen `v'_pre4_o = cut(`v'_pre) if year==2009 & in_balanced_panel==1, group(4)
		bys identificad: egen `v'_pre4 = min(`v'_pre4_o)
		drop `v'_pre4_o
		replace `v'_pre4 = 0 if missing(`v'_pre4)
	}

	* ── Pre-treatment totalflows bins ────────────────────────────────────────
	cap drop totalflows_pw_pre_07_11
	cap drop totalflows_pw_pre_07_11_cnt
	gen double totalflows_pw_pre_07_11     = 0
	gen        totalflows_pw_pre_07_11_cnt = 0
	foreach yp in totalflows_pw_07_08 totalflows_pw_08_09 ///
	              totalflows_pw_09_10 totalflows_pw_10_11 {
		replace totalflows_pw_pre_07_11     = totalflows_pw_pre_07_11 + `yp' if !missing(`yp')
		replace totalflows_pw_pre_07_11_cnt = totalflows_pw_pre_07_11_cnt + (!missing(`yp'))
	}
	replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 / totalflows_pw_pre_07_11_cnt ///
		if totalflows_pw_pre_07_11_cnt > 0
	replace totalflows_pw_pre_07_11 = . if totalflows_pw_pre_07_11_cnt == 0
	drop totalflows_pw_pre_07_11_cnt
	cap drop totalflows_pw_pre4_o
	cap drop totalflows_pw_pre4
	egen totalflows_pw_pre4_o = cut(totalflows_pw_pre_07_11) ///
		if year==2009 & in_balanced_panel==1, group(4)
	bys identificad: egen totalflows_pw_pre4 = min(totalflows_pw_pre4_o)
	drop totalflows_pw_pre4_o
	replace totalflows_pw_pre4 = 0 if missing(totalflows_pw_pre4)

	* ── Run DiD for each firm-level outcome ───────────────────────────────────
	foreach outcome in lr_remdezr_w l_firm_emp {

		di as text "  Outcome: `outcome' | Layer sample: `lv'"

		local extra_f "ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year ib0.totalflows_pw_pre4#i.year i.industry1_num#i.year i.microregion_num#i.year i.mode_base_month_num#i.year"

		* Post-treatment DiD
		reghdfe `outcome' c.totaltreat_pw_norm##i.treat_year ///
			if `s_spill', ///
			absorb(i.firm_id i.year `extra_f') vce(cluster identificad)

		local b_post  = _b[1.treat_year#c.totaltreat_pw_norm]
		local se_post = _se[1.treat_year#c.totaltreat_pw_norm]
		local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
		local n_obs   = e(N)
		local n_firms = e(N_clust)

		local st_post ""
		if `p_post' < 0.01                            local st_post "***"
		else if (`p_post' < 0.05 & `p_post' > 0.01)  local st_post "**"
		else if (`p_post' < 0.10 & `p_post' > 0.05)  local st_post "*"

		* Pre-period placebo
		reghdfe `outcome' c.totaltreat_pw_norm##i.placebo_year ///
			if `s_spill' & year <= 2011, ///
			absorb(i.firm_id i.year `extra_f') vce(cluster identificad)

		local b_pre  = _b[1.placebo_year#c.totaltreat_pw_norm]
		local se_pre = _se[1.placebo_year#c.totaltreat_pw_norm]
		local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

		local st_pre ""
		if `p_pre' < 0.01                            local st_pre "***"
		else if (`p_pre' < 0.05 & `p_pre' > 0.01)   local st_pre "**"
		else if (`p_pre' < 0.10 & `p_pre' > 0.05)   local st_pre "*"

		* Event study + pre-trend F-test
		reghdfe `outcome' c.totaltreat_pw_norm##ib2011.year ///
			if `s_spill', ///
			absorb(i.firm_id i.year `extra_f') vce(cluster identificad)

		capture testparm c.totaltreat_pw_norm#i(2009 2010).year
		local pre_pval = cond(_rc==0, r(p), .)

		* Write to CSV
		local outcome_key "`outcome'_`lv'"
		tempname fh
		file open  `fh' using "`csv_out'", write append
		file write `fh' `""firmcheck_occ4";"firm_level";"`outcome_key'";"main";"'    %9.4f (`b_post')  `"`st_post'"' _n
		file write `fh' `""firmcheck_occ4";"firm_level";"`outcome_key'";"main_se";"' %9.4f (`se_post') `"""'         _n
		file write `fh' `""firmcheck_occ4";"firm_level";"`outcome_key'";"pre";"'     %9.4f (`b_pre')   `"`st_pre'"'  _n
		file write `fh' `""firmcheck_occ4";"firm_level";"`outcome_key'";"pre_se";"'  %9.4f (`se_pre')  `"""'         _n
		file write `fh' `""firmcheck_occ4";"firm_level";"`outcome_key'";"n_obs";"'   %12.0fc (`n_obs')  `"""'        _n
		file write `fh' `""firmcheck_occ4";"firm_level";"`outcome_key'";"n_firms";"' %12.0fc (`n_firms') `"""'       _n
		file write `fh' `""firmcheck_occ4";"firm_level";"`outcome_key'";"pre_pval";"'%9.4f (`pre_pval') `"""'        _n
		file close `fh'

		di as result "  Done: `outcome' | `lv'"
	}
}

di as result "Firm-level checks complete. Results in `csv_out'"
log close

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "01b done" "occ4 firm-level check complete"
