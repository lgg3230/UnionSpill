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
use "$rais_firm/lagos_sample_sep24_2.dta", clear
// use "$rais_firm/labor_analysis_sample_aug6.dta", clear
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

cap drop pre_treat_cba
cap drop post_treat_cba
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

* Samples (your definitions — note: s_direct uses totaltreat_pf_n threshold)
local s_direct "(lagos_sample_avg==1 & treat_ultra==0 & totaltreat_pf_n<0.01 | lagos_sample_avg==1 & treat_ultra==1)"
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

* ---------- PRECOMPUTE TVFE CODINGS (0911 window) ----------
* Quintile of lr_remdezr_pre (ALWAYS INCLUDED)
cap drop q5_lrremdezr_p0911_2009a
cap drop q5_lrremdezr_p0911
egen q5_lrremdezr_p0911_2009a = cut(lr_remdezr_pre_p0911) if year==2009, group(5)
bys identificad: egen q5_lrremdezr_p0911 = min(q5_lrremdezr_p0911_2009a)
drop q5_lrremdezr_p0911_2009a
label values q5_lrremdezr_p0911 q5

* Quintiles for n_negs_pre / tn_pre / ret_pre (use if variables exist)
capture confirm variable n_negs_pre_p0911
if !_rc {
    cap drop q5_nnegs_p0911_2009a
    cap drop q5_nnegs_p0911
    egen q5_nnegs_p0911_2009a = cut(n_negs_pre_p0911) if year==2009, group(5)
    bys identificad: egen q5_nnegs_p0911 = min(q5_nnegs_p0911_2009a)
    drop q5_nnegs_p0911_2009a
    label values q5_nnegs_p0911 q5
}
capture confirm variable tn_pre_p0911
if !_rc {
    cap drop q5_tn_p0911_2009a
    cap drop q5_tn_p0911
    egen q5_tn_p0911_2009a = cut(tn_pre_p0911) if year==2009, group(5)
    bys identificad: egen q5_tn_p0911 = min(q5_tn_p0911_2009a)
    drop q5_tn_p0911_2009a
    label values q5_tn_p0911 q5
}
capture confirm variable ret_pre_p0911
if !_rc {
    cap drop q5_ret_p0911_2009a
    cap drop q5_ret_p0911
    egen q5_ret_p0911_2009a = cut(ret_pre_p0911) if year==2009, group(5)
    bys identificad: egen q5_ret_p0911 = min(q5_ret_p0911_2009a)
    drop q5_ret_p0911_2009a
    label values q5_ret_p0911 q5
}

* totalflows_n quartile & quintile (time-invariant buckets)
cap drop q4_tf_2009a
cap drop q4_tf
cap drop q5_tf_2009a
cap drop q5_tf
egen q4_tf_2009a = cut(totalflows_n) if year==2009, group(4)
bys identificad: egen q4_tf = min(q4_tf_2009a)
drop q4_tf_2009a
label values q4_tf q4

egen q5_tf_2009a = cut(totalflows_n) if year==2009, group(5)
bys identificad: egen q5_tf = min(q5_tf_2009a)
drop q5_tf_2009a
label values q5_tf q5

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

* ==========================
* FAMILY A — Progressive TVFEs, TF in L/Q4/Q5, window 0911 only
* ==========================

local pre_windows "0911"
local OUT_A "l_firm_emp lr_remdezr lr_remmedr"
local CONN_MAIN "totaltreat_pf_n totaltreat_pw_n"
local CONN_OUT_pw "outtreat_pw_n"
local CONN_IN_pw  "intreat_pw_n"
local CONN_OUT_pf "outtreat_pf_n"
local CONN_IN_pf  "intreat_pf_n"

