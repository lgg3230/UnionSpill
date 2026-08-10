********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR:  LUIS GOMES
* PROGRAM: Exercises to try to understand the mechanisms behind the spillover effects
* INPUT:   FLOWS DATASET, RESTRICTED TO LAGOS SAMPLE
* OUTPUT:  Regression tables testing different spces on turnover, totalflows, employment.	 
********************************************************************************

use "$rais_firm/labor_analysis_sample_aug6.dta", clear

capture program drop genvar
program define genvar
    // Syntax: genvar <varname> = <expression>
    // Example: genvar myx = 2*z + 5

    // Grab everything before "=" as the variable name
    gettoken varname 0 : 0, parse("=")

    // Trim spaces
    local varname : trim local varname

    // If var exists, drop it
    cap confirm variable `varname'
    if !_rc drop `varname'

    // Now regenerate with whatever follows "="
    gen `varname' `0'
end

gen placebo_year = cond(year<2011, 1,0)

bys identificad: egen firm_emp_pre_o = mean(firm_emp) if year<=2011
bys identificad: egen firm_emp_pre =  min(firm_emp_pre_o)
gen l_firm_emp_pre = log(firm_emp_pre)

bys identificad: egen lr_remmedr_pre_o = mean(lr_remmedr) if year<=2011
bys identificad: egen lr_remmedr_pre = min(lr_remmedr_pre_o)

// First Exercise: Do firms with higher inflows from treatment generally have less outflows with treatment, controlled by things that might be driving both up?

// approach 1:

reg intreat_n outtreat_n l_firm_emp_pre i.microregion i.industry1 totalflows_n if treat_ultra==0 & year==2009, rob

// no sorting


// approach 2:

reg intreat_pw_n i.microregion i.industry1 outtreat_pw_n l_firm_emp_pre totalflows_n if treat_ultra==0 & year==2009, rob


local year 2009
local sample "treat_ultra==0 & year==`year'"
local nbins 100

* Approach 1
reg intreat_n l_firm_emp_pre i.microregion i.industry1 totalflows_n prop_hs outtreat_n  if `sample' & intreat_n<400 & outtreat_n < 250, vce(robust)
local b1 : display %9.4f _b[outtreat_n]
gen byte samp1 = e(sample)

* Residualize Y on controls only
reg intreat_n l_firm_emp_pre i.microregion i.industry1 totalflows_n if samp1 , vce(robust)
predict double y_resid1 if e(sample), resid

binscatter y_resid1 outtreat_n if samp1, n(`nbins') line(lfit) ///
    yline(0) ///
    title("Approach 1: Residualized intreat vs outtreat") ///
    subtitle("β̂_outtreat = `b1'") ///
    ytitle("Residualized intreat_n") ///
    xtitle("outtreat_n") ///
    legend(off)

* Approach 2
reg intreat_pw_n outtreat_pw_n l_firm_emp_pre i.microregion i.industry1 totalflows_n if `sample', vce(robust)
local b2 : display %9.4f _b[outtreat_pw_n]
gen byte samp2 = e(sample)

reg intreat_pw_n l_firm_emp_pre i.microregion i.industry1 totalflows_n if samp2, vce(robust)
predict double y_resid2 if e(sample), resid

binscatter y_resid2 outtreat_pw_n if samp2, n(`nbins') line(lfit) ///
    yline(0) ///
    title("Approach 2: Residualized Y vs outtreat_pw_n") ///
    subtitle("β̂_outtreat_pw = `b2'") ///
    ytitle("Residualized intreat_pw_n") ///
    xtitle("outtreat_pw_n") ///
    legend(off)

    
// Approach 3

cap drop intreat_n_pf
gen intreat_n_pf = intreat_n/totalflows_n

cap drop outtreat_n_pf
gen outtreat_n_pf =  outtreat_n/totalflows_n


local year 2009
local sample "treat_ultra==0 & year==`year'"
local nbins 100

cap drop samp3
cap drop y_resid3
reg intreat_n_pf outtreat_n_pf l_firm_emp_pre i.microregion i.industry1 totalflows_n if `sample' & outtreat_n_pf<.25, vce(robust)
local b2 : display %9.4f _b[outtreat_n_pf]
gen byte samp3 = e(sample)

reg intreat_n_pf outtreat_n_pf l_firm_emp_pre i.microregion i.industry1 totalflows_n if samp3 & outtreat_n_pf<.25, vce(robust)
predict double y_resid3 if e(sample), resid

binscatter y_resid3 outtreat_n_pf if samp3 & outtreat_n_pf<.25, n(`nbins') line(lfit) ///
    yline(0) ///
    title(" Residualized intreat_n_pf vs outtreat_n_pf") ///
    subtitle("β̂_outtreat_pw = `b2'") ///
    ytitle("Residualized Inflows from Treat per flow") ///
    xtitle("Outflows to treated per flow") ///
    legend(off)
    
    graph export "$graphs/y_resid3_outtreat_pf.png", as(png) replace

corr y_resid3 outtreat_n_pf if treat_ultra==0 & year==2009
