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

drop _merge

merge m:1 identificad using  "/Users/luisg/Downloads/connectivity_post_treat_agg.dta"
keep if _merge==3


* ===============================
* GLOBAL SETTINGS
* ===============================
local conn "totaltreat_pw_norm"
global alpha = 0.05

* Sample definitions
local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"
local s_direct "(lagos_sample_avg==1 & treat_ultra==0  & totaltreat_pw_n==0| lagos_sample_avg==1 & treat_ultra==1) & in_balanced_panel==1"

keep if year>=2009
keep if lagos_sample_avg==1

di as result "Sample size: " _N

reg totaltreat_pw_post totaltreat_pw_n if `s_spill' & year==2009, rob

* ===============================
* SPECIFICATIONS TO LOOP OVER
* ===============================
* Each specification will generate a complete set of results

* Only lagos controls
global specs_lagos "4tf_out_alldir_0conn "

* Perfect validation (4/4 tests passed)
global specs_perfect "TFPE_BIN_5 TFPE_BIN_10 TFPE_BIN_4 TFPE_BIN_20"

* Strong performance (3/4 tests passed, only Dec wages marginally missed)
global specs_robust "TFPE_LIN_YR TF_LIN_YR EMP_BIN_4 EMP_BIN_5 EMP_LIN_YR TF_BIN_4 TF_BIN_5"

* Combined list
global specs "$specs_lagos "

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

global ratio_outcomes_dec "lr_remdezr_w_p90p10 lr_remdezr_w_p80p20 lr_remdezr_w_p75p25 lr_remdezr_w_p90p50 lr_remdezr_w_p80p50 lr_remdezr_w_p75p50 lr_remdezr_w_p50p10"

global ratio_outcomes_hour "lr_remdezr_h_w_p90p10 lr_remdezr_h_w_p80p20 lr_remdezr_h_w_p75p25 lr_remdezr_h_w_p90p50 lr_remdezr_h_w_p80p50 lr_remdezr_h_w_p75p50 lr_remdezr_h_w_p50p10"

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

cap drop turnover_pre
cap drop turnover_pre_o
bys identificad: egen turnover_pre_o = mean(turnover) if inrange(year, 2009, 2011)
       bys identificad: egen turnover_pre = min(turnover_pre_o)
        drop turnover_pre_o



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
    
    * p90/p50, p80/p50, p75/p50, p50/p10
    cap drop `wage'_p90p50 `wage'_p80p50 `wage'_p75p50 `wage'_p50p10
    gen double `wage'_p90p50 = `wage'_p90 - `wage'_p50
    gen double `wage'_p80p50 = `wage'_p80 - `wage'_p50
    gen double `wage'_p75p50 = `wage'_p75 - `wage'_p50
    gen double `wage'_p50p10 = `wage'_p50 - `wage'_p10
    
    * Pre-treatment averages for ratios
    foreach ratio in p90p10 p80p20 p75p25 p90p50 p80p50 p75p50 p50p10 {
        cap drop `wage'_`ratio'_pre_o `wage'_`ratio'_pre
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
	foreach wage in lr_remdezr_w lr_remdezr_h_w l_firm_emp numb_clauses lr_remdezr_w_p10 lr_remdezr_w_p20 lr_remdezr_w_p25 lr_remdezr_w_p50 lr_remdezr_w_p75 lr_remdezr_w_p80 lr_remdezr_w_p90 lr_remdezr_h_w_p10 lr_remdezr_h_w_p20 lr_remdezr_h_w_p25 lr_remdezr_h_w_p50 lr_remdezr_h_w_p75 lr_remdezr_h_w_p80 lr_remdezr_h_w_p90 lr_remdezr_w_p90p10 lr_remdezr_w_p80p20 lr_remdezr_w_p75p25 lr_remdezr_w_p90p50 lr_remdezr_w_p80p50 lr_remdezr_w_p75p50 lr_remdezr_w_p50p10 lr_remdezr_h_w_p90p10 lr_remdezr_h_w_p80p20 lr_remdezr_h_w_p75p25 lr_remdezr_h_w_p90p50 lr_remdezr_h_w_p80p50 lr_remdezr_h_w_p75p50 lr_remdezr_h_w_p50p10 {
		cap drop `wage'_pre`g'
		quietly{
			egen `wage'_pre`g'_o = cut(`wage'_pre) if year ==2009 & in_balanced_panel==1, group(`g')
//			 i use cut(wage_pre) here because it refers to groups of the pretreatment average of outcomes
			bys identificad: egen `wage'_pre`g' = min(`wage'_pre`g'_o)
			drop `wage'_pre`g'_o
		}
	}
}
di as result "✓ All variables created"


