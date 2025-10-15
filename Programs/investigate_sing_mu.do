********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR:  LUIS GOMES
* PROGRAM: UNDERSTAND WHAT MAKES REGHDFE DROP SOME UNITS WHEN USING MODE UNION 
* INPUT:   LABOR ANALYSIS DATASET, RESTRICTED TO LAGOS SAMPLE
* OUTPUT:  	 
********************************************************************************


use "$rais_firm/labor_analysis_lagos.dta", clear

keep if lagos_sample_avg==1

// RUN SOME SPILLOVER REGRESSION TO GET FULL SAMPLE


        local outcomes "l_firm_emp lr_remdezr lr_remmedr"
	 local conn_measures "totaltreat_pf_n totaltreat_pw_n avg_ftreat_pf_n"
        local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0"
        local s_direct "lagos_sample_avg==1 & in_balanced_panel==1"
        local s_spill_r "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & !missing(avg_flowtreat_pf)"
	local s_spill_flow "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & totalflows_n>=1 & !missing(totalflows_n)"
	local s_spill_emp "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp>=10 & !missing(firm_emp)"
        local s_direct_r "lagos_sample_avg==1 & in_balanced_panel==1 & !missing(avg_flowtreat_pf)"
	local s_direct_btpf "lagos_sample_avg==1 & in_balanced_panel==1 & bassier_tpf==1"
	local s_direct_btpw "lagos_sample_avg==1 & in_balanced_panel==1 & bassier_tpw==1"
	local s_direct_bapf "lagos_sample_avg==1 & in_balanced_panel==1 & bassier_apf==1"
	local interactions "l_firm_emp_2009 totalflows_n"
	local squares "totaltreat_pf_n_sq totaltreat_pw_n_sq avg_ftreat_pf_n_sq"

  qui: reghdfe lr_remmedr c.avg_ftreat_pf_n##b(2011).year if `s_spill', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year) ///
                vce(cluster identificad)  
		gen full_sample = e(sample)
		
// RUN SPILLOVER REGRESSION WITH MODE_UNION TO GET MODE_UNION SAMPLE:

local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0"
        

