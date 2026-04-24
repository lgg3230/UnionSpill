********************************************************************************
* UNION SPILLOVERS — HORSE RACE ACROSS BINARY LAYERS
*                                (LAYER-BALANCED PANEL)
* Purpose: Run the horse race with both layer-connectivity variables included
*          simultaneously for edu2, gender, and race, restricting to firms with
*          positive employment in all layers in all years 2009–2016.
*
* Outcomes (layer-level): lr_remdezr_layer, l_layer_emp
* Outcomes (firm-level):  lr_remdezr_w, l_firm_emp
*
* Output:  Tables/layer_connectivity/results_horse_race_binary_lbal.csv
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
log using "$logs/layer_connectivity/horse_race_binary_lbal_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
di "Stata version: `c(stata_version)'"

tempfile tfwide
import delimited "$rais_aux/totalflows_wide_2007_2011.csv", stringcols(1) clear
save `tfwide'
di as result "Saved totalflows_wide tempfile."

local csv_out "$tables/layer_connectivity/results_horse_race_binary_lbal.csv"
capture erase "`csv_out'"
tempname fh
file open `fh' using "`csv_out'", write replace
file write `fh' "spec;panel;section;outcome;row_type;value" _n
file close `fh'

foreach layer in edu2 gender race {

	di _newline(2)
	di as result "======================================================================="
	di as result "HORSE RACE PANEL: `layer'"
	di as result "======================================================================="

	if "`layer'" == "edu2" {
		local layer_vals "no_hs has_hs"
		local lv1 "no_hs"
		local lv2 "has_hs"
	}
	if "`layer'" == "gender" {
		local layer_vals "female male"
		local lv1 "female"
		local lv2 "male"
	}
	if "`layer'" == "race" {
		local layer_vals "white nonwhite"
		local lv1 "white"
		local lv2 "nonwhite"
	}
	local n_layers_expected : word count `layer_vals'

	use "$layer_data/firm_layer_outcomes_`layer'.dta", clear
	keep if year >= 2009

	count
	di as result "  Observations loaded: `r(N)'"

	cap drop n_yrs_layer
	cap drop tag_firm_layer
	cap drop n_layers_firm
	cap drop min_n_yrs_layer
	cap drop in_layer_balanced_panel
	bys identificad layer_id: egen n_yrs_layer = count(year)
	egen tag_firm_layer = tag(identificad layer_id)
	bys identificad: egen n_layers_firm = total(tag_firm_layer)
	bys identificad: egen min_n_yrs_layer = min(n_yrs_layer)
	gen byte in_layer_balanced_panel = ///
		(min_n_yrs_layer == 8 & n_layers_firm == `n_layers_expected')
	drop n_yrs_layer tag_firm_layer n_layers_firm min_n_yrs_layer
	label var in_layer_balanced_panel ///
		"Firm has pos. employment in all `layer' layers, all years 2009-2016"

	count if in_layer_balanced_panel == 1
	di as result "  Layer-balanced panel: `r(N)' obs"

	cap drop firm_id
	egen firm_id = group(identificad)

	cap drop firm_layer_id
	egen firm_layer_id = group(identificad layer_id)

	di as result "Merging layer connectivity..."
	merge m:1 identificad layer_id using ///
		"$layer_data/final_measures/firm_layer_connectivity_`layer'.dta", ///
		keep(master match) nogen

	count
	di as result "  After connectivity merge: `r(N)'"

	di as result "Merging firm-level controls..."
	merge m:1 identificad year using ///
		"$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", ///
		keepusing(treat_ultra in_balanced_panel lagos_sample_avg ///
		          industry1 mode_base_month microregion) ///
		keep(master match) nogen

	count
	di as result "  After firm merge: `r(N)'"

	keep if lagos_sample_avg == 1

	count
	di as result "  After sample restriction (lagos_sample_avg==1): `r(N)'"

	cap drop treat_year
	gen byte treat_year = (year >= 2012)
	cap drop placebo_year
	gen byte placebo_year = (year < 2011)

	local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1 & in_layer_balanced_panel==1"

	cap drop layer_conn_norm
	sum layer_treat_pw_n if `s_spill' & year == 2009, detail
	gen double layer_conn_norm = layer_treat_pw_n / r(p90)
	label var layer_conn_norm "Layer connectivity to treated (scaled to P90)"

	foreach lv of local layer_vals {
		cap drop c_`lv'_o
		cap drop c_`lv'
		gen double c_`lv'_o = layer_conn_norm if layer_id == "`lv'"
		bys identificad: egen c_`lv' = min(c_`lv'_o)
		drop c_`lv'_o
	}

	foreach v in lr_remdezr_layer l_layer_emp {
		cap drop `v'_pre_o
		cap drop `v'_pre
		bys identificad layer_id: egen `v'_pre_o = mean(`v') if inrange(year, 2009, 2011)
		bys identificad layer_id: egen `v'_pre = min(`v'_pre_o)
		drop `v'_pre_o

		cap drop `v'_pre4_o
		cap drop `v'_pre4
		egen `v'_pre4_o = cut(`v'_pre) if year == 2009 & in_balanced_panel == 1, group(4)
		bys identificad layer_id: egen `v'_pre4 = min(`v'_pre4_o)
		drop `v'_pre4_o
		replace `v'_pre4 = 0 if missing(`v'_pre4)
	}

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
		bys identificad layer_id: egen layer_totalflows_pw_pre4 = min(layer_totalflows_pw_pre4_o)
		drop layer_totalflows_pw_pre4_o
		replace layer_totalflows_pw_pre4 = 0 if missing(layer_totalflows_pw_pre4)
	}

	foreach outcome in lr_remdezr_layer l_layer_emp {

		di as text "  [Layer-level] Outcome: `outcome'"

		local extra "ib0.`outcome'_pre4#i.year ib0.l_layer_emp_pre4#i.year ib0.layer_totalflows_pw_pre4#i.year"

		foreach lv_o of local layer_vals {

			local outcome_key "`outcome'_`lv_o'"

			reghdfe `outcome' c.c_`lv1'##i.treat_year c.c_`lv2'##i.treat_year ///
				if treat_ultra==0 & in_balanced_panel==1 & in_layer_balanced_panel==1 & layer_id=="`lv_o'", ///
				absorb(i.firm_layer_id i.year `extra') vce(cluster identificad)

			local n_obs   = e(N)
			local n_firms = e(N_clust)

			local b_1_main  = _b[1.treat_year#c.c_`lv1']
			local se_1_main = _se[1.treat_year#c.c_`lv1']
			local p = 2*ttail(e(df_r), abs(`b_1_main'/`se_1_main'))
			local st_1_main ""
			if `p' < 0.01                          local st_1_main "***"
			else if (`p' < 0.05 & `p' > 0.01)     local st_1_main "**"
			else if (`p' < 0.10 & `p' > 0.05)     local st_1_main "*"

			local b_2_main  = _b[1.treat_year#c.c_`lv2']
			local se_2_main = _se[1.treat_year#c.c_`lv2']
			local p = 2*ttail(e(df_r), abs(`b_2_main'/`se_2_main'))
			local st_2_main ""
			if `p' < 0.01                          local st_2_main "***"
			else if (`p' < 0.05 & `p' > 0.01)     local st_2_main "**"
			else if (`p' < 0.10 & `p' > 0.05)     local st_2_main "*"

			reghdfe `outcome' c.c_`lv1'##i.placebo_year c.c_`lv2'##i.placebo_year ///
				if treat_ultra==0 & in_balanced_panel==1 & in_layer_balanced_panel==1 & year<=2011 & layer_id=="`lv_o'", ///
				absorb(i.firm_layer_id i.year `extra') vce(cluster identificad)

			local b_1_pre  = _b[1.placebo_year#c.c_`lv1']
			local se_1_pre = _se[1.placebo_year#c.c_`lv1']
			local p = 2*ttail(e(df_r), abs(`b_1_pre'/`se_1_pre'))
			local st_1_pre ""
			if `p' < 0.01                          local st_1_pre "***"
			else if (`p' < 0.05 & `p' > 0.01)     local st_1_pre "**"
			else if (`p' < 0.10 & `p' > 0.05)     local st_1_pre "*"

			local b_2_pre  = _b[1.placebo_year#c.c_`lv2']
			local se_2_pre = _se[1.placebo_year#c.c_`lv2']
			local p = 2*ttail(e(df_r), abs(`b_2_pre'/`se_2_pre'))
			local st_2_pre ""
			if `p' < 0.01                          local st_2_pre "***"
			else if (`p' < 0.05 & `p' > 0.01)     local st_2_pre "**"
			else if (`p' < 0.10 & `p' > 0.05)     local st_2_pre "*"

			reghdfe `outcome' c.c_`lv1'##ib2011.year c.c_`lv2'##ib2011.year ///
				if treat_ultra==0 & in_balanced_panel==1 & in_layer_balanced_panel==1 & layer_id=="`lv_o'", ///
				absorb(i.firm_layer_id i.year `extra') vce(cluster identificad)

			capture testparm c.c_`lv1'#i(2009 2010).year
			local pf_1 = cond(_rc==0, r(p), .)
			capture testparm c.c_`lv2'#i(2009 2010).year
			local pf_2 = cond(_rc==0, r(p), .)

			tempname fh
			file open `fh' using "`csv_out'", write append
			file write `fh' `""horse_race_binary_lbal";"`layer'";"layer_firm_year";"`outcome_key'";"c_`lv1'_main";"'      %9.4f (`b_1_main')  `"`st_1_main'"' _n
			file write `fh' `""horse_race_binary_lbal";"`layer'";"layer_firm_year";"`outcome_key'";"c_`lv1'_main_se";"'   %9.4f (`se_1_main') `"""'             _n
			file write `fh' `""horse_race_binary_lbal";"`layer'";"layer_firm_year";"`outcome_key'";"c_`lv2'_main";"'      %9.4f (`b_2_main')  `"`st_2_main'"' _n
			file write `fh' `""horse_race_binary_lbal";"`layer'";"layer_firm_year";"`outcome_key'";"c_`lv2'_main_se";"'   %9.4f (`se_2_main') `"""'             _n
			file write `fh' `""horse_race_binary_lbal";"`layer'";"layer_firm_year";"`outcome_key'";"c_`lv1'_pre";"'       %9.4f (`b_1_pre')   `"`st_1_pre'"' _n
			file write `fh' `""horse_race_binary_lbal";"`layer'";"layer_firm_year";"`outcome_key'";"c_`lv1'_pre_se";"'    %9.4f (`se_1_pre')  `"""'            _n
			file write `fh' `""horse_race_binary_lbal";"`layer'";"layer_firm_year";"`outcome_key'";"c_`lv2'_pre";"'       %9.4f (`b_2_pre')   `"`st_2_pre'"' _n
			file write `fh' `""horse_race_binary_lbal";"`layer'";"layer_firm_year";"`outcome_key'";"c_`lv2'_pre_se";"'    %9.4f (`se_2_pre')  `"""'            _n
			file write `fh' `""horse_race_binary_lbal";"`layer'";"layer_firm_year";"`outcome_key'";"c_`lv1'_pre_ftest";"' %9.4f (`pf_1')      `"""'            _n
			file write `fh' `""horse_race_binary_lbal";"`layer'";"layer_firm_year";"`outcome_key'";"c_`lv2'_pre_ftest";"' %9.4f (`pf_2')      `"""'            _n
			file write `fh' `""horse_race_binary_lbal";"`layer'";"layer_firm_year";"`outcome_key'";"n_obs";"'             %12.0fc (`n_obs')   `"""'             _n
			file write `fh' `""horse_race_binary_lbal";"`layer'";"layer_firm_year";"`outcome_key'";"n_firms";"'           %12.0fc (`n_firms') `"""'             _n
			file close `fh'
		}
	}

	preserve

		collapse (first) c_`lv1' c_`lv2' treat_ultra in_balanced_panel in_layer_balanced_panel ///
			industry1 mode_base_month microregion, by(identificad year)

		merge 1:1 identificad year using ///
			"$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", ///
			keepusing(l_firm_emp lr_remdezr_w) keep(match) nogen

		merge m:1 identificad using `tfwide', keep(master match) nogen

		cap drop firm_id
		egen firm_id = group(identificad)

		cap drop treat_year
		gen byte treat_year = (year >= 2012)
		cap drop placebo_year
		gen byte placebo_year = (year < 2011)

		local s_spill_f "treat_ultra==0 & in_balanced_panel==1 & in_layer_balanced_panel==1"

		foreach v in l_firm_emp lr_remdezr_w {
			cap drop `v'_pre_o
			cap drop `v'_pre
			cap drop `v'_pre4_o
			cap drop `v'_pre4
			bys identificad: egen `v'_pre_o = mean(`v') if inrange(year, 2009, 2011)
			bys identificad: egen `v'_pre = min(`v'_pre_o)
			drop `v'_pre_o
			egen `v'_pre4_o = cut(`v'_pre) if year==2009 & in_balanced_panel==1, group(4)
			bys identificad: egen `v'_pre4 = min(`v'_pre4_o)
			drop `v'_pre4_o
			replace `v'_pre4 = 0 if missing(`v'_pre4)
		}

		cap drop totalflows_pw_pre_07_11
		cap drop totalflows_pw_pre_07_11_cnt
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

		cap drop totalflows_pw_pre4_o
		cap drop totalflows_pw_pre4
		egen totalflows_pw_pre4_o = cut(totalflows_pw_pre_07_11) ///
			if year==2009 & in_balanced_panel==1, group(4)
		bys identificad: egen totalflows_pw_pre4 = min(totalflows_pw_pre4_o)
		drop totalflows_pw_pre4_o
		replace totalflows_pw_pre4 = 0 if missing(totalflows_pw_pre4)

		foreach outcome in lr_remdezr_w l_firm_emp {

			local extra_f "ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year ib0.totalflows_pw_pre4#i.year"

			reghdfe `outcome' c.c_`lv1'##i.treat_year c.c_`lv2'##i.treat_year ///
				if `s_spill_f', absorb(i.firm_id i.year `extra_f') vce(cluster identificad)

			local n_obs   = e(N)
			local n_firms = e(N_clust)

			local b_1_main  = _b[1.treat_year#c.c_`lv1']
			local se_1_main = _se[1.treat_year#c.c_`lv1']
			local p = 2*ttail(e(df_r), abs(`b_1_main'/`se_1_main'))
			local st_1_main ""
			if `p' < 0.01                          local st_1_main "***"
			else if (`p' < 0.05 & `p' > 0.01)     local st_1_main "**"
			else if (`p' < 0.10 & `p' > 0.05)     local st_1_main "*"

			local b_2_main  = _b[1.treat_year#c.c_`lv2']
			local se_2_main = _se[1.treat_year#c.c_`lv2']
			local p = 2*ttail(e(df_r), abs(`b_2_main'/`se_2_main'))
			local st_2_main ""
			if `p' < 0.01                          local st_2_main "***"
			else if (`p' < 0.05 & `p' > 0.01)     local st_2_main "**"
			else if (`p' < 0.10 & `p' > 0.05)     local st_2_main "*"

			reghdfe `outcome' c.c_`lv1'##i.placebo_year c.c_`lv2'##i.placebo_year ///
				if `s_spill_f' & year<=2011, absorb(i.firm_id i.year `extra_f') vce(cluster identificad)

			local b_1_pre  = _b[1.placebo_year#c.c_`lv1']
			local se_1_pre = _se[1.placebo_year#c.c_`lv1']
			local p = 2*ttail(e(df_r), abs(`b_1_pre'/`se_1_pre'))
			local st_1_pre ""
			if `p' < 0.01                          local st_1_pre "***"
			else if (`p' < 0.05 & `p' > 0.01)     local st_1_pre "**"
			else if (`p' < 0.10 & `p' > 0.05)     local st_1_pre "*"

			local b_2_pre  = _b[1.placebo_year#c.c_`lv2']
			local se_2_pre = _se[1.placebo_year#c.c_`lv2']
			local p = 2*ttail(e(df_r), abs(`b_2_pre'/`se_2_pre'))
			local st_2_pre ""
			if `p' < 0.01                          local st_2_pre "***"
			else if (`p' < 0.05 & `p' > 0.01)     local st_2_pre "**"
			else if (`p' < 0.10 & `p' > 0.05)     local st_2_pre "*"

			reghdfe `outcome' c.c_`lv1'##ib2011.year c.c_`lv2'##ib2011.year ///
				if `s_spill_f', absorb(i.firm_id i.year `extra_f') vce(cluster identificad)

			capture testparm c.c_`lv1'#i(2009 2010).year
			local pf_1 = cond(_rc==0, r(p), .)
			capture testparm c.c_`lv2'#i(2009 2010).year
			local pf_2 = cond(_rc==0, r(p), .)

			tempname fh
			file open `fh' using "`csv_out'", write append
			file write `fh' `""horse_race_binary_lbal";"`layer'";"firm_firm_year";"`outcome'";"c_`lv1'_main";"'      %9.4f (`b_1_main')  `"`st_1_main'"' _n
			file write `fh' `""horse_race_binary_lbal";"`layer'";"firm_firm_year";"`outcome'";"c_`lv1'_main_se";"'   %9.4f (`se_1_main') `"""'             _n
			file write `fh' `""horse_race_binary_lbal";"`layer'";"firm_firm_year";"`outcome'";"c_`lv2'_main";"'      %9.4f (`b_2_main')  `"`st_2_main'"' _n
			file write `fh' `""horse_race_binary_lbal";"`layer'";"firm_firm_year";"`outcome'";"c_`lv2'_main_se";"'   %9.4f (`se_2_main') `"""'             _n
			file write `fh' `""horse_race_binary_lbal";"`layer'";"firm_firm_year";"`outcome'";"c_`lv1'_pre";"'       %9.4f (`b_1_pre')   `"`st_1_pre'"' _n
			file write `fh' `""horse_race_binary_lbal";"`layer'";"firm_firm_year";"`outcome'";"c_`lv1'_pre_se";"'    %9.4f (`se_1_pre')  `"""'            _n
			file write `fh' `""horse_race_binary_lbal";"`layer'";"firm_firm_year";"`outcome'";"c_`lv2'_pre";"'       %9.4f (`b_2_pre')   `"`st_2_pre'"' _n
			file write `fh' `""horse_race_binary_lbal";"`layer'";"firm_firm_year";"`outcome'";"c_`lv2'_pre_se";"'    %9.4f (`se_2_pre')  `"""'            _n
			file write `fh' `""horse_race_binary_lbal";"`layer'";"firm_firm_year";"`outcome'";"c_`lv1'_pre_ftest";"' %9.4f (`pf_1')      `"""'            _n
			file write `fh' `""horse_race_binary_lbal";"`layer'";"firm_firm_year";"`outcome'";"c_`lv2'_pre_ftest";"' %9.4f (`pf_2')      `"""'            _n
			file write `fh' `""horse_race_binary_lbal";"`layer'";"firm_firm_year";"`outcome'";"n_obs";"'             %12.0fc (`n_obs')   `"""'             _n
			file write `fh' `""horse_race_binary_lbal";"`layer'";"firm_firm_year";"`outcome'";"n_firms";"'           %12.0fc (`n_firms') `"""'             _n
			file close `fh'
		}

	restore
}

di as result "Horse race binary (layer-balanced) regressions complete. Results in `csv_out'"

log close

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "Horse race binary lbal done" "13e_horse_race_binary_lbal.do complete"
