********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR:  LUIS GOMES
* PROGRAM: PLOTS TO IDENTIFY WAHT SETS APPRAT AVG_FLOWTREAT_PF =0 ESTABS TO OTHERS
* INPUT:   LABOR ANALYSIS DATASET, RESTRICTED TO LAGOS SAMPLE
* OUTPUT:  PLOTS FOR DIFFERENT FIRM CHARACTERISTICS BETWEEN FIRMS WITH MISSING AND 
*          NON-MISSING AVG_FLOWTREAT_PF.	 
********************************************************************************

use "$rais_firm/cba_rais_firm_2009_2016_flows.dta", clear

keep if lagos_sample_avg==1


// Distribution Graphs:

preserve
keep if year==2011 & lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0

gen has_avg_flowtreat_pf = !missing(avg_flowtreat_pf)

tab broad_industry has_avg_flowtreat_pf, matcell(freq) matrow(values)
mata: st_matrix("pct", st_matrix("freq") :/ colsum(st_matrix("freq")) :* 100)

clear
svmat values
svmat pct

rename pct1 missing_pct
rename pct2 non_missing_pct
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

graph bar (asis) non_missing_pct missing_pct, over(ind_label, sort(ind_value) label(labsize(small) angle(45))) ///
    bar(1, color(navy)) bar(2, color(sand)) ///
    legend(label(1 "Non-missing") label(2 "Missing") region(style(none) color(none))) ///
    ytitle("Percent") title("Distribution by Broad Industry Group") ///
    ylabel(0(10)40, angle(horizontal)) ///
    graphregion(style(none) margin(zero)) ///
    scheme(s1mono)

graph export "$graphs/distro_broad_industry_missing.png", replace
restore

// Geographical region dispersion

preserve
keep if year==2011 & lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0

gen has_avg_flowtreat_pf = !missing(avg_flowtreat_pf)

tab big_region has_avg_flowtreat_pf, matcell(freq) matrow(values)
mata: st_matrix("pct", st_matrix("freq") :/ colsum(st_matrix("freq")) :* 100)

clear
svmat values
svmat pct

rename pct1 missing_pct
rename pct2 non_missing_pct
rename values1 category_value

gen region_label = ""
replace region_label = "North" if category_value == 1
replace region_label = "Northeast" if category_value == 2
replace region_label = "Southeast" if category_value == 3
replace region_label = "South" if category_value == 4
replace region_label = "Midwest" if category_value == 5

graph bar (asis) non_missing_pct missing_pct, over(region_label, sort(category_value) label(labsize(vsmall) angle(45))) ///
    bar(1, color(navy)) bar(2, color(sand)) ///
    legend(label(1 "Non-missing") label(2 "Missing") region(style(none) color(none))) ///
    ytitle("Percent") title("Distribution by Region") ///
    ylabel(0(10)60, angle(horizontal)) ///
    graphregion(style(none) margin(zero)) ///
    scheme(s1mono)

graph export "$graphs/distro_region_missing.png", replace
restore


// Establishment Size Distribution

preserve
keep if year==2010 & lagos_sample_avg==1  & treat_ultra==0

gen has_avg_flowtreat_pf = !missing(avg_flowtreat_pf)

tab size_cat has_avg_flowtreat_pf, matcell(freq) matrow(values)
mata: st_matrix("pct", st_matrix("freq") :/ colsum(st_matrix("freq")) :* 100)

clear
svmat values
svmat pct

rename pct1 missing_pct
rename pct2 non_missing_pct
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

graph bar (asis) non_missing_pct missing_pct, over(size_label, sort(category_value) label(labsize(small) angle(45))) ///
    blabel(bar, format(%9.1f)) ///
    bar(1, color(navy)) bar(2, color(eltblue)) ///
    legend(label(1 "Non-Missing") label(2 "Missing") region(style(none) color(none))) ///
    ytitle("Percent") title("Distribution by Establishment Size") ///
    ylabel(0(5)35, angle(horizontal)) ///
    graphregion(style(none) margin(zero)) ///
    scheme(s1mono)

graph export "$graphs/distro_establishment_size_missing.png", replace
restore

// Mode base month:


preserve
keep if lagos_sample_avg == 1 & in_balanced_panel==1 & treat_ultra==0 & year==2009

gen has_avg_flowtreat_pf = !missing(avg_flowtreat_pf)

tab mode_base_month has_avg_flowtreat_pf, matcell(freq) matrow(values)
mata: st_matrix("pct", st_matrix("freq") :/ colsum(st_matrix("freq")) :* 100)

clear
svmat values
svmat pct

rename pct1 missing_pct
rename pct2 non_missing_pct
rename values1 category_value

