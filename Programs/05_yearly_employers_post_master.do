********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: MASTER FILE FOR POST-TREATMENT CONNECTIVITY MEASURES (2011-2016)
* INPUT: RAIS FILES (2012-2016), PRE-TREATMENT CONNECTIVITY MEASURES
* OUTPUT: POST-TREATMENT CONNECTIVITY MEASURES AND COMBINED DATASET
********************************************************************************

* This master script:
* 1. Generates yearly employer files for 2012-2016
* 2. Creates transition matrices for 2011-2016
* 3. Runs MATLAB connectivity scripts
* 4. Processes and aggregates connectivity measures

********************************************************************************
* SETUP AND GLOBALS
********************************************************************************

set more off
set varabbrev off
clear all
macro drop _all
version 17.0

* Define globals (same as 00_master.do)
global klc "/kellogg/proj/lgg3230"
global main "$klc"

global rais_raw_dir "$main/RAIS/output/data/full"
global rais_aux "$main/UnionSpill/Data/RAIS_aux"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global programs "$main/UnionSpill/Programs"
global tables "$main/UnionSpill/Tables"
global graphs "$main/UnionSpill/Graphs"

timer clear
timer on 1

********************************************************************************
* PART 1: GENERATE EMPLOYER FILES AND TRANSITION MATRICES
********************************************************************************

di "===== PART 1: Creating employer files for 2011-2016 ====="

do "$programs/05_yearly_employers_post.do"

********************************************************************************
* PART 2: RUN MATLAB CONNECTIVITY SCRIPTS
********************************************************************************

di "===== PART 2: Running MATLAB connectivity scripts ====="

* Full connectivity (to Lagos sample)
shell "/software/matlab/R2020b/bin/matlab" -nojvm < "/kellogg/proj/lgg3230/UnionSpill/Programs/connectivity_full_lagos_post.m"

* Connectivity to treated firms
shell "/software/matlab/R2020b/bin/matlab" -nojvm < "/kellogg/proj/lgg3230/UnionSpill/Programs/connectivity_treat_lagos_post.m"

* Connectivity to control firms
shell "/software/matlab/R2020b/bin/matlab" -nojvm < "/kellogg/proj/lgg3230/UnionSpill/Programs/connectivity_control_lagos_post.m"

* Bilateral connectivity
shell "/software/matlab/R2020b/bin/matlab" -nojvm < "/kellogg/proj/lgg3230/UnionSpill/Programs/bilateral_connectivity_post.m"

di "MATLAB scripts completed."

********************************************************************************
* PART 3: PROCESS FULL CONNECTIVITY OUTPUT (2011-2016)
********************************************************************************

di "===== PART 3: Processing connectivity output ====="

import delimited "$rais_aux/connectivity_2011_2016.csv", clear

format identificad1 %21.0f
gen identificad1_s = string(identificad1, "%015.0f")
order identificad1_s

gen identificad = substr(identificad1_s, 2, 14)
order identificad

drop identificad1 identificad1_s

// Level variables (sum across year pairs)
foreach prefix in totalout totalin totalflows outlagos inlagos totallagos {
    ds `prefix'_*
    local allvars = r(varlist)

    * Keep only those that do NOT contain _pw_
    local vars
    foreach v of local allvars {
        if strpos("`v'", "_pw_") == 0 {
            local vars `vars' `v'
        }
    }

    gen `prefix'_post = 0
    foreach var of local vars {
        replace `prefix'_post = `prefix'_post + `var'
    }
}

// Per-worker variables (average across year pairs)
foreach prefix in totalout totalin totalflows outlagos inlagos totallagos {
    local pwprefix = "`prefix'_pw"

    ds `pwprefix'_*
    local vars = r(varlist)

    gen `pwprefix'_post = 0
    foreach var of local vars {
        replace `pwprefix'_post = (`pwprefix'_post + `var') / 5  // 5 year pairs
    }
}

save "$rais_aux/connectivity_2011_2016_yearly.dta", replace

keep identificad totalout_post totalin_post totalflows_post outlagos_post inlagos_post totallagos_post ///
     totalout_pw_post totalin_pw_post totalflows_pw_post outlagos_pw_post inlagos_pw_post totallagos_pw_post

save "$rais_aux/connectivity_2011_2016_agg.dta", replace

