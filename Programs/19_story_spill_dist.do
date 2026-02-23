* ===============================
* START LOG FILE
* ===============================
capture log close
log using "$logs/Specs_`c(current_date)'_`c(current_time)'.log", replace text

* Display session info
di "Started: `c(current_date)' `c(current_time)'"
di "Stata version: `c(stata_version)'"

********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR:  LUIS GOMES (+tidy skeleton)
* PROGRAM: GENERATE DISTRIBUTION STORY FOR DIFFERENT CONTROL SPECIFICATIONS
********************************************************************************





cls

// use "$rais_firm/lagos_sample_sep24_pct.dta", clear
// use "$rais_firm/lagos_sample_sep24_pct_unionexp.dta", clear

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext.dta", clear


* LOCALS *

* samples:

local s_direct "(lagos_sample_avg==1 & treat_ultra==0 & totaltreat_pw_n<=0.01 | lagos_sample_avg==1 & treat_ultra==1) & in_balanced_panel==1 "
local s_direct_all "(lagos_sample_avg==1 & treat_ultra==0  | lagos_sample_avg==1 & treat_ultra==1) & in_balanced_panel==1 "
local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

* fixed effects (outcome-independent only)

local labor_outcomes "lr_remdezr lr_remdezr_h l_firm_emp p90p10_h_ratio_dec p90p10_ratio_dec p50p10_h_ratio_dec p50p10_ratio_dec lr_remdezr_h_p90 lr_remdezr_p90 lr_remdezr_h_p10 lr_remdezr_p10 lr_remdezr_p25 lr_remdezr_p75 lr_remdezr_h_p25 lr_remdezr_h_p75 p75p25_ratio_dec p75p25_ratio_dec_h" 

local income_out "lr_remdezr_h"

* connectivity measure

local conn "totaltreat_pw_norm"
// local conn "outtreat_pw_norm"
// local conn "totaltreat_pf_norm"
// local conn "avg_ftreat_pf_norm"

// sum outtreat_pw_n totaltreat_pw_n if year==2009 & `s_spill', detail
//
// binscatter outtreat_pw_norm totaltreat_pw_norm if year==2009 & `s_spill', nquantiles(100)

* comparing distribution of outtreat with totaltreat_pw_norm

* GENERATE NECESSARY VARIABLES


keep if year>=2009

keep if lagos_sample_avg==1

// gen placebo_year = cond(year<2011, 1,0)


* cba periods

* Mark the CBA periods
cap drop cba_period
gen cba_period = .
replace cba_period = 1 if avg_file_date==earliest2009_avg-1 & !missing(avg_file_date) /* First 2009 CBA */
replace cba_period = 2 if avg_file_date==second_cba_avg & !missing(avg_file_date) /* First renewal */
replace cba_period = 3 if inrange(avg_file_date, mdy(1,1,2013), mdy(12,31,2013)) & cba_period==. /* 2013 CBA */
replace cba_period = 4 if inrange(avg_file_date, mdy(1,1,2014), mdy(12,31,2014)) & cba_period==. /* 2014 CBA */
replace cba_period = 5 if inrange(avg_file_date, mdy(1,1,2015), mdy(12,31,2015)) & cba_period==. /* 2015 CBA */
replace cba_period = 6 if inrange(avg_file_date, mdy(1,1,2016), mdy(12,31,2016)) & cba_period==. /* 2016 CBA */



cap drop pre_treat_cba
gen pre_treat_cba = cond(cba_period<2,1,0)


cap drop post_treat_cba
gen post_treat_cba = cond(cba_period>2,1,0) if !missing(cba_period)

* in and out flows per flow measures:
cap drop intreat_pf_n
cap drop outtreat_pf_n

gen intreat_pf_n = intreat_n/totalflows_n
gen outtreat_pf_n = outtreat_n/totalflows_n

local s_spill  "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0"

*  scalled measures

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year==2009, detail
gen totaltreat_pw_n_p90 = r(p90)
gen totaltreat_pw_norm = (totaltreat_pw_n / totaltreat_pw_n_p90) 

cap drop intreat_pw_n_p90
cap drop intreat_pw_norm
sum intreat_pw_n if `s_spill' & year==2009, detail
gen intreat_pw_n_p90 = r(p90)
gen intreat_pw_norm = (intreat_pw_n / intreat_pw_n_p90) 

cap drop outtreat_pw_n_p90
cap drop outtreat_pw_norm
sum outtreat_pw_n if `s_spill' & year==2009, detail
gen outtreat_pw_n_p90 = r(p90)
gen outtreat_pw_norm = (outtreat_pw_n / outtreat_pw_n_p90) 

