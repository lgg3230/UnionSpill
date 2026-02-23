********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR:  LUIS GOMES
* PROGRAM: Worker-Level Results
* INPUTS: WORKER-LEVEL DATASET RESTRICTED TO LAGOS SAMPLE
* OUTPUTS: WORKER-LEVEL ANALYSIS
********************************************************************************


********************************************************************************
* PROJECT: UNION SPILLOVERS – Worker Classification
********************************************************************************

use "$rais_firm/lagos_sample_workers.dta", clear
keep if inrange(year, 2009, 2016)

destring industry1, replace force

count if missing(tempempr) // 37k, all in 2011
gen miss_tempempr

egen miss_tenure_firms = nvals(identificad) if year==2011 & missing(tempempr) // spread across 218 firms






********************************************************************************
* 1. Define NEW HIRES POST-2012 (already correct in your code)
********************************************************************************

gen hire_months = ym(year,12) - tempempr
local cutoff = ym(2012,12)
gen newhire_tmp = hire_months >= `cutoff'
bysort PIS identificad: egen newhire = max(newhire_tmp)
drop newhire_tmp

********************************************************************************
* 2. Define PRE-PERIOD NEW HIRES (for comparison group)
********************************************************************************

local cutoff_pre = ym(2011,12)
gen newhire_pre_tmp = hire_months >= `cutoff_pre'
bysort PIS identificad: egen newhire_pre = max(newhire_pre_tmp)
drop newhire_pre_tmp


********************************************************************************
* 2.1 Define NEW HIRES (people that were hired in the current year)
********************************************************************************

gen new_hire_yearly = cond(tempempr<=12 & !missing(tempempr),1,0)

********************************************************************************
* 3. Define INCUMBENTS AFTER THE REFORM (2011–2016, no firm switching)
********************************************************************************

* Tag firm switches
bysort PIS (identificad year): gen firm_change = (identificad != identificad[_n-1])
bysort PIS: egen any_change_1116 = max(firm_change * (year >= 2011))

* Require presence pre & post
bysort PIS identificad: egen in_2011 = max(year == 2011)
bysort PIS identificad: egen in_post = max(year >= 2013)

gen incumbent = (in_2011 == 1 & in_post == 1 & any_change_1116 == 0)




********************************************************************************
* 4. Define INCUMBENTS BEFORE THE REFORM (2009–2011, no switching)
********************************************************************************

bysort PIS: egen any_change_0911 = max(firm_change * (year <= 2011))

bysort PIS identificad: egen in_2009 = max(year == 2009)
bysort PIS identificad: egen in_2011_pre = max(year == 2011)

gen incumbent_pre = (in_2009 == 1 & in_2011_pre == 1 & any_change_0911 == 0)


********************************************************************************
* 5. Create share variables
********************************************************************************

bysort identificad year: egen firm_newhire_count = total(newhire)
gen share_newhires = firm_newhire_count / firm_emp

bysort identificad year: egen firm_incumbents = total(incumbent)
gen share_incumbents = firm_incumbents / firm_emp

bysort identificad year: egen firm_newhire_pre_count = total(newhire_pre)
gen share_newhires_pre = firm_newhire_pre_count / firm_emp

bysort identificad year: egen firm_incumbents_pre_count = total(incumbent_pre)
gen share_incumbents_pre = firm_incumbents_pre_count / firm_emp

* Residual group
gen share_other = 1 - share_newhires - share_incumbents
********************************************************************************
save "$rais_firm/lagos_sample_workers_new_inc_sep24.dta", replace
use "$rais_firm/lagos_sample_workers_new_inc_sep24.dta", clear

local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0"


destring industry1, replace force

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year==2009, detail
gen totaltreat_pw_n_p90 = r(p90)

// normalize by 2009 p90 and scale down by 100 so coefficients scale up by 100
gen totaltreat_pw_norm = (totaltreat_pw_n / totaltreat_pw_n_p90)

* ===============================
// Overall sample - WAges
* ===============================

// Overall sample - Wages
cap drop inv_firm_emp
gen inv_firm_emp = 1/firm_emp

local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0"
local conn totaltreat_pw_norm
local outcome lr_remdezr

// preserve

