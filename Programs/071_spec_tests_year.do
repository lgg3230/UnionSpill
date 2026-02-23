********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR:  LUIS GOMES (+tidy skeleton)
* PROGRAM: MEGA tables — Direct + Spillovers (complete story per spec)
* STYLE:   Readable, linear, minimal meta-code
********************************************************************************

version 17
clear all
set more off

*==========================
* (0) Paths / setup
*==========================
use "$rais_firm/lagos_sample_sep24_pct.dta", clear
cap mkdir "results"
cap mkdir "results/tables"

cap which esttab
if _rc ssc install estout, replace

*==========================
* (1) Samples, basics, and FE-safe encodings
*==========================
keep if lagos_sample_avg==1

* String → numeric for FE interactions if needed
capture confirm string variable industry1
if !_rc encode industry1, gen(industry1_num)
else gen industry1_num = industry1

capture confirm string variable mode_base_month
if !_rc encode mode_base_month, gen(mode_base_month_num)
else gen mode_base_month_num = mode_base_month

capture confirm string variable microregion
if !_rc encode microregion, gen(microregion_num)
else gen microregion_num = microregion

* Placebo-year dummy for non-clauses PRE
cap drop placebo_year
gen byte placebo_year = (year<2011)

* Mark CBA periods (as in your script)
cap drop cba_period
gen cba_period = .
replace cba_period = 1 if avg_file_date==earliest2009_avg-1 & !missing(avg_file_date)
replace cba_period = 2 if avg_file_date==second_cba_avg & !missing(avg_file_date)
replace cba_period = 3 if inrange(avg_file_date, mdy(1,1,2013), mdy(12,31,2013)) & cba_period==.
replace cba_period = 4 if inrange(avg_file_date, mdy(1,1,2014), mdy(12,31,2014)) & cba_period==.
replace cba_period = 5 if inrange(avg_file_date, mdy(1,1,2015), mdy(12,31,2015)) & cba_period==.
replace cba_period = 6 if inrange(avg_file_date, mdy(1,1,2016), mdy(12,31,2016)) & cba_period==.

cap drop pre_treat_cba post_treat_cba
gen pre_treat_cba  = cba_period<2 if !missing(cba_period)
gen post_treat_cba = cba_period>2 if !missing(cba_period)

* Average employment (used elsewhere)
cap drop avg_emp
bys identificad (year): gen avg_emp = (firm_emp + firm_emp[_n-1])/2 if year>=2010

* in and out flows per flow measures:
cap drop intreat_pf_n
cap drop outtreat_pf_n

gen intreat_pf_n = intreat_n/totalflows_n
gen outtreat_pf_n = outtreat_n/totalflows_n

local s_spill  "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0"

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

gen p90p10_ratio_dec = lr_remdezr_p90-lr_remdezr_p10
label var p90p10_ratio_dec "90 10 log wage ratio , december wages"

gen p50p10_ratio_dec  = lr_remdezr_p50 - lr_remdezr_p10
label var p90p10_ratio_dec "50 10 log wage ratio , december wages"

gen p90p10_h_ratio_dec = lr_remdezr_h_p90-lr_remdezr_h_p10
label var p90p10_h_ratio_dec "90 10 log hourly wage ratio , december wages"

gen p50p10_h_ratio_dec  = lr_remdezr_h_p50 - lr_remdezr_h_p10
label var p90p10_h_ratio_dec "50 10 log hourly wage ratio , december wages"

* Samples (your definitions — note: s_direct uses totaltreat_pf_n threshold)
local s_direct "(lagos_sample_avg==1 & treat_ultra==0 & totaltreat_pw_n<=0.01 | lagos_sample_avg==1 & treat_ultra==1) & in_balanced_panel==1"
local s_spill  "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0"

* Always-in FE (use encoded *_num variables for safety)
local FEYPRE        "identificad treat_year industry1_num#placebo_year mode_base_month_num#placebo_year microregion_num#placebo_year"
local FEYPOST       "identificad placebo_year industry1_num#treat_year mode_base_month_num#treat_year microregion_num#treat_year"
local FEPOSTCBA  "identificad post_treat_cba industry1_num#post_treat_cba mode_base_month_num#post_treat_cba microregion_num#post_treat_cba"
local FEPRECBA   "identificad pre_treat_cba  industry1_num#pre_treat_cba  mode_base_month_num#pre_treat_cba  microregion_num#pre_treat_cba"

