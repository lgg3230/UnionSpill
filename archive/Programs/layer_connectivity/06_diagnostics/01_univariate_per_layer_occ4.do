********************************************************************************
* LAYER CONNECTIVITY — DIAGNOSTIC: Univariate cross-firm spec per occ4 layer
*
* Check 3 from notes_occ4_diagnostics_Apr2026.md:
*   Run a separate cross-firm regression for each occ4 layer, using only
*   that layer's observations. Eliminates the within-firm cross-occupation
*   comparison that may confound the pooled within-firm spec.
*
* If the negative wage sign (found in the pooled within-firm spec) disappears
* or flips to positive here, it was driven by the within-firm occupational
* wage hierarchy, not a genuine negative spillover.
*
* FE: firm FE + year FE + micro×year + industry×year + mode×year
*     (same as cross-firm spec, but no layer_id×year since we restrict to
*      one layer at a time)
*
* Output: Tables/layer_connectivity/06_diagnostics/results_univariate_occ4.csv
*         Graphs/layer_connectivity/06_diagnostics/es_*
********************************************************************************

********************************************************************************
* SECTION 1: PATHS & GLOBALS
********************************************************************************

global main      "/kellogg/proj/lgg3230"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global tables    "$main/UnionSpill/Tables"
global graphs    "$main/UnionSpill/Graphs"
global logs      "$main/UnionSpill/Logs"
global layer_data "$main/UnionSpill/Data/layer_connectivity"

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/layer_connectivity/06_diagnostics/univariate_occ4_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
di "Stata version: `c(stata_version)'"

local layer_vals "1_mgr 23_high 4_bur 5p_low"

********************************************************************************
* SECTION 2: LOAD AND PREPARE DATA
********************************************************************************

use "$layer_data/firm_layer_outcomes_occ4.dta", clear
keep if year >= 2009

count
di as result "  Observations loaded: `r(N)'"

* Numeric IDs for FE
cap drop firm_id
egen firm_id = group(identificad)
cap drop firm_layer_id
egen firm_layer_id = group(identificad layer_id)

* ── Merge connectivity ────────────────────────────────────────────────────────
merge m:1 identificad layer_id using ///
	"$layer_data/final_measures/firm_layer_connectivity_occ4.dta", ///
	keep(master match) nogen

* ── Merge firm-level controls ─────────────────────────────────────────────────
merge m:1 identificad year using ///
	"$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", ///
	keepusing(treat_ultra in_balanced_panel lagos_sample_avg ///
	          industry1 mode_base_month microregion) ///
	keep(master match) nogen

keep if lagos_sample_avg == 1

* ── Encode categorical FE variables ──────────────────────────────────────────
capture confirm string variable industry1
if !_rc encode industry1,         gen(industry1_num)
else     gen industry1_num       = industry1

capture confirm string variable mode_base_month
if !_rc encode mode_base_month,   gen(mode_base_month_num)
else     gen mode_base_month_num = mode_base_month

capture confirm string variable microregion
if !_rc encode microregion,       gen(microregion_num)
else     gen microregion_num     = microregion

********************************************************************************
* SECTION 3: VARIABLE CREATION
********************************************************************************

cap drop treat_year
gen byte treat_year = (year >= 2012)

cap drop placebo_year
gen byte placebo_year = (year < 2011)

* ── Pre-treatment outcome averages ───────────────────────────────────────────
foreach v in lr_remdezr_layer l_layer_emp {
	cap drop `v'_pre_o
	cap drop `v'_pre
	bys identificad layer_id: ///
		egen `v'_pre_o = mean(`v') if inrange(year, 2009, 2011)
	bys identificad layer_id: ///
		egen `v'_pre   = min(`v'_pre_o)
	drop `v'_pre_o

	cap drop `v'_pre4_o
	cap drop `v'_pre4
	egen `v'_pre4_o = cut(`v'_pre) ///
		if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad layer_id: ///
		egen `v'_pre4 = min(`v'_pre4_o)
	drop `v'_pre4_o
	replace `v'_pre4 = 0 if missing(`v'_pre4)
}