// post treat coefficient
reghdfe `outcome' ///
		c.`conn'##treat_year ///
		if `s_spill' & year>=2009, ///
        absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year totalflows_n#treat_year) ///
        vce(cluster identificad)

* New hires analysis: 

* Define a comparison group for the pretreatment period:

local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0"
local conn totaltreat_pw_norm
local outcome lr_remdezr
		
// post treat coefficient
reghdfe `outcome' ///
		c.`conn'##treat_year ///
		if `s_spill' & year>=2009 & (new_hire_yearly==1), ///
        absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year totalflows_n#treat_year) ///
        vce(cluster identificad)	

// restore

bys identificad year: egen lr_remdezr_firm = mean(lr_remdezr)

mmerge identificad year using "$rais_firm/lagos_sample_sep24_remdezr.dta", type(n:1)

assert lr_remdezr_2==lr_remdezr_firm if !missing(lr_remdezr_firm)
assert firm_emp_2==firm_emp_assert if !missing(lr_remdezr_firm)

egen num_firms_missing = nvals(identificad) if missing(lr_remdezr_firm)

* (dirty) pretreatment firm employment:

bys identificad: egen firm_emp_pre_o = mean(firm_emp) if year<=2011
bys identificad: egen firm_emp_pre = min(firm_emp_pre_o)
drop firm_emp_pre_o

sum firm_emp_pre if year==2009, detail


* generate indicator of new hires and incumbents

bys identificad year: gen newhire = cond(tempempr<12,1,0)
label var newhire "indicates whether worker was hired during current year"
bys identificad year: gen incumbent = cond(tempempr>=12,1,0) & !missing(tempempr)
label var incumbent "indicates whether worker was already active in previous years"

* 
local V "totalflows_n"
cap drop q4_`V'_2009a q4_`V'
                    egen q4_`V'_2009a = cut(`V') if year==2009, group(4)
                    bys identificad: egen q4_`V' = min(q4_`V'_2009a)
                    drop q4_`V'_2009a
					label var q4_`V' "quartiles of pretreatment `V'"
					
destring industry1, replace force	

gen inv_firm_emp = 1/firm_emp

// collapse (firstnm) identificad year treat_ultra industry1 mode_base_month microregion q4_totalflows_n placebo_year treat_year totaltreat_pf_n lagos_sample_avg ///
// 			(mean) lr_remmedr lr_remdezr ,by(cnpj_year)				

* ===============================
* Direct effects: pre/post coeffs - december Earnings
* ===============================
local s_direct "(lagos_sample_avg==1 & treat_ultra==0 | lagos_sample_avg==1 & treat_ultra==1) & firm_emp_pre<30 "

