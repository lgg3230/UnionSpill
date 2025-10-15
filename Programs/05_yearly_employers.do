********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: SELECT SPELLS TO BE CONSIDERED IN THE TRANSITION MATRICES
* INPUT: DTA RAIS FILES(DAHIS'CLEANING PROCEDURE)
* OUTPUT: FIRM LEVEL RAIS FILES WITH ANALYSIS OUTCOMES
********************************************************************************


forvalues  i=2007/2011{

use "$rais_raw_dir/RAIS_`i'.dta",clear

// first we will keep only the variables we need to make this lighter.

 keep PIS identificad empem3112 tempempr horascontr remdezr

// genreate firm identifier:

gen identificad8 = substr(identificad, 1,8)

// select only spells within each firm that are active throughtout december of each year

gen empdec_lagos = empem3112*(tempempr>1)
keep if empdec_lagos ==1

// generate necessary wage variable for ranking

gen remdezr_h = remdezr/(horascontr*4.348)
gen l_remdezr_h = ln(remdezr_h)

// now select only one spell per worker per firm:
// Step 1: Rank by contracted hours (higher = better)
bysort identificad PIS: egen max_hours = max(horascontr * empdec_lagos) // orders by estab_id and then PIS, within each estab-PIS group, takes the max of the contract hours, given that this spell is active in dec
gen rank1 = (horascontr == max_hours & empdec_lagos==1) // generates an indicator for the spells active throughout dec and whose contracted hours match the max 

* Step 2: Among those with max hours, rank by hourly wage (higher = better)
bysort identificad PIS: egen max_wage = max(l_remdezr_h * rank1) // orderd by estab id and PIS, within each group computes the max of the log hourly dec wages within the max contracted hours that are active in dec
gen rank2 = (l_remdezr_h == max_wage & rank1==1) // marks spells w/in estab-pis active in dec that have max hourly log dec wages among those that have max contracted hours

* Step 3: For any remaining ties, assign a random number
set seed 12345
gen random = runiform() if rank2==1 // gen random number w/in spells that fulfill conditions of rank2

* Create a final rank combining all criteria
bysort identificad PIS: egen max_random = max(random * rank2) // w/in estab-PIS-max hourly log dec wage-max contracted hours computes the maximum random number
gen final_rank = (random == max_random & rank2==1) // marks spells that fulfill rank2 and have max random number

drop rank1 rank2 random max_random

* count the number of selected spells within each establishment:
bysort identificad: egen firm_emp = total(final_rank==1) // w/in estab counts spells that fulfill conditions of final_rank. 


keep if final_rank==1

// Now, among selected spells, select only one per worker, according to the longest tenure

recast float tempempr, force
 
bys PIS: egen max_ten = max(tempempr)
gen rank1 = (tempempr==max_ten)

// among those with same tenure, choose  the one with the largest lgo hourly december earning

bys PIS: egen max_worker_wage = max(l_remdezr_h*rank1)
gen rank2 = (l_remdezr_h==max_worker_wage & rank1==1)

// among those with same tenure and december earnings, choose randomly

set seed 12345

gen random = runiform() if rank2==1

bys PIS: egen max_random = max(rank2*random)

gen rank_emp = (max_random==random & rank2==1)

keep if rank_emp==1



// keep only necessary variables to perform connectivity measures.

keep PIS identificad identificad8 firm_emp

// rename variables in order to keep them after the merge later:

rename (identificad identificad8 firm_emp ) (identificad_`i' identificad8_`i' firm_emp_`i')

save "$rais_aux/yearly_employers_`i'.dta", replace

	
}



forvalues i=2007/2010{
	local j = `i'+1
use "$rais_aux/yearly_employers_`i'.dta", clear

merge 1:1 PIS using "$rais_aux/yearly_employers_`j'.dta"
keep if _merge==3 // only get those who transitioned between two estabs, not those who left or entered the job market

replace identificad_`i' = "1"+identificad_`i'
replace identificad_`j' = "1"+identificad_`j'

replace identificad8_`i' = "1"+identificad8_`i'
replace identificad8_`j' = "1"+identificad8_`j' 
save "$rais_aux/employers_`i'_`j'.dta", replace 
export delimited "$rais_aux/employers_`i'_`j'.csv", replace	
}


// use "$rais_aux/employers_2007_2008.dta", clear
// sample 500, count
// export delimited "$rais_aux/employers_2007_2008_500.csv", replace

////////////////////////////////////////////////////////////////////////////////
// Run matlab scripts

shell "/software/matlab/R2020b/bin/matlab" -nojvm < "/kellogg/proj/lgg3230/UnionSpill/Programs/connectivity_full_lagos.m"
shell "/software/matlab/R2020b/bin/matlab" -nojvm < "/kellogg/proj/lgg3230/UnionSpill/Programs/connectivity_treat_lagos.m"
shell "/software/matlab/R2020b/bin/matlab" -nojvm < "/kellogg/proj/lgg3230/UnionSpill/Programs/connectivity_control_lagos.m"
shell "/software/matlab/R2020b/bin/matlab" -nojvm < "/kellogg/proj/lgg3230/UnionSpill/Programs/connectivity_treat_onecba.m"
shell "/software/matlab/R2020b/bin/matlab" -nojvm < "/kellogg/proj/lgg3230/UnionSpill/Programs/connectivity_treat_zerocba.m"

////////////////////////////////////////////////////////////////////////////////

// compute final conenctivity measures

import delimited "$rais_aux/connectivity_2007_2011.csv", clear

format identificad1 %21.0f
gen identificad1_s = string(identificad1, "%015.0f")
order identificad1_s

gen identificad = substr(identificad1_s,2,14)
order identificad

drop identificad1 identificad1_s


// level variables
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

    gen `prefix' = 0
    foreach var of local vars {
        replace `prefix' = `prefix' + `var'
    }
}

// per-worker variables:

foreach prefix in totalout totalin totalflows outlagos inlagos totallagos {
    * Build the prefix for pw variables
    local pwprefix = "`prefix'_pw"

    ds `pwprefix'_* 
    local vars = r(varlist)

    gen `pwprefix' = 0
    foreach var of local vars {
        replace `pwprefix' = (`pwprefix' + `var')/4 // average flow perworker across every 2 consecutive years
    }
}

