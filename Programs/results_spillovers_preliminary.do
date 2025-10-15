********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR:  LUIS GOMES
* PROGRAM: PRELIMINARY SPILLOVER RESULTS, TO TEST FOR DIFFERENT SPECIFICATIONS
* INPUT:   MERGED CBA RAIS, WITH CONNECTIVITY MEASURES
* OUTPUT:  TABLES FOR EMPLOYMENT FOR DYNAMIC DID COEFFICIENTS FOR DIFFERENT 
* 	   SAMPLES AND SPECIFICATIONS	 
********************************************************************************

use "$rais_firm/labor_analysis_sample.dta",clear 

*-------------------------------------------------------------------------------
* 1) Define the dimensions of your samples:
*    t = treat_ultra (0/1)
*    l = lagos_sample_avg (0/1)
*    c = connectivity positive? (0/1)
*    type = pf   (flows-count) 
*           pw   (per-worker flows)
*-------------------------------------------------------------------------------
local treats 0 1
local lagos  0 1
local types  pf pw



foreach t of local treats {
  foreach l of local lagos {
    * sample_tl : treat_ultra==t & in_balanced_panel==1 & lagos_sample_avg==l
     quietly gen sample_`t'`l' = 0
    foreach type of local types {
      * positive connectivity
      quietly gen sample_`t'`l'_1_t`type' = 0
      * zero connectivity
      quietly gen sample_`t'`l'_0_t`type' = 0
    }
  }
}

*-------------------------------------------------------------------------------
* 4) Loop to create:
*     • sample_tl   : full sample (just t & l)
*     • sample_tl_1_tType : those with connectivity > 0  
*     • sample_tl_0_tType : those with connectivity == 0
*-------------------------------------------------------------------------------
local treats 0 1
local lagos  0 1
local types  pf pw



foreach t of local treats {
	if `t'==0{
  foreach l of local lagos {
  	if `l'==0{
    * sample_tl : treat_ultra==t & in_balanced_panel==1 & lagos_sample_avg==l
     quietly replace sample_`t'`l' = (treat_ultra==`t' & ///
                                     in_balanced_panel==1  & ///
                                     lagos_sample_avg   ==`l')
    foreach type of local types {
      * positive connectivity
      quietly replace sample_`t'`l'_1_t`type' = ///
          (treat_ultra   ==`t' & ///
           in_balanced_panel==1 & ///
           lagos_sample_avg   ==`l' & ///
           totaltreat_`type' > 0)
      * zero connectivity
      quietly replace sample_`t'`l'_0_t`type' = ///
          (treat_ultra   ==`t' & ///
           in_balanced_panel==1 & ///
           lagos_sample_avg   ==`l' & ///
           totaltreat_`type' == 0)
    }
    }
    if `l'==1{
    	 *sample_tl : treat_ultra==t & in_balanced_panel==1 & lagos_sample_avg==l
     quietly replace sample_`t'`l' = (treat_ultra==`t' & ///
                                     in_balanced_panel==1 )
    foreach type of local types {
      * positive connectivity
      quietly replace sample_`t'`l'_1_t`type' = ///
          (treat_ultra   ==`t' & ///
           in_balanced_panel==1 & ///
           totaltreat_`type' > 0)
      * zero connectivity
      quietly replace sample_`t'`l'_0_t`type' = ///
          (treat_ultra   ==`t' & ///
           in_balanced_panel==1 & ///
           totaltreat_`type' == 0)
    }
  }
  }
	}
  if `t'==1 {
  foreach l of local lagos {
  	if `l'==0{
    * sample_tl : treat_ultra==t & in_balanced_panel==1 & lagos_sample_avg==l
     quietly replace sample_`t'`l' = (in_balanced_panel==1  & ///
                                     lagos_sample_avg   ==`l')
    foreach type of local types {
      * positive connectivity
      quietly replace sample_`t'`l'_1_t`type' = ///
          (in_balanced_panel==1 & ///
           lagos_sample_avg   ==`l' & ///
           totaltreat_`type' > 0)
      * zero connectivity
      quietly replace sample_`t'`l'_0_t`type' = ///
          (in_balanced_panel==1 & ///
           lagos_sample_avg   ==`l' & ///
           totaltreat_`type' == 0)
    }
	}
	if `l'==1{
	* sample_tl : treat_ultra==t & in_balanced_panel==1 & lagos_sample_avg==l
     quietly replace sample_`t'`l' = (in_balanced_panel==1 )
    foreach type of local types {
      * positive connectivity
      quietly replace sample_`t'`l'_1_t`type' = ///
          (in_balanced_panel==1 & ///
           totaltreat_`type' > 0)
      * zero connectivity
      quietly replace sample_`t'`l'_0_t`type' = ///
          (in_balanced_panel==1 & ///
           totaltreat_`type' == 0)
    }	
	}
  }	
  }
}

// Some sanity checks: see if samples with treated are larger than without treated:


local treats 0 1
local lagos  0 1
local types  pf pw

foreach t of local treats {
  foreach l of local lagos {
    * sample_tl : treat_ultra==t & in_balanced_panel==1 & lagos_sample_avg==l
     di "sample_`t'`l':"
     count if sample_`t'`l' == 1
     
    foreach type of local types {
      * positive connectivity
      di "sample_`t'`l'_1_t`type':"
      count if sample_`t'`l'_1_t`type' ==1
      * zero connectivity
      di "sample_`t'`l'_0_t`type':"
      count if sample_`t'`l'_0_t`type' ==1
    }
  }
}

* NOTE: "samps" is the list of suffixes; "mlabels" is the title you'll put under each column
local samps_pf_nt 00 /// lagos_sample_avg==0 & treat_ultra==0 
		  00_0_tpf /// + totaltreat_pf==0
		  00_1_tpf /// + totaltreat_pf>0
		  10 /// lagos_sample_avg==1 & treat_ultra==0
		  10_0_tpf ///
		  10_1_tpf ///
		
local samps_pf_yt 01 /// lagos_sample_avg==0 & treat_ultra==1 
		  01_0_tpf ///
		  01_1_tpf ///
		  11 /// lagos_sample_avg==1 & treat_ultra==1
		  11_0_tpf ///
		  11_1_tpf ///
		

local samps_pw_nt 00 /// lagos_sample_avg==0 & treat_ultra==0 
		  00_0_tpw /// + totaltreat_pw==0
		  00_1_tpw /// + totaltreat_pw>0
		  10 /// lagos_sample_avg==1 & treat_ultra==0
		  10_0_tpw ///
		  10_1_tpw ///
		   
local samps_pw_yt 01 /// lagos_sample_avg==0 & treat_ultra==1 
		  01_0_tpw ///
		  01_1_tpw ///
		  11 /// lagos_sample_avg==1 & treat_ultra==1
		  11_0_tpw ///
		  11_1_tpw ///

// 		
//------------------------------------------------------------------------------
// 2) Define Fixed Effect groups:
//------------------------------------------------------------------------------

**# Bookmark #1

local All  "identificad year industry1#year mode_base_month#year microregion#year"
local IndustryY  "identificad year industry1#year"
local BaseMonthY  "identificad year mode_base_month#year"
local MicroregionY  "identificad year microregion#year"
local OnlyIDY  "identificad year"




// local fes All IndustryY BaseMonthY MicroregionY OnlyIDY
// local fedesc  "All FE" "Industry × Year" "Month × Year" "Micro × Year" "ID & Year"


//------------------------------------------------------------------------------
// 3) Define outcome group:
//------------------------------------------------------------------------------

local outcomes "lr_remdezr lr_remmedr l_firm_emp"		
		
		
//------------------------------------------------------------------------------
// 5) Run regression loop
//------------------------------------------------------------------------------


// RESULTS WITHOUT UNITS DIRECTLY AFFECTED BY ULTRACTIVITY

// Results with flows to treat / total flows as connectivity measure
eststo clear

