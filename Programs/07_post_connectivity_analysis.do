********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: POST-TREATMENT CONNECTIVITY ANALYSIS
* INPUT: MATLAB connectivity outputs, bilateral connectivity, firm-level data
* OUTPUT: Aggregated post-treatment connectivity, IV regressions, correlates
********************************************************************************

* This script:
* 1. Processes MATLAB output for connectivity to treated (2011-2016)
* 2. Aggregates to immediate post-treatment period (2012-2014)
* 3. Processes bilateral connectivity for post-treatment
* 4. Runs first-stage: pre-treatment flows predicting post-treatment flows
* 5. Runs IV regression: wages ~ post-treatment flows (IV = pre-treatment flows)
* 6. Runs correlates analysis for post-treatment bilateral flows

timer clear
timer on 1

set more off
set varabbrev off
clear all
version 17.0

* Define globals
global klc "/kellogg/proj/lgg3230"
global main "$klc"
global rais_raw_dir "$main/RAIS/output/data/full"
global rais_aux "$main/UnionSpill/Data/RAIS_aux"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global programs "$main/UnionSpill/Programs"
global tables "$main/UnionSpill/Tables"
global graphs "$main/UnionSpill/Graphs"
global ibge "$main/UnionSpill/Data/IBGE"

********************************************************************************
* PART 1: PROCESS CONNECTIVITY TO TREATED (ESTABLISHMENT-LEVEL)
********************************************************************************

di _newline(2) "===== PART 1: Processing connectivity to treated ====="

* Import MATLAB output
import delimited "$rais_aux/connectivity_treat_2011_2016.csv", clear

* Clean establishment identifier
format identificad1 %21.0f
gen identificad1_s = string(identificad1, "%015.0f")
gen identificad = substr(identificad1_s, 2, 14)
order identificad
drop identificad1 identificad1_s

* ============================================================================
* Aggregate to IMMEDIATE POST-TREATMENT (2012-2014) - 3 year pairs
* Year pairs: 2011-2012, 2012-2013, 2013-2014
* ============================================================================

di "Aggregating connectivity to immediate post-treatment period (2012-2014)..."