save "$rais_aux/connectivity_2007_2011_yearly.dta", replace

keep identificad totalout totalin totalflows outlagos inlagos totallagos totalout_pw totalin_pw totalflows_pw outlagos_pw inlagos_pw totallagos_pw

save "$rais_aux/connectivity_2007_2011_agg.dta", replace

timer clear
timer on 1

foreach dataset in treat control one zero {
	import delimited "$rais_aux/connectivity_`dataset'_2007_2011.csv", clear


format identificad1 %21.0f // these lines just make identificad back into the RAIS format (with trailing zeroes, no 1 in the front)
gen identificad1_s = string(identificad1, "%015.0f")
order identificad1_s

gen identificad = substr(identificad1_s,2,14)
order identificad

drop identificad1 identificad1_s

	 gen flow`dataset'_pf_07_08 = total`dataset'_2007_2008/totalflows_2007_2008
	 gen flow`dataset'_pf_08_09 = total`dataset'_2008_2009/totalflows_2008_2009
	 gen flow`dataset'_pf_09_10 = total`dataset'_2009_2010/totalflows_2009_2010
	 gen flow`dataset'_pf_10_11 = total`dataset'_2010_2011/totalflows_2010_2011
	 
	  gen avg_flow`dataset'_pf = (flow`dataset'_pf_07_08+flow`dataset'_pf_08_09+flow`dataset'_pf_09_10+flow`dataset'_pf_10_11)/4

	  
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



// level variables
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

    gen `prefix' = 0
    foreach var of local vars {
        replace `prefix' = `prefix' + `var'
    }
    
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

// per-worker variables:

foreach prefix in totalout totalin totalflows out`dataset' in`dataset' total`dataset' {
    * Build the prefix for pw variables
    local pwprefix = "`prefix'_pw"

    ds `pwprefix'_* 
    local vars = r(varlist)

    gen `pwprefix' = 0
    foreach var of local vars {
        replace `pwprefix' = (`pwprefix' + `var')/4 // average flow perworker across every 2 consecutive years
    }
    
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