foreach outcome of local outcomes {

  foreach s of local samps_pf_nt {
 	
    local label = "`s'_`outcome'"  
    eststo : quietly reghdfe   /// your regression
     `outcome'     /// (example outcome)
        c.totaltreat_pf##b(2011).year  if sample_`s'==1 ,  ///
        absorb(`All')   /// FE spec name
        vce(cluster identificad)
	di " just ran `s' × `outcome'"  
   
  }
}

	

esttab using "$tables/spillover_results_pf_nt_25.csv" , ///
    keep(*#*c.totaltreat_pf)    /// only the interaction terms
    se                          /// show standard errors
    star(* 0.10 ** 0.05 *** 0.01) ///
    /// these two lines format the coefficients and SEs nicely:
    b(3) se(3)                  ///
    replace //     using "spillover_results.csv"/// output to CSV that Excel can read
    
    

// Results with Avg flows to treat / firm_emp as connectivity measure    
eststo clear

foreach outcome of local outcomes {

  foreach s of local samps_pw_nt {
 	
    local label = "`s'_`outcome'"  
    eststo : quietly reghdfe   /// your regression
     `outcome'     /// (example outcome)
        c.totaltreat_pw##b(2011).year  if sample_`s'==1 ,  ///
        absorb(`All')   /// FE spec name
        vce(cluster identificad)
	di " just ran `s' × `outcome'"  
   
  }
}

	

esttab using "$tables/spillover_results_pw_nt_25.csv" , ///
    keep(*#*c.totaltreat_pw)    /// only the interaction terms
    se                          /// show standard errors
    star(* 0.10 ** 0.05 *** 0.01) ///
    /// these two lines format the coefficients and SEs nicely:
    b(3) se(3)                  ///
    replace //     using "spillover_results.csv"/// output to CSV that Excel can read
    
    
// RESTULS !!!!WITH!!!! UNITS AFFECTED BY ULTRACTIVITY

// Results with flows to treat / total flows as connectivity measure
eststo clear

foreach outcome of local outcomes {

  foreach s of local samps_pf_yt {
 	
    local label = "`s'_`outcome'"  
    eststo : quietly reghdfe   /// your regression
     `outcome'     /// (example outcome)
        c.totaltreat_pf##b(2011).year treat_ultra##b(2011).year if sample_`s'==1 ,  ///
        absorb(`All')   /// FE spec name
        vce(cluster identificad)
	di " just ran `s' × `outcome'"  
   
  }
}

	

esttab using "$tables/spillover_results_pf_yt_25.csv" , ///
    keep(*#*c.totaltreat_pf)    /// only the interaction terms
    se                          /// show standard errors
    star(* 0.10 ** 0.05 *** 0.01) ///
    /// these two lines format the coefficients and SEs nicely:
    b(3) se(3)                  ///
    replace //     using "spillover_results.csv"/// output to CSV that Excel can read
    
    

// Results with Avg flows to treat / firm_emp as connectivity measure    
eststo clear

foreach outcome of local outcomes {

  foreach s of local samps_pw_yt {
 	
    local label = "`s'_`outcome'"  
    eststo : quietly reghdfe   /// your regression
     `outcome'     /// (example outcome)
        c.totaltreat_pw##b(2011).year treat_ultra##b(2011).year if sample_`s'==1 ,  ///
        absorb(`All')   /// FE spec name
        vce(cluster identificad)
	di " just ran `s' × `outcome'"  
   
  }
}

	

esttab using "$tables/spillover_results_pw_yt_25.csv" , ///
    keep(*#*c.totaltreat_pw)    /// only the interaction terms
    se                          /// show standard errors
    star(* 0.10 ** 0.05 *** 0.01) ///
    /// these two lines format the coefficients and SEs nicely:
    b(3) se(3)                  ///
    replace //     using "spillover_results.csv"/// output to CSV that Excel can read

 
////////////////////////////////////////////////////////////////////////////////    
* Test additional speficiations: Testing both effect oif controlling for lagos sample and robustness of different fixed effects 

local outcomes "lr_remdezr lr_remmedr l_firm_emp"

local fe_groups  `""identificad year industry1#year mode_base_month#year microregion#year"  "identificad year industry1#year" "identificad year mode_base_month#year" "identificad year microregion#year" "identificad year""' 



// foreach a of local fe_groups {
// 	di "`a'"
// }

eststo clear		
foreach outcome of local outcomes{
foreach fe_group of local fe_groups{	
	eststo: qui reghdfe ///
	`outcome' /// 
	c.totaltreat_pf##b(2011).year if sample_00==1, ///
	absorb(`fe_group') ///
	vce(cluster identificad)
	di "just ran `fe_group'"
	
	eststo: qui reghdfe ///
	`outcome' /// 
	c.totaltreat_pf##b(2011).year c.totallagos_pf##b(2011).year if sample_00==1, ///
	absorb(`fe_group') ///
	vce(cluster identificad)
	di "just ran `fe_group' and totallagos_pf"
}	
}
		
		
esttab using "$tables/spillover_fes_lagosflows_25.csv" , ///
    keep(*#*c.totaltreat_pf)    /// only the interaction terms
    se                          /// show standard errors
    star(* 0.10 ** 0.05 *** 0.01) ///
    /// these two lines format the coefficients and SEs nicely:
    b(3) se(3)                  ///
    replace //  

////////////////////////////////////////////////////////////////////////////////
// Exploring control by flows to lagos sample further:


local outcomes "lr_remdezr lr_remmedr l_firm_emp"
eststo clear

foreach outcome of local outcomes{
	eststo: qui reghdfe ///
	`outcome' /// 
	c.totaltreat_pf##b(2011).year c.totallagos_pf##b(2011).year if sample_00==1, ///
	absorb(identificad year industry1#year mode_base_month#year microregion#year) ///
	vce(cluster identificad)
	di "just ran `outocome'"
	
	
}    
    
    
esttab using "$tables/spillover_lagosflows_pf_25.csv" , ///
    keep(*#*c.totaltreat_pf *#*c.totallagos_pf)    /// only the interaction terms
    se                          /// show standard errors
    star(* 0.10 ** 0.05 *** 0.01) ///
    /// these two lines format the coefficients and SEs nicely:
    b(3) se(3)                  ///
    replace //   

eststo clear
local outcomes "lr_remdezr lr_remmedr l_firm_emp"
foreach outcome of local outcomes{
    eststo: qui reghdfe ///
	`outcome' /// 
	c.totaltreat_pw##b(2011).year c.totallagos_pw##b(2011).year if sample_00==1, ///
	absorb(identificad year industry1#year mode_base_month#year microregion#year) ///
	vce(cluster identificad)
	di "just ran `outocome'"
}

	
esttab using "$tables/spillover_lagosflows_pw_25.csv" , ///
    keep(*#*c.totaltreat_pw *#*c.totallagos_pw)    /// only the interaction terms
    se                          /// show standard errors
    star(* 0.10 ** 0.05 *** 0.01) ///
    /// these two lines format the coefficients and SEs nicely:
    b(3) se(3)                  ///
    replace //   
    
    
    
    
////////////////////////////////////////////////////////////////////////////////
// Results for number of clauses:


* Mark the CBA periods
gen cba_period_lg = .
replace cba_period_lg = 1 if file_date_stata==earliest_cba & !missing(file_date_stata) /* First 2009 CBA */
replace cba_period_lg = 2 if file_date_stata==second_cba_lg & !missing(file_date_stata) /* First renewal */
replace cba_period_lg = 3 if inrange(file_date_stata, mdy(1,1,2013), mdy(12,31,2013)) & cba_period_lg==. /* 2013 CBA */
replace cba_period_lg = 4 if inrange(file_date_stata, mdy(1,1,2014), mdy(12,31,2014)) & cba_period_lg==. /* 2014 CBA */
replace cba_period_lg = 5 if inrange(file_date_stata, mdy(1,1,2015), mdy(12,31,2015)) & cba_period_lg==. /* 2015 CBA */
replace cba_period_lg = 6 if inrange(file_date_stata, mdy(1,1,2016), mdy(12,31,2016)) & cba_period_lg==. /* 2016 CBA */

eststo clear
eststo: reghdfe /// simplest regression with per flow flows
	numb_clauses /// 
	c.totaltreat_pf##b(2).cba_period_lg if luis_sample==1, ///
	absorb(identificad cba_period_lg industry1#cba_period_lg mode_base_month#cba_period_lg microregion#cba_period_lg) ///
	vce(cluster identificad)
	


eststo: reghdfe /// simplest regression with per flow flows and controlling for flows with lagos sample
	numb_clauses /// 
	c.totaltreat_pf##b(2).cba_period_lg c.totallagos_pf##b(2).cba_period_lg if luis_sample==1, ///
	absorb(identificad cba_period_lg industry1#cba_period_lg mode_base_month#cba_period_lg microregion#cba_period_lg) ///
	vce(cluster identificad)
	


esttab using "$tables/spillover_numbclauses_pf_25.csv" , ///
    keep(*#*c.totaltreat_pf)    /// only the interaction terms
    se                          /// show standard errors
    star(* 0.10 ** 0.05 *** 0.01) ///
    /// these two lines format the coefficients and SEs nicely:
    b(3) se(3)                  ///
    replace //  
    
eststo clear	
eststo: reghdfe /// simplest regression with per workerflows
	numb_clauses /// 
	c.totaltreat_pw##b(2).cba_period_lg if luis_sample==1, ///
	absorb(identificad cba_period_lg industry1#cba_period_lg mode_base_month#cba_period_lg microregion#cba_period_lg) ///
	vce(cluster identificad)    
	
eststo: reghdfe /// simplest regression with per workerflows and flows with lagos samples
	numb_clauses /// 
	c.totaltreat_pw##b(2).cba_period_lg c.totallagos_pw##b(2).cba_period_lg if luis_sample==1, ///
	absorb(identificad cba_period_lg industry1#cba_period_lg mode_base_month#cba_period_lg microregion#cba_period_lg) ///
	vce(cluster identificad) 
	
esttab using "$tables/spillover_numbclauses_pw_25.csv" , ///
keep(*#*c.totaltreat_pw)    /// only the interaction terms
se                          /// show standard errors
star(* 0.10 ** 0.05 *** 0.01) ///
/// these two lines format the coefficients and SEs nicely:
b(3) se(3)                  ///
replace //  



// Graphs for Spillover Effects: no treated, no direct effects sample, per flows flow:

// Log Employment
reghdfe   /// your regression
     l_firm_emp    /// (example outcome)
        c.totaltreat_pf##b(2011).year  if sample_00==1 & in_balanced_panel==1,  ///
        absorb(identificad year industry1#year mode_base_month#year microregion#year)   /// FE spec name
        vce(cluster identificad)
estimates store es_spill_emp	
	
// Create event study plot
coefplot es_spill_emp, ///
    keep(*#*c.totaltreat_pf) ///
    coeflabels(2009.year#c.totaltreat_pf = "2009" ///
               2010.year#c.totaltreat_pf = "2010" ///
               2011.year#c.totaltreat_pf = "2011" ///
               2012.year#c.totaltreat_pf = "2012" ///
               2013.year#c.totaltreat_pf = "2013" ///
               2014.year#c.totaltreat_pf = "2014" ///
               2015.year#c.totaltreat_pf = "2015" ///
               2016.year#c.totaltreat_pf = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-.1(.02).1) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Log Employment", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(orange)) mcolor(orange)
	
graph export "$graphs/es_emp_spill.png", as(png) replace	


local conn totaltreat_pf_n
reghdfe   /// your regression
     lr_remdezr    /// (example outcome)
        c.`conn'##b(2011).year  if  sample_01==1 & in_balanced_panel==1,  ///
        absorb(identificad year industry1#year  mode_base_month#year microregion#year)   /// FE spec name
        vce(cluster identificad)
estimates store es_spill_remdezr	

local conn totaltreat_pf_n	
// Create event study plot
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
	ylabel(-.1(.02).1) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Log December Earnings", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) ///
    text(-0.09 6 "C x Post Coef: -0.023", color(blue))

    
graph export "$graphs/es_remdezr_spill.png", as(png) replace


reghdfe   /// your regression
     lr_remdezr    /// (example outcome)
        c.totaltreat_pf_n##treat_year  if sample_01==1,  ///
        absorb(identificad year industry1#treat_year  mode_base_month#treat_year microregion#treat_year)   /// FE spec name
        vce(cluster identificad)
	
	
reghdfe   /// your regression
     lr_remdezr    /// (example outcome)
        c.totaltreat_pf_n##treat_year  if sample_01==1,  ///
        absorb(identificad year industry1#treat_year  mode_base_month#treat_year microregion#treat_year)   /// FE spec name
        vce(cluster identificad)	
	
	
//	descriptives of sample_00:

tab lagos_sample_avg if sample_00 & year==2009

eststo clear


eststo: qui reghdfe   /// your regression
     l_firm_emp    /// (example outcome)
        c.totaltreat_pf##treat_year  if sample_00==1 ,  ///
        absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year)   /// FE spec name
        vce(cluster identificad)
eststo: qui reghdfe   /// your regression
     lr_remdezr    /// (example outcome)
        c.totaltreat_pf##treat_year  if sample_00==1 ,  ///
        absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year)   /// FE spec name
        vce(cluster identificad)
eststo: qui reghdfe   /// your regression
     lr_remmedr    /// (example outcome)
        c.totaltreat_pf##treat_year  if sample_00==1 ,  ///
        absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year)   /// FE spec name
        vce(cluster identificad)

esttab using "$tables/spillover_did_pf.csv" , ///
   /// only the interaction terms
se                          /// show standard errors
star(* 0.10 ** 0.05 *** 0.01) ///
/// these two lines format the coefficients and SEs nicely:
b(3) se(3)                  ///
replace //  	


eststo clear


eststo: qui reghdfe   /// your regression
     l_firm_emp    /// (example outcome)
        c.totaltreat_pw##treat_year  if sample_00==1 ,  ///
        absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year)   /// FE spec name
        vce(cluster identificad)
eststo: qui reghdfe   /// your regression
     lr_remdezr    /// (example outcome)
        c.totaltreat_pw##treat_year  if sample_00==1 ,  ///
        absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year)   /// FE spec name
        vce(cluster identificad)
eststo: qui reghdfe   /// your regression
     lr_remmedr    /// (example outcome)
        c.totaltreat_pw##treat_year  if sample_00==1 ,  ///
        absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year)   /// FE spec name
        vce(cluster identificad)

esttab using "$tables/spillover_did_pw.csv" , ///
  /// only the interaction terms
se                          /// show standard errors
star(* 0.10 ** 0.05 *** 0.01) ///
/// these two lines format the coefficients and SEs nicely:
b(3) se(3)                  ///
replace //  	
	
eststo clear
eststo: qui reg lr_remdezr totaltreat_pf i.mode_base_month i.industry1 i.microregion if year==2011 & sample_00==1, rob
esttab, keep(totaltreat_pf)

eststo clear
eststo: qui reg l_firm_emp totaltreat_pf i.mode_base_month i.industry1 i.microregion if year==2011 & sample_00==1, rob
esttab, keep(totaltreat_pf)
	
	
// Charts for spillover effects, using untreated in and out of direct effects sample:

// Log Employment
reghdfe   /// your regression
     l_firm_emp    /// (example outcome)
        c.avg_flowone_pf##b(2011).year  if in_balanced_panel==1 & treat_ultra==0 ,  ///
        absorb(identificad year industry1#year mode_base_month#year microregion#year)   /// FE spec name
        vce(cluster identificad)
estimates store es_spill_emp_ut	

local conn avg_flowone_pf
// Create event study plot
coefplot es_spill_emp_ut, ///
    keep(*#*c.`conn') ///
    coeflabels(2009.year#c.`conn' = "2009" ///
               2010.year#c.`conn' = "2010" ///
               2011.year#c.`conn'= "2011" ///
               2012.year#c.`conn' = "2012" ///
               2013.year#c.`conn' = "2013" ///
               2014.year#c.`conn' = "2014" ///
               2015.year#c.`conn' = "2015" ///
               2016.year#c.`conn' = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-.1(.02).1) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Log Employment", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(orange)) mcolor(orange)
	
graph export "$graphs/es_emp_spill_lagosuntreated_one.png", as(png) replace	




local conn totalone_pf
reghdfe   /// your regression
     lr_remdezr    /// (example outcome)
        c.`conn'##b(2011).year  if in_balanced_panel==1 & treat_ultra==0,  ///
        absorb(identificad year industry1#year  mode_base_month#year microregion#year pub_firm#year mode_union#year avg_n_negs#year)   /// FE spec name
        vce(cluster identificad)
estimates store es_spill_remdezr_ut	


reghdfe   /// your regression
     lr_remdezr    /// (example outcome)
        c.totalone_pf##treat_year  if in_balanced_panel==1 & treat_ultra==0,  ///
        absorb(identificad year industry1#treat_year  mode_base_month#treat_year microregion#treat_year)   /// FE spec name
        vce(cluster identificad)

local conn totalone_pf	
// Create event study plot
coefplot es_spill_remdezr_ut, ///
    msymbol(diamond) ///
    keep(*#*c.`conn') ///
    coeflabels(2009.year#c.`conn' = "2009" ///
               2010.year#c.`conn' = "2010" ///
               2011.year#c.`conn'= "2011" ///
               2012.year#c.`conn' = "2012" ///
               2013.year#c.`conn' = "2013" ///
               2014.year#c.`conn' = "2014" ///
               2015.year#c.`conn' = "2015" ///
               2016.year#c.`conn' = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-.1(.02).1) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Log December Earnings", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) ///
    text(-0.09 6 "C x Post Coef: -0.05", color(blue))

    
graph export "$graphs/es_remdezr_spill_lagosuntreated_one.png", as(png) replace


// Charts for spillover effects, using untreated in and out of direct effects sample:

// Log Employment
reghdfe   /// your regression
     l_firm_emp    /// (example outcome)
        c.totaltreat_pf##b(2011).year  if sample_01==1 ,  ///
        absorb(identificad year industry1#year mode_base_month#year microregion#year)   /// FE spec name
        vce(cluster identificad)
estimates store es_spill_emp_ut	


reghdfe   /// your regression
     l_firm_emp    /// (example outcome)
        c.totaltreat_pf##treat_year  if sample_01==1,  ///
        absorb(identificad year industry1#treat_year  microregion#treat_year)   /// FE spec name
        vce(cluster identificad)
	
// Create event study plot
coefplot es_spill_emp_ut, ///
    keep(*#*c.totaltreat_pf) ///
    coeflabels(2009.year#c.totaltreat_pf = "2009" ///
               2010.year#c.totaltreat_pf = "2010" ///
               2011.year#c.totaltreat_pf = "2011" ///
               2012.year#c.totaltreat_pf = "2012" ///
               2013.year#c.totaltreat_pf = "2013" ///
               2014.year#c.totaltreat_pf = "2014" ///
               2015.year#c.totaltreat_pf = "2015" ///
               2016.year#c.totaltreat_pf = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-.1(.02).1) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Log Employment", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(orange)) mcolor(orange)
	
graph export "$graphs/es_emp_spill_lagosuntreated.png", as(png) replace	




local conn totaltreat_pf
reghdfe   /// your regression
     lr_remdezr    /// (example outcome)
        c.`conn'##b(2011).year  if sample_01==1,  ///
        absorb(identificad year industry1#year  mode_base_month#year microregion#year)   /// FE spec name
        vce(cluster identificad)
estimates store es_spill_remdezr_ut	


reghdfe   /// your regression
     lr_remdezr    /// (example outcome)
        c.totaltreat_pf##treat_year  if sample_01==1,  ///
        absorb(identificad year industry1#treat_year  mode_base_month#treat_year microregion#treat_year)   /// FE spec name
        vce(cluster identificad)

	
	
local conn totaltreat_pf	
// Create event study plot
coefplot es_spill_remdezr_ut, ///
    keep(*#*c.`conn') ///
    msymbol(diamond) ///
    coeflabels(2009.year#c.`conn' = "2009" ///
               2010.year#c.`conn' = "2010" ///
               2011.year#c.`conn'= "2011" ///
               2012.year#c.`conn' = "2012" ///
               2013.year#c.`conn' = "2013" ///
               2014.year#c.`conn' = "2014" ///
               2015.year#c.`conn' = "2015" ///
               2016.year#c.`conn' = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-.1(.02).1) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Log December Earnings", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) ///
    text(-0.09 6 "C x Post Coef: -0.019", color(blue))

    
graph export "$graphs/es_remdezr_spill_lagosuntreated.png", as(png) replace



// Including estabs with no cba (just exclude mode base month of the controls)



// Log Employment


reghdfe   /// your regression
     l_firm_emp   /// (example outcome)
        c.totaltreat_pw##treat_year  if in_balanced_panel==1 & treat_ultra==0,  ///
        absorb(identificad year industry1#treat_year  microregion#treat_year)   /// FE spec name
        vce(cluster identificad)
	
reghdfe   /// your regression
     l_firm_emp    /// (example outcome)
        c.totaltreat_pw##b(2011).year  if sample_01==1  ,  ///
        absorb(identificad year industry1#year  microregion#year)   /// FE spec name
        vce(cluster identificad)
estimates store es_spill_emp_ut	


	
// Create event study plot
coefplot es_spill_emp_ut, ///
    keep(*#*c.totaltreat_pw) ///
    coeflabels(2009.year#c.totaltreat_pw = "2009" ///
               2010.year#c.totaltreat_pw = "2010" ///
               2011.year#c.totaltreat_pw = "2011" ///
               2012.year#c.totaltreat_pw = "2012" ///
               2013.year#c.totaltreat_pw = "2013" ///
               2014.year#c.totaltreat_pw = "2014" ///
               2015.year#c.totaltreat_pw = "2015" ///
               2016.year#c.totaltreat_pw = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-.1(.02).1) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Log Employment", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(orange)) mcolor(orange) ///
    text(-0.09 6 "C x Post Coef: -0.015", color(orange))
	
graph export "$graphs/es_emp_spill_lagosuntreated_all.png", as(png) replace	



reghdfe   /// your regression
     lr_remdezr    /// (example outcome)
        c.totaltreat_pf##treat_year  if sample_01==1,  ///
        absorb(identificad year industry1#treat_year  microregion#treat_year)   /// FE spec name
        vce(cluster identificad)

// timer clear
// timer on 12
local conn totaltreat_pf
reghdfe   /// your regression
     lr_remdezr    /// (example outcome)
        c.`conn'##b(2011).year  if in_balanced_panel==1 & treat_ultra==0,  ///
        absorb(identificad year industry1#year  microregion#year)   /// FE spec name
        vce(cluster identificad) parallel(2)
estimates store es_spill_remdezr_ut	

// timer off 12
// timer list

local conn totaltreat_pf	
// Create event study plot
coefplot es_spill_remdezr_ut, ///
    keep(*#*c.`conn') ///
    msymbol(diamond) ///
    coeflabels(2009.year#c.`conn' = "2009" ///
               2010.year#c.`conn' = "2010" ///
               2011.year#c.`conn'= "2011" ///
               2012.year#c.`conn' = "2012" ///
               2013.year#c.`conn' = "2013" ///
               2014.year#c.`conn' = "2014" ///
               2015.year#c.`conn' = "2015" ///
               2016.year#c.`conn' = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-.02(.005).02) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Log December Earnings", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) ///
    text(-0.015 6 "C x Post Coef: -0.004", color(blue))

    
graph export "$graphs/es_remdezr_spill_lagosuntreated_all.png", as(png) replace

// Making restriction similar to Bassier(2022): only estabs with connectivity of more than 1% to treated firms


// Only establishments with at least one cba:

// Log Employment
reghdfe   /// your regression
     l_firm_emp    /// (example outcome)
        c.totaltreat_pf##b(2011).year  if sample_01==1 & high_totaltreat_pf==1,  ///
        absorb(identificad year industry1#year mode_base_month#year microregion#year)   /// FE spec name
        vce(cluster identificad)
estimates store es_spill_emp_ut_h

reghdfe   /// your regression
     l_firm_emp     /// (example outcome)
        c.totaltreat_pf##treat_year  if sample_01==1  & high_totaltreat_pf==1,  ///
        absorb(identificad year industry1#treat_year  mode_base_month#treat_year microregion#treat_year)   /// FE spec name
        vce(cluster identificad)	
	
// Create event study plot
coefplot es_spill_emp_ut_h, ///
    keep(*#*c.totaltreat_pf) ///
    coeflabels(2009.year#c.totaltreat_pf = "2009" ///
               2010.year#c.totaltreat_pf = "2010" ///
               2011.year#c.totaltreat_pf = "2011" ///
               2012.year#c.totaltreat_pf = "2012" ///
               2013.year#c.totaltreat_pf = "2013" ///
               2014.year#c.totaltreat_pf = "2014" ///
               2015.year#c.totaltreat_pf = "2015" ///
               2016.year#c.totaltreat_pf = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-.2(.05).6) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Log Employment", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(orange)) mcolor(orange) ///
	text(-0.09 6 "C x Post Coef: 0.32", color(orange))
	
graph export "$graphs/es_emp_spill_lagosuntreated_h.png", as(png) replace	




local conn totaltreat_pf
reghdfe   /// your regression
     lr_remdezr    /// (example outcome)
        c.`conn'##b(2011).year  if sample_01==1 & high_totaltreat_pf==1,  ///
        absorb(identificad year industry1#year  mode_base_month#year microregion#year)   /// FE spec name
        vce(cluster identificad)
estimates store es_spill_remdezr_ut_h	


reghdfe   /// your regression
     lr_remdezr    /// (example outcome)
        c.totaltreat_pf##treat_year  if sample_01==1  & high_totaltreat_pf==1,  ///
        absorb(identificad year industry1#treat_year  mode_base_month#treat_year microregion#treat_year)   /// FE spec name
        vce(cluster identificad)

local conn totaltreat_pf	
// Create event study plot
coefplot es_spill_remdezr_ut_h, ///
    keep(*#*c.`conn') ///
    msymbol(diamond) ///
    coeflabels(2009.year#c.`conn' = "2009" ///
               2010.year#c.`conn' = "2010" ///
               2011.year#c.`conn'= "2011" ///
               2012.year#c.`conn' = "2012" ///
               2013.year#c.`conn' = "2013" ///
               2014.year#c.`conn' = "2014" ///
               2015.year#c.`conn' = "2015" ///
               2016.year#c.`conn' = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-.1(.02).1) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Log December Earnings", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) 
//     text(-0.09 6 "C x Post Coef: -0.019", color(blue))

    
graph export "$graphs/es_remdezr_spill_lagosuntreated_h.png", as(png) replace



// Trying a different interpretation of Bassier (2022): 
// We have a direct effects sample that we disregard highly connected estabs from control to do direct effects
// We then use only original lagos sample control to do spillover effects


// Log Employment
reghdfe   /// your regression
     l_firm_emp    /// (example outcome)
       c.totaltreat_pf##b(2011).year  if lagos_sample_spill==1 ,  ///
        absorb(identificad year industry1#year mode_base_month#year microregion#year)   /// FE spec name
        vce(cluster identificad)
estimates store es_spill_emp_lss

reghdfe   /// your regression
     l_firm_emp     /// (example outcome)
        c.totaltreat_pf##treat_year  if lagos_sample_spill==1,  ///
        absorb(identificad year industry1#treat_year  mode_base_month#treat_year microregion#treat_year)   /// FE spec name
        vce(cluster identificad)	
	
// Create event study plot
coefplot es_spill_emp_lss, ///
    keep(*#*c.totaltreat_pf) ///
    coeflabels(2009.year#c.totaltreat_pf = "2009" ///
               2010.year#c.totaltreat_pf = "2010" ///
               2011.year#c.totaltreat_pf = "2011" ///
               2012.year#c.totaltreat_pf = "2012" ///
               2013.year#c.totaltreat_pf = "2013" ///
               2014.year#c.totaltreat_pf = "2014" ///
               2015.year#c.totaltreat_pf = "2015" ///
               2016.year#c.totaltreat_pf = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-.3(.05).3) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Log Employment", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(orange)) mcolor(orange) 
// 	text(-0.09 6 "C x Post Coef: 0.32", color(orange))
	
graph export "$graphs/es_emp_spill_lss.png", as(png) replace	




local conn totaltreat_pf
reghdfe   /// your regression
     lr_remdezr    /// (example outcome)
        c.`conn'##b(2011).year  if lagos_sample_spill==1,  ///
        absorb(identificad year industry1#year c.totalflows#year mode_base_month#year microregion#year)   /// FE spec name
        vce(cluster identificad)
estimates store es_spill_remdezr_lss	


reghdfe   /// your regression
     lr_remdezr    /// (example outcome)
        c.totaltreat_pf##treat_year  if lagos_sample_spill==1,  ///
        absorb(identificad year industry1#treat_year c.totalflows#treat_year mode_base_month#treat_year microregion#treat_year)   /// FE spec name
        vce(cluster identificad)

local conn totaltreat_pf	
// Create event study plot
coefplot es_spill_remdezr_lss, ///
    keep(*#*c.`conn') ///
    msymbol(diamond) ///
    coeflabels(2009.year#c.`conn' = "2009" ///
               2010.year#c.`conn' = "2010" ///
               2011.year#c.`conn'= "2011" ///
               2012.year#c.`conn' = "2012" ///
               2013.year#c.`conn' = "2013" ///
               2014.year#c.`conn' = "2014" ///
               2015.year#c.`conn' = "2015" ///
               2016.year#c.`conn' = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-.1(.02).15) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Log December Earnings", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) 
//     text(-0.09 6 "C x Post Coef: -0.019", color(blue))

    
graph export "$graphs/es_remdezr_spill_lss.png", as(png) replace


// Trying a different interpretation of Bassier (2022): 
// We have a direct effects sample that we disregard highly connected estabs from control to do direct effects
// We then use only original lagos sample control to do spillover effects


// Log Employment
reghdfe   /// your regression
     l_firm_emp    /// (example outcome)
       c.totaltreat_pf##b(2011).year  if lagos_sample_spill==1 ,  ///
        absorb(identificad year industry1#year mode_base_month#year microregion#year)   /// FE spec name
        vce(cluster identificad)
estimates store es_spill_emp_lss

reghdfe   /// your regression
     l_firm_emp     /// (example outcome)
        c.totaltreat_pf##treat_year  if lagos_sample_spill==1,  ///
        absorb(identificad year industry1#treat_year  mode_base_month#treat_year microregion#treat_year)   /// FE spec name
        vce(cluster identificad)	
	
// Create event study plot
coefplot es_spill_emp_lss, ///
    keep(*#*c.totaltreat_pf) ///
    coeflabels(2009.year#c.totaltreat_pf = "2009" ///
               2010.year#c.totaltreat_pf = "2010" ///
               2011.year#c.totaltreat_pf = "2011" ///
               2012.year#c.totaltreat_pf = "2012" ///
               2013.year#c.totaltreat_pf = "2013" ///
               2014.year#c.totaltreat_pf = "2014" ///
               2015.year#c.totaltreat_pf = "2015" ///
               2016.year#c.totaltreat_pf = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-.3(.05).3) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Log Employment", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(orange)) mcolor(orange) 
// 	text(-0.09 6 "C x Post Coef: 0.32", color(orange))
	
graph export "$graphs/es_emp_spill_lss.png", as(png) replace	




local conn totaltreat_pf
reghdfe   /// your regression
     lr_remdezr    /// (example outcome)
        c.`conn'##b(2011).year  if lagos_sample_spill==1,  ///
        absorb(identificad year industry1#year  mode_base_month#year microregion#year)   /// FE spec name
        vce(cluster identificad)
estimates store es_spill_remdezr_lss	


reghdfe   /// your regression
     lr_remdezr    /// (example outcome)
        c.totaltreat_pf##treat_year  if lagos_sample_spill==1,  ///
        absorb(identificad year industry1#treat_year  mode_base_month#treat_year microregion#treat_year)   /// FE spec name
        vce(cluster identificad)

local conn totaltreat_pf	
// Create event study plot
coefplot es_spill_remdezr_lss, ///
    keep(*#*c.`conn') ///
    msymbol(diamond) ///
    coeflabels(2009.year#c.`conn' = "2009" ///
               2010.year#c.`conn' = "2010" ///
               2011.year#c.`conn'= "2011" ///
               2012.year#c.`conn' = "2012" ///
               2013.year#c.`conn' = "2013" ///
               2014.year#c.`conn' = "2014" ///
               2015.year#c.`conn' = "2015" ///
               2016.year#c.`conn' = "2016") ///
    vert omitted baselevels yline(0) xline(3.75, lpattern(dash)) ///
	ylabel(-.1(.02).15) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Spillover Effect on Log December Earnings", size(medium large)) ///
    note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue) 
//     text(-0.09 6 "C x Post Coef: -0.019", color(blue))

    
graph export "$graphs/es_remdezr_spill_lss.png", as(png) replace


// Testing if sample_01 excluding high connectivity is a good control for direct effects
// Then it would only be a matter of justifying to use this sample over the one by lagos

// Creating samples: 
// sample x: control - everyone with at least one cba in the period and low connectivity and treat_ultra==0
// 	     trated  - everyone with at least one cba in the period and treat_ultra==1

gen sample_x = cond((treat_ultra==1)|(treat_ultra==0 & high_totaltreat_pf==0), 1,0)


// I.a. log employment

reghdfe l_firm_emp treat_ultra##b(2011).year  if  sample_x==1 & in_balanced_panel==1,  absorb( identificad industry1#year mode_base_month#year microregion#year) vce(cluster identificad)
estimates store es_direct_emp_x

// Create event study plot
coefplot es_direct_emp_x, ///
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
    ci(95) ciopts(recast(rcap) color(orange)) mcolor(orange)
	
graph export "$graphs/es_l_emp_treat_x.png", as(png) replace

// I.c. log december earnings:

reghdfe lr_remdezr treat_ultra##b(2011).year  if sample_x==1 & in_balanced_panel==1, absorb(year identificad  industry1#year mode_base_month#year  microregion#year ) vce(cluster identificad)
estimates store es_direct_remdezr_x

// Create event study plot
coefplot es_direct_remdezr_x, ///
msymbol(diamond) ///
    keep(1.treat_ultra#2009.year 1.treat_ultra#2010.year 1.treat_ultra#2011.year 1.treat_ultra#2012.year 1.treat_ultra#2013.year 1.treat_ultra#2014.year 1.treat_ultra#2015.year 1.treat_ultra#2016.year) ///
    coeflabels(1.treat_ultra#2009.year = "2009" ///
              1.treat_ultra#2010.year = "2010" ///
              1.treat_ultra#2011.year = "2011" ///
              1.treat_ultra#2012.year = "2012" ///
              1.treat_ultra#2013.year = "2013" ///
              1.treat_ultra#2014.year = "2014" ///
              1.treat_ultra#2015.year = "2015" ///
              1.treat_ultra#2016.year = "2016") ///
    vert omitted baselevels yline(0)  xline(3.75, lpattern(dash)) ///
	ylabel(-.06(.02).08) ///
	ytitle("Dynamic DiD coefficients", size(small)) ///
    title("Direct Effect on Log December Earnings", size(medium large)) ///
   note("Dashed line corresponds to the enactment of ultractivity (Sep. 2012)") ///
    graphregion(color(white)) bgcolor(white) ///
    ci(95) ciopts(recast(rcap) color(blue)) mcolor(blue)
    //     text(.045 6 "Post x Treat Coef: 0.019", color(blue)) ///
 
	
graph export "$graphs/es_l_remdezr_treat_x.png", as(png) replace
 

 // connectivity tests: 
 
 
 foreach conn in totaltreat_pf totaltreat_pw avg_flowtreat_pf{
 	reg `conn' treat_ultra industry1 mode_base_month microregion pub_firm mode_union avg_n_negs if lagos_sample_avg==1 & year==2009, rob 
 }
 
 
 foreach conn in totalone_pf totalone_pw avg_flowone_pf{
 	reg `conn' treat_ultra industry1 mode_base_month microregion pub_firm mode_union avg_n_negs if in_balanced_panel==1 & !missing(mode_base_month) & year==2009, rob 
 }
 
 foreach conn in totalzero_pf totalzero_pw avg_flowzero_pf{
 	reg `conn' treat_ultra industry1 mode_base_month microregion pub_firm mode_union avg_n_negs if in_balanced_panel==1 & year==2009, rob 
 }
 
 
 timer clear
timer on 1
local samples "1 2 3"
local outcomes "l_firm_emp lr_remdezr lr_remmedr"

* Loop over samples
foreach s of local samples {
    
    * Set connectivity measures for each sample
    if `s' == 1 {
        local conn_measures "totalone_pf totalone_pw avg_flowone_pf"
        local sample_condition "!missing(mode_base_month) & in_balanced_panel==1 & treat_ultra==0"
        local direct_sample_condition "!missing(mode_base_month) & in_balanced_panel==1"
    }
    else if `s' == 2 {
        local conn_measures "totalzero_pf totalzero_pw avg_flowzero_pf"
        local sample_condition "in_balanced_panel==1 & treat_ultra==0"
        local direct_sample_condition "in_balanced_panel==1"
    }
    else if `s' == 3 {
        local conn_measures "totaltreat_pf totaltreat_pw avg_flowtreat_pf"
        local sample_condition "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0"
        local direct_sample_condition "lagos_sample_avg==1 & in_balanced_panel==1"
    }
    
    * Loop over outcomes
    foreach outcome of local outcomes {
        
        * Clear stored estimates
        eststo clear
        
        * Loop over connectivity measures
        foreach conn of local conn_measures {
            
            * Base specification (without mode_union, avg_n_negs, pub_firm, totalflows)
            eststo `conn'_base: reghdfe `outcome' c.`conn'##b(2011).year if `sample_condition', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year) ///
                vce(cluster identificad) parallel(2)
            
            * Add mode_union (skip for sample 2)
            if `s' != 2 {
                eststo `conn'_union: reghdfe `outcome' c.`conn'##b(2011).year if `sample_condition', ///
                    absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
                    vce(cluster identificad) parallel(2)
            }
           
            * Add avg_n_negs as continuous FE (skip for sample 2)
            if `s' != 2 {
                eststo `conn'_negs: reghdfe `outcome' c.`conn'##b(2011).year if `sample_condition', ///
                    absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year c.avg_n_negs#year) ///
                    vce(cluster identificad) parallel(2)
            }
           
            * Add totalflows as continuous FE
            eststo `conn'_flow: reghdfe `outcome' c.`conn'##b(2011).year if `sample_condition', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year c.avg_n_negs#year c.totalflows#year) ///
                vce(cluster identificad) parallel(2)
           
            * Add pub_firm
            eststo `conn'_full: reghdfe `outcome' c.`conn'##b(2011).year if `sample_condition', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year c.avg_n_negs#year c.totalflows#year pub_firm#year) ///
                vce(cluster identificad) parallel(2)
        }
        
        * Direct effects regressions
        * Base specification
        eststo direct_base: reghdfe `outcome' treat_ultra##b(2011).year if `direct_sample_condition', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year) ///
            vce(cluster identificad) parallel(2)
        
        * Add mode_union (skip for sample 2)
        if `s' != 2 {
            eststo direct_union: reghdfe `outcome' treat_ultra##b(2011).year if `direct_sample_condition', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
                vce(cluster identificad) parallel(2)
        }
       
        * Add avg_n_negs as continuous FE (skip for sample 2)
        if `s' != 2 {
            eststo direct_negs: reghdfe `outcome' treat_ultra##b(2011).year if `direct_sample_condition', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year c.avg_n_negs#year) ///
                vce(cluster identificad) parallel(2)
        }
       
        * Add totalflows as continuous FE
        eststo direct_flow: reghdfe `outcome' treat_ultra##b(2011).year if `direct_sample_condition', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year c.avg_n_negs#year c.totalflows#year) ///
            vce(cluster identificad) parallel(2)
       
        * Add pub_firm
        eststo direct_full: reghdfe `outcome' treat_ultra##b(2011).year if `direct_sample_condition', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year c.avg_n_negs#year c.totalflows#year pub_firm#year) ///
            vce(cluster identificad) parallel(2)
        
        * Create one table for this sample and outcome
        esttab using "$tables/spillover_sample`s'_`outcome'.csv", ///
            keep(*#*c.* 1.treat_ultra*#*) se star(* 0.10 ** 0.05 *** 0.01) b(3) se(3) replace
        
    }
}
timer off 1
timer list






local outcome lr_remdezr
local direct_sample_condition "lagos_sample_avg==1 & in_balanced_panel==1 & !missing(avg_flowtreat_pf)"
    

* Direct effects regressions
        * Base specification
        eststo direct_base: reghdfe `outcome' treat_ultra##b(2011).year if `direct_sample_condition', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year) ///
            vce(cluster identificad) parallel(2)
        
	* Add mode uinon
        eststo direct_union: reghdfe `outcome' treat_ultra##b(2011).year if `direct_sample_condition', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
            vce(cluster identificad) parallel(2)
	    
	    * Add avg_n_negs
        eststo direct_negs: reghdfe `outcome' treat_ultra##b(2011).year if `direct_sample_condition', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year c.avg_n_negs#year) ///
            vce(cluster identificad) parallel(2)
               
        * Add totalflows as continuous FE
        eststo direct_flow: reghdfe `outcome' treat_ultra##b(2011).year if `direct_sample_condition', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year c.avg_n_negs#year c.totalflows#year) ///
            vce(cluster identificad) parallel(2)
       
        * Add pub_firm
        eststo direct_full: reghdfe `outcome' treat_ultra##b(2011).year if `direct_sample_condition', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year c.avg_n_negs#year c.totalflows#year pub_firm#year) ///
            vce(cluster identificad) parallel(2)
        
        * Create one table for this sample and outcome
        esttab using "$tables/direct_sample3_`outcome'.csv", ///
            keep(1.treat_ultra*#*) se star(* 0.10 ** 0.05 *** 0.01) b(3) se(3) replace
	
gen avg_flowtreat_pf_c = avg_flowtreat_pf
replace avg_flowtreat_pf_c = 0 if !missing(avg_flowtreat_pf) & (totalflows==0 | totalflows==.)




keep if lagos_sample_avg==1

timer clear

// timer on 1
// reghdfe l_firm_emp c.totaltreat_pf_n##b(2011).year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0, ///
//     absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
//     vce(cluster identificad) parallel(2)
//
// timer off 1
// timer list        

timer on 2

local samples "3"
local outcomes "l_firm_emp lr_remdezr lr_remmedr"

* Loop over samples
foreach s of local samples {
    
    * Set connectivity measures for each sample
    if `s' == 3 {
        local conn_measures "totaltreat_pf_n totaltreat_pw_n avg_ftreat_pf_n"
        local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0"
        local s_direct "lagos_sample_avg==1 & in_balanced_panel==1"
        local s_spill_r "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & !missing(avg_flowtreat_pf)"
        local s_direct_r "lagos_sample_avg==1 & in_balanced_panel==1 & !missing(avg_flowtreat_pf)"
    }
    
    * Loop over outcomes
    foreach outcome of local outcomes {
        
        * Clear stored estimates
        eststo clear
        
        * Loop over connectivity measures
        foreach conn of local conn_measures {
            
            * REGULAR SAMPLE - Spillover effects
            * Base specification
            eststo `conn'_1: reghdfe `outcome' c.`conn'##b(2011).year if `s_spill', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year) ///
                vce(cluster identificad) parallel(2)
            
            * Individual controls
            eststo `conn'_2: reghdfe `outcome' c.`conn'##b(2011).year if `s_spill', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
                vce(cluster identificad) parallel(2)
            
            eststo `conn'_3: reghdfe `outcome' c.`conn'##b(2011).year if `s_spill', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year c.avg_n_negs_pre#year) ///
                vce(cluster identificad) parallel(2)
            
            eststo `conn'_4: reghdfe `outcome' c.`conn'##b(2011).year if `s_spill', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year c.totalflows_n#year) ///
                vce(cluster identificad) parallel(2)
            
            eststo `conn'_5: reghdfe `outcome' c.`conn'##b(2011).year if `s_spill', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year pub_firm#year) ///
                vce(cluster identificad) parallel(2)
            
            * Incremental specifications
            eststo `conn'_6: reghdfe `outcome' c.`conn'##b(2011).year if `s_spill', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
                vce(cluster identificad) parallel(2)
            
            eststo `conn'_7: reghdfe `outcome' c.`conn'##b(2011).year if `s_spill', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year c.avg_n_negs_pre#year) ///
                vce(cluster identificad) parallel(2)
            
            eststo `conn'_8: reghdfe `outcome' c.`conn'##b(2011).year if `s_spill', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year c.avg_n_negs_pre#year c.totalflows_n#year) ///
                vce(cluster identificad) parallel(2)
            
            eststo `conn'_9: reghdfe `outcome' c.`conn'##b(2011).year if `s_spill', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year c.avg_n_negs_pre#year c.totalflows_n#year pub_firm#year) ///
                vce(cluster identificad) parallel(2)
            
            * RESTRICTIVE SAMPLE - Spillover effects
            * Base specification
            eststo `conn'_10: reghdfe `outcome' c.`conn'##b(2011).year if `s_spill_r', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year) ///
                vce(cluster identificad) parallel(2)
            
            * Individual controls
            eststo `conn'_11: reghdfe `outcome' c.`conn'##b(2011).year if `s_spill_r', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
                vce(cluster identificad) parallel(2)
            
            eststo `conn'_12: reghdfe `outcome' c.`conn'##b(2011).year if `s_spill_r', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year c.avg_n_negs_pre#year) ///
                vce(cluster identificad) parallel(2)
            
            eststo `conn'_13: reghdfe `outcome' c.`conn'##b(2011).year if `s_spill_r', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year c.totalflows_n#year) ///
                vce(cluster identificad) parallel(2)
            
            eststo `conn'_14: reghdfe `outcome' c.`conn'##b(2011).year if `s_spill_r', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year pub_firm#year) ///
                vce(cluster identificad) parallel(2)
            
            * Incremental specifications
            eststo `conn'_15: reghdfe `outcome' c.`conn'##b(2011).year if `s_spill_r', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
                vce(cluster identificad) parallel(2)
            
            eststo `conn'_16: reghdfe `outcome' c.`conn'##b(2011).year if `s_spill_r', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year c.avg_n_negs_pre#year) ///
                vce(cluster identificad) parallel(2)
            
            eststo `conn'_17: reghdfe `outcome' c.`conn'##b(2011).year if `s_spill_r', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year c.avg_n_negs_pre#year c.totalflows_n#year) ///
                vce(cluster identificad) parallel(2)
            
            eststo `conn'_18: reghdfe `outcome' c.`conn'##b(2011).year if `s_spill_r', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year c.avg_n_negs_pre#year c.totalflows_n#year pub_firm#year) ///
                vce(cluster identificad) parallel(2)
        }
        
        * REGULAR SAMPLE - Direct effects
        * Base specification
        eststo direct_1: reghdfe `outcome' treat_ultra##b(2011).year if `s_direct', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year) ///
            vce(cluster identificad) parallel(2)
        
        * Individual controls
        eststo direct_2: reghdfe `outcome' treat_ultra##b(2011).year if `s_direct', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
            vce(cluster identificad) parallel(2)
        
        eststo direct_3: reghdfe `outcome' treat_ultra##b(2011).year if `s_direct', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year c.avg_n_negs_pre#year) ///
            vce(cluster identificad) parallel(2)
        
        eststo direct_4: reghdfe `outcome' treat_ultra##b(2011).year if `s_direct', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year c.totalflows_n#year) ///
            vce(cluster identificad) parallel(2)
        
        eststo direct_5: reghdfe `outcome' treat_ultra##b(2011).year if `s_direct', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year pub_firm#year) ///
            vce(cluster identificad) parallel(2)
        
        * Incremental specifications
        eststo direct_6: reghdfe `outcome' treat_ultra##b(2011).year if `s_direct', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
            vce(cluster identificad) parallel(2)
        
        eststo direct_7: reghdfe `outcome' treat_ultra##b(2011).year if `s_direct', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year c.avg_n_negs_pre#year) ///
            vce(cluster identificad) parallel(2)
        
        eststo direct_8: reghdfe `outcome' treat_ultra##b(2011).year if `s_direct', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year c.avg_n_negs_pre#year c.totalflows_n#year) ///
            vce(cluster identificad) parallel(2)
        
        eststo direct_9: reghdfe `outcome' treat_ultra##b(2011).year if `s_direct', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year c.avg_n_negs_pre#year c.totalflows_n#year pub_firm#year) ///
            vce(cluster identificad) parallel(2)
        
        * RESTRICTIVE SAMPLE - Direct effects
        * Base specification
        eststo direct_10: reghdfe `outcome' treat_ultra##b(2011).year if `s_direct_r', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year) ///
            vce(cluster identificad) parallel(2)
        
        * Individual controls
        eststo direct_11: reghdfe `outcome' treat_ultra##b(2011).year if `s_direct_r', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
            vce(cluster identificad) parallel(2)
        
        eststo direct_12: reghdfe `outcome' treat_ultra##b(2011).year if `s_direct_r', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year c.avg_n_negs_pre#year) ///
            vce(cluster identificad) parallel(2)
        
        eststo direct_13: reghdfe `outcome' treat_ultra##b(2011).year if `s_direct_r', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year c.totalflows_n#year) ///
            vce(cluster identificad) parallel(2)
        
        eststo direct_14: reghdfe `outcome' treat_ultra##b(2011).year if `s_direct_r', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year pub_firm#year) ///
            vce(cluster identificad) parallel(2)
        
        * Incremental specifications
        eststo direct_15: reghdfe `outcome' treat_ultra##b(2011).year if `s_direct_r', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
            vce(cluster identificad) parallel(2)
        
        eststo direct_16: reghdfe `outcome' treat_ultra##b(2011).year if `s_direct_r', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year c.avg_n_negs_pre#year) ///
            vce(cluster identificad) parallel(2)
        
        eststo direct_17: reghdfe `outcome' treat_ultra##b(2011).year if `s_direct_r', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year c.avg_n_negs_pre#year c.totalflows_n#year) ///
            vce(cluster identificad) parallel(2)
        
        eststo direct_18: reghdfe `outcome' treat_ultra##b(2011).year if `s_direct_r', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year c.avg_n_negs_pre#year c.totalflows_n#year pub_firm#year) ///
            vce(cluster identificad) parallel(2)
        
        * Create one table for this sample and outcome
        esttab using "$tables/spillover_sample`s'_`outcome'.csv", ///
            keep(*#*c.* 1.treat_ultra*#*) se star(* 0.10 ** 0.05 *** 0.01) b(3) se(3) replace
        
    }
}

timer off 2
timer list
	


// Testing if effects of mode_union are due to sample selection or the control itself:		


* First, create a variable to identify singletons for mode_union x year
// egen mu_year_cell = group(mode_union year)
// bys mu_year_cell: gen mu_year_n = _N
// gen no_sing_mu = cond(mu_year_n >1 & mu_year_cell!=., 1,0)

local outcomes "l_firm_emp lr_remdezr lr_remmedr"
local conn_measures "totaltreat_pf_n totaltreat_pw_n avg_ftreat_pf_n"
local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0  & !missing(avg_flowtreat_pf)"


foreach outcome of local outcomes{
	foreach conn of local conn_measures{
		gen s_`outcome'_`conn'=0
	}
}

local outcomes "l_firm_emp lr_remdezr lr_remmedr"
local conn_measures "totaltreat_pf_n totaltreat_pw_n avg_ftreat_pf_n"
local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0  & !missing(avg_flowtreat_pf)"

timer on 3

foreach outcome of local outcomes {
    eststo clear
    local m = 1

    foreach conn of local conn_measures {

        * 1. mode_union#year, to generate sample
        eststo m`m': reghdfe `outcome' c.`conn'##b(2011).year if `s_spill', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
            vce(cluster identificad) parallel(2)
	    replace s_`outcome'_`conn' = e(sample)
        local ++m

        * 2. base specification, but restricting sample
        eststo m`m': reghdfe `outcome' c.`conn'##b(2011).year if `s_spill' & s_`outcome'_`conn'==1, ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year ) ///
            vce(cluster identificad) parallel(2)
        local ++m

        * 3. avg_n_negs_pre#year
        eststo m`m': reghdfe `outcome' c.`conn'##b(2011).year if `s_spill' & s_`outcome'_`conn'==1, ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year c.avg_n_negs_pre#year) ///
            vce(cluster identificad) parallel(2)
        local ++m

        * 4. totalflows_n#year
        eststo m`m': reghdfe `outcome' c.`conn'##b(2011).year if `s_spill' & s_`outcome'_`conn'==1, ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year c.totalflows_n#year) ///
            vce(cluster identificad) parallel(2)
        local ++m

        * 5. pub_firm#year
        eststo m`m': reghdfe `outcome' c.`conn'##b(2011).year if `s_spill' & s_`outcome'_`conn'==1, ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year pub_firm#year) ///
            vce(cluster identificad) parallel(2)
        local ++m
    }

    * Save all models for this outcome in one CSV
    esttab m* using "$tables/no_mu_sing_`outcome'.csv", ///
        keep(*#*c.totaltreat_pf_n *#*c.totaltreat_pw_n *#*c.avg_ftreat_pf_n) ///
        se star(* 0.10 ** 0.05 *** 0.01) b(3) se(3) replace
}

timer off 3
timer list 
// apparently, the control itself is making a difference. detrending by  union specific trends does seem to generate the negative spillvoers

// On top of mode_union and the constraint induced by avg_flowtreat_pf, let's see if the effect survives the inclusion of tvfe of outocome variable in the begining of the sample.


local outcomes "lr_remmedr lr_remdezr lr_remmedr"
local conn_measures "totaltreat_pf_n totaltreat_pw_n avg_ftreat_pf_n"
local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0  & !missing(avg_flowtreat_pf)"
local s_direct "lagos_sample_avg==1 & in_balanced_panel==1   & !missing(avg_flowtreat_pf)"


timer on 4

foreach outcome of local outcomes {
    eststo clear
    local m = 1

    foreach conn of local conn_measures {

        

        * 2. base specification, but restricting sample
        eststo m`m': reghdfe `outcome' c.`conn'##b(2011).year if `s_spill', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year ) ///
            vce(cluster identificad) parallel(2)
        local ++m
	
	* 2'. base specification, but restricting sample
        eststo m`m': reghdfe `outcome' c.`conn'##b(2011).year if `s_spill', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year `outcome'_2009_5#year) ///
            vce(cluster identificad) parallel(2)
        local ++m

        * 3. avg_n_negs_pre#year
        eststo m`m': reghdfe `outcome' c.`conn'##b(2011).year if `s_spill' , ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year c.avg_n_negs_pre#year) ///
            vce(cluster identificad) parallel(2)
        local ++m
	
	* 3'. avg_n_negs_pre#year
        eststo m`m': reghdfe `outcome' c.`conn'##b(2011).year if `s_spill' , ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year c.avg_n_negs_pre#year `outcome'_2009_5#year) ///
            vce(cluster identificad) parallel(2)
        local ++m

        * 4. totalflows_n#year
        eststo m`m': reghdfe `outcome' c.`conn'##b(2011).year if `s_spill', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year c.totalflows_n#year ) ///
            vce(cluster identificad) parallel(2)
        local ++m
	* 4'. totalflows_n#year
        eststo m`m': reghdfe `outcome' c.`conn'##b(2011).year if `s_spill', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year c.totalflows_n#year `outcome'_2009_5#year) ///
            vce(cluster identificad) parallel(2)
        local ++m

        * 5. pub_firm#year
        eststo m`m': reghdfe `outcome' c.`conn'##b(2011).year if `s_spill' , ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year pub_firm#year) ///
            vce(cluster identificad) parallel(2)
        local ++m
	 * 5'. pub_firm#year
        eststo m`m': reghdfe `outcome' c.`conn'##b(2011).year if `s_spill' , ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year pub_firm#year `outcome'_2009_5#year) ///
            vce(cluster identificad) parallel(2)
        local ++m
    }
    
//    REgressions for the direct effects: 
    * 2. base specification, but restricting sample
        eststo m`m': reghdfe `outcome' treat_ultra##b(2011).year if `s_direct', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year ) ///
            vce(cluster identificad) parallel(2)
        local ++m
	
	* 2'. base specification, but restricting sample
        eststo m`m': reghdfe `outcome' treat_ultra##b(2011).year if `s_direct', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year `outcome'_2009_5#year) ///
            vce(cluster identificad) parallel(2)
        local ++m

        * 3. avg_n_negs_pre#year
        eststo m`m': reghdfe `outcome' treat_ultra##b(2011).year if `s_direct' , ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year c.avg_n_negs_pre#year) ///
            vce(cluster identificad) parallel(2)
        local ++m
	
	* 3'. avg_n_negs_pre#year
        eststo m`m': reghdfe `outcome' treat_ultra##b(2011).year if `s_direct' , ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year c.avg_n_negs_pre#year `outcome'_2009_5#year) ///
            vce(cluster identificad) parallel(2)
        local ++m

        * 4. totalflows_n#year
        eststo m`m': reghdfe `outcome' treat_ultra##b(2011).year if `s_direct', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year c.totalflows_n#year ) ///
            vce(cluster identificad) parallel(2)
        local ++m
	* 4'. totalflows_n#year
        eststo m`m': reghdfe `outcome' treat_ultra##b(2011).year if `s_direct', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year c.totalflows_n#year `outcome'_2009_5#year) ///
            vce(cluster identificad) parallel(2)
        local ++m

        * 5. pub_firm#year
        eststo m`m': reghdfe `outcome' treat_ultra##b(2011).year if `s_direct' , ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year pub_firm#year) ///
            vce(cluster identificad) parallel(2)
        local ++m
	 * 5'. pub_firm#year
        eststo m`m': reghdfe `outcome' treat_ultra##b(2011).year if `s_direct' , ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year pub_firm#year `outcome'_2009_5#year) ///
            vce(cluster identificad) parallel(2)
        local ++m
    

    * Save all models for this outcome in one CSV
    esttab m* using "$tables/mu_lag_`outcome'.csv", ///
        keep(*#*c.totaltreat_pf_n *#*c.totaltreat_pw_n *#*c.avg_ftreat_pf_n 1.treat_ultra*#*) ///
        se star(* 0.10 ** 0.05 *** 0.01) b(3) se(3) replace
}

timer off 4
timer list 


local outcomes "l_firm_emp lr_remdezr lr_remmedr"
local lags "l_firm_emp_2009_5 lr_remdezr_2009_5 lr_remmedr_2009_5"
local conn_measures "totaltreat_pf_n totaltreat_pw_n avg_ftreat_pf_n"
local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0  "
local s_direct "lagos_sample_avg==1 & in_balanced_panel==1 "


eststo clear
    local m = 1
foreach outcome of local outcomes{
	foreach lag of local lags{
	foreach conn of local conn_measures{
		
		* 2. base specification, but restricting sample
        eststo m`m': reghdfe `outcome' c.`conn'##b(2011).year if `s_spill', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year ) ///
            vce(cluster identificad) parallel(2)
        local ++m
	
	* 2'. base specification, but restricting sample
        eststo m`m': reghdfe `outcome' c.`conn'##b(2011).year if `s_spill', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year `lag'#year) ///
            vce(cluster identificad) parallel(2)
        local ++m
	
		}
		//    REgressions for the direct effects: 
    * 2. base specification, but restricting sample
        eststo m`m': reghdfe `outcome' treat_ultra##b(2011).year if `s_direct', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year ) ///
            vce(cluster identificad) parallel(2)
        local ++m
	
	* 2'. base specification, but restricting sample
        eststo m`m': reghdfe `outcome' treat_ultra##b(2011).year if `s_direct', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year `lag'#year) ///
            vce(cluster identificad) parallel(2)
        local ++m
	}
	
}

* Save all models for this outcome in one CSV
    esttab m* using "$tables/mu_lags.csv", ///
        keep(*#*c.totaltreat_pf_n *#*c.totaltreat_pw_n *#*c.avg_ftreat_pf_n 1.treat_ultra*#*) ///
        se star(* 0.10 ** 0.05 *** 0.01) b(3) se(3) replace
	

	
// Don't Apply avg_flowtreat_pf restriction to direct effect. 
// Divide direct effects between full control sample and low connectivity sample




* Set connectivity measures for each sample
         local outcomes "l_firm_emp lr_remdezr lr_remmedr"
	 local conn_measures "totaltreat_pf_n totaltreat_pw_n avg_ftreat_pf_n"
        local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0"
        local s_direct "lagos_sample_avg==1 & in_balanced_panel==1"
        local s_spill_r "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & !missing(avg_flowtreat_pf)"
	local s_spill_flow "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & totalflows_n>1 & !missing(totalflows_n)"
	local s_spill_emp "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp>=10 & !missing(firm_emp)"
        local s_direct_r "lagos_sample_avg==1 & in_balanced_panel==1 & !missing(avg_flowtreat_pf)"
	local s_direct_btpf "lagos_sample_avg==1 & in_balanced_panel==1 & bassier_tpf==1"
	local s_direct_btpw "lagos_sample_avg==1 & in_balanced_panel==1 & bassier_tpw==1"
	local s_direct_bapf "lagos_sample_avg==1 & in_balanced_panel==1 & bassier_apf==1"
	
	timer on 5
    
    * Loop over outcomes
    foreach outcome of local outcomes {
        
        * Clear stored estimates
        eststo clear
        
//         * Loop over connectivity measures
//         foreach conn of local conn_measures {
//            
//             * REGULAR SAMPLE - Spillover effects
//             * Base specification
//             eststo `conn'_1: reghdfe `outcome' c.`conn'##b(2011).year if `s_spill', ///
//                 absorb(identificad year industry1#year mode_base_month#year microregion#year) ///
//                 vce(cluster identificad) parallel(2)
//            
//             * Individual controls
//             eststo `conn'_2: reghdfe `outcome' c.`conn'##b(2011).year if `s_spill', ///
//                 absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
//                 vce(cluster identificad) parallel(2)
//            
//                       
//             * RESTRICTIVE SAMPLE - Spillover effects
//             * Base specification
//             eststo `conn'_3: reghdfe `outcome' c.`conn'##b(2011).year if `s_spill_r', ///
//                 absorb(identificad year industry1#year mode_base_month#year microregion#year) ///
//                 vce(cluster identificad) parallel(2)
//            
//             * Individual controls
//             eststo `conn'_4: reghdfe `outcome' c.`conn'##b(2011).year if `s_spill_r', ///
//                 absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
//                 vce(cluster identificad) parallel(2)
//		
// 	* RESTRICTIVE SAMPLE - Non-zero totalflows
// 	* Base specification
//             eststo `conn'_5: reghdfe `outcome' c.`conn'##b(2011).year if `s_spill_flow', ///
//                 absorb(identificad year industry1#year mode_base_month#year microregion#year) ///
//                 vce(cluster identificad) parallel(2)
//            
//             * Individual controls
//             eststo `conn'_6: reghdfe `outcome' c.`conn'##b(2011).year if `s_spill_flow', ///
//                 absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
//                 vce(cluster identificad) parallel(2)
//		
// 	* RESTRICTIVE SAMPLE - High 2009 employment
// 	* Base specification
//             eststo `conn'_7: reghdfe `outcome' c.`conn'##b(2011).year if `s_spill_emp', ///
//                 absorb(identificad year industry1#year mode_base_month#year microregion#year) ///
//                 vce(cluster identificad) parallel(2)
//            
//             * Individual controls
//             eststo `conn'_8: reghdfe `outcome' c.`conn'##b(2011).year if `s_spill_emp', ///
//                 absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
//                 vce(cluster identificad) parallel(2)
//        
//         }
        * REGULAR SAMPLE - Direct effects
        * Base specification
        eststo direct_9: reghdfe `outcome' treat_ultra##b(2011).year if `s_direct', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year) ///
            vce(cluster identificad) parallel(2)
       
        * Individual controls
        eststo direct_10: reghdfe `outcome' treat_ultra##b(2011).year if `s_direct', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
            vce(cluster identificad) parallel(2)
       
               
        * RESTRICTIVE SAMPLE - Direct effects
        * Base specification
        eststo direct_11: reghdfe `outcome' treat_ultra##b(2011).year if `s_direct_btpf', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year) ///
            vce(cluster identificad) parallel(2)
       
        * Individual controls
        eststo direct_12: reghdfe `outcome' treat_ultra##b(2011).year if `s_direct_btpf', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
            vce(cluster identificad) parallel(2)
	    
	     * Base specification
        eststo direct_13: reghdfe `outcome' treat_ultra##b(2011).year if `s_direct_btpw', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year) ///
            vce(cluster identificad) parallel(2)
       
        * Individual controls
        eststo direct_14: reghdfe `outcome' treat_ultra##b(2011).year if `s_direct_btpw', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
            vce(cluster identificad) parallel(2)
	    
	         * Base specification
        eststo direct_15: reghdfe `outcome' treat_ultra##b(2011).year if `s_direct_bapf', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year) ///
            vce(cluster identificad) parallel(2)
       
        * Individual controls
        eststo direct_16: reghdfe `outcome' treat_ultra##b(2011).year if `s_direct_bapf', ///
            absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
            vce(cluster identificad) parallel(2)
      
        
        
        * Create one table for this sample and outcome
        esttab using "$tables/mode_union_constraints_`outcome'.csv", ///
            keep(/*#*c.*/ 1.treat_ultra*#* ) se star(* 0.10 ** 0.05 *** 0.01) b(3) se(3) replace
        
    }

timer off 5
timer list

// Interaction terms and non-linearities in the effect of connectivity


// parametric approach: interaction with firm_emp, totalflows_n#year and quadratic term for connectivity

* Set connectivity measures for each sample
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
	
	timer on 6

foreach inter of local interactions {
    
    eststo clear
    local estnum = 1
    
    foreach conn of local conn_measures {
        foreach outcome of local outcomes {
            
            eststo est`estnum': reghdfe `outcome' c.`conn'##b(2011).year if `s_spill', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year) ///
                vce(cluster identificad)
            local ++estnum
            
            eststo est`estnum': reghdfe `outcome' c.`conn'##b(2011).year if `s_spill', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
                vce(cluster identificad)
            local ++estnum
            
            eststo est`estnum': reghdfe `outcome' c.`conn'##b(2011).year if `s_spill_r', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
                vce(cluster identificad)
            local ++estnum
            
            eststo est`estnum': reghdfe `outcome' c.`conn'##b(2011).year c.`conn'_`inter'##b(2011).year if `s_spill', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
                vce(cluster identificad)
            local ++estnum
            
            eststo est`estnum': reghdfe `outcome' c.`conn'##b(2011).year c.`conn'_`inter'##b(2011).year if `s_spill_r', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
                vce(cluster identificad)
            local ++estnum
        }
    }

    esttab using "$tables/mu_nlspecs_`inter'.csv", ///
        keep(*#*c.*) se star(* 0.10 ** 0.05 *** 0.01) b(3) se(3) replace
}

foreach squared of local squares {
    
    eststo clear
    local estnum = 1
    
    foreach conn of local conn_measures {
        foreach outcome of local outcomes {
            
            * Base specification
            eststo est`estnum': reghdfe `outcome' c.`conn'##b(2011).year if `s_spill', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year) ///
                vce(cluster identificad)
            local ++estnum
            
            * With individual controls
            eststo est`estnum': reghdfe `outcome' c.`conn'##b(2011).year if `s_spill', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
                vce(cluster identificad)
            local ++estnum
            
            * With mode_union and non-missing avg_flow restriction
            eststo est`estnum': reghdfe `outcome' c.`conn'##b(2011).year if `s_spill_r', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
                vce(cluster identificad)
            local ++estnum
            
            * With squared term interaction
            eststo est`estnum': reghdfe `outcome' c.`conn'##b(2011).year c.`squared'##b(2011).year if `s_spill', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
                vce(cluster identificad)
            local ++estnum
            
            * With squared term interaction and flow restriction
            eststo est`estnum': reghdfe `outcome' c.`conn'##b(2011).year c.`squared'##b(2011).year if `s_spill_r', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
                vce(cluster identificad)
            local ++estnum
        }
    }

    esttab using "$tables/mu_nlspecs_`squared'.csv", ///
        keep(*#*c.*) se star(* 0.10 ** 0.05 *** 0.01) b(3) se(3) replace
}

         

timer off 6
timer list

// For Jul 24 meeting:

timer clear
timer on 7
//
// local inter_am_totaltreat_pf_n "totaltreat_pf_n_am_tn_pre totaltreat_pf_n_am_lfe totaltreat_pf_n_am_tf_n_pw  totaltreat_pw_n_am_tn_pre totaltreat_pw_n_am_lfe totaltreat_pw_n_am_tf_n_pw  avg_ftreat_pf_n_am_tn_pre avg_ftreat_pf_n_am_lfe avg_ftreat_pf_n_am_tf_n_pw "
// 	 local inter_am_totaltreat_pw_n
// 	 local inter_am_avg_ftreat_pf_n
// 	 local inter_3_totaltreat_pf_n " totaltreat_pf_n_tn_pre_m totaltreat_pf_n_tn_pre_h totaltreat_pf_n_lfe_2009_m totaltreat_pf_n_lfe_2009_h totaltreat_pf_n_tf_n_pw_2009_m totaltreat_pf_n_tf_n_pw_2009_h  "
// 	 local inter_3_totaltreat_pw_n "totaltreat_pw_n_tn_pre_m totaltreat_pw_n_tn_pre_h totaltreat_pw_n_lfe_2009_m totaltreat_pw_n_lfe_2009_h totaltreat_pw_n_tf_n_pw_2009_m totaltreat_pw_n_tf_n_pw_2009_h"
// 	 local inter_3_avg_ftreat_pf_n "avg_ftreat_pf_n_tn_pre_m avg_ftreat_pf_n_tn_pre_h avg_ftreat_pf_n_lfe_2009_m avg_ftreat_pf_n_lfe_2009_h avg_ftreat_pf_n_tf_n_pw_2009_m avg_ftreat_pf_n_tf_n_pw_2009_h"
// 	 local conn_measures "totaltreat_pf_n totaltreat_pw_n avg_ftreat_pf_n "

* Set connectivity measures for each sample
         local outcomes "l_firm_emp lr_remdezr lr_remmedr"
	 local conn_measures "totaltreat_pf_n totaltreat_pw_n avg_ftreat_pf_n"
	 local interactions "tn_pre tf_n_pw lfe"
        local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0"
        local s_direct "lagos_sample_avg==1 & in_balanced_panel==1"
        local s_spill_r "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & !missing(avg_flowtreat_pf)"
	local s_spill_flow "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & totalflows_n>1 & !missing(totalflows_n)"
	local s_spill_emp "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp>=10 & !missing(firm_emp)"
        local s_direct_r "lagos_sample_avg==1 & in_balanced_panel==1 & !missing(avg_flowtreat_pf)"
	local s_direct_btpf "lagos_sample_avg==1 & in_balanced_panel==1 & bassier_tpf==1"
	local s_direct_btpw "lagos_sample_avg==1 & in_balanced_panel==1 & bassier_tpw==1"
	local s_direct_bapf "lagos_sample_avg==1 & in_balanced_panel==1 & bassier_apf==1"

	

	
foreach outcome of local outcomes{	

	eststo clear
	local estnum = 1
	
	foreach conn of local conn_measures{
// 	 * Base specification
            eststo est`estnum': reghdfe `outcome' c.`conn'##b(2011).year if `s_spill', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year) ///
                vce(cluster identificad)
            local ++estnum
           
            * With individual controls
            eststo est`estnum': reghdfe `outcome' c.`conn'##b(2011).year if `s_spill', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
                vce(cluster identificad)
            local ++estnum
           
            * With mode_union and non-missing avg_flow restriction
            eststo est`estnum': reghdfe `outcome' c.`conn'##b(2011).year if `s_spill_r', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
                vce(cluster identificad)
            local ++estnum

	    foreach inter of local interactions{
	     * With mode_union and am interaction terms:
            eststo est`estnum': reghdfe `outcome' c.`conn'##b(2011).year c.`conn'#am_`inter'##b(2011).year if `s_spill', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
                vce(cluster identificad)
            local ++estnum
	    
	    * Without mode_union, but with am interaction terms:
            eststo est`estnum': reghdfe `outcome' c.`conn'##b(2011).year c.`conn'#am_`inter'##b(2011).year if `s_spill', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year) ///
                vce(cluster identificad)
            local ++estnum
	    
	    * With mode_union and 3 groups interaction terms:
            eststo est`estnum': reghdfe `outcome' c.`conn'##b(2011).year c.`conn'#`inter'_m##b(2011).year c.`conn'#`inter'_h##b(2011).year if `s_spill', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year mode_union#year) ///
                vce(cluster identificad)
            local ++estnum
	    
	    * Without mode_union, but with 3 groups interaction terms:
            eststo est`estnum': reghdfe `outcome' c.`conn'##b(2011).year c.`conn'#`inter'_m##b(2011).year c.`conn'#`inter'_h##b(2011).year if `s_spill', ///
                absorb(identificad year industry1#year mode_base_month#year microregion#year) ///
                vce(cluster identificad)
            local ++estnum
	    }
}
esttab using "$tables/mu_catspects_`outcome'.csv", ///
        keep(*#*c.*) se star(* 0.10 ** 0.05 *** 0.01) b(3) se(3) replace
}

timer off 7
timer list

// Confirming variables exist before running loop:

// local conn_measures "totaltreat_pf_n totaltreat_pw_n avg_ftreat_pf_n"
// 	 local interactions "tn_pre tf_n_pw lfe"
// foreach conn of local conn_measures{	 
// foreach inter of local interactions{
// capture confirm variable `conn'_am_`inter'
// if _rc != 0 {
//     di as error "Variable `conn'_am_`inter' not found"
// }
// }
// }
