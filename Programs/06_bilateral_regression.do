********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: BILATERAL CONNECTIVITY REGRESSION (COMPREHENSIVE)
* INPUT: CSV FROM PYTHON (06_bilateral_descriptives.py), CBA-RAIS FIRM DATA
* OUTPUT: BINSCATTER PLOTS, CORRELATION TABLE, COEFFICIENT PLOTS, REGRESSION TABLES
********************************************************************************

* This script imports the bilateral pairs data prepared by Python, merges in
* additional variables (numb_clauses), and performs full analysis including
* binscatter plots with residualized y-axis and regressions.

timer clear
timer on 1

set more off
set varabbrev off
clear all
version 17.0

* Define globals
global klc "/gpfs/kellogg/proj/lgg3230"
global main "$klc"
global rais_aux "$main/UnionSpill/Data/RAIS_aux"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global tables "$main/UnionSpill/Tables"
global graphs "$main/UnionSpill/Graphs"
global ibge "$main/UnionSpill/Data/IBGE"

********************************************************************************
* STEP 1: Import CSV data from Python
********************************************************************************

di _newline(2) "=== Importing bilateral pairs data from Python ==="

import delimited "$rais_aux/bilateral_pairs_descriptives.csv", clear stringcols(1 2)

* Check import
describe
summarize bilateral_conn_pw has_positive_flow, detail

di "Observations imported: " _N

* Save temporarily for merging
save "$rais_aux/bilateral_pairs_temp.dta", replace

********************************************************************************
* STEP 2: Merge numb_clauses from CBA-RAIS firm data (2009 pretreatment)
********************************************************************************

di _newline(2) "=== Merging numb_clauses from CBA-RAIS data ==="

* Extract numb_clauses for establishment i
use "$rais_firm/cba_rais_firm_2009_2016_flows_1.dta", clear
keep if year == 2009                                                              // Keep only 2009 (pretreatment)
keep identificad numb_clauses                                                     // Keep establishment ID and number of clauses
duplicates drop identificad, force                                                // Remove duplicates
rename identificad identificad_i                                                  // Rename for merge with establishment i
rename numb_clauses numb_clauses_2009_i                                           // Rename with suffix
save "$rais_aux/numb_clauses_i.dta", replace

* Extract numb_clauses for establishment j
use "$rais_firm/cba_rais_firm_2009_2016_flows_1.dta", clear
keep if year == 2009
keep identificad numb_clauses
duplicates drop identificad, force
rename identificad identificad_j                                                  // Rename for merge with establishment j
rename numb_clauses numb_clauses_2009_j                                           // Rename with suffix
save "$rais_aux/numb_clauses_j.dta", replace

* Merge back to bilateral pairs
use "$rais_aux/bilateral_pairs_temp.dta", clear

* Merge numb_clauses for establishment i
merge m:1 identificad_i using "$rais_aux/numb_clauses_i.dta", keep(master match) nogen

* Merge numb_clauses for establishment j
merge m:1 identificad_j using "$rais_aux/numb_clauses_j.dta", keep(master match) nogen

* Check merge results
count if !missing(numb_clauses_2009_i)
di "Establishments i with numb_clauses: " r(N)
count if !missing(numb_clauses_2009_j)
di "Establishments j with numb_clauses: " r(N)

* Save temporarily
save "$rais_aux/bilateral_pairs_temp2.dta", replace

********************************************************************************
* STEP 2b: Merge municipality codes and compute geographic proximity
********************************************************************************

di _newline(2) "=== Merging municipality codes and computing geo_proximity ==="

* Extract municipio for establishment i
use "$rais_firm/cba_rais_firm_2009_2016_flows_1.dta", clear
keep if year == 2009
keep identificad municipio
duplicates drop identificad, force
rename identificad identificad_i
rename municipio municipio_i
* Ensure municipio is numeric
capture confirm string variable municipio_i
if _rc == 0 {
    destring municipio_i, replace force
}
save "$rais_aux/municipio_i.dta", replace