* ratios

cap drop p75p25_ratio_dec
gen p75p25_ratio_dec = lr_remdezr_p75 - lr_remdezr_p25
label var p75p25_ratio_dec " log ratio of 75th percentile and 25th percentile"


cap drop p75p25_ratio_dec_h
gen p75p25_ratio_dec_h = lr_remdezr_h_p75 - lr_remdezr_h_p25
label var p75p25_ratio_dec_h "log ratio of 75th and 25th percentiles (lr_remdezr_h)"

cap drop p90p10_ratio_dec
gen p90p10_ratio_dec = lr_remdezr_p90-lr_remdezr_p10
label var p90p10_ratio_dec "90 10 log wage ratio , december wages"

cap drop p50p10_ratio_dec
gen p50p10_ratio_dec  = lr_remdezr_p50 - lr_remdezr_p10
label var p90p10_ratio_dec "50 10 log wage ratio , december wages"

cap drop p90p10_h_ratio_dec
gen p90p10_h_ratio_dec = lr_remdezr_h_p90-lr_remdezr_h_p10
label var p90p10_h_ratio_dec "90 10 log hourly wage ratio , december wages"

cap drop p50p10_h_ratio_dec
gen p50p10_h_ratio_dec  = lr_remdezr_h_p50 - lr_remdezr_h_p10
label var p90p10_h_ratio_dec "50 10 log hourly wage ratio , december wages"


* union exposition to treatment

bys mode_union (year): egen treat_union_exp = mean(treat_ultra)


gen union_has_treated = cond(treat_union_exp_all>0,1,0 )
label var union_has_treated "union representing estab represents at least one estab in treatment"

sum treat_union_exp_all if year ==2009 & lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0, detail
gen union_exp_med = r(p50)
gen union_exp_am = cond(treat_union_exp_all>=union_exp_med,1,0)

* normalized perflow connectivity

cap drop totaltreat_pf_n_p90
cap drop totaltreat_pf_norm
sum totaltreat_pf_n if `s_spill' & year==2009, detail
gen totaltreat_pf_n_p90 = r(p90)
gen totaltreat_pf_norm = (totaltreat_pf_n / totaltreat_pf_n_p90) 

* normalized perflow connectivity avg_ftreat_pf_n measures

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

* pretreatment numb_clauses (averaged over cba periods 1-2)
cap drop numb_clauses_pre_o
cap drop numb_clauses_pre
bys identificad: egen numb_clauses_pre_o = mean(numb_clauses) if inrange(cba_period,1,2)
bys identificad: egen numb_clauses_pre = min(numb_clauses_pre_o)
drop numb_clauses_pre_o

* quartiles, quintiles, deciles and vingtiles of pretreatment outcomes and totalflows_n


** labor outcomes
foreach outcome of local labor_outcomes{
	foreach g in 4 5 10 20 {
		cap drop `outcome'_pre_q`g'_o
		cap drop `outcome'_pre_q`g'
		egen `outcome'_pre_q`g'_o = cut(`outcome'_pre) if year==2009 & in_balanced_panel==1, group(`g')
		bys identificad: egen `outcome'_pre_q`g' = min(`outcome'_pre_q`g'_o)
		label var `outcome'_pre_q`g' "`outcome' pretreatment `g' categories"
		drop `outcome'_pre_q`g'_o 
	}
}

** number of clauses
foreach g in 4 5 10 20 {
	cap drop numb_clauses_pre_q`g'_o
	cap drop numb_clauses_pre_q`g'
	egen numb_clauses_pre_q`g'_o = cut(numb_clauses_pre) if cba_period ==1 & in_balanced_panel==1, group(`g')
	bys identificad: egen numb_clauses_pre_q`g'= min(numb_clauses_pre_q`g'_o)
	label var numb_clauses_pre_q`g' "numb_clauses pretreatment `g' categories"
	drop numb_clauses_pre_q`g'_o
}

** totalflows_n
foreach g in 4 5 10 20 {
	cap drop totalflows_n`g'_o
	cap drop totalflows_n`g'
	egen totalflows_n`g'_o = cut(totalflows_n) if year==2009 & in_balanced_panel==1, group(`g')
	bys identificad: egen totalflows_n`g'= min(totalflows_n`g'_o)
	label var totalflows_n`g' "numb_clauses pretreatment `g' categories"
	drop totalflows_n`g'_o
}

* Spillover EFFECTS *

* ===============================
* Spillover effects: pre/post coeffs
* ===============================
// foreach g in 4 5 10 20 {
 foreach outcome of local labor_outcomes{
 eststo clear
 
 * Define FE locals inside the loop so `outcome' and `g' have values
 local post_tvfe "treat_year identificad industry1#year mode_base_month#year microregion#year c.`outcome'_pre#year c.totalflows_n#year"
 local pre_tvfe "placebo_year identificad industry1#year mode_base_month#year microregion#year c.`outcome'_pre#year c.totalflows_n#year"
 local es_tvfe "year identificad industry1#year mode_base_month#year microregion#year c.`outcome'_pre#year c.totalflows#year"
 
 // run regressions for each outcome
 // store all regressions in a separate folder for each control

