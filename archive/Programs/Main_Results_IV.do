********************************************************************************
* UNION SPILLOVERS — FINAL RESULTS DO-FILE
* Purpose: Generate all estimation results, figures, and numeric outputs
* Output: CSV files with numeric results + PDF figures
* No LaTeX tables generated here
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/FinalResults_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
di "Stata version: `c(stata_version)'"

********************************************************************************
* SECTION 1: SETUP AND VARIABLE PREPARATION
********************************************************************************

cls
use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

* ===============================
* GLOBAL SETTINGS
* ===============================
local conn "totaltreat_pw_norm"

* Sample definitions
local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"
local s_direct "(lagos_sample_avg==1 & treat_ultra==0  | lagos_sample_avg==1 & treat_ultra==1) & in_balanced_panel==1"

keep if year>=2009
keep if lagos_sample_avg==1

di as result "Sample size: " _N

* ===============================
* SPECIFICATIONS TO LOOP OVER
* ===============================
* Each specification will generate a complete set of results

* Only lagos controls
global specs_lagos "4tf_out_alldir_0conn "



* ===============================
* OUTCOME LISTS
* ===============================
global main_outcomes "lr_remdezr_w lr_remdezr_h_w l_firm_emp numb_clauses"

global pct_outcomes_dec "lr_remdezr_w_p10 lr_remdezr_w_p20 lr_remdezr_w_p25 lr_remdezr_w_p50 lr_remdezr_w_p75 lr_remdezr_w_p80 lr_remdezr_w_p90"

global pct_outcomes_hour "lr_remdezr_h_w_p10 lr_remdezr_h_w_p20 lr_remdezr_h_w_p25 lr_remdezr_h_w_p50 lr_remdezr_h_w_p75 lr_remdezr_h_w_p80 lr_remdezr_h_w_p90"

global ratio_outcomes_dec "lr_remdezr_w_p90p10 lr_remdezr_w_p80p20 lr_remdezr_w_p75p25 lr_remdezr_w_p90p50 lr_remdezr_w_p80p50 lr_remdezr_w_p75p50"

global ratio_outcomes_hour "lr_remdezr_h_w_p90p10 lr_remdezr_h_w_p80p20 lr_remdezr_h_w_p75p25 lr_remdezr_h_w_p90p50 lr_remdezr_h_w_p80p50 lr_remdezr_h_w_p75p50"

* ===============================
* VARIABLE CREATION
* ===============================
di _newline(1)
di as result "Creating necessary variables..."

* Treatment indicators
cap drop placebo_year // drops variable if it exists to avoid errors
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

* Scalling connectity to the 90th percentile among untreated firms
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

cap drop tf_per_emp_pre
gen double tf_per_emp_pre = totalflows_n / firm_emp_pre if firm_emp_pre>0
label var tf_per_emp_pre "Pre-treatment total flows per employee (average 2009-2011)"



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

* Pre-treatment averages for percentile outcomes
foreach pct in p10 p20 p25 p50 p75 p80 p90 {
    foreach wage in lr_remdezr_w lr_remdezr_h_w {
        cap drop `wage'_`pct'_pre_o 
		cap drop `wage'_`pct'_pre
        quietly {
            bys identificad: egen `wage'_`pct'_pre_o = mean(`wage'_`pct') if inrange(year, 2009, 2011)
            bys identificad: egen `wage'_`pct'_pre = min(`wage'_`pct'_pre_o)
            drop `wage'_`pct'_pre_o
        }
    }
}

* Create ratio outcomes (log differences)
foreach wage in lr_remdezr_w lr_remdezr_h_w {
    * p90/p10, p80/p20, p75/p25
    cap drop `wage'_p90p10 
	cap drop `wage'_p80p20 
	cap drop `wage'_p75p25
    gen double `wage'_p90p10 = `wage'_p90 - `wage'_p10
    gen double `wage'_p80p20 = `wage'_p80 - `wage'_p20
    gen double `wage'_p75p25 = `wage'_p75 - `wage'_p25
    
    * p90/p50, p80/p50, p75/p50
    cap drop `wage'_p90p50 
	cap drop `wage'_p80p50 
	cap drop `wage'_p75p50
    gen double `wage'_p90p50 = `wage'_p90 - `wage'_p50
    gen double `wage'_p80p50 = `wage'_p80 - `wage'_p50
    gen double `wage'_p75p50 = `wage'_p75 - `wage'_p50
    
    * Pre-treatment averages for ratios
    foreach ratio in p90p10 p80p20 p75p25 p90p50 p80p50 p75p50 {
        cap drop `wage'_`ratio'_pre_o 
		cap drop `wage'_`ratio'_pre
        quietly {
            bys identificad: egen `wage'_`ratio'_pre_o = mean(`wage'_`ratio') if inrange(year, 2009, 2011)
            bys identificad: egen `wage'_`ratio'_pre = min(`wage'_`ratio'_pre_o)
            drop `wage'_`ratio'_pre_o
        }
    }
}

* Create control bins
local glist "4 "

foreach g of local glist {
    cap drop totalflows_n`g'_o 
	cap drop totalflows_n`g'
    quietly {
        egen totalflows_n`g'_o = cut(totalflows_n) if year==2009 & in_balanced_panel==1, group(`g')
        bys identificad: egen totalflows_n`g' = min(totalflows_n`g'_o)
        drop totalflows_n`g'_o
    }
}

foreach g of local glist {
    cap drop firm_emp_pre`g'_o 
	cap drop firm_emp_pre`g'
    quietly {
        egen firm_emp_pre`g'_o = cut(firm_emp_pre) if year==2009 & in_balanced_panel==1, group(`g')
        bys identificad: egen firm_emp_pre`g' = min(firm_emp_pre`g'_o)
        drop firm_emp_pre`g'_o
    }
}

// generates 8 bins for firm employment, which is very differenct between firms with zero and positive connectivity
local m=8

cap drop firm_emp_pre`m'_o 
	cap drop firm_emp_pre`m'
   egen firm_emp_pre`m'_o = cut(firm_emp_pre) if year==2009 & in_balanced_panel==1, group(`m')
        bys identificad: egen firm_emp_pre`m' = min(firm_emp_pre`m'_o)
        drop firm_emp_pre`m'_o
	


foreach g of local glist {
    cap drop tf_per_emp_pre`g'_o 
	cap drop tf_per_emp_pre`g'
    quietly {
        egen tf_per_emp_pre`g'_o = cut(tf_per_emp_pre) if year==2009 & in_balanced_panel==1, group(`g')
        bys identificad: egen tf_per_emp_pre`g' = min(tf_per_emp_pre`g'_o)
        drop tf_per_emp_pre`g'_o
    }
}

local glist "4"


foreach g of local glist{
	foreach wage in lr_remdezr_w  lr_remdezr_h_w l_firm_emp numb_clauses lr_remdezr_w_p10 lr_remdezr_w_p20 lr_remdezr_w_p25 lr_remdezr_w_p50 lr_remdezr_w_p75 lr_remdezr_w_p80 lr_remdezr_w_p90 lr_remdezr_h_w_p10 lr_remdezr_h_w_p20 lr_remdezr_h_w_p25 lr_remdezr_h_w_p50 lr_remdezr_h_w_p75 lr_remdezr_h_w_p80 lr_remdezr_h_w_p90 lr_remdezr_w_p90p10 lr_remdezr_w_p80p20 lr_remdezr_w_p75p25 lr_remdezr_w_p90p50 lr_remdezr_w_p80p50 lr_remdezr_w_p75p50 lr_remdezr_h_w_p90p10 lr_remdezr_h_w_p80p20 lr_remdezr_h_w_p75p25 lr_remdezr_h_w_p90p50 lr_remdezr_h_w_p80p50 lr_remdezr_h_w_p75p50 turnover {
		cap drop `wage'_pre`g'
		quietly{
			egen `wage'_pre`g'_o = cut(`wage'_pre) if year ==2009 & in_balanced_panel==1, group(`g')
//			 i use cut(wage_pre) here because it refers to groups of the pretreatment average of outcomes
			bys identificad: egen `wage'_pre`g' = min(`wage'_pre`g'_o)
			drop `wage'_pre`g'_o
		}
	}
}
* ===============================
* ADDITIONAL VARIABLE CREATION (treatment exposure, geography, industry)
* ===============================

// Among untreated firms, how many are covered by a union that also covers treated firms?
cap drop treat_union
gen treat_union = cond(treat_union_exp_all>0,1,0)
label var treat_union "Indicates whether a firm's union also covers at least one treated firm"

// Geographic sharing of treatment exposure (scaled measures)
cap drop geo_exp
bys microregion (year): egen geo_exp = mean(treat_ultra)
label var geo_exp "Share of treated among sample in a given microregion"

cap drop geo_mun_exp
bys municipio (year): egen geo_mun_exp = mean(treat_ultra)
label var geo_mun_exp "Share of treated among sample in a given municipality"

cap drop mun_spill_count
bys year: egen mun_spill_count = nvals(municipio) if treat_ultra==0 & in_balanced_panel==1 & lagos_sample_avg == 1
label var mun_spill_count "Number of municipalities in spillover sample"

cap drop mic_spill_count
bys year: egen mic_spill_count = nvals(microregion) if treat_ultra==0 & in_balanced_panel==1 & lagos_sample_avg == 1
label var mic_spill_count "Number of microregions in spillover sample"

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

cap drop totaltreat_pw_n_p80
egen totaltreat_pw_n_p80 = pctile(totaltreat_pw_n) if `s_spill',  p(80)
label var totaltreat_pw_n_p80 "80th percentile of total flows to treated (spillover sample)"

cap drop ind_exp_o
bys industry1 (year): egen ind_exp_o = mean(treat_ultra)
label var ind_exp_o "Share of treated firms within each industry"

di as result "✓ All variables created"

********************************************************************************
* SECTION 2: NO HELPER PROGRAMS - DIRECT FILE WRITING
********************************************************************************
* Results will be written directly to CSV files in the estimation loop

********************************************************************************
* SECTION 3: MAIN ESTIMATION LOOP
********************************************************************************

di _newline(2)
di as result "{hline 80}"
di as result "STARTING MAIN ESTIMATION LOOP"
di as result "{hline 80}"

foreach spec of global specs {
    
    di _newline(3)
    di as result "═══════════════════════════════════════════════════════════════════════════"
    di as result "SPECIFICATION: `spec'"
    di as result "═══════════════════════════════════════════════════════════════════════════"
    
    * ===========================
    * BUILD FIXED EFFECTS STRING
    * ===========================
    
    * Extract group number if applicable
	if regexm("`spec'", "^([0-9]+)tf_out_alldir_0conn$") {
        local g = regexs(1)
        local flow_control "ib0.totalflows_n`g' ib0.tf_per_emp_pre`g'#i.year ib0.firm_emp_pre`m'#i.year "
		local flow_control_year "year  ib0.tf_per_emp_pre`g'#i.year  ib0.firm_emp_pre`m'#i.year"
		local flow_control_cba "cba_period  ib0.tf_per_emp_pre`g'#i.cba_period  ib0.firm_emp_pre`m'#i.cba_period"
        local flow_control_post "year   ib0.tf_per_emp_pre`g'#i.year ib0.firm_emp_pre`m'#i.year "
		local flow_control_pre "year  ib0.tf_per_emp_pre`g'#i.year  ib0.firm_emp_pre`m'#i.year"
        local flow_control_cba_post "cba_period  ib0.tf_per_emp_pre`g'#i.cba_period ib0.firm_emp_pre`m'#i.cba_period"
		local flow_control_cba_pre "cba_period  ib0.tf_per_emp_pre`g'#i.cba_period ib0.firm_emp_pre`m'#i.cba_period"
	}

   
    
    * ===========================
    * INITIALIZE OUTPUT FILES
    * ===========================
    
    * Create header for direct effects file
    capture erase "$tables/results_direct_`spec'.csv"
    tempname fh
    file open `fh' using "$tables/results_direct_`spec'.csv", write replace
    file write `fh' "spec,section,outcome,row_type,value" _n
    file close `fh'
    
    * Create header for spillover effects file
    capture erase "$tables/results_spill_`spec'.csv"
    file open `fh' using "$tables/results_spill_`spec'.csv", write replace
    file write `fh' "spec,section,outcome,row_type,value" _n
    file close `fh'
    
    * ===========================
    * PART A: DIRECT EFFECTS
    * ===========================
    
    di _newline(2)
    di as result "───────────────────────────────────────────────────────────────────────────"
    di as result "DIRECT EFFECTS"
    di as result "───────────────────────────────────────────────────────────────────────────"
