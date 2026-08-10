************************************************************************************************************************************
* Project: Union Spillovers
* Program: Collecting current and year‐ahead employers to define worker flows.
* Author: Luis Gustavo Gomes
* Date: Nov 30, 2024
* 
* Objective: Arrange a dataset at the firm level that defines treated and control units,
*            for both direct and indirect effects.
************************************************************************************************************************************

** SET ENVIRONMENT
************************************************************************************************************************************

clear all                // Clear all variables from memory
clear matrix             // Clear any matrices stored in memory
set maxvar 20000         // Increase the maximum number of variables allowed
set more off             // Turn off --more-- prompts (output scrolling)

* Define global directories for your datasets (adjust these as necessary)
global rais_hom_dir "/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_homog"
global emp_assoc "/kellogg/proj/lgg3230/UnionSpill/Data/stata_emp_assoc"
global rais_emp_merge "/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_emp_merge"
global cba_dir "/kellogg/proj/lgg3230/UnionSpill/Data/CBA"
global cba_rais_fir "/kellogg/proj/lgg3230/UnionSpill/Data/CBA_RAIS/cba_rais_firm"
global cba_rais_mun "/kellogg/proj/lgg3230/UnionSpill/Data/CBA_RAIS/cba_rais_muni"
global cba_rais_sta "/kellogg/proj/lgg3230/UnionSpill/Data/CBA_RAIS/cba_rais_stat"
global cba_rais_nac "/kellogg/proj/lgg3230/UnionSpill/Data/CBA_RAIS/cba_rais_nati"
global cba_rais_tot "/kellogg/proj/lgg3230/UnionSpill/Data/CBA_RAIS/cba_rais_total"
global rais_aux "/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux"
global tables "/kellogg/proj/lgg3230/UnionSpill/Tables"

*-------------------------------------------------------------------------------------------------------------
* PART 1: Compute connectivity measure quantiles
*-------------------------------------------------------------------------------------------------------------
ssc install estout, replace
use "$rais_aux/connectivity_2009_2012.dta"

preserve
keep if treat_ultra==0

*---------------------------------------------------------------
* Create a local macro with all connectivity variable names
* assuming variables follow the naming pattern: Connectivity_t_tprime
* For years 2009 to 2012, t goes from 2009 to 2011 and t' from t+1 to 2012.
*---------------------------------------------------------------
local connectivity_vars ""
forvalues t = 2009/2011 {
    * Compute the starting value for the inner loop (t' = t+1)
    local tprime_min = `t' + 1
    forvalues tprime = `tprime_min'/2012 {
        local connectivity_vars "`connectivity_vars' connectivity_`t'_`tprime'"
    }
}
* Display the list of variables to check that it is built correctly
display "`connectivity_vars'"

*---------------------------------------------------------------
* Now use estpost (from the estout package) to calculate quantiles 
* for the connectivity variables. For example, we compute the 25th, 50th, 75th, and 90th percentiles.
* If you haven't installed estout, run: ssc install estout, replace
*---------------------------------------------------------------
estpost tabstat `connectivity_vars', statistics(p25 p50 p75 p90 p95) ///
    columns(statistics) 

*---------------------------------------------------------------
* Export the results to a LaTeX table
esttab using "$rais_aux/connectivity_quantiles.tex", replace ///
    title("Quantiles of Connectivity Measures") ///
    label nogap nonumbers cells("stat(fmt(%9.2f))")

display "LaTeX table with connectivity quantiles has been saved as $tables/connectivity_quantiles.tex."
restore