reghdfe lr_remmedr c.avg_ftreat_pf_n##b(2011).year if `s_spill', ///
                absorb(identificad year microregion#year mode_base_month#year industry1#year  mode_union#year) ///
                vce(cluster identificad)  
		gen mu_sample = e(sample)	

reghdfe lr_remmedr c.avg_ftreat_pf_n##b(2011).year if `s_spill', ///
                absorb(identificad year  mode_union#year) ///
                vce(cluster identificad)  
		gen mu_sample_1 = e(sample)	

		
local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0"
bys year: tab mu_sample if `s_spill'

local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0"
bys year: tab mu_sample if `s_spill' & !missing(lr_remmedr)


local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0"
bys year: tab full_sample if `s_spill' 	  

local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0"
bys year: count if missing(lr_remmedr) & `s_spill' // -> sort of accompanies the variation in missing obs each year	  
	

gen non_miss_lr_remmedr = !missing(lr_remmedr)

local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0"
bys year: tab mu_sample_1 if `s_spill'& non_miss_lr_remmedr==1

local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0"
count if year ==2009 & mu_sample==0 & `s_spill'& non_miss_lr_remmedr==1 

local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0"
preserve 
keep if year==2009 & `s_spill'
destring identificad, replace
collapse (count) identificad (mean) avg_ftreat_pf_n, by(mode_union)
gen pos_flow = cond(avg_ftreat_pf_n>0 & !missing(avg_ftreat_pf_n),1,0)
gen one_flow = cond(avg_ftreat_pf_n==.15,1,0)
tab identificad pos_flow
tab identificad one_flow
restore


// hypothesis 1: 
bys mode_union year: gen n_estabs_union = _N
bys mode_union year: egen avg_flow_union = mean(avg_ftreat_pf_n)
gen dm_avg_f_union = avg_ftreat_pf_n-avg_flow_union
gen mse_f_union = dm_avg_f_union^2


local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0"
tab n_estabs_union if year==2009 & `s_spill' & mu_sample ==0 & non_miss_lr_remmedr==1 & !missing(avg_ftreat_pf_n) & !missing(microregion)  & dm_avg_f_union!=0 & !missing(dm_avg_f_union)

local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0"
gen drop_h1 =  cond(year==2009 & `s_spill' & mu_sample ==0 & non_miss_lr_remmedr==1 & !missing(avg_ftreat_pf_n) & !missing(microregion)  & dm_avg_f_union!=0 & !missing(dm_avg_f_union), 1,0)

// hypothesis 2:  mode_union#year is going to be almost colinear with other tvfe, how many of the units above are still missing if we remove the other fixed effects? 

local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0"
gen drop_h2 =  cond(year==2009 & `s_spill' & mu_sample_1 ==0 & non_miss_lr_remmedr==1 & !missing(avg_ftreat_pf_n) & !missing(microregion)  & dm_avg_f_union!=0 & !missing(dm_avg_f_union), 1,0)

gen drop_h1_h2 = drop_h1*drop_h2

count if drop_h1_h2==1



local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0"
tab n_estabs_union if year==2009 & `s_spill' & mu_sample ==0 & mu_sample_1==0 & non_miss_lr_remmedr==1 & !missing(avg_ftreat_pf_n) & !missing(microregion)  & dm_avg_f_union!=0 & !missing(dm_avg_f_union)


save "$rais_firm/analysis_missing_mu_sing.dta", replace

// keep lr_remmedr microregion year mode_union industry1 mode_base_month identificad avg_ftreat_pf_n dm_avg_f_union mu_sample mu_sample_1 non_miss_lr_remmedr in_balanced_panel lagos_sample_avg treat_ultra
//
// local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0"
// keep if year==2009 & `s_spill' & mu_sample_1 ==0 & non_miss_lr_remmedr==1 & !missing(avg_ftreat_pf_n) & !missing(microregion) & dm_avg_f_union!=0 & !missing(dm_avg_f_union)
//
// gen pos_flow = cond(avg_ftreat_pf_n>0 & !missing(avg_ftreat_pf_n),1,0)
//
// local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0"
// tab n_estabs_union pos_flow if year==2009 & `s_spill'
//
// local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0"
// bys year: tab mu_sample if `s_spill'& non_miss_lr_remmedr==1 & !missing(avg_ftreat_pf_n) & n_estabs_union>1
//
// local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0"
// bys year: tab mu_sample if `s_spill'& non_miss_lr_remmedr==1 & !missing(avg_ftreat_pf_n) & n_estabs_union>1 & avg_flow_union>0


// Cahracteristics of dropped estabs due to mode_union (excludes dropped because of missing values)



// Distribution Graphs:

// 1. Establishment Size Categories
gen size_cat = .
replace size_cat = 1 if firm_emp <= 4
replace size_cat = 2 if firm_emp > 4 & firm_emp <= 9
replace size_cat = 3 if firm_emp > 9 & firm_emp <= 19
replace size_cat = 4 if firm_emp > 19 & firm_emp <= 49
replace size_cat = 5 if firm_emp > 49 & firm_emp <= 99
replace size_cat = 6 if firm_emp > 99 & firm_emp <= 249
replace size_cat = 7 if firm_emp > 249 & firm_emp <= 499
replace size_cat = 8 if firm_emp > 499 & firm_emp <= 999
replace size_cat = 9 if firm_emp > 999 & !missing(firm_emp)

label define size_lbl 1 "1-4" 2 "5-9" 3 "10-19" 4 "20-49" 5 "50-99" 6 "100-249" 7 "250-499" 8 "500-999" 9 ">1000"
label values size_cat size_lbl

// 2. Broad Industry Categories
gen broad_industry = .
label define broad_ind_lbl ///
    1 "Farming/fishing" ///
    2 "Extractive ind." ///
    3 "Manufacturing" ///
    4 "Utilities" ///
    5 "Construction" ///
    6 "Trade/commerce" ///
    7 "Transportation" ///
    8 "Hospitality" ///
    9 "Communication" ///
    10 "Banking/finance" ///
    11 "Real estate" ///
    12 "Professional act." ///
    13 "Administrative act." ///
    14 "Public admin." ///
    15 "Education" ///
    16 "Health" ///
    17 "Culture/sports" ///
    18 "Other"
label values broad_industry broad_ind_lbl

// Industry category assignments
replace broad_industry = 1 if inlist(big_industry, 1, 2, 3)
replace broad_industry = 2 if inrange(big_industry, 5, 9)
replace broad_industry = 3 if inrange(big_industry, 10, 33)
replace broad_industry = 4 if inrange(big_industry, 35, 39)
replace broad_industry = 5 if inrange(big_industry, 41, 43)
replace broad_industry = 6 if inrange(big_industry, 45, 47)
replace broad_industry = 7 if inrange(big_industry, 49, 53)
replace broad_industry = 8 if inrange(big_industry, 55, 56)
replace broad_industry = 9 if inrange(big_industry, 58, 63)
replace broad_industry = 10 if inrange(big_industry, 64, 66)
replace broad_industry = 11 if big_industry == 68
replace broad_industry = 12 if (inrange(big_industry, 69, 75) | inrange(big_industry, 77, 79))
replace broad_industry = 13 if inrange(big_industry, 80, 82)
replace broad_industry = 14 if big_industry == 84
replace broad_industry = 15 if big_industry == 85
replace broad_industry = 16 if inrange(big_industry, 86, 88)
replace broad_industry = 17 if inrange(big_industry, 90, 91)
replace broad_industry = 18 if inrange(big_industry, 92, 99)


preserve
keep if year==2009 & lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & !missing(avg_ftreat_pf_n) & !missing(lr_remmedr) &  mse_f_union!=0


tab broad_industry mu_sample if year==2009 & lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & !missing(avg_ftreat_pf_n) & !missing(lr_remmedr) & mse_f_union!=0, matcell(freq) matrow(values)
mata: st_matrix("pct", st_matrix("freq") :/ colsum(st_matrix("freq")) :* 100)

clear
svmat values
svmat pct

rename pct1 dropped_pct
rename pct2 kept_pct
rename values1 ind_value

gen ind_label = ""
replace ind_label = "Farming/fishing" if ind_value == 1
replace ind_label = "Extractive ind." if ind_value == 2
replace ind_label = "Manufacturing" if ind_value == 3
replace ind_label = "Utilities" if ind_value == 4
replace ind_label = "Construction" if ind_value == 5
replace ind_label = "Trade/commerce" if ind_value == 6
replace ind_label = "Transportation" if ind_value == 7
replace ind_label = "Hospitality" if ind_value == 8
replace ind_label = "Communication" if ind_value == 9
replace ind_label = "Banking/finance" if ind_value == 10
replace ind_label = "Real estate" if ind_value == 11
replace ind_label = "Professional act." if ind_value == 12
replace ind_label = "Administrative act." if ind_value == 13
replace ind_label = "Public admin." if ind_value == 14
replace ind_label = "Education" if ind_value == 15
replace ind_label = "Health" if ind_value == 16
replace ind_label = "Culture/sports" if ind_value == 17
replace ind_label = "Other" if ind_value == 18

graph bar (asis)  dropped_pct kept_pct , over(ind_label, sort(ind_value) label(labsize(small) angle(45))) ///
    bar(1, color(navy)) bar(2, color(eltblue)) ///
    legend(label(1 "Dropped") label(2 "Kept") region(style(none) color(none))) ///
    ytitle("Percent") title("Distribution by Broad Industry Group") ///
    ylabel(0(10)40, angle(horizontal)) ///
    graphregion(style(none) margin(zero)) ///
    scheme(s1mono)

graph export "$graphs/distro_broad_industry_mu_sample_1.png", replace
restore

// Geographical region dispersion

preserve
keep if year==2009 & lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & !missing(avg_ftreat_pf_n) & !missing(lr_remmedr)


tab big_region mu_sample , matcell(freq) matrow(values) 

mata: st_matrix("pct", st_matrix("freq") :/ colsum(st_matrix("freq")) :* 100)

clear
svmat values
svmat pct

rename pct1 dropped_pct
rename pct2 kept_pct
rename values1 category_value

gen region_label = ""
replace region_label = "North" if category_value == 1
replace region_label = "Northeast" if category_value == 2
replace region_label = "Southeast" if category_value == 3
replace region_label = "South" if category_value == 4
replace region_label = "Midwest" if category_value == 5

graph bar (asis)  dropped_pct kept_pct,  over(region_label, sort(category_value) label(labsize(vsmall) angle(45))) ///
    bar(1, color(navy)) bar(2, color(eltblue)) ///
    legend(label(1 "Dropped") label(2 "Kept") region(style(none) color(none))) ///
    ytitle("Percent") title("Distribution by Region") ///
    ylabel(0(10)60, angle(horizontal)) ///
    graphregion(style(none) margin(zero)) ///
    scheme(s1mono)

graph export "$graphs/distro_region_missing.png", replace
restore


// Establishment Size Distribution

preserve
keep if year==2009 & lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & !missing(avg_ftreat_pf_n) & !missing(lr_remmedr)

tab size_cat mu_sample if year==2009 & lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & !missing(avg_ftreat_pf_n) & !missing(lr_remmedr), matcell(freq) matrow(values)
mata: st_matrix("pct", st_matrix("freq") :/ colsum(st_matrix("freq")) :* 100)

clear
svmat values
svmat pct

rename pct1 dropped_pct
rename pct2 kept_pct
rename values1 category_value

gen size_label = ""
replace size_label = "1-4" if category_value == 1
replace size_label = "5-9" if category_value == 2
replace size_label = "10-19" if category_value == 3
replace size_label = "20-49" if category_value == 4
replace size_label = "50-99" if category_value == 5
replace size_label = "100-249" if category_value == 6
replace size_label = "250-499" if category_value == 7
replace size_label = "500-999" if category_value == 8
replace size_label = ">1000" if category_value == 9

graph bar (asis)  dropped_pct kept_pct, over(size_label, sort(category_value) label(labsize(small) angle(45))) ///
    blabel(bar, format(%9.1f)) ///
    bar(1, color(navy)) bar(2, color(eltblue)) ///
    legend(label(1 "Dropped") label(2 "Kept") region(style(none) color(none))) ///
    ytitle("Percent") title("Distribution by Establishment Size") ///
    ylabel(0(5)35, angle(horizontal)) ///
    graphregion(style(none) margin(zero)) ///
    scheme(s1mono)

graph export "$graphs/distro_establishment_size_missing.png", replace
restore

// Mode base month:


preserve
keep if year==2009 & lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & !missing(avg_ftreat_pf_n) & !missing(lr_remmedr)


tab mode_base_month mu_sample if year==2009 & lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & !missing(avg_ftreat_pf_n) & !missing(lr_remmedr), matcell(freq) matrow(values)
mata: st_matrix("pct", st_matrix("freq") :/ colsum(st_matrix("freq")) :* 100)

clear
svmat values
svmat pct

rename pct1 dropped_pct
rename pct2 kept_pct
rename values1 category_value

graph bar (asis) dropped_pct kept_pct, over(category_value, sort(category_value) label(labsize(small) angle(45))) ///
    blabel(bar, format(%9.1f)) ///
    bar(1, color(navy)) bar(2, color(eltblue)) ///
    legend(label(1 "Dropped") label(2 "Kept") region(style(none) color(none))) ///
    ytitle("Percent") title("Distribution by Negotiation Month") ///
    ylabel(0(5)40, angle(horizontal)) ///
    graphregion(style(none) margin(zero)) ///
    scheme(s1mono)

graph export "$graphs/distro_negotiation_month_missing.png", replace
restore


// totalflows_n

// Generate flows categories:


gen totalflows_cat = .
replace totalflows_cat = 0 if totalflows_n==0
replace totalflows_cat = 1 if totalflows_n > 0 & totalflows_n <=4
replace totalflows_cat = 2 if totalflows_n > 4 & totalflows_n <= 9
replace totalflows_cat = 3 if totalflows_n > 9 & totalflows_n <= 19
replace totalflows_cat = 4 if totalflows_n > 19 & totalflows_n <= 49
replace totalflows_cat = 5 if totalflows_n > 49 & totalflows_n <= 99
replace totalflows_cat = 6 if totalflows_n > 99 & totalflows_n <= 249
replace totalflows_cat = 7 if totalflows_n > 249 & totalflows_n <= 499
replace totalflows_cat = 8 if totalflows_n > 499 & totalflows_n <= 999
replace totalflows_cat = 9 if totalflows_n > 999 & !missing(totalflows_n)

label define totalflows_lbl 0 "0" 1 "1-4" 2 "5-9" 3 "10-19" 4 "20-49" 5 "50-99" 6 "100-249" 7 "250-499" 8 "500-999" 9 ">1000"
label values totalflows_cat totalflows_lbl

preserve
keep if year==2009 & lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & !missing(avg_ftreat_pf_n) & !missing(lr_remmedr)


tab totalflows_cat mu_sample if year==2009 & lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & !missing(avg_ftreat_pf_n) & !missing(lr_remmedr), matcell(freq) matrow(values)
mata: st_matrix("pct", st_matrix("freq") :/ colsum(st_matrix("freq")) :* 100)

clear
svmat values
svmat pct

rename pct1 dropped_pct
rename pct2 kept_pct
rename values1 category_value

gen size_label = ""
replace size_label = "0" if category_value ==0
replace size_label = "1-4" if category_value == 1
replace size_label = "5-9" if category_value == 2
replace size_label = "10-19" if category_value == 3
replace size_label = "20-49" if category_value == 4
replace size_label = "50-99" if category_value == 5
replace size_label = "100-249" if category_value == 6
replace size_label = "250-499" if category_value == 7
replace size_label = "500-999" if category_value == 8
replace size_label = ">1000" if category_value == 9

graph bar (asis) dropped_pct kept_pct, over(size_label, sort(category_value) label(labsize(small) angle(45))) ///
    blabel(bar, format(%9.1f)) ///
    bar(1, color(navy)) bar(2, color(eltblue)) ///
    legend(label(1 "Dropped") label(2 "Kept") region(style(none) color(none))) ///
    ytitle("Percent") title("Distribution by Total Flows Category ") ///
    ylabel(0(5)45, angle(horizontal)) ///
    graphregion(style(none) margin(zero)) ///
    scheme(s1mono)

graph export "$graphs/distro_totalflows__missing.png", replace
restore


// Average ratio of flow to treated over total flows:

// flow size categories:

gen avg_flow_cat = .
replace avg_flow_cat = 1 if avg_ftreat_pf_n == 0
replace avg_flow_cat = 2 if avg_ftreat_pf_n > 0 & avg_ftreat_pf_n <= 0.01
replace avg_flow_cat = 3 if avg_ftreat_pf_n > 0.01 & avg_ftreat_pf_n <= 0.02
replace avg_flow_cat = 4 if avg_ftreat_pf_n > 0.02 & avg_ftreat_pf_n <= 0.05
replace avg_flow_cat = 5 if avg_ftreat_pf_n > 0.05 & avg_ftreat_pf_n <= 0.1
replace avg_flow_cat = 6 if avg_ftreat_pf_n > 0.1 & avg_ftreat_pf_n <= 0.2
replace avg_flow_cat = 7 if avg_ftreat_pf_n > 0.2 & avg_ftreat_pf_n <= 0.3
replace avg_flow_cat = 8 if avg_ftreat_pf_n > 0.3 & avg_ftreat_pf_n <= 0.5
replace avg_flow_cat = 9 if avg_ftreat_pf_n > 0.5 & avg_ftreat_pf_n <= 1
replace avg_flow_cat = 10 if avg_ftreat_pf_n > 1 & !missing(avg_ftreat_pf_n)

preserve
keep if year==2009 & lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & !missing(avg_ftreat_pf_n) & !missing(lr_remmedr)


tab avg_flow_cat mu_sample, matcell(freq) matrow(values)
mata: st_matrix("pct", st_matrix("freq") :/ colsum(st_matrix("freq")) :* 100)

clear
svmat values
svmat pct

rename pct1 dropped_pct
rename pct2 kept_pct
rename values1 cat_value

* Build labels right before graph
gen flow_label = ""
replace flow_label = "0%" if cat_value == 1
replace flow_label = "0-1%" if cat_value == 2
replace flow_label = "1-2%" if cat_value == 3
replace flow_label = "2-5%" if cat_value == 4
replace flow_label = "5-10%" if cat_value == 5
replace flow_label = "10-20%" if cat_value == 6
replace flow_label = "20-30%" if cat_value == 7
replace flow_label = "30-50%" if cat_value == 8
replace flow_label = "50-100%" if cat_value == 9
replace flow_label = ">100%" if cat_value == 10

graph bar (asis) dropped_pct kept_pct, over(flow_label, sort(cat_value) label(labsize(small) angle(45))) ///
    blabel(bar, format(%9.1f)) ///
    bar(1, color(navy)) bar(2, color(eltblue)) ///
    legend(label(1 "Dropped") label(2 "Kept") region(style(none) color(none))) ///
    ytitle("Percent") title("Distribution by avg_ftreat_pf_n (%)") ///
    ylabel(0(10)80, angle(horizontal)) ///
    graphregion(style(none) margin(zero)) ///
    scheme(s1mono)

graph export "$graphs/distro_avg_flowtreat_pf_missing.png", replace
restore



// Averege flows to treat per worker:

* flow size categories for totaltreat_pw_n:

gen total_pw_cat = .
replace total_pw_cat = 1 if totaltreat_pw_n == 0
replace total_pw_cat = 2 if totaltreat_pw_n > 0 & totaltreat_pw_n <= 0.01
replace total_pw_cat = 3 if totaltreat_pw_n > 0.01 & totaltreat_pw_n <= 0.02
replace total_pw_cat = 4 if totaltreat_pw_n > 0.02 & totaltreat_pw_n <= 0.05
replace total_pw_cat = 5 if totaltreat_pw_n > 0.05 & totaltreat_pw_n <= 0.1
replace total_pw_cat = 6 if totaltreat_pw_n > 0.1 & totaltreat_pw_n <= 0.2
replace total_pw_cat = 7 if totaltreat_pw_n > 0.2 & totaltreat_pw_n <= 0.3
replace total_pw_cat = 8 if totaltreat_pw_n > 0.3 & totaltreat_pw_n <= 0.5
replace total_pw_cat = 9 if totaltreat_pw_n > 0.5 & totaltreat_pw_n <= 1
replace total_pw_cat = 10 if totaltreat_pw_n > 1 & !missing(totaltreat_pw_n)

preserve
keep if year==2009 & lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & !missing(avg_ftreat_pf_n) & !missing(lr_remmedr)


tab total_pw_cat mu_sample, matcell(freq) matrow(values)
mata: st_matrix("pct", st_matrix("freq") :/ colsum(st_matrix("freq")) :* 100)

clear
svmat values
svmat pct

rename pct1 dropped_pct
rename pct2 kept_pct
rename values1 cat_value

* Build labels right before graph
gen flow_label = ""
replace flow_label = "0%" if cat_value == 1
replace flow_label = "0-1%" if cat_value == 2
replace flow_label = "1-2%" if cat_value == 3
replace flow_label = "2-5%" if cat_value == 4
replace flow_label = "5-10%" if cat_value == 5
replace flow_label = "10-20%" if cat_value == 6
replace flow_label = "20-30%" if cat_value == 7
replace flow_label = "30-50%" if cat_value == 8
replace flow_label = "50-100%" if cat_value == 9
replace flow_label = ">100%" if cat_value == 10

graph bar (asis) dropped_pct kept_pct, over(flow_label, sort(cat_value) label(labsize(small) angle(45))) ///
    blabel(bar, format(%9.1f)) ///
    bar(1, color(navy)) bar(2, color(eltblue)) ///
    legend(label(1 "Dropped") label(2 "Kept") region(style(none) color(none))) ///
    ytitle("Percent") title("Distribution by totaltreat_pw_n (%)") ///
    ylabel(0(10)80, angle(horizontal)) ///
    graphregion(style(none) margin(zero)) ///
    scheme(s1mono)

graph export "$graphs/distro_totaltreat_pw_missing.png", replace
restore


// Averege flows to treat per worker:

* flow size categories for totaltreat_pw_n:

gen total_remed_cat = .
replace total_remed_cat = 2 if r_remmedr > 0 & r_remmedr <= 800
replace total_remed_cat = 3 if r_remmedr > 800 & r_remmedr <= 1200
replace total_remed_cat = 4 if r_remmedr > 1200 & r_remmedr <= 2000
replace total_remed_cat = 5 if r_remmedr > 2000 & r_remmedr <= 4000
replace total_remed_cat = 6 if r_remmedr > 4000 & !missing(r_remmedr)


preserve
keep if year==2009 & lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & !missing(avg_ftreat_pf_n) & !missing(lr_remmedr)


tab total_remed_cat mu_sample, matcell(freq) matrow(values)
mata: st_matrix("pct", st_matrix("freq") :/ colsum(st_matrix("freq")) :* 100)

clear
svmat values
svmat pct

rename pct1 dropped_pct
rename pct2 kept_pct
rename values1 cat_value

* Build labels right before graph
gen flow_label = ""
replace flow_label = "0-800" if cat_value == 2
replace flow_label = "800-1200" if cat_value == 3
replace flow_label = "1200-2000" if cat_value == 4
replace flow_label = "2000-4000" if cat_value == 5
replace flow_label = ">4000" if cat_value == 6

graph bar (asis) dropped_pct kept_pct, over(flow_label, sort(cat_value) label(labsize(small) angle(45))) ///
    blabel(bar, format(%9.1f)) ///
    bar(1, color(eltblue)) bar(2, color(edkblue)) ///
    legend(label(1 "Dropped") label(2 "Kept") region(style(none) color(none))) ///
    ytitle("Percent") title("Distribution by Real Avg Earnings") ///
    ylabel(0(5)45, angle(horizontal)) ///
    graphregion(style(none) margin(zero)) ///
    scheme(s1mono)

graph export "$graphs/distro_remmedr_missing.png", replace
restore