* Level variables: sum across year pairs
foreach prefix in totalout totalin totalflows outtreat intreat totaltreat {
    * Get all variables with this prefix (exclude _pw versions)
    ds `prefix'_*
    local allvars = r(varlist)

    local vars
    foreach v of local allvars {
        if strpos("`v'", "_pw_") == 0 {
            local vars `vars' `v'
        }
    }

    * Sum only 2011-12, 2012-13, 2013-14 (immediate post)
    gen `prefix'_post = 0
    foreach yr in 2011_2012 2012_2013 2013_2014 {
        capture replace `prefix'_post = `prefix'_post + `prefix'_`yr' if !missing(`prefix'_`yr')
    }
}

* Per-worker variables: average across year pairs
foreach prefix in totalout totalin totalflows outtreat intreat totaltreat {
    local pwprefix = "`prefix'_pw"

    gen `pwprefix'_post = 0
    gen `pwprefix'_count = 0

    foreach yr in 2011_2012 2012_2013 2013_2014 {
        capture replace `pwprefix'_post = `pwprefix'_post + `pwprefix'_`yr' if !missing(`pwprefix'_`yr')
        capture replace `pwprefix'_count = `pwprefix'_count + (!missing(`pwprefix'_`yr'))
    }

    replace `pwprefix'_post = `pwprefix'_post / `pwprefix'_count if `pwprefix'_count > 0
    replace `pwprefix'_post = . if `pwprefix'_count == 0
    drop `pwprefix'_count
}

* Compute proportion of flows to treated (immediate post)
gen flowtreat_pf_post = totaltreat_post / totalflows_post if totalflows_post > 0

* Non-missing average proportion across year pairs
gen flowtreat_pf_1112 = totaltreat_2011_2012 / totalflows_2011_2012 if totalflows_2011_2012 > 0
gen flowtreat_pf_1213 = totaltreat_2012_2013 / totalflows_2012_2013 if totalflows_2012_2013 > 0
gen flowtreat_pf_1314 = totaltreat_2013_2014 / totalflows_2013_2014 if totalflows_2013_2014 > 0

egen avg_flowtreat_pf_post = rowmean(flowtreat_pf_1112 flowtreat_pf_1213 flowtreat_pf_1314)

* Save full yearly data
save "$rais_aux/connectivity_treat_2011_2016_yearly.dta", replace

* Keep aggregated measures only
keep identificad totaltreat_post totaltreat_pw_post flowtreat_pf_post avg_flowtreat_pf_post ///
     totalflows_post totalflows_pw_post

save "$rais_aux/connectivity_treat_post_agg.dta", replace

di "Saved: $rais_aux/connectivity_treat_post_agg.dta"
di "Variables: totaltreat_post, totaltreat_pw_post, flowtreat_pf_post, avg_flowtreat_pf_post"

********************************************************************************
* PART 2: PROCESS BILATERAL CONNECTIVITY (POST-TREATMENT)
********************************************************************************

di _newline(2) "===== PART 2: Processing bilateral connectivity (post-treatment) ====="

* Import bilateral connectivity from MATLAB output
import delimited "$rais_aux/bilateral_connectivity_2011_2016.csv", clear stringcols(1 2)

* Clean up establishment IDs (remove leading "1" prefix)
gen str14 id_i_clean = substr(identificad_i, 2, 14)
gen str14 id_j_clean = substr(identificad_j, 2, 14)
drop identificad_i identificad_j
rename id_i_clean identificad_i
rename id_j_clean identificad_j

* Compute immediate post-treatment flows (2012-2014)
* Year pairs: 2011-12, 2012-13, 2013-14 (but column names are flows_1112, etc.)
gen flows_post = flows_1112 + flows_1213 + flows_1314

* Compute average ratio for immediate post
egen bilateral_conn_pw_post = rowmean(ratio_1112 ratio_1213 ratio_1314)

* Keep only post-treatment variables
keep identificad_i identificad_j bilateral_conn_pw_post flows_post ///
     flows_1112 flows_1213 flows_1314 ratio_1112 ratio_1213 ratio_1314

save "$rais_aux/bilateral_connectivity_post_raw.dta", replace

di "Saved: $rais_aux/bilateral_connectivity_post_raw.dta"

********************************************************************************
* PART 3: MERGE PRE AND POST CONNECTIVITY FOR FIRST-STAGE ANALYSIS
********************************************************************************

di _newline(2) "===== PART 3: Merging pre and post connectivity ====="

* Load pre-treatment connectivity to treated
use "$rais_aux/connectivity_2007_2011_tcl.dta", clear

* Keep relevant pre-treatment variables
keep identificad totaltreat_pf_n avg_ftreat_pf_n totaltreat_pw_n

rename totaltreat_pf_n totaltreat_pf_pre
rename avg_ftreat_pf_n avg_flowtreat_pf_pre
rename totaltreat_pw_n totaltreat_pw_pre

* Merge with post-treatment connectivity
merge 1:1 identificad using "$rais_aux/connectivity_treat_post_agg.dta", gen(_merge_post)

* Summary of merge
tab _merge_post

* Keep only establishments with both pre and post
keep if _merge_post == 3
drop _merge_post

save "$rais_aux/connectivity_pre_post_merged.dta", replace

di "Saved: $rais_aux/connectivity_pre_post_merged.dta"

********************************************************************************
* PART 4: FIRST-STAGE ANALYSIS - PRE PREDICTING POST
********************************************************************************

di _newline(2) "===== PART 4: First-stage analysis ====="

use "$rais_aux/connectivity_pre_post_merged.dta", clear

* Merge sample restrictions from main dataset
merge 1:1 identificad using "$rais_firm/cba_rais_firm_2009_2016_flows_1.dta", ///
    keep(match) keepusing(lagos_sample_avg in_balanced_panel treat_ultra microregion industry1) nogen

* Restrict to sample
keep if lagos_sample_avg == 1 & in_balanced_panel == 1

* First-stage: How well do pre-treatment flows predict post-treatment flows?
di _newline "=== First Stage: Pre-treatment flows predicting post-treatment flows ==="

* Simple correlation
corr avg_flowtreat_pf_pre avg_flowtreat_pf_post
local corr_pf = r(rho)
di "Correlation (avg proportion to treated): `corr_pf'"

corr totaltreat_pw_pre totaltreat_pw_post
local corr_pw = r(rho)
di "Correlation (flows per worker): `corr_pw'"

