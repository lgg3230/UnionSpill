**************************					
* Preffered Specification
**************************

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
use "$rais_firm/lagos_sample_sep24.dta", clear

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
local s_direct "(lagos_sample_avg==1 & treat_ultra==0 & totaltreat_pw_n<0.01 | lagos_sample_avg==1 & treat_ultra==1)"
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

* --- generate below and above median firms:


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



* --- Always-on TVFE: quartiles of totalflows_n_p0911 (built once) ---
cap drop q4_totalflows_n_p0911_2009a
cap drop q4_totalflows_n_p0911
egen q4_totalflows_n_p0911_2009a  = cut(totalflows_n) if year==2009, group(4)
bys identificad: egen q4_totalflows_n_p0911 = min(q4_totalflows_n_p0911_2009a )
drop q4_totalflows_n_p0911_2009a 
label var q4_totalflows_n_p0911 "quartiles of totalflows in pretreatment period"

* --- Normalize connectivity measure:


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


// normalize by 2009 p90 and scale down by 100 so coefficients scale up by 100
cap drop totaltreat_pw_norm
gen totaltreat_pw_norm = (totaltreat_pw_n / totaltreat_pw_n_p90) 


// get baseline means:

*==============================
* Baseline wages (2009–2011)
*==============================

* Direct sample
cap drop lr_remdezr_pre_o_direct
cap drop lr_remdezr_pre_direct
bys identificad: egen lr_remdezr_pre_o_direct = ///
    mean(lr_remdezr) if year<=2011 & year>=2009 & `s_direct'
bys identificad: egen lr_remdezr_pre_direct = min(lr_remdezr_pre_o_direct)

* Spillover sample
cap drop lr_remdezr_pre_o_spill
cap drop lr_remdezr_pre_spill
bys identificad: egen lr_remdezr_pre_o_spill = ///
    mean(lr_remdezr) if year<=2011 & year>=2009 & `s_spill'
bys identificad: egen lr_remdezr_pre_spill = min(lr_remdezr_pre_o_spill)

* Spillover, below median emp (bm)
cap drop lr_remdezr_pre_o_spill_bm
cap drop lr_remdezr_pre_spill_bm
bys identificad: egen lr_remdezr_pre_o_spill_bm = ///
    mean(lr_remdezr) if year<=2011 & year>=2009 & `s_spill' & below_med
bys identificad: egen lr_remdezr_pre_spill_bm = min(lr_remdezr_pre_o_spill_bm)

* Spillover, above median emp (am)
cap drop lr_remdezr_pre_o_spill_am
cap drop lr_remdezr_pre_spill_am
bys identificad: egen lr_remdezr_pre_o_spill_am = ///
    mean(lr_remdezr) if year<=2011 & year>=2009 & `s_spill' & above_med
bys identificad: egen lr_remdezr_pre_spill_am = min(lr_remdezr_pre_o_spill_am)

* Summaries: baseline wages
sum lr_remdezr_pre_direct // 7.75
sum lr_remdezr_pre_spill // 7.55
sum lr_remdezr_pre_spill_bm // 7.49
sum lr_remdezr_pre_spill_am // 7.60


*==============================
* Baseline employment (2009–2011)
*==============================

* Direct sample
cap drop firm_emp_pre_o_direct
cap drop firm_emp_pre_direct
bys identificad: egen firm_emp_pre_o_direct = ///
    mean(l_firm_emp) if year<=2011 & year>=2009 & `s_direct'
bys identificad: egen firm_emp_pre_direct = min(firm_emp_pre_o_direct)

* Spillover sample
cap drop firm_emp_pre_o_spill
cap drop firm_emp_pre_spill
bys identificad: egen firm_emp_pre_o_spill = ///
    mean(l_firm_emp) if year<=2011 & year>=2009 & `s_spill'
bys identificad: egen firm_emp_pre_spill = min(firm_emp_pre_o_spill)

