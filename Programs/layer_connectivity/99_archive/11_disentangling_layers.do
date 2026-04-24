********************************************************************************
* UNION SPILLOVERS — DISENTANGLING LAYER-LEVEL SPILLOVER EFFECTS
* Purpose: Test spillover effects on firm×layer×year outcomes using one of the
*          layer-specific connectivity to treated firms as the treatment variable.
*          Identifies which layer's connecitiviyt is contributing to the effect.
*
* Layers:  edu    (3-bin: 0_no_hs / 1_hs / 2_higher)
*          edu2   (2-bin: no_hs / has_hs)
*          gender (female / male)
*          race   (white / nonwhite)
*
* Main FE: identificad × year  — absorbs all firm-level controls
* Other FE (layer-level, vary within firm×year):
*          outcome_pre4 × year, l_layer_emp_pre4 × year,
*          layer_totalflows_pw_pre4 × year
*
* Output:  Tables/layer_connectivity/results_spill_layer_{edu,edu2,gender,race}_disentangle.csv
*          Graphs/layer_connectivity/es_{outcome}_spill_{layer}_{date}_disentangle.pdf
********************************************************************************

* ── Set globals (safe to set unconditionally — same values as 00_master.do) ──
global main      "/kellogg/proj/lgg3230"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
global tables    "$main/UnionSpill/Tables"
global graphs    "$main/UnionSpill/Graphs"
global logs      "$main/UnionSpill/Logs"
global programs  "$main/UnionSpill/Programs"

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/layer_connectivity/disentangling_layers_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
di "Stata version: `c(stata_version)'"

global layer_data "$main/UnionSpill/Data/layer_connectivity"
local  spec       "layer_spill"

********************************************************************************
* SECTION 1b: LOAD TOTALFLOWS WIDE CSV INTO TEMPFILE (once, before layer loop)
* Cannot be loaded inside preserve block — Stata does not support nested preserve.
********************************************************************************

tempfile tfwide
import delimited "$rais_aux/totalflows_wide_2007_2011.csv", stringcols(1) clear
save `tfwide'
di as result "Saved totalflows_wide tempfile."

********************************************************************************
* SECTION 2: LOOP OVER LAYER DEFINITIONS
********************************************************************************

foreach layer in edu2 gender race {

* ── 2a. Load outcomes (firm × layer × year) ──────────────────────────────
	use "$layer_data/firm_layer_outcomes_`layer'.dta", clear
	keep if year >= 2009