********************************************************************************
* DESCRIPTIVE STATISTICS TABLE
********************************************************************************

* ===============================
* SETUP
* ===============================

* Define group conditions (all include year==2009 restriction in the loop)
local g1_name "Overall"
local g1_cond "lagos_sample_avg==1 & in_balanced_panel==1"

local g2_name "Treated"
local g2_cond "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==1"

local g3_name "Untreated"
local g3_cond "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0"

local g4_name "Untreated_Conn"
local g4_cond "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & totaltreat_pw_n>0"

local g5_name "Untreated_Zero"
local g5_cond "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & totaltreat_pw_n==0"

* Create output file
capture erase "$tables/descriptive_stats.csv"
tempname fh
file open `fh' using "$tables/descriptive_stats.csv", write replace
file write `fh' "statistic;Overall;Treated;Untreated;Untreated_Conn;Untreated_Zero" _n
file close `fh'

* ===============================
* COMPUTE STATISTICS
* ===============================

* Initialize locals to store results
foreach stat in n_estab n_workers prop_treated mean_emp mean_wage mean_med_wage med_wage ///
                mean_clauses prop_hs prop_sup prop_female prop_nonwhite ///
                mean_flows med_flows mean_churn mean_tn mean_p90p10 mean_p80p20 mean_p75p25 mean_p50p10 mean_p90p50 {
    forvalues g = 1/5 {
        local `stat'_g`g' = .
    }
}

