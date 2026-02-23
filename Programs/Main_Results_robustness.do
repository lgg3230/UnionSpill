********************************************************************************
* UNION SPILLOVERS — ROBUSTNESS TO ADDITIONAL PRE-TREATMENT CONTROLS
* Purpose: Test sensitivity of main results to controlling for total worker
*          flows, total churn, and churn rate (all pre-treatment, 4 bins × year)
* Output: CSV files with numeric results + PDF event study figures
* Panels: A (zero-connectivity controls), B (<=1% connectivity controls),
*         C (all untreated controls)
* Specifications: baseline, totalflows, churn, churn_rate,
*                 tf_07_11, tf_09_11, tfpw_07_11, tfpw_09_11
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/FinalResults_robustness_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
di "Stata version: `c(stata_version)'"

********************************************************************************
* SECTION 1: SETUP AND DATA MERGE
********************************************************************************

capture cls

* ===============================
* SET PATHNAME FOR THE FOLDER WHERE lagos_sample_sep24_pct_unionexp_ext_df2.dta IS AND THEN UNCOMMENT LINE (REMOVE "//") !!!!!

* SET PATHNAME TO TABLES FOR THE FOLDER WHERE YOU WANNA STORE THE RESULTS

* SET PATHNAME TO GRAPHS FOR THE FOLDER WHERE YOU WANNA STORE GRAPHS.

// global rais_firm "PATHNAME"
// global tables "PATHNAME TO TABLES"
// global graphs "PATHNAME TO GRAPHS"
// global rais_aux "PATHNAME"

* ===============================

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

* ===============================
* MERGE TURNOVER DATA
* ===============================

di as result "Merging turnover data..."

preserve
	import delimited "$rais_aux/corrected_turnover_sample.csv", clear
	keep identificad year separations_u hired_u avg_emp
	tostring identificad, replace format(%014.0f) force
	tempfile turnover
	save `turnover'
restore

merge 1:1 identificad year using `turnover', keep(master match) nogen

* Construct churn variables
gen double churn_u = separations_u + hired_u
label var churn_u "Total churn (separations + hires, uncensored)"

gen double churn_rate_u = (separations_u + hired_u) / avg_emp if avg_emp > 0
label var churn_rate_u "Churn rate (churn / avg employment, uncensored)"

di as result "Turnover data merged."

* ===============================
* MERGE YEARLY PAIRWISE FLOWS DATA
* ===============================

di as result "Merging yearly pairwise flows data..."

preserve
	import delimited "$rais_aux/totalflows_wide_2007_2011.csv", clear
	tostring identificad, replace format(%014.0f) force
	tempfile totalflows_wide
	save `totalflows_wide'
restore

merge m:1 identificad using `totalflows_wide', keep(master match) nogen

* Construct pre-treatment flow averages (missing-friendly).
* Average across year pairs with non-missing data; denominator = number
* of non-missing pairs. Follows the pattern in 05_yearly_employers.do.