*==========================
* (2) PRE variables for 3 windows (2007–11, 2008–11, 2009–11)
*==========================
cap drop turnover
sort identificad year
bys identificad: gen turnover = 2*separations/(firm_emp + firm_emp[_n-1])

foreach pw in 0711 0811 0911 {
    if "`pw'"=="0711" local pstart=2007
    if "`pw'"=="0811" local pstart=2008
    if "`pw'"=="0911" local pstart=2009

    cap drop firm_emp_pre_p`pw'_o firm_emp_pre_p`pw'
    bys identificad: egen firm_emp_pre_p`pw'_o = mean(firm_emp)    if inrange(year,`pstart',2011)
    bys identificad: egen firm_emp_pre_p`pw'   = min(firm_emp_pre_p`pw'_o)

    cap drop lr_remdezr_pre_p`pw'_o lr_remdezr_pre_p`pw'
    bys identificad: egen lr_remdezr_pre_p`pw'_o = mean(lr_remdezr) if inrange(year,`pstart',2011)
    bys identificad: egen lr_remdezr_pre_p`pw'   = min(lr_remdezr_pre_p`pw'_o)
	
    cap drop lr_remdezr_h_pre_p`pw'_o lr_remdezr_h_pre_p`pw'
    bys identificad: egen lr_remdezr_h_pre_p`pw'_o = mean(lr_remdezr_h) if inrange(year,`pstart',2011)
    bys identificad: egen lr_remdezr_h_pre_p`pw'   = min(lr_remdezr_h_pre_p`pw'_o)

    cap drop lr_remmedr_pre_p`pw'_o lr_remmedr_pre_p`pw'
    bys identificad: egen lr_remmedr_pre_p`pw'_o = mean(lr_remmedr) if inrange(year,`pstart',2011)
    bys identificad: egen lr_remmedr_pre_p`pw'   = min(lr_remmedr_pre_p`pw'_o)

    cap drop tn_pre_p`pw'_o tn_pre_p`pw'
    bys identificad: egen tn_pre_p`pw'_o = mean(turnover) if inrange(year,`pstart',2011)
    bys identificad: egen tn_pre_p`pw'   = min(tn_pre_p`pw'_o)

    cap drop ret_pre_p`pw'_o ret_pre_p`pw'
    capture confirm variable retention
    if !_rc {
        bys identificad: egen ret_pre_p`pw'_o = mean(retention) if inrange(year,`pstart',2011)
        bys identificad: egen ret_pre_p`pw'   = min(ret_pre_p`pw'_o)
    }

    cap drop n_negs_pre_p`pw'_o n_negs_pre_p`pw'
    capture confirm variable n_negs_union_year
    if !_rc {
        bys identificad: egen n_negs_pre_p`pw'_o = mean(n_negs_union_year) if inrange(year,`pstart',2011)
        bys identificad: egen n_negs_pre_p`pw'   = min(n_negs_pre_p`pw'_o)
    }
}

* natjuridica1 (first digit)
cap drop natjuridica1
tostring natjuridica, replace force
gen natjuridica1 = substr(natjuridica,1,1)
destring natjuridica natjuridica1, replace force

gen mode_union_1 = floor(mode_union)

*==========================
* (3) Size split (median firm_emp at 2009)
*==========================
cap drop firm_emp_2009_o 
cap drop firm_emp_2009 
cap drop below_med 
cap drop above_med
gen firm_emp_2009_o = firm_emp if year==2009
bys identificad: egen firm_emp_2009 = min(firm_emp_2009_o)
sum firm_emp_2009 if firm_emp_2009<., detail
scalar med_emp = r(p50)
gen byte below_med = (firm_emp_2009 <= med_emp) if firm_emp_2009<.
gen byte above_med = (firm_emp_2009 >  med_emp) if firm_emp_2009<.

*==========================
* (4) Rotations and labels
*==========================
local pre_windows "0911"

local codings    "level quartile quintile"

* Continuous (rotate as level / quartiles / quintiles)
local cont_controls "n_negs_pre ret_pre tn_pre totalflows_n firm_emp_pre lr_remmedr_pre lr_remdezr_pre"