* ── Layer-level totalflows bins ──────────────────────────────────────────────
capture confirm variable totalflows_layer_pw_n
if _rc {
	gen byte layer_totalflows_pw_pre4 = 0
}
else {
	cap drop layer_totalflows_pw_pre4_o
	cap drop layer_totalflows_pw_pre4
	egen layer_totalflows_pw_pre4_o = cut(totalflows_layer_pw_n) ///
		if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad layer_id: ///
		egen layer_totalflows_pw_pre4 = min(layer_totalflows_pw_pre4_o)
	drop layer_totalflows_pw_pre4_o
	replace layer_totalflows_pw_pre4 = 0 if missing(layer_totalflows_pw_pre4)
}

di as result "Variables created."

********************************************************************************
* SECTION 4: INITIALIZE OUTPUT CSV
********************************************************************************

local csv_out "$tables/layer_connectivity/06_diagnostics/results_univariate_occ4.csv"
capture erase "`csv_out'"
tempname fh
file open  `fh' using "`csv_out'", write replace
file write `fh' "spec;section;outcome;row_type;value" _n
file close `fh'

di as result "Output CSV: `csv_out'"

********************************************************************************
* SECTION 5: PER-LAYER REGRESSIONS
*
* For each occupation layer: scale connectivity to its own P90, then run
* cross-firm DiD restricted to that layer only.
* FE: firm FE + year FE + micro×year + industry×year + mode×year
*     (no layer_id×year since we restrict to a single layer)
********************************************************************************

local s_spill "treat_ultra==0 & in_balanced_panel==1"

