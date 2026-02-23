* ===============================
* START LOG FILE
* ===============================
capture log close
log using "$logs/AllSpecs_`c(current_date)'_`c(current_time)'.log", replace text

* Display session info
di "Started: `c(current_date)' `c(current_time)'"
di "Stata version: `c(stata_version)'"

********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR:  LUIS GOMES (+tidy skeleton)
* PROGRAM: GENERATE DISTRIBUTION STORY FOR ALL CONTROL SPECIFICATIONS
*          AND ALL CONNECTIVITY MEASURES
********************************************************************************

cls

use "$rais_firm/lagos_sample_sep24_pct_unionexp.dta", clear

* ===============================
* DEFINE ALL SPECIFICATIONS
* ===============================

* Control specifications:
* 1 = linear totalflows
* 2 = flows per worker (linear)
* 3 = quartiles of totalflows only
* 4 = deciles of totalflows only
* 5 = quartiles of totalflows + quartiles of pretreatment outcomes
* 6 = deciles of totalflows + deciles of pretreatment outcomes

local control_specs "1 2 3 4 5 6"

* Connectivity measures
local conn_measures "totaltreat_pw_norm totaltreat_pf_norm outtreat_pw_norm avg_ftreat_pf_norm"

* Labor outcomes (now including non-hourly wages)
local labor_outcomes "lr_remdezr lr_remdezr_h l_firm_emp p90p10_h_ratio_dec p90p10_ratio_dec p50p10_h_ratio_dec p50p10_ratio_dec lr_remdezr_h_p90 lr_remdezr_p90 lr_remdezr_h_p10 lr_remdezr_p10" 

local income_out "lr_remdezr_h"

* ===============================
* SAMPLES
* ===============================

local s_direct_all "(lagos_sample_avg==1 & treat_ultra==0  | lagos_sample_avg==1 & treat_ultra==1) & in_balanced_panel==1 "
local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

* ===============================
* DATA PREPARATION
* ===============================

keep if year>=2009
keep if lagos_sample_avg==1

* normalized perflow connectivity
cap drop totaltreat_pf_n_p90
cap drop totaltreat_pf_norm
sum totaltreat_pf_n if `s_spill' & year==2009, detail
gen totaltreat_pf_n_p90 = r(p90)
gen totaltreat_pf_norm = (totaltreat_pf_n / totaltreat_pf_n_p90) 

* normalized avg perflow connectivity
cap drop avg_ftreat_pf_n_p90
cap drop avg_ftreat_pf_norm
sum avg_ftreat_pf_n if `s_spill' & year==2009, detail
gen avg_ftreat_pf_n_p90 = r(p90)
gen avg_ftreat_pf_norm = (avg_ftreat_pf_n / avg_ftreat_pf_n_p90) 

* Totalflows per employee control (linear)
cap drop firm_emp_pre_o
cap drop firm_emp_pre
bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year,2009,2011)
bys identificad: egen firm_emp_pre = min(firm_emp_pre_o)
label var firm_emp_pre "average firm employment in the pre treatment period"
drop firm_emp_pre_o

cap drop flows_per_worker
gen flows_per_worker = totalflows_n/firm_emp_pre
label var flows_per_worker "worker flows per worker ratio"

* pretreatment outcomes
foreach outcome of local labor_outcomes{
	cap drop `outcome'_pre_o
	cap drop `outcome'_pre
	bys identificad: egen `outcome'_pre_o = mean(`outcome') if inrange(year, 2009,2011)
	bys identificad: egen `outcome'_pre = min(`outcome'_pre_o)
	label var `outcome'_pre "pretreatment `outcome' average"
	drop `outcome'_pre_o
}

* pretreatment numb_clauses
cap drop numb_clauses_pre_o
cap drop numb_clauses_pre
bys identificad: egen numb_clauses_pre_o = mean(numb_clauses) if inrange(cba_period,1,2)
bys identificad: egen numb_clauses_pre = min(numb_clauses_pre_o)
drop numb_clauses_pre_o

* quartiles and deciles of pretreatment outcomes and totalflows_n
foreach outcome of local labor_outcomes{
	foreach g in 4 10 {
		cap drop `outcome'_pre_q`g'_o
		cap drop `outcome'_pre_q`g'
		egen `outcome'_pre_q`g'_o = cut(`outcome'_pre) if year==2009 & in_balanced_panel==1, group(`g')
		bys identificad: egen `outcome'_pre_q`g' = min(`outcome'_pre_q`g'_o)
		label var `outcome'_pre_q`g' "`outcome' pretreatment `g' categories"
		drop `outcome'_pre_q`g'_o 
	}
}