save "$rais_aux/connectivity_`dataset'_2007_2011_yearly.dta", replace


keep identificad  out`dataset' in`dataset' total`dataset'  out`dataset'_pw in`dataset'_pw total`dataset'_pw  avg_flow`dataset'_pf out`dataset'_n in`dataset'_n total`dataset'_n out`dataset'_pw_n in`dataset'_pw_n total`dataset'_pw_n avg_flow`dataset'_pf_n totalflows_n


save "$rais_aux/connectivity_`dataset'_2007_2011_agg.dta", replace
}
timer off 1



// sum across year measures to get flows across all years

// ds totallagos_*, has(type numeric) // list all variables starting with a certian prefix
// local totallagos_vars `r(varlist)'  // generates list of variable with this prefix, and store in local
//
// gen totallagos =0 // generates new variable summing across all these variables
// foreach var of local totallagos_vars {
// 	replace totallagos = totallagos +`var'
// }

timer on 2

use "$rais_aux/connectivity_2007_2011_agg.dta", clear

merge 1:1 identificad using "$rais_aux/connectivity_treat_2007_2011_agg.dta"

drop _merge

merge 1:1 identificad using "$rais_aux/connectivity_control_2007_2011_agg.dta"

drop _merge

merge 1:1 identificad using "$rais_aux/connectivity_one_2007_2011_agg.dta"

drop _merge

merge 1:1 identificad using "$rais_aux/connectivity_zero_2007_2011_agg.dta"

drop _merge


save "$rais_aux/connectivity_2007_2011_tcl.dta", replace

merge 1:m identificad using "$rais_firm/cba_rais_firm_2007_2016.dta"



foreach var in totalout totalin totalflows outlagos inlagos totallagos outtreat intreat outcontrol incontrol totaltreat totalcontrol totalout_pw totalin_pw totalflows_pw outlagos_pw inlagos_pw totallagos_pw outtreat_pw intreat_pw totaltreat_pw outcontrol_pw incontrol_pw totalcontrol_pw{
	replace `var' = 0 if `var'==.
}



// Now, let's do the adjusted measures:

// as a proportion of total flows

                                           
gen totallagos_pf = totallagos/totalflows
                                                                                         
gen totaltreat_pf = totaltreat/totalflows

gen totalcontrol_pf = totalcontrol/totalflows

gen totalone_pf = totalone/totalflows

gen totalzero_pf = totalzero/totalflows

gen totaltreat_pf_n = totaltreat_n/totalflows_n

rename avg_flowtreat_pf_n avg_ftreat_pf_n

// Sample constraints similar to BAssier(2023):

gen bassier_tpf = cond((treat_ultra==1 | (treat_ultra==0 & totaltreat_pf_n<0.01 & !missing(totaltreat_pf_n))),1,0)
gen bassier_tpw = cond((treat_ultra==1 | (treat_ultra==0 & totaltreat_pw_n<0.01 & !missing(totaltreat_pw_n))),1,0)
gen bassier_apf = cond((treat_ultra==1 | (treat_ultra==0 & avg_ftreat_pf_n<0.01 & !missing(avg_ftreat_pf_n))),1,0)


// Per worker totalflows:
gen totalflows_n_pw = totalflows_n/firm_emp

cap drop turnover
gen turnover = separations/firm_emp

local outcomes "turnover totalflows_n totalflows_n_pw firm_emp l_firm_emp lr_remdezr lr_remmedr" // generate locals for outcomes -> easy to add later on

