********************************************************************************
* UNION SPILLOVERS — CROSS-LAYER SPILLOVER EFFECTS
* Purpose: Test whether connectivity of other layers within the same firm spills
*          over to a focal layer's outcomes.
*
*          For each outcome, two FE specifications:
*            (1) Base: firm×year FE
*            (2) Extended: firm×year FE + layer×year FE + firm×layer FE
*                - layer×year FE: controls for aggregate layer-level time shocks
*                - firm×layer FE: cross-section unit FE for the firm×layer panel
*
* Input:   Data/layer_connectivity/cross_layer_balanced_{layer}.dta
*          (produced by 10_cross_layer_prep.py)
*
* Output:  Tables/layer_connectivity/results_cross_layer_{layer}_layer_spill.csv
*          Graphs/layer_connectivity/es_{outcome}_cross_layer_{layer}_{date}.pdf
*
* Layers:  edu, edu2, gender, race
********************************************************************************

********************************************************************************
* SECTION 1: PATHS & GLOBALS
********************************************************************************

global main      "/kellogg/proj/lgg3230"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
global tables    "$main/UnionSpill/Tables"
global graphs    "$main/UnionSpill/Graphs"
global logs      "$main/UnionSpill/Logs"
global programs  "$main/UnionSpill/Programs"
global layer_data "$main/UnionSpill/Data/layer_connectivity"

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/layer_connectivity/05_cross_layer/cross_layer_spillover_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
di "Stata version: `c(stata_version)'"

local spec "layer_spill"

********************************************************************************
* SECTION 2: LOOP OVER LAYER DEFINITIONS
********************************************************************************