* Categorical (rotate as time-varying FE i.var#time)
local cat_controls  ""

cap label define q4 1 "Q1" 2 "Q2" 3 "Q3" 4 "Q4"
cap label define q5 1 "Q1 (smallest)" 2 "Q2" 3 "Q3" 4 "Q4" 5 "Q5 (largest)"

* Outcomes and connectivity
local OUT_A  "l_firm_emp lr_remdezr lr_remdezr_h lr_remmedr p90p10_h_ratio_dec p90p10_ratio_dec lr_remdezr_p10 lr_remdezr_h_p50 lr_remdezr_h_p90"
local CONN_A "totaltreat_pw_norm"
local CONN_OUT_pw "outtreat_pw_norm"
local CONN_IN_pw  "intreat_pw_norm"

local CONN_OUT_pf "outtreat_pf_n"
local CONN_IN_pf  "intreat_pf_n"

* Column labels
local mcols_A   "Direct-Post Direct-Pre Overall-Post Overall-Pre Below-Post Below-Pre Above-Post Above-Pre Outflows-Post Outflows-Pre Inflows-Post Inflows-Pre"
local mlabels_A "`mcols_A' `mcols_A' `mcols_A'"

local mcols_B   "`mcols_A'"

********************************************************************************
* ==========================
* FAMILY A: Employment & Wages (Direct + Spillovers in ONE table)
* ==========================
********************************************************************************

foreach pw in `pre_windows' {
    if "`pw'"=="0711" local pstart=2007
    if "`pw'"=="0811" local pstart=2008
    if "`pw'"=="0911" local pstart=2009

    * === Window filters for this loop ===
    local WIN_POST "inrange(year, `pstart', 2016)"
    local WIN_PRE  "inrange(year, `pstart', 2011)"

    foreach coding in `codings' {
        foreach C in `cont_controls' `cat_controls' {

            * ---- Build additional control terms (timing-specific) ----
            local ADD_POST ""
            local ADD_PRE  ""

            if inlist("`C'","natjuridica1","mode_union") {
                local ADD_POST "i.`C'#year"
                local ADD_PRE  "i.`C'#year"
            }
            else {
                local V ""
                if "`C'"=="firm_emp_pre"     local V "firm_emp_pre_p`pw'"
                if "`C'"=="lr_remmedr_pre"   local V "lr_remmedr_pre_p`pw'"
                if "`C'"=="lr_remdezr_pre"   local V "lr_remdezr_pre_p`pw'"
                if "`C'"=="lr_remdezr_h_pre" local V "lr_remdezr_h_pre_p`pw'"
                if "`C'"=="tn_pre"           local V "tn_pre_p`pw'"
                if "`C'"=="ret_pre"          local V "ret_pre_p`pw'"
                if "`C'"=="n_negs_pre"       local V "n_negs_pre_p`pw'"
                if "`C'"=="totalflows_n"     local V "totalflows_n"

                capture confirm variable `V'
                if _rc {
                    di as txt "Skipping control `C' (missing `V') in window `pw'."
                    continue
                }

                if "`coding'"=="level" {
                    local ADD_POST "`V'#year"
                    local ADD_PRE  "`V'#year"
                }
                if "`coding'"=="quartile" {
                    cap drop q4_`V'_2009a q4_`V'
                    egen q4_`V'_2009a = cut(`V') if year==2009, group(4)
                    bys identificad: egen q4_`V' = min(q4_`V'_2009a)
                    drop q4_`V'_2009a
                    label values q4_`V' q4
                    local ADD_POST "i.q4_`V'#year"
                    local ADD_PRE  "i.q4_`V'#year"
                }
                if "`coding'"=="quintile"  {
                    cap drop q5_`V'_2009a q5_`V'
                    egen q5_`V'_2009a = cut(`V') if year==2009, group(5)
                    bys identificad: egen q5_`V' = min(q5_`V'_2009a)
                    drop q5_`V'_2009a
                    label values q5_`V' q5
                    local ADD_POST "i.q5_`V'#year"
                    local ADD_PRE  "i.q5_`V'#year"
                }
            }

            foreach conn of local CONN_A {
                eststo clear
                local estnum = 1

                foreach y of local OUT_A {
                    
                    di as txt "=== Running outcome: `y' | control: `C' | coding: `coding' ==="
                    
                    * Define absorb and if conditions
                    local abs_post "`FEYPOST' `ADD_POST'"
                    local abs_pre  "`FEYPRE' `ADD_PRE'"
                    
                    * ---------- DIRECT POST ----------
                    capture noisily reghdfe `y' i.treat_ultra##i.treat_year ///
                        if (`s_direct') & `WIN_POST', absorb(`abs_post') vce(cluster identificad)
                    if _rc == 0 {
                        eststo est`estnum'
                    }
                    else {
                        di as txt "  -> Skipped est`estnum' (rc=" _rc ")"
                        quietly eststo est`estnum': reg `y' if 0
                    }
                    local ++estnum

                    * ---------- DIRECT PRE ----------
                    capture noisily reghdfe `y' i.treat_ultra##i.placebo_year ///
                        if (`s_direct') & `WIN_PRE', absorb(`abs_pre') vce(cluster identificad)
                    if _rc == 0 {
                        eststo est`estnum'
                    }
                    else {
                        di as txt "  -> Skipped est`estnum' (rc=" _rc ")"
                        quietly eststo est`estnum': reg `y' if 0
                    }
                    local ++estnum

                    * ---------- OVERALL POST ----------
                    capture noisily reghdfe `y' c.`conn'##i.treat_year ///
                        if (`s_spill') & `WIN_POST', absorb(`abs_post') vce(cluster identificad)
                    if _rc == 0 {
                        eststo est`estnum'
                    }
                    else {
                        di as txt "  -> Skipped est`estnum' (rc=" _rc ")"
                        quietly eststo est`estnum': reg `y' if 0
                    }
                    local ++estnum

                    * ---------- OVERALL PRE ----------
                    capture noisily reghdfe `y' c.`conn'##i.placebo_year ///
                        if (`s_spill') & `WIN_PRE', absorb(`abs_pre') vce(cluster identificad)
                    if _rc == 0 {
                        eststo est`estnum'
                    }
                    else {
                        di as txt "  -> Skipped est`estnum' (rc=" _rc ")"
                        quietly eststo est`estnum': reg `y' if 0
                    }
                    local ++estnum

                    * ---------- BELOW MEDIAN POST ----------
                    capture noisily reghdfe `y' c.`conn'##i.treat_year ///
                        if (`s_spill') & below_med==1 & `WIN_POST', absorb(`abs_post') vce(cluster identificad)
                    if _rc == 0 {
                        eststo est`estnum'
                    }
                    else {
                        di as txt "  -> Skipped est`estnum' (rc=" _rc ")"
                        quietly eststo est`estnum': reg `y' if 0
                    }
                    local ++estnum

                    * ---------- BELOW MEDIAN PRE ----------
                    capture noisily reghdfe `y' c.`conn'##i.placebo_year ///
                        if (`s_spill') & below_med==1 & `WIN_PRE', absorb(`abs_pre') vce(cluster identificad)
                    if _rc == 0 {
                        eststo est`estnum'
                    }
                    else {
                        di as txt "  -> Skipped est`estnum' (rc=" _rc ")"
                        quietly eststo est`estnum': reg `y' if 0
                    }
                    local ++estnum

                    * ---------- ABOVE MEDIAN POST ----------
                    capture noisily reghdfe `y' c.`conn'##i.treat_year ///
                        if (`s_spill') & above_med==1 & `WIN_POST', absorb(`abs_post') vce(cluster identificad)
                    if _rc == 0 {
                        eststo est`estnum'
                    }
                    else {
                        di as txt "  -> Skipped est`estnum' (rc=" _rc ")"
                        quietly eststo est`estnum': reg `y' if 0
                    }
                    local ++estnum

                    * ---------- ABOVE MEDIAN PRE ----------
                    capture noisily reghdfe `y' c.`conn'##i.placebo_year ///
                        if (`s_spill') & above_med==1 & `WIN_PRE', absorb(`abs_pre') vce(cluster identificad)
                    if _rc == 0 {
                        eststo est`estnum'
                    }
                    else {
                        di as txt "  -> Skipped est`estnum' (rc=" _rc ")"
                        quietly eststo est`estnum': reg `y' if 0
                    }
                    local ++estnum

                    * ---------- OUTFLOWS PW POST ----------
                    capture noisily reghdfe `y' c.`CONN_OUT_pw'##i.treat_year ///
                        if (`s_spill') & `WIN_POST', absorb(`abs_post') vce(cluster identificad)
                    if _rc == 0 {
                        eststo est`estnum'
                    }
                    else {
                        di as txt "  -> Skipped est`estnum' (rc=" _rc ")"
                        quietly eststo est`estnum': reg `y' if 0
                    }
                    local ++estnum

                    * ---------- OUTFLOWS PW PRE ----------
                    capture noisily reghdfe `y' c.`CONN_OUT_pw'##i.placebo_year ///
                        if (`s_spill') & `WIN_PRE', absorb(`abs_pre') vce(cluster identificad)
                    if _rc == 0 {
                        eststo est`estnum'
                    }
                    else {
                        di as txt "  -> Skipped est`estnum' (rc=" _rc ")"
                        quietly eststo est`estnum': reg `y' if 0
                    }
                    local ++estnum

                    * ---------- INFLOWS PW POST ----------
                    capture noisily reghdfe `y' c.`CONN_IN_pw'##i.treat_year ///
                        if (`s_spill') & `WIN_POST', absorb(`abs_post') vce(cluster identificad)
                    if _rc == 0 {
                        eststo est`estnum'
                    }
                    else {
                        di as txt "  -> Skipped est`estnum' (rc=" _rc ")"
                        quietly eststo est`estnum': reg `y' if 0
                    }
                    local ++estnum

                    * ---------- INFLOWS PW PRE ----------
                    capture noisily reghdfe `y' c.`CONN_IN_pw'##i.placebo_year ///
                        if (`s_spill') & `WIN_PRE', absorb(`abs_pre') vce(cluster identificad)
                    if _rc == 0 {
                        eststo est`estnum'
                    }
                    else {
                        di as txt "  -> Skipped est`estnum' (rc=" _rc ")"
                        quietly eststo est`estnum': reg `y' if 0
                    }
                    local ++estnum

                    * ---------- OUTFLOWS PF POST ----------
                    capture noisily reghdfe `y' c.`CONN_OUT_pf'##i.treat_year ///
                        if (`s_spill') & `WIN_POST', absorb(`abs_post') vce(cluster identificad)
                    if _rc == 0 {
                        eststo est`estnum'
                    }
                    else {
                        di as txt "  -> Skipped est`estnum' (rc=" _rc ")"
                        quietly eststo est`estnum': reg `y' if 0
                    }
                    local ++estnum

                    * ---------- OUTFLOWS PF PRE ----------
                    capture noisily reghdfe `y' c.`CONN_OUT_pf'##i.placebo_year ///
                        if (`s_spill') & `WIN_PRE', absorb(`abs_pre') vce(cluster identificad)
                    if _rc == 0 {
                        eststo est`estnum'
                    }
                    else {
                        di as txt "  -> Skipped est`estnum' (rc=" _rc ")"
                        quietly eststo est`estnum': reg `y' if 0
                    }
                    local ++estnum

                    * ---------- INFLOWS PF POST ----------
                    capture noisily reghdfe `y' c.`CONN_IN_pf'##i.treat_year ///
                        if (`s_spill') & `WIN_POST', absorb(`abs_post') vce(cluster identificad)
                    if _rc == 0 {
                        eststo est`estnum'
                    }
                    else {
                        di as txt "  -> Skipped est`estnum' (rc=" _rc ")"
                        quietly eststo est`estnum': reg `y' if 0
                    }
                    local ++estnum

                    * ---------- INFLOWS PF PRE ----------
                    capture noisily reghdfe `y' c.`CONN_IN_pf'##i.placebo_year ///
                        if (`s_spill') & `WIN_PRE', absorb(`abs_pre') vce(cluster identificad)
                    if _rc == 0 {
                        eststo est`estnum'
                    }
                    else {
                        di as txt "  -> Skipped est`estnum' (rc=" _rc ")"
                        quietly eststo est`estnum': reg `y' if 0
                    }
                    local ++estnum
                }
                
                * ---- Export MEGA table ----
                esttab using "results/tables/MEGA_A_`conn'_`C'_`coding'_p`pw'_Dec14.csv", replace ///
                    keep( ///
                        1.treat_ultra#1.treat_year  1.treat_ultra#1.placebo_year ///
                        1.treat_year#c.`conn'       1.placebo_year#c.`conn' ///
                        1.treat_year#c.`conn'       1.placebo_year#c.`conn' ///
                        1.treat_year#c.`conn'       1.placebo_year#c.`conn' ///
                        1.treat_year#c.`CONN_OUT_pw'   1.placebo_year#c.`CONN_OUT_pw' ///
                        1.treat_year#c.`CONN_IN_pw'    1.placebo_year#c.`CONN_IN_pw'  ///
                        1.treat_year#c.`CONN_OUT_pf'   1.placebo_year#c.`CONN_OUT_pf' ///
                        1.treat_year#c.`CONN_IN_pf'    1.placebo_year#c.`CONN_IN_pf' ) ///
                    se star(* 0.10 ** 0.05 *** 0.01) b(4) se(4)
            }
        }
    }
}