foreach pw in `pre_windows' {
    local pstart = 2009
    local WIN_POST "inrange(year, `pstart', 2016)"
    local WIN_PRE  "inrange(year, `pstart', 2011)"

    * totalflows_n coding ways
    foreach tf_way in L Q4 Q5 {

        * 6 progressive stages (always include lr_remdezr quintile TVFE)
        forvalues stage = 0/5 {

            * ---- Build timing-specific absorb bundles ----
            local ADD_POST "i.q5_lrremdezr_p0911#treat_year"
            local ADD_PRE  "i.q5_lrremdezr_p0911#placebo_year"

            * totalflows_n as L/Q4/Q5
            if "`tf_way'"=="L" {
                local ADD_POST "`ADD_POST' totalflows_n#treat_year"
                local ADD_PRE  "`ADD_PRE'  totalflows_n#placebo_year"
            }
            else if "`tf_way'"=="Q4" {
                local ADD_POST "`ADD_POST' i.q4_tf#treat_year"
                local ADD_PRE  "`ADD_PRE'  i.q4_tf#placebo_year"
            }
            else if "`tf_way'"=="Q5" {
                local ADD_POST "`ADD_POST' i.q5_tf#treat_year"
                local ADD_PRE  "`ADD_PRE'  i.q5_tf#placebo_year"
            }

            * add n_negs_pre quintile (if present) from stage >=1
            if `stage' >= 1 {
                capture confirm variable q5_nnegs_p0911
                if !_rc {
                    local ADD_POST "`ADD_POST' i.q5_nnegs_p0911#treat_year"
                    local ADD_PRE  "`ADD_PRE'  i.q5_nnegs_p0911#placebo_year"
                }
            }
            * add tn_pre quintile (if present) from stage >=2
            if `stage' >= 2 {
                capture confirm variable q5_tn_p0911
                if !_rc {
                    local ADD_POST "`ADD_POST' i.q5_tn_p0911#treat_year"
                    local ADD_PRE  "`ADD_PRE'  i.q5_tn_p0911#placebo_year"
                }
            }
            * add ret_pre quintile (if present) from stage >=3
            if `stage' >= 3 {
                capture confirm variable q5_ret_p0911
                if !_rc {
                    local ADD_POST "`ADD_POST' i.q5_ret_p0911#treat_year"
                    local ADD_PRE  "`ADD_PRE'  i.q5_ret_p0911#placebo_year"
                }
            }
            * add natjuridica1 categorical from stage >=4
            if `stage' >= 4 {
                local ADD_POST "`ADD_POST' i.natjuridica1#treat_year"
                local ADD_PRE  "`ADD_PRE'  i.natjuridica1#placebo_year"
            }
            * add mode_union_1 categorical from stage >=5
            if `stage' >= 5 {
                local ADD_POST "`ADD_POST' i.mode_union#treat_year"
                local ADD_PRE  "`ADD_PRE'  i.mode_union#placebo_year"
            }

            * ---------- Run all regressions for both spillover measures ----------
            foreach conn of local CONN_MAIN {
                eststo clear
                local estnum = 1

                foreach y of local OUT_A {
                    * DIRECT
                    eststo est`estnum': reghdfe `y' i.treat_ultra##i.treat_year ///
                        if (`s_direct') & `WIN_POST', absorb(`FEYPOST' `ADD_POST') vce(cluster identificad)
                    local ++estnum

                    eststo est`estnum': reghdfe `y' i.treat_ultra##i.placebo_year ///
                        if (`s_direct') & `WIN_PRE', absorb(`FEYPRE' `ADD_PRE') vce(cluster identificad)
                    local ++estnum

                    * OVERALL
                    eststo est`estnum': reghdfe `y' c.`conn'##i.treat_year ///
                        if (`s_spill') & `WIN_POST', absorb(`FEYPOST' `ADD_POST') vce(cluster identificad)
                    local ++estnum

                    eststo est`estnum': reghdfe `y' c.`conn'##i.placebo_year ///
                        if (`s_spill') & `WIN_PRE', absorb(`FEYPRE' `ADD_PRE') vce(cluster identificad)
                    local ++estnum

                    * BELOW / ABOVE
                    eststo est`estnum': reghdfe `y' c.`conn'##i.treat_year ///
                        if (`s_spill') & below_med==1 & `WIN_POST', absorb(`FEYPOST' `ADD_POST') vce(cluster identificad)
                    local ++estnum

                    eststo est`estnum': reghdfe `y' c.`conn'##i.placebo_year ///
                        if (`s_spill') & below_med==1 & `WIN_PRE', absorb(`FEYPRE' `ADD_PRE') vce(cluster identificad)
                    local ++estnum

                    eststo est`estnum': reghdfe `y' c.`conn'##i.treat_year ///
                        if (`s_spill') & above_med==1 & `WIN_POST', absorb(`FEYPOST' `ADD_POST') vce(cluster identificad)
                    local ++estnum

                    eststo est`estnum': reghdfe `y' c.`conn'##i.placebo_year ///
                        if (`s_spill') & above_med==1 & `WIN_PRE', absorb(`FEYPRE' `ADD_PRE') vce(cluster identificad)
                    local ++estnum

                    * INFLOWS/OUTFLOWS (pw)
                    eststo est`estnum': reghdfe `y' c.`CONN_OUT_pw'##i.treat_year ///
                        if (`s_spill') & `WIN_POST', absorb(`FEYPOST' `ADD_POST') vce(cluster identificad)
                    local ++estnum

                    eststo est`estnum': reghdfe `y' c.`CONN_OUT_pw'##i.placebo_year ///
                        if (`s_spill') & `WIN_PRE', absorb(`FEYPRE' `ADD_PRE') vce(cluster identificad)
                    local ++estnum

                    eststo est`estnum': reghdfe `y' c.`CONN_IN_pw'##i.treat_year ///
                        if (`s_spill') & `WIN_POST', absorb(`FEYPOST' `ADD_POST') vce(cluster identificad)
                    local ++estnum

                    eststo est`estnum': reghdfe `y' c.`CONN_IN_pw'##i.placebo_year ///
                        if (`s_spill') & `WIN_PRE', absorb(`FEYPRE' `ADD_PRE') vce(cluster identificad)
                    local ++estnum

                    * INFLOWS/OUTFLOWS (pf)
                    eststo est`estnum': reghdfe `y' c.`CONN_OUT_pf'##i.treat_year ///
                        if (`s_spill') & `WIN_POST', absorb(`FEYPOST' `ADD_POST') vce(cluster identificad)
                    local ++estnum

                    eststo est`estnum': reghdfe `y' c.`CONN_OUT_pf'##i.placebo_year ///
                        if (`s_spill') & `WIN_PRE', absorb(`FEYPRE' `ADD_PRE') vce(cluster identificad)
                    local ++estnum

                    eststo est`estnum': reghdfe `y' c.`CONN_IN_pf'##i.treat_year ///
                        if (`s_spill') & `WIN_POST', absorb(`FEYPOST' `ADD_POST') vce(cluster identificad)
                    local ++estnum

                    eststo est`estnum': reghdfe `y' c.`CONN_IN_pf'##i.placebo_year ///
                        if (`s_spill') & `WIN_PRE', absorb(`FEYPRE' `ADD_PRE') vce(cluster identificad)
                    local ++estnum
                }

                * Export one table per (conn, tf_way, stage)
                esttab using ///
                    "results/tables/MEGA_A_3_conn-`conn'_TF-`tf_way'_stage-`stage'_p`pw'.csv", replace ///
                    keep( ///
                        1.treat_ultra#1.treat_year  1.treat_ultra#1.placebo_year ///
                        1.treat_year#c.`conn'       1.placebo_year#c.`conn'     ///
                        1.treat_year#c.`conn'       1.placebo_year#c.`conn'     ///
                        1.treat_year#c.`conn'       1.placebo_year#c.`conn'     ///
                        1.treat_year#c.`CONN_OUT_pw'  1.placebo_year#c.`CONN_OUT_pw' ///
                        1.treat_year#c.`CONN_IN_pw'   1.placebo_year#c.`CONN_IN_pw'  ///
                        1.treat_year#c.`CONN_OUT_pf'  1.placebo_year#c.`CONN_OUT_pf' ///
                        1.treat_year#c.`CONN_IN_pf'   1.placebo_year#c.`CONN_IN_pf'  ///
                    ) se star(* 0.10 ** 0.05 *** 0.01) b(3) se(3)
            }
        }
    }
}


// local y "lr_remdezr"
// local s_spill  "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0"
// local pstart = 2009
// local WIN_POST "inrange(year, `pstart', 2016)"
// local WIN_PRE  "inrange(year, `pstart', 2011)"
// local FEYPRE        "identificad treat_year industry1_num#placebo_year mode_base_month_num#placebo_year microregion_num#placebo_year"
// local FEYPOST       "identificad placebo_year industry1_num#treat_year mode_base_month_num#treat_year microregion_num#treat_year"
// local ADD_POST "i.mode_union#treat_year i.natjuridica1#treat_year"
// local ADD_PRE "i.mode_union#placebo_year i.natjuridica1#placebo_year"
// local conn "totaltreat_pw_n"
//
//
//  reghdfe `y' c.`conn'##i.treat_year ///
//                         if (`s_spill') & above_med==1 & `WIN_POST', absorb(`FEYPOST' `ADD_POST') vce(cluster identificad)
//                  
//
//  reghdfe `y' c.`conn'##i.placebo_year ///
//                         if (`s_spill') & above_med==1 & `WIN_PRE', absorb(`FEYPRE' `ADD_PRE') vce(cluster identificad)
//                  
