********************************************************************************
* UNION SPILLOVERS — HORSE RACE: c_no_hs vs c_has_hs simultaneously
*                                (LAYER-BALANCED PANEL)
* Purpose: Horse race with stricter sample requiring positive employment in
*          BOTH layers in ALL years 2009–2016 (layer-balanced panel).
*
* Outcomes (layer-level): lr_remdezr_layer, l_layer_emp
* Outcomes (firm-level):  lr_remdezr_w, l_firm_emp
*
* FE: firm×layer FE + year FE (layer-level); firm FE + year FE (firm-level)
*
* Output:  Tables/layer_connectivity/results_horse_race_edu2_lbal.csv
********************************************************************************

* ── Set globals ───────────────────────────────────────────────────────────────
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
log using "$logs/layer_connectivity/horse_race_edu2_lbal_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
di "Stata version: `c(stata_version)'"

********************************************************************************
* SECTION 1: LOAD TOTALFLOWS WIDE CSV INTO TEMPFILE
* (Must be loaded before preserve block — Stata does not allow nested preserve)
********************************************************************************

tempfile tfwide
import delimited "$rais_aux/totalflows_wide_2007_2011.csv", stringcols(1) clear
save `tfwide'
di as result "Saved totalflows_wide tempfile."

********************************************************************************
* SECTION 2: LOAD AND PREPARE LAYER-LEVEL DATA
********************************************************************************

use "$layer_data/firm_layer_outcomes_edu2.dta", clear
keep if year >= 2009

count
di as result "  Observations loaded: `r(N)'"

* ── Layer-balanced panel indicator ───────────────────────────────────────────
* Firm must have positive employment in BOTH layers in ALL 8 years (2009–2016).
* Data is sparse: a row exists only when layer_emp > 0.
* So count of rows per firm per layer == number of years with positive employment.
cap drop n_yrs_no_hs
cap drop n_yrs_has_hs
cap drop in_layer_balanced_panel
bys identificad: egen n_yrs_no_hs  = total(layer_id == "no_hs")
bys identificad: egen n_yrs_has_hs = total(layer_id == "has_hs")
gen byte in_layer_balanced_panel = (n_yrs_no_hs == 8 & n_yrs_has_hs == 8)
cap drop n_yrs_no_hs
cap drop n_yrs_has_hs
label var in_layer_balanced_panel "Firm has pos. employment in both layers, all years 2009-2016"

count if in_layer_balanced_panel == 1
di as result "  Firms in layer-balanced panel: `r(N)' obs"

* Numeric firm ID for FE
cap drop firm_id
egen firm_id = group(identificad)

* Firm×layer unit ID
cap drop firm_layer_id
egen firm_layer_id = group(identificad layer_id)

* ── Merge layer connectivity ──────────────────────────────────────────────────
di as result "Merging layer connectivity..."
merge m:1 identificad layer_id using ///
	"$layer_data/final_measures/firm_layer_connectivity_edu2.dta", ///
	keep(master match) nogen

count
di as result "  After connectivity merge: `r(N)'"

* ── Merge firm-level controls ─────────────────────────────────────────────────
di as result "Merging firm-level controls..."
merge m:1 identificad year using ///
	"$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", ///
	keepusing(treat_ultra in_balanced_panel lagos_sample_avg ///
	          industry1 mode_base_month microregion) ///
	keep(master match) nogen

count
di as result "  After firm merge: `r(N)'"

* ── Sample restriction ────────────────────────────────────────────────────────
keep if lagos_sample_avg == 1

count
di as result "  After sample restriction (lagos_sample_avg==1): `r(N)'"

********************************************************************************
* SECTION 3: VARIABLE CREATION
********************************************************************************

* Treatment indicators
cap drop treat_year
gen byte treat_year = (year >= 2012)
label var treat_year "Post-treatment period (year >= 2012)"

cap drop placebo_year
gen byte placebo_year = (year < 2011)
label var placebo_year "Pre-treatment placebo (year < 2011)"