di as txt "=== DONE ==="




// * ==========================
// * FAMILY B: Clauses (numb_clauses) with accumulator bundles
// * ==========================
// foreach pw in `pre_windows' {
//     if "`pw'"=="0711" local pstart=2007
//     if "`pw'"=="0811" local pstart=2008
//     if "`pw'"=="0911" local pstart=2009
//
//     * Windows to match your pre/post comparisons
//     local WIN_POST "inrange(year, `pstart', 2016)"
//     local WIN_PRE  "inrange(year, `pstart', 2011)"
//
//     foreach coding in `codings' {
//
//         * ---------------------------
//         * Build bundles once per (pw, coding)
//         * ---------------------------
//         local ADD_POST ""
//         local ADD_PRE  ""
//
//         foreach C in `cont_controls' `cat_controls' {
//             local TERM_POST ""
//             local TERM_PRE  ""
//
//             * Categorical controls vary by timing dummy
//             if inlist("`C'","natjuridica1","mode_union_1") {
//                 local TERM_POST "i.`C'#post_treat_cba"
//                 local TERM_PRE  "i.`C'#pre_treat_cba"
//             }
//             else {
//                 * Map continuous control to the right pre-window variable
//                 local V ""
//                 if "`C'"=="firm_emp_pre"     local V "firm_emp_pre_p`pw'"
//                 if "`C'"=="lr_remmedr_pre"   local V "lr_remmedr_pre_p`pw'"
//                 if "`C'"=="lr_remdezr_pre"   local V "lr_remdezr_pre_p`pw'"
//                 if "`C'"=="tn_pre"           local V "tn_pre_p`pw'"
//                 if "`C'"=="ret_pre"          local V "ret_pre_p`pw'"
//                 if "`C'"=="n_negs_pre"       local V "n_negs_pre_p`pw'"
//                 if "`C'"=="totalflows_n"     local V "totalflows_n"
//
//                 capture confirm variable `V'
//                 if _rc {
//                     di as txt "Skipping control `C' (missing `V') in window `pw'."
//                     continue
//                 }
//
//                 * Your preference: continuous terms go inside absorb() without c.
//                 if "`coding'"=="level" {
//                     local TERM_POST "`V'"
//                     local TERM_PRE  "`V'"
//                 }
//                 else if "`coding'"=="quartile" & "`C'"!="totalflows_n" {
//                     cap drop q4_`V'_2009a q4_`V'
//                     egen q4_`V'_2009a = cut(`V') if year==2009, group(4)
//                     bys identificad: egen q4_`V' = min(q4_`V'_2009a)
//                     drop q4_`V'_2009a
//                     label values q4_`V' q4
//                     local TERM_POST "i.q4_`V'#post_treat_cba"
//                     local TERM_PRE  "i.q4_`V'#pre_treat_cba"
//                 }
//                 else if "`coding'"=="quintile" & "`C'"!="totalflows_n" {
//                     cap drop q5_`V'_2009a q5_`V'
//                     egen q5_`V'_2009a = cut(`V') if year==2009, group(5)
//                     bys identificad: egen q5_`V' = min(q5_`V'_2009a)
//                     drop q5_`V'_2009a
//                     label values q5_`V' q5
//                     local TERM_POST "i.q5_`V'#post_treat_cba"
//                     local TERM_PRE  "i.q5_`V'#pre_treat_cba"
//                 }
//                 else if inlist("`coding'","quartile","quintile") & "`C'"=="totalflows_n" {
//                     * treat network measure as time-invariant level
//                     local TERM_POST "`V'"
//                     local TERM_PRE  "`V'"
//                 }
//             }
//
//             if "`TERM_POST'" != "" local ADD_POST "`ADD_POST' `TERM_POST'"
//             if "`TERM_PRE'"  != "" local ADD_PRE  "`ADD_PRE'  `TERM_PRE'"
//         }
//
//         * ---------------------------
//         * Run the 12 clause regressions per connectivity choice
//         * ---------------------------
//         foreach conn of local CONN_A {
//             eststo clear
//             local estnum = 1
//
//             * ---------- DIRECT ----------
//             eststo est`estnum': reghdfe numb_clauses i.treat_ultra##i.post_treat_cba ///
//                 if (`s_direct') & !missing(cba_period) & `WIN_POST', ///
//                 absorb(`FEPOSTCBA' `ADD_POST') vce(cluster identificad)
//             local ++estnum
//
//             eststo est`estnum': reghdfe numb_clauses i.treat_ultra##i.pre_treat_cba ///
//                 if (`s_direct') & !missing(cba_period) & cba_period<=2 & `WIN_PRE', ///
//                 absorb(`FEPRECBA' `ADD_PRE') vce(cluster identificad)
//             local ++estnum
//
//             * ---------- OVERALL (conn × post/pre CBA) ----------
//             eststo est`estnum': reghdfe numb_clauses c.`conn'##i.post_treat_cba ///
//                 if (`s_spill') & !missing(cba_period) & `WIN_POST', ///
//                 absorb(`FEPOSTCBA' `ADD_POST') vce(cluster identificad)
//             local ++estnum
//
//             eststo est`estnum': reghdfe numb_clauses c.`conn'##i.pre_treat_cba ///
//                 if (`s_spill') & !missing(cba_period) & cba_period<=2 & `WIN_PRE', ///
//                 absorb(`FEPRECBA' `ADD_PRE') vce(cluster identificad)
//             local ++estnum
//
//             * ---------- BELOW / ABOVE ----------
//             eststo est`estnum': reghdfe numb_clauses c.`conn'##i.post_treat_cba ///
//                 if (`s_spill') & below_med==1 & !missing(cba_period) & `WIN_POST', ///
//                 absorb(`FEPOSTCBA' `ADD_POST') vce(cluster identificad)
//             local ++estnum
//
//             eststo est`estnum': reghdfe numb_clauses c.`conn'##i.pre_treat_cba ///
//                 if (`s_spill') & below_med==1 & !missing(cba_period) & cba_period<=2 & `WIN_PRE', ///
//                 absorb(`FEPRECBA' `ADD_PRE') vce(cluster identificad)
//             local ++estnum
//
//             eststo est`estnum': reghdfe numb_clauses c.`conn'##i.post_treat_cba ///
//                 if (`s_spill') & above_med==1 & !missing(cba_period) & `WIN_POST', ///
//                 absorb(`FEPOSTCBA' `ADD_POST') vce(cluster identificad)
//             local ++estnum
//
//             eststo est`estnum': reghdfe numb_clauses c.`conn'##i.pre_treat_cba ///
//                 if (`s_spill') & above_med==1 & !missing(cba_period) & cba_period<=2 & `WIN_PRE', ///
//                 absorb(`FEPRECBA' `ADD_PRE') vce(cluster identificad)
//             local ++estnum
//
//             * ---------- OUTFLOWS / INFLOWS (pw) ----------
//             eststo est`estnum': reghdfe numb_clauses c.`CONN_OUT_pw'##i.post_treat_cba ///
//                 if (`s_spill') & !missing(cba_period) & `WIN_POST', ///
//                 absorb(`FEPOSTCBA' `ADD_POST') vce(cluster identificad)
//             local ++estnum
//
//             eststo est`estnum': reghdfe numb_clauses c.`CONN_OUT_pw'##i.pre_treat_cba ///
//                 if (`s_spill') & !missing(cba_period) & cba_period<=2 & `WIN_PRE', ///
//                 absorb(`FEPRECBA' `ADD_PRE') vce(cluster identificad)
//             local ++estnum
//
//             eststo est`estnum': reghdfe numb_clauses c.`CONN_IN_pw'##i.post_treat_cba ///
//                 if (`s_spill') & !missing(cba_period) & `WIN_POST', ///
//                 absorb(`FEPOSTCBA' `ADD_POST') vce(cluster identificad)
//             local ++estnum
//
//             eststo est`estnum': reghdfe numb_clauses c.`CONN_IN_pw'##i.pre_treat_cba ///
//                 if (`s_spill') & !missing(cba_period) & cba_period<=2 & `WIN_PRE', ///
//                 absorb(`FEPRECBA' `ADD_PRE') vce(cluster identificad)
//             local ++estnum
//
//             * ---------- OUTFLOWS / INFLOWS (pf) ----------
//             eststo est`estnum': reghdfe numb_clauses c.`CONN_OUT_pf'##i.post_treat_cba ///
//                 if (`s_spill') & !missing(cba_period) & `WIN_POST', ///
//                 absorb(`FEPOSTCBA' `ADD_POST') vce(cluster identificad)
//             local ++estnum
//
//             eststo est`estnum': reghdfe numb_clauses c.`CONN_OUT_pf'##i.pre_treat_cba ///
//                 if (`s_spill') & !missing(cba_period) & cba_period<=2 & `WIN_PRE', ///
//                 absorb(`FEPRECBA' `ADD_PRE') vce(cluster identificad)
//             local ++estnum
//
//             eststo est`estnum': reghdfe numb_clauses c.`CONN_IN_pf'##i.post_treat_cba ///
//                 if (`s_spill') & !missing(cba_period) & `WIN_POST', ///
//                 absorb(`FEPOSTCBA' `ADD_POST') vce(cluster identificad)
//             local ++estnum
//
//             eststo est`estnum': reghdfe numb_clauses c.`CONN_IN_pf'##i.pre_treat_cba ///
//                 if (`s_spill') & !missing(cba_period) & cba_period<=2 & `WIN_PRE', ///
//                 absorb(`FEPRECBA' `ADD_PRE') vce(cluster identificad)
//             local ++estnum
//
//             * export (adjust keep() to your preferred columns)
//             esttab using "results/tables/MEGA_B_clauses_`conn'_`coding'_p`pw'.csv", replace ///
//                 keep( ///
//                     1.treat_ultra#1.post_treat_cba 1.treat_ultra#1.pre_treat_cba ///
//                     1.post_treat_cba#c.`conn'      1.pre_treat_cba#c.`conn'     ///
//                     1.post_treat_cba#c.`conn'      1.pre_treat_cba#c.`conn'     ///
//                     1.post_treat_cba#c.`conn'      1.pre_treat_cba#c.`conn'     ///
//                     1.post_treat_cba#c.`CONN_OUT_pw'  1.pre_treat_cba#c.`CONN_OUT_pw' ///
//                     1.post_treat_cba#c.`CONN_IN_pw'   1.pre_treat_cba#c.`CONN_IN_pw'  ///
//                     1.post_treat_cba#c.`CONN_OUT_pf'  1.pre_treat_cba#c.`CONN_OUT_pf' ///
//                     1.post_treat_cba#c.`CONN_IN_pf'   1.pre_treat_cba#c.`CONN_IN_pf'  ///
//                 ) se star(* 0.10 ** 0.05 *** 0.01) b(3) se(3)
//         }
//     }
// }