count
	di as result "  Observations loaded: `r(N)'"

	* Create numeric firm ID for interaction FE
	cap drop firm_id
	egen firm_id = group(identificad)

	* Create firm×layer unit ID for cross-section FE
	cap drop firm_layer_id
	egen firm_layer_id = group(identificad layer_id)

	* ── 2b. Merge connectivity (firm × layer, time-invariant pre-treatment) ──
	di as result "Merging layer connectivity..."
	merge m:1 identificad layer_id using ///
		"$layer_data/final_measures/firm_layer_connectivity_`layer'.dta", ///
		keep(master match) nogen

	count
	di as result "  After connectivity merge: `r(N)'"

	* ── 2c. Merge firm-level controls (firm × year) ──────────────────────────
	di as result "Merging firm-level controls..."
	merge m:1 identificad year using ///
		"$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", ///
		keepusing(treat_ultra in_balanced_panel lagos_sample_avg ///
		          industry1 mode_base_month microregion) ///
		keep(master match) nogen

	count
	di as result "  After firm merge: `r(N)'"

	* ── Encode firm-level categorical FE variables (needed for cross-firm spec) ─
	capture confirm string variable industry1
	if !_rc encode industry1,       gen(industry1_num)
	else     gen industry1_num     = industry1

	capture confirm string variable mode_base_month
	if !_rc encode mode_base_month, gen(mode_base_month_num)
	else     gen mode_base_month_num = mode_base_month

	capture confirm string variable microregion
	if !_rc encode microregion,     gen(microregion_num)
	else     gen microregion_num   = microregion

	* ── 2d. Sample restriction ───────────────────────────────────────────────
	keep if lagos_sample_avg == 1

	count
	di as result "  After sample restriction (lagos_sample_avg==1): `r(N)'"

	****************************************************************************
	* SECTION 2e: VARIABLE CREATION
	****************************************************************************

	* ── Treatment period indicators ──────────────────────────────────────────
	cap drop treat_year
	gen byte treat_year = (year >= 2012)
	label var treat_year "Post-treatment period (year >= 2012)"

	cap drop placebo_year
	gen byte placebo_year = (year < 2011)
	label var placebo_year "Pre-treatment placebo (year < 2011)"

	* ── Layer connectivity scaling ───────────────────────────────────────────
	* Scale layer_treat_pw_n to P90 of untreated balanced-panel firms at 2009.
	* layer_conn_norm varies across layers within the same firm × year.
	local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

    cap drop layer_conn_norm
	sum layer_treat_pw_n if `s_spill' & year == 2009, detail
	gen double layer_conn_norm = layer_treat_pw_n / r(p90)
	label var layer_conn_norm "Layer connectivity to treated (scaled to P90)"

	* ── Broadcast each layer's connectivity to all obs in the firm ───────────
	* Cannot use firm×year FE because c_* are firm-level constants (same across
	* all layers within a firm×year). Identification comes from cross-firm DID.
	if "`layer'" == "edu2"   local layer_vals "no_hs has_hs"
	if "`layer'" == "gender" local layer_vals "female male"
	if "`layer'" == "race"   local layer_vals "white nonwhite"
	if "`layer'" == "edu"    local layer_vals "0_no_hs 1_hs 2_higher"

	foreach lv in `layer_vals' {
		cap drop c_`lv'_o
		cap drop c_`lv'
		gen double c_`lv'_o = layer_conn_norm if layer_id == "`lv'"
		bys identificad: egen c_`lv' = min(c_`lv'_o)
		cap drop c_`lv'_o
		label var c_`lv' "Firm-broadcast layer connectivity: `lv'"
	}
    * ── Pre-treatment layer-level outcome averages ───────────────────────────
	* Computed within firm × layer, so they vary across layers within a firm.
	* NOT absorbed by firm×year FE — used as additional within-firm controls.
	foreach v in lr_remdezr_layer lr_remdezr_h_layer l_layer_emp {
		cap drop `v'_pre_o
		cap drop `v'_pre
		bys identificad layer_id: ///
			egen `v'_pre_o = mean(`v') if inrange(year, 2009, 2011)
		bys identificad layer_id: ///
			egen `v'_pre   = min(`v'_pre_o)
		drop `v'_pre_o

		* 4-bin controls (balanced-panel firms at 2009, then propagate to all years)
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
	* totalflows_layer_pw_n: layer-specific movers per worker (pre-treatment avg).
	* Must exist in firm_layer_connectivity_{layer}.dta (requires pipeline re-run).
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
	* SECTION 2f: INITIALIZE OUTPUT CSV
	****************************************************************************

	local csv_out "$tables/layer_connectivity/results_disentangle_`layer'_`spec'.csv"
	capture erase "`csv_out'"
	tempname fh
	file open  `fh' using "`csv_out'", write replace
	file write `fh' "spec;section;outcome;row_type;value" _n
	file close `fh'

	di as result "Output CSV: `csv_out'"

	****************************************************************************
	* SECTION 2g: LAYER-LEVEL REGRESSIONS
	* For each regressor lv_r and outcome layer lv_o: regress layer outcome
	* restricted to layer_id == lv_o on c_lv_r. Own layer (lv_o == lv_r)
	* first, then cross-layer columns. FE: firm×layer FE + year FE
	* (≡ firm FE + year FE when restricted to one layer).
	****************************************************************************

	foreach outcome in lr_remdezr_layer lr_remdezr_h_layer l_layer_emp {

		di as text "  [Layer-level] Outcome: `outcome' (layer: `layer')"

		local extra "ib0.`outcome'_pre4#i.year ib0.l_layer_emp_pre4#i.year ib0.layer_totalflows_pw_pre4#i.year"

		foreach fe_spec in firm_year cross_firm {

			if "`fe_spec'" == "firm_year" {
				local absorb "i.firm_layer_id i.year `extra'"
				local section_label "layer_firm_year"
			}
			else {
				local absorb "i.microregion_num#i.year i.industry1_num#i.year i.mode_base_month_num#i.year `extra'"
				local section_label "layer_cross_firm"
			}

			foreach lv_r in `layer_vals' {

				foreach lv_o in `layer_vals' {

					di as text "    FE: `section_label'  reg: `lv_r'  out-layer: `lv_o'"

					* ── Post-treatment DiD ──────────────────────────────────
					reghdfe `outcome' c.c_`lv_r'##i.treat_year ///
						if treat_ultra==0 & in_balanced_panel==1 & layer_id=="`lv_o'", ///
						absorb(`absorb') vce(cluster identificad)

					local n_obs   = e(N)
					local n_firms = e(N_clust)
					local b_main  = _b[1.treat_year#c.c_`lv_r']
					local se_main = _se[1.treat_year#c.c_`lv_r']
					local p_main  = 2*ttail(e(df_r), abs(`b_main'/`se_main'))
					local st_main ""
					if `p_main' < 0.01                             local st_main "***"
					else if (`p_main' < 0.05 & `p_main' > 0.01)  local st_main "**"
					else if (`p_main' < 0.10 & `p_main' > 0.05)  local st_main "*"

					* ── Pre-trend placebo ───────────────────────────────────
					reghdfe `outcome' c.c_`lv_r'##i.placebo_year ///
						if treat_ultra==0 & in_balanced_panel==1 & year<=2011 & layer_id=="`lv_o'", ///
						absorb(`absorb') vce(cluster identificad)

					local b_pre  = _b[1.placebo_year#c.c_`lv_r']
					local se_pre = _se[1.placebo_year#c.c_`lv_r']
					local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))
					local st_pre ""
					if `p_pre' < 0.01                             local st_pre "***"
					else if (`p_pre' < 0.05 & `p_pre' > 0.01)   local st_pre "**"
					else if (`p_pre' < 0.10 & `p_pre' > 0.05)   local st_pre "*"

					* ── Event study + pre-trend F-test ─────────────────────
					reghdfe `outcome' c.c_`lv_r'##ib2011.year ///
						if treat_ultra==0 & in_balanced_panel==1 & layer_id=="`lv_o'", ///
						absorb(`absorb') vce(cluster identificad)

					testparm c.c_`lv_r'#i(2009 2010).year
					local pf = r(p)

					* ── Write to CSV ────────────────────────────────────────
					* outcome key = `outcome'_`lv_o' (outcome layer)
					* row_type    = c_`lv_r'_* (regressor)
					tempname fh
					file open  `fh' using "`csv_out'", write append
					file write `fh' `""disentangle_`layer'";"`section_label'";"`outcome'_`lv_o'";"c_`lv_r'_main";"'      %9.4f (`b_main')  `"`st_main'"' _n
					file write `fh' `""disentangle_`layer'";"`section_label'";"`outcome'_`lv_o'";"c_`lv_r'_main_se";"'   %9.4f (`se_main') `"""'        _n
					file write `fh' `""disentangle_`layer'";"`section_label'";"`outcome'_`lv_o'";"c_`lv_r'_pre";"'       %9.4f (`b_pre')   `"`st_pre'"' _n
					file write `fh' `""disentangle_`layer'";"`section_label'";"`outcome'_`lv_o'";"c_`lv_r'_pre_se";"'    %9.4f (`se_pre')  `"""'        _n
					file write `fh' `""disentangle_`layer'";"`section_label'";"`outcome'_`lv_o'";"c_`lv_r'_pre_ftest";"' %9.4f (`pf')      `"""'        _n
					file write `fh' `""disentangle_`layer'";"`section_label'";"`outcome'_`lv_o'";"c_`lv_r'_n_obs";"'   %12.0fc (`n_obs')   `"""'       _n
					file write `fh' `""disentangle_`layer'";"`section_label'";"`outcome'_`lv_o'";"c_`lv_r'_n_firms";"' %12.0fc (`n_firms') `"""'       _n
					file close `fh'

					di as result "      Done: `section_label' / reg=`lv_r' / out_layer=`lv_o'"
				}
			}
		}

		di as result "  Layer-level outcome `outcome' complete."
	}

	****************************************************************************
	* SECTION 2h: FIRM-LEVEL REGRESSIONS
	* Collapse to firm×year, merge firm-level outcomes, include all layers'
	* connectivity simultaneously. Cannot use firm×year FE (treatment is
	* time-invariant at the firm level). Uses firm FE + year FE.
	****************************************************************************

	preserve

		* Collapse to firm×year — c_* are firm-constant so (first) is exact
		collapse (first) c_* treat_ultra in_balanced_panel ///
			industry1_num mode_base_month_num microregion_num, ///
			by(identificad year)

		* Merge firm-level outcomes
		merge 1:1 identificad year using ///
			"$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", ///
			keepusing(l_firm_emp lr_remdezr_w lr_remdezr_h_w) ///
			keep(match) nogen

		* Merge pre-treatment totalflows (loaded into tempfile before preserve)
		merge m:1 identificad using `tfwide', keep(master match) nogen

		cap drop firm_id
		egen firm_id = group(identificad)

		gen byte treat_year   = (year >= 2012)
		gen byte placebo_year = (year < 2011)

		local s_spill_f "treat_ultra==0 & in_balanced_panel==1"

		* Pre-treatment outcome bins (firm-level)
		foreach v in l_firm_emp lr_remdezr_w lr_remdezr_h_w {
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

		* Build pre-treatment totalflows average from year-pair variables
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

		* Totalflows quartile bins (firm-level)
		cap drop totalflows_pw_pre4_o
		cap drop totalflows_pw_pre4
		egen totalflows_pw_pre4_o = cut(totalflows_pw_pre_07_11) ///
			if year==2009 & in_balanced_panel==1, group(4)
		bys identificad: egen totalflows_pw_pre4 = min(totalflows_pw_pre4_o)
		drop totalflows_pw_pre4_o
		replace totalflows_pw_pre4 = 0 if missing(totalflows_pw_pre4)

		foreach outcome in l_firm_emp lr_remdezr_w lr_remdezr_h_w {

			di as text "  [Firm-level] Outcome: `outcome' (layer: `layer')"

			local extra_f "ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year ib0.totalflows_pw_pre4#i.year"

			foreach fe_spec in firm_year cross_firm {

				if "`fe_spec'" == "firm_year" {
					local absorb_f "i.firm_id i.year `extra_f'"
					local section_label "firm_firm_year"
				}
				else {
					local absorb_f "i.microregion_num#i.year i.industry1_num#i.year i.mode_base_month_num#i.year `extra_f'"
					local section_label "firm_cross_firm"
				}

				foreach lv in `layer_vals' {

					di as text "    FE: `section_label'  focal layer: `lv'"

					* ── Post-treatment DiD ─────────────────────────────────
					reghdfe `outcome' c.c_`lv'##i.treat_year ///
						if `s_spill_f', ///
						absorb(`absorb_f') vce(cluster identificad)

					local n_obs   = e(N)
					local n_firms = e(N_clust)
					local b_main  = _b[1.treat_year#c.c_`lv']
					local se_main = _se[1.treat_year#c.c_`lv']
					local p_main  = 2*ttail(e(df_r), abs(`b_main'/`se_main'))
					local st_main ""
					if `p_main' < 0.01                             local st_main "***"
					else if (`p_main' < 0.05 & `p_main' > 0.01)  local st_main "**"
					else if (`p_main' < 0.10 & `p_main' > 0.05)  local st_main "*"

					* ── Pre-trend placebo ──────────────────────────────────
					reghdfe `outcome' c.c_`lv'##i.placebo_year ///
						if `s_spill_f' & year<=2011, ///
						absorb(`absorb_f') vce(cluster identificad)

					local b_pre  = _b[1.placebo_year#c.c_`lv']
					local se_pre = _se[1.placebo_year#c.c_`lv']
					local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))
					local st_pre ""
					if `p_pre' < 0.01                             local st_pre "***"
					else if (`p_pre' < 0.05 & `p_pre' > 0.01)   local st_pre "**"
					else if (`p_pre' < 0.10 & `p_pre' > 0.05)   local st_pre "*"

					* ── Event study + pre-trend F-test ────────────────────
					reghdfe `outcome' c.c_`lv'##ib2011.year ///
						if `s_spill_f', ///
						absorb(`absorb_f') vce(cluster identificad)

					testparm c.c_`lv'#i(2009 2010).year
					local pf = r(p)

					* ── Write to CSV ───────────────────────────────────────
					tempname fh
					file open  `fh' using "`csv_out'", write append
					file write `fh' `""disentangle_`layer'";"`section_label'";"`outcome'";"c_`lv'_main";"'       %9.4f (`b_main')  `"`st_main'"'  _n
					file write `fh' `""disentangle_`layer'";"`section_label'";"`outcome'";"c_`lv'_main_se";"'    %9.4f (`se_main') `"""'          _n
					file write `fh' `""disentangle_`layer'";"`section_label'";"`outcome'";"c_`lv'_pre";"'        %9.4f (`b_pre')   `"`st_pre'"'   _n
					file write `fh' `""disentangle_`layer'";"`section_label'";"`outcome'";"c_`lv'_pre_se";"'     %9.4f (`se_pre')  `"""'          _n
					file write `fh' `""disentangle_`layer'";"`section_label'";"`outcome'";"c_`lv'_pre_ftest";"'  %9.4f (`pf')      `"""'          _n
					file write `fh' `""disentangle_`layer'";"`section_label'";"`outcome'";"c_`lv'_n_obs";"'   %12.0fc (`n_obs')   `"""'          _n
					file write `fh' `""disentangle_`layer'";"`section_label'";"`outcome'";"c_`lv'_n_firms";"' %12.0fc (`n_firms') `"""'          _n
					file close `fh'

					di as result "      Done: `section_label' / `lv'"
				}
			}

			di as result "  Firm-level outcome `outcome' complete."
		}

	restore

	di as result "Layer `layer' complete. Results in `csv_out'"

} /* end foreach layer */

********************************************************************************
* SECTION 3: COMPLETION
********************************************************************************

log close

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "Disentangling layers done" "11_disentangling_layers.do complete"

********************************************************************************
* END OF DO-FILE
********************************************************************************


