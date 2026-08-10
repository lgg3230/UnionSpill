********************************************************************************
* UNION SPILLOVERS — HORSE RACE (CROSS-FIRM FE, ABOVE-P25 BOTH LAYERS)
* Purpose: Same as 13e_horse_race_xfirm_abvmed.do but restricted to firms where
*          BOTH layers have average pre-treatment (2009-2011) employment above
*          the 25th percentile:
*            edu2:   no_hs  > 3.0,    has_hs > 7.333
*            gender: female > 3.667,  male   > 6.333
*            race:   nonwhite > 2.333, white > 7.0
*
* Identifies which layer's connectivity drives the effect by including both
* c_lv1 and c_lv2 simultaneously in the regression (cross-firm FE).
*
* Outcomes (layer-level): lr_remdezr_layer, l_layer_emp
* Outcomes (firm-level):  lr_remdezr_w, l_firm_emp
*
* Output (one CSV per layer):
*   Tables/layer_connectivity/results_horse_race_{edu2,gender,race}_xfirm_abvp25.csv
********************************************************************************

* ── Set globals ────────────────────────────────────────────────────────────────
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
log using "$logs/layer_connectivity/horse_race_xfirm_abvp25_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
di "Stata version: `c(stata_version)'"

********************************************************************************
* SECTION 1: LOAD TOTALFLOWS WIDE CSV INTO TEMPFILE
********************************************************************************