* Regression: post = alpha + beta * pre
di _newline "Regression: post-treatment flows ~ pre-treatment flows"
reg avg_flowtreat_pf_post avg_flowtreat_pf_pre, robust
estimates store fs_simple

* With fixed effects
reghdfe avg_flowtreat_pf_post avg_flowtreat_pf_pre, absorb(microregion industry1) vce(robust)
estimates store fs_fe

* Binscatter
binscatter avg_flowtreat_pf_post avg_flowtreat_pf_pre, nquantiles(20) ///
    xtitle("Pre-treatment flows to treated (avg proportion)") ///
    ytitle("Post-treatment flows to treated (avg proportion)") ///
    mcolor(navy) lcolor(navy) ///
    plotregion(color(white)) graphregion(color(white)) ///
    title("First Stage: Pre vs Post Connectivity to Treated")
graph export "$graphs/first_stage_flows_binscatter.pdf", replace

* Export first-stage results
esttab fs_simple fs_fe using "$tables/first_stage_flows.tex", ///
    replace booktabs ///
    title("First Stage: Pre-treatment Flows Predicting Post-treatment Flows") ///
    mtitles("OLS" "With FE") ///
    label se(3) b(3) star(* 0.10 ** 0.05 *** 0.01) ///
    addnotes("Sample: lagos\_sample\_avg==1 \& in\_balanced\_panel==1" ///
             "Post-treatment: 2012-2014, Pre-treatment: 2007-2011")

di "Saved: $tables/first_stage_flows.tex"
di "Saved: $graphs/first_stage_flows_binscatter.pdf"

********************************************************************************
* PART 5: IV REGRESSION - WAGES ~ POST FLOWS (IV = PRE FLOWS)
********************************************************************************

di _newline(2) "===== PART 5: IV Regression ====="

* Load main panel dataset
use "$rais_firm/cba_rais_firm_2009_2016_flows_1.dta", clear

* Restrict to sample
keep if lagos_sample_avg == 1 & in_balanced_panel == 1

* Merge pre-treatment connectivity
merge m:1 identificad using "$rais_aux/connectivity_pre_post_merged.dta", ///
    keep(match master) nogen

* Create post-treatment indicator
gen post = (year >= 2012)

* Create interaction terms for DiD-style IV
gen post_flowtreat_pre = post * avg_flowtreat_pf_pre
gen post_flowtreat_post = post * avg_flowtreat_pf_post

* Summary statistics
di _newline "=== Summary Statistics ==="
sum lr_remdezr avg_flowtreat_pf_pre avg_flowtreat_pf_post if !missing(avg_flowtreat_pf_pre) & !missing(avg_flowtreat_pf_post)

* ============================================================================
* IV REGRESSIONS
* ============================================================================

di _newline "=== IV Regression: Log Wages ~ Post-treatment Connectivity ==="

* First stage
di _newline "--- First Stage ---"
reghdfe post_flowtreat_post post_flowtreat_pre if year >= 2012, ///
    absorb(identificad year) vce(cluster identificad)
estimates store iv_fs

* Reduced form
di _newline "--- Reduced Form ---"
reghdfe lr_remdezr post_flowtreat_pre if year >= 2012, ///
    absorb(identificad year) vce(cluster identificad)
estimates store iv_rf

* IV: Post-treatment flows instrumented by pre-treatment flows
di _newline "--- IV Estimation ---"
ivreghdfe lr_remdezr (post_flowtreat_post = post_flowtreat_pre) if year >= 2012, ///
    absorb(identificad year) cluster(identificad)
estimates store iv_main

* IV with controls
ivreghdfe lr_remdezr (post_flowtreat_post = post_flowtreat_pre) ///
    l_firm_emp prop_sup prop_hs male_prop white_prop if year >= 2012, ///
    absorb(identificad year) cluster(identificad)
estimates store iv_controls

* ============================================================================
* OLS FOR COMPARISON
* ============================================================================

di _newline "=== OLS Comparison ==="

* OLS: Post-treatment flows (potentially endogenous)
reghdfe lr_remdezr post_flowtreat_post if year >= 2012, ///
    absorb(identificad year) vce(cluster identificad)
estimates store ols_post

* OLS: Pre-treatment flows (reduced form / intent-to-treat)
reghdfe lr_remdezr post_flowtreat_pre if year >= 2012, ///
    absorb(identificad year) vce(cluster identificad)