foreach layer in edu edu2 gender race {

	di _newline(2)
	di as result "======================================================================="
	di as result "CROSS-LAYER SPILLOVER — LAYER: `layer'"
	di as result "======================================================================="

	* ── 2a. Load balanced panel (built by 10_cross_layer_prep.py) ────────────
	use "$layer_data/cross_layer_balanced_`layer'.dta", clear
	keep if year >= 2009

	count
	di as result "  Observations loaded: `r(N)'"

	* ── 2b. Encode IDs for FE ─────────────────────────────────────────────────
	cap drop firm_id
	egen firm_id = group(identificad)

	* Numeric layer ID for layer×year and firm×layer FE
	cap drop layer_id_num
	egen layer_id_num = group(layer_id)

	* Firm×layer panel unit ID
	cap drop firm_layer_id
	egen firm_layer_id = group(identificad layer_id)

	* ── 2c. Sample restriction ───────────────────────────────────────────────
	local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

	count if `s_spill'
	di as result "  Spillover-sample obs: `r(N)'"

	****************************************************************************
	* SECTION 2d: VARIABLE CREATION
	****************************************************************************

	* ── Treatment period indicators ──────────────────────────────────────────
	cap drop treat_year
	gen byte treat_year = (year >= 2012)
	label var treat_year "Post-treatment period (year >= 2012)"

	cap drop placebo_year
	gen byte placebo_year = (year < 2011)
	label var placebo_year "Pre-treatment placebo (year < 2011)"

	* ── Connectivity scaling (P90 of spillover sample at 2009) ───────────────
	cap drop own_conn_norm
	sum layer_treat_pw_n if `s_spill' & year == 2009, detail
	local p90_own = r(p90)
	gen double own_conn_norm = layer_treat_pw_n / `p90_own'
	label var own_conn_norm "Own-layer connectivity (scaled to P90)"

	cap drop cross_conn_norm
	sum cross_conn if `s_spill' & year == 2009, detail
	local p90_cross = r(p90)
	gen double cross_conn_norm = cross_conn / `p90_cross'
	label var cross_conn_norm "Cross-layer connectivity (scaled to P90)"

	di as result "  P90 own_conn: `p90_own'   P90 cross_conn: `p90_cross'"

	* ── Pre-treatment layer-level outcome averages ───────────────────────────
	foreach v in lr_remdezr_layer lr_remdezr_h_layer l_layer_emp {
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

	* ── Layer-level totalflows bins ──────────────────────────────────────────
	capture confirm variable totalflows_layer_pw_n
	if _rc {
		di as error "WARNING: totalflows_layer_pw_n not found — using zero bins."
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

	di as result "All variables created."

	****************************************************************************
	* SECTION 2e: FE MACROS
	****************************************************************************

	* FE structure — both specs always include firm×layer FE (unit FE):
	*
	*   with_firmyr:  i.firm_layer_id + i.firm_id#i.year
	*                 Unit FE + firm×year FE (absorbs all firm-level time shocks)
	*                 Identification: within firm×year cross-layer variation
	*
	*   no_firmyr:    i.firm_layer_id + i.year
	*                 Unit FE + aggregate year FE only
	*                 Identification: cross-firm cross-layer variation over time

	local extra_year "ib0.layer_totalflows_pw_pre4#i.year"

	****************************************************************************
	* SECTION 2f: INITIALIZE OUTPUT CSV
	****************************************************************************

	local csv_out "$tables/layer_connectivity/05_cross_layer/results_cross_layer_`layer'_`spec'.csv"
	capture erase "`csv_out'"
	tempname fh
	file open  `fh' using "`csv_out'", write replace
	file write `fh' "spec,section,outcome,row_type,value" _n
	file close `fh'

	di as result "Output CSV: `csv_out'"

	****************************************************************************
	* SECTION 2g: REGRESSIONS — loop over outcomes, then over FE specs
	****************************************************************************

	di _newline(2)
	di as result "-----------------------------------------------------------------------"
	di as result "REGRESSIONS — layer: `layer'"
	di as result "-----------------------------------------------------------------------"

	foreach outcome in lr_remdezr_layer lr_remdezr_h_layer l_layer_emp {

		di as text "  Outcome: `outcome' (layer: `layer')"

		* ── (1) firm×layer FE + firm×year FE ────────────────────────────────
		* ── (2) firm×layer FE + year FE only ────────────────────────────────
		foreach fe_spec in with_firmyr no_firmyr {

			if "`fe_spec'" == "with_firmyr" {
				local absorb "i.firm_layer_id i.year i.firm_id#i.year ib0.`outcome'_pre4#i.year ib0.l_layer_emp_pre4#i.year `extra_year'"
				local section_label "with_firmyr"
			}
			else {
				local absorb "i.firm_layer_id i.year ib0.`outcome'_pre4#i.year ib0.l_layer_emp_pre4#i.year `extra_year'"
				local section_label "no_firmyr"
			}

			di as text "    FE spec: `section_label'"

			* ── Post-treatment spillover ──────────────────────────────────────
			reghdfe `outcome' ///
				c.own_conn_norm##i.treat_year ///
				c.cross_conn_norm##i.treat_year ///
				if `s_spill', ///
				absorb(`absorb') vce(cluster identificad)

			local b_own    = _b[1.treat_year#c.own_conn_norm]
			local se_own   = _se[1.treat_year#c.own_conn_norm]
			local p_own    = 2*ttail(e(df_r), abs(`b_own'/`se_own'))

			local b_cross  = _b[1.treat_year#c.cross_conn_norm]
			local se_cross = _se[1.treat_year#c.cross_conn_norm]
			local p_cross  = 2*ttail(e(df_r), abs(`b_cross'/`se_cross'))

			local n_obs    = e(N)
			local n_firms  = e(N_clust)

			* Count unique firm×layer cells
			tempvar in_samp cell_first
			gen byte `in_samp'   = e(sample)
			bys identificad layer_id (`in_samp'): ///
				gen byte `cell_first' = (_n == 1 & `in_samp' == 1)
			qui count if `cell_first' == 1
			local n_cells = r(N)
			cap drop `in_samp'
			cap drop `cell_first'

			* ── Pre-treatment placebo ─────────────────────────────────────────
			reghdfe `outcome' ///
				c.own_conn_norm##i.placebo_year ///
				c.cross_conn_norm##i.placebo_year ///
				if `s_spill' & year <= 2011, ///
				absorb(`absorb') vce(cluster identificad)

			local b_pre_own    = _b[1.placebo_year#c.own_conn_norm]
			local se_pre_own   = _se[1.placebo_year#c.own_conn_norm]
			local p_pre_own    = 2*ttail(e(df_r), abs(`b_pre_own'/`se_pre_own'))

			local b_pre_cross  = _b[1.placebo_year#c.cross_conn_norm]
			local se_pre_cross = _se[1.placebo_year#c.cross_conn_norm]
			local p_pre_cross  = 2*ttail(e(df_r), abs(`b_pre_cross'/`se_pre_cross'))

			* ── Event study for pre-trend F-tests ────────────────────────────
			reghdfe `outcome' ///
				c.own_conn_norm##ib2011.year ///
				c.cross_conn_norm##ib2011.year ///
				if `s_spill', ///
				absorb(`absorb') vce(cluster identificad)

			testparm c.cross_conn_norm#i(2009 2010).year
			local pre_ftest_pval = r(p)

			testparm c.own_conn_norm#i(2009 2010).year
			local pre_ftest_pval_own = r(p)

			* ── Stars ─────────────────────────────────────────────────────────
			foreach stub in own cross pre_own pre_cross {
				local stars_`stub' ""
				local p_val = `p_`stub''
				if `p_val' < 0.01                              local stars_`stub' "***"
				else if (`p_val' < 0.05 & `p_val' > 0.01)     local stars_`stub' "**"
				else if (`p_val' < 0.10 & `p_val' > 0.05)     local stars_`stub' "*"
			}

			* ── Write to CSV ──────────────────────────────────────────────────
			tempname fh
			file open  `fh' using "`csv_out'", write append
			file write `fh' `""cross_`layer'";"`section_label'";"`outcome'";"own_main";"'      %9.4f (`b_own')              `"`stars_own'""'     _n
			file write `fh' `""cross_`layer'";"`section_label'";"`outcome'";"own_main_se";"'   %9.4f (`se_own')             `"""'                _n
			file write `fh' `""cross_`layer'";"`section_label'";"`outcome'";"cross_main";"'    %9.4f (`b_cross')            `"`stars_cross'""'   _n
			file write `fh' `""cross_`layer'";"`section_label'";"`outcome'";"cross_main_se";"' %9.4f (`se_cross')           `"""'                _n
			file write `fh' `""cross_`layer'";"`section_label'";"`outcome'";"own_pre";"'       %9.4f (`b_pre_own')          `"`stars_pre_own'""' _n
			file write `fh' `""cross_`layer'";"`section_label'";"`outcome'";"own_pre_se";"'    %9.4f (`se_pre_own')         `"""'                _n
			file write `fh' `""cross_`layer'";"`section_label'";"`outcome'";"cross_pre";"'     %9.4f (`b_pre_cross')        `"`stars_pre_cross'""' _n
			file write `fh' `""cross_`layer'";"`section_label'";"`outcome'";"cross_pre_se";"'  %9.4f (`se_pre_cross')       `"""'                _n
			file write `fh' `""cross_`layer'";"`section_label'";"`outcome'";"n_obs";"'         %12.0fc (`n_obs')            `"""'                _n
			file write `fh' `""cross_`layer'";"`section_label'";"`outcome'";"n_firms";"'       %12.0fc (`n_firms')          `"""'                _n
			file write `fh' `""cross_`layer'";"`section_label'";"`outcome'";"n_cells";"'       %12.0fc (`n_cells')          `"""'                _n
			file write `fh' `""cross_`layer'";"`section_label'";"`outcome'";"pre_pval";"'      %9.4f (`pre_ftest_pval')     `"""'                _n
			file write `fh' `""cross_`layer'";"`section_label'";"`outcome'";"pre_pval_own";"'  %9.4f (`pre_ftest_pval_own') `"""'                _n
			file close `fh'

			* ── Event study plot (base spec only, cross_conn) ─────────────────
			if "`fe_spec'" == "base" {
				estimates store _es_tmp
				local pre_pval_s = string(`pre_ftest_pval', "%9.3f")
				local b_cross_s  = string(`b_cross',        "%9.4f")
				local se_cross_s = string(`se_cross',       "%9.4f")

				coefplot _es_tmp, ///
					keep(*#c.cross_conn_norm) ///
					msymbol(diamond) ///
					coeflabels(2009.year#c.cross_conn_norm = "2009" ///
					           2010.year#c.cross_conn_norm = "2010" ///
					           2011.year#c.cross_conn_norm = "2011" ///
					           2012.year#c.cross_conn_norm = "2012" ///
					           2013.year#c.cross_conn_norm = "2013" ///
					           2014.year#c.cross_conn_norm = "2014" ///
					           2015.year#c.cross_conn_norm = "2015" ///
					           2016.year#c.cross_conn_norm = "2016") ///
					vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
					ytitle("Cross-layer spillover coefficient", size(small)) ///
					note("Pre-trend F-test (cross) p = `pre_pval_s'  |  Post: `b_cross_s' (`se_cross_s')") ///
					graphregion(color(white)) bgcolor(white) ///
					ci(95) ciopts(recast(rcap) color(red)) mcolor(red)

				graph export "$graphs/layer_connectivity/05_cross_layer/es_`outcome'_cross_layer_`layer'_`d'.pdf", ///
					as(pdf) replace

				estimates drop _es_tmp
			}

			di as result "    Done: `section_label'"
		}

		di as result "  Outcome `outcome' complete."
	}

	di as result "Layer `layer' complete. Results in `csv_out'"
}

********************************************************************************
* SECTION 3: COMPLETION
********************************************************************************

log close
di as result "Finished: `c(current_date)' `c(current_time)'"

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "Cross-layer spillover done" "01_cross_layer.do complete — base + extended FE"

********************************************************************************
* END OF DO-FILE
********************************************************************************