tempfile tfwide
import delimited "$rais_aux/totalflows_wide_2007_2011.csv", stringcols(1) clear
save `tfwide'
di as result "Saved totalflows_wide tempfile."

********************************************************************************
* SECTION 2: LOOP OVER LAYER DEFINITIONS
********************************************************************************

foreach layer in edu2 gender race {

	di _newline(2)
	di as result "======================================================================="
	di as result "LAYER: `layer'"
	di as result "======================================================================="

	* ── Layer-specific split labels and above-p25 thresholds ─────────────────
	if "`layer'" == "edu2" {
		local lv1      "no_hs"
		local lv2      "has_hs"
		local med_lv1  = 3.0
		local med_lv2  = 7.333333
	}
	if "`layer'" == "gender" {
		local lv1      "female"
		local lv2      "male"
		local med_lv1  = 3.666667
		local med_lv2  = 6.333333
	}
	if "`layer'" == "race" {
		local lv1      "nonwhite"
		local lv2      "white"
		local med_lv1  = 2.333333
		local med_lv2  = 7.0
	}

	****************************************************************************
	* SECTION 2a: LOAD AND PREPARE LAYER-LEVEL DATA
	****************************************************************************

	use "$layer_data/firm_layer_outcomes_`layer'.dta", clear
	keep if year >= 2009

	count
	di as result "  Observations loaded: `r(N)'"

	* ── Above-p25 both-layers restriction ────────────────────────────────────
	cap drop avg_pre_emp_o
	cap drop avg_pre_emp
	bys identificad layer_id: ///
		egen avg_pre_emp_o = mean(layer_emp) if inrange(year, 2009, 2011)
	bys identificad layer_id: ///
		egen avg_pre_emp   = min(avg_pre_emp_o)
	drop avg_pre_emp_o

	cap drop abv_lv1_o
	cap drop abv_lv1
	gen byte abv_lv1_o = (avg_pre_emp > `med_lv1') ///
		if layer_id == "`lv1'" & !missing(avg_pre_emp)
	bys identificad: egen abv_lv1 = max(abv_lv1_o)
	drop abv_lv1_o

	cap drop abv_lv2_o
	cap drop abv_lv2
	gen byte abv_lv2_o = (avg_pre_emp > `med_lv2') ///
		if layer_id == "`lv2'" & !missing(avg_pre_emp)
	bys identificad: egen abv_lv2 = max(abv_lv2_o)
	drop abv_lv2_o

	cap drop in_above_p25_both
	gen byte in_above_p25_both = (abv_lv1 == 1 & abv_lv2 == 1)
	drop avg_pre_emp abv_lv1 abv_lv2
	label var in_above_p25_both ///
		"Both layers above p25 pre-treatment emp (`lv1'>`med_lv1', `lv2'>`med_lv2')"

	count if in_above_p25_both == 1
	di as result "  Above-p25 both layers: `r(N)' obs"

	* Firm×layer unit ID (used in extra bin FEs)
	cap drop firm_layer_id
	egen firm_layer_id = group(identificad layer_id)

	* ── Merge layer connectivity ──────────────────────────────────────────────
	di as result "Merging layer connectivity..."
	merge m:1 identificad layer_id using ///
		"$layer_data/final_measures/firm_layer_connectivity_`layer'.dta", ///
		keep(master match) nogen

	count
	di as result "  After connectivity merge: `r(N)'"

	* ── Merge firm-level controls ─────────────────────────────────────────────
	di as result "Merging firm-level controls..."
	merge m:1 identificad year using ///
		"$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", ///
		keepusing(treat_ultra in_balanced_panel lagos_sample_avg ///
		          industry1 mode_base_month microregion) ///
		keep(master match) nogen

	count
	di as result "  After firm merge: `r(N)'"

	* ── Encode categorical FE variables ──────────────────────────────────────
	capture confirm string variable industry1
	if !_rc encode industry1,       gen(industry1_num)
	else     gen industry1_num     = industry1

	capture confirm string variable mode_base_month
	if !_rc encode mode_base_month, gen(mode_base_month_num)
	else     gen mode_base_month_num = mode_base_month

	capture confirm string variable microregion
	if !_rc encode microregion,     gen(microregion_num)
	else     gen microregion_num   = microregion

	* ── Sample restriction ────────────────────────────────────────────────────
	keep if lagos_sample_avg == 1

	count
	di as result "  After sample restriction (lagos_sample_avg==1): `r(N)'"

	****************************************************************************
	* SECTION 2b: VARIABLE CREATION
	****************************************************************************

	* Treatment indicators
	cap drop treat_year
	gen byte treat_year = (year >= 2012)
	label var treat_year "Post-treatment period (year >= 2012)"

	cap drop placebo_year
	gen byte placebo_year = (year < 2011)
	label var placebo_year "Pre-treatment placebo (year < 2011)"

	* Scale layer connectivity to P90 of untreated balanced-panel above-p25 firms at 2009
	local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1 & in_above_p25_both==1"

	cap drop layer_conn_norm
	sum layer_treat_pw_n if `s_spill' & year == 2009, detail
	gen double layer_conn_norm = layer_treat_pw_n / r(p90)
	label var layer_conn_norm "Layer connectivity to treated (scaled to P90)"

	* Broadcast each layer's connectivity to all obs in the firm
	cap drop c_`lv1'_o
	cap drop c_`lv1'
	gen double c_`lv1'_o = layer_conn_norm if layer_id == "`lv1'"
	bys identificad: egen c_`lv1' = min(c_`lv1'_o)
	drop c_`lv1'_o
	label var c_`lv1' "Firm-broadcast layer connectivity: `lv1'"

	cap drop c_`lv2'_o
	cap drop c_`lv2'
	gen double c_`lv2'_o = layer_conn_norm if layer_id == "`lv2'"
	bys identificad: egen c_`lv2' = min(c_`lv2'_o)
	drop c_`lv2'_o
	label var c_`lv2' "Firm-broadcast layer connectivity: `lv2'"

	* Pre-treatment layer-level outcome averages (within firm × layer)
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

	* Layer-level totalflows bins
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
	* SECTION 2c: INITIALIZE OUTPUT CSV
	****************************************************************************

	local csv_out "$tables/layer_connectivity/results_horse_race_`layer'_xfirm_abvp25.csv"
	capture erase "`csv_out'"
	tempname fh
	file open  `fh' using "`csv_out'", write replace
	file write `fh' "spec;section;outcome;row_type;value" _n
	file close `fh'

	di as result "Output CSV: `csv_out'"

	****************************************************************************
	* SECTION 2d: LAYER-LEVEL REGRESSIONS (cross-firm FE, horse race)
	****************************************************************************

	foreach outcome in lr_remdezr_layer l_layer_emp {

		di as text "  [Layer-level] Outcome: `outcome'"

		local extra "ib0.`outcome'_pre4#i.year ib0.l_layer_emp_pre4#i.year ib0.layer_totalflows_pw_pre4#i.year"
		local absorb "i.microregion_num#i.year i.industry1_num#i.year i.mode_base_month_num#i.year `extra'"

		foreach lv_o in `lv1' `lv2' {

			di as text "  Outcome layer: `lv_o'"

			local outcome_key "`outcome'_`lv_o'"

			* ── Post-treatment DiD ───────────────────────────────────────────
			reghdfe `outcome' c.c_`lv1'##i.treat_year c.c_`lv2'##i.treat_year ///
				if treat_ultra==0 & in_balanced_panel==1 & in_above_p25_both==1 & layer_id=="`lv_o'", ///
				absorb(`absorb') vce(cluster identificad)

			local n_obs   = e(N)
			local n_firms = e(N_clust)

			* c_lv1 main
			local b_lv1_main  = _b[1.treat_year#c.c_`lv1']
			local se_lv1_main = _se[1.treat_year#c.c_`lv1']
			local p  = 2*ttail(e(df_r), abs(`b_lv1_main'/`se_lv1_main'))
			local st_lv1_main ""
			if `p' < 0.01                          local st_lv1_main "***"
			else if (`p' < 0.05 & `p' > 0.01)     local st_lv1_main "**"
			else if (`p' < 0.10 & `p' > 0.05)     local st_lv1_main "*"

			* c_lv2 main
			local b_lv2_main  = _b[1.treat_year#c.c_`lv2']
			local se_lv2_main = _se[1.treat_year#c.c_`lv2']
			local p  = 2*ttail(e(df_r), abs(`b_lv2_main'/`se_lv2_main'))
			local st_lv2_main ""
			if `p' < 0.01                          local st_lv2_main "***"
			else if (`p' < 0.05 & `p' > 0.01)     local st_lv2_main "**"
			else if (`p' < 0.10 & `p' > 0.05)     local st_lv2_main "*"

			* ── Pre-period placebo ───────────────────────────────────────────
			reghdfe `outcome' c.c_`lv1'##i.placebo_year c.c_`lv2'##i.placebo_year ///
				if treat_ultra==0 & in_balanced_panel==1 & in_above_p25_both==1 & year<=2011 & layer_id=="`lv_o'", ///
				absorb(`absorb') vce(cluster identificad)

			* c_lv1 pre
			local b_lv1_pre  = _b[1.placebo_year#c.c_`lv1']
			local se_lv1_pre = _se[1.placebo_year#c.c_`lv1']
			local p  = 2*ttail(e(df_r), abs(`b_lv1_pre'/`se_lv1_pre'))
			local st_lv1_pre ""
			if `p' < 0.01                          local st_lv1_pre "***"
			else if (`p' < 0.05 & `p' > 0.01)     local st_lv1_pre "**"
			else if (`p' < 0.10 & `p' > 0.05)     local st_lv1_pre "*"

			* c_lv2 pre
			local b_lv2_pre  = _b[1.placebo_year#c.c_`lv2']
			local se_lv2_pre = _se[1.placebo_year#c.c_`lv2']
			local p  = 2*ttail(e(df_r), abs(`b_lv2_pre'/`se_lv2_pre'))
			local st_lv2_pre ""
			if `p' < 0.01                          local st_lv2_pre "***"
			else if (`p' < 0.05 & `p' > 0.01)     local st_lv2_pre "**"
			else if (`p' < 0.10 & `p' > 0.05)     local st_lv2_pre "*"

			* ── Event study + pre-trend F-tests ──────────────────────────────
			reghdfe `outcome' c.c_`lv1'##ib2011.year c.c_`lv2'##ib2011.year ///
				if treat_ultra==0 & in_balanced_panel==1 & in_above_p25_both==1 & layer_id=="`lv_o'", ///
				absorb(`absorb') vce(cluster identificad)

			capture testparm c.c_`lv1'#i(2009 2010).year
			local pf_lv1 = cond(_rc==0, r(p), .)

			capture testparm c.c_`lv2'#i(2009 2010).year
			local pf_lv2 = cond(_rc==0, r(p), .)

			* ── Write to CSV ──────────────────────────────────────────────────
			local spec_key "horse_race_`layer'_xfirm_abvp25"
			tempname fh
			file open  `fh' using "`csv_out'", write append
			file write `fh' `""`spec_key'";"layer_cross_firm";"`outcome_key'";"c_`lv1'_main";"'    %9.4f (`b_lv1_main')  `"`st_lv1_main'"' _n
			file write `fh' `""`spec_key'";"layer_cross_firm";"`outcome_key'";"c_`lv1'_main_se";"' %9.4f (`se_lv1_main') `"""'            _n
			file write `fh' `""`spec_key'";"layer_cross_firm";"`outcome_key'";"c_`lv2'_main";"'    %9.4f (`b_lv2_main')  `"`st_lv2_main'"' _n
			file write `fh' `""`spec_key'";"layer_cross_firm";"`outcome_key'";"c_`lv2'_main_se";"' %9.4f (`se_lv2_main') `"""'            _n
			file write `fh' `""`spec_key'";"layer_cross_firm";"`outcome_key'";"c_`lv1'_pre";"'     %9.4f (`b_lv1_pre')   `"`st_lv1_pre'"' _n
			file write `fh' `""`spec_key'";"layer_cross_firm";"`outcome_key'";"c_`lv1'_pre_se";"'  %9.4f (`se_lv1_pre')  `"""'            _n
			file write `fh' `""`spec_key'";"layer_cross_firm";"`outcome_key'";"c_`lv2'_pre";"'     %9.4f (`b_lv2_pre')   `"`st_lv2_pre'"' _n
			file write `fh' `""`spec_key'";"layer_cross_firm";"`outcome_key'";"c_`lv2'_pre_se";"'  %9.4f (`se_lv2_pre')  `"""'            _n
			file write `fh' `""`spec_key'";"layer_cross_firm";"`outcome_key'";"c_`lv1'_pre_ftest";"'  %9.4f (`pf_lv1')   `"""'            _n
			file write `fh' `""`spec_key'";"layer_cross_firm";"`outcome_key'";"c_`lv2'_pre_ftest";"'  %9.4f (`pf_lv2')   `"""'            _n
			file write `fh' `""`spec_key'";"layer_cross_firm";"`outcome_key'";"n_obs";"'            %12.0fc (`n_obs')    `"""'             _n
			file write `fh' `""`spec_key'";"layer_cross_firm";"`outcome_key'";"n_firms";"'          %12.0fc (`n_firms')  `"""'             _n
			file close `fh'

			di as result "    Done: outcome=`outcome_key'"
		}
	}

	****************************************************************************
	* SECTION 2e: FIRM-LEVEL REGRESSIONS (cross-firm FE, horse race)
	****************************************************************************

	preserve

		* Collapse to firm×year — c_lv*, in_above_p25_both are firm-constant
		collapse (first) c_`lv1' c_`lv2' treat_ultra in_balanced_panel in_above_p25_both ///
			industry1_num mode_base_month_num microregion_num, ///
			by(identificad year)

		* Merge firm-level outcomes
		merge 1:1 identificad year using ///
			"$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", ///
			keepusing(l_firm_emp lr_remdezr_w) ///
			keep(match) nogen

		* Merge pre-treatment totalflows
		merge m:1 identificad using `tfwide', keep(master match) nogen

		gen byte treat_year   = (year >= 2012)
		gen byte placebo_year = (year < 2011)

		local s_spill_f "treat_ultra==0 & in_balanced_panel==1 & in_above_p25_both==1"

		* Pre-treatment outcome bins
		foreach v in l_firm_emp lr_remdezr_w {
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

		* Totalflows quartile bins
		cap drop totalflows_pw_pre4_o
		cap drop totalflows_pw_pre4
		egen totalflows_pw_pre4_o = cut(totalflows_pw_pre_07_11) ///
			if year==2009 & in_balanced_panel==1, group(4)
		bys identificad: egen totalflows_pw_pre4 = min(totalflows_pw_pre4_o)
		drop totalflows_pw_pre4_o
		replace totalflows_pw_pre4 = 0 if missing(totalflows_pw_pre4)

		foreach outcome in lr_remdezr_w l_firm_emp {

			di as text "  [Firm-level] Outcome: `outcome'"

			local extra_f "ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year ib0.totalflows_pw_pre4#i.year"
			local absorb_f "i.microregion_num#i.year i.industry1_num#i.year i.mode_base_month_num#i.year `extra_f'"

			* ── Post-treatment DiD ───────────────────────────────────────────
			reghdfe `outcome' c.c_`lv1'##i.treat_year c.c_`lv2'##i.treat_year ///
				if `s_spill_f', ///
				absorb(`absorb_f') vce(cluster identificad)

			local n_obs   = e(N)
			local n_firms = e(N_clust)

			* c_lv1 main
			local b_lv1_main  = _b[1.treat_year#c.c_`lv1']
			local se_lv1_main = _se[1.treat_year#c.c_`lv1']
			local p  = 2*ttail(e(df_r), abs(`b_lv1_main'/`se_lv1_main'))
			local st_lv1_main ""
			if `p' < 0.01                          local st_lv1_main "***"
			else if (`p' < 0.05 & `p' > 0.01)     local st_lv1_main "**"
			else if (`p' < 0.10 & `p' > 0.05)     local st_lv1_main "*"

			* c_lv2 main
			local b_lv2_main  = _b[1.treat_year#c.c_`lv2']
			local se_lv2_main = _se[1.treat_year#c.c_`lv2']
			local p  = 2*ttail(e(df_r), abs(`b_lv2_main'/`se_lv2_main'))
			local st_lv2_main ""
			if `p' < 0.01                          local st_lv2_main "***"
			else if (`p' < 0.05 & `p' > 0.01)     local st_lv2_main "**"
			else if (`p' < 0.10 & `p' > 0.05)     local st_lv2_main "*"

			* ── Pre-period placebo ───────────────────────────────────────────
			reghdfe `outcome' c.c_`lv1'##i.placebo_year c.c_`lv2'##i.placebo_year ///
				if `s_spill_f' & year<=2011, ///
				absorb(`absorb_f') vce(cluster identificad)

			* c_lv1 pre
			local b_lv1_pre  = _b[1.placebo_year#c.c_`lv1']
			local se_lv1_pre = _se[1.placebo_year#c.c_`lv1']
			local p  = 2*ttail(e(df_r), abs(`b_lv1_pre'/`se_lv1_pre'))
			local st_lv1_pre ""
			if `p' < 0.01                          local st_lv1_pre "***"
			else if (`p' < 0.05 & `p' > 0.01)     local st_lv1_pre "**"
			else if (`p' < 0.10 & `p' > 0.05)     local st_lv1_pre "*"

			* c_lv2 pre
			local b_lv2_pre  = _b[1.placebo_year#c.c_`lv2']
			local se_lv2_pre = _se[1.placebo_year#c.c_`lv2']
			local p  = 2*ttail(e(df_r), abs(`b_lv2_pre'/`se_lv2_pre'))
			local st_lv2_pre ""
			if `p' < 0.01                          local st_lv2_pre "***"
			else if (`p' < 0.05 & `p' > 0.01)     local st_lv2_pre "**"
			else if (`p' < 0.10 & `p' > 0.05)     local st_lv2_pre "*"

			* ── Event study + pre-trend F-tests ──────────────────────────────
			reghdfe `outcome' c.c_`lv1'##ib2011.year c.c_`lv2'##ib2011.year ///
				if `s_spill_f', ///
				absorb(`absorb_f') vce(cluster identificad)

			capture testparm c.c_`lv1'#i(2009 2010).year
			local pf_lv1 = cond(_rc==0, r(p), .)

			capture testparm c.c_`lv2'#i(2009 2010).year
			local pf_lv2 = cond(_rc==0, r(p), .)

			* ── Write to CSV ──────────────────────────────────────────────────
			local spec_key "horse_race_`layer'_xfirm_abvp25"
			tempname fh
			file open  `fh' using "`csv_out'", write append
			file write `fh' `""`spec_key'";"firm_cross_firm";"`outcome'";"c_`lv1'_main";"'    %9.4f (`b_lv1_main')  `"`st_lv1_main'"' _n
			file write `fh' `""`spec_key'";"firm_cross_firm";"`outcome'";"c_`lv1'_main_se";"' %9.4f (`se_lv1_main') `"""'            _n
			file write `fh' `""`spec_key'";"firm_cross_firm";"`outcome'";"c_`lv2'_main";"'    %9.4f (`b_lv2_main')  `"`st_lv2_main'"' _n
			file write `fh' `""`spec_key'";"firm_cross_firm";"`outcome'";"c_`lv2'_main_se";"' %9.4f (`se_lv2_main') `"""'            _n
			file write `fh' `""`spec_key'";"firm_cross_firm";"`outcome'";"c_`lv1'_pre";"'     %9.4f (`b_lv1_pre')   `"`st_lv1_pre'"' _n
			file write `fh' `""`spec_key'";"firm_cross_firm";"`outcome'";"c_`lv1'_pre_se";"'  %9.4f (`se_lv1_pre')  `"""'            _n
			file write `fh' `""`spec_key'";"firm_cross_firm";"`outcome'";"c_`lv2'_pre";"'     %9.4f (`b_lv2_pre')   `"`st_lv2_pre'"' _n
			file write `fh' `""`spec_key'";"firm_cross_firm";"`outcome'";"c_`lv2'_pre_se";"'  %9.4f (`se_lv2_pre')  `"""'            _n
			file write `fh' `""`spec_key'";"firm_cross_firm";"`outcome'";"c_`lv1'_pre_ftest";"'  %9.4f (`pf_lv1')   `"""'            _n
			file write `fh' `""`spec_key'";"firm_cross_firm";"`outcome'";"c_`lv2'_pre_ftest";"'  %9.4f (`pf_lv2')   `"""'            _n
			file write `fh' `""`spec_key'";"firm_cross_firm";"`outcome'";"n_obs";"'            %12.0fc (`n_obs')    `"""'             _n
			file write `fh' `""`spec_key'";"firm_cross_firm";"`outcome'";"n_firms";"'          %12.0fc (`n_firms')  `"""'             _n
			file close `fh'

			di as result "    Done: firm-level outcome=`outcome'"
		}

	restore

	di as result "Layer `layer' complete. Results in `csv_out'"
}

********************************************************************************
* SECTION 3: COMPLETION
********************************************************************************

di as result "Horse race (cross-firm FE, above-p25) complete."

log close

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "Horse race xfirm abvp25 done" "13f: all layers complete"

********************************************************************************
* END OF DO-FILE
********************************************************************************
