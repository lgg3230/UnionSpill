********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR:  LUIS GOMES
* PROGRAM: INVESTIGATE MISSING CONNECTIVITY MEASURES
* INPUT:   SPILLOVER SAMPLES WITH YEARLY CONNECTIVITY MEASURES
* OUTPUT:  UNDERSTANDING WHAT IS GENERATING THE MISSING VALUES IN CONNECTIVITY MEASURES	 
********************************************************************************

use "$rais_aux//cba_rais_firm_2009_2016_flows.dta", clear

// Analysing missing values in the regression above:

gen sample_1  = !missing(mode_base_month) & in_balanced_panel==1 & treat_ultra==0 // 63.7k
gen sample_2  =  in_balanced_panel==1 & treat_ultra==0 // 1.37M
gen sample_3  = lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 // 4.2 k


forvalues i=1/3{
	di "N. Obs full sample_`i':"
	count if sample_`i'==1 & year==2009
	if `i'==1{
		local conn "totalone_pf totalone_pw avg_flowone_pf totalflows"
	}
	else if `i'==2 {
		local conn "totalzero_pf totalzero_pw avg_flowzero_pf totalflows"
	}
	else if `i'==3 {
		local conn "totaltreat_pf totaltreat_pw avg_flowtreat_pf totalflows"
	}
	foreach measure of local conn{
	di "N. Obs non missing connectivity measure `measure' in sample `i':"
	count if sample_`i'==1 & year==2009 & !missing(`measure')
	 
	}
	di "N. obs missing or zero totalflows:"
	count if sample_`i'==1 & (missing(totalflows) | totalflows==0) & year==2009
}


forvalues i=1/3{
	di "N. obs missing or zero totalflows in sample_`i':"
	count if sample_`i'==1 & (missing(totalflows) | totalflows==0) & year==2009
}

// N. Obs full sample_1:
//   63,717
// N. Obs non missing connectivity measure totalone_pf in sample 1:
//   34,192 -> 22.7 k difference: missing totalone
// N. Obs non missing connectivity measure totalone_pw in sample 1:
//   56,881 -> basically all missing comes from missing totalflows
// N. Obs non missing connectivity measure avg_flowone_pf in sample 1:
//   34,193 -> difference of one: missing totalflows, but not totalone(=0)

// N. Obs non missing connectivity measure totalflows in sample 1:
//   56,880
// N. obs missing totalflows:
//   6,837

//N. obs missing or zero totalflows in sample_1:
//   10,103



// N. Obs full sample_2:
//   1,369,436
// N. Obs non missing connectivity measure totalzero_pf in sample 2:
//   261,617
// N. Obs non missing connectivity measure totalzero_pw in sample 2:
//   1,063,220 -> all missing comes from missing totalflows, because this means we cant compute the measure at all
// N. Obs non missing connectivity measure avg_flowzero_pf in sample 2:
//   261,627 -> difference with totalzero_pf count is missing totalflows, but not missing totalzero
// N. Obs non missing connectivity measure totalflows in sample 2:
//   1,063,206

// N. obs missing totalflows:
//   306,230
//N. obs missing or zero totalflows in sample_2:
//   577,602


// N. Obs full sample_3:
//   4,194
// N. Obs non missing connectivity measure totaltreat_pf in sample 3:
//   3,746 -> non-missing totalflows and non_zero totalflows
// N. Obs non missing connectivity measure totaltreat_pw in sample 3:
//   3,893 -> everybody that has non-missing totalflows
// N. Obs non missing connectivity measure avg_flowtreat_pf in sample 3:
//   2,786 -> irregular with other samples, either aggregation or 

// N. Obs non missing connectivity measure totalflows in sample 3:
//   3,893
// N. obs missing totalflows:
//   301
// N. obs missing or zero totalflows in sample_3:
//   448


preserve
keep if year==2009
keep identificad sample_1 sample_2 sample_3
save "$rais_aux/spill_samples.dta", replace
restore

use "$rais_aux/spill_samples.dta", clear

foreach dataset in treat one zero{
	merge 1:1 identificad using "$rais_aux/connectivity_`dataset'_2007_2011_yearly.dta"
drop _merge
	}
save "$rais_aux/spill_samples_connectivity.dta", replace

gen totaltreat_pf = totaltreat/totalflows
	
forvalues i=2007/2010{
	local j =`i'+1
	sum totalflows_`i'_`j' if missing(totalflows) & sample_3==1 & missing(totaltreat_pf)
}	


count if (missing( totalflows_2007_2008 )| missing( totalflows_2008_2009 ) | missing( totalflows_2009_2010 ) | missing(totalflows_2010_2011)) & sample_3==1 & missing(totaltreat_pf)
// 301 miss at least one of the above variables, so this means 

count if (missing( totalflows_2007_2008 ) & missing( totalflows_2008_2009 ) & missing( totalflows_2009_2010 ) & missing(totalflows_2010_2011)) & sample_3==1 & missing(totaltreat_pf)
// only one estab misses all

forvalues i=2007/2010{
	local j =`i'+1
	count if missing( totalflows_`i'_`j') & sample_3==1 & missing(totaltreat_pf)
}

// most missing values come from 2007 to 2008: 278

count if (missing( totalflows_2008_2009 ) | missing( totalflows_2009_2010 ) | missing(totalflows_2010_2011)) & sample_3==1 & missing(totaltreat_pf)
// only 55 miss any of the flows from 08 to 11.

count if (missing( totaltreat_2007_2008 ) | missing(totaltreat_2008_2009 ) | missing( totaltreat_2009_2010 ) | missing(totaltreat_2010_2011)) & sample_3==1 & missing(avg_flowtreat_pf)
// still 301

count if sample_3==1 & missing(avg_flowtreat_pf)
// 1408 -> this is not explained by missing components. 

