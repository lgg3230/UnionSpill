********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: BALANCE TESTS WITH LAGOS SAMPLE, ATTEMPT TO REPLICATE PARALLEL TRENDS
* INPUT: MERGED CBA RAIS, W/OUT CLAUSE VARIABLES
* OUTPUT: LATEX BALANCE TABLES AND GRAPHS; TWFE ESTIMATES FOR DIRECT EFFECT WITH PARALLEL TRENDS TEST
********************************************************************************


ssc install coefplot, replace all 

use "$rais_firm/cba_rais_firm_2009_2017_rep_3.dta",clear 



//Generate locals to run regression loops:


// local outcomes " turnover retention layoffs hiring l_firm_emp lr_remdezr"
//
// local exposures "con_2009_2010 con_2010_2011 con_2011_2012"
//
// // Generate graphs for comparison with Lagos's paper:
//
// // BALANCE CHECKS:
//
// preserve
// // Keep only pre-treatment period for balance analysis
//     keep if year == 2011 & lagos_sample == 1  & in_balanced_panel==1
//
//     // Create a clean balance table
//     iebaltab l_firm_emp lr_salcontr_m lr_remmedr retention turnover /// 
//              prop_sup prop_hs prop_below_30 prop_30_40 prop_above_40 ///
//              white_prop male_prop avg_tenure hiring layoffs quits ///
//              if year == 2011, ///
//              grpvar(treat_ultra) control(0) replace savexlsx("$tables/balance_table.xlsx") ///
//              rowvarlabels
// restore
//
// preserve
// keep if year == 2011 & lagos_sample == 1 
// count
// count if treat_ultra==1
// count if treat_ultra==0
// count if missing(l_firm_emp)
// count if missing(lr_remdezr)
// count if missing(lr_remdezr)
// count if missing(lr_salcontr_m)
// restore
//
//
// bysort year: count if missing(lr_salcontr_m) & lagos_sample == 1  & in_balanced_panel==1

********************************************************************************
**# Bookmark #3
//  PART I: Distribution Statistics
********************************************************************************


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

// 1. Industry Distribution Graph
preserve
keep if year==2011 & lagos_sample==1 
    
    
    // Create the distribution calculation
    tab broad_industry treat_ultra, matcell(freq) matrow(values)
    
    // Convert to percentages
    mata: st_matrix("pct", st_matrix("freq") :/ colsum(st_matrix("freq")) :* 100)
    
    // Create graph dataset
//     preserve
        clear
        svmat values
        svmat pct
        
        // Rename variables
        rename pct1 control_pct
        rename pct2 treat_pct
        rename values1 ind_value
        
        // Add labels
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
        
        // Create the graph
        graph bar (asis) control_pct treat_pct, over(ind_label, sort(ind_value) label(labsize(small) angle(45))) ///
            bar(1, color(navy)) bar(2, color(sand)) ///
            legend(label(1 "Control") label(2 "Treated")  region(style(none) color(none))) ///
            ytitle("Percent") title("Distribution by Broad Industry Group") ///
            ylabel(0(10)40, angle(horizontal)) ///
			graphregion(style(none) margin(zero)) ///
			scheme(s1mono)
			
        // Save the graph
        graph export "$graphs/distro_broad_industry.png", replace
//     restore
  restore
  
  preserve
keep if year==2011 & lagos_sample==1 & in_balanced_panel==1
    
    
    // Create the distribution calculation
    tab broad_industry treat_ultra, matcell(freq) matrow(values)
    
    // Convert to percentages
    mata: st_matrix("pct", st_matrix("freq") :/ colsum(st_matrix("freq")) :* 100)
    
    // Create graph dataset
