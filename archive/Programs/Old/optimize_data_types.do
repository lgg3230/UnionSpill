********************************************************************************
* PROJECT: UNION SPILLOVERS - DATA TYPE OPTIMIZATION
* AUTHOR: LUIS GOMES
* PROGRAM: OPTIMIZE DATA TYPES TO REDUCE MEMORY USAGE
* STRATEGY: Convert variables to smallest appropriate data types
********************************************************************************

* This script can be used on any dataset to optimize memory usage

program define optimize_types
    args filename
    
    di "Optimizing data types for `filename'..."
    
    use "`filename'", clear
    
    * Get variable information
    describe, short
    
    * Optimize string variables
    foreach var of varlist _all {
        capture confirm string variable `var'
        if !_rc {
            * Check if string can be converted to numeric
            capture destring `var', replace
            if _rc {
                * Keep as string but optimize length
                compress `var'
            }
        }
    }
    
    * Optimize numeric variables
    foreach var of varlist _all {
        capture confirm numeric variable `var'
        if !_rc {
            * Check value ranges and convert to appropriate types
            quietly summarize `var'
            
            * If all values are integers and small, convert to byte/int
            if r(min) >= 0 & r(max) <= 255 & !has_decimals(`var') {
                recast byte `var'
            }
            else if r(min) >= -128 & r(max) <= 127 & !has_decimals(`var') {
                recast byte `var'
            }
            else if r(min) >= 0 & r(max) <= 65535 & !has_decimals(`var') {
                recast int `var'
            }
            else if r(min) >= -32768 & r(max) <= 32767 & !has_decimals(`var') {
                recast int `var'
            }
            else {
                * Keep as float or double based on precision needs
                compress `var'
            }
        }
    }
    
    * Apply general compression
    compress
    
    * Save optimized dataset
    save "`filename'", replace
    
    di "Optimization completed for `filename'"
end

* Helper function to check if variable has decimal values
program define has_decimals
    args varname
    
    quietly generate temp_check = `varname' == int(`varname')
    quietly summarize temp_check
    local has_decimals = (r(min) == 0)
    drop temp_check
    
    return local result = `has_decimals'
end

* Example usage:
* optimize_types "$rais_aux/worker_panel_final.dta"