foreach outcome of local outcomes{
	capture drop `outcome'_2009_a 
	capture drop `outcome'_2009
	cap drop `outcome'_2009_5_a
	cap drop `outcome'_2009_5 // -> checks if var already there to allow for easy change of definition
	gen `outcome'_2009_a = `outcome' if year==2009 // -> auxiliary var to get 2009 value
	bys identificad: egen  `outcome'_2009 = max(`outcome'_2009_a) // -> expand 2009 to all years
	drop `outcome'_2009_a // -> drops auxiliary var
	egen `outcome'_2009_5_a = cut(`outcome'_2009) if year==2009 & treat_ultra==0,group(5) // generates quintiles for the variables
	bys identificad: egen `outcome'_2009_5 = min(`outcome'_2009_5_a)
	drop `outcome'_2009_5_a
}
order identificad year l_firm_emp lr_remdezr lr_remmedr l_firm_emp_2009 l_firm_emp_2009_5 lr_remdezr_2009 lr_remmedr_2009

local outcomes "l_firm_emp lr_remdezr lr_remmedr"
foreach outcome of local outcomes{
	cap drop has_na_`outcome'_2009
	gen has_na_`outcome'_2009 = cond(missing(`outcome'_2009),1,0)
	
}

// generate interaction terms

// connectivity and firm_emp_2009


local conn_measures "totaltreat_pf_n totaltreat_pw_n avg_ftreat_pf_n"
local lags "l_firm_emp_2009 lr_remdezr_2009 lr_remmedr_2009"