gen x=cond((missing( totaltreat_2007_2008 ) | missing(totaltreat_2008_2009 ) | missing( totaltreat_2009_2010 ) | missing(totaltreat_2010_2011)) & sample_3==1 & missing(avg_flowtreat_pf),1,0)

gen y=cond(sample_3==1 & missing(avg_flowtreat_pf), 1,0)

gen z=cond(x==0 & y==1, 1,0)

count if z==1

gsort -z


order identificad totaltreat_2007_2008 totalflows_2007_2008 flowtreat_pf_07_08 totaltreat_2008_2009 totalflows_2008_2009 flowtreat_pf_08_09 totaltreat_2009_2010 totalflows_2009_2010 flowtreat_pf_09_10 totaltreat_2010_2011 totalflows_2010_2011 flowtreat_pf_10_11 totaltreat totalflows avg_flowtreat_pf


// for some reason, when adding to create totalflows or totaltreat, stata treats missing values as zero
// the above is not true. the issue is that whenever an individual totalflow_yearly is zero, flowtreat becomes missing, and a single one is enough to set the whole measure to missing. 
// one solution is to take the average among non-missing flowtreat_yearly measures
// another one is to set these measures to zero.
// but, when adding to create avg_flowtreat_pf, one missing value is enough to make the whole measure go missing


// Testing for correction in avg_flowtreat_pf:

local dataset treat


gen flow`dataset'_pf_07_08_n = total`dataset'_2007_2008/totalflows_2007_2008 if totalflows_2007_2008 > 0
gen flow`dataset'_pf_08_09_n = total`dataset'_2008_2009/totalflows_2008_2009 if totalflows_2008_2009 > 0
gen flow`dataset'_pf_09_10_n = total`dataset'_2009_2010/totalflows_2009_2010 if totalflows_2009_2010 > 0
gen flow`dataset'_pf_10_11_n = total`dataset'_2010_2011/totalflows_2010_2011 if totalflows_2010_2011 > 0

* Calculate average of non-missing values
gen avg_flow`dataset'_pf_n = 0
gen avg_flow`dataset'_pf_count_n = 0

foreach year_pair in "07_08" "08_09" "09_10" "10_11" {
    replace avg_flow`dataset'_pf_n = avg_flow`dataset'_pf_n + flow`dataset'_pf_`year_pair'_n if !missing(flow`dataset'_pf_`year_pair'_n)
    replace avg_flow`dataset'_pf_count_n = avg_flow`dataset'_pf_count_n + (missing(flow`dataset'_pf_`year_pair'_n) == 0)
}

* Divide by count of non-missing values
replace avg_flow`dataset'_pf_n = avg_flow`dataset'_pf_n / avg_flow`dataset'_pf_count_n if avg_flow`dataset'_pf_count_n > 0

* Set to missing only if ALL components are missing
replace avg_flow`dataset'_pf_n = . if avg_flow`dataset'_pf_count_n == 0

drop avg_flow`dataset'_pf_count_n

corr avg_flowtreat_pf_n totaltreat_pf if sample_3==1 // correlation is .96 
corr avg_flowtreat_pf   totaltreat_pf if sample_3==1 // correlation is .94
// => different results should come from implied sample selection, not the measures

corr avg_flowtreat_pf_n totaltreat_pw if sample_3==1 // correlation is .52
// => indeed, we should expect different results from this measure

// Now lets take a look at the totaltreat_pf and totaltreat_pw measures:

// totaltreat_pf:

foreach prefix in totalout totalin totalflows outtreat intreat totaltreat {
    ds `prefix'_* 
    local allvars = r(varlist)

    * Keep only those that do NOT contain _pw_
    local vars
    foreach v of local allvars {
        if strpos("`v'", "_pw_") == 0 {
            local vars `vars' `v'
        }
    }

    gen `prefix'_n = 0
    gen `prefix'_count_n = 0
    
    foreach var of local vars {
        replace `prefix'_n = `prefix'_n + `var' if !missing(`var')
        replace `prefix'_count_n = `prefix'_count_n + (missing(`var') == 0)
    }
    
    * Set to missing only if ALL components are missing
    replace `prefix'_n = . if `prefix'_count_n == 0
    
    drop `prefix'_count_n
}

gen totaltreat_pf_n = totaltreat_n/totalflows_n

corr totaltreat_pf_n totaltreat_pf if sample_3==1 // .96 correlation

corr totaltreat_pf_n avg_flowtreat_pf_n if sample_3==1 // .93 correlation

// per-worker measures:
foreach prefix in totalout totalin totalflows outtreat intreat totaltreat {
    * Build the prefix for pw variables
    local pwprefix = "`prefix'_pw"

    ds `pwprefix'_* 
    local vars = r(varlist)

    gen `pwprefix'_n = 0
    gen `pwprefix'_count_n = 0
    
    foreach var of local vars {
        replace `pwprefix'_n = `pwprefix'_n + `var' if !missing(`var')
        replace `pwprefix'_count_n = `pwprefix'_count_n + (missing(`var') == 0)
    }
    
    * Calculate average of non-missing values
    replace `pwprefix'_n = `pwprefix'_n / `pwprefix'_count_n if `pwprefix'_count_n > 0
    
    * Set to missing only if ALL components are missing
    replace `pwprefix'_n = . if `pwprefix'_count_n == 0
    
    drop `pwprefix'_count_n
}


corr totaltreat_pw totaltreat_pw_n if sample_3==1 // correlation of .57 this sounds bad
corr totaltreat_pw totaltreat_pf if sample_3==1 // correlation of .56
corr totaltreat_pw_n totaltreat_pf_n if sample_3==1 // correlaiton of .58
// -> did not change much, but we dont expect results to be very different from using this measure