* --- Post-treatment coefficient (treat_ultra × Post) ---
eststo: reghdfe `outcome' ///
		c.`conn'##treat_year ///
		if `s_spill' & year>=2009, ///
        absorb(`post_tvfe') ///
        vce(cluster identificad)

		// Extract post-treatment coefficient and p-value
local post_coef = string(_b[1.treat_year#c.`conn'], "%9.4f")
local post_se  = string(_se[1.treat_year#c.`conn'], "%9.4f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_year#c.`conn']/_se[1.treat_year#c.`conn'])), "%9.4f")

* --- Pre-treatment (placebo) coefficient (treat_ultra × Pre) ---
eststo: reghdfe `outcome' c.`conn'##placebo_year if `s_spill' & year<=2011, ///
        absorb(`pre_tvfe') ///
        vce(cluster identificad)

// Extract pre-treatment coefficient and p-value
local pre_coef = string(_b[1.placebo_year#c.`conn'], "%9.4f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.placebo_year#c.`conn']/_se[1.placebo_year#c.`conn'])), "%9.4f")

* ===============================
* Spillover effects: event study plot
* ===============================
reghdfe `outcome' c.`conn'##b(2011).year if `s_spill' & year>=2009, ///
        absorb(`es_tvfe') ///
        vce(cluster identificad)
estimates store es_spill_remmedr

coefplot es_spill_remmedr, ///
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
graph export "$graphs/es_`outcome'_spill_`outcome'_pre_totalflows_linear_pw.pdf", as(pdf) replace
 }

* CBA CLAUSES

* Define CBA FE locals for numb_clauses
local post_tvfe_cba "post_treat_cba identificad industry1#cba_period mode_base_month#cba_period microregion#cba_period c.numb_clauses_pre#cba_period c.totalflows_n#cba_period"
local pre_tvfe_cba "pre_treat_cba identificad industry1#cba_period mode_base_month#cba_period microregion#cba_period c.numb_clauses_pre#cba_period c.totalflows_n#cba_period"
local es_tvfe_cba "cba_period identificad industry1#cba_period mode_base_month#cba_period microregion#cba_period c.numb_clauses_pre#cba_period c.totalflows_n#cba_period"

* --- Post-treatment coefficient (connectivity × Post) ---
// Spillover Effect on Number of Clauses
// post treat coefficient
eststo: reghdfe numb_clauses c.`conn'##post_treat_cba if `s_spill' & !missing(cba_period), ///
        absorb(`post_tvfe_cba') ///
        vce(cluster identificad)

// Extract post-treatment coefficient and p-value
local post_coef = string(_b[1.post_treat_cba#c.`conn'], "%9.4f")
local post_se = string(_se[1.post_treat_cba#c.`conn'], "%9.4f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.post_treat_cba#c.`conn']/_se[1.post_treat_cba#c.`conn'])), "%9.4f")

// pre treat coefficient
eststo: reghdfe numb_clauses c.`conn'##pre_treat_cba if `s_spill' & !missing(cba_period) & cba_period<=2, ///
        absorb(`pre_tvfe_cba') ///
        vce(cluster identificad)

// Extract pre-treatment coefficient and p-value
local pre_coef = string(_b[1.pre_treat_cba#c.`conn'], "%9.4f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.pre_treat_cba#c.`conn']/_se[1.pre_treat_cba#c.`conn'])), "%9.4f")

// Event study regression
reghdfe numb_clauses c.`conn'##ib(2).cba_period if `s_spill' & !missing(cba_period), ///
        absorb(`es_tvfe_cba') ///
        vce(cluster identificad)
estimates store es_clauses


// Generate event study plot for total clauses - draft
coefplot es_clauses, ///
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

graph export "$graphs/es_numb_clauses_spill_numb_clauses_pre_totalflows_lienar_pw.pdf", as(pdf) replace

// } // end of g loop for spillover effects

* DIRECT EFFECTS *

* ===============================
* Direct effects: pre/post coeffs
* ===============================
// foreach g in 4 5 10 20 {
 foreach outcome of local labor_outcomes{
 eststo clear
 
 * Define FE locals inside the loop so `outcome' and `g' have values
 local post_tvfe "treat_year identificad industry1#year mode_base_month#year microregion#year c.`outcome'_pre#year c.totalflows_n#year"
 local pre_tvfe "placebo_year identificad industry1#year mode_base_month#year microregion#year c.`outcome'_pre#year c.totalflows_n#year"
 local es_tvfe "year identificad industry1#year mode_base_month#year microregion#year c.`outcome'_pre#year c.totalflows_n#year"
 
 // run regressions for each outcome
 // store all regressions in a separate folder for each control

* --- Post-treatment coefficient (treat_ultra × Post) ---
eststo: reghdfe `outcome' treat_ultra##treat_year if `s_direct', ///
        absorb(`post_tvfe') ///
        vce(cluster identificad)

local post_coef = string(_b[1.treat_ultra#1.treat_year], "%9.4f")
local post_se = string(_se[1.treat_ultra#1.treat_year], "%9.4f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_ultra#1.treat_year]/_se[1.treat_ultra#1.treat_year])), "%9.4f")

* --- Pre-treatment (placebo) coefficient (treat_ultra × Pre) ---
eststo: reghdfe `outcome' treat_ultra##placebo_year if `s_direct' & year<=2011, ///
        absorb(`pre_tvfe') ///
        vce(cluster identificad)

local pre_coef = string(_b[1.treat_ultra#1.placebo_year], "%9.4f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.treat_ultra#1.placebo_year]/_se[1.treat_ultra#1.placebo_year])), "%9.4f")

* ===============================
* Direct effects: event study plot
* ===============================
reghdfe `outcome' treat_ultra##b(2011).year  if `s_direct', ///
        absorb(`es_tvfe') ///
        vce(cluster identificad)
estimates store es_direct_remmedr

coefplot es_direct_remmedr, ///
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

graph export "$graphs/es_`outcome'_treat_`outcome'_pre_totalflows_linear_pw.pdf", as(pdf) replace
 }

* CBA CLAUSES

* Define CBA FE locals for numb_clauses
local post_tvfe_cba "post_treat_cba identificad industry1#cba_period mode_base_month#cba_period microregion#cba_period c.numb_clauses_pre#cba_period c.totalflows_n#cba_period"
local pre_tvfe_cba "pre_treat_cba identificad industry1#cba_period mode_base_month#cba_period microregion#cba_period c.numb_clauses_pre#cba_period c.totalflows_n#cba_period"
local es_tvfe_cba "cba_period identificad industry1#cba_period mode_base_month#cba_period microregion#cba_period c.numb_clauses_pre#cba_period c.totalflows_n#cba_period"

* --- Post-treatment coefficient (treat_ultra × Post) ---
// Direct Effect on Number of Clauses
// post treat coefficient
eststo: reghdfe numb_clauses i.treat_ultra##post_treat_cba if `s_direct' & !missing(cba_period), ///
        absorb(`post_tvfe_cba') ///
        vce(cluster identificad)

// Extract post-treatment coefficient and p-value
local post_coef = string(_b[1.treat_ultra#1.post_treat_cba], "%9.4f")
local post_se = string(_se[1.treat_ultra#1.post_treat_cba], "%9.4f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_ultra#1.post_treat_cba]/_se[1.treat_ultra#1.post_treat_cba])), "%9.4f")

// pre treat coefficient
eststo: reghdfe numb_clauses i.treat_ultra##pre_treat_cba if `s_direct' & !missing(cba_period) & cba_period<=2, ///
        absorb(`pre_tvfe_cba') ///
        vce(cluster identificad)

// Extract pre-treatment coefficient and p-value
local pre_coef = string(_b[1.treat_ultra#1.pre_treat_cba], "%9.4f")
local pre_se = string(_se[1.treat_ultra#1.pre_treat_cba], "%9.4f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.treat_ultra#1.pre_treat_cba]/_se[1.treat_ultra#1.pre_treat_cba])),"%9.4f")

// Event study regression
reghdfe numb_clauses i.treat_ultra##ib(2).cba_period if `s_direct' & !missing(cba_period), ///
        absorb(`es_tvfe_cba') ///
        vce(cluster identificad)
estimates store es_clauses


// Generate event study plot for total clauses - draft
coefplot es_clauses, ///
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

graph export "$graphs/es_numb_clauses_treat_numb_clauses_totalflows_linear_pw.pdf", as(pdf) replace

// } // end of g loop for direct effects




* ===============================
* CONTROLING FOR UNION EFFECTS
* ===============================

// foreach g in 4 5 10 20 {

* Define FE locals for union mediation (using lr_remdezr_h)
local income_out "lr_remdezr"
local post_tvfe "treat_year identificad industry1#year mode_base_month#year microregion#year c.`outcome'_pre#year c.totalflows_n#year"
local pre_tvfe "placebo_year identificad industry1#year mode_base_month#year microregion#year c.`outcome'_pre#year c.totalflows_n#year"

* CONTROLLING FOR MODE UNION NON PARAMETRICALLY

eststo : reghdfe `income_out' c.`conn'##i.treat_year if `s_spill' & year>=2009, ///
        absorb(`post_tvfe' mode_union#year) ///
        vce(cluster identificad)
// local ++estnum
**# Bookmark #2

// placebo coefficient
eststo : reghdfe `income_out' c.`conn'##i.placebo_year  if `s_spill' & year<=2011 & year>=2009, ///
        absorb(`pre_tvfe' mode_union#year) ///
        vce(cluster identificad)
// local ++estnum

* CONTROLLING FOR UNION EXPOSITION TO TREATED FIRMS

eststo : reghdfe `income_out' c.`conn'##i.treat_year if `s_spill' & year>=2009, ///
        absorb(`post_tvfe' c.treat_union_exp_all#year) ///
        vce(cluster identificad)
// local ++estnum
**# Bookmark #2

// placebo coefficient
eststo : reghdfe `income_out' c.`conn'##i.placebo_year  if `s_spill' & year<=2011 & year>=2009, ///
        absorb(`pre_tvfe' c.treat_union_exp_all#year) ///
        vce(cluster identificad)
// local ++estnum

* CONTROLLING FOR UNION EXPOSITION TO TREATED WORKERS

eststo : reghdfe `income_out' c.`conn'##i.treat_year if `s_spill' & year>=2009, ///
        absorb(`post_tvfe' c.union_emp_exp#year) ///
        vce(cluster identificad)
// local ++estnum
**# Bookmark #2

// placebo coefficient
eststo : reghdfe `income_out' c.`conn'##i.placebo_year  if `s_spill' & year<=2011 & year>=2009, ///
        absorb(`pre_tvfe' c.union_emp_exp#year) ///
        vce(cluster identificad)
// local ++estnum

// } // end of g loop for union effects


* testing:

local outcome "lr_remdezr_w"
local conn "totaltreat_pw_norm"
local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"
* Define FE locals inside the loop so `outcome' and `g' have values
 local post_tvfe "treat_year identificad industry1#treat_year mode_base_month#treat_year microregion#treat_year  ib0.totalflows_n#treat_year"
 local pre_tvfe "placebo_year identificad industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year ib0.totalflows_n#placebo_year"
 local es_tvfe "year identificad industry1#year mode_base_month#year microregion#year  totalflows#year"
 
 // run regressions for each outcome
 // store all regressions in a separate folder for each control

* --- Post-treatment coefficient (treat_ultra × Post) ---
eststo: reghdfe `outcome' ///
		c.`conn'##treat_year ///
		if `s_spill' & year>=2009, ///
        absorb(`post_tvfe') ///
        vce(cluster identificad)

		// Extract post-treatment coefficient and p-value
local post_coef = string(_b[1.treat_year#c.`conn'], "%9.4f")
local post_se  = string(_se[1.treat_year#c.`conn'], "%9.4f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_year#c.`conn']/_se[1.treat_year#c.`conn'])), "%9.4f")

* --- Pre-treatment (placebo) coefficient (treat_ultra × Pre) ---
eststo: reghdfe `outcome' c.`conn'##placebo_year if `s_spill' & year<=2011, ///
        absorb(`pre_tvfe') ///
        vce(cluster identificad)

// Extract pre-treatment coefficient and p-value
local pre_coef = string(_b[1.placebo_year#c.`conn'], "%9.4f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.placebo_year#c.`conn']/_se[1.placebo_year#c.`conn'])), "%9.4f")

// we are finding different effects for lr_remdezr_h and lr_remdezr_h_w. correlation between two meaures is very high (.9895), though

* ===============================
* END OF PROGRAM
* ===============================
di _newline(3)
di as text "{hline 80}"
di as result "PROGRAM COMPLETED SUCCESSFULLY"
di as text "Ended: `c(current_date)' `c(current_time)'"
di as text "{hline 80}"

log close
