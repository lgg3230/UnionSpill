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
global alpha = 0.05

* Sample definitions
local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"
local s_direct "(lagos_sample_avg==1 & treat_ultra==0 & totaltreat_pw_n<=0.01 | lagos_sample_avg==1 & treat_ultra==1) & in_balanced_panel==1"

keep if year>=2009
keep if lagos_sample_avg==1

di as result "Sample size: " _N

* ===============================
* SPECIFICATIONS TO LOOP OVER
* ===============================
* Each specification will generate a complete set of results

* Perfect validation (4/4 tests passed)
global specs_perfect "TFPE_BIN_5 TFPE_BIN_10 TFPE_BIN_4 TFPE_BIN_20"

* Strong performance (3/4 tests passed, only Dec wages marginally missed)
global specs_robust "TFPE_LIN_YR TF_LIN_YR EMP_BIN_4 EMP_BIN_5 EMP_LIN_YR TF_BIN_4 TF_BIN_5"

* Combined list
global specs "$specs_perfect $specs_robust"

di _newline(2)
di as result "{hline 80}"
di as result "SPECIFICATIONS TO ESTIMATE"
di as result "{hline 80}"
di as text "Perfect validation (4/4 tests):"
foreach spec of global specs_perfect {
    di as text "  ✓✓✓ `spec'"
}
di _newline(1)
di as text "Strong performance (3/4 tests):"
foreach spec of global specs_robust {
    di as text "  ✓✓ `spec'"
}
di as result "{hline 80}"
di as text "Total specifications: " `: word count $specs'

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
cap drop placebo_pre 
cap drop placebo_year 
cap drop treat_year
gen byte placebo_pre = (year==2011)
gen byte placebo_year = (year<2011)
gen byte treat_year = (year>=2012)

label var placebo_pre "Placebo post (2011 vs 2009-2010)"
label var placebo_year "Pre-treatment period"
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

gen pre_treat_cba = cond(cba_period<2,1,0)
gen post_treat_cba = cond(cba_period>=3,1,0) if !missing(cba_period)

* Normalized connectivity
cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
quietly sum totaltreat_pw_n if `s_spill' & year==2009, detail
gen totaltreat_pw_n_p90 = r(p90)
gen totaltreat_pw_norm = (totaltreat_pw_n / totaltreat_pw_n_p90)

* Pre-treatment firm characteristics
cap drop firm_emp_pre_o
cap drop firm_emp_pre
quietly {
    bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year,2009,2011)
    bys identificad: egen firm_emp_pre = min(firm_emp_pre_o)
    drop firm_emp_pre_o
}

cap drop tf_per_emp_pre
gen double tf_per_emp_pre = totalflows_n / firm_emp_pre if firm_emp_pre>0

* Log employment
cap drop l_firm_emp
gen double l_firm_emp = ln(firm_emp)

* Pre-treatment outcome averages
foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {
    cap drop `outcome'_pre_o `outcome'_pre
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
        cap drop `wage'_`pct'_pre_o `wage'_`pct'_pre
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
    cap drop `wage'_p90p10 `wage'_p80p20 `wage'_p75p25
    gen double `wage'_p90p10 = `wage'_p90 - `wage'_p10
    gen double `wage'_p80p20 = `wage'_p80 - `wage'_p20
    gen double `wage'_p75p25 = `wage'_p75 - `wage'_p25
    
    * p90/p50, p80/p50, p75/p50
    cap drop `wage'_p90p50 `wage'_p80p50 `wage'_p75p50
    gen double `wage'_p90p50 = `wage'_p90 - `wage'_p50
    gen double `wage'_p80p50 = `wage'_p80 - `wage'_p50
    gen double `wage'_p75p50 = `wage'_p75 - `wage'_p50
    
    * Pre-treatment averages for ratios
    foreach ratio in p90p10 p80p20 p75p25 p90p50 p80p50 p75p50 {
        cap drop `wage'_`ratio'_pre_o `wage'_`ratio'_pre
        quietly {
            bys identificad: egen `wage'_`ratio'_pre_o = mean(`wage'_`ratio') if inrange(year, 2009, 2011)
            bys identificad: egen `wage'_`ratio'_pre = min(`wage'_`ratio'_pre_o)
            drop `wage'_`ratio'_pre_o
        }
    }
}