* Extract municipio for establishment j
use "$rais_firm/cba_rais_firm_2009_2016_flows_1.dta", clear
keep if year == 2009
keep identificad municipio
duplicates drop identificad, force
rename identificad identificad_j
rename municipio municipio_j
* Ensure municipio is numeric
capture confirm string variable municipio_j
if _rc == 0 {
    destring municipio_j, replace force
}
save "$rais_aux/municipio_j.dta", replace

* Merge municipio back to bilateral pairs
use "$rais_aux/bilateral_pairs_temp2.dta", clear
merge m:1 identificad_i using "$rais_aux/municipio_i.dta", keep(master match) nogen
merge m:1 identificad_j using "$rais_aux/municipio_j.dta", keep(master match) nogen

* Check if municipality coordinates file exists
capture confirm file "$ibge/municipality_coordinates.dta"

if _rc == 0 {
    di "Municipality coordinates file found. Computing geographic proximity..."

    * Load coordinates and merge for i
    preserve
    use "$ibge/municipality_coordinates.dta", clear
    rename municipio municipio_i
    rename latitude lat_i
    rename longitude lon_i
    save "$rais_aux/coords_i.dta", replace
    restore

    merge m:1 municipio_i using "$rais_aux/coords_i.dta", keep(master match) nogen

    * Load coordinates and merge for j
    preserve
    use "$ibge/municipality_coordinates.dta", clear
    rename municipio municipio_j
    rename latitude lat_j
    rename longitude lon_j
    save "$rais_aux/coords_j.dta", replace
    restore

    merge m:1 municipio_j using "$rais_aux/coords_j.dta", keep(master match) nogen

    * Compute Haversine distance (in km)
    * Formula: 2 * R * arcsin(sqrt(sin^2((lat2-lat1)/2) + cos(lat1)*cos(lat2)*sin^2((lon2-lon1)/2)))
    * R = 6371 km (Earth radius)

    gen lat1_rad = lat_i * _pi / 180
    gen lat2_rad = lat_j * _pi / 180
    gen lon1_rad = lon_i * _pi / 180
    gen lon2_rad = lon_j * _pi / 180

    gen dlat = lat2_rad - lat1_rad
    gen dlon = lon2_rad - lon1_rad

    gen a = sin(dlat/2)^2 + cos(lat1_rad) * cos(lat2_rad) * sin(dlon/2)^2
    gen c = 2 * asin(sqrt(a))
    gen geo_distance = 6371 * c

    * Geographic proximity (negative of distance: higher = closer)
    gen geo_proximity = -geo_distance
    label var geo_proximity "Geographic proximity (negative km)"

    * Clean up temp variables
    drop lat1_rad lat2_rad lon1_rad lon2_rad dlat dlon a c lat_i lon_i lat_j lon_j

    * Summary
    count if !missing(geo_proximity)
    di "Pairs with geo_proximity: " r(N)
    summarize geo_distance geo_proximity, detail
}
else {
    di "Municipality coordinates file not found. Skipping geographic proximity."
    di "To enable, provide: $ibge/municipality_coordinates.dta"
    gen geo_distance = .
    gen geo_proximity = .
}

* create log geographic proximity measures
gen l_geo_distance = log(geo_distance)
replace l_geo_distance = 0 if l_geo_distance==.

gen l_geo_proximity = -l_geo_distance
********************************************************************************
* STEP 3: Create clauses_proximity measure
********************************************************************************

di _newline(2) "=== Creating clauses_proximity measure ==="

* Clauses proximity: negative absolute difference in pretreatment numb_clauses
gen clauses_proximity = -abs(numb_clauses_2009_i - numb_clauses_2009_j) ///
    if !missing(numb_clauses_2009_i) & !missing(numb_clauses_2009_j)

label var clauses_proximity "CBA clauses proximity (negative |diff|)"

summarize clauses_proximity numb_clauses_2009_i numb_clauses_2009_j, detail

********************************************************************************
* STEP 4: Compute residualized bilateral connectivity (firm i FE)
********************************************************************************

di _newline(2) "=== Computing residualized bilateral connectivity (firm i FE) ==="

* Check if reghdfe is installed
capture which reghdfe
if _rc != 0 {
    di as error "reghdfe not installed. Please run: ssc install reghdfe"
    exit 1
}