* Spillover, below median emp (bm)
cap drop firm_emp_pre_o_spill_bm
cap drop firm_emp_pre_spill_bm
bys identificad: egen firm_emp_pre_o_spill_bm = ///
    mean(l_firm_emp) if year<=2011 & year>=2009 & `s_spill' & below_med
bys identificad: egen firm_emp_pre_spill_bm = min(firm_emp_pre_o_spill_bm)

* Spillover, above median emp (am)
cap drop firm_emp_pre_o_spill_am
cap drop firm_emp_pre_spill_am
bys identificad: egen firm_emp_pre_o_spill_am = ///
    mean(l_firm_emp) if year<=2011 & year>=2009 & `s_spill' & above_med
bys identificad: egen firm_emp_pre_spill_am = min(firm_emp_pre_o_spill_am)

* Summaries: baseline employment
sum firm_emp_pre_direct // 3.41
sum firm_emp_pre_spill // 3.56
sum firm_emp_pre_spill_bm // 2.12
sum firm_emp_pre_spill_am // 4.80


					

**************************					
* Preffered Specification
**************************


local OUT_A "lr_remdezr l_firm_emp"
local conn totaltreat_pw_norm
local s_spill  "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0"
local s_direct "(lagos_sample_avg==1 & treat_ultra==0 & totaltreat_pw_n<0.01 | lagos_sample_avg==1 & treat_ultra==1)"
local WIN_POST "inrange(year, 2009, 2016)"
local WIN_PRE  "inrange(year, 2009, 2011)"
local FEYPRE   "identificad treat_year industry1_num#placebo_year mode_base_month_num#placebo_year microregion_num#placebo_year"
local FEYPOST  "identificad placebo_year industry1_num#treat_year  mode_base_month_num#treat_year  microregion_num#treat_year"
local ADD_POST  "totalflows_n#treat_year "
local ADD_PRE   "totalflows_n#placebo_year "
local CONN_OUT_pw "outtreat_pw_norm"
local CONN_IN_pw  "intreat_pw_norm"

            eststo clear
            local estnum = 1

            foreach y of local OUT_A {

                * ---------- DIRECT ----------
                eststo est`estnum': reghdfe `y' i.treat_ultra##i.treat_year ///
                    if (`s_direct') & `WIN_POST', absorb(`FEYPOST' `ADD_POST') vce(cluster identificad)
                local ++estnum

                eststo est`estnum': reghdfe `y' i.treat_ultra##i.placebo_year ///
                    if (`s_direct') & `WIN_PRE', absorb(`FEYPRE' `ADD_PRE') vce(cluster identificad)
                local ++estnum

                * ---------- OVERALL (main spillover) ----------
                eststo est`estnum': reghdfe `y' c.`conn'##i.treat_year ///
                    if (`s_spill') & `WIN_POST', absorb(`FEYPOST' `ADD_POST') vce(cluster identificad)
                local ++estnum

                eststo est`estnum': reghdfe `y' c.`conn'##i.placebo_year ///
                    if (`s_spill') & `WIN_PRE', absorb(`FEYPRE' `ADD_PRE') vce(cluster identificad)
                local ++estnum

                * ---------- BELOW / ABOVE ----------
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

                * ---------- OUTFLOWS / INFLOWS (pw) ----------
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

               }
			pwd
			cap mkdir "results"
cap mkdir "results/tables"

            * ---- Export table (36 columns per outcome) ----
            esttab using "$tables/Table_2.csv", replace ///
                keep( ///
                    1.treat_ultra#1.treat_year  1.treat_ultra#1.placebo_year ///
                    1.treat_year#c.`conn'       1.placebo_year#c.`conn'     ///
                    1.treat_year#c.`conn'       1.placebo_year#c.`conn'     ///
                    1.treat_year#c.`conn'       1.placebo_year#c.`conn'     ///
                    1.treat_year#c.`CONN_OUT_pw'  1.placebo_year#c.`CONN_OUT_pw' ///
                    1.treat_year#c.`CONN_IN_pw'   1.placebo_year#c.`CONN_IN_pw'  ///
                    ) se star(* 0.10 ** 0.05 *** 0.01) b(4) se(3)


