********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: BILATERAL CONNECTIVITY REGRESSION - GRAVITY SPECIFICATION
* INPUT: PREPARED DATA FROM PYTHON (06_bilateral_data_prep.py)
* OUTPUT: COEFFICIENT PLOTS, REGRESSION TABLES
*
* METHODOLOGY:
* This script implements a gravity-style specification for validating the
* bilateral connectivity measure. The connectivity measure C_ij has a symmetric
* numerator (total flows between i and j) but asymmetric denominator (employment
* at firm i), so C_ij != C_ji. Data includes both directed pairs (i,j) and (j,i).
*
* FIXED EFFECTS STRUCTURE:
* - Reference firm FE (identificad_i): Controls for firm i's size, turnover
*   propensity, and tendency to have workers with outside options
* - Connected firm FE (identificad_j): Controls for firm j's general
*   "popularity" as an outside option destination
*
* STANDARD ERRORS:
* Two-way clustering at reference firm and connected firm levels
*
* NOTE: Data preparation (merges, reshaping, standardization) is done in Python
* using DuckDB for efficiency. This script only runs regressions.
********************************************************************************

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
global tables "$main/UnionSpill/Tables"
global graphs "$main/UnionSpill/Graphs"

* Check for parallel package (optional speedup)
capture which parallel
if _rc != 0 {
    di as text "Note: parallel package not installed. Running without parallelization."
    di as text "To enable, run: ssc install parallel"
    local use_parallel = 0
}
else {
    local use_parallel = 1
    local n_cores = 4
}

********************************************************************************
* STEP 1: Load prepared data from Python
********************************************************************************

di _newline(2) "=== Loading prepared data from Python/DuckDB ==="

* Load parquet file from /tmp (due to disk quota constraints)
* IMPORTANT: Run this immediately after Python data prep - /tmp is cleared periodically
import parquet "/tmp/bilateral_pairs_gravity_ready.parquet", clear

describe
di _newline "Observations: " _N

********************************************************************************
* STEP 1b: Merge supplementary CEP and turnover proximity data
********************************************************************************

di _newline(2) "=== Merging supplementary CEP and turnover proximity data ==="

* Merge with supplementary data (CEP-based distance and turnover proximity)
merge 1:1 identificad_i identificad_j using "$rais_aux/bilateral_cep_turnover.dta", ///
    keep(master match) nogen

* Check merge results
count if !missing(z_cep_proximity)
di "Pairs with CEP proximity: " r(N)
count if !missing(z_turnover_proximity)
di "Pairs with turnover proximity: " r(N)

* Quick summary of key variables
summarize z_bilateral_conn_pw z_cep_proximity z_turnover_proximity z_size_proximity, separator(0)

********************************************************************************
* STEP 2: Run UNIVARIATE regressions with two-way fixed effects
********************************************************************************

di _newline(2) "=== Running univariate regressions with two-way FE ==="

* Check if reghdfe is installed
capture which reghdfe
if _rc != 0 {
    di as error "reghdfe not installed. Please run: ssc install reghdfe"
    exit 1
}

* Create file to store univariate regression coefficients
tempname univ_coef_hold
tempfile univ_coef_data
postfile `univ_coef_hold' str50 variable str20 var_type double coef double se ///
    double ci_lower double ci_upper str30 spec double r2 double n ///
    using `univ_coef_data'

* Define proximity variables (standardized)
* NOTE: z_cep_proximity replaces z_geo_proximity, z_turnover_proximity added
local prox_vars "z_cep_proximity z_turnover_proximity z_size_proximity z_wage_proximity z_female_proximity z_nonwhite_proximity z_educ_proximity z_hs_proximity z_clauses_proximity"

* Define dummy variables
local dummy_vars "same_microregion same_union same_industry same_industry_micro"

di _newline "--- Univariate regressions: Proximity variables ---"