* Use reghdfe to partial out firm i fixed effects
qui reghdfe bilateral_conn_pw, absorb(identificad_i) resid(bilateral_conn_resid)

* Check residuals
summarize bilateral_conn_pw bilateral_conn_resid, detail

********************************************************************************
* STEP 5: Standardize variables for regression
********************************************************************************

di _newline(2) "=== Standardizing variables ==="

* Standardize continuous variables (including geo_proximity)
foreach var in bilateral_conn_pw geo_proximity size_proximity wage_proximity ///
               female_proximity nonwhite_proximity educ_proximity ///
               hs_proximity nhs_proximity clauses_proximity {
    capture confirm variable `var'
    if _rc == 0 {
        qui sum `var'
        if r(sd) > 0 & !missing(r(sd)) {
            gen z_`var' = (`var' - r(mean)) / r(sd)
            label var z_`var' "Standardized `var'"
        }
    }
}

********************************************************************************
* STEP 6: Run INDIVIDUAL regressions with establishment i fixed effects
*         and generate binscatters with slope coefficients
********************************************************************************

di _newline(2) "=== Running individual regressions and generating binscatters ==="

* Check if binscatter is installed
capture which binscatter
if _rc != 0 {
    di as error "binscatter not installed. Please run: ssc install binscatter"
}

* Set publication-quality scheme
set scheme s2color

* Create temporary file to store individual regression coefficients
tempname indiv_coef_hold
tempfile indiv_coef_data
postfile `indiv_coef_hold' str50 variable str20 var_type coef se ci_lower ci_upper str30 spec r2 using `indiv_coef_data'