//     preserve
        clear
        svmat values
        svmat pct
        
        // Rename variables
        rename pct1 control_pct
        rename pct2 treat_pct
        rename values1 ind_value
        
        // Add labels
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
        
        // Create the graph
        graph bar (asis) control_pct treat_pct, over(ind_label, sort(ind_value) label(labsize(small) angle(45))) ///
            bar(1, color(navy)) bar(2, color(sand)) ///
            legend(label(1 "Control") label(2 "Treated")  region(style(none) color(none))) ///
            ytitle("Percent") title("Distribution by Broad Industry Group - Bal. Panel") ///
            ylabel(0(10)40, angle(horizontal)) ///
			graphregion(style(none) margin(zero)) ///
			scheme(s1mono)
			
        // Save the graph
        graph export "$graphs/distro_broad_industry_bp.png", replace
//     restore
  restore

// 2. Region Distribution Graph
preserve
    keep if year == 2011 & lagos_sample == 1
    
    // Create frequency tables
    tab big_region treat_ultra, matcell(freq) matrow(values)
    
    // Convert to percentages by treatment status
    mata: st_matrix("pct", st_matrix("freq") :/ colsum(st_matrix("freq")) :* 100)
    
    // Create dataset for graphing
    clear
    svmat values
    svmat pct
    
    // Rename variables
    rename pct1 control_pct
    rename pct2 treat_pct
    rename values1 category_value
    
    // Add labels
    gen region_label = ""
    replace region_label = "North" if category_value == 1
    replace region_label = "Northeast" if category_value == 2
    replace region_label = "Southeast" if category_value == 3
    replace region_label = "South" if category_value == 4
    replace region_label = "Midwest" if category_value == 5
    
    // Region Distribution Graph
    graph bar (asis) control_pct treat_pct, over(region_label, sort(category_value) label(labsize(vsmall) angle(45))) ///
        bar(1, color(navy)) bar(2, color(sand)) ///
        legend(label(1 "Control") label(2 "Treated") region(style(none) color(none))) ///
        ytitle("Percent") title("Distribution by Region") ///
        ylabel(0(10)60, angle(horizontal)) ///
        graphregion(style(none) margin(zero)) ///
        scheme(s1mono)
    
    // Save the graph
    graph export "$graphs/distro_region.png", replace
restore

preserve
    keep if year == 2011 & lagos_sample == 1 & in_balanced_panel==1
    
    // Create frequency tables
    tab big_region treat_ultra, matcell(freq) matrow(values)
    
    // Convert to percentages by treatment status
    mata: st_matrix("pct", st_matrix("freq") :/ colsum(st_matrix("freq")) :* 100)
    
    // Create dataset for graphing
    clear
    svmat values
    svmat pct
    
    // Rename variables
    rename pct1 control_pct
    rename pct2 treat_pct
    rename values1 category_value
    
    // Add labels
    gen region_label = ""
    replace region_label = "North" if category_value == 1
    replace region_label = "Northeast" if category_value == 2
    replace region_label = "Southeast" if category_value == 3
    replace region_label = "South" if category_value == 4
    replace region_label = "Midwest" if category_value == 5
    
    // Region Distribution Graph
    graph bar (asis) control_pct treat_pct, over(region_label, sort(category_value) label(labsize(vsmall) angle(45))) ///
        bar(1, color(navy)) bar(2, color(sand)) ///
        legend(label(1 "Control") label(2 "Treated") region(style(none) color(none))) ///
        ytitle("Percent") title("Distribution by Region - Bal Panel") ///
        ylabel(0(10)60, angle(horizontal)) ///
        graphregion(style(none) margin(zero)) ///
        scheme(s1mono)
    
    // Save the graph
    graph export "$graphs/distro_region.png", replace
restore