foreach lv in `layer_vals' {

	di _newline(1)
	di as result "===== Layer: `lv' ====="

	* ── Scale connectivity to P90 of this layer's control firms at 2009 ────
	cap drop layer_conn_norm
	sum layer_treat_pw_n if `s_spill' & year == 2009 & layer_id == "`lv'", detail
	gen double layer_conn_norm = layer_treat_pw_n / r(p90)
	label var layer_conn_norm "Layer connectivity (scaled to P90, `lv' layer)"

	local cross_fe "i.firm_layer_id i.year i.industry1_num#i.year i.mode_base_month_num#i.year i.microregion_num#i.year"

	foreach outcome in lr_remdezr_layer l_layer_emp {

		di as text "  Outcome: `outcome' | Layer: `lv'"

		local extra "`cross_fe' ib0.`outcome'_pre4#i.year ib0.l_layer_emp_pre4#i.year ib0.layer_totalflows_pw_pre4#i.year"

		* ── Post-treatment DiD ───────────────────────────────────────────────
		reghdfe `outcome' c.layer_conn_norm##i.treat_year ///
			if `s_spill' & layer_id == "`lv'", ///
			absorb(`extra') vce(cluster identificad)

		local b_post  = _b[1.treat_year#c.layer_conn_norm]
		local se_post = _se[1.treat_year#c.layer_conn_norm]
		local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
		local n_obs   = e(N)
		local n_firms = e(N_clust)

		local st_post ""
		if `p_post' < 0.01                            local st_post "***"
		else if (`p_post' < 0.05 & `p_post' > 0.01)  local st_post "**"
		else if (`p_post' < 0.10 & `p_post' > 0.05)  local st_post "*"

		* ── Pre-period placebo ───────────────────────────────────────────────
		reghdfe `outcome' c.layer_conn_norm##i.placebo_year ///
			if `s_spill' & year <= 2011 & layer_id == "`lv'", ///
			absorb(`extra') vce(cluster identificad)

		local b_pre  = _b[1.placebo_year#c.layer_conn_norm]
		local se_pre = _se[1.placebo_year#c.layer_conn_norm]
		local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

		local st_pre ""
		if `p_pre' < 0.01                            local st_pre "***"
		else if (`p_pre' < 0.05 & `p_pre' > 0.01)   local st_pre "**"
		else if (`p_pre' < 0.10 & `p_pre' > 0.05)   local st_pre "*"

		* ── Event study + pre-trend F-test ──────────────────────────────────
		reghdfe `outcome' c.layer_conn_norm##ib2011.year ///
			if `s_spill' & layer_id == "`lv'", ///
			absorb(`extra') vce(cluster identificad)

		capture testparm c.layer_conn_norm#i(2009 2010).year
		local pre_pval = cond(_rc==0, r(p), .)

		* ── Count unique firm×layer cells; save firm IDs (first outcome only) ──
		tempvar in_samp cell_first
		gen byte `in_samp'   = e(sample)
		bys identificad layer_id (`in_samp'): ///
			gen byte `cell_first' = (_n == 1 & `in_samp' == 1)
		qui count if `cell_first' == 1
		local n_cells = r(N)

		* Save firm IDs for the firm-level check (only once per layer, using wages)
		if "`outcome'" == "lr_remdezr_layer" {
			preserve
				keep if `in_samp' == 1
				keep identificad
				duplicates drop
				save "$tables/layer_connectivity/06_diagnostics/firms_samp_`lv'.dta", replace
				di as result "  Saved `r(N)' firm IDs for layer `lv' → firms_samp_`lv'.dta"
			restore
		}

		cap drop `in_samp'
		cap drop `cell_first'

		* ── Write to CSV ─────────────────────────────────────────────────────
		local outcome_key "`outcome'_`lv'"
		tempname fh
		file open  `fh' using "`csv_out'", write append
		file write `fh' `""univariate_occ4";"cross_firm";"`outcome_key'";"main";"'    %9.4f (`b_post')  `"`st_post'"' _n
		file write `fh' `""univariate_occ4";"cross_firm";"`outcome_key'";"main_se";"' %9.4f (`se_post') `"""'         _n
		file write `fh' `""univariate_occ4";"cross_firm";"`outcome_key'";"pre";"'     %9.4f (`b_pre')   `"`st_pre'"'  _n
		file write `fh' `""univariate_occ4";"cross_firm";"`outcome_key'";"pre_se";"'  %9.4f (`se_pre')  `"""'         _n
		file write `fh' `""univariate_occ4";"cross_firm";"`outcome_key'";"n_obs";"'   %12.0fc (`n_obs')  `"""'        _n
		file write `fh' `""univariate_occ4";"cross_firm";"`outcome_key'";"n_firms";"' %12.0fc (`n_firms') `"""'       _n
		file write `fh' `""univariate_occ4";"cross_firm";"`outcome_key'";"n_cells";"' %12.0fc (`n_cells') `"""'       _n
		file write `fh' `""univariate_occ4";"cross_firm";"`outcome_key'";"pre_pval";"'%9.4f (`pre_pval') `"""'        _n
		file close `fh'

		* ── Event study plot ─────────────────────────────────────────────────
		estimates store _es_tmp
		local post_s   = string(`b_post',  "%9.4f")
		local se_s     = string(`se_post', "%9.4f")
		local pval_s   = string(`pre_pval',"%9.3f")

		coefplot _es_tmp, ///
			keep(*#c.layer_conn_norm) ///
			msymbol(diamond) ///
			coeflabels(2009.year#c.layer_conn_norm = "2009" ///
			           2010.year#c.layer_conn_norm = "2010" ///
			           2011.year#c.layer_conn_norm = "2011" ///
			           2012.year#c.layer_conn_norm = "2012" ///
			           2013.year#c.layer_conn_norm = "2013" ///
			           2014.year#c.layer_conn_norm = "2014" ///
			           2015.year#c.layer_conn_norm = "2015" ///
			           2016.year#c.layer_conn_norm = "2016") ///
			vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
			ytitle("Cross-firm spillover coef (`lv' layer)", size(small)) ///
			note("Pre-trend F-test p = `pval_s'  |  Post: `post_s' (`se_s')" ///
			     "Layer: `lv' | Outcome: `outcome'") ///
			graphregion(color(white)) bgcolor(white) ///
			ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)

		graph export "$graphs/layer_connectivity/06_diagnostics/es_`outcome'_`lv'_`d'.pdf", ///
			as(pdf) replace

		estimates drop _es_tmp

		di as result "  Done: `outcome' | `lv'"
	}

	cap drop layer_conn_norm
}

********************************************************************************
* SECTION 6: COMPLETION
********************************************************************************

di as result "Univariate per-layer regressions complete. Results in `csv_out'"

log close

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "06_diag done" "occ4 univariate per-layer complete"

********************************************************************************
* END OF DO-FILE
********************************************************************************