* Define proximity variables and their labels/titles
local prox_vars "geo_proximity size_proximity wage_proximity female_proximity nonwhite_proximity educ_proximity hs_proximity nhs_proximity clauses_proximity"
local prox_xtitles `" "Geographic Proximity (negative km)" "Size Proximity (negative |log emp diff|)" "Wage Proximity (negative |log wage diff|)" "% Female Proximity" "% Non-white Proximity" "% Higher Education Proximity" "% High School Proximity" "% Less than High School Proximity" "CBA Clauses Proximity (negative |diff|)" "'

* Loop over proximity variables for individual regressions and binscatters
local i = 1
foreach var of local prox_vars {
    
    * Check if variable exists
    capture confirm variable z_`var'
    if _rc == 0 {
        
        * Count non-missing observations
        qui count if !missing(z_`var') & !missing(z_bilateral_conn_pw)
        local n_obs = r(N)
        
        if `n_obs' > 0 {
            
            di _newline "=== Individual regression: z_bilateral_conn_pw on z_`var' ==="
            
            * Run individual regression with firm i FE
            qui reghdfe z_bilateral_conn_pw z_`var', absorb(identificad_i) vce(robust)

            * Extract coefficient, SE, and R-squared
            local coef = _b[z_`var']
            local se = _se[z_`var']
            local ci_lower = `coef' - 1.96 * `se'
            local ci_upper = `coef' + 1.96 * `se'
            local r2 = e(r2)

            * Store in results file
            post `indiv_coef_hold' ("z_`var'") ("proximity") (`coef') (`se') (`ci_lower') (`ci_upper') ("individual") (`r2')
            
            * Display results
            di "  Coefficient: " %7.4f `coef'
            di "  Std. Error:  " %7.4f `se'
            
            * Get x-axis title
            local xtitle : word `i' of `prox_xtitles'
            
            * Create binscatter with coefficient annotation
            binscatter bilateral_conn_resid `var', nquantiles(20) ///
                xtitle("`xtitle'") ///
                ytitle("Bilateral Connectivity (residualized)") ///
                mcolor(navy) lcolor(navy) ///
                plotregion(color(white)) graphregion(color(white)) ///
                note("{it:β} = `: di %7.4f `coef'' (`: di %7.4f `se'')", size(small))
            
            graph export "$graphs/binscatter_conn_`var'.pdf", replace
            di "Saved: $graphs/binscatter_conn_`var'.pdf"
        }
    }
    
    local i = `i' + 1
}

* Define dummy variables
local dummy_vars "same_muni same_microregion same_union same_industry same_industry_micro"

* Loop over dummy variables for individual regressions (no binscatters)
foreach var of local dummy_vars {
    
    * Check if variable exists
    capture confirm variable `var'
    if _rc == 0 {
        
        * Count non-missing observations
        qui count if !missing(`var') & !missing(z_bilateral_conn_pw)
        local n_obs = r(N)
        
        if `n_obs' > 0 {
            
            di _newline "=== Individual regression: z_bilateral_conn_pw on `var' ==="
            
            * Run individual regression with firm i FE
            qui reghdfe z_bilateral_conn_pw `var', absorb(identificad_i) vce(robust)

            * Extract coefficient, SE, and R-squared
            local coef = _b[`var']
            local se = _se[`var']
            local ci_lower = `coef' - 1.96 * `se'
            local ci_upper = `coef' + 1.96 * `se'
            local r2 = e(r2)

            * Store in results file
            post `indiv_coef_hold' ("`var'") ("dummy") (`coef') (`se') (`ci_lower') (`ci_upper') ("individual") (`r2')
            
            * Display results
            di "  Coefficient: " %7.4f `coef'
            di "  Std. Error:  " %7.4f `se'
        }
    }
}

postclose `indiv_coef_hold'

* Save individual regression coefficients
preserve
use `indiv_coef_data', clear
export delimited using "$rais_aux/bilateral_individual_coefficients.csv", replace
di _newline "Saved: $rais_aux/bilateral_individual_coefficients.csv"
restore

********************************************************************************
* STEP 7: Compute correlations and generate LaTeX table
********************************************************************************

di _newline(2) "=== Computing correlations ==="

* Create temporary file to store correlations
tempname memhold
tempfile corr_results
postfile `memhold' str30 variable corr n using `corr_results'

* Correlation with geographic proximity
count if !missing(geo_proximity)
if r(N) > 0 {
    qui corr bilateral_conn_pw geo_proximity
    local corr_geo = r(rho)
    qui count if !missing(bilateral_conn_pw) & !missing(geo_proximity)
    local n_geo = r(N)
    post `memhold' ("Geographic proximity") (`corr_geo') (`n_geo')
}

* Correlation with size proximity
qui corr bilateral_conn_pw size_proximity
local corr_size = r(rho)
qui count if !missing(bilateral_conn_pw) & !missing(size_proximity)
local n_size = r(N)
post `memhold' ("Size proximity") (`corr_size') (`n_size')

* Correlation with wage proximity
capture confirm variable wage_proximity
if _rc == 0 {
    qui corr bilateral_conn_pw wage_proximity
    local corr_wage = r(rho)
    qui count if !missing(bilateral_conn_pw) & !missing(wage_proximity)
    local n_wage = r(N)
    post `memhold' ("Wage proximity") (`corr_wage') (`n_wage')
}

* Correlation with female proximity
qui corr bilateral_conn_pw female_proximity
local corr_female = r(rho)
qui count if !missing(bilateral_conn_pw) & !missing(female_proximity)
local n_female = r(N)
post `memhold' ("% female proximity") (`corr_female') (`n_female')

* Correlation with nonwhite proximity
qui corr bilateral_conn_pw nonwhite_proximity
local corr_nonwhite = r(rho)
qui count if !missing(bilateral_conn_pw) & !missing(nonwhite_proximity)
local n_nonwhite = r(N)
post `memhold' ("% non-white proximity") (`corr_nonwhite') (`n_nonwhite')

* Correlation with higher education proximity
qui corr bilateral_conn_pw educ_proximity
local corr_educ = r(rho)
qui count if !missing(bilateral_conn_pw) & !missing(educ_proximity)
local n_educ = r(N)
post `memhold' ("% higher ed. proximity") (`corr_educ') (`n_educ')

* Correlation with high school proximity
qui corr bilateral_conn_pw hs_proximity
local corr_hs = r(rho)
qui count if !missing(bilateral_conn_pw) & !missing(hs_proximity)
local n_hs = r(N)
post `memhold' ("% high school proximity") (`corr_hs') (`n_hs')