* Scale layer connectivity to P90 of untreated balanced-panel firms at 2009
local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

cap drop layer_conn_norm
sum layer_treat_pw_n if `s_spill' & year == 2009, detail
gen double layer_conn_norm = layer_treat_pw_n / r(p90)
label var layer_conn_norm "Layer connectivity to treated (scaled to P90)"

* Broadcast each layer's connectivity to all obs in the firm
foreach lv in no_hs has_hs {
	cap drop c_`lv'_o
	cap drop c_`lv'
	gen double c_`lv'_o = layer_conn_norm if layer_id == "`lv'"
	bys identificad: egen c_`lv' = min(c_`lv'_o)
	cap drop c_`lv'_o
	label var c_`lv' "Firm-broadcast layer connectivity: `lv'"
}

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

********************************************************************************
* SECTION 4: INITIALIZE OUTPUT CSV
********************************************************************************

local csv_out "$tables/layer_connectivity/results_horse_race_edu2_lbal.csv"
capture erase "`csv_out'"
tempname fh
file open  `fh' using "`csv_out'", write replace
file write `fh' "spec;section;outcome;row_type;value" _n
file close `fh'

di as result "Output CSV: `csv_out'"

********************************************************************************
* SECTION 5: LAYER-LEVEL REGRESSIONS (horse race — both c_no_hs and c_has_hs)
* Sample: treat_ultra==0 & in_balanced_panel==1 & in_layer_balanced_panel==1
********************************************************************************