* --- Post-treatment coefficient (treat_ultra × Post) ---
reghdfe lr_remdezr treat_ultra##treat_year if `s_direct', ///
        absorb(treat_year identificad industry1#treat_year mode_base_month#treat_year microregion#treat_year ) ///
        vce(cluster identificad)

local post_coef = string(_b[1.treat_ultra#1.treat_year], "%9.2f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_ultra#1.treat_year]/_se[1.treat_ultra#1.treat_year])), "%9.2f")

* --- Pre-treatment (placebo) coefficient (treat_ultra × Pre) ---
reghdfe lr_remdezr treat_ultra##placebo_year  if `s_direct' & year<=2011, ///
        absorb(placebo_year identificad industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year ) ///
        vce(cluster identificad)

local pre_coef = string(_b[1.treat_ultra#1.placebo_year], "%9.2f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.treat_ultra#1.placebo_year]/_se[1.treat_ultra#1.placebo_year])), "%9.2f")

* ===============================
* Direct effects: event study plot
* ===============================
reghdfe lr_remdezr treat_ultra##b(2011).year  if `s_direct', ///
        absorb(year identificad industry1#year mode_base_month#year microregion#year q4_totalflows_n#year ) ///
        vce(cluster identificad)
estimates store es_direct_remmedr

coefplot es_direct_remmedr, ///
    keep(1.treat_ultra#2009.year 1.treat_ultra#2010.year 1.treat_ultra#2011.year ///
         1.treat_ultra#2012.year 1.treat_ultra#2013.year 1.treat_ultra#2014.year ///
         1.treat_ultra#2015.year 1.treat_ultra#2016.year) ///
    coeflabels(1.treat_ultra#2009.year = "2009" ///
               1.treat_ultra#2010.year = "2010" ///
               1.treat_ultra#2011.year = "2011" ///
               1.treat_ultra#2012.year = "2012" ///
               1.treat_ultra#2013.year = "2013" ///
               1.treat_ultra#2014.year = "2014" ///
               1.treat_ultra#2015.year = "2015" ///
               1.treat_ultra#2016.year = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
    ylabel(-.06(.02).08) ///
    ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Direct Effect on Log December Earnings - Worker-level", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) ///
    text(-.05 6 "Post x Treat Coef: `post_coef', p-v: `post_pval'", color(blue)) ///
    text(.075 2 "Pre x Treat Coef: `pre_coef', p-v: `pre_pval'", color(blue))

graph export "$graphs/es_l_remdezr_treat_workerlevel.png", as(png) replace


* ===============================
* Direct effects: pre/post coeffs - Average Earnings
* ===============================
local s_direct "(lagos_sample_avg==1 & treat_ultra==0 | lagos_sample_avg==1 & treat_ultra==1)  "

* --- Post-treatment coefficient (treat_ultra × Post) ---
reghdfe lr_remmedr treat_ultra##treat_year if `s_direct', ///
        absorb(treat_year identificad industry1#treat_year mode_base_month#treat_year microregion#treat_year q4_totalflows_n#treat_year) ///
        vce(cluster identificad)

local post_coef = string(_b[1.treat_ultra#1.treat_year], "%9.2f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_ultra#1.treat_year]/_se[1.treat_ultra#1.treat_year])), "%9.2f")

* --- Pre-treatment (placebo) coefficient (treat_ultra × Pre) ---
reghdfe lr_remmedr treat_ultra##placebo_year if `s_direct' & year<=2011, ///
        absorb(placebo_year identificad industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year q4_totalflows_n#placebo_year ) ///
        vce(cluster identificad)

local pre_coef = string(_b[1.treat_ultra#1.placebo_year], "%9.2f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.treat_ultra#1.placebo_year]/_se[1.treat_ultra#1.placebo_year])), "%9.2f")

* ===============================
* Direct effects: event study plot
* ===============================
reghdfe lr_remmedr treat_ultra##b(2011).year  if `s_direct', ///
        absorb(year identificad industry1#year mode_base_month#year microregion#year q4_totalflows_n#year ) ///
        vce(cluster identificad)
estimates store es_direct_remmedr

coefplot es_direct_remmedr, ///
    keep(1.treat_ultra#2009.year 1.treat_ultra#2010.year 1.treat_ultra#2011.year ///
         1.treat_ultra#2012.year 1.treat_ultra#2013.year 1.treat_ultra#2014.year ///
         1.treat_ultra#2015.year 1.treat_ultra#2016.year) ///
    coeflabels(1.treat_ultra#2009.year = "2009" ///
               1.treat_ultra#2010.year = "2010" ///
               1.treat_ultra#2011.year = "2011" ///
               1.treat_ultra#2012.year = "2012" ///
               1.treat_ultra#2013.year = "2013" ///
               1.treat_ultra#2014.year = "2014" ///
               1.treat_ultra#2015.year = "2015" ///
               1.treat_ultra#2016.year = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
    ylabel(-.06(.02).08) ///
    ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Direct Effect on Log AverageEarnings - Worker-level", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) ///
    text(-.05 6 "Post x Treat Coef: `post_coef', p-v: `post_pval'", color(blue)) ///
    text(.075 2 "Pre x Treat Coef: `pre_coef', p-v: `pre_pval'", color(blue))

graph export "$graphs/es_l_remmedr_treat_workerlevel.png", as(png) replace



* ===============================
* Direct effects: pre/post coeffs -  December Earnings & Small firms
* ===============================
local s_direct "(lagos_sample_avg==1 & treat_ultra==0 | lagos_sample_avg==1 & treat_ultra==1)  "

* --- Post-treatment coefficient (treat_ultra × Post) ---
reghdfe lr_remdezr treat_ultra##treat_year if `s_direct', ///
        absorb(treat_year identificad industry1#treat_year mode_base_month#treat_year microregion#treat_year q4_totalflows_n#treat_year) ///
        vce(cluster identificad)

local post_coef = string(_b[1.treat_ultra#1.treat_year], "%9.2f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_ultra#1.treat_year]/_se[1.treat_ultra#1.treat_year])), "%9.2f")

* --- Pre-treatment (placebo) coefficient (treat_ultra × Pre) ---
reghdfe lr_remdezr treat_ultra##placebo_year if `s_direct' & year<=2011, ///
        absorb(placebo_year identificad industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year q4_totalflows_n#placebo_year) ///
        vce(cluster identificad)

local pre_coef = string(_b[1.treat_ultra#1.placebo_year], "%9.2f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.treat_ultra#1.placebo_year]/_se[1.treat_ultra#1.placebo_year])), "%9.2f")

* ===============================
* Direct effects: event study plot
* ===============================
reghdfe lr_remdezr treat_ultra##b(2011).year  if `s_direct', ///
        absorb(year identificad industry1#year mode_base_month#year microregion#year q4_totalflows_n#year ) ///
        vce(cluster identificad)
estimates store es_direct_remmedr

coefplot es_direct_remmedr, ///
    keep(1.treat_ultra#2009.year 1.treat_ultra#2010.year 1.treat_ultra#2011.year ///
         1.treat_ultra#2012.year 1.treat_ultra#2013.year 1.treat_ultra#2014.year ///
         1.treat_ultra#2015.year 1.treat_ultra#2016.year) ///
    coeflabels(1.treat_ultra#2009.year = "2009" ///
               1.treat_ultra#2010.year = "2010" ///
               1.treat_ultra#2011.year = "2011" ///
               1.treat_ultra#2012.year = "2012" ///
               1.treat_ultra#2013.year = "2013" ///
               1.treat_ultra#2014.year = "2014" ///
               1.treat_ultra#2015.year = "2015" ///
               1.treat_ultra#2016.year = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
    ylabel(-.06(.02).08) ///
    ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Direct Effect on Log December Earnings - Worker-level", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) ///
    text(-.05 6 "Post x Treat Coef: `post_coef', p-v: `post_pval'", color(blue)) ///
    text(.075 2 "Pre x Treat Coef: `pre_coef', p-v: `pre_pval'", color(blue))

graph export "$graphs/es_l_remdezr_treat_workerlevel.png", as(png) replace





* ===============================
* Direct effects: pre/post coeffs - Average Earnings
* ===============================
local s_direct "(lagos_sample_avg==1 & treat_ultra==0 | lagos_sample_avg==1 & treat_ultra==1) & incumbent==1 "

* --- Post-treatment coefficient (treat_ultra × Post) ---
reghdfe lr_remmedr treat_ultra##treat_year if `s_direct', ///
        absorb(treat_year identificad industry1#treat_year mode_base_month#treat_year microregion#treat_year q4_totalflows_n#treat_year) ///
        vce(cluster identificad)

local post_coef = string(_b[1.treat_ultra#1.treat_year], "%9.2f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_ultra#1.treat_year]/_se[1.treat_ultra#1.treat_year])), "%9.2f")

* --- Pre-treatment (placebo) coefficient (treat_ultra × Pre) ---
reghdfe lr_remmedr treat_ultra##placebo_year if `s_direct' & year<=2011, ///
        absorb(placebo_year identificad industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year q4_totalflows_n#placebo_year) ///
        vce(cluster identificad)

local pre_coef = string(_b[1.treat_ultra#1.placebo_year], "%9.2f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.treat_ultra#1.placebo_year]/_se[1.treat_ultra#1.placebo_year])), "%9.2f")

* ===============================
* Direct effects: event study plot
* ===============================
reghdfe lr_remmedr treat_ultra##b(2011).year  if `s_direct', ///
        absorb(year identificad industry1#year mode_base_month#year microregion#year q4_totalflows_n#year  ) ///
        vce(cluster identificad)
estimates store es_direct_remmedr

coefplot es_direct_remmedr, ///
    keep(1.treat_ultra#2009.year 1.treat_ultra#2010.year 1.treat_ultra#2011.year ///
         1.treat_ultra#2012.year 1.treat_ultra#2013.year 1.treat_ultra#2014.year ///
         1.treat_ultra#2015.year 1.treat_ultra#2016.year) ///
    coeflabels(1.treat_ultra#2009.year = "2009" ///
               1.treat_ultra#2010.year = "2010" ///
               1.treat_ultra#2011.year = "2011" ///
               1.treat_ultra#2012.year = "2012" ///
               1.treat_ultra#2013.year = "2013" ///
               1.treat_ultra#2014.year = "2014" ///
               1.treat_ultra#2015.year = "2015" ///
               1.treat_ultra#2016.year = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
    ylabel(-.06(.02).08) ///
    ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Direct Effect on Log AverageEarnings - Incumbents only", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) ///
    text(-.05 6 "Post x Treat Coef: `post_coef', p-v: `post_pval'", color(blue)) ///
    text(.075 2 "Pre x Treat Coef: `pre_coef', p-v: `pre_pval'", color(blue))

graph export "$graphs/es_l_remmedr_treat_workerlevel_inc.png", as(png) replace


* ===============================
* Direct effects: pre/post coeffs - Average Earnings
* ===============================
local s_direct "(lagos_sample_avg==1 & treat_ultra==0 | lagos_sample_avg==1 & treat_ultra==1) & newhire==1 "

* --- Post-treatment coefficient (treat_ultra × Post) ---
reghdfe lr_remmedr treat_ultra##treat_year if `s_direct', ///
        absorb(treat_year identificad industry1#treat_year mode_base_month#treat_year microregion#treat_year q4_totalflows_n#treat_year) ///
        vce(cluster identificad)

local post_coef = string(_b[1.treat_ultra#1.treat_year], "%9.2f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_ultra#1.treat_year]/_se[1.treat_ultra#1.treat_year])), "%9.2f")

* --- Pre-treatment (placebo) coefficient (treat_ultra × Pre) ---
reghdfe lr_remmedr treat_ultra##placebo_year if `s_direct' & year<=2011, ///
        absorb(placebo_year identificad industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year q4_totalflows_n#placebo_year) ///
        vce(cluster identificad)

local pre_coef = string(_b[1.treat_ultra#1.placebo_year], "%9.2f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.treat_ultra#1.placebo_year]/_se[1.treat_ultra#1.placebo_year])), "%9.2f")

* ===============================
* Direct effects: event study plot
* ===============================
reghdfe lr_remmedr treat_ultra##b(2011).year  if `s_direct', ///
        absorb(year identificad industry1#year mode_base_month#year microregion#year q4_totalflows_n#year ) ///
        vce(cluster identificad)
estimates store es_direct_remmedr

coefplot es_direct_remmedr, ///
    keep(1.treat_ultra#2009.year 1.treat_ultra#2010.year 1.treat_ultra#2011.year ///
         1.treat_ultra#2012.year 1.treat_ultra#2013.year 1.treat_ultra#2014.year ///
         1.treat_ultra#2015.year 1.treat_ultra#2016.year) ///
    coeflabels(1.treat_ultra#2009.year = "2009" ///
               1.treat_ultra#2010.year = "2010" ///
               1.treat_ultra#2011.year = "2011" ///
               1.treat_ultra#2012.year = "2012" ///
               1.treat_ultra#2013.year = "2013" ///
               1.treat_ultra#2014.year = "2014" ///
               1.treat_ultra#2015.year = "2015" ///
               1.treat_ultra#2016.year = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
    ylabel(-.06(.02).08) ///
    ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Direct Effect on Log AverageEarnings - New hires only", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) ///
    text(-.05 6 "Post x Treat Coef: `post_coef', p-v: `post_pval'", color(blue)) ///
    text(.075 2 "Pre x Treat Coef: `pre_coef', p-v: `pre_pval'", color(blue))

graph export "$graphs/es_l_remmedr_treat_workerlevel_nhire.png", as(png) replace


* ===============================
* Spillover effects: event study plot
* ===============================

local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "
local conn totaltreat_pw_n
// post treat coefficient
reghdfe lr_remdezr c.`conn'##treat_year  if `s_spill' & year>=2009, ///
        absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year q4_totalflows_n#treat_year ) ///
        vce(cluster identificad)

		// Extract post-treatment coefficient and p-value
local post_coef = string(_b[1.treat_year#c.`conn'], "%9.2f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_year#c.`conn']/_se[1.treat_year#c.`conn'])), "%9.2f")


// placebo coefficient
reghdfe lr_remdezr c.`conn'##placebo_year if `s_spill' & year<=2011 & year>=2009, ///
        absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year q4_totalflows_n#placebo_year) ///
        vce(cluster identificad)

// Extract pre-treatment coefficient and p-value
local pre_coef = string(_b[1.placebo_year#c.`conn'], "%9.2f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.placebo_year#c.`conn']/_se[1.placebo_year#c.`conn'])), "%9.2f")

		
	local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "
reghdfe lr_remdezr c.`conn'##b(2011).year if `s_spill' & year>=2009, ///
        absorb(identificad year industry1#year mode_base_month#year microregion#year q4_totalflows_n#year) ///
        vce(cluster identificad)
// 		gen emp_sample = e(sample)	
estimates store es_spill_remdezr	

coefplot es_spill_remdezr, ///
    keep(*#*c.`conn') ///
    msymbol(diamond) ///
    coeflabels(2009.year#c.`conn' = "2009" ///
               2010.year#c.`conn' = "2010" ///
               2011.year#c.`conn' = "2011" ///
               2012.year#c.`conn' = "2012" ///
               2013.year#c.`conn' = "2013" ///
               2014.year#c.`conn' = "2014" ///
               2015.year#c.`conn' = "2015" ///
               2016.year#c.`conn' = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-.2(.05).35) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Dec Earnings - Workers - Overall", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    text(-.1 6 "C x Post Coef: `post_coef', p-v: `post_pval'", color(blue)) ///
    text(.25 2 "C x Pre Coef: `pre_coef', p-v: `pre_pval'", color(blue)) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
    
graph export "$graphs/es_remdezr_spill_overall_workerlevel.png", as(png) replace

* ===============================
* Spillover effects: event study plot - incumbents
* ===============================

local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & incumbent==1"
local conn totaltreat_pw_n
// post treat coefficient
reghdfe lr_remdezr c.`conn'##treat_year  if `s_spill' & year>=2009, ///
        absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year q4_totalflows_n#treat_year ) ///
        vce(cluster identificad)

		// Extract post-treatment coefficient and p-value
local post_coef = string(_b[1.treat_year#c.`conn'], "%9.2f")
local post_pval = string(2*ttail(e(df_r), abs(_b[1.treat_year#c.`conn']/_se[1.treat_year#c.`conn'])), "%9.2f")


// placebo coefficient
reghdfe lr_remdezr c.`conn'##placebo_year if `s_spill' & year<=2011 & year>=2009, ///
        absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year q4_totalflows_n#placebo_year) ///
        vce(cluster identificad)

// Extract pre-treatment coefficient and p-value
local pre_coef = string(_b[1.placebo_year#c.`conn'], "%9.2f")
local pre_pval = string(2*ttail(e(df_r), abs(_b[1.placebo_year#c.`conn']/_se[1.placebo_year#c.`conn'])), "%9.2f")

		
	local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & incumbent==1"
reghdfe lr_remdezr c.`conn'##b(2011).year if `s_spill' & year>=2009, ///
        absorb(identificad year industry1#year mode_base_month#year microregion#year q4_totalflows_n#year) ///
        vce(cluster identificad)
// 		gen emp_sample = e(sample)	
estimates store es_spill_remdezr	

coefplot es_spill_remdezr, ///
    keep(*#*c.`conn') ///
    msymbol(diamond) ///
    coeflabels(2009.year#c.`conn' = "2009" ///
               2010.year#c.`conn' = "2010" ///
               2011.year#c.`conn' = "2011" ///
               2012.year#c.`conn' = "2012" ///
               2013.year#c.`conn' = "2013" ///
               2014.year#c.`conn' = "2014" ///
               2015.year#c.`conn' = "2015" ///
               2016.year#c.`conn' = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-.2(.05).35) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Dec Earnings - Workers - Incumbents", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    text(-.1 6 "C x Post Coef: `post_coef', p-v: `post_pval'", color(blue)) ///
    text(.25 2 "C x Pre Coef: `pre_coef', p-v: `pre_pval'", color(blue)) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
    
graph export "$graphs/es_remdezr_spill_overall_workerlevel_inc.png", as(png) replace