* Create control bins
local glist "4 5 10 20"

foreach g of local glist {
    cap drop totalflows_n`g'_o totalflows_n`g'
    quietly {
        egen totalflows_n`g'_o = cut(totalflows_n) if year==2009 & in_balanced_panel==1, group(`g')
        bys identificad: egen totalflows_n`g' = min(totalflows_n`g'_o)
        drop totalflows_n`g'_o
    }
}

foreach g of local glist {
    cap drop firm_emp_pre`g'_o firm_emp_pre`g'
    quietly {
        egen firm_emp_pre`g'_o = cut(firm_emp_pre) if year==2009 & in_balanced_panel==1, group(`g')
        bys identificad: egen firm_emp_pre`g' = min(firm_emp_pre`g'_o)
        drop firm_emp_pre`g'_o
    }
}

foreach g of local glist {
    cap drop tf_per_emp_pre`g'_o tf_per_emp_pre`g'
    quietly {
        egen tf_per_emp_pre`g'_o = cut(tf_per_emp_pre) if year==2009 & in_balanced_panel==1, group(`g')
        bys identificad: egen tf_per_emp_pre`g' = min(tf_per_emp_pre`g'_o)
        drop tf_per_emp_pre`g'_o
    }
}

di as result "✓ All variables created"

********************************************************************************
* SECTION 2: DEFINE HELPER PROGRAM FOR EXPORTING RESULTS
********************************************************************************

capture program drop export_results
program define export_results
    syntax, spec(string) section(string) outcome(string) ///
        b_post(real) se_post(real) p_post(real) ///
        b_pre(real) se_pre(real) p_pre(real) ///
        n_obs(real) n_estab(real)
    
    * Create significance stars
    local stars_post ""
    if `p_post' < 0.01 local stars_post "***"
    else if `p_post' < 0.05 local stars_post "**"
    else if `p_post' < 0.10 local stars_post "*"
    
    local stars_pre ""
    if `p_pre' < 0.01 local stars_pre "***"
    else if `p_pre' < 0.05 local stars_pre "**"
    else if `p_pre' < 0.10 local stars_pre "*"
    
    * Format coefficient with stars
    local b_post_str = string(`b_post', "%9.4f") + "`stars_post'"
    local b_pre_str = string(`b_pre', "%9.4f") + "`stars_pre'"
    
    * Open file (append mode)
    tempname fh
    file open `fh' using "$results/results_`section'_`spec'.csv", write append
    
    * Write rows
    file write `fh' `""`spec'","`section'","`outcome'","main","`b_post_str'""' _n
    file write `fh' `""`spec'","`section'","`outcome'","main_se","' %9.4f (`se_post') `"""' _n
    file write `fh' `""`spec'","`section'","`outcome'","pre","`b_pre_str'""' _n
    file write `fh' `""`spec'","`section'","`outcome'","pre_se","' %9.4f (`se_pre') `"""' _n
    file write `fh' `""`spec'","`section'","`outcome'","n_obs","' %12.0f (`n_obs') `"""' _n
    file write `fh' `""`spec'","`section'","`outcome'","n_estab","' %12.0f (`n_estab') `"""' _n
    
    file close `fh'
end

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
    if regexm("`spec'", "^TFPE_BIN_([0-9]+)$") {
        local g = regexs(1)
        local flow_control "ib0.tf_per_emp_pre`g'"
        local flow_control_year "ib0.tf_per_emp_pre`g'#i.year"
        local flow_control_cba "ib0.tf_per_emp_pre`g'#i.cba_period"
    }
    else if regexm("`spec'", "^TF_BIN_([0-9]+)$") {
        local g = regexs(1)
        local flow_control "ib0.totalflows_n`g'"
        local flow_control_year "ib0.totalflows_n`g'#i.year"
        local flow_control_cba "ib0.totalflows_n`g'#i.cba_period"
    }
    else if regexm("`spec'", "^EMP_BIN_([0-9]+)$") {
        local g = regexs(1)
        local flow_control "ib0.firm_emp_pre`g'"
        local flow_control_year "ib0.firm_emp_pre`g'#i.year"
        local flow_control_cba "ib0.firm_emp_pre`g'#i.cba_period"
    }
    else if "`spec'" == "TF_LIN_YR" {
        local flow_control "c.totalflows_n"
        local flow_control_year "c.totalflows_n#i.year"
        local flow_control_cba "c.totalflows_n#i.cba_period"
    }
    else if "`spec'" == "EMP_LIN_YR" {
        local flow_control "c.firm_emp_pre"
        local flow_control_year "c.firm_emp_pre#i.year"
        local flow_control_cba "c.firm_emp_pre#i.cba_period"
    }
    else if "`spec'" == "TFPE_LIN_YR" {
        local flow_control "c.tf_per_emp_pre"
        local flow_control_year "c.tf_per_emp_pre#i.year"
        local flow_control_cba "c.tf_per_emp_pre#i.cba_period"
    }
    
    * ===========================
    * INITIALIZE OUTPUT FILES
    * ===========================
    
    * Create header for direct effects file
    capture erase "$results/results_direct_`spec'.csv"
    tempname fh
    file open `fh' using "$results/results_direct_`spec'.csv", write replace
    file write `fh' "spec,section,outcome,row_type,value" _n
    file close `fh'
    
    * Create header for spillover effects file
    capture erase "$results/results_spill_`spec'.csv"
    file open `fh' using "$results/results_spill_`spec'.csv", write replace
    file write `fh' "spec,section,outcome,row_type,value" _n
    file close `fh'
    
    * ===========================
    * PART A: DIRECT EFFECTS
    * ===========================
    
    di _newline(2)
    di as result "───────────────────────────────────────────────────────────────────────────"
    di as result "DIRECT EFFECTS"
    di as result "───────────────────────────────────────────────────────────────────────────"
    
    * Loop over main outcomes (excluding numb_clauses for now)
    foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {
        
        di _newline(1)
        di as text "Estimating: `outcome'"
        
        * Base FE
        local base_fe "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year c.`outcome'_pre#i.year"
        
        * Post-treatment regression
        quietly reghdfe `outcome' treat_ultra##i.treat_year if `s_direct', ///
            absorb(`base_fe' `flow_control_year') vce(cluster identificad)
        
        local b_post = _b[1.treat_ultra#1.treat_year]
        local se_post = _se[1.treat_ultra#1.treat_year]
        local p_post = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
        local n_obs = e(N)
        local n_estab = e(N_clust)
        
        * Pre-treatment regression (placebo test)
        quietly reghdfe `outcome' treat_ultra##i.placebo_year if `s_direct' & year<=2011, ///
            absorb(`base_fe' `flow_control_year') vce(cluster identificad)
        
        local b_pre = _b[1.treat_ultra#1.placebo_year]
        local se_pre = _se[1.treat_ultra#1.placebo_year]
        local p_pre = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))
        
        * Export results
        export_results, spec(`spec') section(direct) outcome(`outcome') ///
            b_post(`b_post') se_post(`se_post') p_post(`p_post') ///
            b_pre(`b_pre') se_pre(`se_pre') p_pre(`p_pre') ///
            n_obs(`n_obs') n_estab(`n_estab')
        
        * Event study for plot
        quietly reghdfe `outcome' i.treat_ultra##ib2011.year if `s_direct', ///
            absorb(`base_fe' `flow_control_year') vce(cluster identificad)
        
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
        
        estimates drop es_direct_`outcome'
    }
    
    * Special handling for numb_clauses (CBA periods)
    capture confirm variable numb_clauses
    if _rc == 0 {
        
        di _newline(1)
        di as text "Estimating: numb_clauses (CBA periods)"
        
        local base_fe_cba "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period c.numb_clauses_pre#i.cba_period"
        
        * Post-treatment
        quietly reghdfe numb_clauses i.treat_ultra##post_treat_cba if `s_direct' & !missing(cba_period), ///
            absorb(`base_fe_cba' `flow_control_cba') vce(cluster identificad)
        
        local b_post = _b[1.treat_ultra#1.post_treat_cba]
        local se_post = _se[1.treat_ultra#1.post_treat_cba]
        local p_post = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
        local n_obs = e(N)
        local n_estab = e(N_clust)
        
        * Pre-treatment
        quietly reghdfe numb_clauses i.treat_ultra##pre_treat_cba if `s_direct' & !missing(cba_period) & cba_period<=2, ///
            absorb(`base_fe_cba' `flow_control_cba') vce(cluster identificad)
        
        local b_pre = _b[1.treat_ultra#1.pre_treat_cba]
        local se_pre = _se[1.treat_ultra#1.pre_treat_cba]
        local p_pre = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))
        
        * Export
        export_results, spec(`spec') section(direct) outcome(numb_clauses) ///
            b_post(`b_post') se_post(`se_post') p_post(`p_post') ///
            b_pre(`b_pre') se_pre(`se_pre') p_pre(`p_pre') ///
            n_obs(`n_obs') n_estab(`n_estab')
        
        * Event study
        quietly reghdfe numb_clauses i.treat_ultra##ib2.cba_period if `s_direct' & !missing(cba_period), ///
            absorb(`base_fe_cba' `flow_control_cba') vce(cluster identificad)
        
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
        
        estimates drop es_clauses
    }
    
    * Percentile outcomes - direct effects (numeric results only, no plots)
    di _newline(1)
    di as text "Estimating: Percentile outcomes (direct) - numeric results only"
    
    foreach outcome in $pct_outcomes_dec $pct_outcomes_hour {
        
        quietly {
            local base_fe "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year c.`outcome'_pre#i.year"
            
            reghdfe `outcome' treat_ultra##i.treat_year if `s_direct', ///
                absorb(`base_fe' `flow_control_year') vce(cluster identificad)
            
            local b_post = _b[1.treat_ultra#1.treat_year]
            local se_post = _se[1.treat_ultra#1.treat_year]
            local p_post = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
            local n_obs = e(N)
            local n_estab = e(N_clust)
            
            reghdfe `outcome' treat_ultra##i.placebo_year if `s_direct' & year<=2011, ///
                absorb(`base_fe' `flow_control_year') vce(cluster identificad)
            
            local b_pre = _b[1.treat_ultra#1.placebo_year]
            local se_pre = _se[1.treat_ultra#1.placebo_year]
            local p_pre = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))
            
            export_results, spec(`spec') section(direct) outcome(`outcome') ///
                b_post(`b_post') se_post(`se_post') p_post(`p_post') ///
                b_pre(`b_pre') se_pre(`se_pre') p_pre(`p_pre') ///
                n_obs(`n_obs') n_estab(`n_estab')
        }
    }
    
    * Ratio outcomes - direct effects (numeric results only, no plots)
    di as text "Estimating: Ratio outcomes (direct) - numeric results only"
    
    foreach outcome in $ratio_outcomes_dec $ratio_outcomes_hour {
        
        quietly {
            local base_fe "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year c.`outcome'_pre#i.year"
            
            reghdfe `outcome' treat_ultra##i.treat_year if `s_direct', ///
                absorb(`base_fe' `flow_control_year') vce(cluster identificad)
            
            local b_post = _b[1.treat_ultra#1.treat_year]
            local se_post = _se[1.treat_ultra#1.treat_year]
            local p_post = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
            local n_obs = e(N)
            local n_estab = e(N_clust)
            
            reghdfe `outcome' treat_ultra##i.placebo_year if `s_direct' & year<=2011, ///
                absorb(`base_fe' `flow_control_year') vce(cluster identificad)
            
            local b_pre = _b[1.treat_ultra#1.placebo_year]
            local se_pre = _se[1.treat_ultra#1.placebo_year]
            local p_pre = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))
            
            export_results, spec(`spec') section(direct) outcome(`outcome') ///
                b_post(`b_post') se_post(`se_post') p_post(`p_post') ///
                b_pre(`b_pre') se_pre(`se_pre') p_pre(`p_pre') ///
                n_obs(`n_obs') n_estab(`n_estab')
        }
    }
    
    * ===========================
    * PART B: SPILLOVER EFFECTS
    * ===========================
    
    di _newline(2)
    di as result "───────────────────────────────────────────────────────────────────────────"
    di as result "SPILLOVER EFFECTS"
    di as result "───────────────────────────────────────────────────────────────────────────"
    
    * Loop over main outcomes (excluding numb_clauses)
    foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {
        
        di _newline(1)
        di as text "Estimating: `outcome' (spillover)"
        
        local base_fe "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year c.`outcome'_pre#i.year"
        
        * Post-treatment
        quietly reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
            absorb(`base_fe' `flow_control_year') vce(cluster identificad)
        
        local b_post = _b[1.treat_year#c.`conn']
        local se_post = _se[1.treat_year#c.`conn']
        local p_post = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
        local n_obs = e(N)
        local n_estab = e(N_clust)
        
        * Pre-treatment
        quietly reghdfe `outcome' c.`conn'##i.placebo_year if `s_spill' & year<=2011, ///
            absorb(`base_fe' `flow_control_year') vce(cluster identificad)
        
        local b_pre = _b[1.placebo_year#c.`conn']
        local se_pre = _se[1.placebo_year#c.`conn']
        local p_pre = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))
        
        * Export
        export_results, spec(`spec') section(spill) outcome(`outcome') ///
            b_post(`b_post') se_post(`se_post') p_post(`p_post') ///
            b_pre(`b_pre') se_pre(`se_pre') p_pre(`p_pre') ///
            n_obs(`n_obs') n_estab(`n_estab')
        
        * Event study
        quietly reghdfe `outcome' c.`conn'##ib2011.year if `s_spill', ///
            absorb(`base_fe' `flow_control_year') vce(cluster identificad)
        
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
        
        local base_fe_cba "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period c.numb_clauses_pre#i.cba_period"
        
        * Post-treatment
        quietly reghdfe numb_clauses c.`conn'##post_treat_cba if `s_spill' & !missing(cba_period), ///
            absorb(`base_fe_cba' `flow_control_cba') vce(cluster identificad)
        
        local b_post = _b[1.post_treat_cba#c.`conn']
        local se_post = _se[1.post_treat_cba#c.`conn']
        local p_post = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
        local n_obs = e(N)
        local n_estab = e(N_clust)
        
        * Pre-treatment
        quietly reghdfe numb_clauses c.`conn'##pre_treat_cba if `s_spill' & !missing(cba_period) & cba_period<=2, ///
            absorb(`base_fe_cba' `flow_control_cba') vce(cluster identificad)
        
        local b_pre = _b[1.pre_treat_cba#c.`conn']
        local se_pre = _se[1.pre_treat_cba#c.`conn']
        local p_pre = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))
        
        * Export
        export_results, spec(`spec') section(spill) outcome(numb_clauses) ///
            b_post(`b_post') se_post(`se_post') p_post(`p_post') ///
            b_pre(`b_pre') se_pre(`se_pre') p_pre(`p_pre') ///
            n_obs(`n_obs') n_estab(`n_estab')
        
        * Event study
        quietly reghdfe numb_clauses c.`conn'##ib2.cba_period if `s_spill' & !missing(cba_period), ///
            absorb(`base_fe_cba' `flow_control_cba') vce(cluster identificad)
        
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
        
        quietly {
            local base_fe "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year c.`outcome'_pre#i.year"
            
            reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
                absorb(`base_fe' `flow_control_year') vce(cluster identificad)
            
            local b_post = _b[1.treat_year#c.`conn']
            local se_post = _se[1.treat_year#c.`conn']
            local p_post = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
            local n_obs = e(N)
            local n_estab = e(N_clust)
            
            reghdfe `outcome' c.`conn'##i.placebo_year if `s_spill' & year<=2011, ///
                absorb(`base_fe' `flow_control_year') vce(cluster identificad)
            
            local b_pre = _b[1.placebo_year#c.`conn']
            local se_pre = _se[1.placebo_year#c.`conn']
            local p_pre = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))
            
            export_results, spec(`spec') section(spill) outcome(`outcome') ///
                b_post(`b_post') se_post(`se_post') p_post(`p_post') ///
                b_pre(`b_pre') se_pre(`se_pre') p_pre(`p_pre') ///
                n_obs(`n_obs') n_estab(`n_estab')
        }
    }
    
    * Ratio outcomes - spillover (numeric results only, no plots)
    di as text "Estimating: Ratio outcomes (spillover) - numeric results only"
    
    foreach outcome in $ratio_outcomes_dec $ratio_outcomes_hour {
        
        quietly {
            local base_fe "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year c.`outcome'_pre#i.year"
            
            reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
                absorb(`base_fe' `flow_control_year') vce(cluster identificad)
            
            local b_post = _b[1.treat_year#c.`conn']
            local se_post = _se[1.treat_year#c.`conn']
            local p_post = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
            local n_obs = e(N)
            local n_estab = e(N_clust)
            
            reghdfe `outcome' c.`conn'##i.placebo_year if `s_spill' & year<=2011, ///
                absorb(`base_fe' `flow_control_year') vce(cluster identificad)
            
            local b_pre = _b[1.placebo_year#c.`conn']
            local se_pre = _se[1.placebo_year#c.`conn']
            local p_pre = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))
            
            export_results, spec(`spec') section(spill) outcome(`outcome') ///
                b_post(`b_post') se_post(`se_post') p_post(`p_post') ///
                b_pre(`b_pre') se_pre(`se_pre') p_pre(`p_pre') ///
                n_obs(`n_obs') n_estab(`n_estab')
        }
    }
    
    di _newline(1)
    di as result "✓ Specification `spec' complete"
}

********************************************************************************
* SECTION 4: COMPLETION
********************************************************************************

di _newline(3)
di as result "{hline 80}"
di as result "ESTIMATION COMPLETE"
di as result "{hline 80}"
di as result "Output files created:"
di as text "  • Results CSVs: $results/results_[direct|spill]_[spec].csv"
di as text "    (11 specs × 2 sections = 22 files)"
di as text "  • Event study PDFs: $graphs/es_[direct|spill]_[outcome]_[spec].pdf"
di as text "    (11 specs × 8 plots each = 88 PDF files)"
di _newline(1)
di as text "Plots per specification:"
di as text "  • Direct effects: 4 main outcomes (lr_remdezr_w, lr_remdezr_h_w, l_firm_emp, numb_clauses)"
di as text "  • Spillover effects: 4 main outcomes"
di as text "  • Total: 8 event study plots per spec"
di _newline(1)
di as text "Numeric results exported for:"
di as text "  • Main outcomes: 4"
di as text "  • Percentiles: 14 (7 Dec + 7 Hourly)"
di as text "  • Ratios: 12 (6 Dec + 6 Hourly)"
di as text "  • Total: 30 outcomes per spec × 11 specs = 330 outcome estimates"
di as result "{hline 80}"

log close
di as result "Finished: `c(current_date)' `c(current_time)'"

********************************************************************************
* END OF DO-FILE
********************************************************************************
