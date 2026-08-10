********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: AGGREGATE EXTENDED CONNECTIVITY (6 YEAR-PAIRS: 2005-2011)
* INPUT: connectivity_treat_2005_2011.csv (from MATLAB extended script)
* OUTPUT: connectivity_treat_2005_2011_6yr.dta
*
* NOTE: Adapts lines 130-386 of 1050_yearly_employers.do for 6 year-pairs.
*       The CSV contains both totaltreat and totalflows columns.
********************************************************************************

version 17.0

global klc "/kellogg/proj/lgg3230"
global main "$klc"
global rais_aux "$main/UnionSpill/Data/RAIS_aux"

timer clear
timer on 1

********************************************************************************
* PART 1: Import and clean IDs
********************************************************************************

import delimited "$rais_aux/connectivity_treat_2005_2011.csv", clear

format identificad1 %21.0f
gen identificad1_s = string(identificad1, "%015.0f")
order identificad1_s

gen identificad = substr(identificad1_s,2,14)
order identificad

drop identificad1 identificad1_s


********************************************************************************
* PART 2: Compute year-pair-specific flow proportions (NaN-aware)
********************************************************************************

* Year-pair-specific proportions (only where totalflows > 0)
gen flowtreat_pf_05_06_n = totaltreat_2005_2006/totalflows_2005_2006 if totalflows_2005_2006 > 0
gen flowtreat_pf_06_07_n = totaltreat_2006_2007/totalflows_2006_2007 if totalflows_2006_2007 > 0
gen flowtreat_pf_07_08_n = totaltreat_2007_2008/totalflows_2007_2008 if totalflows_2007_2008 > 0
gen flowtreat_pf_08_09_n = totaltreat_2008_2009/totalflows_2008_2009 if totalflows_2008_2009 > 0
gen flowtreat_pf_09_10_n = totaltreat_2009_2010/totalflows_2009_2010 if totalflows_2009_2010 > 0
gen flowtreat_pf_10_11_n = totaltreat_2010_2011/totalflows_2010_2011 if totalflows_2010_2011 > 0

* NaN-aware average across 6 year-pair-specific proportions
gen avg_ftreat_pf_n_6yr = 0
gen avg_ftreat_pf_count = 0

foreach year_pair in "05_06" "06_07" "07_08" "08_09" "09_10" "10_11" {
    replace avg_ftreat_pf_n_6yr = avg_ftreat_pf_n_6yr + flowtreat_pf_`year_pair'_n if !missing(flowtreat_pf_`year_pair'_n)
    replace avg_ftreat_pf_count = avg_ftreat_pf_count + (missing(flowtreat_pf_`year_pair'_n) == 0)
}

replace avg_ftreat_pf_n_6yr = avg_ftreat_pf_n_6yr / avg_ftreat_pf_count if avg_ftreat_pf_count > 0
replace avg_ftreat_pf_n_6yr = . if avg_ftreat_pf_count == 0

drop avg_ftreat_pf_count


********************************************************************************
* PART 3: Level variables - NaN-aware sum across 6 year-pairs
********************************************************************************

foreach prefix in totalflows totaltreat {
    ds `prefix'_*
    local allvars = r(varlist)

    * Keep only those that do NOT contain _pw_
    local vars
    foreach v of local allvars {
        if strpos("`v'", "_pw_") == 0 {
            local vars `vars' `v'
        }
    }

    * NaN-aware sum
    gen `prefix'_n_6yr = 0
    gen `prefix'_count_6yr = 0

    foreach var of local vars {
        replace `prefix'_n_6yr = `prefix'_n_6yr + `var' if !missing(`var')
        replace `prefix'_count_6yr = `prefix'_count_6yr + (missing(`var') == 0)
    }

    * Set to missing only if ALL components are missing
    replace `prefix'_n_6yr = . if `prefix'_count_6yr == 0

    drop `prefix'_count_6yr
}


********************************************************************************
* PART 4: Per-worker variables - NaN-aware average across 6 year-pairs
********************************************************************************

foreach prefix in totalflows totaltreat {
    * Build the prefix for pw variables
    local pwprefix = "`prefix'_pw"

    ds `pwprefix'_*
    local vars = r(varlist)

    * NaN-aware average
    gen `pwprefix'_n_6yr = 0
    gen `pwprefix'_count_6yr = 0

    foreach var of local vars {
        replace `pwprefix'_n_6yr = `pwprefix'_n_6yr + `var' if !missing(`var')
        replace `pwprefix'_count_6yr = `pwprefix'_count_6yr + (missing(`var') == 0)
    }

    * Calculate average of non-missing values
    replace `pwprefix'_n_6yr = `pwprefix'_n_6yr / `pwprefix'_count_6yr if `pwprefix'_count_6yr > 0

    * Set to missing only if ALL components are missing
    replace `pwprefix'_n_6yr = . if `pwprefix'_count_6yr == 0

    drop `pwprefix'_count_6yr
}


********************************************************************************
* PART 5: Compute aggregate proportion measure
********************************************************************************

* Total proportion: totaltreat / totalflows across all 6 year-pairs
gen totaltreat_pf_n_6yr = totaltreat_n_6yr / totalflows_n_6yr if totalflows_n_6yr > 0


********************************************************************************
* PART 6: Save
********************************************************************************

* Save full version with all year-pair columns for reference
save "$rais_aux/connectivity_treat_2005_2011_6yr_yearly.dta", replace

* Save compact version with key aggregated measures
keep identificad ///
    totaltreat_pw_n_6yr totaltreat_pf_n_6yr avg_ftreat_pf_n_6yr ///
    totalflows_n_6yr totaltreat_n_6yr totalflows_pw_n_6yr ///
    flowtreat_pf_05_06_n flowtreat_pf_06_07_n ///
    flowtreat_pf_07_08_n flowtreat_pf_08_09_n ///
    flowtreat_pf_09_10_n flowtreat_pf_10_11_n

save "$rais_aux/connectivity_treat_2005_2011_6yr.dta", replace

* Save sample-restricted version (lagos_sample_avg==1 & in_balanced_panel==1)
preserve
use "$rais_firm/cba_rais_firm_2009_2016_flows_1.dta" if year==2009, clear
keep identificad lagos_sample_avg in_balanced_panel
tempfile sample_flags
save `sample_flags'
restore

merge 1:1 identificad using `sample_flags', keep(match) nogenerate
keep if lagos_sample_avg == 1 & in_balanced_panel == 1
drop lagos_sample_avg in_balanced_panel
display "Sample-restricted firm count: " _N
save "$rais_aux/connectivity_treat_2005_2011_6yr_sample.dta", replace

timer off 1
timer list

* Verification
describe using "$rais_aux/connectivity_treat_2005_2011_6yr.dta"
summarize totaltreat_pw_n_6yr totaltreat_pf_n_6yr avg_ftreat_pf_n_6yr totalflows_n_6yr

display "Output: $rais_aux/connectivity_treat_2005_2011_6yr.dta"
display "Done."