graph bar (asis) non_missing_pct missing_pct, over(category_value, sort(category_value) label(labsize(small) angle(45))) ///
    blabel(bar, format(%9.1f)) ///
    bar(1, color(navy)) bar(2, color(eltblue)) ///
    legend(label(1 "Non-missing") label(2 "Missing") region(style(none) color(none))) ///
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
keep if year==2009 & lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0

gen has_avg_flowtreat_pf = !missing(avg_flowtreat_pf)

tab totalflows_cat has_avg_flowtreat_pf, matcell(freq) matrow(values)
mata: st_matrix("pct", st_matrix("freq") :/ colsum(st_matrix("freq")) :* 100)

clear
svmat values
svmat pct

rename pct1 missing_pct
rename pct2 non_missing_pct
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

graph bar (asis) non_missing_pct missing_pct, over(size_label, sort(category_value) label(labsize(small) angle(45))) ///
    blabel(bar, format(%9.1f)) ///
    bar(1, color(navy)) bar(2, color(eltblue)) ///
    legend(label(1 "Non-missing") label(2 "Missing") region(style(none) color(none))) ///
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
keep if year==2011 & lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0

gen has_avg_flowtreat_pf = !missing(avg_flowtreat_pf)

tab avg_flow_cat has_avg_flowtreat_pf, matcell(freq) matrow(values)
mata: st_matrix("pct", st_matrix("freq") :/ colsum(st_matrix("freq")) :* 100)

clear
svmat values
svmat pct

rename pct1 missing_pct
rename pct2 non_missing_pct
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

graph bar (asis) missing_pct non_missing_pct, over(flow_label, sort(cat_value) label(labsize(small) angle(45))) ///
    blabel(bar, format(%9.1f)) ///
    bar(1, color(eltblue)) bar(2, color(navy)) ///
    legend(label(1 "Missing") label(2 "Non-missing") region(style(none) color(none))) ///
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
keep if year==2011 & lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0

gen has_avg_flowtreat_pf = !missing(avg_flowtreat_pf)

tab total_pw_cat has_avg_flowtreat_pf, matcell(freq) matrow(values)
mata: st_matrix("pct", st_matrix("freq") :/ colsum(st_matrix("freq")) :* 100)

clear
svmat values
svmat pct

rename pct1 missing_pct
rename pct2 non_missing_pct
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

graph bar (asis) missing_pct non_missing_pct, over(flow_label, sort(cat_value) label(labsize(small) angle(45))) ///
    blabel(bar, format(%9.1f)) ///
    bar(1, color(eltblue)) bar(2, color(navy)) ///
    legend(label(1 "Missing") label(2 "Non-missing") region(style(none) color(none))) ///
    ytitle("Percent") title("Distribution by totaltreat_pw_n (%)") ///
    ylabel(0(10)80, angle(horizontal)) ///
    graphregion(style(none) margin(zero)) ///
    scheme(s1mono)

graph export "$graphs/distro_totaltreat_pw_missing.png", replace
restore


/ Averege flows to treat per worker:

* flow size categories for totaltreat_pw_n:

gen total_remed_cat = .
replace total_remed_cat = 2 if r_remmedr > 0 & r_remmedr <= 800
replace total_remed_cat = 3 if r_remmedr > 800 & r_remmedr <= 1200
replace total_remed_cat = 4 if r_remmedr > 1200 & r_remmedr <= 2000
replace total_remed_cat = 5 if r_remmedr > 2000 & r_remmedr <= 4000
replace total_remed_cat = 6 if r_remmedr > 4000 & !missing(r_remmedr)


preserve
keep if year==2009 & lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0

gen has_avg_flowtreat_pf = !missing(avg_flowtreat_pf)

tab total_remed_cat has_avg_flowtreat_pf, matcell(freq) matrow(values)
mata: st_matrix("pct", st_matrix("freq") :/ colsum(st_matrix("freq")) :* 100)

clear
svmat values
svmat pct

rename pct1 missing_pct
rename pct2 non_missing_pct
rename values1 cat_value

* Build labels right before graph
gen flow_label = ""
replace flow_label = "0-800" if cat_value == 2
replace flow_label = "800-1200" if cat_value == 3
replace flow_label = "1200-2000" if cat_value == 4
replace flow_label = "2000-4000" if cat_value == 5
replace flow_label = ">4000" if cat_value == 6

graph bar (asis) missing_pct non_missing_pct, over(flow_label, sort(cat_value) label(labsize(small) angle(45))) ///
    blabel(bar, format(%9.1f)) ///
    bar(1, color(eltblue)) bar(2, color(edkblue)) ///
    legend(label(1 "Missing") label(2 "Non-missing") region(style(none) color(none))) ///
    ytitle("Percent") title("Distribution by Real Avg Earnings") ///
    ylabel(0(5)45, angle(horizontal)) ///
    graphregion(style(none) margin(zero)) ///
    scheme(s1mono)

graph export "$graphs/distro_remmedr_missing.png", replace
restore
