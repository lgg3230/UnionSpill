********************************************************************************
* REPLICATION OF CBA OUTCOMES FROM LAGOS (2024)
* OUTPUT: EVENT STUDIES FOR CBA-RELATED OUTCOMES
********************************************************************************

// use "$rais_firm/cba_rais_firm_2009_2016.dta",clear 



********************************************************************************
********************************************************************************
**# Bookmark #2
// DEFINITION OF THE CBA ANALYSIS PERIOD:
********************************************************************************
********************************************************************************


* Keep only establishments in the Lagos sample (satisfy all restrictions)
keep if lagos_sample == 1 & in_balanced_panel==1

* First identify the 2009 CBAs (initial agreements)
* Use file dates to classify when coverage begins
* generates dummy indicating if cba start date is between january and december 2009 	
// gen cba_2009 = inrange(file_date_stata, mdy(1,1,2009), mdy(12,31,2009))

* We need to identify the first renewal of the 2009 CBA for each establishment
* Sort by establishment ID and start date
// sort identificad file_date_stata


// The bit commented below needed to be done for the lagos_sample

// * Generate a sequence number within each establishment
// by identificad: gen seq_num = _n
// by identificad: gen earliest_2009 = start_date_stata if cba_2009==1 & seq_num==1
// format earliest_2009 %td 
// by identificad: egen first_cba_2009_date = min(earliest_2009)
// format first_cba_2009_date %td 
// drop earliest_2009



* Identify the first CBA that starts after the 2009 CBA but before September 2012
* This will be the renewal of the 2009 CBA
// by identificad: gen renewal_date = file_date_stata if ///
//     file_date_stata > earliest_2009 & ///
//     file_date_stata < mdy(9,1,2012) & ///
//     !missing(earliest_2009)
//     format renewal_date %td
    
* Get the earliest renewal for each establishment
// by identificad: egen first_renewal_date = min(renewal_date)
// format first_renewal_date %td
// drop renewal_date

* Mark the CBA periods
gen cba_period = .
replace cba_period = 1 if file_date_stata==earliest2009-1 & !missing(file_date_stata) /* First 2009 CBA */
replace cba_period = 2 if file_date_stata==second_cba & !missing(file_date_stata) /* First renewal */
replace cba_period = 3 if inrange(file_date_stata, mdy(1,1,2013), mdy(12,31,2013)) & cba_period==. /* 2013 CBA */
replace cba_period = 4 if inrange(file_date_stata, mdy(1,1,2014), mdy(12,31,2014)) & cba_period==. /* 2014 CBA */
replace cba_period = 5 if inrange(file_date_stata, mdy(1,1,2015), mdy(12,31,2015)) & cba_period==. /* 2015 CBA */
replace cba_period = 6 if inrange(file_date_stata, mdy(1,1,2016), mdy(12,31,2016)) & cba_period==. /* 2016 CBA */

gen post_treat_cba = cond(cba_period>2,1,0) if !missing(cba_period)

* Keep only observations with valid CBA periods
// keep if cba_period != .

********************************************************************************
********************************************************************************



**# Bookmark #1

// preserve

//  keep if identificad_8!="00360305"



reghdfe numb_clauses i.treat_ultra##ib(2).cba_period if lagos_sample==1 & in_balanced_panel==1 ,  absorb(identificad cba_period industry1#cba_period microregion#cba_period mode_base_month#cba_period)vce(cluster identificad)

estimates store es_clauses