foreach outcome in lr_remdezr_layer l_layer_emp {

	di as text "  [Layer-level] Outcome: `outcome'"

	local extra "ib0.`outcome'_pre4#i.year ib0.l_layer_emp_pre4#i.year ib0.layer_totalflows_pw_pre4#i.year"

	foreach lv_o in no_hs has_hs {

		di as text "  Outcome layer: `lv_o'"

		local outcome_key "`outcome'_`lv_o'"

		* ── Post-treatment DiD — both regressors simultaneously ──────────────
		reghdfe `outcome' c.c_no_hs##i.treat_year c.c_has_hs##i.treat_year ///
			if treat_ultra==0 & in_balanced_panel==1 & in_layer_balanced_panel==1 & layer_id=="`lv_o'", ///
			absorb(i.firm_layer_id i.year `extra') vce(cluster identificad)

		local n_obs   = e(N)
		local n_firms = e(N_clust)

		* c_no_hs main
		local b_no_hs_main  = _b[1.treat_year#c.c_no_hs]
		local se_no_hs_main = _se[1.treat_year#c.c_no_hs]
		local p  = 2*ttail(e(df_r), abs(`b_no_hs_main'/`se_no_hs_main'))
		local st_no_hs_main ""
		if `p' < 0.01                          local st_no_hs_main "***"
		else if (`p' < 0.05 & `p' > 0.01)     local st_no_hs_main "**"
		else if (`p' < 0.10 & `p' > 0.05)     local st_no_hs_main "*"

		* c_has_hs main
		local b_has_hs_main  = _b[1.treat_year#c.c_has_hs]
		local se_has_hs_main = _se[1.treat_year#c.c_has_hs]
		local p  = 2*ttail(e(df_r), abs(`b_has_hs_main'/`se_has_hs_main'))
		local st_has_hs_main ""
		if `p' < 0.01                          local st_has_hs_main "***"
		else if (`p' < 0.05 & `p' > 0.01)     local st_has_hs_main "**"
		else if (`p' < 0.10 & `p' > 0.05)     local st_has_hs_main "*"

		* ── Pre-period placebo ───────────────────────────────────────────────
		reghdfe `outcome' c.c_no_hs##i.placebo_year c.c_has_hs##i.placebo_year ///
			if treat_ultra==0 & in_balanced_panel==1 & in_layer_balanced_panel==1 & year<=2011 & layer_id=="`lv_o'", ///
			absorb(i.firm_layer_id i.year `extra') vce(cluster identificad)

		* c_no_hs pre
		local b_no_hs_pre  = _b[1.placebo_year#c.c_no_hs]
		local se_no_hs_pre = _se[1.placebo_year#c.c_no_hs]
		local p  = 2*ttail(e(df_r), abs(`b_no_hs_pre'/`se_no_hs_pre'))
		local st_no_hs_pre ""
		if `p' < 0.01                          local st_no_hs_pre "***"
		else if (`p' < 0.05 & `p' > 0.01)     local st_no_hs_pre "**"
		else if (`p' < 0.10 & `p' > 0.05)     local st_no_hs_pre "*"

		* c_has_hs pre
		local b_has_hs_pre  = _b[1.placebo_year#c.c_has_hs]
		local se_has_hs_pre = _se[1.placebo_year#c.c_has_hs]
		local p  = 2*ttail(e(df_r), abs(`b_has_hs_pre'/`se_has_hs_pre'))
		local st_has_hs_pre ""
		if `p' < 0.01                          local st_has_hs_pre "***"
		else if (`p' < 0.05 & `p' > 0.01)     local st_has_hs_pre "**"
		else if (`p' < 0.10 & `p' > 0.05)     local st_has_hs_pre "*"

		* ── Event study + pre-trend F-tests ─────────────────────────────────
		reghdfe `outcome' c.c_no_hs##ib2011.year c.c_has_hs##ib2011.year ///
			if treat_ultra==0 & in_balanced_panel==1 & in_layer_balanced_panel==1 & layer_id=="`lv_o'", ///
			absorb(i.firm_layer_id i.year `extra') vce(cluster identificad)

		capture testparm c.c_no_hs#i(2009 2010).year
		local pf_no_hs = cond(_rc==0, r(p), .)

		capture testparm c.c_has_hs#i(2009 2010).year
		local pf_has_hs = cond(_rc==0, r(p), .)

		* ── Write to CSV ─────────────────────────────────────────────────────
		tempname fh
		file open  `fh' using "`csv_out'", write append
		file write `fh' `""horse_race_edu2_lbal";"layer_firm_year";"`outcome_key'";"c_no_hs_main";"'    %9.4f (`b_no_hs_main')  `"`st_no_hs_main'"' _n
		file write `fh' `""horse_race_edu2_lbal";"layer_firm_year";"`outcome_key'";"c_no_hs_main_se";"' %9.4f (`se_no_hs_main') `"""'              _n
		file write `fh' `""horse_race_edu2_lbal";"layer_firm_year";"`outcome_key'";"c_has_hs_main";"'   %9.4f (`b_has_hs_main')  `"`st_has_hs_main'"' _n
		file write `fh' `""horse_race_edu2_lbal";"layer_firm_year";"`outcome_key'";"c_has_hs_main_se";"'%9.4f (`se_has_hs_main') `"""'              _n
		file write `fh' `""horse_race_edu2_lbal";"layer_firm_year";"`outcome_key'";"c_no_hs_pre";"'     %9.4f (`b_no_hs_pre')   `"`st_no_hs_pre'"' _n
		file write `fh' `""horse_race_edu2_lbal";"layer_firm_year";"`outcome_key'";"c_no_hs_pre_se";"'  %9.4f (`se_no_hs_pre')  `"""'              _n
		file write `fh' `""horse_race_edu2_lbal";"layer_firm_year";"`outcome_key'";"c_has_hs_pre";"'    %9.4f (`b_has_hs_pre')   `"`st_has_hs_pre'"' _n
		file write `fh' `""horse_race_edu2_lbal";"layer_firm_year";"`outcome_key'";"c_has_hs_pre_se";"' %9.4f (`se_has_hs_pre')  `"""'              _n
		file write `fh' `""horse_race_edu2_lbal";"layer_firm_year";"`outcome_key'";"c_no_hs_pre_ftest";"'  %9.4f (`pf_no_hs')   `"""'              _n
		file write `fh' `""horse_race_edu2_lbal";"layer_firm_year";"`outcome_key'";"c_has_hs_pre_ftest";"' %9.4f (`pf_has_hs')  `"""'              _n
		file write `fh' `""horse_race_edu2_lbal";"layer_firm_year";"`outcome_key'";"n_obs";"'           %12.0fc (`n_obs')    `"""'                  _n
		file write `fh' `""horse_race_edu2_lbal";"layer_firm_year";"`outcome_key'";"n_firms";"'         %12.0fc (`n_firms')  `"""'                  _n
		file close `fh'

		di as result "    Done: outcome=`outcome_key'"
	}
}

********************************************************************************
* SECTION 6: FIRM-LEVEL REGRESSIONS (horse race — both c_no_hs and c_has_hs)
********************************************************************************

preserve

	* Collapse to firm×year — c_* and flags are firm-constant so (first) is exact
	collapse (first) c_no_hs c_has_hs treat_ultra in_balanced_panel in_layer_balanced_panel ///
		industry1 mode_base_month microregion, ///
		by(identificad year)

	* Merge firm-level outcomes
	merge 1:1 identificad year using ///
		"$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", ///
		keepusing(l_firm_emp lr_remdezr_w) ///
		keep(match) nogen

	* Merge pre-treatment totalflows
	merge m:1 identificad using `tfwide', keep(master match) nogen

	cap drop firm_id
	egen firm_id = group(identificad)

	gen byte treat_year   = (year >= 2012)
	gen byte placebo_year = (year < 2011)

	local s_spill_f "treat_ultra==0 & in_balanced_panel==1 & in_layer_balanced_panel==1"

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

		* ── Post-treatment DiD ───────────────────────────────────────────────
		reghdfe `outcome' c.c_no_hs##i.treat_year c.c_has_hs##i.treat_year ///
			if `s_spill_f', ///
			absorb(i.firm_id i.year `extra_f') vce(cluster identificad)

		local n_obs   = e(N)
		local n_firms = e(N_clust)

		* c_no_hs main
		local b_no_hs_main  = _b[1.treat_year#c.c_no_hs]
		local se_no_hs_main = _se[1.treat_year#c.c_no_hs]
		local p  = 2*ttail(e(df_r), abs(`b_no_hs_main'/`se_no_hs_main'))
		local st_no_hs_main ""
		if `p' < 0.01                          local st_no_hs_main "***"
		else if (`p' < 0.05 & `p' > 0.01)     local st_no_hs_main "**"
		else if (`p' < 0.10 & `p' > 0.05)     local st_no_hs_main "*"

		* c_has_hs main
		local b_has_hs_main  = _b[1.treat_year#c.c_has_hs]
		local se_has_hs_main = _se[1.treat_year#c.c_has_hs]
		local p  = 2*ttail(e(df_r), abs(`b_has_hs_main'/`se_has_hs_main'))
		local st_has_hs_main ""
		if `p' < 0.01                          local st_has_hs_main "***"
		else if (`p' < 0.05 & `p' > 0.01)     local st_has_hs_main "**"
		else if (`p' < 0.10 & `p' > 0.05)     local st_has_hs_main "*"

		* ── Pre-period placebo ───────────────────────────────────────────────
		reghdfe `outcome' c.c_no_hs##i.placebo_year c.c_has_hs##i.placebo_year ///
			if `s_spill_f' & year<=2011, ///
			absorb(i.firm_id i.year `extra_f') vce(cluster identificad)

		* c_no_hs pre
		local b_no_hs_pre  = _b[1.placebo_year#c.c_no_hs]
		local se_no_hs_pre = _se[1.placebo_year#c.c_no_hs]
		local p  = 2*ttail(e(df_r), abs(`b_no_hs_pre'/`se_no_hs_pre'))
		local st_no_hs_pre ""
		if `p' < 0.01                          local st_no_hs_pre "***"
		else if (`p' < 0.05 & `p' > 0.01)     local st_no_hs_pre "**"
		else if (`p' < 0.10 & `p' > 0.05)     local st_no_hs_pre "*"

		* c_has_hs pre
		local b_has_hs_pre  = _b[1.placebo_year#c.c_has_hs]
		local se_has_hs_pre = _se[1.placebo_year#c.c_has_hs]
		local p  = 2*ttail(e(df_r), abs(`b_has_hs_pre'/`se_has_hs_pre'))
		local st_has_hs_pre ""
		if `p' < 0.01                          local st_has_hs_pre "***"
		else if (`p' < 0.05 & `p' > 0.01)     local st_has_hs_pre "**"
		else if (`p' < 0.10 & `p' > 0.05)     local st_has_hs_pre "*"

		* ── Event study + pre-trend F-tests ─────────────────────────────────
		reghdfe `outcome' c.c_no_hs##ib2011.year c.c_has_hs##ib2011.year ///
			if `s_spill_f', ///
			absorb(i.firm_id i.year `extra_f') vce(cluster identificad)

		capture testparm c.c_no_hs#i(2009 2010).year
		local pf_no_hs = cond(_rc==0, r(p), .)

		capture testparm c.c_has_hs#i(2009 2010).year
		local pf_has_hs = cond(_rc==0, r(p), .)

		* ── Write to CSV ─────────────────────────────────────────────────────
		tempname fh
		file open  `fh' using "`csv_out'", write append
		file write `fh' `""horse_race_edu2_lbal";"firm_firm_year";"`outcome'";"c_no_hs_main";"'    %9.4f (`b_no_hs_main')  `"`st_no_hs_main'"' _n
		file write `fh' `""horse_race_edu2_lbal";"firm_firm_year";"`outcome'";"c_no_hs_main_se";"' %9.4f (`se_no_hs_main') `"""'              _n
		file write `fh' `""horse_race_edu2_lbal";"firm_firm_year";"`outcome'";"c_has_hs_main";"'   %9.4f (`b_has_hs_main')  `"`st_has_hs_main'"' _n
		file write `fh' `""horse_race_edu2_lbal";"firm_firm_year";"`outcome'";"c_has_hs_main_se";"'%9.4f (`se_has_hs_main') `"""'              _n
		file write `fh' `""horse_race_edu2_lbal";"firm_firm_year";"`outcome'";"c_no_hs_pre";"'     %9.4f (`b_no_hs_pre')   `"`st_no_hs_pre'"' _n
		file write `fh' `""horse_race_edu2_lbal";"firm_firm_year";"`outcome'";"c_no_hs_pre_se";"'  %9.4f (`se_no_hs_pre')  `"""'              _n
		file write `fh' `""horse_race_edu2_lbal";"firm_firm_year";"`outcome'";"c_has_hs_pre";"'    %9.4f (`b_has_hs_pre')   `"`st_has_hs_pre'"' _n
		file write `fh' `""horse_race_edu2_lbal";"firm_firm_year";"`outcome'";"c_has_hs_pre_se";"' %9.4f (`se_has_hs_pre')  `"""'              _n
		file write `fh' `""horse_race_edu2_lbal";"firm_firm_year";"`outcome'";"c_no_hs_pre_ftest";"'  %9.4f (`pf_no_hs')   `"""'              _n
		file write `fh' `""horse_race_edu2_lbal";"firm_firm_year";"`outcome'";"c_has_hs_pre_ftest";"' %9.4f (`pf_has_hs')  `"""'              _n
		file write `fh' `""horse_race_edu2_lbal";"firm_firm_year";"`outcome'";"n_obs";"'           %12.0fc (`n_obs')    `"""'                  _n
		file write `fh' `""horse_race_edu2_lbal";"firm_firm_year";"`outcome'";"n_firms";"'         %12.0fc (`n_firms')  `"""'                  _n
		file close `fh'

		di as result "    Done: firm-level outcome=`outcome'"
	}

restore

********************************************************************************
* SECTION 7: COMPLETION
********************************************************************************

di as result "Horse race (layer-balanced) regressions complete. Results in `csv_out'"

log close

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "Horse race lbal done" "13c_horse_race_edu2_lbal.do complete"

********************************************************************************
* END OF DO-FILE
********************************************************************************