********************************************************************************
* PART 4: PROCESS TREATMENT/CONTROL CONNECTIVITY OUTPUT
********************************************************************************

foreach dataset in treat control {
    import delimited "$rais_aux/connectivity_`dataset'_2011_2016.csv", clear

    format identificad1 %21.0f
    gen identificad1_s = string(identificad1, "%015.0f")
    order identificad1_s

    gen identificad = substr(identificad1_s, 2, 14)
    order identificad

    drop identificad1 identificad1_s

    // Proportion of flows to treat/control for each year pair
    gen flow`dataset'_pf_11_12 = total`dataset'_2011_2012 / totalflows_2011_2012
    gen flow`dataset'_pf_12_13 = total`dataset'_2012_2013 / totalflows_2012_2013
    gen flow`dataset'_pf_13_14 = total`dataset'_2013_2014 / totalflows_2013_2014
    gen flow`dataset'_pf_14_15 = total`dataset'_2014_2015 / totalflows_2014_2015
    gen flow`dataset'_pf_15_16 = total`dataset'_2015_2016 / totalflows_2015_2016

    gen avg_flow`dataset'_pf_post = (flow`dataset'_pf_11_12 + flow`dataset'_pf_12_13 + ///
                                      flow`dataset'_pf_13_14 + flow`dataset'_pf_14_15 + ///
                                      flow`dataset'_pf_15_16) / 5

    // Non-missing average calculation
    gen flow`dataset'_pf_11_12_n = total`dataset'_2011_2012 / totalflows_2011_2012 if totalflows_2011_2012 > 0
    gen flow`dataset'_pf_12_13_n = total`dataset'_2012_2013 / totalflows_2012_2013 if totalflows_2012_2013 > 0
    gen flow`dataset'_pf_13_14_n = total`dataset'_2013_2014 / totalflows_2013_2014 if totalflows_2013_2014 > 0
    gen flow`dataset'_pf_14_15_n = total`dataset'_2014_2015 / totalflows_2014_2015 if totalflows_2014_2015 > 0
    gen flow`dataset'_pf_15_16_n = total`dataset'_2015_2016 / totalflows_2015_2016 if totalflows_2015_2016 > 0

    * Calculate average of non-missing values
    gen avg_flow`dataset'_pf_n_post = 0
    gen avg_flow`dataset'_pf_count_n = 0

    foreach year_pair in "11_12" "12_13" "13_14" "14_15" "15_16" {
        replace avg_flow`dataset'_pf_n_post = avg_flow`dataset'_pf_n_post + flow`dataset'_pf_`year_pair'_n if !missing(flow`dataset'_pf_`year_pair'_n)
        replace avg_flow`dataset'_pf_count_n = avg_flow`dataset'_pf_count_n + (missing(flow`dataset'_pf_`year_pair'_n) == 0)
    }

    replace avg_flow`dataset'_pf_n_post = avg_flow`dataset'_pf_n_post / avg_flow`dataset'_pf_count_n if avg_flow`dataset'_pf_count_n > 0
    replace avg_flow`dataset'_pf_n_post = . if avg_flow`dataset'_pf_count_n == 0

    drop avg_flow`dataset'_pf_count_n

    // Level variables (sum across year pairs)
    foreach prefix in totalout totalin totalflows out`dataset' in`dataset' total`dataset' {
        ds `prefix'_*
        local allvars = r(varlist)

        * Keep only those that do NOT contain _pw_
        local vars
        foreach v of local allvars {
            if strpos("`v'", "_pw_") == 0 {
                local vars `vars' `v'
            }
        }

        gen `prefix'_post = 0
        foreach var of local vars {
            replace `prefix'_post = `prefix'_post + `var'
        }

        // Non-missing version
        gen `prefix'_n_post = 0
        gen `prefix'_count_n = 0

        foreach var of local vars {
            replace `prefix'_n_post = `prefix'_n_post + `var' if !missing(`var')
            replace `prefix'_count_n = `prefix'_count_n + (missing(`var') == 0)
        }

        replace `prefix'_n_post = . if `prefix'_count_n == 0
        drop `prefix'_count_n
    }

    // Per-worker variables
    foreach prefix in totalout totalin totalflows out`dataset' in`dataset' total`dataset' {
        local pwprefix = "`prefix'_pw"

        ds `pwprefix'_*
        local vars = r(varlist)

        gen `pwprefix'_post = 0
        foreach var of local vars {
            replace `pwprefix'_post = (`pwprefix'_post + `var') / 5
        }

        // Non-missing version
        gen `pwprefix'_n_post = 0
        gen `pwprefix'_count_n = 0

        foreach var of local vars {
            replace `pwprefix'_n_post = `pwprefix'_n_post + `var' if !missing(`var')
            replace `pwprefix'_count_n = `pwprefix'_count_n + (missing(`var') == 0)
        }

        replace `pwprefix'_n_post = `pwprefix'_n_post / `pwprefix'_count_n if `pwprefix'_count_n > 0
        replace `pwprefix'_n_post = . if `pwprefix'_count_n == 0

        drop `pwprefix'_count_n
    }

    save "$rais_aux/connectivity_`dataset'_2011_2016_yearly.dta", replace

    keep identificad out`dataset'_post in`dataset'_post total`dataset'_post ///
         out`dataset'_pw_post in`dataset'_pw_post total`dataset'_pw_post ///
         avg_flow`dataset'_pf_post out`dataset'_n_post in`dataset'_n_post total`dataset'_n_post ///
         out`dataset'_pw_n_post in`dataset'_pw_n_post total`dataset'_pw_n_post avg_flow`dataset'_pf_n_post ///
         totalflows_n_post

    save "$rais_aux/connectivity_`dataset'_2011_2016_agg.dta", replace
}

********************************************************************************
* PART 5: MERGE ALL CONNECTIVITY MEASURES
********************************************************************************

di "===== PART 5: Merging all connectivity measures ====="

use "$rais_aux/connectivity_2011_2016_agg.dta", clear

merge 1:1 identificad using "$rais_aux/connectivity_treat_2011_2016_agg.dta"
drop _merge

merge 1:1 identificad using "$rais_aux/connectivity_control_2011_2016_agg.dta"
drop _merge

save "$rais_aux/connectivity_2011_2016_tcl.dta", replace

********************************************************************************
* PART 6: PROCESS BILATERAL CONNECTIVITY OUTPUT
********************************************************************************

di "===== PART 6: Processing bilateral connectivity ====="

import delimited "$rais_aux/bilateral_connectivity_2011_2016.csv", clear

* Clean up establishment IDs (remove leading 1 if present)
gen identificad_i_clean = substr(identificad_i, 2, 14) if substr(identificad_i, 1, 1) == "1"
replace identificad_i_clean = identificad_i if missing(identificad_i_clean)

gen identificad_j_clean = substr(identificad_j, 2, 14) if substr(identificad_j, 1, 1) == "1"
replace identificad_j_clean = identificad_j if missing(identificad_j_clean)

drop identificad_i identificad_j
rename (identificad_i_clean identificad_j_clean) (identificad_i identificad_j)

save "$rais_aux/bilateral_connectivity_2011_2016.dta", replace

********************************************************************************
* PART 7: COMBINE PRE AND POST TREATMENT CONNECTIVITY
********************************************************************************

di "===== PART 7: Combining pre and post treatment connectivity ====="

* Merge pre-treatment (2007-2011) and post-treatment (2011-2016) bilateral connectivity
use "$rais_aux/bilateral_connectivity_2007_2011.dta", clear

merge 1:1 identificad_i identificad_j using "$rais_aux/bilateral_connectivity_2011_2016.dta", ///
    gen(_merge_bilateral)

* Rename variables to distinguish periods
rename (bilateral_conn_pw flows_total) (bilateral_conn_pw_pre flows_total_pre)
rename (bilateral_conn_pw flows_total) (bilateral_conn_pw_post flows_total_post) if _merge_bilateral == 2 | _merge_bilateral == 3

save "$rais_aux/bilateral_connectivity_full.dta", replace

* Also merge establishment-level connectivity
use "$rais_aux/connectivity_2007_2011_tcl.dta", clear

merge 1:1 identificad using "$rais_aux/connectivity_2011_2016_tcl.dta", gen(_merge_conn)

save "$rais_aux/connectivity_full_2007_2016.dta", replace

timer off 1

di "===== POST-TREATMENT CONNECTIVITY PROCESSING COMPLETE ====="
timer list