estimates store ols_pre

* ============================================================================
* EXPORT IV RESULTS
* ============================================================================

* Table 1: First stage and reduced form
esttab iv_fs iv_rf using "$tables/iv_first_stage.tex", ///
    replace booktabs ///
    title("First Stage and Reduced Form") ///
    mtitles("First Stage" "Reduced Form") ///
    label se(4) b(4) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N r2 F, labels("Observations" "R-squared" "F-statistic")) ///
    addnotes("Sample: Post-treatment period (2012-2016), balanced panel" ///
             "Establishment and year fixed effects" ///
             "Standard errors clustered at establishment level")

* Table 2: Main IV results
esttab ols_post ols_pre iv_main iv_controls using "$tables/iv_wages_flows.tex", ///
    replace booktabs ///
    title("IV Regression: Wages and Connectivity to Treated Firms") ///
    mtitles("OLS (Post)" "OLS (Pre)" "IV" "IV + Controls") ///
    label se(4) b(4) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N r2, labels("Observations" "R-squared")) ///
    addnotes("Dependent variable: Log December real earnings" ///
             "Endogenous: post $\times$ post-treatment flows to treated" ///
             "Instrument: post $\times$ pre-treatment flows to treated" ///
             "Establishment and year fixed effects" ///
             "Standard errors clustered at establishment level")

di _newline "Saved: $tables/iv_first_stage.tex"
di "Saved: $tables/iv_wages_flows.tex"

********************************************************************************
* PART 6: BILATERAL CONNECTIVITY CORRELATES (POST-TREATMENT)
********************************************************************************

di _newline(2) "===== PART 6: Bilateral connectivity correlates (post-treatment) ====="

* Load sample establishments
use "$rais_firm/cba_rais_firm_2009_2016_flows_1.dta", clear
keep if year == 2011
keep if lagos_sample_avg == 1 & in_balanced_panel == 1
keep identificad municipio microregion big_industry industry1 mode_union
duplicates drop identificad, force
save "$rais_aux/sample_establishments_post.dta", replace

* Create all pairs and merge bilateral connectivity
* (Following same structure as 06_bilateral_descriptives.do)

* Create establishment i file
use "$rais_aux/sample_establishments_post.dta", clear
rename identificad identificad_i
rename municipio municipio_i
rename microregion microregion_i
rename big_industry big_industry_i
rename industry1 industry1_i
rename mode_union mode_union_i
gen _crossjoin = 1
save "$rais_aux/sample_flags_i_post.dta", replace

* Create establishment j file
use "$rais_aux/sample_establishments_post.dta", clear
rename identificad identificad_j
rename municipio municipio_j
rename microregion microregion_j
rename big_industry big_industry_j
rename industry1 industry1_j
rename mode_union mode_union_j
gen _crossjoin = 1
save "$rais_aux/sample_flags_j_post.dta", replace

* Cross-join
use "$rais_aux/sample_flags_i_post.dta", clear
joinby _crossjoin using "$rais_aux/sample_flags_j_post.dta"
drop _crossjoin
drop if identificad_i == identificad_j

* Merge bilateral connectivity (post-treatment)
merge 1:1 identificad_i identificad_j using "$rais_aux/bilateral_connectivity_post_raw.dta", keep(master match)
replace bilateral_conn_pw_post = 0 if _merge == 1
replace flows_post = 0 if _merge == 1
gen has_positive_flow_post = (_merge == 3)
drop _merge

* Merge pre-treatment bilateral connectivity for comparison
merge 1:1 identificad_i identificad_j using "$rais_aux/bilateral_connectivity_raw.dta", keep(master match)
replace bilateral_conn_pw = 0 if _merge == 1
replace flows_total = 0 if _merge == 1
gen has_positive_flow_pre = (_merge == 3)
drop _merge

* Create proximity measures
gen same_muni = (municipio_i == municipio_j)
gen same_microregion = (microregion_i == microregion_j)
gen same_union = (mode_union_i == mode_union_j) if !missing(mode_union_i) & !missing(mode_union_j)
gen same_big_industry = (big_industry_i == big_industry_j)
gen same_industry = (industry1_i == industry1_j)