foreach var of local prox_vars {

    capture confirm variable `var'
    if _rc == 0 {

        qui count if !missing(`var') & !missing(z_bilateral_conn_pw)
        local n_obs = r(N)

        if `n_obs' > 100 {

            di _newline "=== z_bilateral_conn_pw ~ `var' ==="

            if `use_parallel' == 1 {
                qui reghdfe z_bilateral_conn_pw `var', ///
                    absorb(identificad_i identificad_j) ///
                    vce(cluster identificad_i identificad_j) ///
                    parallel(`n_cores') nosample
            }
            else {
                qui reghdfe z_bilateral_conn_pw `var', ///
                    absorb(identificad_i identificad_j) ///
                    vce(cluster identificad_i identificad_j) nosample
            }

            local coef = _b[`var']
            local se = _se[`var']
            local ci_lower = `coef' - 1.96 * `se'
            local ci_upper = `coef' + 1.96 * `se'
            local r2 = e(r2)
            local n = e(N)

            post `univ_coef_hold' ("`var'") ("proximity") (`coef') (`se') ///
                (`ci_lower') (`ci_upper') ("univariate_twoway") (`r2') (`n')

            di "  β = " %9.6f `coef' " (SE = " %9.6f `se' ")"
            di "  R² = " %9.6f `r2' ", N = " %12.0fc `n'
        }
    }
}

di _newline "--- Univariate regressions: Dummy variables ---"

foreach var of local dummy_vars {

    capture confirm variable `var'
    if _rc == 0 {

        qui count if !missing(`var') & !missing(z_bilateral_conn_pw)
        local n_obs = r(N)

        if `n_obs' > 100 {

            di _newline "=== z_bilateral_conn_pw ~ `var' ==="

            if `use_parallel' == 1 {
                qui reghdfe z_bilateral_conn_pw `var', ///
                    absorb(identificad_i identificad_j) ///
                    vce(cluster identificad_i identificad_j) ///
                    parallel(`n_cores') nosample
            }
            else {
                qui reghdfe z_bilateral_conn_pw `var', ///
                    absorb(identificad_i identificad_j) ///
                    vce(cluster identificad_i identificad_j) nosample
            }

            local coef = _b[`var']
            local se = _se[`var']
            local ci_lower = `coef' - 1.96 * `se'
            local ci_upper = `coef' + 1.96 * `se'
            local r2 = e(r2)
            local n = e(N)

            post `univ_coef_hold' ("`var'") ("dummy") (`coef') (`se') ///
                (`ci_lower') (`ci_upper') ("univariate_twoway") (`r2') (`n')

            di "  β = " %9.6f `coef' " (SE = " %9.6f `se' ")"
            di "  R² = " %9.6f `r2' ", N = " %12.0fc `n'
        }
    }
}

postclose `univ_coef_hold'

* Save univariate coefficients
preserve
use `univ_coef_data', clear
export delimited using "$rais_aux/bilateral_univariate_coefficients_gravity.csv", replace
di _newline "Saved: $rais_aux/bilateral_univariate_coefficients_gravity.csv"
restore

********************************************************************************
* STEP 3: Run MULTIVARIATE regression with two-way fixed effects
********************************************************************************

di _newline(2) "=== Running multivariate regression with two-way FE ==="

* Build regressor list from available variables
local prox_regressors ""
foreach var of local prox_vars {
    capture confirm variable `var'
    if _rc == 0 {
        local prox_regressors "`prox_regressors' `var'"
    }
}

local dummy_regressors ""
foreach var of local dummy_vars {
    capture confirm variable `var'
    if _rc == 0 {
        local dummy_regressors "`dummy_regressors' `var'"
    }
}

di "Proximity regressors: `prox_regressors'"
di "Dummy regressors: `dummy_regressors'"

* Run multivariate regression
di _newline "=== Multivariate: Two-way FE (Reference firm + Connected firm) ==="

if `use_parallel' == 1 {
    reghdfe z_bilateral_conn_pw `prox_regressors' `dummy_regressors', ///
        absorb(identificad_i identificad_j) ///
        vce(cluster identificad_i identificad_j) ///
        parallel(`n_cores')
}
else {
    reghdfe z_bilateral_conn_pw `prox_regressors' `dummy_regressors', ///
        absorb(identificad_i identificad_j) ///
        vce(cluster identificad_i identificad_j)
}

estimates store gravity_twoway
local r2_twoway = e(r2)
local n_twoway = e(N)

********************************************************************************
* STEP 4: Export multivariate coefficients to CSV
********************************************************************************

di _newline(2) "=== Exporting multivariate coefficients ==="

tempname coef_hold
tempfile coef_data
postfile `coef_hold' str50 variable str20 var_type double coef double se ///
    double ci_lower double ci_upper str30 spec double r2 double n ///
    using `coef_data'