foreach conn of local conn_measures{
	foreach lag of local lags{
		capture drop `conn'_`lag'
		gen `conn'_`lag' = `conn'*`lag'
	}
	cap drop `conn'_sq
	gen `conn'_sq = `conn'^2
}




// above and below median interaction terms

//turnover pre
egen med_turnover_2009 = median(turnover_2009) if year==2009 & in_balanced_panel==1 & lagos_sample_avg==1 & treat_ultra==0 
egen med_turnover_2009_o= min(med_turnover_2009)
drop med_turnover_2009
rename med_turnover_2009_o med_turnover_2009

gen am_turnover_2009 = cond(turnover_2009>=med_turnover_2009 & !missing(turnover_2009),1,0 )


// l_firm_emp
egen med_l_firm_emp = median(l_firm_emp) if year==2009 & in_balanced_panel==1 & lagos_sample_avg==1 & treat_ultra==0 
egen med_l_firm_emp_o= min(med_l_firm_emp)
drop med_l_firm_emp
rename med_l_firm_emp_o med_l_firm_emp

gen am_l_firm_emp = cond(l_firm_emp>=med_l_firm_emp & !missing(l_firm_emp),1,0 )

// totalflows_n_pw
egen med_totalflows_n_pw = median(totalflows_n_pw) if year==2009 & in_balanced_panel==1 & lagos_sample_avg==1 & treat_ultra==0 
egen med_totalflows_n_pw_o= min(med_totalflows_n_pw)
drop med_totalflows_n_pw
rename med_totalflows_n_pw_o med_totalflows_n_pw

gen am_totalflows_n_pw = cond(totalflows_n_pw>=med_totalflows_n_pw & !missing(totalflows_n_pw),1,0 )

// totalflows_n_pw
egen med_totalflows_n = median(totalflows_n) if year==2009 & in_balanced_panel==1 & lagos_sample_avg==1 & treat_ultra==0 
egen med_totalflows_n_o= min(med_totalflows_n)
drop med_totalflows_n
rename med_totalflows_n_o med_totalflows_n

gen am_totalflows_n = cond(totalflows_n>=med_totalflows_n & !missing(totalflows_n),1,0 )

cap drop hiring_2009
// gen hiring = hired_count/firm_emp

//turnover pre
gen hiring_2009_a  = hiring if year==2009
bys identificad: egen hiring_2009 = min(hiring_2009_a)

egen med_hiring_2009 = median(hiring_2009) if year==2009 & in_balanced_panel==1 & lagos_sample_avg==1 & treat_ultra==0 
egen med_hiring_2009_o= min(med_hiring_2009)
drop med_hiring_2009
rename med_hiring_2009_o med_hiring_2009

gen am_hire_2009 = cond(hiring_2009>=med_hiring_2009 & !missing(hiring_2009),1,0 )



// above and below median connectivity measures

local conn_measures "totaltreat_pf_n totaltreat_pw_n avg_ftreat_pf_n"

foreach conn of local conn_measures{
	egen med_`conn' = median(`conn') if year==2009 & in_balanced_panel==1 & lagos_sample_avg==1 & treat_ultra==0 
egen med_`conn'_o= min(med_`conn')
drop med_`conn'
rename med_`conn'_o med_`conn'

gen am_`conn' = cond(`conn'>=med_`conn' & !missing(`conn'),1,0 )
}




// Generate dummies for three groups of measures:

local interactions "turnover_2009 l_firm_emp_2009 totalflows_n_pw_2009"

foreach inter of local interactions{
	cap drop `inter'_3_a
	cap drop `inter'_3 // -> checks if var already there to allow for easy change of definition
	cap drop `inter'_l
	cap drop `inter'_m 
	cap drop `inter'_h 
	egen `inter'_3_a = cut(`inter') if year==2009 ,group(3) // generates thirds for the variables
	bys identificad: egen `inter'_3 = min(`inter'_3_a)
	drop `inter'_3_a
	
	// generate dummies
	gen `inter'_l = (`inter'_3 ==0)
	gen `inter'_m = (`inter'_3 ==1)
	gen `inter'_h = (`inter'_3 ==2)

}

rename (turnover_2009_m turnover_2009_h l_firm_emp_2009_m l_firm_emp_2009_h totalflows_n_pw_2009_m totalflows_n_pw_2009_h) (tn_pre_m tn_pre_h lfe_m lfe_h tf_n_pw_m tf_n_pw_h)

rename (am_turnover_2009 am_l_firm_emp am_totalflows_n_pw am_totalflows_n) (am_tn_pre am_lfe am_tf_n_pw am_tf_n)

// generate interaction terms:

local conn_measures "totaltreat_pf_n totaltreat_pw_n avg_ftreat_pf_n"
local lags_groups "am_tn_pre am_lfe am_tf_n_pw tn_pre_m tn_pre_h lfe_m lfe_h tf_n_pw_m tf_n_pw_h"

foreach conn of local conn_measures{
	foreach lag of local lags_groups{
		capture drop `conn'_`lag'
		gen `conn'_`lag' = `conn'*`lag'
		
	}
}

local conn_measures "totaltreat_pf_n totaltreat_pw_n avg_ftreat_pf_n"
local lags_groups "am_tn_pre am_lfe am_tf_n_pw tn_pre_m tn_pre_h lfe_2009_m lfe_2009_h tf_n_pw_2009_m tf_n_pw_2009_h"

local interaction_vars ""

foreach conn of local conn_measures {
	foreach lag of local lags_groups {
		local interaction_vars "`interaction_vars' `conn'_`lag'"
	}
}

* Now you can use:
display "`interaction_vars'"



destring industry1, replace force



// marke firms with 10% highest connectivity with lagos sample

save "$rais_firm/cba_rais_firm_2009_2016_flows_1.dta", replace

timer off 2
timer list

* Keep only required variables
keep l_firm_emp firm_emp lr_remdezr lr_remmedr retention hiring quits layoffs leaves turnover in_balanced_panel treat_ultra lagos_sample_avg mode_base_month totalone_pf totalone_pw avg_flowone_pf totalzero_pf totalzero_pw avg_flowzero_pf totaltreat_pf totaltreat_pw avg_flowtreat_pf totaltreat_pf_n totaltreat_pw_n avg_ftreat_pf_n totalflows totalflows_n totalflows_pw totalflows_pw outtreat outone outone_pw outzero outzero_pw outtreat_pw  identificad year industry1 microregion mode_union  n_negs_union_year pub_firm bassier_apf bassier_tpf bassier_tpw

* Save smaller dataset
save "$rais_firm/labor_analysis_sample.dta", replace

use "$rais_firm/cba_rais_firm_2009_2016_flows_1.dta", clear

keep if lagos_sample_avg==1

save "$rais_firm/lagos_sample_sep24.dta", replace


* get data from 2007 and 2008:


