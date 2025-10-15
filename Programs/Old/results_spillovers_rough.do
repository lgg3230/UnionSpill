********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: SPILLOVER EFFECTS ESTIMATES ON WAGES/EMPLOYMENT, WITH CONNECTIVITY MEASURED AS FLOW COUNTS (ROUGH MEASURE)
* INPUT: MERGED CBA RAIS, WITH CONNECTIVITY MEASURES
* OUTPUT:TWFE ESTIMATES FOR ROUGHT SPILLOVER EFFECTS 
********************************************************************************

use "$rais_firm/cba_rais_firm_2009_2016.dta",clear 

// keep high_treat lr_remdezr lr_remmedr l_firm_emp year microregion industry1 mode_union identificad mode_base_month high_t_top10 in_balanced_panel top10_linklagos

////////////////////////////////////////////////////////////////////////////////
**# Bookmark #1
// a. Comparing below and above median connectivity with treatment within top 10% connectivity with Lagos Sample, EXCLUDING THOSE BELONGING TO LAGOS SAMPLE:


// a.1 December wages:
reghdfe lr_remdezr high_treat##b(2011).year  if x==1, absorb(year identificad  industry1#year mode_base_month#year microregion#year mode_union#year) vce(cluster identificad)
estimates store es_spillover_remdezr