* number of clauses quartiles/deciles
foreach g in 4 10 {
	cap drop numb_clauses_pre_q`g'_o
	cap drop numb_clauses_pre_q`g'
	egen numb_clauses_pre_q`g'_o = cut(numb_clauses_pre) if cba_period ==1 & in_balanced_panel==1, group(`g')
	bys identificad: egen numb_clauses_pre_q`g'= min(numb_clauses_pre_q`g'_o)
	label var numb_clauses_pre_q`g' "numb_clauses pretreatment `g' categories"
	drop numb_clauses_pre_q`g'_o
}

* totalflows_n quartiles/deciles
foreach g in 4 10 {
	cap drop totalflows_n`g'_o
	cap drop totalflows_n`g'
	egen totalflows_n`g'_o = cut(totalflows_n) if year==2009 & in_balanced_panel==1, group(`g')
	bys identificad: egen totalflows_n`g'= min(totalflows_n`g'_o)
	label var totalflows_n`g' "totalflows pretreatment `g' categories"
	drop totalflows_n`g'_o
}

********************************************************************************
* MAIN LOOP: ITERATE OVER CONNECTIVITY MEASURES AND CONTROL SPECIFICATIONS
********************************************************************************

foreach conn of local conn_measures {

local s_direct "(lagos_sample_avg==1 & treat_ultra==0 & `conn'<=0.01 | lagos_sample_avg==1 & treat_ultra==1) & in_balanced_panel==1 "


di _newline(3)
di as text "{hline 80}"
di as result "CONNECTIVITY MEASURE: `conn'"
di as text "{hline 80}"

foreach spec of local control_specs {

di _newline(2)
di as text "{hline 60}"
di as result "CONTROL SPECIFICATION: `spec'"
di as text "{hline 60}"

* ===============================
* DEFINE SPEC-SPECIFIC CONTROLS
* ===============================

if `spec' == 1 {
	local spec_suffix "linear_totalflows"
	local spec_suffix_cba "linear_totalflows"
	local base_controls "c.totalflows_n#year"
	local base_controls_cba "c.totalflows_n#cba_period"
	local use_outcome_controls = 0
	local g = 0
}
else if `spec' == 2 {
	local spec_suffix "flows_per_worker"
	local spec_suffix_cba "flows_per_worker"
	local base_controls "c.flows_per_worker#year"
	local base_controls_cba "c.flows_per_worker#cba_period"
	local use_outcome_controls = 0
	local g = 0
}
else if `spec' == 3 {
	local spec_suffix "q4_totalflows"
	local spec_suffix_cba "q4_totalflows"
	local base_controls "ib0.totalflows_n4#year"
	local base_controls_cba "ib0.totalflows_n4#cba_period"
	local use_outcome_controls = 0
	local g = 4
}
else if `spec' == 4 {
	local spec_suffix "q10_totalflows"
	local spec_suffix_cba "q10_totalflows"
	local base_controls "ib0.totalflows_n10#year"
	local base_controls_cba "ib0.totalflows_n10#cba_period"
	local use_outcome_controls = 0
	local g = 10
}
else if `spec' == 5 {
	local spec_suffix "q4_both"
	local spec_suffix_cba "q4_both"
	local base_controls "ib0.totalflows_n4#year"
	local base_controls_cba "ib0.totalflows_n4#cba_period"
	local use_outcome_controls = 1
	local g = 4
}
else if `spec' == 6 {
	local spec_suffix "q10_both"
	local spec_suffix_cba "q10_both"
	local base_controls "ib0.totalflows_n10#year"
	local base_controls_cba "ib0.totalflows_n10#cba_period"
	local use_outcome_controls = 1
	local g = 10
}

* ===============================
* SPILLOVER EFFECTS
* ===============================