// 3. Establishment Size Distribution Graph
preserve
    keep if year == 2011 & lagos_sample == 1
    
    // Create frequency tables
    tab size_cat treat_ultra, matcell(freq) matrow(values)
    
    // Convert to percentages by treatment status
    mata: st_matrix("pct", st_matrix("freq") :/ colsum(st_matrix("freq")) :* 100)
    
    // Create dataset for graphing
    clear
    svmat values
    svmat pct
    
    // Rename variables
    rename pct1 control_pct
    rename pct2 treat_pct
    rename values1 category_value
    
    // Add labels
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
    
    // Establishment Size Distribution Graph
    graph bar (asis) control_pct treat_pct, over(size_label, sort(category_value) label(labsize(small) angle(45))) ///
        blabel(bar, format(%9.1f)) ///
        bar(1, color(navy)) bar(2, color(sand)) ///
        legend(label(1 "Control") label(2 "Treated") region(style(none) color(none))) ///
        ytitle("Percent") title("Distribution by Establishment Size") ///
        ylabel(0(5)30, angle(horizontal)) ///
        graphregion(style(none) margin(zero)) ///
        scheme(s1mono)
    
    // Save the graph
    graph export "$graphs/distro_establishment_size.png", replace
restore


// 4. Mode base month Distribution Graph:
preserve
   keep if year == 2011 & lagos_sample == 1
   
   // Create frequency tables
   tab mode_base_month treat_ultra, matcell(freq) matrow(values)
   
   // Convert to percentages by treatment status
   mata: st_matrix("pct", st_matrix("freq") :/ colsum(st_matrix("freq")) :* 100)
   
   // Create dataset for graphing
   clear
   svmat values
   svmat pct
   
   // Rename variables
   rename pct1 control_pct
   rename pct2 treat_pct
   rename values1 category_value
   
   // Establishment Size Distribution Graph
   graph bar (asis) control_pct treat_pct, over(category_value, sort(category_value) label(labsize(small) angle(45))) ///
       blabel(bar, format(%9.1f)) ///
       bar(1, color(navy)) bar(2, color(sand)) ///
       legend(label(1 "Control") label(2 "Treated") region(style(none) color(none))) ///
       ytitle("Percent") title("Distribution by Negotiation Month") ///
       ylabel(0(5)40, angle(horizontal)) ///
       graphregion(style(none) margin(zero)) ///
       scheme(s1mono)
   
   // Save the graph
   graph export "$graphs/distro_negotiation_month.png", replace
restore
 
********************************************************************************
**# Bookmark #2
 // PART II: Evolution of Selected Outcomes
********************************************************************************