* Correlation with less than high school proximity
qui corr bilateral_conn_pw nhs_proximity
local corr_nhs = r(rho)
qui count if !missing(bilateral_conn_pw) & !missing(nhs_proximity)
local n_nhs = r(N)
post `memhold' ("% less than HS proximity") (`corr_nhs') (`n_nhs')

* Correlation with clauses proximity
count if !missing(clauses_proximity)
if r(N) > 0 {
    qui corr bilateral_conn_pw clauses_proximity
    local corr_clauses = r(rho)
    qui count if !missing(bilateral_conn_pw) & !missing(clauses_proximity)
    local n_clauses = r(N)
    post `memhold' ("CBA clauses proximity") (`corr_clauses') (`n_clauses')
}

postclose `memhold'

* Display correlation table
preserve
use `corr_results', clear
di _newline(2) "=== Correlation Table: Bilateral Connectivity vs Proximity Measures ==="
list variable corr n, noobs sep(0)

* Generate LaTeX table
capture file close latex_table
file open latex_table using "$tables/correlation_bilateral_connectivity.txt", write replace

file write latex_table "\begin{table}[htbp]" _newline
file write latex_table "\centering" _newline
file write latex_table "\begin{threeparttable}" _newline
file write latex_table "\caption{Correlation between Bilateral Connectivity and Proximity Measures}" _newline
file write latex_table "\label{tab:corr_bilateral}" _newline
file write latex_table "\footnotesize" _newline
file write latex_table "\begin{tabular}{lcc}" _newline
file write latex_table "\hline\hline" _newline
file write latex_table "Proximity Measure & Correlation & N \\\\" _newline
file write latex_table "\hline" _newline