* Merge firm characteristics
foreach yr in 2012 2013 2014 {
    use "$rais_firm/rais_firm_`yr'.dta", clear
    keep identificad firm_emp r_remdezr male_prop white_prop prop_sup prop_hs prop_nhs
    gen prop_female = 1 - male_prop
    gen prop_nonwhite = 1 - white_prop
    foreach var in firm_emp r_remdezr prop_female prop_nonwhite prop_sup prop_hs prop_nhs {
        rename `var' `var'_`yr'
    }
    drop male_prop white_prop
    save "$rais_aux/firm_chars_`yr'_post.dta", replace
}

* Merge years
use "$rais_aux/firm_chars_2012_post.dta", clear
merge 1:1 identificad using "$rais_aux/firm_chars_2013_post.dta", nogen
merge 1:1 identificad using "$rais_aux/firm_chars_2014_post.dta", nogen

* Compute 2012-2014 averages
egen avg_firm_emp_post = rowmean(firm_emp_2012 firm_emp_2013 firm_emp_2014)
egen avg_prop_female_post = rowmean(prop_female_2012 prop_female_2013 prop_female_2014)
egen avg_prop_sup_post = rowmean(prop_sup_2012 prop_sup_2013 prop_sup_2014)
egen avg_prop_nonwhite_post = rowmean(prop_nonwhite_2012 prop_nonwhite_2013 prop_nonwhite_2014)
egen avg_prop_hs_post = rowmean(prop_hs_2012 prop_hs_2013 prop_hs_2014)
egen avg_prop_nhs_post = rowmean(prop_nhs_2012 prop_nhs_2013 prop_nhs_2014)
egen avg_r_remdezr_post = rowmean(r_remdezr_2012 r_remdezr_2013 r_remdezr_2014)

gen l_avg_firm_emp_post = ln(avg_firm_emp_post)
gen l_avg_r_remdezr_post = ln(avg_r_remdezr_post)

keep identificad avg_firm_emp_post l_avg_firm_emp_post avg_prop_female_post ///
     avg_prop_sup_post avg_prop_nonwhite_post avg_prop_hs_post avg_prop_nhs_post ///
     avg_r_remdezr_post l_avg_r_remdezr_post

* Save for i and j
rename identificad identificad_i
foreach var in avg_firm_emp_post l_avg_firm_emp_post avg_prop_female_post ///
               avg_prop_sup_post avg_prop_nonwhite_post avg_prop_hs_post avg_prop_nhs_post ///
               avg_r_remdezr_post l_avg_r_remdezr_post {
    rename `var' `var'_i
}
save "$rais_aux/firm_chars_post_i.dta", replace

use "$rais_aux/firm_chars_post_i.dta", clear
rename identificad_i identificad_j
foreach var in avg_firm_emp_post l_avg_firm_emp_post avg_prop_female_post ///
               avg_prop_sup_post avg_prop_nonwhite_post avg_prop_hs_post avg_prop_nhs_post ///
               avg_r_remdezr_post l_avg_r_remdezr_post {
    rename `var'_i `var'_j
}
save "$rais_aux/firm_chars_post_j.dta", replace

* Merge to bilateral pairs
use "$rais_aux/sample_flags_i_post.dta", clear
drop _crossjoin
joinby _n using "$rais_aux/sample_flags_j_post.dta"
* Actually need to reload the cross-joined pairs
use "$rais_aux/sample_flags_i_post.dta", clear
joinby _crossjoin using "$rais_aux/sample_flags_j_post.dta"
drop _crossjoin
drop if identificad_i == identificad_j

merge 1:1 identificad_i identificad_j using "$rais_aux/bilateral_connectivity_post_raw.dta", keep(master match)
replace bilateral_conn_pw_post = 0 if _merge == 1
replace flows_post = 0 if _merge == 1
gen has_positive_flow_post = (_merge == 3)
drop _merge

merge m:1 identificad_i using "$rais_aux/firm_chars_post_i.dta", nogen keep(match master)
merge m:1 identificad_j using "$rais_aux/firm_chars_post_j.dta", nogen keep(match master)