* --- totalflows_pre_07_11: average of 4 year pairs ---
gen double totalflows_pre_07_11 = 0
gen totalflows_pre_07_11_cnt = 0
foreach yp in totalflows_07_08 totalflows_08_09 totalflows_09_10 totalflows_10_11 {
    replace totalflows_pre_07_11 = totalflows_pre_07_11 + `yp' if !missing(`yp')
    replace totalflows_pre_07_11_cnt = totalflows_pre_07_11_cnt + (!missing(`yp'))
}
replace totalflows_pre_07_11 = totalflows_pre_07_11 / totalflows_pre_07_11_cnt if totalflows_pre_07_11_cnt > 0
replace totalflows_pre_07_11 = . if totalflows_pre_07_11_cnt == 0
drop totalflows_pre_07_11_cnt

* --- totalflows_pre_09_11: average of 2 year pairs ---
gen double totalflows_pre_09_11 = 0
gen totalflows_pre_09_11_cnt = 0
foreach yp in totalflows_09_10 totalflows_10_11 {
    replace totalflows_pre_09_11 = totalflows_pre_09_11 + `yp' if !missing(`yp')
    replace totalflows_pre_09_11_cnt = totalflows_pre_09_11_cnt + (!missing(`yp'))
}
replace totalflows_pre_09_11 = totalflows_pre_09_11 / totalflows_pre_09_11_cnt if totalflows_pre_09_11_cnt > 0
replace totalflows_pre_09_11 = . if totalflows_pre_09_11_cnt == 0
drop totalflows_pre_09_11_cnt

* --- totalflows_pw_pre_07_11: average of 4 year pairs (per-worker) ---
gen double totalflows_pw_pre_07_11 = 0
gen totalflows_pw_pre_07_11_cnt = 0
foreach yp in totalflows_pw_07_08 totalflows_pw_08_09 totalflows_pw_09_10 totalflows_pw_10_11 {
    replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 + `yp' if !missing(`yp')
    replace totalflows_pw_pre_07_11_cnt = totalflows_pw_pre_07_11_cnt + (!missing(`yp'))
}
replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 / totalflows_pw_pre_07_11_cnt if totalflows_pw_pre_07_11_cnt > 0
replace totalflows_pw_pre_07_11 = . if totalflows_pw_pre_07_11_cnt == 0
drop totalflows_pw_pre_07_11_cnt

* --- totalflows_pw_pre_09_11: average of 2 year pairs (per-worker) ---
gen double totalflows_pw_pre_09_11 = 0
gen totalflows_pw_pre_09_11_cnt = 0
foreach yp in totalflows_pw_09_10 totalflows_pw_10_11 {
    replace totalflows_pw_pre_09_11 = totalflows_pw_pre_09_11 + `yp' if !missing(`yp')
    replace totalflows_pw_pre_09_11_cnt = totalflows_pw_pre_09_11_cnt + (!missing(`yp'))
}
replace totalflows_pw_pre_09_11 = totalflows_pw_pre_09_11 / totalflows_pw_pre_09_11_cnt if totalflows_pw_pre_09_11_cnt > 0
replace totalflows_pw_pre_09_11 = . if totalflows_pw_pre_09_11_cnt == 0
drop totalflows_pw_pre_09_11_cnt

label var totalflows_pre_07_11 "Avg yearly total flows 2007-2011"
label var totalflows_pre_09_11 "Avg yearly total flows 2009-2011"
label var totalflows_pw_pre_07_11 "Avg yearly per-worker flows 2007-2011"
label var totalflows_pw_pre_09_11 "Avg yearly per-worker flows 2009-2011"

di as result "Yearly pairwise flows data merged."

* ===============================
* GLOBAL SETTINGS
* ===============================
local conn "totaltreat_pw_norm"
local g = 4

* Sample definitions
local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"
local s_direct_A "(treat_ultra==0 & totaltreat_pw_n==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_direct_B "(treat_ultra==0 & totaltreat_pw_n<=0.01 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
local s_direct_C "(treat_ultra==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"

keep if year>=2009
keep if lagos_sample_avg==1

di as result "Sample size: " _N

* ===============================
* OUTCOME LIST
* ===============================
global main_outcomes "lr_remdezr_w lr_remdezr_h_w l_firm_emp numb_clauses"

********************************************************************************
* SECTION 2: VARIABLE CREATION
********************************************************************************

di _newline(1)
di as result "Creating necessary variables..."

* Treatment indicators
cap drop placebo_year
gen byte placebo_year = (year<2011)
label var placebo_year "Pre-treatment period"

cap drop treat_year
gen byte treat_year = (year>=2012)
label var treat_year "Post-treatment period"

* CBA periods
cap drop cba_period
cap drop pre_treat_cba
cap drop post_treat_cba

gen cba_period = .
replace cba_period = 1 if avg_file_date==earliest2009_avg-1 & !missing(avg_file_date)
replace cba_period = 2 if avg_file_date==second_cba_avg & !missing(avg_file_date)
replace cba_period = 3 if inrange(avg_file_date, mdy(1,1,2013), mdy(12,31,2013)) & cba_period==.
replace cba_period = 4 if inrange(avg_file_date, mdy(1,1,2014), mdy(12,31,2014)) & cba_period==.
replace cba_period = 5 if inrange(avg_file_date, mdy(1,1,2015), mdy(12,31,2015)) & cba_period==.
replace cba_period = 6 if inrange(avg_file_date, mdy(1,1,2016), mdy(12,31,2016)) & cba_period==.
label var cba_period "CBA negotiation period (1=earliest, 2=second, 3-6=post-treatment years)"

gen pre_treat_cba = cond(cba_period<2,1,0)
label var pre_treat_cba "Pre-treatment CBA period indicator"

gen post_treat_cba = cond(cba_period>=3,1,0) if !missing(cba_period)
label var post_treat_cba "Post-treatment CBA period indicator"

* Scaling connectivity to the 90th percentile among untreated firms
cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
quietly sum totaltreat_pw_n if `s_spill' & year==2009, detail
gen totaltreat_pw_n_p90 = r(p90)
label var totaltreat_pw_n_p90 "90th percentile of total flows to treated (spillover sample)"

gen totaltreat_pw_norm = (totaltreat_pw_n / totaltreat_pw_n_p90)
label var totaltreat_pw_norm "Connectivity scaled to 90th percentile among untreated firms"

* Pre-treatment firm characteristics
cap drop firm_emp_pre_o
cap drop firm_emp_pre
quietly {
    bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year,2009,2011)
    bys identificad: egen firm_emp_pre = min(firm_emp_pre_o)
    drop firm_emp_pre_o
    label var firm_emp_pre "Pre-treatment firm employment (average 2009-2011)"
}

* Pre-treatment outcome averages
foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp turnover {
    cap drop `outcome'_pre_o
	cap drop `outcome'_pre
    quietly {
        bys identificad: egen `outcome'_pre_o = mean(`outcome') if inrange(year, 2009, 2011)
        bys identificad: egen `outcome'_pre = min(`outcome'_pre_o)
        drop `outcome'_pre_o
    }
}

* Numb_clauses pre-treatment average
capture confirm variable numb_clauses
if _rc == 0 {
    cap drop numb_clauses_pre_o
	cap drop numb_clauses_pre
    quietly {
        bys identificad: egen numb_clauses_pre_o = mean(numb_clauses) if inrange(cba_period,1,2)
        bys identificad: egen numb_clauses_pre = min(numb_clauses_pre_o)
        drop numb_clauses_pre_o
    }
}

* Pre-treatment averages for churn variables
foreach v in churn_u churn_rate_u {
    cap drop `v'_pre_o
    cap drop `v'_pre
    quietly {
        bys identificad: egen `v'_pre_o = mean(`v') if inrange(year, 2009, 2011)
        bys identificad: egen `v'_pre = min(`v'_pre_o)
        drop `v'_pre_o
    }
}

* ===============================
* CREATE CONTROL BINS (4 bins)
* ===============================

* Total flows bins
cap drop totalflows_n4_o
cap drop totalflows_n4
quietly {
    egen totalflows_n4_o = cut(totalflows_n) if year==2009 & in_balanced_panel==1, group(4)
    bys identificad: egen totalflows_n4 = min(totalflows_n4_o)
    drop totalflows_n4_o
}

* Pre-treatment employment bins
cap drop firm_emp_pre4_o
cap drop firm_emp_pre4
quietly {
    egen firm_emp_pre4_o = cut(firm_emp_pre) if year==2009 & in_balanced_panel==1, group(4)
    bys identificad: egen firm_emp_pre4 = min(firm_emp_pre4_o)
    drop firm_emp_pre4_o
}

* Log pre-treatment employment
cap drop l_firm_emp_pre
gen double l_firm_emp_pre = ln(firm_emp_pre)
label var l_firm_emp_pre "Log pre-treatment firm employment"

cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
quietly {
    egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) if year==2009 & in_balanced_panel==1, group(4)
    bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
    drop l_firm_emp_pre4_o
}

* Churn bins
cap drop churn_u_pre4_o
cap drop churn_u_pre4
quietly {
    egen churn_u_pre4_o = cut(churn_u_pre) if year==2009 & in_balanced_panel==1, group(4)
    bys identificad: egen churn_u_pre4 = min(churn_u_pre4_o)
    drop churn_u_pre4_o
}

* Churn rate bins
cap drop churn_rate_u_pre4_o
cap drop churn_rate_u_pre4
quietly {
    egen churn_rate_u_pre4_o = cut(churn_rate_u_pre) if year==2009 & in_balanced_panel==1, group(4)
    bys identificad: egen churn_rate_u_pre4 = min(churn_rate_u_pre4_o)
    drop churn_rate_u_pre4_o
}

* Yearly pairwise flow bins (4 bins)
* Note: replace missing bins with 0 (reference category) to match R's ntile behavior
* — firms without flow data stay in the sample absorbed into the base group.
foreach v in totalflows_pre_07_11 totalflows_pre_09_11 totalflows_pw_pre_07_11 totalflows_pw_pre_09_11 {
    cap drop `v'4_o
    cap drop `v'4
    quietly {
        egen `v'4_o = cut(`v') if year==2009 & in_balanced_panel==1, group(4)
        bys identificad: egen `v'4 = min(`v'4_o)
        drop `v'4_o
        replace `v'4 = 0 if missing(`v'4)
    }
}

* Pre-treatment outcome bins (4 bins)
foreach wage in lr_remdezr_w lr_remdezr_h_w l_firm_emp numb_clauses turnover {
    cap drop `wage'_pre4
    quietly {
        egen `wage'_pre4_o = cut(`wage'_pre) if year==2009 & in_balanced_panel==1, group(4)
        bys identificad: egen `wage'_pre4 = min(`wage'_pre4_o)
        drop `wage'_pre4_o
    }
}

* ===============================
* ADDITIONAL VARIABLE CREATION
* ===============================

// Among untreated firms, how many are covered by a union that also covers treated firms?
capture confirm new variable treat_union
if _rc {
    drop treat_union
}
gen treat_union = cond(treat_union_exp_all>0,1,0)
label var treat_union "Indicates whether a firm's union also covers at least one treated firm"

// Geographic sharing of treatment exposure
cap drop geo_exp
bys microregion (year): egen geo_exp = mean(treat_ultra)
label var geo_exp "Share of treated among sample in a given microregion"

cap drop geo_mun_exp
bys municipio (year): egen geo_mun_exp = mean(treat_ultra)
label var geo_mun_exp "Share of treated among sample in a given municipality"

// Microregion-industry indicator
cap drop micro_ind
egen micro_ind = group(microregion industry)
label var micro_ind "Industry x microregion cell indicator"

cap drop mic_ind_exp
bys micro_ind (year): egen mic_ind_exp = mean(treat_ultra)
label var mic_ind_exp "Proportion of in-sample firms treated within each micro-industry cell"

cap drop mic_ind_treat
gen mic_ind_treat = cond(mic_ind_exp>0,1,0)
label var mic_ind_treat "Indicates whether a firm's micro-industry cell covers at least one treated firm"

cap drop ind_exp_o
bys industry1 (year): egen ind_exp_o = mean(treat_ultra)
label var ind_exp_o "Share of treated firms within each industry"

di as result "All variables created"

********************************************************************************
* SECTION 3: MAIN ESTIMATION LOOP
********************************************************************************

di _newline(2)
di as result "{hline 80}"
di as result "STARTING ROBUSTNESS ESTIMATION LOOP"
di as result "{hline 80}"

* Define specification names and their extra absorb terms
local spec_list "baseline totalflows churn churn_rate tf_07_11 tf_09_11 tfpw_07_11 tfpw_09_11"
local extra_year_baseline ""
local extra_cba_baseline ""
local extra_year_totalflows "ib0.totalflows_n4#i.year"
local extra_cba_totalflows "ib0.totalflows_n4#i.cba_period"
local extra_year_churn "ib0.churn_u_pre4#i.year"
local extra_cba_churn "ib0.churn_u_pre4#i.cba_period"
local extra_year_churn_rate "ib0.churn_rate_u_pre4#i.year"
local extra_cba_churn_rate "ib0.churn_rate_u_pre4#i.cba_period"
local extra_year_tf_07_11 "ib0.totalflows_pre_07_114#i.year"
local extra_cba_tf_07_11 "ib0.totalflows_pre_07_114#i.cba_period"
local extra_year_tf_09_11 "ib0.totalflows_pre_09_114#i.year"
local extra_cba_tf_09_11 "ib0.totalflows_pre_09_114#i.cba_period"
local extra_year_tfpw_07_11 "ib0.totalflows_pw_pre_07_114#i.year"
local extra_cba_tfpw_07_11 "ib0.totalflows_pw_pre_07_114#i.cba_period"
local extra_year_tfpw_09_11 "ib0.totalflows_pw_pre_09_114#i.year"
local extra_cba_tfpw_09_11 "ib0.totalflows_pw_pre_09_114#i.cba_period"

foreach spec of local spec_list {

    di _newline(3)
    di as result "======================================================================="
    di as result "SPECIFICATION: `spec'"
    di as result "======================================================================="

    * ===========================
    * BUILD FIXED EFFECTS STRINGS
    * ===========================

    * Base FE (year-based outcomes)
    local base_fe "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"

    * Base FE (CBA-based outcomes)
    local base_fe_cba "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period"

    * Extra controls for this specification
    local extra_year "`extra_year_`spec''"
    local extra_cba "`extra_cba_`spec''"

    * ===========================
    * INITIALIZE OUTPUT FILES
    * ===========================

    * Direct effects Panel A
    capture erase "$tables/results_direct_panelA_`spec'.csv"
    tempname fh
    file open `fh' using "$tables/results_direct_panelA_`spec'.csv", write replace
    file write `fh' "spec,section,outcome,row_type,value" _n
    file close `fh'

    * Direct effects Panel B
    capture erase "$tables/results_direct_panelB_`spec'.csv"
    file open `fh' using "$tables/results_direct_panelB_`spec'.csv", write replace
    file write `fh' "spec,section,outcome,row_type,value" _n
    file close `fh'

    * Direct effects Panel C
    capture erase "$tables/results_direct_panelC_`spec'.csv"
    file open `fh' using "$tables/results_direct_panelC_`spec'.csv", write replace
    file write `fh' "spec,section,outcome,row_type,value" _n
    file close `fh'

    * Spillover effects
    capture erase "$tables/results_spill_`spec'.csv"
    file open `fh' using "$tables/results_spill_`spec'.csv", write replace
    file write `fh' "spec,section,outcome,row_type,value" _n
    file close `fh'

    * ===========================
    * PART A: DIRECT EFFECTS — PANEL A (zero-connectivity controls)
    * ===========================

    di _newline(2)
    di as result "-----------------------------------------------------------------------"
    di as result "DIRECT EFFECTS — PANEL A (zero connectivity controls)"
    di as result "-----------------------------------------------------------------------"

    * Year-based outcomes
    foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {

        di _newline(1)
        di as text "Estimating: `outcome' (Panel A)"

        * Full absorb string for this outcome
        local absorb_post "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"
        local absorb_pre  "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"
        local absorb_es   "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

        * Post-treatment regression
        quietly reghdfe `outcome' treat_ultra##i.treat_year if `s_direct_A', ///
            absorb(`absorb_post') vce(cluster identificad)

        local b_post = _b[1.treat_ultra#1.treat_year]
        local se_post = _se[1.treat_ultra#1.treat_year]
        local p_post = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
        local n_obs = e(N)
        local n_estab = e(N_clust)

        * Pre-treatment regression (placebo test)
        quietly reghdfe `outcome' treat_ultra##i.placebo_year if `s_direct_A' & year<=2011, ///
            absorb(`absorb_pre') vce(cluster identificad)

        local b_pre = _b[1.treat_ultra#1.placebo_year]
        local se_pre = _se[1.treat_ultra#1.placebo_year]
        local p_pre = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

        * Stars
        local stars_post ""
        if `p_post' < 0.01 local stars_post "***"
        else if (`p_post' < 0.05 & `p_post' > 0.01) local stars_post "**"
        else if (`p_post' < 0.10 & `p_post' > 0.05) local stars_post "*"

        local stars_pre ""
        if `p_pre' < 0.01 local stars_pre "***"
        else if (`p_pre' < 0.05 & `p_pre' > 0.01) local stars_pre "**"
        else if (`p_pre' < 0.10 & `p_pre' > 0.05) local stars_pre "*"

        * Write to file
        tempname fh
        file open `fh' using "$tables/results_direct_panelA_`spec'.csv", write append
        file write `fh' `""`spec'";"direct_A";"`outcome'";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
        file write `fh' `""`spec'";"direct_A";"`outcome'";"main_se";"' %9.4f (`se_post') `"""' _n
        file write `fh' `""`spec'";"direct_A";"`outcome'";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
        file write `fh' `""`spec'";"direct_A";"`outcome'";"pre_se";"' %9.4f (`se_pre') `"""' _n
        file write `fh' `""`spec'";"direct_A";"`outcome'";"n_obs";"' %12.0fc (`n_obs') `"""' _n
        file write `fh' `""`spec'";"direct_A";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""' _n
        file close `fh'

        * Event study
        quietly reghdfe `outcome' i.treat_ultra##ib2011.year if `s_direct_A', ///
            absorb(`absorb_es') vce(cluster identificad)

        estimates store es_dA_`outcome'

        * Joint F-test for pre-trends
        testparm 1.treat_ultra#i(2009 2010).year
        local pre_ftest_pval = r(p)

        tempname fh
        file open `fh' using "$tables/results_direct_panelA_`spec'.csv", write append
        file write `fh' `""`spec'";"direct_A";"`outcome'";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""' _n
        file close `fh'

        local post_coef = string(`b_post', "%9.4f")
        local post_se = string(`se_post', "%9.4f")
        local pre_pval = string(`pre_ftest_pval', "%9.3f")

        coefplot es_dA_`outcome', ///
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
            ytitle("Dynamic DiD coefficients", size(small)) ///
            note("P-value for pre-trend test = `pre_pval'") ///
            graphregion(color(white)) bgcolor(white) ///
            ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) ///
            text(0.05 6 "`post_coef' (`post_se')", color(blue) size(small))

        graph export "$graphs/es_direct_panelA_`outcome'_`spec'.pdf", as(pdf) replace

        estimates drop es_dA_`outcome'
    }

    * numb_clauses (CBA periods) — Panel A
    capture confirm variable numb_clauses
    if _rc == 0 {

        di _newline(1)
        di as text "Estimating: numb_clauses (CBA periods, Panel A)"

        local absorb_cba_post "`base_fe_cba' ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"
        local absorb_cba_pre  "`base_fe_cba' ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"
        local absorb_cba_es   "`base_fe_cba' ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

        * Post-treatment
        quietly reghdfe numb_clauses i.treat_ultra##post_treat_cba if `s_direct_A' & !missing(cba_period), ///
            absorb(`absorb_cba_post') vce(cluster identificad)

        local b_post = _b[1.treat_ultra#1.post_treat_cba]
        local se_post = _se[1.treat_ultra#1.post_treat_cba]
        local p_post = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
        local n_obs = e(N)
        local n_estab = e(N_clust)

        * Pre-treatment
        quietly reghdfe numb_clauses i.treat_ultra##pre_treat_cba if `s_direct_A' & !missing(cba_period) & cba_period<=2, ///
            absorb(`absorb_cba_pre') vce(cluster identificad)

        local b_pre = _b[1.treat_ultra#1.pre_treat_cba]
        local se_pre = _se[1.treat_ultra#1.pre_treat_cba]
        local p_pre = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

        * Stars
        local stars_post ""
        if `p_post' < 0.01 local stars_post "***"
        else if (`p_post' < 0.05 & `p_post' > 0.01) local stars_post "**"
        else if (`p_post' < 0.10 & `p_post' > 0.05) local stars_post "*"

        local stars_pre ""
        if `p_pre' < 0.01 local stars_pre "***"
        else if (`p_pre' < 0.05 & `p_pre' > 0.01) local stars_pre "**"
        else if (`p_pre' < 0.10 & `p_pre' > 0.05) local stars_pre "*"

        * Write
        tempname fh
        file open `fh' using "$tables/results_direct_panelA_`spec'.csv", write append
        file write `fh' `""`spec'";"direct_A";"numb_clauses";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
        file write `fh' `""`spec'";"direct_A";"numb_clauses";"main_se";"' %9.4f (`se_post') `"""' _n
        file write `fh' `""`spec'";"direct_A";"numb_clauses";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
        file write `fh' `""`spec'";"direct_A";"numb_clauses";"pre_se";"' %9.4f (`se_pre') `"""' _n
        file write `fh' `""`spec'";"direct_A";"numb_clauses";"n_obs";"' %12.0fc (`n_obs') `"""' _n
        file write `fh' `""`spec'";"direct_A";"numb_clauses";"n_estab";"' %12.0fc (`n_estab') `"""' _n
        file close `fh'

        * Event study
        quietly reghdfe numb_clauses i.treat_ultra##ib2.cba_period if `s_direct_A' & !missing(cba_period), ///
            absorb(`absorb_cba_es') vce(cluster identificad)

        estimates store es_clA

        * Joint F-test for pre-trends
        testparm 1.treat_ultra#1.cba_period
        local pre_ftest_pval = r(p)

        tempname fh
        file open `fh' using "$tables/results_direct_panelA_`spec'.csv", write append
        file write `fh' `""`spec'";"direct_A";"numb_clauses";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""' _n
        file close `fh'

        local post_coef = string(`b_post', "%9.4f")
        local post_se = string(`se_post', "%9.4f")
        local pre_pval = string(`pre_ftest_pval', "%9.3f")

        coefplot es_clA, ///
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
            note("P-value for pre-trend test = `pre_pval'") ///
            graphregion(color(white)) bgcolor(white) ///
            ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) ///
            text(2.5 4 "`post_coef' (`post_se')", color(blue) size(small))

        graph export "$graphs/es_direct_panelA_numb_clauses_`spec'.pdf", as(pdf) replace

        estimates drop es_clA
    }

    * ===========================
    * PART B: DIRECT EFFECTS — PANEL B (<=1% connectivity controls)
    * ===========================

    di _newline(2)
    di as result "-----------------------------------------------------------------------"
    di as result "DIRECT EFFECTS — PANEL B (<=1% connectivity controls)"
    di as result "-----------------------------------------------------------------------"

    * Year-based outcomes
    foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {

        di _newline(1)
        di as text "Estimating: `outcome' (Panel B)"

        local absorb_post "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"
        local absorb_pre  "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"
        local absorb_es   "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

        * Post-treatment regression
        quietly reghdfe `outcome' treat_ultra##i.treat_year if `s_direct_B', ///
            absorb(`absorb_post') vce(cluster identificad)

        local b_post = _b[1.treat_ultra#1.treat_year]
        local se_post = _se[1.treat_ultra#1.treat_year]
        local p_post = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
        local n_obs = e(N)
        local n_estab = e(N_clust)

        * Pre-treatment regression
        quietly reghdfe `outcome' treat_ultra##i.placebo_year if `s_direct_B' & year<=2011, ///
            absorb(`absorb_pre') vce(cluster identificad)

        local b_pre = _b[1.treat_ultra#1.placebo_year]
        local se_pre = _se[1.treat_ultra#1.placebo_year]
        local p_pre = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

        * Stars
        local stars_post ""
        if `p_post' < 0.01 local stars_post "***"
        else if (`p_post' < 0.05 & `p_post' > 0.01) local stars_post "**"
        else if (`p_post' < 0.10 & `p_post' > 0.05) local stars_post "*"

        local stars_pre ""
        if `p_pre' < 0.01 local stars_pre "***"
        else if (`p_pre' < 0.05 & `p_pre' > 0.01) local stars_pre "**"
        else if (`p_pre' < 0.10 & `p_pre' > 0.05) local stars_pre "*"

        * Write
        tempname fh
        file open `fh' using "$tables/results_direct_panelB_`spec'.csv", write append
        file write `fh' `""`spec'";"direct_B";"`outcome'";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
        file write `fh' `""`spec'";"direct_B";"`outcome'";"main_se";"' %9.4f (`se_post') `"""' _n
        file write `fh' `""`spec'";"direct_B";"`outcome'";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
        file write `fh' `""`spec'";"direct_B";"`outcome'";"pre_se";"' %9.4f (`se_pre') `"""' _n
        file write `fh' `""`spec'";"direct_B";"`outcome'";"n_obs";"' %12.0fc (`n_obs') `"""' _n
        file write `fh' `""`spec'";"direct_B";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""' _n
        file close `fh'

        * Event study
        quietly reghdfe `outcome' i.treat_ultra##ib2011.year if `s_direct_B', ///
            absorb(`absorb_es') vce(cluster identificad)

        estimates store es_dB_`outcome'

        * Joint F-test for pre-trends
        testparm 1.treat_ultra#i(2009 2010).year
        local pre_ftest_pval = r(p)

        tempname fh
        file open `fh' using "$tables/results_direct_panelB_`spec'.csv", write append
        file write `fh' `""`spec'";"direct_B";"`outcome'";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""' _n
        file close `fh'

        local post_coef = string(`b_post', "%9.4f")
        local post_se = string(`se_post', "%9.4f")
        local pre_pval = string(`pre_ftest_pval', "%9.3f")

        coefplot es_dB_`outcome', ///
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
            ytitle("Dynamic DiD coefficients", size(small)) ///
            note("P-value for pre-trend test = `pre_pval'") ///
            graphregion(color(white)) bgcolor(white) ///
            ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) ///
            text(0.05 6 "`post_coef' (`post_se')", color(blue) size(small))

        graph export "$graphs/es_direct_panelB_`outcome'_`spec'.pdf", as(pdf) replace

        estimates drop es_dB_`outcome'
    }

    * numb_clauses (CBA periods) — Panel B
    capture confirm variable numb_clauses
    if _rc == 0 {

        di _newline(1)
        di as text "Estimating: numb_clauses (CBA periods, Panel B)"

        local absorb_cba_post "`base_fe_cba' ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"
        local absorb_cba_pre  "`base_fe_cba' ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"
        local absorb_cba_es   "`base_fe_cba' ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

        * Post-treatment
        quietly reghdfe numb_clauses i.treat_ultra##post_treat_cba if `s_direct_B' & !missing(cba_period), ///
            absorb(`absorb_cba_post') vce(cluster identificad)

        local b_post = _b[1.treat_ultra#1.post_treat_cba]
        local se_post = _se[1.treat_ultra#1.post_treat_cba]
        local p_post = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
        local n_obs = e(N)
        local n_estab = e(N_clust)

        * Pre-treatment
        quietly reghdfe numb_clauses i.treat_ultra##pre_treat_cba if `s_direct_B' & !missing(cba_period) & cba_period<=2, ///
            absorb(`absorb_cba_pre') vce(cluster identificad)

        local b_pre = _b[1.treat_ultra#1.pre_treat_cba]
        local se_pre = _se[1.treat_ultra#1.pre_treat_cba]
        local p_pre = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

        * Stars
        local stars_post ""
        if `p_post' < 0.01 local stars_post "***"
        else if (`p_post' < 0.05 & `p_post' > 0.01) local stars_post "**"
        else if (`p_post' < 0.10 & `p_post' > 0.05) local stars_post "*"

        local stars_pre ""
        if `p_pre' < 0.01 local stars_pre "***"
        else if (`p_pre' < 0.05 & `p_pre' > 0.01) local stars_pre "**"
        else if (`p_pre' < 0.10 & `p_pre' > 0.05) local stars_pre "*"

        * Write
        tempname fh
        file open `fh' using "$tables/results_direct_panelB_`spec'.csv", write append
        file write `fh' `""`spec'";"direct_B";"numb_clauses";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
        file write `fh' `""`spec'";"direct_B";"numb_clauses";"main_se";"' %9.4f (`se_post') `"""' _n
        file write `fh' `""`spec'";"direct_B";"numb_clauses";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
        file write `fh' `""`spec'";"direct_B";"numb_clauses";"pre_se";"' %9.4f (`se_pre') `"""' _n
        file write `fh' `""`spec'";"direct_B";"numb_clauses";"n_obs";"' %12.0fc (`n_obs') `"""' _n
        file write `fh' `""`spec'";"direct_B";"numb_clauses";"n_estab";"' %12.0fc (`n_estab') `"""' _n
        file close `fh'

        * Event study
        quietly reghdfe numb_clauses i.treat_ultra##ib2.cba_period if `s_direct_B' & !missing(cba_period), ///
            absorb(`absorb_cba_es') vce(cluster identificad)

        estimates store es_clB

        * Joint F-test for pre-trends
        testparm 1.treat_ultra#1.cba_period
        local pre_ftest_pval = r(p)

        tempname fh
        file open `fh' using "$tables/results_direct_panelB_`spec'.csv", write append
        file write `fh' `""`spec'";"direct_B";"numb_clauses";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""' _n
        file close `fh'

        local post_coef = string(`b_post', "%9.4f")
        local post_se = string(`se_post', "%9.4f")
        local pre_pval = string(`pre_ftest_pval', "%9.3f")

        coefplot es_clB, ///
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
            note("P-value for pre-trend test = `pre_pval'") ///
            graphregion(color(white)) bgcolor(white) ///
            ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) ///
            text(2.5 4 "`post_coef' (`post_se')", color(blue) size(small))

        graph export "$graphs/es_direct_panelB_numb_clauses_`spec'.pdf", as(pdf) replace

        estimates drop es_clB
    }

    * ===========================
    * PART C: DIRECT EFFECTS — PANEL C (all untreated controls)
    * ===========================

    di _newline(2)
    di as result "-----------------------------------------------------------------------"
    di as result "DIRECT EFFECTS — PANEL C (all untreated controls)"
    di as result "-----------------------------------------------------------------------"

    * Year-based outcomes
    foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {

        di _newline(1)
        di as text "Estimating: `outcome' (Panel C)"

        local absorb_post "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"
        local absorb_pre  "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"
        local absorb_es   "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

        * Post-treatment regression
        quietly reghdfe `outcome' treat_ultra##i.treat_year if `s_direct_C', ///
            absorb(`absorb_post') vce(cluster identificad)

        local b_post = _b[1.treat_ultra#1.treat_year]
        local se_post = _se[1.treat_ultra#1.treat_year]
        local p_post = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
        local n_obs = e(N)
        local n_estab = e(N_clust)

        * Pre-treatment regression
        quietly reghdfe `outcome' treat_ultra##i.placebo_year if `s_direct_C' & year<=2011, ///
            absorb(`absorb_pre') vce(cluster identificad)

        local b_pre = _b[1.treat_ultra#1.placebo_year]
        local se_pre = _se[1.treat_ultra#1.placebo_year]
        local p_pre = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

        * Stars
        local stars_post ""
        if `p_post' < 0.01 local stars_post "***"
        else if (`p_post' < 0.05 & `p_post' > 0.01) local stars_post "**"
        else if (`p_post' < 0.10 & `p_post' > 0.05) local stars_post "*"

        local stars_pre ""
        if `p_pre' < 0.01 local stars_pre "***"
        else if (`p_pre' < 0.05 & `p_pre' > 0.01) local stars_pre "**"
        else if (`p_pre' < 0.10 & `p_pre' > 0.05) local stars_pre "*"

        * Write
        tempname fh
        file open `fh' using "$tables/results_direct_panelC_`spec'.csv", write append
        file write `fh' `""`spec'";"direct_C";"`outcome'";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
        file write `fh' `""`spec'";"direct_C";"`outcome'";"main_se";"' %9.4f (`se_post') `"""' _n
        file write `fh' `""`spec'";"direct_C";"`outcome'";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
        file write `fh' `""`spec'";"direct_C";"`outcome'";"pre_se";"' %9.4f (`se_pre') `"""' _n
        file write `fh' `""`spec'";"direct_C";"`outcome'";"n_obs";"' %12.0fc (`n_obs') `"""' _n
        file write `fh' `""`spec'";"direct_C";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""' _n
        file close `fh'

        * Event study
        quietly reghdfe `outcome' i.treat_ultra##ib2011.year if `s_direct_C', ///
            absorb(`absorb_es') vce(cluster identificad)

        estimates store es_dC_`outcome'

        * Joint F-test for pre-trends
        testparm 1.treat_ultra#i(2009 2010).year
        local pre_ftest_pval = r(p)

        tempname fh
        file open `fh' using "$tables/results_direct_panelC_`spec'.csv", write append
        file write `fh' `""`spec'";"direct_C";"`outcome'";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""' _n
        file close `fh'

        local post_coef = string(`b_post', "%9.4f")
        local post_se = string(`se_post', "%9.4f")
        local pre_pval = string(`pre_ftest_pval', "%9.3f")

        coefplot es_dC_`outcome', ///
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
            ytitle("Dynamic DiD coefficients", size(small)) ///
            note("P-value for pre-trend test = `pre_pval'") ///
            graphregion(color(white)) bgcolor(white) ///
            ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) ///
            text(0.05 6 "`post_coef' (`post_se')", color(blue) size(small))

        graph export "$graphs/es_direct_panelC_`outcome'_`spec'.pdf", as(pdf) replace

        estimates drop es_dC_`outcome'
    }

    * numb_clauses (CBA periods) — Panel C
    capture confirm variable numb_clauses
    if _rc == 0 {

        di _newline(1)
        di as text "Estimating: numb_clauses (CBA periods, Panel C)"

        local absorb_cba_post "`base_fe_cba' ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"
        local absorb_cba_pre  "`base_fe_cba' ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"
        local absorb_cba_es   "`base_fe_cba' ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

        * Post-treatment
        quietly reghdfe numb_clauses i.treat_ultra##post_treat_cba if `s_direct_C' & !missing(cba_period), ///
            absorb(`absorb_cba_post') vce(cluster identificad)

        local b_post = _b[1.treat_ultra#1.post_treat_cba]
        local se_post = _se[1.treat_ultra#1.post_treat_cba]
        local p_post = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
        local n_obs = e(N)
        local n_estab = e(N_clust)

        * Pre-treatment
        quietly reghdfe numb_clauses i.treat_ultra##pre_treat_cba if `s_direct_C' & !missing(cba_period) & cba_period<=2, ///
            absorb(`absorb_cba_pre') vce(cluster identificad)

        local b_pre = _b[1.treat_ultra#1.pre_treat_cba]
        local se_pre = _se[1.treat_ultra#1.pre_treat_cba]
        local p_pre = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

        * Stars
        local stars_post ""
        if `p_post' < 0.01 local stars_post "***"
        else if (`p_post' < 0.05 & `p_post' > 0.01) local stars_post "**"
        else if (`p_post' < 0.10 & `p_post' > 0.05) local stars_post "*"

        local stars_pre ""
        if `p_pre' < 0.01 local stars_pre "***"
        else if (`p_pre' < 0.05 & `p_pre' > 0.01) local stars_pre "**"
        else if (`p_pre' < 0.10 & `p_pre' > 0.05) local stars_pre "*"

        * Write
        tempname fh
        file open `fh' using "$tables/results_direct_panelC_`spec'.csv", write append
        file write `fh' `""`spec'";"direct_C";"numb_clauses";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
        file write `fh' `""`spec'";"direct_C";"numb_clauses";"main_se";"' %9.4f (`se_post') `"""' _n
        file write `fh' `""`spec'";"direct_C";"numb_clauses";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
        file write `fh' `""`spec'";"direct_C";"numb_clauses";"pre_se";"' %9.4f (`se_pre') `"""' _n
        file write `fh' `""`spec'";"direct_C";"numb_clauses";"n_obs";"' %12.0fc (`n_obs') `"""' _n
        file write `fh' `""`spec'";"direct_C";"numb_clauses";"n_estab";"' %12.0fc (`n_estab') `"""' _n
        file close `fh'

        * Event study
        quietly reghdfe numb_clauses i.treat_ultra##ib2.cba_period if `s_direct_C' & !missing(cba_period), ///
            absorb(`absorb_cba_es') vce(cluster identificad)

        estimates store es_clC

        * Joint F-test for pre-trends
        testparm 1.treat_ultra#1.cba_period
        local pre_ftest_pval = r(p)

        tempname fh
        file open `fh' using "$tables/results_direct_panelC_`spec'.csv", write append
        file write `fh' `""`spec'";"direct_C";"numb_clauses";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""' _n
        file close `fh'

        local post_coef = string(`b_post', "%9.4f")
        local post_se = string(`se_post', "%9.4f")
        local pre_pval = string(`pre_ftest_pval', "%9.3f")

        coefplot es_clC, ///
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
            note("P-value for pre-trend test = `pre_pval'") ///
            graphregion(color(white)) bgcolor(white) ///
            ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) ///
            text(2.5 4 "`post_coef' (`post_se')", color(blue) size(small))

        graph export "$graphs/es_direct_panelC_numb_clauses_`spec'.pdf", as(pdf) replace

        estimates drop es_clC
    }

    * ===========================
    * PART D: SPILLOVER EFFECTS
    * ===========================

    di _newline(2)
    di as result "-----------------------------------------------------------------------"
    di as result "SPILLOVER EFFECTS"
    di as result "-----------------------------------------------------------------------"

    * Year-based outcomes
    foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {

        di _newline(1)
        di as text "Estimating: `outcome' (spillover)"

        local absorb_post "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"
        local absorb_pre  "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"
        local absorb_es   "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

        * BASELINE: Post-treatment
        reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
            absorb(`absorb_post') vce(cluster identificad)

        local b_post = _b[1.treat_year#c.`conn']
        local se_post = _se[1.treat_year#c.`conn']
        local p_post = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
        local n_obs = e(N)
        local n_estab = e(N_clust)

        * BASELINE: Pre-treatment
        reghdfe `outcome' c.`conn'##i.placebo_year if `s_spill' & year<=2011, ///
            absorb(`absorb_pre') vce(cluster identificad)

        local b_pre = _b[1.placebo_year#c.`conn']
        local se_pre = _se[1.placebo_year#c.`conn']
        local p_pre = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

        * Stars
        local stars_post ""
        if `p_post' < 0.01 local stars_post "***"
        else if (`p_post' < 0.05 & `p_post' > 0.01) local stars_post "**"
        else if (`p_post' < 0.10 & `p_post' > 0.05) local stars_post "*"

        local stars_pre ""
        if `p_pre' < 0.01 local stars_pre "***"
        else if (`p_pre' < 0.05 & `p_pre' > 0.01) local stars_pre "**"
        else if (`p_pre' < 0.10 & `p_pre' > 0.05) local stars_pre "*"

        * Write BASELINE results
        tempname fh
        file open `fh' using "$tables/results_spill_`spec'.csv", write append
        file write `fh' `""`spec'";"spill";"`outcome'";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
        file write `fh' `""`spec'";"spill";"`outcome'";"main_se";"' %9.4f (`se_post') `"""' _n
        file write `fh' `""`spec'";"spill";"`outcome'";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
        file write `fh' `""`spec'";"spill";"`outcome'";"pre_se";"' %9.4f (`se_pre') `"""' _n
        file write `fh' `""`spec'";"spill";"`outcome'";"n_obs";"' %12.0fc (`n_obs') `"""' _n
        file write `fh' `""`spec'";"spill";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""' _n
        file close `fh'

        * Event study
        quietly reghdfe `outcome' c.`conn'##ib2011.year if `s_spill', ///
            absorb(`absorb_es') vce(cluster identificad)

        estimates store es_sp_`outcome'

        * Joint F-test for pre-trends
        testparm c.`conn'#i(2009 2010).year
        local pre_ftest_pval = r(p)

        tempname fh
        file open `fh' using "$tables/results_spill_`spec'.csv", write append
        file write `fh' `""`spec'";"spill";"`outcome'";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""' _n
        file close `fh'

        local post_coef = string(`b_post', "%9.4f")
        local post_se = string(`se_post', "%9.4f")
        local pre_pval = string(`pre_ftest_pval', "%9.3f")

        coefplot es_sp_`outcome', ///
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
            ytitle("Dynamic DiD coefficients", size(small)) ///
            note("P-value for pre-trend test = `pre_pval'") ///
            graphregion(color(white)) bgcolor(white) ///
            ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) ///
            text(0.015 5 "`post_coef' (`post_se')", color(blue) size(small))

        graph export "$graphs/es_spill_`outcome'_`spec'.pdf", as(pdf) replace

        estimates drop es_sp_`outcome'
    }

    * numb_clauses spillover
    capture confirm variable numb_clauses
    if _rc == 0 {

        di _newline(1)
        di as text "Estimating: numb_clauses (spillover, CBA periods)"

        local absorb_cba_post "`base_fe_cba' ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"
        local absorb_cba_pre  "`base_fe_cba' ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"
        local absorb_cba_es   "`base_fe_cba' ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

        * Post-treatment
        quietly reghdfe numb_clauses c.`conn'##post_treat_cba if `s_spill' & !missing(cba_period), ///
            absorb(`absorb_cba_post') vce(cluster identificad)

        local b_post = _b[1.post_treat_cba#c.`conn']
        local se_post = _se[1.post_treat_cba#c.`conn']
        local p_post = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
        local n_obs = e(N)
        local n_estab = e(N_clust)

        * Pre-treatment
        quietly reghdfe numb_clauses c.`conn'##pre_treat_cba if `s_spill' & !missing(cba_period) & cba_period<=2, ///
            absorb(`absorb_cba_pre') vce(cluster identificad)

        local b_pre = _b[1.pre_treat_cba#c.`conn']
        local se_pre = _se[1.pre_treat_cba#c.`conn']
        local p_pre = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

        * Stars
        local stars_post ""
        if `p_post' < 0.01 local stars_post "***"
        else if (`p_post' < 0.05 & `p_post' > 0.01) local stars_post "**"
        else if (`p_post' < 0.10 & `p_post' > 0.05) local stars_post "*"

        local stars_pre ""
        if `p_pre' < 0.01 local stars_pre "***"
        else if (`p_pre' < 0.05 & `p_pre' > 0.01) local stars_pre "**"
        else if (`p_pre' < 0.10 & `p_pre' > 0.05) local stars_pre "*"

        * Write
        tempname fh
        file open `fh' using "$tables/results_spill_`spec'.csv", write append
        file write `fh' `""`spec'";"spill";"numb_clauses";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
        file write `fh' `""`spec'";"spill";"numb_clauses";"main_se";"' %9.4f (`se_post') `"""' _n
        file write `fh' `""`spec'";"spill";"numb_clauses";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
        file write `fh' `""`spec'";"spill";"numb_clauses";"pre_se";"' %9.4f (`se_pre') `"""' _n
        file write `fh' `""`spec'";"spill";"numb_clauses";"n_obs";"' %12.0fc (`n_obs') `"""' _n
        file write `fh' `""`spec'";"spill";"numb_clauses";"n_estab";"' %12.0fc (`n_estab') `"""' _n
        file close `fh'

        * Event study
        quietly reghdfe numb_clauses c.`conn'##ib2.cba_period if `s_spill' & !missing(cba_period), ///
            absorb(`absorb_cba_es') vce(cluster identificad)

        estimates store es_cl_sp

        * Joint F-test for pre-trends
        testparm c.`conn'#1.cba_period
        local pre_ftest_pval = r(p)

        tempname fh
        file open `fh' using "$tables/results_spill_`spec'.csv", write append
        file write `fh' `""`spec'";"spill";"numb_clauses";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""' _n
        file close `fh'

        local post_coef = string(`b_post', "%9.4f")
        local post_se = string(`se_post', "%9.4f")
        local pre_pval = string(`pre_ftest_pval', "%9.3f")

        coefplot es_cl_sp, ///
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
            note("P-value for pre-trend test = `pre_pval'") ///
            graphregion(color(white)) bgcolor(white) ///
            ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) ///
            text(0.6 4 "`post_coef' (`post_se')", color(blue) size(small))

        graph export "$graphs/es_spill_numb_clauses_`spec'.pdf", as(pdf) replace

        estimates drop es_cl_sp
    }

    * ===========================
    * PART E: SPILLOVER UNION ROBUSTNESS (lr_remdezr_w only)
    * ===========================

    di _newline(2)
    di as result "-----------------------------------------------------------------------"
    di as result "SPILLOVER UNION ROBUSTNESS (lr_remdezr_w only)"
    di as result "-----------------------------------------------------------------------"

    local outcome "lr_remdezr_w"
    local absorb_post "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"
    local absorb_pre  "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

    * --- MODE_UNION: Union fixed effects ---
    quietly reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
        absorb(`absorb_post' i.mode_union#i.year) vce(cluster identificad)

    local b_post_union = _b[1.treat_year#c.`conn']
    local se_post_union = _se[1.treat_year#c.`conn']
    local p_post_union = 2*ttail(e(df_r), abs(`b_post_union'/`se_post_union'))
    local n_obs_union = e(N)
    local n_estab_union = e(N_clust)

    local stars_post_union ""
    if `p_post_union' < 0.01 local stars_post_union "***"
    else if (`p_post_union'< 0.05 & `p_post_union'> 0.01) local stars_post_union "**"
    else if (`p_post_union'< 0.10 & `p_post_union'> 0.05) local stars_post_union "*"

    quietly reghdfe `outcome' c.`conn'##i.placebo_year if `s_spill' & year<=2011, ///
        absorb(`absorb_pre' i.mode_union#i.year) vce(cluster identificad)

    local b_pre_union = _b[1.placebo_year#c.`conn']
    local se_pre_union = _se[1.placebo_year#c.`conn']
    local p_pre_union = 2*ttail(e(df_r), abs(`b_pre_union'/`se_pre_union'))

    local stars_pre_union ""
    if `p_pre_union' < 0.01 local stars_pre_union "***"
    else if (`p_pre_union'< 0.05 & `p_pre_union'> 0.01) local stars_pre_union "**"
    else if (`p_pre_union'< 0.10 & `p_pre_union'> 0.05) local stars_pre_union "*"

    * Write MODE_UNION results
    tempname fh
    file open `fh' using "$tables/results_spill_`spec'.csv", write append
    file write `fh' `""`spec'";"spill";"`outcome'_union";"main";"' %9.4f (`b_post_union') `"`stars_post_union'""' _n
    file write `fh' `""`spec'";"spill";"`outcome'_union";"main_se";"' %9.4f (`se_post_union') `"""' _n
    file write `fh' `""`spec'";"spill";"`outcome'_union";"pre";"' %9.4f (`b_pre_union') `"`stars_pre_union'""' _n
    file write `fh' `""`spec'";"spill";"`outcome'_union";"pre_se";"' %9.4f (`se_pre_union') `"""' _n
    file write `fh' `""`spec'";"spill";"`outcome'_union";"n_obs";"' %12.0fc (`n_obs_union') `"""' _n
    file write `fh' `""`spec'";"spill";"`outcome'_union";"n_estab";"' %12.0fc (`n_estab_union') `"""' _n
    file close `fh'

    * Joint F-test for pre-trends (MODE_UNION)
    quietly reghdfe `outcome' c.`conn'##ib2011.year if `s_spill', ///
        absorb(`absorb_post' i.mode_union#i.year) vce(cluster identificad)
    testparm c.`conn'#i(2009 2010).year
    local pre_ftest_pval_union = r(p)

    file open `fh' using "$tables/results_spill_`spec'.csv", write append
    file write `fh' `""`spec'";"spill";"`outcome'_union";"pre_pval";"' %9.4f (`pre_ftest_pval_union') `"""' _n
    file close `fh'

    * --- UNION_EXP_FIRMS: Union exposure control ---
    quietly reghdfe `outcome' c.`conn'##i.treat_year c.treat_union_exp_all#i.year if `s_spill', ///
        absorb(`absorb_post') vce(cluster identificad)

    local b_post_exp = _b[1.treat_year#c.`conn']
    local se_post_exp = _se[1.treat_year#c.`conn']
    local p_post_exp = 2*ttail(e(df_r), abs(`b_post_exp'/`se_post_exp'))
    local n_obs_exp = e(N)
    local n_estab_exp = e(N_clust)

    local stars_post_exp ""
    if `p_post_exp' < 0.01 local stars_post_exp "***"
    else if (`p_post_exp' < 0.05 & `p_post_exp'> 0.01) local stars_post_exp "**"
    else if (`p_post_exp' < 0.10 & `p_post_exp'> 0.05) local stars_post_exp "*"

    quietly reghdfe `outcome' c.`conn'##i.placebo_year c.treat_union_exp_all#i.year if `s_spill' & year<=2011, ///
        absorb(`absorb_pre') vce(cluster identificad)

    local b_pre_exp = _b[1.placebo_year#c.`conn']
    local se_pre_exp = _se[1.placebo_year#c.`conn']
    local p_pre_exp = 2*ttail(e(df_r), abs(`b_pre_exp'/`se_pre_exp'))

    local stars_pre_exp ""
    if `p_pre_exp' < 0.01 local stars_pre_exp "***"
    else if (`p_pre_exp' < 0.05 & `p_pre_exp'> 0.01) local stars_pre_exp "**"
    else if (`p_pre_exp' < 0.10 & `p_pre_exp'> 0.05) local stars_pre_exp "*"

    * Write UNION_EXP results
    file open `fh' using "$tables/results_spill_`spec'.csv", write append
    file write `fh' `""`spec'";"spill";"`outcome'_unionexp";"main";"' %9.4f (`b_post_exp') `"`stars_post_exp'""' _n
    file write `fh' `""`spec'";"spill";"`outcome'_unionexp";"main_se";"' %9.4f (`se_post_exp') `"""' _n
    file write `fh' `""`spec'";"spill";"`outcome'_unionexp";"pre";"' %9.4f (`b_pre_exp') `"`stars_pre_exp'""' _n
    file write `fh' `""`spec'";"spill";"`outcome'_unionexp";"pre_se";"' %9.4f (`se_pre_exp') `"""' _n
    file write `fh' `""`spec'";"spill";"`outcome'_unionexp";"n_obs";"' %12.0fc (`n_obs_exp') `"""' _n
    file write `fh' `""`spec'";"spill";"`outcome'_unionexp";"n_estab";"' %12.0fc (`n_estab_exp') `"""' _n
    file close `fh'

    * Joint F-test for pre-trends (UNION_EXP)
    quietly reghdfe `outcome' c.`conn'##ib2011.year c.treat_union_exp_all#i.year if `s_spill', ///
        absorb(`absorb_post') vce(cluster identificad)
    testparm c.`conn'#i(2009 2010).year
    local pre_ftest_pval_exp = r(p)

    file open `fh' using "$tables/results_spill_`spec'.csv", write append
    file write `fh' `""`spec'";"spill";"`outcome'_unionexp";"pre_pval";"' %9.4f (`pre_ftest_pval_exp') `"""' _n
    file close `fh'

    * --- UNION_EMP_EXP: Union exposure control (by number of workers) ---
    quietly reghdfe `outcome' c.`conn'##i.treat_year c.union_emp_exp#i.year if `s_spill', ///
        absorb(`absorb_post') vce(cluster identificad)

    local b_post_empexp = _b[1.treat_year#c.`conn']
    local se_post_empexp = _se[1.treat_year#c.`conn']
    local p_post_empexp = 2*ttail(e(df_r), abs(`b_post_empexp'/`se_post_empexp'))
    local n_obs_empexp = e(N)
    local n_estab_empexp = e(N_clust)

    local stars_post_empexp ""
    if `p_post_empexp' < 0.01 local stars_post_empexp "***"
    else if (`p_post_empexp' < 0.05 & `p_post_empexp' > 0.01) local stars_post_empexp "**"
    else if (`p_post_empexp' < 0.10 & `p_post_empexp' > 0.05) local stars_post_empexp "*"

    quietly reghdfe `outcome' c.`conn'##i.placebo_year c.union_emp_exp#i.year if `s_spill' & year<=2011, ///
        absorb(`absorb_pre') vce(cluster identificad)

    local b_pre_empexp = _b[1.placebo_year#c.`conn']
    local se_pre_empexp = _se[1.placebo_year#c.`conn']
    local p_pre_empexp = 2*ttail(e(df_r), abs(`b_pre_empexp'/`se_pre_empexp'))

    local stars_pre_empexp ""
    if `p_pre_empexp' < 0.01 local stars_pre_empexp "***"
    else if (`p_pre_empexp' < 0.05 & `p_pre_empexp' > 0.01) local stars_pre_empexp "**"
    else if (`p_pre_empexp' < 0.10 & `p_pre_empexp' > 0.05) local stars_pre_empexp "*"

    * Write UNION_EMP_EXP results
    file open `fh' using "$tables/results_spill_`spec'.csv", write append
    file write `fh' `""`spec'";"spill";"`outcome'_unionempexp";"main";"' %9.4f (`b_post_empexp') `"`stars_post_empexp'""' _n
    file write `fh' `""`spec'";"spill";"`outcome'_unionempexp";"main_se";"' %9.4f (`se_post_empexp') `"""' _n
    file write `fh' `""`spec'";"spill";"`outcome'_unionempexp";"pre";"' %9.4f (`b_pre_empexp') `"`stars_pre_empexp'""' _n
    file write `fh' `""`spec'";"spill";"`outcome'_unionempexp";"pre_se";"' %9.4f (`se_pre_empexp') `"""' _n
    file write `fh' `""`spec'";"spill";"`outcome'_unionempexp";"n_obs";"' %12.0fc (`n_obs_empexp') `"""' _n
    file write `fh' `""`spec'";"spill";"`outcome'_unionempexp";"n_estab";"' %12.0fc (`n_estab_empexp') `"""' _n
    file close `fh'

    * Joint F-test for pre-trends (UNION_EMP_EXP)
    quietly reghdfe `outcome' c.`conn'##ib2011.year c.union_emp_exp#i.year if `s_spill', ///
        absorb(`absorb_post') vce(cluster identificad)
    testparm c.`conn'#i(2009 2010).year
    local pre_ftest_pval_empexp = r(p)

    file open `fh' using "$tables/results_spill_`spec'.csv", write append
    file write `fh' `""`spec'";"spill";"`outcome'_unionempexp";"pre_pval";"' %9.4f (`pre_ftest_pval_empexp') `"""' _n
    file close `fh'

    di _newline(1)
    di as result "Specification `spec' complete"
}

********************************************************************************
* SECTION 4: COMPLETION
********************************************************************************

log close
di as result "Finished: `c(current_date)' `c(current_time)'"

********************************************************************************
* END OF DO-FILE
********************************************************************************