local nrows = _N
forvalues i = 1/`nrows' {
    local var = variable[`i']
    local c = corr[`i']
    local n_obs = n[`i']
    file write latex_table "`var' & " %6.3f (`c') " & " %9.0fc (`n_obs') " \\\\" _newline
}

file write latex_table "\hline\hline" _newline
file write latex_table "\end{tabular}" _newline
file write latex_table "\begin{tablenotes}" _newline
file write latex_table "\footnotesize" _newline
file write latex_table "\item \textit{Notes:} Pearson correlations between bilateral connectivity and proximity measures. Sample includes all establishment pairs (including zeros)." _newline
file write latex_table "\end{tablenotes}" _newline
file write latex_table "\end{threeparttable}" _newline
file write latex_table "\end{table}" _newline
file close latex_table

di _newline "Saved: $tables/correlation_bilateral_connectivity.txt"
restore

********************************************************************************
* STEP 8: Run MULTIVARIATE regressions with establishment i fixed effects
********************************************************************************

di _newline(2) "=== Running multivariate regressions with establishment FE ==="

* Specification 1: With industry x microregion interaction
di _newline(2) "=== Regression 1: With industry x microregion interaction ==="
reghdfe z_bilateral_conn_pw ///
    z_geo_proximity z_size_proximity z_wage_proximity ///
    z_female_proximity z_nonwhite_proximity z_educ_proximity ///
    z_hs_proximity z_nhs_proximity z_clauses_proximity ///
    same_muni same_microregion same_union same_industry same_industry_micro, ///
    absorb(identificad_i) vce(robust)

estimates store main_reg

* Specification 2: Without industry x microregion interaction
di _newline(2) "=== Regression 2: Without industry x microregion interaction ==="
reghdfe z_bilateral_conn_pw ///
    z_geo_proximity z_size_proximity z_wage_proximity ///
    z_female_proximity z_nonwhite_proximity z_educ_proximity ///
    z_hs_proximity z_nhs_proximity z_clauses_proximity ///
    same_muni same_microregion same_union same_industry, ///
    absorb(identificad_i) vce(robust)

estimates store main_reg_no_intx

********************************************************************************
* STEP 9: Create coefficient plots (multivariate regressions)
********************************************************************************

di _newline(2) "=== Creating coefficient plots ==="

* Check if coefplot is installed
capture which coefplot
if _rc != 0 {
    di as error "coefplot not installed. Please run: ssc install coefplot"
    exit 1
}

* Coefficient plot 1: With industry x microregion interaction
coefplot main_reg, ///
    keep(z_geo_proximity z_size_proximity z_wage_proximity ///
         z_female_proximity z_nonwhite_proximity z_educ_proximity ///
         z_hs_proximity z_nhs_proximity z_clauses_proximity ///
         same_muni same_microregion same_union same_industry same_industry_micro) ///
    xline(0, lcolor(gs10)) ///
    mcolor(navy) ciopts(lcolor(navy)) ///
    xlabel(, format(%4.2f)) ///
    coeflabels(z_geo_proximity = "Geographic" ///
               z_size_proximity = "Size" ///
               z_wage_proximity = "Wage" ///
               z_female_proximity = "% female" ///
               z_nonwhite_proximity = "% non-white" ///
               z_educ_proximity = "% higher ed." ///
               z_hs_proximity = "% high school" ///
               z_nhs_proximity = "% less than HS" ///
               z_clauses_proximity = "CBA clauses" ///
               same_muni = "Same municipality" ///
               same_microregion = "Same microregion" ///
               same_union = "Same union" ///
               same_industry = "Same industry" ///
               same_industry_micro = "Same industry x microregion") ///
    ytitle("") xtitle("Standardized Coefficient") ///
    plotregion(color(white)) graphregion(color(white))

graph export "$graphs/coefplot_bilateral_regression.pdf", replace
di _newline "Saved: $graphs/coefplot_bilateral_regression.pdf"

* Coefficient plot 2: Without industry x microregion interaction
coefplot main_reg_no_intx, ///
    keep(z_geo_proximity z_size_proximity z_wage_proximity ///
         z_female_proximity z_nonwhite_proximity z_educ_proximity ///
         z_hs_proximity z_nhs_proximity z_clauses_proximity ///
         same_muni same_microregion same_union same_industry) ///
    xline(0, lcolor(gs10)) ///
    mcolor(maroon) ciopts(lcolor(maroon)) ///
    xlabel(, format(%4.2f)) ///
    coeflabels(z_geo_proximity = "Geographic" ///
               z_size_proximity = "Size" ///
               z_wage_proximity = "Wage" ///
               z_female_proximity = "% female" ///
               z_nonwhite_proximity = "% non-white" ///
               z_educ_proximity = "% higher ed." ///
               z_hs_proximity = "% high school" ///
               z_nhs_proximity = "% less than HS" ///
               z_clauses_proximity = "CBA clauses" ///
               same_muni = "Same municipality" ///
               same_microregion = "Same microregion" ///
               same_union = "Same union" ///
               same_industry = "Same industry") ///
    ytitle("") xtitle("Standardized Coefficient") ///
    plotregion(color(white)) graphregion(color(white))

graph export "$graphs/coefplot_bilateral_regression_no_intx.pdf", replace
di "Saved: $graphs/coefplot_bilateral_regression_no_intx.pdf"

********************************************************************************
* STEP 10: Export regression results to LaTeX
********************************************************************************

di _newline(2) "=== Exporting regression results ==="

* Export using esttab if available
capture which esttab
if _rc == 0 {
    * Export both specifications side by side
    esttab main_reg main_reg_no_intx using "$tables/bilateral_regression.tex", ///
        replace label ///
        b(3) se(3) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        title("Bilateral Connectivity and Establishment Proximity") ///
        mtitles("With Ind x Micro" "Without Ind x Micro") ///
        scalars("N Observations" "r2 R-squared") ///
        note("Robust standard errors in parentheses. Establishment i fixed effects absorbed.")
    di "Saved: $tables/bilateral_regression.tex"
}
else {
    di "esttab not installed. Skipping LaTeX export."
}

********************************************************************************
* STEP 11: Export multivariate coefficients to CSV for Python plotting
********************************************************************************

di _newline(2) "=== Exporting multivariate coefficients to CSV for Python ==="

* Create dataset with coefficients from main_reg (with industry x microregion)
tempname coef_hold
tempfile coef_data
postfile `coef_hold' str50 variable str20 var_type coef se ci_lower ci_upper str30 spec r2 using `coef_data'

* Restore main_reg estimates and extract coefficients
estimates restore main_reg
matrix b = e(b)
matrix V = e(V)
local varnames : colnames b
local r2_with_intx = e(r2)

foreach var of local varnames {
    if "`var'" != "_cons" {
        * Get coefficient and SE
        local coef = b[1, colnumb(b, "`var'")]
        local se = sqrt(V[colnumb(V, "`var'"), colnumb(V, "`var'")])
        local ci_lower = `coef' - 1.96 * `se'
        local ci_upper = `coef' + 1.96 * `se'

        * Determine variable type (proximity vs dummy)
        local var_type = "proximity"
        if inlist("`var'", "same_muni", "same_microregion", "same_union", "same_industry", "same_industry_micro") {
            local var_type = "dummy"
        }

        post `coef_hold' ("`var'") ("`var_type'") (`coef') (`se') (`ci_lower') (`ci_upper') ("with_intx") (`r2_with_intx')
    }
}

* Restore main_reg_no_intx estimates and extract coefficients
estimates restore main_reg_no_intx
matrix b = e(b)
matrix V = e(V)
local varnames : colnames b
local r2_no_intx = e(r2)

foreach var of local varnames {
    if "`var'" != "_cons" {
        * Get coefficient and SE
        local coef = b[1, colnumb(b, "`var'")]
        local se = sqrt(V[colnumb(V, "`var'"), colnumb(V, "`var'")])
        local ci_lower = `coef' - 1.96 * `se'
        local ci_upper = `coef' + 1.96 * `se'

        * Determine variable type (proximity vs dummy)
        local var_type = "proximity"
        if inlist("`var'", "same_muni", "same_microregion", "same_union", "same_industry", "same_industry_micro") {
            local var_type = "dummy"
        }

        post `coef_hold' ("`var'") ("`var_type'") (`coef') (`se') (`ci_lower') (`ci_upper') ("without_intx") (`r2_no_intx')
    }
}

postclose `coef_hold'

* Save to CSV
preserve
use `coef_data', clear
export delimited using "$rais_aux/bilateral_regression_coefficients.csv", replace
di "Saved: $rais_aux/bilateral_regression_coefficients.csv"
restore

********************************************************************************
* STEP 12: Clean up temporary files
********************************************************************************

capture erase "$rais_aux/bilateral_pairs_temp.dta"
capture erase "$rais_aux/bilateral_pairs_temp2.dta"
capture erase "$rais_aux/numb_clauses_i.dta"
capture erase "$rais_aux/numb_clauses_j.dta"
capture erase "$rais_aux/municipio_i.dta"
capture erase "$rais_aux/municipio_j.dta"
capture erase "$rais_aux/coords_i.dta"
capture erase "$rais_aux/coords_j.dta"

********************************************************************************
* DONE
********************************************************************************

timer off 1
timer list

di _newline(2) "=== Bilateral Regression Analysis Complete ==="
di _newline "Output files:"
di _newline "Binscatter plots (with slope coefficients):"
di "  - $graphs/binscatter_conn_geo_proximity.pdf"
di "  - $graphs/binscatter_conn_size_proximity.pdf"
di "  - $graphs/binscatter_conn_wage_proximity.pdf"
di "  - $graphs/binscatter_conn_female_proximity.pdf"
di "  - $graphs/binscatter_conn_nonwhite_proximity.pdf"
di "  - $graphs/binscatter_conn_educ_proximity.pdf"
di "  - $graphs/binscatter_conn_hs_proximity.pdf"
di "  - $graphs/binscatter_conn_nhs_proximity.pdf"
di "  - $graphs/binscatter_conn_clauses_proximity.pdf"
di _newline "Tables and coefficient plots:"
di "  - $tables/correlation_bilateral_connectivity.txt"
di "  - $graphs/coefplot_bilateral_regression.pdf (multivariate, with industry x microregion)"
di "  - $graphs/coefplot_bilateral_regression_no_intx.pdf (multivariate, without industry x microregion)"
di "  - $tables/bilateral_regression.tex (both multivariate specifications)"
di _newline "Coefficient data for Python plotting:"
di "  - $rais_aux/bilateral_regression_coefficients.csv (multivariate)"
di "  - $rais_aux/bilateral_individual_coefficients.csv (individual regressions)"
di _newline "Run: python Programs/06_bilateral_coefplot.py"