* Create proximity measures (post-treatment characteristics)
gen size_proximity_post = -abs(l_avg_firm_emp_post_i - l_avg_firm_emp_post_j)
gen wage_proximity_post = -abs(l_avg_r_remdezr_post_i - l_avg_r_remdezr_post_j)
gen female_proximity_post = -abs(avg_prop_female_post_i - avg_prop_female_post_j)
gen nonwhite_proximity_post = -abs(avg_prop_nonwhite_post_i - avg_prop_nonwhite_post_j)
gen educ_proximity_post = -abs(avg_prop_sup_post_i - avg_prop_sup_post_j)
gen hs_proximity_post = -abs(avg_prop_hs_post_i - avg_prop_hs_post_j)
gen nhs_proximity_post = -abs(avg_prop_nhs_post_i - avg_prop_nhs_post_j)

* Geographic proximity
capture confirm file "$ibge/municipality_coordinates.dta"
if _rc == 0 {
    preserve
    use "$ibge/municipality_coordinates.dta", clear
    rename municipio municipio_i
    rename latitude lat_i
    rename longitude lon_i
    save "$rais_aux/coords_i_post.dta", replace
    restore

    merge m:1 municipio_i using "$rais_aux/coords_i_post.dta", nogen keep(match master)

    preserve
    use "$ibge/municipality_coordinates.dta", clear
    rename municipio municipio_j
    rename latitude lat_j
    rename longitude lon_j
    save "$rais_aux/coords_j_post.dta", replace
    restore

    merge m:1 municipio_j using "$rais_aux/coords_j_post.dta", nogen keep(match master)

    * Haversine distance
    gen lat1_rad = lat_i * _pi / 180
    gen lat2_rad = lat_j * _pi / 180
    gen lon1_rad = lon_i * _pi / 180
    gen lon2_rad = lon_j * _pi / 180
    gen dlat = lat2_rad - lat1_rad
    gen dlon = lon2_rad - lon1_rad
    gen a = sin(dlat/2)^2 + cos(lat1_rad) * cos(lat2_rad) * sin(dlon/2)^2
    gen c = 2 * asin(sqrt(a))
    gen geo_distance_post = 6371 * c
    gen geo_proximity_post = -geo_distance_post
    drop lat1_rad lat2_rad lon1_rad lon2_rad dlat dlon a c lat_i lon_i lat_j lon_j
}
else {
    gen geo_distance_post = .
    gen geo_proximity_post = .
}

* Same dummy variables
gen same_muni = (municipio_i == municipio_j)
gen same_microregion = (microregion_i == microregion_j)
gen same_union = (mode_union_i == mode_union_j) if !missing(mode_union_i) & !missing(mode_union_j)
gen same_big_industry = (big_industry_i == big_industry_j)
gen same_industry = (industry1_i == industry1_j)

compress
save "$rais_aux/bilateral_pairs_post.dta", replace

di "Saved: $rais_aux/bilateral_pairs_post.dta"

* ============================================================================
* CORRELATES ANALYSIS
* ============================================================================

di _newline "=== Correlates of Post-Treatment Bilateral Connectivity ==="

* Standardize variables
foreach var in bilateral_conn_pw_post geo_proximity_post size_proximity_post ///
               wage_proximity_post female_proximity_post nonwhite_proximity_post ///
               educ_proximity_post hs_proximity_post nhs_proximity_post {
    capture confirm variable `var'
    if _rc == 0 {
        qui sum `var'
        if r(sd) > 0 & !missing(r(sd)) {
            gen z_`var' = (`var' - r(mean)) / r(sd)
        }
    }
}

* Regression with firm i FE
capture confirm variable z_geo_proximity_post
if _rc == 0 {
    reghdfe z_bilateral_conn_pw_post z_geo_proximity_post z_size_proximity_post ///
            z_wage_proximity_post z_female_proximity_post z_nonwhite_proximity_post ///
            z_educ_proximity_post z_hs_proximity_post z_nhs_proximity_post ///
            same_muni same_microregion same_union same_industry same_big_industry, ///
            absorb(identificad_i) vce(robust)
    estimates store reg_bilateral_post
}
else {
    reghdfe z_bilateral_conn_pw_post z_size_proximity_post ///
            z_wage_proximity_post z_female_proximity_post z_nonwhite_proximity_post ///
            z_educ_proximity_post z_hs_proximity_post z_nhs_proximity_post ///
            same_muni same_microregion same_union same_industry same_big_industry, ///
            absorb(identificad_i) vce(robust)
    estimates store reg_bilateral_post
}