//
// local conn "totaltreat_pw_n"
// local y "lr_remdezr"
// // local ADD_POST "firm_emp_pre_p0911#treat_year"
// // local ADD_PRE "firm_emp_pre_p0911#placebo_year"
// // local V "lr_remdezr_pre_p0911"
// local WIN_PRE "(inrange(year,2009,2011))"
// local WIN_POST "(inrange(year,2009,2016))"
// local FEYPRE        "identificad treat_year industry1_num#placebo_year mode_base_month_num#placebo_year microregion_num#placebo_year"
// local FEYPOST       "identificad placebo_year industry1_num#treat_year mode_base_month_num#treat_year microregion_num#treat_year"
// local s_spill  "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0"
// local s_direct "(lagos_sample_avg==1 & treat_ultra==0 & totaltreat_pw_n<0.01 | lagos_sample_avg==1 & treat_ultra==1)"
//
// local V totalflows_n
// cap drop q4_`V'_2009a 
// cap drop q4_`V'
//                     egen q4_`V'_2009a = cut(`V') if year==2009, group(30)
//                     bys identificad: egen q4_`V' = min(q4_`V'_2009a)
//                     drop q4_`V'_2009a
//                     label values q4_`V' q4
//                     local ADD_POST "`V'#treat_year "
//                     local ADD_PRE  "`V'#placebo_year"
//
//
// reghdfe `y' i.treat_ultra##i.treat_year ///
//     if (`s_direct') & `WIN_POST', absorb(`FEYPOST' `ADD_POST') vce(cluster identificad)
//
//  reghdfe `y' i.treat_ultra##i.placebo_year ///
//     if (`s_direct') & `WIN_PRE', absorb(`FEYPRE' `ADD_PRE') vce(cluster identificad)


//  reghdfe `y' c.`conn'##i.treat_year ///
//                         if `s_spill' & `WIN_POST', absorb(`FEYPOST' `ADD_POST') vce(cluster identificad)
//              
//
//  reghdfe `y' c.`conn'##i.placebo_year ///
//                         if `s_spill' & `WIN_PRE', absorb(`FEYPRE' `ADD_PRE') vce(cluster identificad)
//                   
//
//					
//					
//
// display as txt "Done. Tables saved under results/tables/"