// Create event study plot
coefplot es_spillover_remdezr, ///
    keep(1.high_treat#2009.year 1.high_treat#2010.year 1.high_treat#2011.year 1.high_treat#2012.year 1.high_treat#2013.year 1.high_treat#2014.year 1.high_treat#2015.year 1.high_treat#2016.year) ///
    coeflabels(1.high_treat#2009.year = "2009" ///
              1.high_treat#2010.year = "2010" ///
              1.high_treat#2011.year = "2011" ///
              1.high_treat#2012.year = "2012" ///
              1.high_treat#2013.year = "2013" ///
              1.high_treat#2014.year = "2014" ///
              1.high_treat#2015.year = "2015" ///
              1.high_treat#2016.year = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-.06(.02).08) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Log December Wages", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
    

// a.2 Employment:
reghdfe l_firm_emp high_treat##b(2011).year  if x==1, absorb(year identificad  ) vce(cluster identificad)
estimates store es_spillover_emp

// Create event study plot
coefplot es_spillover_emp, ///
    keep(1.high_treat#2009.year 1.high_treat#2010.year 1.high_treat#2011.year 1.high_treat#2012.year 1.high_treat#2013.year 1.high_treat#2014.year 1.high_treat#2015.year 1.high_treat#2016.year) ///
    coeflabels(1.high_treat#2009.year = "2009" ///
              1.high_treat#2010.year = "2010" ///
              1.high_treat#2011.year = "2011" ///
              1.high_treat#2012.year = "2012" ///
              1.high_treat#2013.year = "2013" ///
              1.high_treat#2014.year = "2014" ///
              1.high_treat#2015.year = "2015" ///
              1.high_treat#2016.year = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-.06(.02).08) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Log Employment", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)    
    

    
// a.3 Average wages:    
    reghdfe lr_remmedr high_treat##b(2011).year  if x==1, absorb(year identificad  mode_base_month#year ) vce(cluster identificad)
estimates store es_spillover_remmedr

// Create event study plot
coefplot es_spillover_remmedr, ///
    keep(1.high_treat#2009.year 1.high_treat#2010.year 1.high_treat#2011.year 1.high_treat#2012.year 1.high_treat#2013.year 1.high_treat#2014.year 1.high_treat#2015.year 1.high_treat#2016.year) ///
    coeflabels(1.high_treat#2009.year = "2009" ///
              1.high_treat#2010.year = "2010" ///
              1.high_treat#2011.year = "2011" ///
              1.high_treat#2012.year = "2012" ///
              1.high_treat#2013.year = "2013" ///
              1.high_treat#2014.year = "2014" ///
              1.high_treat#2015.year = "2015" ///
              1.high_treat#2016.year = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-.06(.02).08) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Direct Effect on Log Average Wages", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)

    
////////////////////////////////////////////////////////////////////////////////
**# Bookmark #2
// b.  Comparing below and above median connectivity with treatment within top 10% connectivity with Lagos Sample,INCLUDING LAGOS SAMPLE (TREAT AND CONTROL) 


// b.1 December wages:
reghdfe lr_remdezr high_t_top10##b(2011).year treat_ultra##b(2011).year if top10_linklagos==1 & in_balanced_panel==1, absorb(year identificad ) vce(cluster identificad)
estimates store es_spillover_remdezr

// Create event study plot
coefplot es_spillover_remdezr, ///
    keep(1.high_t_top10#2009.year 1.high_t_top10#2010.year 1.high_t_top10#2011.year 1.high_t_top10#2012.year 1.high_t_top10#2013.year 1.high_t_top10#2014.year 1.high_t_top10#2015.year 1.high_t_top10#2016.year) ///
    coeflabels(1.high_t_top10#2009.year = "2009" ///
              1.high_t_top10#2010.year = "2010" ///
              1.high_t_top10#2011.year = "2011" ///
              1.high_t_top10#2012.year = "2012" ///
              1.high_t_top10#2013.year = "2013" ///
              1.high_t_top10#2014.year = "2014" ///
              1.high_t_top10#2015.year = "2015" ///
              1.high_t_top10#2016.year = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-.06(.02).08) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Log December Wages", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
    

// b.2 Employment:
reghdfe l_firm_emp high_t_top10##b(2011).year treat_ultra##b(2011).year  if top10_linklagos==1 & in_balanced_panel==1, absorb(year identificad industry1#year mode_base_month#year microregion#year mode_union#year) vce(cluster identificad)
estimates store es_spillover_emp

// Create event study plot
coefplot es_spillover_emp, ///
    keep(1.high_t_top10#2009.year 1.high_t_top10#2010.year 1.high_t_top10#2011.year 1.high_t_top10#2012.year 1.high_t_top10#2013.year 1.high_t_top10#2014.year 1.high_t_top10#2015.year 1.high_t_top10#2016.year) ///
    coeflabels(1.high_t_top10#2009.year = "2009" ///
              1.high_t_top10#2010.year = "2010" ///
              1.high_t_top10#2011.year = "2011" ///
              1.high_t_top10#2012.year = "2012" ///
              1.high_t_top10#2013.year = "2013" ///
              1.high_t_top10#2014.year = "2014" ///
              1.high_t_top10#2015.year = "2015" ///
              1.high_t_top10#2016.year = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-.06(.02).08) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Log Employment", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)    
    

    
// b.3 Average wages:    
    reghdfe lr_remmedr high_t_top10##b(2011).year treat_ultra##b(2011).year  if top10_linklagos==1 & in_balanced_panel==1 , absorb(year identificad industry1#year mode_base_month#year microregion#year) vce(cluster identificad)
estimates store es_spillover_remmedr

// Create event study plot
coefplot es_spillover_remmedr, ///
    keep(1.high_t_top10#2009.year 1.high_t_top10#2010.year 1.high_t_top10#2011.year 1.high_t_top10#2012.year 1.high_t_top10#2013.year 1.high_t_top10#2014.year 1.high_t_top10#2015.year 1.high_t_top10#2016.year) ///
    coeflabels(1.high_t_top10#2009.year = "2009" ///
              1.high_t_top10#2010.year = "2010" ///
              1.high_t_top10#2011.year = "2011" ///
              1.high_t_top10#2012.year = "2012" ///
              1.high_t_top10#2013.year = "2013" ///
              1.high_t_top10#2014.year = "2014" ///
              1.high_t_top10#2015.year = "2015" ///
              1.high_t_top10#2016.year = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-.06(.02).08) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Direct Effect on Log Average Wages", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
    
    
////////////////////////////////////////////////////////////////////////////////    
// Effects in Clauses



    
    
    