* Coefficient plot
capture confirm variable z_geo_proximity_post
if _rc == 0 {
    coefplot reg_bilateral_post, ///
        keep(z_geo_proximity_post z_size_proximity_post z_wage_proximity_post ///
             z_female_proximity_post z_nonwhite_proximity_post z_educ_proximity_post ///
             z_hs_proximity_post z_nhs_proximity_post ///
             same_muni same_microregion same_union same_industry same_big_industry) ///
        xline(0, lcolor(gs10)) ///
        mcolor(maroon) ciopts(lcolor(maroon)) ///
        xlabel(, format(%4.2f)) ///
        coeflabels(z_geo_proximity_post = "Geographic" ///
                   z_size_proximity_post = "Size" ///
                   z_wage_proximity_post = "Wage" ///
                   z_female_proximity_post = "% female" ///
                   z_nonwhite_proximity_post = "% non-white" ///
                   z_educ_proximity_post = "% higher ed." ///
                   z_hs_proximity_post = "% high school" ///
                   z_nhs_proximity_post = "% less than HS" ///
                   same_muni = "Same municipality" ///
                   same_microregion = "Same microregion" ///
                   same_union = "Same union" ///
                   same_industry = "Same industry" ///
                   same_big_industry = "Same broad industry") ///
        ytitle("") xtitle("Standardized Coefficient") ///
        title("Correlates of Post-Treatment Bilateral Connectivity") ///
        plotregion(color(white)) graphregion(color(white))
}
else {
    coefplot reg_bilateral_post, ///
        keep(z_size_proximity_post z_wage_proximity_post ///
             z_female_proximity_post z_nonwhite_proximity_post z_educ_proximity_post ///
             z_hs_proximity_post z_nhs_proximity_post ///
             same_muni same_microregion same_union same_industry same_big_industry) ///
        xline(0, lcolor(gs10)) ///
        mcolor(maroon) ciopts(lcolor(maroon)) ///
        xlabel(, format(%4.2f)) ///
        coeflabels(z_size_proximity_post = "Size" ///
                   z_wage_proximity_post = "Wage" ///
                   z_female_proximity_post = "% female" ///
                   z_nonwhite_proximity_post = "% non-white" ///
                   z_educ_proximity_post = "% higher ed." ///
                   z_hs_proximity_post = "% high school" ///
                   z_nhs_proximity_post = "% less than HS" ///
                   same_muni = "Same municipality" ///
                   same_microregion = "Same microregion" ///
                   same_union = "Same union" ///
                   same_industry = "Same industry" ///
                   same_big_industry = "Same broad industry") ///
        ytitle("") xtitle("Standardized Coefficient") ///
        title("Correlates of Post-Treatment Bilateral Connectivity") ///
        plotregion(color(white)) graphregion(color(white))
}
graph export "$graphs/connectivity/coefplot_bilateral_post.pdf", replace

di "Saved: $graphs/connectivity/coefplot_bilateral_post.pdf"

********************************************************************************
* PART 7: CLEAN UP TEMPORARY FILES
********************************************************************************

capture erase "$rais_aux/sample_establishments_post.dta"
capture erase "$rais_aux/sample_flags_i_post.dta"
capture erase "$rais_aux/sample_flags_j_post.dta"
capture erase "$rais_aux/firm_chars_2012_post.dta"
capture erase "$rais_aux/firm_chars_2013_post.dta"
capture erase "$rais_aux/firm_chars_2014_post.dta"
capture erase "$rais_aux/firm_chars_post_i.dta"
capture erase "$rais_aux/firm_chars_post_j.dta"
capture erase "$rais_aux/coords_i_post.dta"
capture erase "$rais_aux/coords_j_post.dta"

timer off 1
timer list

di _newline(2) "===== POST-TREATMENT CONNECTIVITY ANALYSIS COMPLETE ====="
di "Output files:"
di "  Data:"
di "    - $rais_aux/connectivity_treat_post_agg.dta"
di "    - $rais_aux/connectivity_pre_post_merged.dta"
di "    - $rais_aux/bilateral_connectivity_post_raw.dta"
di "    - $rais_aux/bilateral_pairs_post.dta"
di "  Tables:"
di "    - $tables/first_stage_flows.tex"
di "    - $tables/iv_first_stage.tex"
di "    - $tables/iv_wages_flows.tex"
di "  Graphs:"
di "    - $graphs/first_stage_flows_binscatter.pdf"
di "    - $graphs/coefplot_bilateral_post.pdf"
