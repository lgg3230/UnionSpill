********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: PROCESS POST-TREATMENT CONNECTIVITY MEASURES
* INPUT: MATLAB connectivity outputs (connectivity_treat_2011_2016.csv)
* OUTPUT: Establishment-level post-treatment connectivity dataset for merging
********************************************************************************

* This script ONLY processes the MATLAB output and creates a clean dataset
* with post-treatment connectivity measures that can be merged with firm-level data

timer clear
timer on 1

set more off
set varabbrev off
clear all
version 17.0

* Define globals
global klc "/kellogg/proj/lgg3230"
global main "$klc"
global rais_aux "$main/UnionSpill/Data/RAIS_aux"

********************************************************************************
* STEP 1: IMPORT AND CLEAN MATLAB OUTPUT
********************************************************************************

di _newline(2) "===== Processing connectivity to treated (2011-2016) ====="

* Import MATLAB output
import delimited "$rais_aux/connectivity_treat_2011_2016.csv", clear

* Clean establishment identifier (remove leading "1" prefix from MATLAB)
format identificad1 %21.0f
gen identificad1_s = string(identificad1, "%015.0f")
gen identificad = substr(identificad1_s, 2, 14)
order identificad
drop identificad1 identificad1_s

di "Imported " _N " establishments from MATLAB output"

********************************************************************************
* STEP 2: AGGREGATE TO POST-TREATMENT PERIOD (4 year pairs, like pre-treatment)
* Year pairs: 2011-2012, 2012-2013, 2013-2014, 2014-2015
********************************************************************************

di _newline "Aggregating to post-treatment period (2011-2015, 4 year pairs)..."

* Level variables: sum across 4 year pairs (only non-missing)
foreach prefix in totalout totalin totalflows outtreat intreat totaltreat {
    gen `prefix'_post = 0
    foreach yr in 2011_2012 2012_2013 2013_2014 2014_2015 {
        capture replace `prefix'_post = `prefix'_post + `prefix'_`yr' if !missing(`prefix'_`yr')
    }
}

* Per-worker variables: average across year pairs (only non-missing, like pre-treatment)
foreach prefix in totalout totalin totalflows outtreat intreat totaltreat {
    local pwprefix = "`prefix'_pw"

    gen `pwprefix'_post = 0
    gen `pwprefix'_count = 0

    foreach yr in 2011_2012 2012_2013 2013_2014 2014_2015 {
        capture replace `pwprefix'_post = `pwprefix'_post + `pwprefix'_`yr' if !missing(`pwprefix'_`yr')
        capture replace `pwprefix'_count = `pwprefix'_count + (!missing(`pwprefix'_`yr'))
    }

    replace `pwprefix'_post = `pwprefix'_post / `pwprefix'_count if `pwprefix'_count > 0
    replace `pwprefix'_post = . if `pwprefix'_count == 0
    drop `pwprefix'_count
}

* Proportion of flows to treated (post-treatment)
gen totaltreat_pf_post = totaltreat_post / totalflows_post if totalflows_post > 0

* Proportion for each year pair
gen flowtreat_pf_1112 = totaltreat_2011_2012 / totalflows_2011_2012 if totalflows_2011_2012 > 0
gen flowtreat_pf_1213 = totaltreat_2012_2013 / totalflows_2012_2013 if totalflows_2012_2013 > 0
gen flowtreat_pf_1314 = totaltreat_2013_2014 / totalflows_2013_2014 if totalflows_2013_2014 > 0
gen flowtreat_pf_1415 = totaltreat_2014_2015 / totalflows_2014_2015 if totalflows_2014_2015 > 0

* Average proportion across year pairs (only non-missing, like pre-treatment)
egen avg_ftreat_pf_post = rowmean(flowtreat_pf_1112 flowtreat_pf_1213 flowtreat_pf_1314 flowtreat_pf_1415)

********************************************************************************
* STEP 3: SAVE FULL YEARLY DATA (FOR REFERENCE)
********************************************************************************

save "$rais_aux/connectivity_treat_2011_2016_yearly.dta", replace
di "Saved full yearly data: $rais_aux/connectivity_treat_2011_2016_yearly.dta"

********************************************************************************
* STEP 4: CREATE CLEAN AGGREGATED DATASET FOR MERGING
********************************************************************************

* Keep only the aggregated measures needed for analysis
keep identificad ///
     totaltreat_post totaltreat_pw_post totaltreat_pf_post avg_ftreat_pf_post ///
     totalflows_post totalflows_pw_post ///
     outtreat_post outtreat_pw_post intreat_post intreat_pw_post

* Label variables
label var identificad "Establishment identifier (14-digit CNPJ)"
label var totaltreat_post "Total flows to treated (sum 2011-2015)"
label var totaltreat_pw_post "Flows to treated per worker (avg non-missing 2011-2015)"
label var totaltreat_pf_post "Proportion of flows to treated (2011-2015)"
label var avg_ftreat_pf_post "Average proportion to treated across non-missing year-pairs"
label var totalflows_post "Total flows (sum 2011-2015)"
label var totalflows_pw_post "Total flows per worker (avg non-missing 2011-2015)"
label var outtreat_post "Outflows to treated (sum 2011-2015)"
label var outtreat_pw_post "Outflows to treated per worker (avg non-missing 2011-2015)"
label var intreat_post "Inflows from treated (sum 2011-2015)"
label var intreat_pw_post "Inflows from treated per worker (avg non-missing 2011-2015)"

* Summary statistics
di _newline "=== Summary Statistics: Post-Treatment Connectivity ==="
summarize totaltreat_pw_post avg_ftreat_pf_post totalflows_pw_post, detail

* Save aggregated dataset
compress
save "$rais_aux/connectivity_post_treat_agg.dta", replace

di _newline "Saved aggregated dataset:"
di "  - $rais_aux/connectivity_post_treat_agg.dta"

********************************************************************************
* DONE
********************************************************************************

timer off 1
timer list

di _newline(2) "===== POST-TREATMENT CONNECTIVITY PROCESSING COMPLETE ====="
di _newline "Post-treatment period: 4 year pairs (2011-12, 2012-13, 2013-14, 2014-15)"
di "Averages computed over non-missing year pairs only (same as pre-treatment)"
di _newline "Key variables for IV analysis:"
di "  - totaltreat_pw_post: flows to treated per worker (main measure)"
di "  - avg_ftreat_pf_post: avg proportion of flows to treated"
di _newline "Merge with your firm-level data using: identificad"