* Loop over groups
forvalues g = 1/5 {
    
    di _newline(1)
    di as result "{hline 50}"
    di as result "Group `g': `g`g'_name'"
    di as result "{hline 50}"
    
    local cond "`g`g'_cond'"
    
    * --------------------------
    * 1. Number of establishments
    * --------------------------
    count if `cond' & year==2009
    local n_estab_g`g' = r(N)
    di as text "N establishments: " %12.0fc `n_estab_g`g''
    
    * --------------------------
    * 2. Total number of workers
    * --------------------------
    sum firm_emp if `cond' & year==2009, meanonly
    local n_workers_g`g' = r(sum)
    di as text "Total workers: " %12.0fc `n_workers_g`g''
    
	* --------------------------
    * 3. Proportion treated
    * --------------------------
    sum treat_ultra if `cond' & year==2009
    local prop_treated_g`g' = r(mean)
    di as text "Prop treated: " %9.4f `prop_treated_g`g''
	
    * --------------------------
    * 3. Average establishment size
    * --------------------------
    sum firm_emp if `cond' & year==2009
    local mean_emp_g`g' = r(mean)
    di as text "Mean estab size: " %9.2f `mean_emp_g`g''
    
    * --------------------------
    * 4. Average december wages
    * --------------------------
    sum r_remdezr if `cond' & year==2009
    local mean_wage_g`g' = r(mean)
    di as text "Mean dec wages: " %9.2f `mean_wage_g`g''
    
    * --------------------------
    * 5. Average of within-firm median wages
    * --------------------------
    * Create temp variable for exp(lr_remdezr_w_p50)
    cap drop temp_med_wage
    gen temp_med_wage = exp(lr_remdezr_w_p50)
    sum temp_med_wage if `cond' & year==2009
    local mean_med_wage_g`g' = r(mean)
    di as text "Mean of median wages: " %9.2f `mean_med_wage_g`g''
    drop temp_med_wage
    
    * --------------------------
    * 6. Median of within-firm average wages
    * --------------------------
    sum r_remdezr if `cond' & year==2009, detail
    local med_wage_g`g' = r(p50)
    di as text "Median of mean wages: " %9.2f `med_wage_g`g''
    
    * --------------------------
    * 7. Average numb_clauses (use cba_period==1)
    * --------------------------
    sum numb_clauses if `cond' & cba_period==1
    local mean_clauses_g`g' = r(mean)
    di as text "Mean clause count: " %9.2f `mean_clauses_g`g''
    
    * --------------------------
    * 8. Proportion high school
    * --------------------------
    sum prop_hs if `cond' & year==2009
    local prop_hs_g`g' = r(mean)
    di as text "Prop high school: " %9.4f `prop_hs_g`g''
    
    * --------------------------
    * 9. Proportion higher education
    * --------------------------
    sum prop_sup if `cond' & year==2009
    local prop_sup_g`g' = r(mean)
    di as text "Prop higher ed: " %9.4f `prop_sup_g`g''
    
    * --------------------------
    * 10. Proportion female
    * --------------------------
    cap drop temp_female
    gen temp_female = 1 - male_prop
    sum temp_female if `cond' & year==2009
    local prop_female_g`g' = r(mean)
    di as text "Prop female: " %9.4f `prop_female_g`g''
    drop temp_female
    
    * --------------------------
    * 11. Proportion non-white
    * --------------------------
    cap drop temp_nonwhite
    gen temp_nonwhite = 1 - white_prop
    sum temp_nonwhite if `cond' & year==2009
    local prop_nonwhite_g`g' = r(mean)
    di as text "Prop non-white: " %9.4f `prop_nonwhite_g`g''
    drop temp_nonwhite
    
    * --------------------------
    * 12. Mean and median totaltreat_pw_n
    * --------------------------
    sum totaltreat_pw_n if `cond' & year==2009, detail
    local mean_flows_g`g' = r(mean)
    local med_flows_g`g' = r(p50)
    di as text "Mean flows: " %9.4f `mean_flows_g`g''
    di as text "Median flows: " %9.4f `med_flows_g`g''
    
    * --------------------------
    * 13. Mean tf_per_emp_pre
    * --------------------------
    sum tf_per_emp_pre if `cond' & year==2009
    local mean_churn_g`g' = r(mean)
    di as text "Mean churn rate: " %9.4f `mean_churn_g`g''
	
	* --------------------------
    * 14. Mean turnover
    * --------------------------
    sum turnover_pre if `cond' & year==2009
    local mean_tn_g`g' = r(mean)
    di as text "Mean turnover rate: " %9.4f `mean_tn_g`g''
	
	* --------------------------
    * 15. Inequality: p90/p10 (exponentiated)
    * --------------------------
    cap drop temp_p90p10
    gen temp_p90p10 = exp(lr_remdezr_w_p90p10)
    sum temp_p90p10 if `cond' & year==2009
    local mean_p90p10_g`g' = r(mean)
    di as text "Mean p90/p10: " %9.2f `mean_p90p10_g`g''
    drop temp_p90p10
    
    * --------------------------
    * 16. Inequality: p80/p20 (exponentiated)
    * --------------------------
    cap drop temp_p80p20
    gen temp_p80p20 = exp(lr_remdezr_w_p80p20)
    sum temp_p80p20 if `cond' & year==2009
    local mean_p80p20_g`g' = r(mean)
    di as text "Mean p80/p20: " %9.2f `mean_p80p20_g`g''
    drop temp_p80p20
    
    * --------------------------
    * 17. Inequality: p75/p25 (exponentiated)
    * --------------------------
    cap drop temp_p75p25
    gen temp_p75p25 = exp(lr_remdezr_w_p75p25)
    sum temp_p75p25 if `cond' & year==2009
    local mean_p75p25_g`g' = r(mean)
    di as text "Mean p75/p25: " %9.2f `mean_p75p25_g`g''
    drop temp_p75p25
    
    * --------------------------
    * 18. Inequality: p50/p10 (exponentiated)
    * --------------------------
    cap drop temp_p50p10
    gen temp_p50p10 = exp(lr_remdezr_w_p50p10)
    sum temp_p50p10 if `cond' & year==2009
    local mean_p50p10_g`g' = r(mean)
    di as text "Mean p50/p10: " %9.2f `mean_p50p10_g`g''
    drop temp_p50p10
    
    * --------------------------
    * 19. Inequality: p90/p50 (exponentiated)
    * --------------------------
    cap drop temp_p90p50
    gen temp_p90p50 = exp(lr_remdezr_w_p90p50)
    sum temp_p90p50 if `cond' & year==2009
    local mean_p90p50_g`g' = r(mean)
    di as text "Mean p90/p50: " %9.2f `mean_p90p50_g`g''
    drop temp_p90p50
}

* ===============================
* WRITE TO CSV
* ===============================

file open `fh' using "$tables/descriptive_stats.csv", write append

* Row 1: Number of establishments
file write `fh' "N establishments"
forvalues g = 1/5 {
    file write `fh' ";" %12.0f (`n_estab_g`g'')
}
file write `fh' _n

* Row 2: Total workers
file write `fh' "Total workers"
forvalues g = 1/5 {
    file write `fh' ";" %12.0f (`n_workers_g`g'')
}
file write `fh' _n

* Row 3: Proportion treated
file write `fh' "Prop treated"
forvalues g = 1/5 {
    file write `fh' ";" %9.4f (`prop_treated_g`g'')
}
file write `fh' _n

* Row 4: Mean establishment size
file write `fh' "Mean estab size"
forvalues g = 1/5 {
    file write `fh' ";" %9.2f (`mean_emp_g`g'')
}
file write `fh' _n

* Row 5: Mean december wages
file write `fh' "Mean dec wages"
forvalues g = 1/5 {
    file write `fh' ";" %9.2f (`mean_wage_g`g'')
}
file write `fh' _n

* Row 6: Mean of median wages
file write `fh' "Mean of median wages"
forvalues g = 1/5 {
    file write `fh' ";" %9.2f (`mean_med_wage_g`g'')
}
file write `fh' _n

* Row 7: Median of mean wages
file write `fh' "Median of mean wages"
forvalues g = 1/5 {
    file write `fh' ";" %9.2f (`med_wage_g`g'')
}
file write `fh' _n

* Row 8: Mean clause count
file write `fh' "Mean clause count"
forvalues g = 1/5 {
    file write `fh' ";" %9.2f (`mean_clauses_g`g'')
}
file write `fh' _n

* Row 9: Proportion high school
file write `fh' "Prop high school"
forvalues g = 1/5 {
    file write `fh' ";" %9.4f (`prop_hs_g`g'')
}
file write `fh' _n

* Row 10: Proportion higher ed
file write `fh' "Prop higher ed"
forvalues g = 1/5 {
    file write `fh' ";" %9.4f (`prop_sup_g`g'')
}
file write `fh' _n

* Row 11: Proportion female
file write `fh' "Prop female"
forvalues g = 1/5 {
    file write `fh' ";" %9.4f (`prop_female_g`g'')
}
file write `fh' _n

* Row 12: Proportion non-white
file write `fh' "Prop non-white"
forvalues g = 1/5 {
    file write `fh' ";" %9.4f (`prop_nonwhite_g`g'')
}
file write `fh' _n

* Row 13: Mean flows
file write `fh' "Mean Connectivity"
forvalues g = 1/5 {
    file write `fh' ";" %9.4f (`mean_flows_g`g'')
}
file write `fh' _n

* Row 14: Median flows
file write `fh' "Median Connectivity"
forvalues g = 1/5 {
    file write `fh' ";" %9.4f (`med_flows_g`g'')
}
file write `fh' _n

* Row 15: Mean churn rate
file write `fh' "Mean churn rate"
forvalues g = 1/5 {
    file write `fh' ";" %9.4f (`mean_tn_g`g'')
}
file write `fh' _n

* Row 16: Inequality p90/p10
file write `fh' "p90/p10"
forvalues g = 1/5 {
    file write `fh' ";" %9.2f (`mean_p90p10_g`g'')
}
file write `fh' _n

// * Row 17: Inequality p80/p20
// file write `fh' "p80/p20"
// forvalues g = 1/5 {
//     file write `fh' ";" %9.2f (`mean_p80p20_g`g'')
// }
// file write `fh' _n
//
// * Row 18: Inequality p75/p25
// file write `fh' "p75/p25"
// forvalues g = 1/5 {
//     file write `fh' ";" %9.2f (`mean_p75p25_g`g'')
// }
// file write `fh' _n

* Row 19: Inequality p50/p10
file write `fh' "p50/p10"
forvalues g = 1/5 {
    file write `fh' ";" %9.2f (`mean_p50p10_g`g'')
}
file write `fh' _n

* Row 20: Inequality p90/p50
file write `fh' "p90/p50"
forvalues g = 1/5 {
    file write `fh' ";" %9.2f (`mean_p90p50_g`g'')
}
file write `fh' _n

file close `fh'

di _newline(2)
di as result "{hline 50}"
di as result "Descriptive statistics saved to:"
di as result "$tables/descriptive_stats.csv"
di as result "{hline 50}"
