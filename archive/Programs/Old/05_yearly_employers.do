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
}



save "$rais_aux/connectivity_`dataset'_2007_2011_yearly.dta", replace


keep identificad  out`dataset' in`dataset' total`dataset'  out`dataset'_pw in`dataset'_pw total`dataset'_pw  avg_flow`dataset'_pf


save "$rais_aux/connectivity_`dataset'_2007_2011_agg.dta", replace
}




// sum across year measures to get flows across all years

// ds totallagos_*, has(type numeric) // list all variables starting with a certian prefix
// local totallagos_vars `r(varlist)'  // generates list of variable with this prefix, and store in local
//
// gen totallagos =0 // generates new variable summing across all these variables
// foreach var of local totallagos_vars {
// 	replace totallagos = totallagos +`var'
// }

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

merge 1:m identificad using "$rais_firm/cba_rais_firm_2009_2016.dta"



foreach var in totalout totalin totalflows outlagos inlagos totallagos outtreat intreat outcontrol incontrol totaltreat totalcontrol totalout_pw totalin_pw totalflows_pw outlagos_pw inlagos_pw totallagos_pw outtreat_pw intreat_pw totaltreat_pw outcontrol_pw incontrol_pw totalcontrol_pw{
	replace `var' = 0 if `var'==.
}

gen linkedtolagos = cond(totallagos>0,1,0)

gen linkedtocontrol = cond(totalcontrol>0,1,0)

gen linkedtotreat = cond(totaltreat>0,1,0)

gen moretreat = cond(totaltreat>totalcontrol, 1,0)

qui sum totallagos if linkedtolagos==1 & year==2010 & in_balanced_panel==1 & lagos_sample==0, detail

scalar p90 = r(p90)

gen top10_linklagos = cond(totallagos >=p90 & in_balanced_panel==1 ,1,0 )

// estabs that are among the top 10% with most connections with lagos sample, not in treatment group
gen x = top10_linklagos*(1-treat_ultra)*(1-lagos_sample)
tab x

// how many of the above have at least one link to the treated?
tab linkedtotreat if x==1 & year==2009 // 4.2k
// how many of hte above have at least one link to control?
tab linkedtocontrol if x==1 & year==2009 // 3.8k

// what does the distribution of links to treatment and control looks like within x ==1?

tab totaltreat if x==1 & year==2009 // median is 9, 
qui sum totaltreat if x==1 & year==2009, detail
scalar median_treat_x = r(p50)
gen high_treat = cond(totaltreat>=median_treat_x & x==1,1,0)

tab totalcontrol if x==1 & year==2009 // median is 4
qui sum totalcontrol if x==1 & year==2009, detail
scalar median_control_x = r(p50)
gen high_control = cond(totalcontrol>=median_control_x & x==1,1,0)

gen high_control_treat = cond(high_control==1 & high_treat==1,1,0)
gen h_control_l_treat  = cond(high_control==1 & high_treat==0,1,0)
gen l_control_h_treat  = cond(high_control==0 & high_treat==1,1,0)
gen low_control_treat  = cond(high_control==0 & high_treat==0,1,0)

tab high_control high_treat if year==2009 & x==1

// Let's do the same measures, but including lagos sample:


tab totaltreat if top10_linklagos==1 & year==2009
qui sum totaltreat if top10_linklagos==1 & year==2009, detail
scalar median_treat_top10 = r(p50)
gen high_t_top10 = cond(totaltreat>=median_treat_top10 & top10_linklagos==1,1,0) 

// Now, let's do the adjusted measures:

// as a proportion of total flows

                                           
gen totallagos_pf = totallagos/totalflows
                                                                                         
gen totaltreat_pf = totaltreat/totalflows

gen totalcontrol_pf = totalcontrol/totalflows

gen totalone_pf = totalone/totalflows

gen totalzero_pf = totalzero/totalflows
// as a proportio of workers


// marke firms with 10% highest connectivity with lagos sample

//  according to pw flows

qui sum totallagos_pw if linkedtolagos==1 & year==2010 & in_balanced_panel==1 & lagos_sample==0, detail

scalar p90_pw = r(p90)

gen top10_linklagos_pw = cond(totallagos >=p90_pw & in_balanced_panel==1 ,1,0 )

gen y = top10_linklagos_pw*(1-treat_ultra)*(1-lagos_sample)

qui sum totaltreat_pw if y==1 & year==2009, detail
scalar median_treat_y = r(p50)
gen high_treat_pw = cond(totaltreat_pw>=median_treat_y,1,0)

gen high_totaltreat_pf = cond(totaltreat_pf>=.01,1,0)
gen high_avg_flowtreat_pf = cond(avg_flowtreat_pf>=.01,1,0)

gen low_conn_control_ttpf = cond((treat_ultra==0 & high_totaltreat_pf==0)| (treat_ultra==1),1, 0 )
label variable low_conn_control_ttpf "obs either in treat group, or low conn in control, using totaltreat_pf "

gen low_conn_control_aftpf = cond((treat_ultra==0 & high_avg_flowtreat_pf==0)| (treat_ultra==1),1, 0 )
label variable low_conn_control_aftpf "obs either in treat group, or low conn in control, using avg_flowtreat_pf "

gen lagos_sample_dir = cond((lagos_sample==1 & treat_ultra==0 & high_totaltreat_pf==0) | (lagos_sample==1 & treat_ultra==1),1,0)

gen lagos_sample_spill = cond(lagos_sample==1 & treat_ultra==0,1,0)

// // mark firms with 10% highest connectivity with lagos sample (as a percentage of total flows)
// qui sum totallagos_pf if linkedtolagos==1 & year==2010 & in_balanced
//
// gen top10_linklagos_pf = 

preserve

* Keep only required variables
keep l_firm_emp firm_emp lr_remdezr lr_remmedr retention hiring quits layoffs leaves turnover in_balanced_panel treat_ultra lagos_sample_avg mode_base_month totalone_pf totalone_pw avg_flowone_pf totalzero_pf totalzero_pw avg_flowzero_pf totaltreat_pf totaltreat_pw avg_flowtreat_pf totalflows totalflows_pw outtreat outone outone_pw outzero outzero_pw outtreat_pw  identificad year industry1 microregion mode_union avg_n_negs n_negs_union_year pub_firm

* Save smaller dataset
save "$rais_firm/labor_analysis_sample.dta", replace

restore

save "$rais_firm/cba_rais_firm_2009_2016_flows.dta", replace

