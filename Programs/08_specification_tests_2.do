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



* --- Always-on TVFE: quartiles of totalflows_n_p0911 (built once) ---
cap drop q4_totalflows_n_p0911_2009a q4_totalflows_n_p0911
egen q4_totalflows_n_p0911_2009a  = cut(totalflows_n) if year==2009, group(4)
bys identificad: egen q4_totalflows_n_p0911 = min(q4_totalflows_n_p0911_2009a )
drop q4_totalflows_n_p0911_2009a 
label var q4_totalflows_n_p0911 "quartiles of totalflows in pretreatment period"

* --- Normalize connectivity measure:


cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year==2009, detail
gen totaltreat_pw_n_p90 = r(p90)
gen totaltreat_pw_norm = (totaltreat_pw_n / totaltreat_pw_n_p90) / 100

cap drop intreat_pw_n_p90
cap drop intreat_pw_norm
sum intreat_pw_n if `s_spill' & year==2009, detail
gen intreat_pw_n_p90 = r(p90)
gen intreat_pw_norm = (intreat_pw_n / intreat_pw_n_p90) / 100

cap drop outtreat_pw_n_p90
cap drop outtreat_pw_norm
sum outtreat_pw_n if `s_spill' & year==2009, detail
gen outtreat_pw_n_p90 = r(p90)
gen outtreat_pw_norm = (outtreat_pw_n / outtreat_pw_n_p90) / 100


// normalize by 2009 p90 and scale down by 100 so coefficients scale up by 100
gen totaltreat_pw_norm = (totaltreat_pw_n / totaltreat_pw_n_p90) / 100

* --- Always-on TVFE: quartiles of lr_remdezr_pre (built once) ---
cap drop q4_lr_remdezr_pre_p0911_2009a q4_lr_remdezr_pre_p0911
egen q4_lr_remdezr_pre_p0911_2009a  = cut(lr_remdezr_pre_p0911) if year==2009, group(4)
bys identificad: egen q4_lr_remdezr_pre_p0911 = min(q4_lr_remdezr_pre_p0911_2009a )
drop q4_lr_remdezr_pre_p0911_2009a 
label var q4_lr_remdezr_pre_p0911 "quartiles of lr_remdezr_pre in pretreatment period"

* --- Only run the 0911 window ---
local pre_windows "0911"

* --- Only these connectivity measures ---
local CONN_A "totaltreat_pf_n totaltreat_pw_norm"

* --- Extra inflow/outflow measures (both pw & pf) are always included in each table ---
local CONN_OUT_pw "outtreat_pw_norm"
local CONN_IN_pw  "intreat_pw_norm"
local CONN_OUT_pf "outtreat_pf_norm"
local CONN_IN_pf  "intreat_pf_norom"

* --- Outcomes to show ---
local OUT_A  "l_firm_emp lr_remdezr lr_remmedr"

* --- FE blocks (lists, to be inserted into absorb()) ---
local FEYPRE   "identificad treat_year industry1_num#placebo_year mode_base_month_num#placebo_year microregion_num#placebo_year"
local FEYPOST  "identificad placebo_year industry1_num#treat_year  mode_base_month_num#treat_year  microregion_num#treat_year"

* --- Progressive specs (names are used in file names) ---
* base: only totalflows_n quartiles (always-on TVFE)
* +remdezr: add lr_remdezr_pre quartiles
* +fempQ: add firm_emp_pre quartiles  
* +femp5: add firm_emp_pre quintiles
* +all: add both lr_remdezr_pre and firm_emp_pre quartiles
local SPEC_LIST "base plus_remdezr plus_fempQ plus_femp5 plus_all"

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


foreach pw in `pre_windows' {
    local pstart = 2009
    local WIN_POST "inrange(year, `pstart', 2016)"
    local WIN_PRE  "inrange(year, `pstart', 2011)"

    foreach spec of local SPEC_LIST {

        * ---- Start with mandatory TVFE (totalflows_n quartiles) ----
        local ADD_POST  "i.q4_totalflows_n_p0911#treat_year"
        local ADD_PRE   "i.q4_totalflows_n_p0911#placebo_year"

        * ---- Progressively add more TVFE by spec ----
        if inlist("`spec'","plus_remdezr","plus_all") {
            * Add lr_remdezr_pre quartiles
            local ADD_POST "`ADD_POST' i.q4_lr_remdezr_pre_p0911#treat_year"
            local ADD_PRE  "`ADD_PRE'  i.q4_lr_remdezr_pre_p0911#placebo_year"
        }

        if inlist("`spec'","plus_fempQ","plus_all") {
            * Add firm_emp_pre quartiles
            cap drop q4_fep_2009a 
			cap drop q4_fep
            egen q4_fep_2009a = cut(firm_emp_pre_p`pw') if year==2009, group(4)
            bys identificad: egen q4_fep = min(q4_fep_2009a)
            drop q4_fep_2009a
            label values q4_fep q4
            local ADD_POST "`ADD_POST' i.q4_fep#treat_year"
            local ADD_PRE  "`ADD_PRE'  i.q4_fep#placebo_year"
        }

        if "`spec'"=="plus_femp5" {
            * Add firm_emp_pre quintiles
            cap drop q5_fep_2009a 
			cap drop q5_fep
            egen q5_fep_2009a = cut(firm_emp_pre_p`pw') if year==2009, group(5)
            bys identificad: egen q5_fep = min(q5_fep_2009a)
            drop q5_fep_2009a
            label values q5_fep q5
            local ADD_POST "`ADD_POST' i.q5_fep#treat_year"
            local ADD_PRE  "`ADD_PRE'  i.q5_fep#placebo_year"
        }

        * ---- Run tables for each spillover measure (pf and pw totals) ----
        foreach conn of local CONN_A {

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

                * ---------- OUTFLOWS / INFLOWS (pf) ----------
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

            * ---- Export table (36 columns per outcome) ----
            esttab using "results/tables/MEGA_A_`conn'_spec-`spec'_p`pw'_ctf.csv", replace ///
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



local y lr_remdezr
local conn totaltreat_pw_n
local s_spill  "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0"
local WIN_POST "inrange(year, 2009, 2016)"
local WIN_PRE  "inrange(year, 2009, 2011)"
local FEYPRE   "identificad treat_year industry1_num#placebo_year mode_base_month_num#placebo_year microregion_num#placebo_year"
local FEYPOST  "identificad placebo_year industry1_num#treat_year  mode_base_month_num#treat_year  microregion_num#treat_year"
local ADD_POST  "i.q4_totalflows_n_p0911#treat_year q4_lr_remdezr_pre_p0911#treat_year"
local ADD_PRE   "i.q4_totalflows_n_p0911#placebo_year q4_lr_remdezr_pre_p0911#placebo_year"


reghdfe `y' c.`conn'##i.treat_year ///
                    if (`s_spill') & `WIN_POST', absorb(`FEYPOST' `ADD_POST') vce(cluster identificad)
                
				
reghdfe `y' c.`conn'##i.placebo_year ///
                    if (`s_spill') & `WIN_PRE', absorb(`FEYPRE' `ADD_PRE') vce(cluster identificad)
					

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
local CONN_OUT_pf "outtreat_pf_norm"
local CONN_IN_pf  "intreat_pf_norm"

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

                * ---------- OUTFLOWS / INFLOWS (pf) ----------
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
			pwd
			cap mkdir "results"
cap mkdir "results/tables"

            * ---- Export table (36 columns per outcome) ----
            esttab using "results/tables/preffered_Oct_24_2025.csv", replace ///
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