foreach outcome of local labor_outcomes {
	eststo clear
	
	* Define outcome-specific controls
	if `use_outcome_controls' == 1 {
		local outcome_controls "ib0.`outcome'_pre_q`g'#year"
	}
	else if `spec' == 1 | `spec' == 2 {
		* Linear pretreatment outcome control
		local outcome_controls "c.`outcome'_pre#year"
	}
	else {
		* Specs 3-4: no outcome controls (only totalflows controls)
		local outcome_controls ""
	}
	
	* Define FE locals
	local post_tvfe "treat_year identificad industry1#year mode_base_month#year microregion#year `base_controls' `outcome_controls'"
	local pre_tvfe "placebo_year identificad industry1#year mode_base_month#year microregion#year `base_controls' `outcome_controls'"
	local es_tvfe "year identificad industry1#year mode_base_month#year microregion#year `base_controls' `outcome_controls'"
	
	di as text "  Spillover: `outcome' | Spec: `spec_suffix' | Conn: `conn'"
	
	* --- Post-treatment coefficient ---
	capture noisily eststo: reghdfe `outcome' ///
		c.`conn'##treat_year ///
		if `s_spill' & year>=2009, ///
		absorb(`post_tvfe') ///
		vce(cluster identificad)
	
	if _rc == 0 {
		local post_coef = string(_b[1.treat_year#c.`conn'], "%9.4f")
		local post_se  = string(_se[1.treat_year#c.`conn'], "%9.4f")
		local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_year#c.`conn']/_se[1.treat_year#c.`conn'])), "%9.4f")
	}
	else {
		local post_coef = "FAILED"
		local post_se = "."
		local post_pval = "."
		continue
	}
	
	* --- Pre-treatment (placebo) coefficient ---
	capture noisily eststo: reghdfe `outcome' c.`conn'##placebo_year if `s_spill' & year<=2011, ///
		absorb(`pre_tvfe') ///
		vce(cluster identificad)
	
	if _rc == 0 {
		local pre_coef = string(_b[1.placebo_year#c.`conn'], "%9.4f")
		local pre_pval = string(2*ttail(e(df_r), abs(_b[1.placebo_year#c.`conn']/_se[1.placebo_year#c.`conn'])), "%9.4f")
	}
	else {
		local pre_pval = "."
	}
	
	* --- Event study ---
	capture noisily reghdfe `outcome' c.`conn'##b(2011).year if `s_spill' & year>=2009, ///
		absorb(`es_tvfe') ///
		vce(cluster identificad)
	
	if _rc == 0 {
		estimates store es_spill_`outcome'
		
		coefplot es_spill_`outcome', ///
			keep(*#*c.`conn') ///
			msymbol(diamond) ///
			coeflabels(2009.year#c.`conn' = "2009" ///
					   2010.year#c.`conn' = "2010" ///
					   2011.year#c.`conn' = "2011" ///
					   2012.year#c.`conn' = "2012" ///
					   2013.year#c.`conn' = "2013" ///
					   2014.year#c.`conn' = "2014" ///
					   2015.year#c.`conn' = "2015" ///
					   2016.year#c.`conn' = "2016") ///
			vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
			ylabel(-.005(.005).02) ///
			ytitle("Dynamic DiD coefficients", size(small)) ///
			note("P-value for pre-trend test = `pre_pval' ") ///
			graphregion(color(white)) bgcolor(white) ///
			ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) ///
			text(.015 5 "`post_coef' (`post_se')", color(blue))
		graph export "$graphs/es_`outcome'_spill_`spec_suffix'_`conn'.pdf", as(pdf) replace
	}
}

* --- Spillover: Number of Clauses ---

* Define CBA FE locals
if `use_outcome_controls' == 1 {
	local outcome_controls_cba "ib0.numb_clauses_pre_q`g'#cba_period"
}
else if `spec' == 1 | `spec' == 2 {
	local outcome_controls_cba "c.numb_clauses_pre#cba_period"
}
else {
	local outcome_controls_cba ""
}

local post_tvfe_cba "post_treat_cba identificad industry1#cba_period mode_base_month#cba_period microregion#cba_period `base_controls_cba' `outcome_controls_cba'"
local pre_tvfe_cba "pre_treat_cba identificad industry1#cba_period mode_base_month#cba_period microregion#cba_period `base_controls_cba' `outcome_controls_cba'"
local es_tvfe_cba "cba_period identificad industry1#cba_period mode_base_month#cba_period microregion#cba_period `base_controls_cba' `outcome_controls_cba'"

di as text "  Spillover: numb_clauses | Spec: `spec_suffix' | Conn: `conn'"

capture noisily eststo: reghdfe numb_clauses c.`conn'##post_treat_cba if `s_spill' & !missing(cba_period), ///
	absorb(`post_tvfe_cba') ///
	vce(cluster identificad)

if _rc == 0 {
	local post_coef = string(_b[1.post_treat_cba#c.`conn'], "%9.3f")
	local post_se = string(_se[1.post_treat_cba#c.`conn'], "%9.3f")
	local post_pval = string(2*ttail(e(df_r), abs(_b[1.post_treat_cba#c.`conn']/_se[1.post_treat_cba#c.`conn'])), "%9.3f")
}
else {
	local post_coef = "FAILED"
	local post_se = "."
}

capture noisily eststo: reghdfe numb_clauses c.`conn'##pre_treat_cba if `s_spill' & !missing(cba_period) & cba_period<=2, ///
	absorb(`pre_tvfe_cba') ///
	vce(cluster identificad)

if _rc == 0 {
	local pre_coef = string(_b[1.pre_treat_cba#c.`conn'], "%9.2f")
	local pre_pval = string(2*ttail(e(df_r), abs(_b[1.pre_treat_cba#c.`conn']/_se[1.pre_treat_cba#c.`conn'])), "%9.2f")
}
else {
	local pre_pval = "."
}

capture noisily reghdfe numb_clauses c.`conn'##ib(2).cba_period if `s_spill' & !missing(cba_period), ///
	absorb(`es_tvfe_cba') ///
	vce(cluster identificad)

if _rc == 0 {
	estimates store es_clauses_spill
	
	coefplot es_clauses_spill, ///
		msymbol(square) ///
		keep(*.cba_period#c.`conn')  ///
		coeflabels(1.cba_period#c.`conn' = "2009" ///
				  2.cba_period#c.`conn' = "2010-2012" ///
				  3.cba_period#c.`conn'= "2013" ///
				  4.cba_period#c.`conn'= "2014" ///
				  5.cba_period#c.`conn' = "2015" ///
				  6.cba_period#c.`conn' = "2016") ///
		vert omitted baselevels yline(0) xline(2.5, lpattern(dash)) ///
		ytitle("Dynamic DiD coefficients", size(small)) ///
		note("P-value for pre-trend test = `pre_pval' ") ///
		graphregion(color(white)) bgcolor(white) ///
		ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) ///
		text(.6 4 "`post_coef' (`post_se')", color(blue)) 
	graph export "$graphs/es_numb_clauses_spill_`spec_suffix'_`conn'.pdf", as(pdf) replace
}


* ===============================
* DIRECT EFFECTS
* ===============================

foreach outcome of local labor_outcomes {
	eststo clear
	
	* Define outcome-specific controls
	if `use_outcome_controls' == 1 {
		local outcome_controls "ib0.`outcome'_pre_q`g'#year"
	}
	else if `spec' == 1 | `spec' == 2 {
		local outcome_controls "c.`outcome'_pre#year"
	}
	else {
		local outcome_controls ""
	}
	
	* Define FE locals
	local post_tvfe "treat_year identificad industry1#year mode_base_month#year microregion#year `base_controls' `outcome_controls'"
	local pre_tvfe "placebo_year identificad industry1#year mode_base_month#year microregion#year `base_controls' `outcome_controls'"
	local es_tvfe "year identificad industry1#year mode_base_month#year microregion#year `base_controls' `outcome_controls'"
	
	di as text "  Direct: `outcome' | Spec: `spec_suffix' | Conn: `conn'"
	
	* --- Post-treatment coefficient ---
	capture noisily eststo: reghdfe `outcome' treat_ultra##treat_year if `s_direct', ///
		absorb(`post_tvfe') ///
		vce(cluster identificad)
	
	if _rc == 0 {
		local post_coef = string(_b[1.treat_ultra#1.treat_year], "%9.3f")
		local post_se = string(_se[1.treat_ultra#1.treat_year], "%9.3f")
		local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_ultra#1.treat_year]/_se[1.treat_ultra#1.treat_year])), "%9.3f")
	}
	else {
		local post_coef = "FAILED"
		local post_se = "."
		local post_pval = "."
		continue
	}
	
	* --- Pre-treatment (placebo) coefficient ---
	capture noisily eststo: reghdfe `outcome' treat_ultra##placebo_year if `s_direct' & year<=2011, ///
		absorb(`pre_tvfe') ///
		vce(cluster identificad)
	
	if _rc == 0 {
		local pre_coef = string(_b[1.treat_ultra#1.placebo_year], "%9.3f")
		local pre_pval = string(2*ttail(e(df_r), abs(_b[1.treat_ultra#1.placebo_year]/_se[1.treat_ultra#1.placebo_year])), "%9.3f")
	}
	else {
		local pre_pval = "."
	}
	
	* --- Event study ---
	capture noisily reghdfe `outcome' treat_ultra##b(2011).year if `s_direct', ///
		absorb(`es_tvfe') ///
		vce(cluster identificad)
	
	if _rc == 0 {
		estimates store es_direct_`outcome'
		
		coefplot es_direct_`outcome', ///
			keep(1.treat_ultra#2009.year 1.treat_ultra#2010.year 1.treat_ultra#2011.year ///
				 1.treat_ultra#2012.year 1.treat_ultra#2013.year 1.treat_ultra#2014.year ///
				 1.treat_ultra#2015.year 1.treat_ultra#2016.year) ///
			coeflabels(1.treat_ultra#2009.year = "2009" ///
					   1.treat_ultra#2010.year = "2010" ///
					   1.treat_ultra#2011.year = "2011" ///
					   1.treat_ultra#2012.year = "2012" ///
					   1.treat_ultra#2013.year = "2013" ///
					   1.treat_ultra#2014.year = "2014" ///
					   1.treat_ultra#2015.year = "2015" ///
					   1.treat_ultra#2016.year = "2016") ///
			vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
			ylabel(-.02(.02).06) ///
			ytitle("Dynamic DiD coefficients", size(small)) ///
			note("P-value for pre-trend test = `pre_pval' ") ///
			graphregion(color(white)) bgcolor(white) ///
			ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) ///
			text(.05 6 "`post_coef' (`post_se')", color(blue)) 
		graph export "$graphs/es_`outcome'_treat_`spec_suffix'_`conn'.pdf", as(pdf) replace
	}
}

* --- Direct: Number of Clauses ---

* Define CBA FE locals
if `use_outcome_controls' == 1 {
	local outcome_controls_cba "ib0.numb_clauses_pre_q`g'#cba_period"
}
else if `spec' == 1 | `spec' == 2 {
	local outcome_controls_cba "c.numb_clauses_pre#cba_period"
}
else {
	local outcome_controls_cba ""
}

local post_tvfe_cba "post_treat_cba identificad industry1#cba_period mode_base_month#cba_period microregion#cba_period `base_controls_cba' `outcome_controls_cba'"
local pre_tvfe_cba "pre_treat_cba identificad industry1#cba_period mode_base_month#cba_period microregion#cba_period `base_controls_cba' `outcome_controls_cba'"
local es_tvfe_cba "cba_period identificad industry1#cba_period mode_base_month#cba_period microregion#cba_period `base_controls_cba' `outcome_controls_cba'"

di as text "  Direct: numb_clauses | Spec: `spec_suffix' | Conn: `conn'"

capture noisily eststo: reghdfe numb_clauses i.treat_ultra##post_treat_cba if `s_direct' & !missing(cba_period), ///
	absorb(`post_tvfe_cba') ///
	vce(cluster identificad)

if _rc == 0 {
	local post_coef = string(_b[1.treat_ultra#1.post_treat_cba], "%9.3f")
	local post_se = string(_se[1.treat_ultra#1.post_treat_cba], "%9.3f")
	local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_ultra#1.post_treat_cba]/_se[1.treat_ultra#1.post_treat_cba])), "%9.3f")
}
else {
	local post_coef = "FAILED"
	local post_se = "."
}

capture noisily eststo: reghdfe numb_clauses i.treat_ultra##pre_treat_cba if `s_direct' & !missing(cba_period) & cba_period<=2, ///
	absorb(`pre_tvfe_cba') ///
	vce(cluster identificad)

if _rc == 0 {
	local pre_coef = string(_b[1.treat_ultra#1.pre_treat_cba], "%9.3f")
	local pre_se = string(_se[1.treat_ultra#1.pre_treat_cba], "%9.3f")
	local pre_pval = string(2*ttail(e(df_r), abs(_b[1.treat_ultra#1.pre_treat_cba]/_se[1.treat_ultra#1.pre_treat_cba])),"%9.3f")
}
else {
	local pre_pval = "."
}

capture noisily reghdfe numb_clauses i.treat_ultra##ib(2).cba_period if `s_direct' & !missing(cba_period), ///
	absorb(`es_tvfe_cba') ///
	vce(cluster identificad)

if _rc == 0 {
	estimates store es_clauses_direct
	
	coefplot es_clauses_direct, ///
		msymbol(square) ///
		keep(1.treat_ultra#*.cba_period) ///
		coeflabels(1.treat_ultra#1.cba_period = "2009" ///
				  1.treat_ultra#2.cba_period = "2010-2012" ///
				  1.treat_ultra#3.cba_period = "2013" ///
				  1.treat_ultra#4.cba_period = "2014" ///
				  1.treat_ultra#5.cba_period = "2015" ///
				  1.treat_ultra#6.cba_period = "2016") ///
		vert omitted baselevels yline(0) xline(2.5, lpattern(dash)) ///
		ytitle("Dynamic DiD coefficients", size(small)) ///
		note("P-value for pre-trend test = `pre_pval' ") ///
		graphregion(color(white)) bgcolor(white) ///
		ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) ///
		text(2.5 4 "`post_coef' (`post_se')", color(blue)) 
	graph export "$graphs/es_numb_clauses_treat_`spec_suffix'_`conn'.pdf", as(pdf) replace
}


* ===============================
* UNION EFFECTS ROBUSTNESS
* ===============================

* Only run union robustness for primary outcome (lr_remdezr_h)
local outcome "lr_remdezr_h"

if `use_outcome_controls' == 1 {
	local outcome_controls "ib0.`outcome'_pre_q`g'#year"
}
else if `spec' == 1 | `spec' == 2 {
	local outcome_controls "c.`outcome'_pre#year"
}
else {
	local outcome_controls ""
}

local post_tvfe "treat_year identificad industry1#year mode_base_month#year microregion#year `base_controls' `outcome_controls'"
local pre_tvfe "placebo_year identificad industry1#year mode_base_month#year microregion#year `base_controls' `outcome_controls'"

di as text "  Union robustness | Spec: `spec_suffix' | Conn: `conn'"

* CONTROLLING FOR MODE UNION NON PARAMETRICALLY
capture noisily eststo : reghdfe `income_out' c.`conn'##i.treat_year if `s_spill' & year>=2009, ///
	absorb(`post_tvfe' mode_union#year) ///
	vce(cluster identificad)

capture noisily eststo : reghdfe `income_out' c.`conn'##i.placebo_year if `s_spill' & year<=2011 & year>=2009, ///
	absorb(`pre_tvfe' mode_union#year) ///
	vce(cluster identificad)

* CONTROLLING FOR UNION EXPOSITION TO TREATED FIRMS
capture noisily eststo : reghdfe `income_out' c.`conn'##i.treat_year if `s_spill' & year>=2009, ///
	absorb(`post_tvfe' c.treat_union_exp_all#year) ///
	vce(cluster identificad)

capture noisily eststo : reghdfe `income_out' c.`conn'##i.placebo_year if `s_spill' & year<=2011 & year>=2009, ///
	absorb(`pre_tvfe' c.treat_union_exp_all#year) ///
	vce(cluster identificad)

* CONTROLLING FOR UNION EXPOSITION TO TREATED WORKERS
capture noisily eststo : reghdfe `income_out' c.`conn'##i.treat_year if `s_spill' & year>=2009, ///
	absorb(`post_tvfe' c.union_emp_exp#year) ///
	vce(cluster identificad)

capture noisily eststo : reghdfe `income_out' c.`conn'##i.placebo_year if `s_spill' & year<=2011 & year>=2009, ///
	absorb(`pre_tvfe' c.union_emp_exp#year) ///
	vce(cluster identificad)


} // end of spec loop

} // end of conn loop


* ===============================
* END OF PROGRAM
* ===============================
di _newline(3)
di as text "{hline 80}"
di as result "PROGRAM COMPLETED SUCCESSFULLY"
di as text "Total specifications run: 6 control specs x 4 connectivity measures = 24"
di as text "Ended: `c(current_date)' `c(current_time)'"
di as text "{hline 80}"

log close