//   
    * =======================================================
    * Loop over main outcomes (excluding numb_clauses for now)
    * =======================================================
    foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {
       
        di _newline(1)
        di as text "Estimating: `outcome'"
       
        * Base FE
        local base_fe "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year "
       
        * ===========================================================================================
        * Post-treatment regression
        quietly reghdfe `outcome' treat_ultra##i.treat_year if `s_direct', ///
            absorb(`base_fe' `flow_control_post' ib0.`outcome'_pre`g'#i.year) vce(cluster identificad) // outcome pre-treat need to be placed here in the code because the local outcome is defined in the loop
        * ===========================================================================================
        
        * ===========================================================================================
        * Collecting reression coefficients, standard errors, p-values, and sample sizes

        local b_post = _b[1.treat_ultra#1.treat_year]
        local se_post = _se[1.treat_ultra#1.treat_year]
        local p_post = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
        local n_obs = e(N)
        local n_estab = e(N_clust)
       * ===========================================================================================

        * ===========================================================================================
        * Pre-treatment regression (placebo test)
        quietly reghdfe `outcome' treat_ultra##i.placebo_year if `s_direct' & year<=2011, ///
            absorb(`base_fe' `flow_control_pre' ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)
        * ===========================================================================================

        * ===========================================================================================
        * Collecting pre-treatment coefficients, standard errors, and p-values
        local b_pre = _b[1.treat_ultra#1.placebo_year]
        local se_pre = _se[1.treat_ultra#1.placebo_year]
        local p_pre = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))
       * ===========================================================================================

       * ===========================================================================================
        * Create significance stars
        local stars_post ""
        if `p_post' < 0.01 local stars_post "***"
        else if (`p_post' < 0.05 & `p_post' > 0.01) local stars_post "**"
        else if (`p_post' < 0.10 & `p_post' > 0.05) local stars_post "*"
       
        local stars_pre ""
        if `p_pre' < 0.01 local stars_pre "***"
        else if (`p_pre' < 0.05 & `p_pre' > 0.01) local stars_pre "**"
        else if (`p_pre' < 0.10 & `p_pre' > 0.05) local stars_pre "*"
       * ===========================================================================================

        * ===========================================================================================
        * Write to file
        tempname fh
        file open `fh' using "$tables/results_direct_`spec'.csv", write append
        file write `fh' `""`spec'";"direct";"`outcome'";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
        file write `fh' `""`spec'";"direct";"`outcome'";"main_se";"' %9.4f (`se_post') `"""' _n
        file write `fh' `""`spec'";"direct";"`outcome'";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
        file write `fh' `""`spec'";"direct";"`outcome'";"pre_se";"' %9.4f (`se_pre') `"""' _n
        file write `fh' `""`spec'";"direct";"`outcome'";"n_obs";"' %12.0fc (`n_obs') `"""' _n
        file write `fh' `""`spec'";"direct";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""' _n
        file close `fh'
        * ===========================================================================================
       
        * ===========================================================================================
        * Event study for plot
        quietly reghdfe `outcome' i.treat_ultra##ib2011.year if `s_direct', ///
            absorb(`base_fe' `flow_control_year'  ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)
       
        estimates store es_direct_`outcome'
       
        * Create plot
        local post_coef = string(`b_post', "%9.4f")
        local post_se = string(`se_post', "%9.4f")
        local pre_pval = string(`p_pre', "%9.3f")
       
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
            ytitle("Dynamic DiD coefficients", size(small)) ///
            note("P-value for pre-trend test = `pre_pval'") ///
            graphregion(color(white)) bgcolor(white) ///
            ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) ///
            text(0.05 6 "`post_coef' (`post_se')", color(blue) size(small))
       
        graph export "$graphs/es_direct_`outcome'_`spec'.pdf", as(pdf) replace
        * ===========================================================================================
       
        estimates drop es_direct_`outcome'
    }
//    
    * ===========================================================================================
    * Special handling for numb_clauses (CBA periods)
    * ===========================================================================================

    capture confirm variable numb_clauses
    if _rc == 0 {
       
        di _newline(1)
        di as text "Estimating: numb_clauses (CBA periods)"
       
        local base_fe_cba "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period "
       
       * ===========================================================================================
        * Post-treatment
        quietly reghdfe numb_clauses i.treat_ultra##post_treat_cba if `s_direct' & !missing(cba_period), ///
            absorb(`base_fe_cba' `flow_control_cba_post' ib0.numb_clauses_pre`g'#i.cba_period) vce(cluster identificad)
       
        local b_post = _b[1.treat_ultra#1.post_treat_cba]
        local se_post = _se[1.treat_ultra#1.post_treat_cba]
        local p_post = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
        local n_obs = e(N)
        local n_estab = e(N_clust)

        * ===========================================================================================
       
       * ===========================================================================================
        * Pre-treatment
        quietly reghdfe numb_clauses i.treat_ultra##pre_treat_cba if `s_direct' & !missing(cba_period) & cba_period<=2, ///
            absorb(`base_fe_cba' `flow_control_cba_pre' ib0.numb_clauses_pre`g'#i.cba_period) vce(cluster identificad)
       
        local b_pre = _b[1.treat_ultra#1.pre_treat_cba]
        local se_pre = _se[1.treat_ultra#1.pre_treat_cba]
        local p_pre = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))
        * ===========================================================================================
       
       * ===========================================================================================
        * Create significance stars
        local stars_post ""
        if `p_post' < 0.01 local stars_post "***"
        else if (`p_post' < 0.05 & `p_post' > 0.01) local stars_post "**"
        else if (`p_post' < 0.10 & `p_post' > 0.05) local stars_post "*"
       
        local stars_pre ""
        if `p_pre' < 0.01 local stars_pre "***"
        else if (`p_pre' < 0.05 & `p_pre' > 0.01) local stars_pre "**"
        else if (`p_pre' < 0.10 & `p_pre' > 0.05) local stars_pre "*"
       * ===========================================================================================

       * ===========================================================================================
        * Write to file
        tempname fh
        file open `fh' using "$tables/results_direct_`spec'.csv", write append
        file write `fh' `""`spec'";"direct";"numb_clauses";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
        file write `fh' `""`spec'";"direct";"numb_clauses";"main_se";"' %9.4f (`se_post') `"""' _n
        file write `fh' `""`spec'";"direct";"numb_clauses";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
        file write `fh' `""`spec'";"direct";"numb_clauses";"pre_se";"' %9.4f (`se_pre') `"""' _n
        file write `fh' `""`spec'";"direct";"numb_clauses";"n_obs";"' %12.0fc (`n_obs') `"""' _n
        file write `fh' `""`spec'";"direct";"numb_clauses";"n_estab";"' %12.0fc (`n_estab') `"""' _n
        file close `fh'
       * ===========================================================================================
       
       * ===========================================================================================
        * Event study
        quietly reghdfe numb_clauses i.treat_ultra##ib2.cba_period if `s_direct' & !missing(cba_period), ///
            absorb(`base_fe_cba' `flow_control_cba' ib0.numb_clauses_pre`g'#i.cba_period) vce(cluster identificad)
       
        estimates store es_clauses
       
        local post_coef = string(`b_post', "%9.4f")
        local post_se = string(`se_post', "%9.4f")
        local pre_pval = string(`p_pre', "%9.3f")
       
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
            note("P-value for pre-trend test = `pre_pval'") ///
            graphregion(color(white)) bgcolor(white) ///
            ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) ///
            text(2.5 4 "`post_coef' (`post_se')", color(blue) size(small))
       
        graph export "$graphs/es_direct_numb_clauses_`spec'.pdf", as(pdf) replace
       * ===========================================================================================
       
        estimates drop es_clauses
    }
    
    * Percentile outcomes - direct effects (numeric results only, no plots)
    di _newline(1)
    di as text "Estimating: Percentile outcomes (direct) - numeric results only"
   
    foreach outcome in $pct_outcomes_dec $pct_outcomes_hour {
       
        local base_fe "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year "
       
        quietly reghdfe `outcome' treat_ultra##i.treat_year if `s_direct', ///
            absorb(`base_fe' `flow_control_post' ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)
       
        local b_post = _b[1.treat_ultra#1.treat_year]
        local se_post = _se[1.treat_ultra#1.treat_year]
        local p_post = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
        local n_obs = e(N)
        local n_estab = e(N_clust)
       
        quietly reghdfe `outcome' treat_ultra##i.placebo_year if `s_direct' & year<=2011, ///
            absorb(`base_fe' `flow_control_pre' ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)
       
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
        file open `fh' using "$tables/results_direct_`spec'.csv", write append
        file write `fh' `""`spec'";"direct";"`outcome'";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
        file write `fh' `""`spec'";"direct";"`outcome'";"main_se";"' %9.4f (`se_post') `"""' _n
        file write `fh' `""`spec'";"direct";"`outcome'";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
        file write `fh' `""`spec'";"direct";"`outcome'";"pre_se";"' %9.4f (`se_pre') `"""' _n
        file write `fh' `""`spec'";"direct";"`outcome'";"n_obs";"' %12.0fc (`n_obs') `"""' _n
        file write `fh' `""`spec'";"direct";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""' _n
        file close `fh'
    }
   
    * Ratio outcomes - direct effects (numeric results only, no plots)
    di as text "Estimating: Ratio outcomes (direct) - numeric results only"
   
    foreach outcome in $ratio_outcomes_dec $ratio_outcomes_hour {
       
        local base_fe "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year "
       
        quietly reghdfe `outcome' treat_ultra##i.treat_year if `s_direct', ///
            absorb(`base_fe' `flow_control_post' ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)
       
        local b_post = _b[1.treat_ultra#1.treat_year]
        local se_post = _se[1.treat_ultra#1.treat_year]
        local p_post = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
        local n_obs = e(N)
        local n_estab = e(N_clust)
       
        quietly reghdfe `outcome' treat_ultra##i.placebo_year if `s_direct' & year<=2011, ///
            absorb(`base_fe' `flow_control_pre' ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)
       
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
        file open `fh' using "$tables/results_direct_`spec'.csv", write append
        file write `fh' `""`spec'";"direct";"`outcome'";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
        file write `fh' `""`spec'";"direct";"`outcome'";"main_se";"' %9.4f (`se_post') `"""' _n
        file write `fh' `""`spec'";"direct";"`outcome'";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
        file write `fh' `""`spec'";"direct";"`outcome'";"pre_se";"' %9.4f (`se_pre') `"""' _n
        file write `fh' `""`spec'";"direct";"`outcome'";"n_obs";"' %12.0fc (`n_obs') `"""' _n
        file write `fh' `""`spec'";"direct";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""' _n
        file close `fh'
    }
    
    * ===========================
    * PART B: SPILLOVER EFFECTS
    * ===========================
   
    di _newline(2)
    di as result "───────────────────────────────────────────────────────────────────────────"
    di as result "SPILLOVER EFFECTS"
    di as result "───────────────────────────────────────────────────────────────────────────"
//    
    * Loop over main outcomes (excluding numb_clauses)
    foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {
      
        di _newline(1)
        di as text "Estimating: `outcome' (spillover)"
      
        local base_fe "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year "
      
        * BASELINE: Post-treatment
         reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
            absorb(`base_fe' `flow_control_post' ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)
      
        local b_post = _b[1.treat_year#c.`conn']
        local se_post = _se[1.treat_year#c.`conn']
        local p_post = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
        local n_obs = e(N)
        local n_estab = e(N_clust)
      
        * BASELINE: Pre-treatment
         reghdfe `outcome' c.`conn'##i.placebo_year if `s_spill' & year<=2011, ///
            absorb(`base_fe' `flow_control_pre' ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)
      
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
      
        * ===========================
        * UNION CONTROL ROBUSTNESS
        * ===========================
      
        * MODE_UNION: Union fixed effects
        quietly reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
            absorb(`base_fe' `flow_control_post' ib0.`outcome'_pre`g'#i.year i.mode_union#i.year) vce(cluster identificad)
      
        local b_post_union = _b[1.treat_year#c.`conn']
        local se_post_union = _se[1.treat_year#c.`conn']
        local p_post_union = 2*ttail(e(df_r), abs(`b_post_union'/`se_post_union'))
      
        local stars_post_union ""
        if `p_post_union' < 0.01 local stars_post_union "***"
        else if (`p_post_union'< 0.05 & `p_post_union'> 0.01) local stars_post_union "**"
        else if (`p_post_union'< 0.10 & `p_post_union'> 0.05) local stars_post_union "*"
      
		quietly reghdfe `outcome' c.`conn'##i.placebo_year if `s_spill' & year<=2011, ///
            absorb(`base_fe' `flow_control_post' ib0.`outcome'_pre`g'#i.year i.mode_union#i.year) vce(cluster identificad)
      
        local b_pre_union = _b[1.placebo_year#c.`conn']
        local se_pre_union = _se[1.placebo_year#c.`conn']
        local p_pre_union = 2*ttail(e(df_r), abs(`b_pre_union'/`se_pre_union'))
      
        local stars_post_union ""
        if `p_pre_union' < 0.01 local stars_post_union "***"
        else if (`p_pre_union'< 0.05 & `p_pre_union'> 0.01) local stars_pre_union "**"
        else if (`p_pre_union'< 0.10 & `p_pre_union'> 0.05) local stars_pre_union "*"
		
        * Write MODE_UNION results
        file open `fh' using "$tables/results_spill_`spec'.csv", write append
        file write `fh' `""`spec'";"spill";"`outcome'_union";"main";"' %9.4f (`b_post_union') `"`stars_post_union'""' _n
        file write `fh' `""`spec'";"spill";"`outcome'_union";"main_se";"' %9.4f (`se_post_union') `"""' _n
		file write `fh' `""`spec'";"spill";"`outcome'_union";"pre";"' %9.4f (`b_pre_union') `"`stars_pre_union'""' _n
        file write `fh' `""`spec'";"spill";"`outcome'_union";"pre_se";"' %9.4f (`se_pre_union') `"""' _n
        file close `fh'
      
        * UNION_EXP_FIRMS: Union exposure control
        quietly reghdfe `outcome' c.`conn'##i.treat_year c.treat_union_exp_all#i.year if `s_spill', ///
            absorb(`base_fe' `flow_control_pre' ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)
      
        local b_post_exp = _b[1.treat_year#c.`conn']
        local se_post_exp = _se[1.treat_year#c.`conn']
        local p_post_exp = 2*ttail(e(df_r), abs(`b_post_exp'/`se_post_exp'))
      
        local stars_post_exp ""
        if `p_post_exp' < 0.01 local stars_post_exp "***"
        else if (`p_post_exp' < 0.05 & `p_post_exp'> 0.01) local stars_post_exp "**"
        else if (`p_post_exp' < 0.10 & `p_post_exp'> 0.05) local stars_post_exp "*"
      
		
		quietly reghdfe `outcome' c.`conn'##i.placebo_year c.treat_union_exp_all#i.year if `s_spill', ///
            absorb(`base_fe' `flow_control_pre' ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)
      
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
        file close `fh'
     
	   
	   * UNION_EMP_EXP: Union exposure control (according to number of workers affected)
        quietly reghdfe `outcome' c.`conn'##i.treat_year c.union_emp_exp#i.year if `s_spill', ///
            absorb(`base_fe' `flow_control_pre' ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)
      
        local b_post_empexp = _b[1.treat_year#c.`conn']
        local se_post_empexp = _se[1.treat_year#c.`conn']
        local p_post_empexp = 2*ttail(e(df_r), abs(`b_post_empexp'/`se_post_empexp'))
      
        local stars_post_empexp ""
        if `p_post_empexp' < 0.01 local stars_post_empexp "***"
        else if (`p_post_empexp' < 0.05 & `p_post_empexp' > 0.01) local stars_post_empexp "**"
        else if (`p_post_empexp' < 0.10 & `p_post_empexp' > 0.05) local stars_post_empexp "*"
      
		
		quietly reghdfe `outcome' c.`conn'##i.placebo_year c.union_emp_exp#i.year if `s_spill', ///
            absorb(`base_fe' `flow_control_pre' ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)
      
        local b_pre_empexp = _b[1.placebo_year#c.`conn']
        local se_pre_empexp = _se[1.placebo_year#c.`conn']
        local p_pre_empexp = 2*ttail(e(df_r), abs(`b_pre_empexp'/`se_pre_empexp'))
      
        local stars_pre_empexp ""
        if `p_pre_empexp' < 0.01 local stars_pre_empexp "***"
        else if (`p_pre_empexp' < 0.05 & `p_pre_empexp' > 0.01) local stars_pre_empexp "**"
        else if (`p_pre_empexp' < 0.10 & `p_pre_empexp' > 0.05) local stars_pre_empexp "*"
      
		* Write UNION_EMP_EXP results
        file open `fh' using "$tables/results_spill_`spec'.csv", write append
        file write `fh' `"`spec'";"spill";"`outcome'_unionempexp";"main";"' %9.4f (`b_post_empexp') `"`stars_post_empexp'""' _n
        file write `fh' `"`spec'";"spill";"`outcome'_unionempexp";"main_se";"' %9.4f (`se_post_empexp') `"""' _n
		file write `fh' `"`spec'";"spill";"`outcome'_unionempexp";"pre";"' %9.4f (`b_pre_empexp') `"`stars_pre_empexp'""' _n
        file write `fh' `"`spec'";"spill";"`outcome'_unionempexp";"pre_se";"' %9.4f (`se_pre_empexp') `"""' _n
        file close `fh'
		
		
      
        * Event study
        quietly reghdfe `outcome' c.`conn'##ib2011.year if `s_spill', ///
            absorb(`base_fe' `flow_control_year'  ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)
      
        estimates store es_spill_`outcome'
      
        local post_coef = string(`b_post', "%9.4f")
        local post_se = string(`se_post', "%9.4f")
        local pre_pval = string(`p_pre', "%9.3f")
      
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
            ytitle("Dynamic DiD coefficients", size(small)) ///
            note("P-value for pre-trend test = `pre_pval'") ///
            graphregion(color(white)) bgcolor(white) ///
            ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) ///
            text(0.015 5 "`post_coef' (`post_se')", color(blue) size(small))
      
        graph export "$graphs/es_spill_`outcome'_`spec'.pdf", as(pdf) replace
      
        estimates drop es_spill_`outcome'
    }
   
    * numb_clauses spillover
    capture confirm variable numb_clauses
    if _rc == 0 {
       
        di _newline(1)
        di as text "Estimating: numb_clauses (spillover, CBA periods)"
       
        local base_fe_cba "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period "
       
        * Post-treatment
        quietly reghdfe numb_clauses c.`conn'##post_treat_cba if `s_spill' & !missing(cba_period), ///
            absorb(`base_fe_cba' `flow_control_cba_post' ib0.numb_clauses_pre`g'#i.cba_period) vce(cluster identificad)
       
        local b_post = _b[1.post_treat_cba#c.`conn']
        local se_post = _se[1.post_treat_cba#c.`conn']
        local p_post = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
        local n_obs = e(N)
        local n_estab = e(N_clust)
       
        * Pre-treatment
        quietly reghdfe numb_clauses c.`conn'##pre_treat_cba if `s_spill' & !missing(cba_period) & cba_period<=2, ///
            absorb(`base_fe_cba' `flow_control_cba_pre' ib0.numb_clauses_pre`g'#i.cba_period) vce(cluster identificad)
       
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
            absorb(`base_fe_cba' `flow_control_cba' ib0.numb_clauses_pre`g'#i.cba_period) vce(cluster identificad)
       
        estimates store es_clauses_spill
       
        local post_coef = string(`b_post', "%9.4f")
        local post_se = string(`se_post', "%9.4f")
        local pre_pval = string(`p_pre', "%9.3f")
       
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
            note("P-value for pre-trend test = `pre_pval'") ///
            graphregion(color(white)) bgcolor(white) ///
            ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) ///
            text(0.6 4 "`post_coef' (`post_se')", color(blue) size(small))
       
        graph export "$graphs/es_spill_numb_clauses_`spec'.pdf", as(pdf) replace
       
        estimates drop es_clauses_spill
    }
    
    * Percentile outcomes - spillover (numeric results only, no plots)
    di as text "Estimating: Percentile outcomes (spillover) - numeric results only"
   
    foreach outcome in $pct_outcomes_dec $pct_outcomes_hour {
       
        local base_fe "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year "
       
        quietly reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
            absorb(`base_fe' `flow_control_post' ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)
       
        local b_post = _b[1.treat_year#c.`conn']
        local se_post = _se[1.treat_year#c.`conn']
        local p_post = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
        local n_obs = e(N)
        local n_estab = e(N_clust)
       
        quietly reghdfe `outcome' c.`conn'##i.placebo_year if `s_spill' & year<=2011, ///
            absorb(`base_fe' `flow_control_pre' ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)
       
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
       
        * Write
        tempname fh
        file open `fh' using "$tables/results_spill_`spec'.csv", write append
        file write `fh' `""`spec'";"spill";"`outcome'";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
        file write `fh' `""`spec'";"spill";"`outcome'";"main_se";"' %9.4f (`se_post') `"""' _n
        file write `fh' `""`spec'";"spill";"`outcome'";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
        file write `fh' `""`spec'";"spill";"`outcome'";"pre_se";"' %9.4f (`se_pre') `"""' _n
        file write `fh' `""`spec'";"spill";"`outcome'";"n_obs";"' %12.0fc (`n_obs') `"""' _n
        file write `fh' `""`spec'";"spill";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""' _n
        file close `fh'
    }
   
    * Ratio outcomes - spillover (numeric results only, no plots)
    di as text "Estimating: Ratio outcomes (spillover) - numeric results only"
   
    foreach outcome in $ratio_outcomes_dec $ratio_outcomes_hour {
       
        local base_fe "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year "
       
        quietly reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
            absorb(`base_fe' `flow_control_post' ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)
       
        local b_post = _b[1.treat_year#c.`conn']
        local se_post = _se[1.treat_year#c.`conn']
        local p_post = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
        local n_obs = e(N)
        local n_estab = e(N_clust)
       
        quietly reghdfe `outcome' c.`conn'##i.placebo_year if `s_spill' & year<=2011, ///
            absorb(`base_fe' `flow_control_pre' ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)
       
        local b_pre = _b[1.placebo_year#c.`conn']
        local se_pre = _se[1.placebo_year#c.`conn']
        local p_pre = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))
       
        * Stars
        local stars_post ""
        if `p_post' < 0.01 local stars_post "***"
        else if (`p_post' < 0.05 & `p_post'>0.01) local stars_post "**"
        else if (`p_post' < 0.10 & `p_post'>0.05) local stars_post "*"
       
        local stars_pre ""
        if `p_pre' < 0.01 local stars_pre "***"
        else if (`p_pre' < 0.05 & `p_pre' > 0.01) local stars_pre "**"
        else if (`p_pre' < 0.10 & `p_pre' > 0.05) local stars_pre "*"
       
        * Write
        tempname fh
        file open `fh' using "$tables/results_spill_`spec'.csv", write append
        file write `fh' `""`spec'";"spill";"`outcome'";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
        file write `fh' `""`spec'";"spill";"`outcome'";"main_se";"' %9.4f (`se_post') `"""' _n
        file write `fh' `""`spec'";"spill";"`outcome'";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
        file write `fh' `""`spec'";"spill";"`outcome'";"pre_se";"' %9.4f (`se_pre') `"""' _n
        file write `fh' `""`spec'";"spill";"`outcome'";"n_obs";"' %12.0fc (`n_obs') `"""' _n
        file write `fh' `""`spec'";"spill";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""' _n
        file close `fh'
    }
    
    di _newline(1)
    di as result "✓ Specification `spec' complete"
}

********************************************************************************
* SECTION 4: COMPLETION
********************************************************************************


 log close
di as result "Finished: `c(current_date)' `c(current_time)'"

********************************************************************************
* END OF DO-FILE
********************************************************************************


local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"
// cap drop totaltreat_pw_n_test_p90
// cap drop totaltreat_pw_test_norm
// sum totaltreat_pw_n_test if `s_spill' & year==2009, detail
// gen totaltreat_pw_n_test_p90 = r(p90)
**# Bookmark #2
// gen totaltreat_pw_test_norm = (totaltreat_pw_n_test / totaltreat_pw_n_test_p90) 

local spec "4tfpe_4out"
local outcome "lr_remdezr_w"
local conn "totaltreat_pw_norm"

local s_direct "(lagos_sample_avg==1 & treat_ultra==0 & totaltreat_pw_n<=0.01 | lagos_sample_avg==1 & treat_ultra==1) & in_balanced_panel==1"
* Define FE locals inside the loop so `outcome' and `g' have values
 local base_fe " identificad  mode_base_month#i.year industry1#i.year i.microregion#i.year"
 local g 4
 local flow_control_post "year   ib0.tf_per_emp_pre`g'#i.year ib0.firm_emp_pre8#i.year "
local flow_control_pre "year  ib0.tf_per_emp_pre`g'#i.year  ib0.firm_emp_pre8#i.year"
        
 * Create header for spillover effects file
    capture erase "$tables/results_spill_`spec'.csv"
	tempname fh
    file open `fh' using "$tables/results_spill_`spec'.csv", write replace
    file write `fh' "spec;section;outcome;row_type;value" _n
    file close `fh'
	
	* BASELINE: Post-treatment
         reghdfe `outcome' c.`conn'##i.treat_year  if `s_spill', ///
            absorb(`base_fe' `flow_control_post' ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)
       
        local b_post = _b[1.treat_year#c.`conn']
        local se_post = _se[1.treat_year#c.`conn']
        local p_post = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
        local n_obs = e(N)
        local n_estab = e(N_clust)
       
        * BASELINE: Pre-treatment
         reghdfe `outcome' c.`conn'##i.placebo_year  if `s_spill' & year<=2011, ///
            absorb(`base_fe' `flow_control_pre' ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)
       
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
//
// * MODE_UNION: Union fixed effects
         reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
            absorb(`base_fe' `flow_control_post' ib0.`outcome'_pre`g'#i.year i.mode_union#i.year) vce(cluster identificad)
       di e(df_r)

        local b_post_union = _b[1.treat_year#c.`conn']
        local se_post_union = _se[1.treat_year#c.`conn']
        local p_post_union = 2*ttail(e(df_r), abs(`b_post_union'/`se_post_union'))
        local n_obs = e(N)
        local n_estab = e(N_clust)
		
        local stars_post_union ""
        if `p_post_union' < 0.01 local stars_post_union "***"
        else if (`p_post_union'< 0.05 & `p_post_union'> 0.01) local stars_post_union "**"
        else if (`p_post_union'< 0.10 & `p_post_union'> 0.05) local stars_post_union "*"
		
		di `"`stars_post_union'""'
       
		 reghdfe `outcome' c.`conn'##i.placebo_year if `s_spill' & year<=2011, ///
            absorb(`base_fe' `flow_control_post' ib0.`outcome'_pre`g'#i.year i.mode_union#i.year) vce(cluster identificad)
//        
        local b_pre_union = _b[1.placebo_year#c.`conn']
        local se_pre_union = _se[1.placebo_year#c.`conn']
        local p_pre_union = 2*ttail(e(df_r), abs(`b_pre_union'/`se_pre_union'))
       
        local stars_pre_union ""
        if `p_pre_union' < 0.01 local stars_pre_union "***"
        else if (`p_pre_union'< 0.05 & `p_pre_union'> 0.01) local stars_pre_union "**"
        else if (`p_pre_union'< 0.10 & `p_pre_union'> 0.05) local stars_pre_union "*"
		
        * Write MODE_UNION results
        file open `fh' using "$tables/results_spill_`spec'.csv", write append
        file write `fh' `""`spec'";"spill";"`outcome'_union";"main";"' %9.4f (`b_post_union') `"`stars_post_union'""' _n
        file write `fh' `""`spec'";"spill";"`outcome'_union";"main_se";"' %9.4f (`se_post_union') `"""' _n
		file write `fh' `""`spec'";"spill";"`outcome'_union";"pre";"' %9.4f (`b_pre_union') `"`stars_pre_union'""' _n
        file write `fh' `""`spec'";"spill";"`outcome'_union";"pre_se";"' %9.4f (`se_pre_union') `"""' _n
		file write `fh' `""`spec'";"spill";"`outcome'_union";"n_obs";"' %12.0fc (`n_obs') `"""' _n
        file write `fh' `""`spec'";"spill";"`outcome'_union";"n_estabs";"' %12.0fc (`n_estab') `"""' _n
        file close `fh'
        
        * UNION_EXP_FIRMS: Union exposure control
         reghdfe `outcome' c.`conn'##i.treat_year c.treat_union_exp_all#i.year if `s_spill', ///
            absorb(`base_fe' `flow_control_pre' ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)
        
        local b_post_exp = _b[1.treat_year#c.`conn']
        local se_post_exp = _se[1.treat_year#c.`conn']
        local p_post_exp = 2*ttail(e(df_r), abs(`b_post_exp'/`se_post_exp'))
		local n_obs = e(N)
        local n_estab = e(N_clust)
        
        local stars_post_exp ""
        if `p_post_exp' < 0.01 local stars_post_exp "***"
        else if (`p_post_exp' < 0.05 & `p_post_exp'> 0.01) local stars_post_exp "**"
        else if (`p_post_exp' < 0.10 & `p_post_exp'> 0.05) local stars_post_exp "*"
        
		
		 reghdfe `outcome' c.`conn'##i.placebo_year c.treat_union_exp_all#i.year if `s_spill' & year<=2011, ///
            absorb(`base_fe' `flow_control_pre' ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)
        di e(df_r)
		
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
        file write `fh' `""`spec'";"spill";"`outcome'_unionexp";"n_obs";"' %12.0fc (`n_obs') `"""' _n
        file write `fh' `""`spec'";"spill";"`outcome'_unionexp";"n_estabs";"' %12.0fc (`n_estab') `"""' _n
        file close `fh'
       
	   
	   * UNION_EMP_EXP: Union exposure control (according to number of workers affected)
         reghdfe `outcome' c.`conn'##treat_year c.union_emp_exp#treat_year if `s_spill' , ///
            absorb(`base_fe' `flow_control_pre' ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)
        
        local b_post_empexp = _b[1.treat_year#c.`conn']
        local se_post_empexp = _se[1.treat_year#c.`conn']
        local p_post_empexp = 2*ttail(e(df_r), abs(`b_post_empexp'/`se_post_empexp'))
		local n_obs = e(N)
        local n_estab = e(N_clust)
        
        local stars_post_empexp ""
        if `p_post_empexp' < 0.01 local stars_post_empexp "***"
        else if (`p_post_empexp' < 0.05 & `p_post_empexp' > 0.01) local stars_post_empexp "**"
        else if (`p_post_empexp' < 0.10 & `p_post_empexp' > 0.05) local stars_post_empexp "*"
        
		
		 reghdfe `outcome' c.`conn'##i.placebo_year c.union_emp_exp#i.placebo_year if `s_spill' & year<=2011, ///
            absorb(`base_fe' `flow_control_pre' ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)
        
        local b_pre_empexp = _b[1.placebo_year#c.`conn']
        local se_pre_empexp = _se[1.placebo_year#c.`conn']
        local p_pre_empexp = 2*ttail(e(df_r), abs(`b_pre_empexp'/`se_pre_empexp'))
        
        local stars_pre_empexp ""
        if `p_pre_empexp' < 0.01 local stars_pre_empexp "***"
        else if (`p_pre_empexp' < 0.05 & `p_pre_empexp' > 0.01) local stars_pre_empexp "**"
        else if (`p_pre_empexp' < 0.10 & `p_pre_empexp' > 0.05) local stars_pre_empexp "*"
        
		* Write UNION_EMP_EXP results
        file open `fh' using "$tables/results_spill_`spec'.csv", write append
        file write `fh' `"`spec'";"spill";"`outcome'_unionempexp";"main";"' %9.4f (`b_post_empexp') `"`stars_post_empexp'""' _n
        file write `fh' `"`spec'";"spill";"`outcome'_unionempexp";"main_se";"' %9.4f (`se_post_empexp') `"""' _n
		file write `fh' `"`spec'";"spill";"`outcome'_unionempexp";"pre";"' %9.4f (`b_pre_empexp') `"`stars_pre_empexp'""' _n
        file write `fh' `"`spec'";"spill";"`outcome'_unionempexp";"pre_se";"' %9.4f (`se_pre_empexp') `"""' _n
        file write `fh' `""`spec'";"spill";"`outcome'_unionempexp";"n_obs";"' %12.0f (`n_obs') `"""' _n
        file write `fh' `""`spec'";"spill";"`outcome'_unionempexp";"n_estabs";"' %12.0f (`n_estab') `"""' _n
        file close `fh'
//		
//	


// Variables below (treat_union, geo_exp, geo_mun_exp, mun_spill_count,
// mic_spill_count, micro_ind, mic_ind_exp, mic_ind_treat, totaltreat_pw_n_p80,
// ind_exp_o) are now generated in Section 1: Variable Creation.

// Descriptive tabs (these use the variables created in Section 1)
local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

tab treat_union if year==2009 & `s_spill'

sum mun_spill_count if year==2011 // 868 municipalities in spillover sample

sum mic_spill_count if year==2011 // 337 microregions in spillover sample

sum totaltreat_pw_n_p80

tab mic_ind_treat if year ==2009 & totaltreat_pw_n >=.0293239 & `s_spill'

// among spillover firms in the top 10% of flows to treated, 63.1% share the same industry and microregion with at least one treated firm

tab mic_ind_treat if year ==2009 & totaltreat_pw_n >=.0494281 & `s_spill' //p95 -> 65%

tab mic_ind_treat if year ==2009 & totaltreat_pw_n >=.0159286 & `s_spill' //p80 -> 59.88%

tab mic_ind_treat if year ==2009 & totaltreat_pw_n >=.0126219 & `s_spill' //p75 -> 58.8%




// How does the distributuion of connectivity looks like?

********************************************************************************
* Test: Industry x Microregion Treatment Exposure Controls
********************************************************************************

* Define sample and specification locals
local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"
local s_exposure "lagos_sample_avg==1 & in_balanced_panel==1"

local spec "micro_ind_test"
local outcome "lr_remdezr_w"
local conn "totaltreat_pw_norm"
local g 4

* Base FE WITHOUT industry#microregion#treat_year
local base_fe "identificad mode_base_month#i.year industry1#i.year i.microregion#i.year"
local flow_control_post "year ib0.tf_per_emp_pre`g'#i.year"
local flow_control_pre "year ib0.tf_per_emp_pre`g'#i.year"

********************************************************************************
* Generate exposure variables
********************************************************************************

* Proportion of treated firms in microregion-industry cell
cap drop mi_exp_f
bys micro_ind year: egen mi_exp_f = mean(treat_ultra) if `s_exposure'

* Proportion of workers in treated firms in microregion-industry cell
cap drop mi_workers
cap drop mi_workers_t
cap drop mi_exp_w
bys micro_ind year: egen mi_workers = total(firm_emp) if `s_exposure'
bys micro_ind year: egen mi_workers_t = total(firm_emp * treat_ultra) if `s_exposure'
gen mi_exp_w = mi_workers_t / mi_workers

********************************************************************************
* Normalize exposure variables to 90th percentile among spillover firms
********************************************************************************

* Get 90th percentile of mi_exp_f among spillover sample in base year
sum mi_exp_f if `s_spill' & year==2009, detail
local p90_exp_f = r(p90)
di "90th percentile of mi_exp_f among spillover firms: `p90_exp_f'"

* Get 90th percentile of mi_exp_w among spillover sample in base year
sum mi_exp_w if `s_spill' & year==2009, detail
local p90_exp_w = r(p90)
di "90th percentile of mi_exp_w among spillover firms: `p90_exp_w'"

* Create normalized versions
cap drop mi_exp_f_n
cap drop mi_exp_w_n
gen mi_exp_f_n = mi_exp_f / `p90_exp_f'
gen mi_exp_w_n = mi_exp_w / `p90_exp_w'

* Label variables
label var mi_exp_f_n "Local Exposure (firms), normalized to P90"
label var mi_exp_w_n "Local Exposure (workers), normalized to P90"

********************************************************************************
* Create CSV file
********************************************************************************
capture erase "$tables/results_micro_ind_test.csv"
tempname fh
file open `fh' using "$tables/results_micro_ind_test.csv", write replace
file write `fh' "spec;outcome;row_type;value" _n
file close `fh'

********************************************************************************
* SPEC 1: Baseline (no industry#microregion#treat_year)
********************************************************************************
reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
    absorb(`base_fe' `flow_control_post' ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)

local b_post = _b[1.treat_year#c.`conn']
local se_post = _se[1.treat_year#c.`conn']
local p_post = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
local n_obs = e(N)
local n_estab = e(N_clust)

reghdfe `outcome' c.`conn'##i.placebo_year if `s_spill' & year<=2011, ///
    absorb(`base_fe' `flow_control_pre' ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)

local b_pre = _b[1.placebo_year#c.`conn']
local se_pre = _se[1.placebo_year#c.`conn']
local p_pre = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

* Stars
local stars_post ""
if `p_post' < 0.01 local stars_post "***"
else if `p_post' < 0.05 local stars_post "**"
else if `p_post' < 0.10 local stars_post "*"

local stars_pre ""
if `p_pre' < 0.01 local stars_pre "***"
else if `p_pre' < 0.05 local stars_pre "**"
else if `p_pre' < 0.10 local stars_pre "*"

* Write results
file open `fh' using "$tables/results_micro_ind_test.csv", write append
file write `fh' `""base";"`outcome'";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
file write `fh' `""base";"`outcome'";"main_se";"' %9.4f (`se_post') `"""' _n
file write `fh' `""base";"`outcome'";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
file write `fh' `""base";"`outcome'";"pre_se";"' %9.4f (`se_pre') `"""' _n
file write `fh' `""base";"`outcome'";"n_obs";"' %12.0fc (`n_obs') `"""' _n
file write `fh' `""base";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""' _n
file close `fh'

********************************************************************************
* SPEC 2: Baseline + i.micro_ind#i.year
********************************************************************************
reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
    absorb(`base_fe' `flow_control_post' ib0.`outcome'_pre`g'#i.year i.micro_ind#i.year) vce(cluster identificad)

local b_post = _b[1.treat_year#c.`conn']
local se_post = _se[1.treat_year#c.`conn']
local p_post = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
local n_obs = e(N)
local n_estab = e(N_clust)

reghdfe `outcome' c.`conn'##i.placebo_year if `s_spill' & year<=2011, ///
    absorb(`base_fe' `flow_control_pre' ib0.`outcome'_pre`g'#i.year i.micro_ind#i.year) vce(cluster identificad)

local b_pre = _b[1.placebo_year#c.`conn']
local se_pre = _se[1.placebo_year#c.`conn']
local p_pre = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

* Stars
local stars_post ""
if `p_post' < 0.01 local stars_post "***"
else if `p_post' < 0.05 local stars_post "**"
else if `p_post' < 0.10 local stars_post "*"

local stars_pre ""
if `p_pre' < 0.01 local stars_pre "***"
else if `p_pre' < 0.05 local stars_pre "**"
else if `p_pre' < 0.10 local stars_pre "*"

* Write results
file open `fh' using "$tables/results_micro_ind_test.csv", write append
file write `fh' `""mi_fe_yr";"`outcome'";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
file write `fh' `""mi_fe_yr";"`outcome'";"main_se";"' %9.4f (`se_post') `"""' _n
file write `fh' `""mi_fe_yr";"`outcome'";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
file write `fh' `""mi_fe_yr";"`outcome'";"pre_se";"' %9.4f (`se_pre') `"""' _n
file write `fh' `""mi_fe_yr";"`outcome'";"n_obs";"' %12.0fc (`n_obs') `"""' _n
file write `fh' `""mi_fe_yr";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""' _n
file close `fh'

********************************************************************************
* SPEC 3: Baseline + i.micro_ind#treat_year / i.micro_ind#placebo_year
********************************************************************************
reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
    absorb(`base_fe' `flow_control_post' i.micro_ind#i.treat_year ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)

local b_post = _b[1.treat_year#c.`conn']
local se_post = _se[1.treat_year#c.`conn']
local p_post = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
local n_obs = e(N)
local n_estab = e(N_clust)

reghdfe `outcome' c.`conn'##i.placebo_year if `s_spill' & year<=2011, ///
    absorb(`base_fe' `flow_control_pre' i.micro_ind#i.placebo_year ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)

local b_pre = _b[1.placebo_year#c.`conn']
local se_pre = _se[1.placebo_year#c.`conn']
local p_pre = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

* Stars
local stars_post ""
if `p_post' < 0.01 local stars_post "***"
else if `p_post' < 0.05 local stars_post "**"
else if `p_post' < 0.10 local stars_post "*"

local stars_pre ""
if `p_pre' < 0.01 local stars_pre "***"
else if `p_pre' < 0.05 local stars_pre "**"
else if `p_pre' < 0.10 local stars_pre "*"

* Write results
file open `fh' using "$tables/results_micro_ind_test.csv", write append
file write `fh' `""mi_fe_tr";"`outcome'";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
file write `fh' `""mi_fe_tr";"`outcome'";"main_se";"' %9.4f (`se_post') `"""' _n
file write `fh' `""mi_fe_tr";"`outcome'";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
file write `fh' `""mi_fe_tr";"`outcome'";"pre_se";"' %9.4f (`se_pre') `"""' _n
file write `fh' `""mi_fe_tr";"`outcome'";"n_obs";"' %12.0fc (`n_obs') `"""' _n
file write `fh' `""mi_fe_tr";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""' _n
file close `fh'

********************************************************************************
* SPEC 4: Baseline + c.mi_exp_f_n#i.year
********************************************************************************
reghdfe `outcome' c.`conn'##i.treat_year c.mi_exp_f_n#i.year if `s_spill', ///
    absorb(`base_fe' `flow_control_post' ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)

local b_post = _b[1.treat_year#c.`conn']
local se_post = _se[1.treat_year#c.`conn']
local p_post = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
local n_obs = e(N)
local n_estab = e(N_clust)

reghdfe `outcome' c.`conn'##i.placebo_year c.mi_exp_f_n#i.year if `s_spill' & year<=2011, ///
    absorb(`base_fe' `flow_control_pre' ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)

local b_pre = _b[1.placebo_year#c.`conn']
local se_pre = _se[1.placebo_year#c.`conn']
local p_pre = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

* Stars
local stars_post ""
if `p_post' < 0.01 local stars_post "***"
else if `p_post' < 0.05 local stars_post "**"
else if `p_post' < 0.10 local stars_post "*"

local stars_pre ""
if `p_pre' < 0.01 local stars_pre "***"
else if `p_pre' < 0.05 local stars_pre "**"
else if `p_pre' < 0.10 local stars_pre "*"

* Write results
file open `fh' using "$tables/results_micro_ind_test.csv", write append
file write `fh' `""mif_yr";"`outcome'";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
file write `fh' `""mif_yr";"`outcome'";"main_se";"' %9.4f (`se_post') `"""' _n
file write `fh' `""mif_yr";"`outcome'";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
file write `fh' `""mif_yr";"`outcome'";"pre_se";"' %9.4f (`se_pre') `"""' _n
file write `fh' `""mif_yr";"`outcome'";"n_obs";"' %12.0fc (`n_obs') `"""' _n
file write `fh' `""mif_yr";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""' _n
file close `fh'

********************************************************************************
* SPEC 5: Baseline + c.mi_exp_f_n#treat_year / placebo_year
********************************************************************************

* Create interaction variables manually
cap drop mief_n_post
cap drop mief_n_plac
gen mief_n_post = mi_exp_f_n * treat_year
gen mief_n_plac = mi_exp_f_n * placebo_year

* Post-treatment regression
reghdfe `outcome' c.`conn'##i.treat_year mief_n_post if `s_spill', ///
    absorb(`base_fe' `flow_control_post' ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)

local b_post = _b[1.treat_year#c.`conn']
local se_post = _se[1.treat_year#c.`conn']
local p_post = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
local n_obs = e(N)
local n_estab = e(N_clust)

* Coefficient on mief_n_post
local b_ctrl = _b[mief_n_post]
local se_ctrl = _se[mief_n_post]
local p_ctrl = 2*ttail(e(df_r), abs(`b_ctrl'/`se_ctrl'))

* Pre-treatment regression
reghdfe `outcome' c.`conn'##i.placebo_year  mief_n_plac if `s_spill' & year<=2011, ///
    absorb(`base_fe' `flow_control_pre' ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)

local b_pre = _b[1.placebo_year#c.`conn']
local se_pre = _se[1.placebo_year#c.`conn']
local p_pre = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

* Coefficient on mief_n_plac
local b_ctrl_pre = _b[mief_n_plac]
local se_ctrl_pre = _se[mief_n_plac]
local p_ctrl_pre = 2*ttail(e(df_r), abs(`b_ctrl_pre'/`se_ctrl_pre'))

* Stars for main coefficients
local stars_post ""
if `p_post' < 0.01 local stars_post "***"
else if `p_post' < 0.05 local stars_post "**"
else if `p_post' < 0.10 local stars_post "*"

local stars_pre ""
if `p_pre' < 0.01 local stars_pre "***"
else if `p_pre' < 0.05 local stars_pre "**"
else if `p_pre' < 0.10 local stars_pre "*"

* Stars for control coefficients
local stars_ctrl ""
if `p_ctrl' < 0.01 local stars_ctrl "***"
else if `p_ctrl' < 0.05 local stars_ctrl "**"
else if `p_ctrl' < 0.10 local stars_ctrl "*"

local stars_ctrl_pre ""
if `p_ctrl_pre' < 0.01 local stars_ctrl_pre "***"
else if `p_ctrl_pre' < 0.05 local stars_ctrl_pre "**"
else if `p_ctrl_pre' < 0.10 local stars_ctrl_pre "*"

* Write results
file open `fh' using "$tables/results_micro_ind_test.csv", write append
file write `fh' `""mif_tr";"`outcome'";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
file write `fh' `""mif_tr";"`outcome'";"main_se";"' %9.4f (`se_post') `"""' _n
file write `fh' `""mif_tr";"`outcome'";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
file write `fh' `""mif_tr";"`outcome'";"pre_se";"' %9.4f (`se_pre') `"""' _n
file write `fh' `""mif_tr";"`outcome'";"ctrl_main";"' %9.4f (`b_ctrl') `"`stars_ctrl'""' _n
file write `fh' `""mif_tr";"`outcome'";"ctrl_main_se";"' %9.4f (`se_ctrl') `"""' _n
file write `fh' `""mif_tr";"`outcome'";"ctrl_pre";"' %9.4f (`b_ctrl_pre') `"`stars_ctrl_pre'""' _n
file write `fh' `""mif_tr";"`outcome'";"ctrl_pre_se";"' %9.4f (`se_ctrl_pre') `"""' _n
file write `fh' `""mif_tr";"`outcome'";"n_obs";"' %12.0fc (`n_obs') `"""' _n
file write `fh' `""mif_tr";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""' _n
file close `fh'


********************************************************************************
* SPEC 5b: Baseline + c.mi_exp_f_n#treat_year / placebo_year, excludes pure connectivity
********************************************************************************

* Create interaction variables manually
cap drop mief_n_post
cap drop mief_n_plac
gen mief_n_post = mi_exp_f_n * treat_year
gen mief_n_plac = mi_exp_f_n * placebo_year

* Post-treatment regression
reghdfe `outcome'  mief_n_post if `s_spill', ///
    absorb(`base_fe' `flow_control_post' ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)

// local b_post = _b[1.treat_year#c.`conn']
// local se_post = _se[1.treat_year#c.`conn']
// local p_post = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
local n_obs = e(N)
local n_estab = e(N_clust)

* Coefficient on mief_n_post
local b_ctrl = _b[mief_n_post]
local se_ctrl = _se[mief_n_post]
local p_ctrl = 2*ttail(e(df_r), abs(`b_ctrl'/`se_ctrl'))

* Pre-treatment regression
reghdfe `outcome'  mief_n_plac if `s_spill' & year<=2011, ///
    absorb(`base_fe' `flow_control_pre' ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)

// local b_pre = _b[1.placebo_year#c.`conn']
// local se_pre = _se[1.placebo_year#c.`conn']
// local p_pre = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

* Coefficient on mief_n_plac
local b_ctrl_pre = _b[mief_n_plac]
local se_ctrl_pre = _se[mief_n_plac]
local p_ctrl_pre = 2*ttail(e(df_r), abs(`b_ctrl_pre'/`se_ctrl_pre'))

* Stars for main coefficients
local stars_post ""
if `p_post' < 0.01 local stars_post "***"
else if `p_post' < 0.05 local stars_post "**"
else if `p_post' < 0.10 local stars_post "*"

local stars_pre ""
if `p_pre' < 0.01 local stars_pre "***"
else if `p_pre' < 0.05 local stars_pre "**"
else if `p_pre' < 0.10 local stars_pre "*"

* Stars for control coefficients
local stars_ctrl ""
if `p_ctrl' < 0.01 local stars_ctrl "***"
else if `p_ctrl' < 0.05 local stars_ctrl "**"
else if `p_ctrl' < 0.10 local stars_ctrl "*"

local stars_ctrl_pre ""
if `p_ctrl_pre' < 0.01 local stars_ctrl_pre "***"
else if `p_ctrl_pre' < 0.05 local stars_ctrl_pre "**"
else if `p_ctrl_pre' < 0.10 local stars_ctrl_pre "*"

* Write results
file open `fh' using "$tables/results_micro_ind_test.csv", write append
file write `fh' `""mif_tr";"`outcome'";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
file write `fh' `""mif_tr";"`outcome'";"main_se";"' %9.4f (`se_post') `"""' _n
file write `fh' `""mif_tr";"`outcome'";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
file write `fh' `""mif_tr";"`outcome'";"pre_se";"' %9.4f (`se_pre') `"""' _n
file write `fh' `""mif_tr";"`outcome'";"ctrl_main";"' %9.4f (`b_ctrl') `"`stars_ctrl'""' _n
file write `fh' `""mif_tr";"`outcome'";"ctrl_main_se";"' %9.4f (`se_ctrl') `"""' _n
file write `fh' `""mif_tr";"`outcome'";"ctrl_pre";"' %9.4f (`b_ctrl_pre') `"`stars_ctrl_pre'""' _n
file write `fh' `""mif_tr";"`outcome'";"ctrl_pre_se";"' %9.4f (`se_ctrl_pre') `"""' _n
file write `fh' `""mif_tr";"`outcome'";"n_obs";"' %12.0fc (`n_obs') `"""' _n
file write `fh' `""mif_tr";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""' _n
file close `fh'

********************************************************************************
* SPEC 6: Baseline + c.mi_exp_w_n#i.year
********************************************************************************
reghdfe `outcome' c.`conn'##i.treat_year c.mi_exp_w_n#i.year if `s_spill', ///
    absorb(`base_fe' `flow_control_post' ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)

local b_post = _b[1.treat_year#c.`conn']
local se_post = _se[1.treat_year#c.`conn']
local p_post = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
local n_obs = e(N)
local n_estab = e(N_clust)

reghdfe `outcome' c.`conn'##i.placebo_year c.mi_exp_w_n#i.year if `s_spill' & year<=2011, ///
    absorb(`base_fe' `flow_control_pre' ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)

local b_pre = _b[1.placebo_year#c.`conn']
local se_pre = _se[1.placebo_year#c.`conn']
local p_pre = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

* Stars
local stars_post ""
if `p_post' < 0.01 local stars_post "***"
else if `p_post' < 0.05 local stars_post "**"
else if `p_post' < 0.10 local stars_post "*"

local stars_pre ""
if `p_pre' < 0.01 local stars_pre "***"
else if `p_pre' < 0.05 local stars_pre "**"
else if `p_pre' < 0.10 local stars_pre "*"

* Write results
file open `fh' using "$tables/results_micro_ind_test.csv", write append
file write `fh' `""miw_yr";"`outcome'";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
file write `fh' `""miw_yr";"`outcome'";"main_se";"' %9.4f (`se_post') `"""' _n
file write `fh' `""miw_yr";"`outcome'";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
file write `fh' `""miw_yr";"`outcome'";"pre_se";"' %9.4f (`se_pre') `"""' _n
file write `fh' `""miw_yr";"`outcome'";"n_obs";"' %12.0fc (`n_obs') `"""' _n
file write `fh' `""miw_yr";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""' _n
file close `fh'

********************************************************************************
* SPEC 7: Baseline + c.mi_exp_w_n#treat_year / placebo_year
********************************************************************************

* Create interaction variables manually
cap drop miew_n_post
cap drop miew_n_plac
gen miew_n_post = mi_exp_w_n * treat_year
gen miew_n_plac = mi_exp_w_n * placebo_year

* Post-treatment regression
reghdfe `outcome' c.`conn'##i.treat_year miew_n_post if `s_spill', ///
    absorb(`base_fe' `flow_control_post' ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)

local b_post = _b[1.treat_year#c.`conn']
local se_post = _se[1.treat_year#c.`conn']
local p_post = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
local n_obs = e(N)
local n_estab = e(N_clust)

* Coefficient on miew_n_post
local b_ctrl = _b[miew_n_post]
local se_ctrl = _se[miew_n_post]
local p_ctrl = 2*ttail(e(df_r), abs(`b_ctrl'/`se_ctrl'))

* Pre-treatment regression
reghdfe `outcome' c.`conn'##i.placebo_year miew_n_plac if `s_spill' & year<=2011, ///
    absorb(`base_fe' `flow_control_pre' ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)

local b_pre = _b[1.placebo_year#c.`conn']
local se_pre = _se[1.placebo_year#c.`conn']
local p_pre = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

* Coefficient on miew_n_plac
local b_ctrl_pre = _b[miew_n_plac]
local se_ctrl_pre = _se[miew_n_plac]
local p_ctrl_pre = 2*ttail(e(df_r), abs(`b_ctrl_pre'/`se_ctrl_pre'))

* Stars for main coefficients
local stars_post ""
if `p_post' < 0.01 local stars_post "***"
else if `p_post' < 0.05 local stars_post "**"
else if `p_post' < 0.10 local stars_post "*"

local stars_pre ""
if `p_pre' < 0.01 local stars_pre "***"
else if `p_pre' < 0.05 local stars_pre "**"
else if `p_pre' < 0.10 local stars_pre "*"

* Stars for control coefficients
local stars_ctrl ""
if `p_ctrl' < 0.01 local stars_ctrl "***"
else if `p_ctrl' < 0.05 local stars_ctrl "**"
else if `p_ctrl' < 0.10 local stars_ctrl "*"

local stars_ctrl_pre ""
if `p_ctrl_pre' < 0.01 local stars_ctrl_pre "***"
else if `p_ctrl_pre' < 0.05 local stars_ctrl_pre "**"
else if `p_ctrl_pre' < 0.10 local stars_ctrl_pre "*"

* Write results
file open `fh' using "$tables/results_micro_ind_test.csv", write append
file write `fh' `""miw_tr";"`outcome'";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
file write `fh' `""miw_tr";"`outcome'";"main_se";"' %9.4f (`se_post') `"""' _n
file write `fh' `""miw_tr";"`outcome'";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
file write `fh' `""miw_tr";"`outcome'";"pre_se";"' %9.4f (`se_pre') `"""' _n
file write `fh' `""miw_tr";"`outcome'";"ctrl_main";"' %9.4f (`b_ctrl') `"`stars_ctrl'""' _n
file write `fh' `""miw_tr";"`outcome'";"ctrl_main_se";"' %9.4f (`se_ctrl') `"""' _n
file write `fh' `""miw_tr";"`outcome'";"ctrl_pre";"' %9.4f (`b_ctrl_pre') `"`stars_ctrl_pre'""' _n
file write `fh' `""miw_tr";"`outcome'";"ctrl_pre_se";"' %9.4f (`se_ctrl_pre') `"""' _n
file write `fh' `""miw_tr";"`outcome'";"n_obs";"' %12.0fc (`n_obs') `"""' _n
file write `fh' `""miw_tr";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""' _n
file close `fh'


********************************************************************************
* SPEC 7b: Baseline + c.mi_exp_w_n#treat_year / placebo_year, no connectivity
********************************************************************************

* Create interaction variables manually
cap drop miew_n_post
cap drop miew_n_plac
gen miew_n_post = mi_exp_w_n * treat_year
gen miew_n_plac = mi_exp_w_n * placebo_year

* Post-treatment regression
reghdfe `outcome'  miew_n_post if `s_spill', ///
    absorb(`base_fe' `flow_control_post' ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)

// local b_post = _b[1.treat_year#c.`conn']
// local se_post = _se[1.treat_year#c.`conn']
// local p_post = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
local n_obs = e(N)
local n_estab = e(N_clust)

* Coefficient on miew_n_post
local b_ctrl = _b[miew_n_post]
local se_ctrl = _se[miew_n_post]
local p_ctrl = 2*ttail(e(df_r), abs(`b_ctrl'/`se_ctrl'))

* Pre-treatment regression
reghdfe `outcome' miew_n_plac if `s_spill' & year<=2011, ///
    absorb(`base_fe' `flow_control_pre' ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)

// local b_pre = _b[1.placebo_year#c.`conn']
// local se_pre = _se[1.placebo_year#c.`conn']
// local p_pre = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

* Coefficient on miew_n_plac
local b_ctrl_pre = _b[miew_n_plac]
local se_ctrl_pre = _se[miew_n_plac]
local p_ctrl_pre = 2*ttail(e(df_r), abs(`b_ctrl_pre'/`se_ctrl_pre'))

* Stars for main coefficients
local stars_post ""
if `p_post' < 0.01 local stars_post "***"
else if `p_post' < 0.05 local stars_post "**"
else if `p_post' < 0.10 local stars_post "*"

local stars_pre ""
if `p_pre' < 0.01 local stars_pre "***"
else if `p_pre' < 0.05 local stars_pre "**"
else if `p_pre' < 0.10 local stars_pre "*"

* Stars for control coefficients
local stars_ctrl ""
if `p_ctrl' < 0.01 local stars_ctrl "***"
else if `p_ctrl' < 0.05 local stars_ctrl "**"
else if `p_ctrl' < 0.10 local stars_ctrl "*"

local stars_ctrl_pre ""
if `p_ctrl_pre' < 0.01 local stars_ctrl_pre "***"
else if `p_ctrl_pre' < 0.05 local stars_ctrl_pre "**"
else if `p_ctrl_pre' < 0.10 local stars_ctrl_pre "*"

* Write results
file open `fh' using "$tables/results_micro_ind_test.csv", write append
file write `fh' `""miw_tr";"`outcome'";"main";"' %9.4f (`b_post') `"`stars_post'""' _n
file write `fh' `""miw_tr";"`outcome'";"main_se";"' %9.4f (`se_post') `"""' _n
file write `fh' `""miw_tr";"`outcome'";"pre";"' %9.4f (`b_pre') `"`stars_pre'""' _n
file write `fh' `""miw_tr";"`outcome'";"pre_se";"' %9.4f (`se_pre') `"""' _n
file write `fh' `""miw_tr";"`outcome'";"ctrl_main";"' %9.4f (`b_ctrl') `"`stars_ctrl'""' _n
file write `fh' `""miw_tr";"`outcome'";"ctrl_main_se";"' %9.4f (`se_ctrl') `"""' _n
file write `fh' `""miw_tr";"`outcome'";"ctrl_pre";"' %9.4f (`b_ctrl_pre') `"`stars_ctrl_pre'""' _n
file write `fh' `""miw_tr";"`outcome'";"ctrl_pre_se";"' %9.4f (`se_ctrl_pre') `"""' _n
file write `fh' `""miw_tr";"`outcome'";"n_obs";"' %12.0fc (`n_obs') `"""' _n
file write `fh' `""miw_tr";"`outcome'";"n_estab";"' %12.0fc (`n_estab') `"""' _n
file close `fh'
* Clean up
drop mief_n_post mief_n_plac miew_n_post miew_n_plac

di "Results saved to: $tables/results_micro_ind_test.csv"
di "Note: Local exposure measures normalized to 90th percentile among spillover firms"
di "  P90 of mi_exp_f: `p90_exp_f'"
di "  P90 of mi_exp_w: `p90_exp_w'"

********************************************************************************
* Diagnostic: Decompose Column 2 effect - Sample restriction vs. FE inclusion
********************************************************************************

* Step 1: Run spec 2 and mark the estimation sample
reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
    absorb(`base_fe' `flow_control_post' ib0.`outcome'_pre`g'#i.year i.micro_ind#i.year) vce(cluster identificad)

* Mark observations used in estimation
gen byte in_spec2_sample = e(sample)

* Step 2: Run baseline on the SAME sample as spec 2
di _n "=============================================="
di "BASELINE ON FULL SAMPLE (Column 1):"
di "=============================================="
reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
    absorb(`base_fe' `flow_control_post' ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)

di _n "=============================================="
di "BASELINE ON SPEC 2 SAMPLE (restricted to non-singletons):"
di "=============================================="
reghdfe `outcome' c.`conn'##i.treat_year if `s_spill' & in_spec2_sample==1, ///
    absorb(`base_fe' `flow_control_post' ib0.`outcome'_pre`g'#i.year) vce(cluster identificad)

di _n "=============================================="
di "SPEC 2: BASELINE + MICRO_IND x YEAR FE (Column 2):"
di "=============================================="
reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
    absorb(`base_fe' `flow_control_post' ib0.`outcome'_pre`g'#i.year i.micro_ind#i.year) vce(cluster identificad)

* Clean up
drop in_spec2_sample

* Summary comparison
di _n "=============================================="
di "INTERPRETATION:"
di "=============================================="
di "If baseline on restricted sample ≈ Column 1 → Sample restriction matters little"
di "If baseline on restricted sample ≈ Column 2 → Sample restriction drives the change"
di "If baseline on restricted sample is between → Both factors contribute"
di "=============================================="



********************************************************************************
* IV ESTIMATION: Instrumenting Post-Treatment Flows with Pre-Treatment Flows
* Plus OLS with Post-Treatment Flows for Comparison
********************************************************************************

* ===============================
* SETUP
* ===============================
local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"
local outcome_list "lr_remdezr_w lr_remdezr_h_w l_firm_emp numb_clauses"
local g 4

* Base FE 
local base_fe "identificad mode_base_month#i.year industry1#i.year i.microregion#i.year"
local flow_control_post "year ib0.tf_per_emp_pre`g'#i.year"
local flow_control_pre "year ib0.tf_per_emp_pre`g'#i.year"

********************************************************************************
* STEP 1: VARIABLE PREPARATION
********************************************************************************

* Normalize post-treatment connectivity to its own P90 among spillover sample
cap drop totaltreat_pw_post_p90
cap drop totaltreat_pw_post_norm
sum totaltreat_pw_post if `s_spill' & year==2009, detail
local p90_post = r(p90)
gen totaltreat_pw_post_p90 = `p90_post'
gen totaltreat_pw_post_norm = totaltreat_pw_post / `p90_post'

di "P90 of post-treatment connectivity: `p90_post'"

* Create interactions for main regressions
cap drop conn_post_X_treat
cap drop conn_pre_X_treat
cap drop conn_post_X_plac
cap drop conn_pre_X_plac

gen conn_post_X_treat = totaltreat_pw_post_norm * treat_year
gen conn_pre_X_treat = totaltreat_pw_norm * treat_year

gen conn_post_X_plac = totaltreat_pw_post_norm * placebo_year
gen conn_pre_X_plac = totaltreat_pw_norm * placebo_year

* Create year-specific interactions for event study (2011 omitted as base)
foreach yr in 2009 2010 2012 2013 2014 2015 2016 {
    cap drop conn_post_`yr' conn_pre_`yr'
    gen conn_post_`yr' = totaltreat_pw_post_norm * (year == `yr')
    gen conn_pre_`yr' = totaltreat_pw_norm * (year == `yr')
}

label var conn_post_X_treat "Post × Connectivity (post-flows)"
label var conn_pre_X_treat "Post × Connectivity (pre-flows, instrument)"
label var totaltreat_pw_post_norm "Post-treatment connectivity (normalized)"
label var totaltreat_pw_norm "Pre-treatment connectivity (normalized)"

********************************************************************************
* STEP 2: CREATE OUTPUT FILES
********************************************************************************

* Main IV results
capture erase "$tables/results_iv_spillover.csv"
tempname fh
file open `fh' using "$tables/results_iv_spillover.csv", write replace
file write `fh' "outcome;row_type;value" _n
file close `fh'

* First stage results
capture erase "$tables/results_iv_firststage.csv"
file open `fh' using "$tables/results_iv_firststage.csv", write replace
file write `fh' "statistic;value" _n
file close `fh'

********************************************************************************
* STEP 3: FIRST STAGE TABLE (Run once on lr_remdezr_w sample)
********************************************************************************

di _newline(2)
di as result "{hline 60}"
di as result "FIRST STAGE REGRESSION"
di as result "{hline 60}"

local outcome "lr_remdezr_w"

* Run IV regression to get first stage diagnostics
ivreghdfe `outcome' (conn_post_X_treat = conn_pre_X_treat) if `s_spill', ///
    absorb(`base_fe' `flow_control_post' ib0.`outcome'_pre`g'#i.year) ///
    cluster(identificad)

* Extract first-stage statistics from e() matrices
matrix fs = e(first)
local fs_F = fs[4,1]          // Kleibergen-Paap rk Wald F statistic
local fs_chi2 = fs[3,1]       // Kleibergen-Paap rk LM statistic (underidentification)

* Get first stage coefficient by running the first stage directly
reghdfe conn_post_X_treat conn_pre_X_treat if `s_spill', ///
    absorb(`base_fe' `flow_control_post' ib0.`outcome'_pre`g'#i.year) ///
    cluster(identificad)

local fs_coef = _b[conn_pre_X_treat]
local fs_se = _se[conn_pre_X_treat]
local n_obs = e(N)
local n_clust = e(N_clust)

* Display results
di as result "First stage coefficient: " %9.4f `fs_coef'
di as result "First stage SE: " %9.4f `fs_se'
di as result "Kleibergen-Paap F-stat: " %9.2f `fs_F'
di as result "Kleibergen-Paap LM stat: " %9.2f `fs_chi2'
di as result "N observations: " %12.0fc `n_obs'
di as result "N clusters: " %12.0fc `n_clust'

* Write first stage results to CSV
tempname fh
file open `fh' using "$tables/results_iv_firststage.csv", write append
file write `fh' "fs_coef;" %9.4f (`fs_coef') _n
file write `fh' "fs_se;" %9.4f (`fs_se') _n
file write `fh' "kp_F;" %9.2f (`fs_F') _n
file write `fh' "kp_LM;" %9.2f (`fs_chi2') _n
file write `fh' "n_obs;" %12.0f (`n_obs') _n
file write `fh' "n_clust;" %12.0f (`n_clust') _n
file close `fh'

********************************************************************************
* STEP 4: MAIN RESULTS - LOOP OVER OUTCOMES (OLS and IV)
********************************************************************************

di _newline(2)
di as result "{hline 60}"
di as result "OLS AND IV SECOND STAGE RESULTS"
di as result "{hline 60}"

foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {
    
    di _newline(1)
    di as text "Estimating: `outcome'"
    di as text "{hline 40}"
    
    * ===================
    * OLS with post-treatment connectivity
    * ===================
    
    di as text "  OLS (post-treatment connectivity)..."
    
    * Post-treatment OLS regression
    reghdfe `outcome' c.totaltreat_pw_post_norm##i.treat_year if `s_spill', ///
        absorb(`base_fe' `flow_control_post' ib0.`outcome'_pre`g'#i.year) ///
        cluster(identificad)
    
    local b_post_ols = _b[1.treat_year#c.totaltreat_pw_post_norm]
    local se_post_ols = _se[1.treat_year#c.totaltreat_pw_post_norm]
    local p_post_ols = 2*ttail(e(df_r), abs(`b_post_ols'/`se_post_ols'))
    local n_obs_ols = e(N)
    local n_estab_ols = e(N_clust)
    
    * Pre-treatment OLS regression (placebo)
    reghdfe `outcome' c.totaltreat_pw_post_norm##i.placebo_year if `s_spill' & year<=2011, ///
        absorb(`base_fe' `flow_control_pre' ib0.`outcome'_pre`g'#i.year) ///
        cluster(identificad)
    
    local b_pre_ols = _b[1.placebo_year#c.totaltreat_pw_post_norm]
    local se_pre_ols = _se[1.placebo_year#c.totaltreat_pw_post_norm]
    local p_pre_ols = 2*ttail(e(df_r), abs(`b_pre_ols'/`se_pre_ols'))
    
    * Stars for OLS
    local stars_post_ols ""
    if `p_post_ols' < 0.01 local stars_post_ols "***"
    else if `p_post_ols' < 0.05 local stars_post_ols "**"
    else if `p_post_ols' < 0.10 local stars_post_ols "*"
    
    local stars_pre_ols ""
    if `p_pre_ols' < 0.01 local stars_pre_ols "***"
    else if `p_pre_ols' < 0.05 local stars_pre_ols "**"
    else if `p_pre_ols' < 0.10 local stars_pre_ols "*"
    
    * Write OLS results to CSV
    tempname fh
    file open `fh' using "$tables/results_iv_spillover.csv", write append
    file write `fh' `"`outcome'_ols;main;"' %9.4f (`b_post_ols') `"`stars_post_ols'"' _n
    file write `fh' `"`outcome'_ols;main_se;"' %9.4f (`se_post_ols') _n
    file write `fh' `"`outcome'_ols;pre;"' %9.4f (`b_pre_ols') `"`stars_pre_ols'"' _n
    file write `fh' `"`outcome'_ols;pre_se;"' %9.4f (`se_pre_ols') _n
    file write `fh' `"`outcome'_ols;n_obs;"' %12.0f (`n_obs_ols') _n
    file write `fh' `"`outcome'_ols;n_estab;"' %12.0f (`n_estab_ols') _n
    file close `fh'
    
    di as result "    Post × Connectivity (OLS): " %9.4f `b_post_ols' " `stars_post_ols'"
    di as result "    Pre-treatment (OLS):       " %9.4f `b_pre_ols' " `stars_pre_ols'"
    
    * ===================
    * IV regression
    * ===================
    
    di as text "  IV (post instrumented by pre)..."
    
    * Post-treatment IV regression
    ivreghdfe `outcome' (conn_post_X_treat = conn_pre_X_treat) if `s_spill', ///
        absorb(`base_fe' `flow_control_post' ib0.`outcome'_pre`g'#i.year) ///
        cluster(identificad)
    
    local b_post_iv = _b[conn_post_X_treat]
    local se_post_iv = _se[conn_post_X_treat]
    local p_post_iv = 2*ttail(e(df_r), abs(`b_post_iv'/`se_post_iv'))
    local n_obs_iv = e(N)
    local n_estab_iv = e(N_clust)
    
    * Pre-treatment IV regression (placebo)
    ivreghdfe `outcome' (conn_post_X_plac = conn_pre_X_plac) if `s_spill' & year<=2011, ///
        absorb(`base_fe' `flow_control_pre' ib0.`outcome'_pre`g'#i.year) ///
        cluster(identificad)
    
    local b_pre_iv = _b[conn_post_X_plac]
    local se_pre_iv = _se[conn_post_X_plac]
    local p_pre_iv = 2*ttail(e(df_r), abs(`b_pre_iv'/`se_pre_iv'))
    
    * Stars for IV
    local stars_post_iv ""
    if `p_post_iv' < 0.01 local stars_post_iv "***"
    else if `p_post_iv' < 0.05 local stars_post_iv "**"
    else if `p_post_iv' < 0.10 local stars_post_iv "*"
    
    local stars_pre_iv ""
    if `p_pre_iv' < 0.01 local stars_pre_iv "***"
    else if `p_pre_iv' < 0.05 local stars_pre_iv "**"
    else if `p_pre_iv' < 0.10 local stars_pre_iv "*"
    
    * Write IV results to CSV
    tempname fh
    file open `fh' using "$tables/results_iv_spillover.csv", write append
    file write `fh' `"`outcome'_iv;main;"' %9.4f (`b_post_iv') `"`stars_post_iv'"' _n
    file write `fh' `"`outcome'_iv;main_se;"' %9.4f (`se_post_iv') _n
    file write `fh' `"`outcome'_iv;pre;"' %9.4f (`b_pre_iv') `"`stars_pre_iv'"' _n
    file write `fh' `"`outcome'_iv;pre_se;"' %9.4f (`se_pre_iv') _n
    file write `fh' `"`outcome'_iv;n_obs;"' %12.0f (`n_obs_iv') _n
    file write `fh' `"`outcome'_iv;n_estab;"' %12.0f (`n_estab_iv') _n
    file close `fh'
    
    di as result "    Post × Connectivity (IV):  " %9.4f `b_post_iv' " `stars_post_iv'"
    di as result "    Pre-treatment (IV):        " %9.4f `b_pre_iv' " `stars_pre_iv'"
}

********************************************************************************
* STEP 5: NUMB_CLAUSES (CBA periods) - OLS and IV
********************************************************************************

di _newline(1)
di as text "Estimating: numb_clauses (CBA periods)"
di as text "{hline 40}"

local base_fe_cba "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period"
local flow_control_cba "cba_period ib0.tf_per_emp_pre`g'#i.cba_period"

* Create CBA period interactions
cap drop conn_post_X_postcba
cap drop conn_pre_X_postcba
cap drop conn_post_X_precba
cap drop conn_pre_X_precba

gen conn_post_X_postcba = totaltreat_pw_post_norm * post_treat_cba
gen conn_pre_X_postcba = totaltreat_pw_norm * post_treat_cba
gen conn_post_X_precba = totaltreat_pw_post_norm * pre_treat_cba
gen conn_pre_X_precba = totaltreat_pw_norm * pre_treat_cba

* ===================
* OLS with post-treatment connectivity
* ===================

di as text "  OLS (post-treatment connectivity)..."

* Post-treatment OLS
reghdfe numb_clauses c.totaltreat_pw_post_norm##i.post_treat_cba if `s_spill' & !missing(cba_period), ///
    absorb(`base_fe_cba' `flow_control_cba' ib0.numb_clauses_pre`g'#i.cba_period) ///
    cluster(identificad)

local b_post_ols = _b[1.post_treat_cba#c.totaltreat_pw_post_norm]
local se_post_ols = _se[1.post_treat_cba#c.totaltreat_pw_post_norm]
local p_post_ols = 2*ttail(e(df_r), abs(`b_post_ols'/`se_post_ols'))
local n_obs_ols = e(N)
local n_estab_ols = e(N_clust)

* Pre-treatment OLS
reghdfe numb_clauses c.totaltreat_pw_post_norm##i.pre_treat_cba if `s_spill' & !missing(cba_period) & cba_period<=2, ///
    absorb(`base_fe_cba' `flow_control_cba' ib0.numb_clauses_pre`g'#i.cba_period) ///
    cluster(identificad)

local b_pre_ols = _b[1.pre_treat_cba#c.totaltreat_pw_post_norm]
local se_pre_ols = _se[1.pre_treat_cba#c.totaltreat_pw_post_norm]
local p_pre_ols = 2*ttail(e(df_r), abs(`b_pre_ols'/`se_pre_ols'))

* Stars for OLS
local stars_post_ols ""
if `p_post_ols' < 0.01 local stars_post_ols "***"
else if `p_post_ols' < 0.05 local stars_post_ols "**"
else if `p_post_ols' < 0.10 local stars_post_ols "*"

local stars_pre_ols ""
if `p_pre_ols' < 0.01 local stars_pre_ols "***"
else if `p_pre_ols' < 0.05 local stars_pre_ols "**"
else if `p_pre_ols' < 0.10 local stars_pre_ols "*"

* Write OLS results to CSV
tempname fh
file open `fh' using "$tables/results_iv_spillover.csv", write append
file write `fh' `"numb_clauses_ols;main;"' %9.4f (`b_post_ols') `"`stars_post_ols'"' _n
file write `fh' `"numb_clauses_ols;main_se;"' %9.4f (`se_post_ols') _n
file write `fh' `"numb_clauses_ols;pre;"' %9.4f (`b_pre_ols') `"`stars_pre_ols'"' _n
file write `fh' `"numb_clauses_ols;pre_se;"' %9.4f (`se_pre_ols') _n
file write `fh' `"numb_clauses_ols;n_obs;"' %12.0f (`n_obs_ols') _n
file write `fh' `"numb_clauses_ols;n_estab;"' %12.0f (`n_estab_ols') _n
file close `fh'

di as result "    Post × Connectivity (OLS): " %9.4f `b_post_ols' " `stars_post_ols'"
di as result "    Pre-treatment (OLS):       " %9.4f `b_pre_ols' " `stars_pre_ols'"

* ===================
* IV regression
* ===================

di as text "  IV (post instrumented by pre)..."

* Post-treatment IV
ivreghdfe numb_clauses (conn_post_X_postcba = conn_pre_X_postcba) if `s_spill' & !missing(cba_period), ///
    absorb(`base_fe_cba' `flow_control_cba' ib0.numb_clauses_pre`g'#i.cba_period) ///
    cluster(identificad)

local b_post_iv = _b[conn_post_X_postcba]
local se_post_iv = _se[conn_post_X_postcba]
local p_post_iv = 2*ttail(e(df_r), abs(`b_post_iv'/`se_post_iv'))
local n_obs_iv = e(N)
local n_estab_iv = e(N_clust)

* Pre-treatment IV
ivreghdfe numb_clauses (conn_post_X_precba = conn_pre_X_precba) if `s_spill' & !missing(cba_period) & cba_period<=2, ///
    absorb(`base_fe_cba' `flow_control_cba' ib0.numb_clauses_pre`g'#i.cba_period) ///
    cluster(identificad)

local b_pre_iv = _b[conn_post_X_precba]
local se_pre_iv = _se[conn_post_X_precba]
local p_pre_iv = 2*ttail(e(df_r), abs(`b_pre_iv'/`se_pre_iv'))

* Stars for IV
local stars_post_iv ""
if `p_post_iv' < 0.01 local stars_post_iv "***"
else if `p_post_iv' < 0.05 local stars_post_iv "**"
else if `p_post_iv' < 0.10 local stars_post_iv "*"

local stars_pre_iv ""
if `p_pre_iv' < 0.01 local stars_pre_iv "***"
else if `p_pre_iv' < 0.05 local stars_pre_iv "**"
else if `p_pre_iv' < 0.10 local stars_pre_iv "*"

* Write IV results to CSV
tempname fh
file open `fh' using "$tables/results_iv_spillover.csv", write append
file write `fh' `"numb_clauses_iv;main;"' %9.4f (`b_post_iv') `"`stars_post_iv'"' _n
file write `fh' `"numb_clauses_iv;main_se;"' %9.4f (`se_post_iv') _n
file write `fh' `"numb_clauses_iv;pre;"' %9.4f (`b_pre_iv') `"`stars_pre_iv'"' _n
file write `fh' `"numb_clauses_iv;pre_se;"' %9.4f (`se_pre_iv') _n
file write `fh' `"numb_clauses_iv;n_obs;"' %12.0f (`n_obs_iv') _n
file write `fh' `"numb_clauses_iv;n_estab;"' %12.0f (`n_estab_iv') _n
file close `fh'

di as result "    Post × Connectivity (IV):  " %9.4f `b_post_iv' " `stars_post_iv'"
di as result "    Pre-treatment (IV):        " %9.4f `b_pre_iv' " `stars_pre_iv'"


********************************************************************************
* IV EVENT STUDY FIGURE - lr_remdezr_w
********************************************************************************

di _newline(2)
di as result "{hline 60}"
di as result "IV EVENT STUDY"
di as result "{hline 60}"

local outcome "lr_remdezr_w"

* Run IV event study regression (2011 omitted as base year)
ivreghdfe `outcome' ///
    (conn_post_2009 conn_post_2010 conn_post_2012 conn_post_2013 ///
     conn_post_2014 conn_post_2015 conn_post_2016 = ///
     conn_pre_2009 conn_pre_2010 conn_pre_2012 conn_pre_2013 ///
     conn_pre_2014 conn_pre_2015 conn_pre_2016) ///
    if `s_spill', ///
    absorb(`base_fe' `flow_control_post' ib0.`outcome'_pre`g'#i.year) ///
    cluster(identificad)

estimates store iv_es

* Calculate pre-trend test (joint test of 2009 and 2010 coefficients)
test conn_post_2009 conn_post_2010
local pre_pval = r(p)

* Get post-period average coefficient (2012-2016)
lincom (conn_post_2012 + conn_post_2013 + conn_post_2014 + conn_post_2015 + conn_post_2016)/5
local post_coef = r(estimate)
local post_se = r(se)

local post_coef_str = string(`post_coef', "%9.4f")
local post_se_str = string(`post_se', "%9.4f")
local pre_pval_str = string(`pre_pval', "%9.3f")

di as text "Pre-trend p-value (joint test 2009-2010): `pre_pval_str'"
di as text "Average post coefficient (2012-2016): `post_coef_str' (`post_se_str')"

* Create coefficient plot
coefplot iv_es, ///
    keep(conn_post_2009 conn_post_2010 conn_post_2012 conn_post_2013 ///
         conn_post_2014 conn_post_2015 conn_post_2016) ///
    coeflabels(conn_post_2009 = "2009" ///
               conn_post_2010 = "2010" ///
               conn_post_2012 = "2012" ///
               conn_post_2013 = "2013" ///
               conn_post_2014 = "2014" ///
               conn_post_2015 = "2015" ///
               conn_post_2016 = "2016") ///
    vert omitted baselevels ///
    yline(0, lcolor(gs10)) ///
    xline(2.5, lpattern(dash) lcolor(gs8)) ///
    ytitle("IV Estimates: Dynamic DiD Coefficients", size(small)) ///
    xtitle("Year", size(small)) ///
    note("Pre-trend p-value = `pre_pval_str'", size(small)) ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) lcolor(navy)) ///
    mcolor(navy) msymbol(diamond) ///
	text(0.05 5.5 "0.0190 (0.0090)", color(navy) size(small))

graph export "$graphs/fig_iv_eventstudy_lr_remdezr_w.pdf", replace

estimates drop iv_es

di _newline(1)
di as result "Event study figure saved to: $graphs/fig_iv_eventstudy_lr_remdezr_w.pdf"

********************************************************************************
* STEP 6: SUMMARY OUTPUT
********************************************************************************

di _newline(2)
di as result "{hline 60}"
di as result "OLS AND IV ESTIMATION COMPLETE"
di as result "{hline 60}"
di as text "Main results saved to: $tables/results_iv_spillover.csv"
di as text "First stage saved to: $tables/results_iv_firststage.csv"
di as result "{hline 60}"