* Generate event study plot for total clauses
coefplot es_clauses, ///
  msymbol(square) ///
  keep(1.treat_ultra#*.cba_period) ///
  coeflabels(1.treat_ultra#1.cba_period = "2009" ///
            1.treat_ultra#2.cba_period = "2010-2012" ///
            1.treat_ultra#3.cba_period = "2013" ///
            1.treat_ultra#4.cba_period = "2014" ///
            1.treat_ultra#5.cba_period = "2015" ///
            1.treat_ultra#6.cba_period = "2016") ///
  vert omitted baselevels yline(0) xline(2.5, lpattern(dash)) ///
  ytitle("Dynamic DiD coefficients", size(small)) ///
  title("Number of clauses", size(medium large)) ///
  graphregion(color(white)) bgcolor(white) ///
  ci(95) ciopts(recast(rcap) color(lime)) mcolor(lime)
graph export "$graphs/es_numb_clauses.png", as(png) replace

// restore
  
// Graph:


**# Bookmark #1
reghdfe numb_clauses i.treat_ultra##ib(2011).year if lagos_sample==1 & in_balanced_panel==1 ,  absorb(identificad  industry1#year  microregion#year mode_base_month#year )vce(cluster identificad)

estimates store es_clauses_year


* Generate event study plot for total clauses
coefplot es_clauses_year, ///
  keep(1.treat_ultra#2009.year 1.treat_ultra#2010.year 1.treat_ultra#2011.year 1.treat_ultra#2012.year 1.treat_ultra#2013.year 1.treat_ultra#2014.year 1.treat_ultra#2015.year 1.treat_ultra#2016.year) ///
  coeflabels(1.treat_ultra#2009.year = "2009" ///
            1.treat_ultra#2010.year = "2010" ///
            1.treat_ultra#2011.year = "2011" ///
            1.treat_ultra#2012.year = "2012" ///
            1.treat_ultra#2013.year = "2013" ///
            1.treat_ultra#2014.year = "2014" ///
	    1.treat_ultra#2015.year = "2015" ///
	    1.treat_ultra#2016.year = "2016" ///
	    ) ///
  vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
  ytitle("Dynamic DiD coefficients", size(small)) ///
  title("Number of clauses", size(medium large)) ///
  graphregion(color(white)) bgcolor(white) ///
  ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
graph export "$graphs/es_numb_clauses_year.png", as(png) replace

preserve

//  keep if identificad_8!="00360305"

destring identificad, replace force

collapse (mean) numb_clauses (count) n_firms=identificad, by(treat_ultra cba_period)

// Create the line graph
    twoway (connected numb_clauses cba_period if treat_ultra==1, lcolor(sand) lwidth(medthick) ///
             mcolor(sand) msymbol(O) msize(medium)) ///
           (connected numb_clauses cba_period if treat_ultra==0, lcolor(navy) lwidth(medthick) ///
             mcolor(navy) msymbol(D) msize(medium)), ///
           xline(2, lpattern(dash) lcolor(gray)) ///
           xlabel(1(1)6, labsize(medium)) ///
           ylabel(10(5)50, angle(horizontal)) ///
           ytitle("clause count")  ///
		   xtitle("") ///
           legend(order(1 "Treated" 2 "Control") pos(6) row(1) region(lstyle(none))) ///
           title("Evolution of Number of Clauses", size(medium large)) ///
           note("Vertical line indicates introduction of ultractivity (September 2012)") ///
		   graphregion(margin(medium) color(white))
graph export "$graphs/numb_clauses_cba_period.png", as(png) replace


restore

preserve
// keep if in_balanced_panel==1

// keep if identificad_8!="00360305"

destring identificad, replace force

collapse (mean) numb_clauses (count) n_firms=identificad, by(treat_ultra year)

// Create the line graph
    twoway (connected numb_clauses year if treat_ultra==1, lcolor(sand) lwidth(medthick) ///
             mcolor(sand) msymbol(O) msize(medium)) ///
           (connected numb_clauses year if treat_ultra==0, lcolor(navy) lwidth(medthick) ///
             mcolor(navy) msymbol(D) msize(medium)), ///
           xline(2012.8, lpattern(dash) lcolor(gray)) ///
           xlabel(2009(1)2016, labsize(medium)) ///
           ylabel(10(5)50, angle(horizontal)) ///
           ytitle("clause count")  ///
		   xtitle("") ///
           legend(order(1 "Treated" 2 "Control") pos(6) row(1) region(lstyle(none))) ///
           title("Evolution of Number of Clauses", size(medium large)) ///
           note("Vertical line indicates introduction of ultractivity (September 2012)") ///
		   graphregion(margin(medium) color(white))
graph export "$graphs/numb_clauses_year.png", as(png) replace

restore

preserve


destring identificad, replace force

collapse (mean) numb_clauses (count) n_firms=identificad, by(treat_ultra active_year)

// Create the line graph
    twoway (connected numb_clauses active_year if treat_ultra==1, lcolor(sand) lwidth(medthick) ///
             mcolor(sand) msymbol(O) msize(medium)) ///
           (connected numb_clauses active_year if treat_ultra==0, lcolor(navy) lwidth(medthick) ///
             mcolor(navy) msymbol(D) msize(medium)), ///
           xline(2012.8, lpattern(dash) lcolor(gray)) ///
           xlabel(2009(1)2016, labsize(medium)) ///
           ylabel(10(5)50, angle(horizontal)) ///
           ytitle("clause count")  ///
		   xtitle("") ///
           legend(order(1 "Treated" 2 "Control") pos(6) row(1) region(lstyle(none))) ///
           title("Evolution of Number of Clauses", size(medium large)) ///
           note("Vertical line indicates introduction of ultractivity (September 2012)") ///
		   graphregion(margin(medium) color(white))


restore