preserve
    // Keep only observations in the Lagos sample with balanced panel
    keep if lagos_sample==1 & in_balanced_panel==1
	destring identificad, replace force
    
    // Collapse to treatment-year level to get means
    collapse (mean) l_firm_emp firm_emp lr_remmedr lr_remdezr (count) n_firms=identificad, by(treat_ultra year)
    
    // Create the line graph
    twoway (connected l_firm_emp year if treat_ultra==1, lcolor(sand) lwidth(medthick) ///
             mcolor(sand) msymbol(O) msize(medium)) ///
           (connected l_firm_emp year if treat_ultra==0, lcolor(navy) lwidth(medthick) ///
             mcolor(navy) msymbol(D) msize(medium)), ///
           xline(2012.8, lpattern(dash) lcolor(gray)) ///
           xlabel(2009(1)2017, labsize(medium)) ///
           ylabel(3.3(0.05)3.55, angle(horizontal)) ///
           ytitle("Log Employment")  ///
		   xtitle("") ///
           legend(order(1 "Treated" 2 "Control") pos(6) row(1) region(lstyle(none))) ///
           title("Log Employment Evolution by Treatment Status", size(medium large)) ///
           note("Vertical line indicates introduction of ultractivity (September 2012)") ///
		   graphregion(margin(medium) color(white))
		   
		   
    // Save the graph
    graph export "$graphs/log_emp_evolution.png", replace
	
	
	
	twoway (connected firm_emp year if treat_ultra==1, lcolor(sand) lwidth(medthick) ///
             mcolor(sand) msymbol(O) msize(medium)) ///
           (connected firm_emp year if treat_ultra==0, lcolor(navy) lwidth(medthick) ///
             mcolor(navy) msymbol(D) msize(medium)), ///
           xline(2011.8, lpattern(dash) lcolor(gray)) ///
           xlabel(2009(1)2017, labsize(medium)) ///
           ylabel(120(5)145, angle(horizontal)) ///
           ytitle("December employment")  ///
		   xtitle("") ///
           legend(order(1 "Treated" 2 "Control") pos(6) row(1) region(lstyle(none))) ///
           title("Employment Evolution by Treatment Status", size(medium large)) ///
           note("Vertical line indicates introduction of ultractivity (September 2012)") ///
		   graphregion( margin(medium) color(white))
		   
  
    // Save the graph
    graph export "$graphs/lev_emp_evolution.png", replace
	
	
	twoway (connected lr_remmedr year if treat_ultra==1, lcolor(sand) lwidth(medthick) ///
             mcolor(sand) msymbol(O) msize(medium)) ///
           (connected lr_remmedr year if treat_ultra==0, lcolor(navy) lwidth(medthick) ///
             mcolor(navy) msymbol(D) msize(medium)), ///
           xline(2011.8, lpattern(dash) lcolor(gray)) ///
           xlabel(2009(1)2017, labsize(medium)) ///
           ylabel(7.2(0.2)8, angle(horizontal)) ///
           ytitle("Log avg wages")  ///
		   xtitle("") ///
           legend(order(1 "Treated" 2 "Control") pos(6) row(1) region(lstyle(none))) ///
           title("Log ave Evolution by Treatment Status", size(medium large)) ///
           note("Vertical line indicates introduction of ultractivity (September 2012)") ///
		   graphregion( margin(medium) color(white))
		   
		   
  
    // Save the graph
    graph export "$graphs/log_remmedr_evolution.png", replace
	
	twoway (connected lr_remdezr year if treat_ultra==1, lcolor(sand) lwidth(medthick) ///
             mcolor(sand) msymbol(O) msize(medium)) ///
           (connected lr_remdezr year if treat_ultra==0, lcolor(navy) lwidth(medthick) ///
             mcolor(navy) msymbol(D) msize(medium)), ///
           xline(2011.8, lpattern(dash) lcolor(gray)) ///
           xlabel(2009(1)2017, labsize(medium)) ///
           ylabel(7.2(0.2)8, angle(horizontal)) ///
           ytitle("Log Dec wages")  ///
		   xtitle("") ///
           legend(order(1 "Treated" 2 "Control") pos(6) row(1) region(lstyle(none))) ///
           title("Log Dec Wages Evolution by Treatment Status", size(medium large)) ///
           note("Vertical line indicates introduction of ultractivity (September 2012)") ///
		   graphregion( margin(medium) color(white))
		   
  
    // Save the graph
    graph export "$graphs/log_remdezr_evolution.png", replace
	
	
	
restore
 
 



**# Bookmark #1
//Different attempts at reproducing LAgos:


// I. Direct interpretation:

// I.a. log employment

reghdfe l_firm_emp treat_ultra##b(2011).year  if lagos_sample==1 ,  absorb( identificad industry1#year mode_base_month#year microregion#year) vce(cluster identificad)
estimates store es_direct_emp