estimates restore gravity_twoway
matrix b = e(b)
matrix V = e(V)
local varnames : colnames b
local r2 = e(r2)
local n = e(N)

foreach var of local varnames {
    if "`var'" != "_cons" {
        local coef = b[1, colnumb(b, "`var'")]
        local se = sqrt(V[colnumb(V, "`var'"), colnumb(V, "`var'")])
        local ci_lower = `coef' - 1.96 * `se'
        local ci_upper = `coef' + 1.96 * `se'

        local var_type = "proximity"
        if inlist("`var'", "same_microregion", "same_union", "same_industry", "same_industry_micro") {
            local var_type = "dummy"
        }

        post `coef_hold' ("`var'") ("`var_type'") (`coef') (`se') ///
            (`ci_lower') (`ci_upper') ("multivariate_twoway") (`r2') (`n')
    }
}

postclose `coef_hold'

preserve
use `coef_data', clear
export delimited using "$rais_aux/bilateral_multivariate_coefficients_gravity.csv", replace
di "Saved: $rais_aux/bilateral_multivariate_coefficients_gravity.csv"
restore

********************************************************************************
* STEP 5: Create coefficient plot
********************************************************************************

di _newline(2) "=== Creating coefficient plot ==="

capture which coefplot
if _rc != 0 {
    di as text "coefplot not installed. Skipping plot. Run: ssc install coefplot"
}
else {
    set scheme s2color

    coefplot gravity_twoway, ///
        keep(z_cep_proximity z_turnover_proximity z_size_proximity z_wage_proximity ///
             z_female_proximity z_nonwhite_proximity z_educ_proximity ///
             z_hs_proximity z_clauses_proximity ///
             same_microregion same_union same_industry same_industry_micro) ///
        xline(0, lcolor(gs10)) ///
        mcolor(navy) ciopts(lcolor(navy)) ///
        xlabel(, format(%5.3f)) ///
        coeflabels(z_cep_proximity = "CEP proximity" ///
                   z_turnover_proximity = "Turnover proximity" ///
                   z_size_proximity = "Size proximity" ///
                   z_wage_proximity = "Wage proximity" ///
                   z_female_proximity = "% Female proximity" ///
                   z_nonwhite_proximity = "% Non-white proximity" ///
                   z_educ_proximity = "% Higher ed. proximity" ///
                   z_hs_proximity = "% High school proximity" ///
                   z_clauses_proximity = "CBA clauses proximity" ///
                   same_microregion = "Same microregion" ///
                   same_union = "Same union" ///
                   same_industry = "Same industry" ///
                   same_industry_micro = "Same industry × microregion") ///
        ytitle("") xtitle("Standardized Coefficient") ///
        title("Bilateral Connectivity: Gravity Specification") ///
        subtitle("Two-way FE (Ref. firm + Conn. firm), Two-way clustered SE") ///
        plotregion(color(white)) graphregion(color(white)) ///
        note("N = `n_twoway'. R² = `: di %5.4f `r2_twoway''")

    graph export "$graphs/coefplot_bilateral_gravity.pdf", replace
    di "Saved: $graphs/coefplot_bilateral_gravity.pdf"
}

********************************************************************************
* STEP 6: Export to LaTeX
********************************************************************************

di _newline(2) "=== Exporting to LaTeX ==="

capture which esttab
if _rc == 0 {
    esttab gravity_twoway using "$tables/bilateral_regression_gravity.tex", ///
        replace label b(4) se(4) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        title("Bilateral Connectivity: Gravity Specification") ///
        mtitles("Two-way FE") ///
        scalars("N Observations" "r2 R-squared") ///
        addnotes("Two-way clustered SE (ref. firm × conn. firm)." ///
                 "Reference and connected firm FE absorbed." ///
                 "All proximity measures standardized.")
    di "Saved: $tables/bilateral_regression_gravity.tex"
}
else {
    di as text "esttab not installed. Run: ssc install estout"
}

********************************************************************************
* DONE
********************************************************************************

timer off 1
timer list

di _newline(2) "=== Regression Analysis Complete ==="
di _newline "Output files:"
di "  - $graphs/coefplot_bilateral_gravity.pdf"
di "  - $tables/bilateral_regression_gravity.tex"
di "  - $rais_aux/bilateral_univariate_coefficients_gravity.csv"
di "  - $rais_aux/bilateral_multivariate_coefficients_gravity.csv"