// Create event study plot
coefplot es_direct_emp, ///
    keep(1.treat_ultra#2009.year 1.treat_ultra#2010.year 1.treat_ultra#2011.year 1.treat_ultra#2012.year 1.treat_ultra#2013.year 1.treat_ultra#2014.year 1.treat_ultra#2015.year 1.treat_ultra#2016.year) ///
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
    title("Direct Effect on Log-Employment", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
	
graph export "$graphs/es_l_emp_treat.png", as(png) replace

// I.b. log avarage earnings:

reghdfe lr_remmedr treat_ultra##b(2011).year  if lagos_sample==1 & in_balanced_panel==1, absorb(year identificad industry1#year mode_base_month#year microregion#year) vce(cluster identificad)
estimates store es_direct_remmedr

// Create event study plot
coefplot es_direct_remmedr, ///
    keep(1.treat_ultra#2009.year 1.treat_ultra#2010.year 1.treat_ultra#2011.year 1.treat_ultra#2012.year 1.treat_ultra#2013.year 1.treat_ultra#2014.year 1.treat_ultra#2015.year 1.treat_ultra#2016.year) ///
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
    title("Direct Effect on Log Average Wages", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
	
graph export "$graphs/es_l_remmedr_treat.png", as(png) replace

// I.c. log december earnings:

reghdfe lr_remdezr treat_ultra##b(2011).year  if lagos_sample==1 , absorb(year identificad industry1#year mode_base_month#year microregion#year) vce(cluster identificad)
estimates store es_direct_remdezr

// Create event study plot
coefplot es_direct_remdezr, ///
    keep(1.treat_ultra#2009.year 1.treat_ultra#2010.year 1.treat_ultra#2011.year 1.treat_ultra#2012.year 1.treat_ultra#2013.year 1.treat_ultra#2014.year 1.treat_ultra#2015.year 1.treat_ultra#2016.year) ///
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
    title("Direct Effect on Log December Wages", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
	
graph export "$graphs/es_l_remdezr_treat.png", as(png) replace





// II. Attempting approach similar to Basssier (2023):

// Create the pre-treatment employment level and growth rate variables
bysort identificad: egen emp_2009 = max(l_firm_emp*(year==2009))
bysort identificad: egen emp_2010 = max(l_firm_emp*(year==2010))
gen emp_growth_09_10 = emp_2010 - emp_2009

// Create the pre-treatment wage level and growth rate variables
bysort identificad: egen wage_2009 = max(lr_remmedr*(year==2009))
bysort identificad: egen wage_2010 = max(lr_remmedr*(year==2010))
gen wage_growth_09_10 = wage_2010 - wage_2009


// Run the regressions:

// II.a. Log-employment:

 reghdfe l_firm_emp i.treat_ultra##ib(2011).year c.emp_2009#i.year c.wage_2009#i.year c.emp_growth_09_10#i.year c.wage_growth_09_10#i.year if lagos_sample==1 , absorb(identificad industry#year  microrregiao#year mode_base_month#year  ) vce(cluster identificad)

estimates store es_direct_dt

 // Create event study plot

 coefplot es_direct_dt, ///
    keep(1.treat_ultra#2009.year 1.treat_ultra#2010.year 1.treat_ultra#2011.year 1.treat_ultra#2012.year 1.treat_ultra#2013.year 1.treat_ultra#2014.year 1.treat_ultra#2015.year 1.treat_ultra#2016.year) ///
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
    title("Direct Effect on Log Employment, with extra controls", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
	

graph export "$graphs/es_lemp_treat_bassier.png", as(png) replace


// II.b. Log-real average wages:

 reghdfe lr_remmedr i.treat_ultra##ib(2011).year c.emp_2009#i.year c.wage_2009#i.year c.emp_growth_09_10#i.year c.wage_growth_09_10#i.year if lagos_sample==1  & in_balanced_panel==1, absorb(identificad industry#year  microrregiao#year mode_base_month#year  ) vce(cluster identificad)

estimates store es_direct_dt

 // Create event study plot

 coefplot es_direct_dt, ///
   keep(1.treat_ultra#2009.year 1.treat_ultra#2010.year 1.treat_ultra#2011.year 1.treat_ultra#2012.year 1.treat_ultra#2013.year 1.treat_ultra#2014.year 1.treat_ultra#2015.year 1.treat_ultra#2016.year) ///
    coeflabels(1.treat_ultra#2009.year = "2009" ///
              1.treat_ultra#2010.year = "2010" ///
              1.treat_ultra#2011.year = "2011" ///
              1.treat_ultra#2012.year = "2012" ///
              1.treat_ultra#2013.year = "2013" ///
              1.treat_ultra#2014.year = "2014" ///
              1.treat_ultra#2015.year = "2015" ///
              1.treat_ultra#2016.year = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-.02(.01).02) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Direct Effect on Log Average Wages, with extra controls", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
	

graph export "$graphs/es_lremmedr_treat_bassier.png", as(png) replace

// II.c. Log-real december wages:

 reghdfe lr_remdezr i.treat_ultra##ib(2011).year c.emp_2009#i.year c.wage_2009#i.year c.emp_growth_09_10#i.year c.wage_growth_09_10#i.year if lagos_sample==1  & in_balanced_panel==1, absorb(identificad industry#year  microrregiao#year mode_base_month#year  ) vce(cluster identificad)

estimates store es_direct_dt

 // Create event study plot

 coefplot es_direct_dt, ///
    keep(1.treat_ultra#2009.year 1.treat_ultra#2010.year 1.treat_ultra#2011.year 1.treat_ultra#2012.year 1.treat_ultra#2013.year 1.treat_ultra#2014.year 1.treat_ultra#2015.year 1.treat_ultra#2016.year) ///
    coeflabels(1.treat_ultra#2009.year = "2009" ///
              1.treat_ultra#2010.year = "2010" ///
              1.treat_ultra#2011.year = "2011" ///
              1.treat_ultra#2012.year = "2012" ///
              1.treat_ultra#2013.year = "2013" ///
              1.treat_ultra#2014.year = "2014" ///
              1.treat_ultra#2015.year = "2015" ///
              1.treat_ultra#2016.year = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-.02(.01).02) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Direct Effect on Log Dec Wages, with extra controls", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
	

graph export "$graphs/es_lremdezr_treat_bassier.png", as(png) replace



	
// III.	 Try to implement matched DiD:


preserve 

keep if lagos_sample==1 & in_balanced_panel==1

keep if inrange(year, 2009, 2011)

keep identificad year l_firm_emp industry microrregiao mode_base_month treat_ultra

bysort identificad: egen estab_industry = mode(industry)
bysort identificad: egen estab_microregion = mode(microrregiao)

drop industry microrregiao

reshape wide l_firm_emp, i(identificad) j(year)

gen control_ultra=cond(treat_ultra==0,1,0)

// Match treated units to control units with replacement
psmatch2 treat_ultra ///
         l_firm_emp2011 l_firm_emp2010 l_firm_emp2009 ///
         i.estab_industry i.estab_microregion i.mode_base_month, ///
         outcome(l_firm_emp2011) ///
         neighbor(1) common noreplacement ///
         
         
// Create a strata variable for matched pairs
gen strata = _id if treat_ultra==0
replace strata = _n1 if treat_ultra==1
keep identificad strata treat_ultra


// Step 3: Check balance across matched pairs 
bys strata: egen n_units = count(identificad)
tab n_units  // Should show mostly values of 2 (pairs)

// Step 4: Apply matched DiD only to properly matched pairs
keep if n_units == 2

save "$rais_aux/matched_pairs.dta", replace

restore

merge m:1 identificad using "$rais_aux/matched_pairs.dta"


// III.a effects on firm employment:
 reghdfe l_firm_emp i.treat_ultra##ib(2011).year if lagos_sample==1  & in_balanced_panel==1 & _merge==3, absorb(identificad industry#year  microrregiao#year mode_base_month#year  ) vce(cluster identificad)

estimates store es_direct_dt

 // Create event study plot

 coefplot es_direct_dt, ///
    keep(1.treat_ultra#2009.year 1.treat_ultra#2010.year 1.treat_ultra#2011.year 1.treat_ultra#2012.year 1.treat_ultra#2013.year 1.treat_ultra#2014.year 1.treat_ultra#2015.year 1.treat_ultra#2016.year) ///
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
    title("Direct Effect on Log Employment, matched sample", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)

graph export "$graphs/es_l_emp_match.png", as(png) replace
	

// III.b. log avarage earnings:

reghdfe lr_remmedr treat_ultra##b(2011).year  if lagos_sample==1 & in_balanced_panel==1 & _merge==3, absorb(year identificad industry#year mode_base_month#year microrregiao#year) vce(cluster identificad)
estimates store es_direct

// Create event study plot
coefplot es_direct, ///
    keep(1.treat_ultra#2009.year 1.treat_ultra#2010.year 1.treat_ultra#2011.year 1.treat_ultra#2012.year 1.treat_ultra#2013.year 1.treat_ultra#2014.year 1.treat_ultra#2015.year 1.treat_ultra#2016.year) ///
    coeflabels(1.treat_ultra#2009.year = "2009" ///
              1.treat_ultra#2010.year = "2010" ///
              1.treat_ultra#2011.year = "2011" ///
              1.treat_ultra#2012.year = "2012" ///
              1.treat_ultra#2013.year = "2013" ///
              1.treat_ultra#2014.year = "2014" ///
              1.treat_ultra#2015.year = "2015" ///
              1.treat_ultra#2016.year = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-.02(.01).02) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Direct Effect on Log Average Wages", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
	
graph export "$graphs/es_l_remmedr_match.png", as(png) replace

// III.c. log december earnings:

reghdfe lr_remdezr treat_ultra##b(2011).year  if lagos_sample==1 & in_balanced_panel==1 & _merge==3, absorb(year identificad industry#year mode_base_month#year microrregiao#year) vce(cluster identificad)
estimates store es_direct

// Create event study plot
coefplot es_direct, ///
    keep(1.treat_ultra#2009.year 1.treat_ultra#2010.year 1.treat_ultra#2011.year 1.treat_ultra#2012.year 1.treat_ultra#2013.year 1.treat_ultra#2014.year 1.treat_ultra#2015.year 1.treat_ultra#2016.year) ///
    coeflabels(1.treat_ultra#2009.year = "2009" ///
              1.treat_ultra#2010.year = "2010" ///
              1.treat_ultra#2011.year = "2011" ///
              1.treat_ultra#2012.year = "2012" ///
              1.treat_ultra#2013.year = "2013" ///
              1.treat_ultra#2014.year = "2014" ///
              1.treat_ultra#2015.year = "2015" ///
              1.treat_ultra#2016.year = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-.02(.01).02) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Direct Effect on Log December Wages", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
	
graph export "$graphs/es_l_remdezr_match.png", as(png) replace	


// IV. Try to implement match DiD to match 	


* Step 1: Create pre-trend slope variables for each unit
preserve 
    * Keep only pre-treatment period
    keep if year <= 2011 & lagos_sample==1 & in_balanced_panel==1
    
    * Run unit-specific regressions to get pre-trend slopes for employment
    bys identificad: asreg l_firm_emp year
    
    * Store the trend coefficient (slope)
    gen emp_trend = _b_year
    
    * Store the number of observations used for trend estimation
    gen emp_nobs = _N
    
    * Clean up regression variables before next regression
    foreach var of varlist _* {
        if "`var'" != "_N" capture drop `var'
    }
    
    * Run regression for wages
    bys identificad: asreg lr_remmedr year
    
    * Store the wage trend coefficient
    gen wage_trend = _b_year
    
    * Keep only identification and computed trend values
    keep identificad emp_trend emp_nobs wage_trend
    
    tempfile trends
    save `trends'
restore

* Step 2: Merge pre-trend slopes back to main dataset
merge m:1 identificad using `trends', keep(master match) nogen

* Step 3: Get average levels for pre-treatment period
preserve
    keep if year <= 2011 & lagos_sample==1 & in_balanced_panel==1
    
    * Calculate pre-treatment averages for key variables
    collapse (mean) pre_emp=l_firm_emp pre_wage=lr_remmedr, by(identificad)
    
    tempfile prelevels
    save `prelevels'
restore

* Step 4: Merge pre-treatment averages back to main dataset
merge m:1 identificad using `prelevels', keep(master match) nogen

* Step 5: Keep only one observation per establishment for matching
preserve
    keep if year == 2011 & lagos_sample==1 & in_balanced_panel==1
    
    * Only include units with enough observations for reliable trend estimation
    keep if emp_nobs >= 3
    
    * Run propensity score matching based on pre-trends and initial levels
    psmatch2 treat_ultra emp_trend wage_trend pre_emp pre_wage ///
            i.industry i.microrregiao i.mode_base_month, ///
            outcome(l_firm_emp) caliper(0.25) neighbor(1) common noreplacement
    
    * Create strata identifier that groups matched pairs
    gen strata = _n1 if treat_ultra==1
    replace strata = _id if treat_ultra==0
    
    * Verify matching quality
    gen is_matched = 1 if (_weight != . & treat_ultra==0) | (_n1 != . & treat_ultra==1)
    tab treat_ultra is_matched, missing
    
    * Keep only matched units
    keep if is_matched==1
    
    * Retain only necessary identifiers
    keep identificad strata
    
    tempfile matched_sample
    save `matched_sample'
restore

* Step 6: Apply matched sample to panel data
merge m:1 identificad using `matched_sample', keep(match) nogen

* Step 7: Run DiD on matched sample
reghdfe l_firm_emp i.treat_ultra##ib(2011).year, ///
        absorb(identificad industry#year microrregiao#year mode_base_month#year) ///
        vce(cluster identificad)

* Step 8: Create event study plot to verify parallel trends
coefplot, keep(1.treat_ultra#*.year) ///
    coeflabels(1.treat_ultra#2009.year = "2009" ///
              1.treat_ultra#2010.year = "2010" ///
              1.treat_ultra#2011.year = "2011" ///
              1.treat_ultra#2012.year = "2012" ///
              1.treat_ultra#2013.year = "2013" ///
              1.treat_ultra#2014.year = "2014" ///
              1.treat_ultra#2015.year = "2015" ///
              1.treat_ultra#2016.year = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
    ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Effect on Log-Employment (Matched on Pre-Trends)", size(medium)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)

graph export "graphs/event_study_emp_pretrend_matched.png", replace
	
// Try to estimate DiD effects for most outcomes to compare:

gen post_treat =  cond(year>=2012,1,0)
	

reghdfe l_firm_emp i.treat_ultra##i.post_treat if lagos_sample==1  , absorb(identificad year   ) vce(cluster identificad)
	
	
	preserve
	keep if lagos_sample==1 & in_balanced_panel==1
	isid identificad year, missok
	restore
	
	
	
// Trying to implement something similar to BAssier(2023)

/
	
	
//	INCORPORATING TIME TRENDS INSTEAD OF FIXED EFFECTS

gen time= year-2009

reghdfe l_firm_emp i.treat_ultra##ib(2011).year ///
        c.time#i.industry c.time#i.microrregiao c.time#i.mode_base_month ///
        if lagos_sample==1 & in_balanced_panel==1, ///
        absorb(identificad year) ///
        vce(cluster identificad)
	
	estimates store es_direct_dt

 // Create event study plot
// Create event study plot
coefplot es_direct_dt, vertical ///
    keep(1.treat_ultra#*.year) ///
    coeflabels(1.treat_ultra#2009.year = "2009" ///
              1.treat_ultra#2010.year= "2010" ///
              1.treat_ultra#2012.year= "2012" ///
              1.treat_ultra#2013.year= "2013" ///
              1.treat_ultra#2014.year= "2014" ///
              1.treat_ultra#2015.year= "2015" ///
              1.treat_ultra#2016.year= "2016" ) ///
    yline(0) xline(3, lpattern(dash)) ///
//     xtitle("Years Relative to Union Bargaining Power Increase (2012)") ///
//     title("Event Study: Dir. Effects of Ultra on `outcome'") ///
    note("Reference year: 2011") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(navy*.6))
	
	
	

	
