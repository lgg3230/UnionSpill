********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR:  LUIS GOMES
* PROGRAM: Regressions to test which specs would transform the selection on avg_flowtreat_pf 
*          into heterogeneity
* INPUT:   FLOWS DATASET, RESTRICTED TO LAGOS SAMPLE
* OUTPUT:  Regression tables testing different spces on turnover, totalflows, employment.	 
********************************************************************************

use "$rais_firm/cba_rais_firm_2009_2016_flows_1.dta", clear

keep if lagos_sample_avg==1

gen placebo_year = cond(year<2011, 1,0)


local outcomes "l_firm_emp lr_remdezr lr_remmedr"
local conn_measures "totaltreat_pw_n avg_ftreat_pf_n"

********************************************************************************
// HETEROGENEITY WITH SEPARATING LOW AND HIGH FLOWS AND INITIAL EMPLOYMENT
********************************************************************************	

********************************************************************************
// FLOWS
********************************************************************************

********************************************************************************
// with mode union
********************************************************************************

foreach outcome of local outcomes{
	eststo clear
	local m = 1
foreach conn of local conn_measures{
	
	// High flows (>8)
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & totalflows_n>8 & !missing(totalflows_n), ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year mode_union#treat_year l_firm_emp_2009_5#treat_year) ///
                vce(cluster identificad)
	local ++m	
	
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & totalflows_n>8 & !missing(totalflows_n) & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year mode_union#placebo_year l_firm_emp_2009_5#placebo_year) ///
                vce(cluster identificad)
	local ++m
	
	// Low flows (<=8)
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & totalflows_n<=8 & !missing(totalflows_n), ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year mode_union#treat_year l_firm_emp_2009_5#treat_year) ///
                vce(cluster identificad)
	local ++m	
	
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & totalflows_n<=8 & !missing(totalflows_n) & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year mode_union#placebo_year l_firm_emp_2009_5#placebo_year) ///
                vce(cluster identificad)
	local ++m
	
	// High flows (>26)
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & totalflows_n>26 & !missing(totalflows_n), ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year mode_union#treat_year l_firm_emp_2009_5#treat_year) ///
                vce(cluster identificad)
	local ++m	
	
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & totalflows_n>26 & !missing(totalflows_n) & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year mode_union#placebo_year l_firm_emp_2009_5#placebo_year) ///
                vce(cluster identificad)
	local ++m
	
	// Low flows (<=26)
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & totalflows_n<=26 & !missing(totalflows_n), ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year mode_union#treat_year l_firm_emp_2009_5#treat_year) ///
                vce(cluster identificad)
	local ++m	
	
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & totalflows_n<=26 & !missing(totalflows_n) & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year mode_union#placebo_year l_firm_emp_2009_5#placebo_year) ///
                vce(cluster identificad)
	local ++m
	
	}
	
esttab m* using "$tables/jul31_ymu_flowsample_`outcome'.csv", ///
keep(*#*c.totaltreat_pw_n *#*c.avg_ftreat_pf_n ) ///
se star(* 0.10 ** 0.05 *** 0.01) b(3) se(3) replace

}

********************************************************************************
// without mode union
********************************************************************************

foreach outcome of local outcomes{
	eststo clear
	local m = 1
foreach conn of local conn_measures{
	
	// High flows (>8)
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & totalflows_n>8 & !missing(totalflows_n), ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year l_firm_emp_2009_5#treat_year) ///
                vce(cluster identificad)
	local ++m	
	
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & totalflows_n>8 & !missing(totalflows_n) & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year l_firm_emp_2009_5#placebo_year) ///
                vce(cluster identificad)
	local ++m
	
	// Low flows (<=8)
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & totalflows_n<=8 & !missing(totalflows_n), ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year l_firm_emp_2009_5#treat_year) ///
                vce(cluster identificad)
	local ++m	
	
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & totalflows_n<=8 & !missing(totalflows_n) & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year l_firm_emp_2009_5#placebo_year) ///
                vce(cluster identificad)
	local ++m
	
	// High flows (>26)
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & totalflows_n>26 & !missing(totalflows_n), ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year l_firm_emp_2009_5#treat_year) ///
                vce(cluster identificad)
	local ++m	
	
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & totalflows_n>26 & !missing(totalflows_n) & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year l_firm_emp_2009_5#placebo_year) ///
                vce(cluster identificad)
	local ++m
	
	// Low flows (<=26)
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & totalflows_n<=26 & !missing(totalflows_n), ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year l_firm_emp_2009_5#treat_year) ///
                vce(cluster identificad)
	local ++m	
	
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & totalflows_n<=26 & !missing(totalflows_n) & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year l_firm_emp_2009_5#placebo_year) ///
                vce(cluster identificad)
	local ++m
	
	}
	
esttab m* using "$tables/jul31_nmu_flowsample_`outcome'.csv", ///
keep(*#*c.totaltreat_pw_n *#*c.avg_ftreat_pf_n ) ///
se star(* 0.10 ** 0.05 *** 0.01) b(3) se(3) replace	

}

********************************************************************************
// EMPLOYMENT
********************************************************************************

********************************************************************************
// with mode union
********************************************************************************

foreach outcome of local outcomes{
	eststo clear
	local m = 1
foreach conn of local conn_measures{
	
	// High employment (>10) - with totalflows control
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_2009>10 & !missing(firm_emp), ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year mode_union#treat_year totalflows_n_2009_5#treat_year) ///
                vce(cluster identificad)
	local ++m	
	
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_2009>10 & !missing(firm_emp) & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year mode_union#placebo_year totalflows_n_2009_5#placebo_year) ///
                vce(cluster identificad)
	local ++m
	
	// High employment (>10) - without totalflows control
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_2009>10 & !missing(firm_emp), ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year mode_union#treat_year) ///
                vce(cluster identificad)
	local ++m	
	
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_2009>10 & !missing(firm_emp) & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year mode_union#placebo_year) ///
                vce(cluster identificad)
	local ++m
	
	// Low employment (<=10) - with totalflows control
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_2009<=10 & !missing(firm_emp), ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year mode_union#treat_year totalflows_n_2009_5#treat_year) ///
                vce(cluster identificad)
	local ++m	
	
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_2009<=10 & !missing(firm_emp) & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year mode_union#placebo_year totalflows_n_2009_5#placebo_year) ///
                vce(cluster identificad)
	local ++m
	
	// Low employment (<=10) - without totalflows control
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_2009<=10 & !missing(firm_emp), ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year mode_union#treat_year) ///
                vce(cluster identificad)
	local ++m	
	
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_2009<=10 & !missing(firm_emp) & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year mode_union#placebo_year) ///
                vce(cluster identificad)
	local ++m
	
	// High employment (>25) - with totalflows control
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_2009>25 & !missing(firm_emp), ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year mode_union#treat_year totalflows_n_2009_5#treat_year) ///
                vce(cluster identificad)
	local ++m	
	
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_2009>25 & !missing(firm_emp) & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year mode_union#placebo_year totalflows_n_2009_5#placebo_year) ///
                vce(cluster identificad)
	local ++m
	
	// High employment (>25) - without totalflows control
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_2009>25 & !missing(firm_emp), ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year mode_union#treat_year) ///
                vce(cluster identificad)
	local ++m	
	
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_2009>25 & !missing(firm_emp) & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year mode_union#placebo_year) ///
                vce(cluster identificad)
	local ++m
	
	// Low employment (<=25) - with totalflows control
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_2009<=25 & !missing(firm_emp), ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year mode_union#treat_year totalflows_n_2009_5#treat_year) ///
                vce(cluster identificad)
	local ++m	
	
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_2009<=25 & !missing(firm_emp) & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year mode_union#placebo_year totalflows_n_2009_5#placebo_year) ///
                vce(cluster identificad)
	local ++m
	
	// Low employment (<=25) - without totalflows control
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_2009<=25 & !missing(firm_emp), ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year mode_union#treat_year) ///
                vce(cluster identificad)
	local ++m	
	
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_2009<=25 & !missing(firm_emp) & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year mode_union#placebo_year) ///
                vce(cluster identificad)
	local ++m
	
	}
	
esttab m* using "$tables/jul31_ymu_empsample_`outcome'.csv", ///
keep(*#*c.totaltreat_pw_n *#*c.avg_ftreat_pf_n ) ///
se star(* 0.10 ** 0.05 *** 0.01) b(3) se(3) replace

}

********************************************************************************
// without mode union
********************************************************************************

foreach outcome of local outcomes{
	eststo clear
	local m = 1
foreach conn of local conn_measures{
	
	// High employment (>10) - with totalflows control
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_2009>10 & !missing(firm_emp), ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year totalflows_n_2009_5#treat_year) ///
                vce(cluster identificad)
	local ++m	
	
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_2009>10 & !missing(firm_emp) & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year totalflows_n_2009_5#placebo_year) ///
                vce(cluster identificad)
	local ++m
	
	// High employment (>10) - without totalflows control
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_2009>10 & !missing(firm_emp), ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year) ///
                vce(cluster identificad)
	local ++m	
	
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_2009>10 & !missing(firm_emp) & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year) ///
                vce(cluster identificad)
	local ++m
	
	// Low employment (<=10) - with totalflows control
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_2009<=10 & !missing(firm_emp), ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year totalflows_n_2009_5#treat_year) ///
                vce(cluster identificad)
	local ++m	
	
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_2009<=10 & !missing(firm_emp) & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year totalflows_n_2009_5#placebo_year) ///
                vce(cluster identificad)
	local ++m
	
	// Low employment (<=10) - without totalflows control
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_2009<=10 & !missing(firm_emp), ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year) ///
                vce(cluster identificad)
	local ++m	
	
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_2009<=10 & !missing(firm_emp) & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year) ///
                vce(cluster identificad)
	local ++m
	
	// High employment (>25) - with totalflows control
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_2009>25 & !missing(firm_emp), ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year totalflows_n_2009_5#treat_year) ///
                vce(cluster identificad)
	local ++m	
	
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_2009>25 & !missing(firm_emp) & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year totalflows_n_2009_5#placebo_year) ///
                vce(cluster identificad)
	local ++m
	
	// High employment (>25) - without totalflows control
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_2009>25 & !missing(firm_emp), ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year) ///
                vce(cluster identificad)
	local ++m	
	
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_2009>25 & !missing(firm_emp) & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year) ///
                vce(cluster identificad)
	local ++m
	
	// Low employment (<=25) - with totalflows control
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_2009<=25 & !missing(firm_emp), ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year totalflows_n_2009_5#treat_year) ///
                vce(cluster identificad)
	local ++m	
	
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_2009<=25 & !missing(firm_emp) & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year totalflows_n_2009_5#placebo_year) ///
                vce(cluster identificad)
	local ++m
	
	// Low employment (<=25) - without totalflows control
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_2009<=25 & !missing(firm_emp), ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year) ///
                vce(cluster identificad)
	local ++m	
	
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year if lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_2009<=25 & !missing(firm_emp) & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year) ///
                vce(cluster identificad)
	local ++m
	
	}
	
esttab m* using "$tables/jul31_nmu_empsample_`outcome'.csv", ///
keep(*#*c.totaltreat_pw_n *#*c.avg_ftreat_pf_n ) ///
se star(* 0.10 ** 0.05 *** 0.01) b(3) se(3) replace	

}

********************************************************************************
// how does connectivity relates to above below median employemnt and totalflows?
********************************************************************************

gen am_totalflows_n  = cond(totalflows_n>26 & !missing(totalflows_n), 1,0)
gen am_firmemp_2009 = cond(firm_emp_2009>25 & !missing(firm_emp_2009),1,0)

gen mode_union_int = mode_union
recast float mode_union_int, force
replace mode_union_int = floor(mode_union_int)

gen mode_union_str = string(mode_union_int, "%12.0f")
destring mode_union_str, gen(mode_union_clean) force
drop mode_union_int
rename mode_union_clean mode_union_int

drop mode_union_int
egen mode_union_int = group(mode_union)


foreach conn in totaltreat_pw_n avg_ftreat_pf_n{
	foreach sel in am_totalflows_n am_firmemp_2009{
 	reg `conn'  `sel' i.industry1 i.mode_base_month  i.microregion i.mode_union_int if treat_ultra==0 & lagos_sample_avg==1 & year==2009, rob 
 }
}


eststo clear
local m = 1
foreach conn in totaltreat_pw_n avg_ftreat_pf_n{
    foreach sel in am_totalflows_n am_firmemp_2009{
        eststo m`m': qui reg `conn' `sel' i.industry1 i.mode_base_month i.microregion i.mode_union_int if treat_ultra==0 & lagos_sample_avg==1 & year==2009, rob 
        local ++m
    }
}
esttab, keep(am_totalflows_n am_firmemp_2009) se star(* 0.10 ** 0.05 *** 0.01)

********************************************************************************
// HETEROGENEITY INTERACTION TERMS
********************************************************************************


local outcomes "l_firm_emp lr_remdezr lr_remmedr"
local conn_measures "totaltreat_pw_n avg_ftreat_pf_n"
local interactions "am_tn_pre am_lfe am_tf_n"
local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0"

********************************************************************************
// INTERACTION HETEROGENEITY - ALL SPECIFICATIONS
********************************************************************************

foreach outcome of local outcomes{
foreach interaction of local interactions{
	
	eststo clear
	local m = 1
	
foreach conn of local conn_measures{
	
	// WITH MODE UNION
	// WITH TOTALFLOWS CONTROL
	// main DiD	
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year c.`conn'#`interaction'##treat_year if `s_spill', ///
	                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year firm_emp_2009_5#treat_year totalflows_n_2009_5#treat_year mode_union#treat_year) ///
	                vce(cluster identificad)
	local ++m
	
	// placebo 
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year c.`conn'#`interaction'##placebo_year if `s_spill' & year<=2011, ///
	                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year firm_emp_2009_5#treat_year totalflows_n_2009_5#placebo_year mode_union#treat_year) ///
	                vce(cluster identificad)
	local ++m
	
	//WITHOUT TOTALFLOWS CONTROL
	// main DiD	
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year c.`conn'#`interaction'##treat_year if `s_spill', ///
	                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year firm_emp_2009_5#treat_year mode_union#treat_year) ///
	                vce(cluster identificad)
	local ++m
	
	// placebo 
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year c.`conn'#`interaction'##placebo_year if `s_spill' & year<=2011, ///
	                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year firm_emp_2009_5#treat_year mode_union#treat_year) ///
	                vce(cluster identificad)
	local ++m
	
	// ONLY MODE UNION:
	// main DiD	
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year c.`conn'#`interaction'##treat_year if `s_spill', ///
	                absorb(identificad treat_year mode_union#treat_year) ///
	                vce(cluster identificad)
	local ++m
	
	// placebo 
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year c.`conn'#`interaction'##placebo_year if `s_spill' & year<=2011, ///
	                absorb(identificad placebo_year mode_union#treat_year) ///
	                vce(cluster identificad)
	local ++m
	
	// ONLY MODE UNION + LAGGED CONTROLS:
	// main DiD	
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year c.`conn'#`interaction'##treat_year if `s_spill', ///
	                absorb(identificad treat_year firm_emp_2009#treat_year totalflows_n_2009#treat_year mode_union#treat_year) ///
	                vce(cluster identificad)
	local ++m
	
	// placebo 
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year c.`conn'#`interaction'##placebo_year if `s_spill' & year<=2011, ///
	                absorb(identificad placebo_year firm_emp_2009#placebo_year totalflows_n_2009#placebo_year mode_union#treat_year) ///
	                vce(cluster identificad)
	local ++m
	
	// WITHOUT MODE UNION		
	// main DiD	
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year c.`conn'#`interaction'##treat_year if `s_spill', ///
	                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year firm_emp_2009_5#treat_year totalflows_n_2009_5#treat_year) ///
	                vce(cluster identificad)
	local ++m
	
	// placebo 
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year c.`conn'#`interaction'##placebo_year if `s_spill' & year<=2011, ///
	                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year firm_emp_2009_5#treat_year totalflows_n_2009_5#placebo_year) ///
	                vce(cluster identificad)
	local ++m
	
	// main DiD	
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year c.`conn'#`interaction'##treat_year if `s_spill', ///
	                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year firm_emp_2009_5#treat_year) ///
	                vce(cluster identificad)
	local ++m
	
	// placebo 
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year c.`conn'#`interaction'##placebo_year if `s_spill' & year<=2011, ///
	                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year firm_emp_2009_5#treat_year) ///
	                vce(cluster identificad)
	local ++m
	
	}
	
	// SAVE TABLE FOR THIS OUTCOME-INTERACTION COMBINATION
	esttab m* using "$tables/jul31_heterogeneity_`outcome'_`interaction'.csv", ///
	keep(*#*c.totaltreat_pw_n *#*c.avg_ftreat_pf_n) ///
	se star(* 0.10 ** 0.05 *** 0.01) b(3) se(3) replace

}
}



********************************************************************************
// Testing whether above below hiring makes a difference in heterogeneous effects
********************************************************************************




local outcomes "l_firm_emp lr_remdezr lr_remmedr"
local conn_measures "totaltreat_pw_n avg_ftreat_pf_n"
local interactions "am_hire_2009"
local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0"

********************************************************************************
// INTERACTION HETEROGENEITY - ALL SPECIFICATIONS
********************************************************************************

foreach outcome of local outcomes{
foreach interaction of local interactions{
	
	eststo clear
	local m = 1
	
foreach conn of local conn_measures{
	
	// WITH MODE UNION
	// WITH TOTALFLOWS CONTROL
	// main DiD	
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year c.`conn'#`interaction'##treat_year if `s_spill', ///
	                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year firm_emp_2009_5#treat_year totalflows_n_2009_5#treat_year mode_union#treat_year) ///
	                vce(cluster identificad)
	local ++m
	
	// placebo 
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year c.`conn'#`interaction'##placebo_year if `s_spill' & year<=2011, ///
	                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year firm_emp_2009_5#treat_year totalflows_n_2009_5#placebo_year mode_union#treat_year) ///
	                vce(cluster identificad)
	local ++m
	
	//WITHOUT TOTALFLOWS CONTROL
	// main DiD	
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year c.`conn'#`interaction'##treat_year if `s_spill', ///
	                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year firm_emp_2009_5#treat_year mode_union#treat_year) ///
	                vce(cluster identificad)
	local ++m
	
	// placebo 
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year c.`conn'#`interaction'##placebo_year if `s_spill' & year<=2011, ///
	                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year firm_emp_2009_5#treat_year mode_union#treat_year) ///
	                vce(cluster identificad)
	local ++m
	
	// ONLY MODE UNION:
	// main DiD	
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year c.`conn'#`interaction'##treat_year if `s_spill', ///
	                absorb(identificad treat_year mode_union#treat_year) ///
	                vce(cluster identificad)
	local ++m
	
	// placebo 
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year c.`conn'#`interaction'##placebo_year if `s_spill' & year<=2011, ///
	                absorb(identificad placebo_year mode_union#treat_year) ///
	                vce(cluster identificad)
	local ++m
	
	// ONLY MODE UNION + LAGGED CONTROLS:
	// main DiD	
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year c.`conn'#`interaction'##treat_year if `s_spill', ///
	                absorb(identificad treat_year firm_emp_2009#treat_year totalflows_n_2009#treat_year mode_union#treat_year) ///
	                vce(cluster identificad)
	local ++m
	
	// placebo 
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year c.`conn'#`interaction'##placebo_year if `s_spill' & year<=2011, ///
	                absorb(identificad placebo_year firm_emp_2009#placebo_year totalflows_n_2009#placebo_year mode_union#treat_year) ///
	                vce(cluster identificad)
	local ++m
	
	// WITHOUT MODE UNION		
	// main DiD	
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year c.`conn'#`interaction'##treat_year if `s_spill', ///
	                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year firm_emp_2009_5#treat_year totalflows_n_2009_5#treat_year) ///
	                vce(cluster identificad)
	local ++m
	
	// placebo 
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year c.`conn'#`interaction'##placebo_year if `s_spill' & year<=2011, ///
	                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year firm_emp_2009_5#treat_year totalflows_n_2009_5#placebo_year) ///
	                vce(cluster identificad)
	local ++m
	
	// main DiD	
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year c.`conn'#`interaction'##treat_year if `s_spill', ///
	                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year firm_emp_2009_5#treat_year) ///
	                vce(cluster identificad)
	local ++m
	
	// placebo 
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year c.`conn'#`interaction'##placebo_year if `s_spill' & year<=2011, ///
	                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year firm_emp_2009_5#treat_year) ///
	                vce(cluster identificad)
	local ++m
	
	}
	
	// SAVE TABLE FOR THIS OUTCOME-INTERACTION COMBINATION
	esttab m* using "$tables/jul31_heterogeneity_`outcome'_`interaction'.csv", ///
	keep(*#*c.totaltreat_pw_n *#*c.avg_ftreat_pf_n) ///
	se star(* 0.10 ** 0.05 *** 0.01) b(3) se(3) replace

}
}


local interactions "am_tn_pre  am_lfe am_tf_n "
local outcomes "l_firm_emp lr_remdezr lr_remmedr"
local conn_measures "totaltreat_pw_n avg_ftreat_pf_n"


local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "

foreach outcome of local outcomes {
    foreach interaction of local interactions {
        foreach conn of local conn_measures {
            
            eststo clear
            
            // WITH MODE UNION - WITH TOTALFLOWS CONTROL
            eststo reg1: reghdfe `outcome' c.`conn'##treat_year c.`conn'#`interaction'##treat_year if `s_spill', ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year firm_emp_2009_5#treat_year totalflows_n_2009_5#treat_year mode_union#treat_year) ///
                vce(cluster identificad)
           
            // WITH MODE UNION - WITHOUT TOTALFLOWS CONTROL  
            eststo reg2: reghdfe `outcome' c.`conn'##treat_year c.`conn'#`interaction'##treat_year if `s_spill', ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year firm_emp_2009_5#treat_year mode_union#treat_year) ///
                vce(cluster identificad)
           
            // ONLY MODE UNION
            eststo reg3: reghdfe `outcome' c.`conn'##treat_year c.`conn'#`interaction'##treat_year if `s_spill', ///
                absorb(identificad treat_year mode_union#treat_year) ///
                vce(cluster identificad)
           
            // ONLY MODE UNION + LAGGED CONTROLS
            eststo reg4: reghdfe `outcome' c.`conn'##treat_year c.`conn'#`interaction'##treat_year if `s_spill', ///
                absorb(identificad treat_year firm_emp_2009#treat_year totalflows_n_2009#treat_year mode_union#treat_year) ///
                vce(cluster identificad)
           
            // WITHOUT MODE UNION - WITH TOTALFLOWS CONTROL
            eststo reg5: reghdfe `outcome' c.`conn'##treat_year c.`conn'#`interaction'##treat_year if `s_spill', ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year firm_emp_2009_5#treat_year totalflows_n_2009_5#treat_year) ///
                vce(cluster identificad)
           
            // WITHOUT MODE UNION - WITHOUT TOTALFLOWS CONTROL
            eststo reg6: reghdfe `outcome' c.`conn'##treat_year c.`conn'#`interaction'##treat_year if `s_spill', ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year firm_emp_2009_5#treat_year) ///
                vce(cluster identificad)
           
// 	    // MAIN EFFECTS TABLE
            esttab reg* using "$tables/jul31_`outcome'_`interaction'_`conn'_main.csv", ///
                keep(1.*#c.`conn' 1.*#1.*#c.`conn') ///
                se star(* 0.10 ** 0.05 *** 0.01) b(3) se(3) replace
          
            // Now run placebo regressions
            eststo clear
           
            // Placebo regressions (same order as main)
            eststo preg1: reghdfe `outcome' c.`conn'##placebo_year c.`conn'#`interaction'##placebo_year if `s_spill' & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year firm_emp_2009_5#treat_year totalflows_n_2009_5#placebo_year mode_union#treat_year) ///
                vce(cluster identificad)
           
            eststo preg2: reghdfe `outcome' c.`conn'##placebo_year c.`conn'#`interaction'##placebo_year if `s_spill' & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year firm_emp_2009_5#treat_year mode_union#treat_year) ///
                vce(cluster identificad)
           
            eststo preg3: reghdfe `outcome' c.`conn'##placebo_year c.`conn'#`interaction'##placebo_year if `s_spill' & year<=2011, ///
                absorb(identificad placebo_year mode_union#treat_year) ///
                vce(cluster identificad)
           
            eststo preg4: reghdfe `outcome' c.`conn'##placebo_year c.`conn'#`interaction'##placebo_year if `s_spill' & year<=2011, ///
                absorb(identificad placebo_year firm_emp_2009#placebo_year totalflows_n_2009#placebo_year mode_union#treat_year) ///
                vce(cluster identificad)
           
            eststo preg5: reghdfe `outcome' c.`conn'##placebo_year c.`conn'#`interaction'##placebo_year if `s_spill' & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year firm_emp_2009_5#treat_year totalflows_n_2009_5#placebo_year) ///
                vce(cluster identificad)
           
            eststo preg6: reghdfe `outcome' c.`conn'##placebo_year c.`conn'#`interaction'##placebo_year if `s_spill' & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year firm_emp_2009_5#treat_year) ///
                vce(cluster identificad)
          
            // PLACEBO EFFECTS TABLE
	    esttab preg* using "$tables/jul31_`outcome'_`interaction'_`conn'_placebo.csv", ///
                keep(*#*c.`conn') ///
                se star(* 0.10 ** 0.05 *** 0.01) b(3) se(3) replace
	    
        }
    }
}






// mode union is a good summary measure of the other fixed effects

local s_direct "lagos_sample_avg==1 & in_balanced_panel==1"	
local s_spill_emp_a25 "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_2009>10 & !missing(firm_emp)"
local s_spill_emp_b25 "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_2009<=10 & !missing(firm_emp)"
local s_spill_emp_a50 "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_2009>25 & !missing(firm_emp)"
local s_spill_emp_b50 "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_2009<=25 & !missing(firm_emp)"
	
	// main DiD	
		
	reghdfe l_firm_emp c.avg_ftreat_pf_n##treat_year c.avg_ftreat_pf_n#am_tf_n##treat_ultra if `s_spill', ///
                absorb(identificad treat_year mode_union#treat_year) ///
                vce(cluster identificad)
		
	// placebo 
	reghdfe l_firm_emp treat_ultra##placebo_year if `s_direct' & year<=2011, ///
                absorb(identificad placebo_year mode_union#placebo_year) ///
                vce(cluster identificad)

		
********************************************************************************
********************************************************************************		
********************************************************************************
********************************************************************************		
********************************************************************************
********************************************************************************		
	
// REFERENCE:


local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "
local interactions "am_tn_pre am_lfe am_tf_n"




// WITH MODE UNION

// WITH TOTALFLOWS CONTROL

// main DiD	
reghdfe `outcome' c.`conn'##treat_year c.`conn'#`interaction'##treat_year if `s_spill', ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year firm_emp_2009_5#treat_year totalflows_n_2009_5#treat_year mode_union#treat_year) ///
                vce(cluster identificad)

// placebo 
reghdfe `outcome' c.`conn'##placebo_year c.`conn'#`interaction'##placebo_year if `s_spill' & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year  firm_emp_2009_5#treat_year totalflows_n_2009_5#placebo_year mode_union#treat_year) ///
                vce(cluster identificad)

//WITHOUT TOTALFLOWS CONTROL
		
// main DiD	
reghdfe `outcome' c.`conn'##treat_year c.`conn'#`interaction'##treat_year if `s_spill', ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year firm_emp_2009_5#treat_year mode_union#treat_year) ///
                vce(cluster identificad)

// placebo 
reghdfe `outcome' c.`conn'##placebo_year c.`conn'#`interaction'##placebo_year if `s_spill' & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year  firm_emp_2009_5#treat_year mode_union#treat_year) ///
                vce(cluster identificad)
		
// ONLY MODE UNION:


// main DiD	
reghdfe `outcome' c.`conn'##treat_year c.`conn'#`interaction'##treat_year if `s_spill', ///
                absorb(identificad treat_year  mode_union#treat_year) ///
                vce(cluster identificad)

// placebo 
reghdfe `outcome' c.`conn'##placebo_year c.`conn'#`interaction'##placebo_year if `s_spill' & year<=2011, ///
                absorb(identificad placebo_year  mode_union#treat_year) ///
                vce(cluster identificad)
		
		
// ONLY MODE UNION + LAGGED CONTROLS:



// main DiD	
reghdfe `outcome' c.`conn'##treat_year c.`conn'#`interaction'##treat_year if `s_spill', ///
                absorb(identificad treat_year firm_emp_2009#treat_year totalflows_n_2009#treat_year mode_union#treat_year) ///
                vce(cluster identificad)

// placebo 
reghdfe `outcome' c.`conn'##placebo_year c.`conn'#`interaction'##placebo_year if `s_spill' & year<=2011, ///
                absorb(identificad placebo_year firm_emp_2009#placebo_year totalflows_n_2009#placebo_year mode_union#treat_year) ///
                vce(cluster identificad)	
		

// WITHOUT MODE UNION		
		
// main DiD	
reghdfe `outcome' c.`conn'##treat_year c.`conn'#`interaction'##treat_year if `s_spill', ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year firm_emp_2009_5#treat_year totalflows_n_2009_5#treat_year) ///
                vce(cluster identificad)

// placebo 
reghdfe `outcome' c.`conn'##placebo_year c.`conn'#`interaction'##placebo_year if `s_spill' & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year  firm_emp_2009_5#treat_year totalflows_n_2009_5#placebo_year) ///
                vce(cluster identificad)

		
// main DiD	
reghdfe `outcome' c.`conn'##treat_year c.`conn'#`interaction'##treat_year if `s_spill', ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year firm_emp_2009_5#treat_year ) ///
                vce(cluster identificad)

// placebo 
reghdfe `outcome' c.`conn'##placebo_year c.`conn'#`interaction'##placebo_year if `s_spill' & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year  firm_emp_2009_5#treat_year) ///
                vce(cluster identificad)	
		
		
		
		
		
		
	
	local outcomes "lr_remmedr lr_remdezr lr_remmedr"
	local conn_measures "totaltreat_pw_n avg_ftreat_pf_n"

********************************************************************************
// HETEROGENEITY WITH SEPARATING LOW AND HIGH FLOWS AND INITIAL EMPLOYMENT
********************************************************************************	

********************************************************************************
// FLOWS
********************************************************************************
	
	local s_spill_flow_a25 "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & totalflows_n>8 & !missing(totalflows_n)"
	local s_spill_flow_b25 "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & totalflows_n<=8 & !missing(totalflows_n)"
	local s_spill_flow_a50 "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & totalflows_n>26 & !missing(totalflows_n)"
	local s_spill_flow_b50 "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & totalflows_n<=26 & !missing(totalflows_n)"
	
	

********************************************************************************
// with mode union
********************************************************************************

	// main Did	
foreach outcome of local outcomes{
	eststo clear
	local m = 1
foreach conn of local conn_measures{
	foreach flow_sample in s_spill_flow_a25 s_spill_flow_b25 s_spill_flow_a50 s_spill_flow_b50 {
	
	// DiD Estimation
	
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year if `flow_sample', ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year mode_union#treat_year l_firm_emp_2009_5#treat_year) ///
                vce(cluster identificad)
	local ++m	
	
	
	// placebo:
	
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year if `flow_sample' & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year mode_union#placebo_year l_firm_emp_2009_5#placebo_year) ///
                vce(cluster identificad)
	local ++m		
	
	}
	
esttab m* using "$tables/jul31_ymu_flowsample_`outcome'.csv", ///
keep(*#*c.totaltreat_pw_n *#*c.avg_ftreat_pf_n ) ///
se star(* 0.10 ** 0.05 *** 0.01) b(3) se(3) replace

}
}
		
********************************************************************************
// without mode union
********************************************************************************

foreach outcome of local outcomes{
	eststo clear
	local m = 1
foreach conn of local conn_measures{
	
	foreach flow_sample in s_spill_flow_a25 s_spill_flow_b25 s_spill_flow_a50 s_spill_flow_b50 {
	
	// DiD Estimation
	
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year if `flow_sample', ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year l_firm_emp_2009_5#treat_year) ///
                vce(cluster identificad)
	local ++m	
	
	
	// placebo:
	
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year if `flow_sample' & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year l_firm_emp_2009_5#placebo_year) ///
                vce(cluster identificad)
	local ++m		
	
	}
	
esttab m* using "$tables/jul31_nmu_flowsample_`outcome'.csv", ///
keep(*#*c.totaltreat_pw_n *#*c.avg_ftreat_pf_n ) ///
se star(* 0.10 ** 0.05 *** 0.01) b(3) se(3) replace	
	
}	
}	
	

	
********************************************************************************
// EMPLOYMENT
********************************************************************************
	
local s_spill_emp_a25 "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_2009>10 & !missing(firm_emp)"
local s_spill_emp_b25 "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_2009<=10 & !missing(firm_emp)"
local s_spill_emp_a50 "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_2009>25 & !missing(firm_emp)"
local s_spill_emp_b50 "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_2009<=25 & !missing(firm_emp)"
	
	
********************************************************************************
// with mode union
********************************************************************************
	// main Did	
foreach outcome of local outcomes{
	eststo clear
	local m = 1
foreach conn of local conn_measures{
	foreach emp_sample in s_spill_emp_a25 s_spill_emp_b25 s_spill_emp_a50 s_spill_emp_b50 {
	
	// DiD Estimation
	
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year if `emp_sample', ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year mode_union#treat_year totalflows_n#treat_year) ///
                vce(cluster identificad)
	local ++m	
	
	
	// placebo:
	
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year if `emp_sample' & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year mode_union#placebo_year totalflows_n#placebo_year) ///
                vce(cluster identificad)
	local ++m		
	
	}
	
esttab m* using "$tables/jul31_ymu_empsample_`outcome'.csv", ///
keep(*#*c.totaltreat_pw_n *#*c.avg_ftreat_pf_n ) ///
se star(* 0.10 ** 0.05 *** 0.01) b(3) se(3) replace
}
}
		
********************************************************************************
// without mode union
********************************************************************************
foreach outcome of local outcomes{
	eststo clear
	local m = 1
foreach conn of local conn_measures{
	
	foreach emp_sample in s_spill_emp_a25 s_spill_emp_b25 s_spill_emp_a50 s_spill_emp_b50 {
	
	// full set of controls:
	
	// DiD Estimation
	
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year if `emp_sample', ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year totalflows_n#treat_year) ///
                vce(cluster identificad)
	local ++m	
	
	
	// placebo:
	
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year if `emp_sample' & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year totalflows_n#placebo_year) ///
                vce(cluster identificad)
	local ++m
	
	// not using totalflows_n:
	
	// DiD Estimation 
	
	eststo m`m':reghdfe `outcome' c.`conn'##treat_year if `emp_sample', ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year ) ///
                vce(cluster identificad)
	local ++m	
	
	
	// placebo:
	
	eststo m`m':reghdfe `outcome' c.`conn'##placebo_year if `emp_sample' & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year ) ///
                vce(cluster identificad)
	local ++m
	
	// not using standard:
	
	
	}
	
esttab m* using "$tables/jul31_nmu_empsample_`outcome'.csv", ///
keep(*#*c.totaltreat_pw_n *#*c.avg_ftreat_pf_n ) ///
se star(* 0.10 ** 0.05 *** 0.01) b(3) se(3) replace	
	
}	
}

		

		
// Interactions reference:



// WITH MODE UNION

// WITH TOTALFLOWS CONTROL

// main DiD	
reghdfe lr_remmedr c.avg_ftreat_pf_n##treat_year c.avg_ftreat_pf_n#am_tf_n##treat_year if `s_spill', ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year firm_emp_2009_5#treat_year totalflows_n_2009_5#treat_year mode_union#treat_year) ///
                vce(cluster identificad)

// placebo 
reghdfe lr_remmedr c.avg_ftreat_pf_n##placebo_year c.avg_ftreat_pf_n#am_tf_n##placebo_year if `s_spill' & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year  firm_emp_2009_5#treat_year totalflows_n_2009_5#placebo_year mode_union#treat_year) ///
                vce(cluster identificad)

//WITHOUT TOTALFLOWS CONTROL
		
// main DiD	
reghdfe lr_remmedr c.avg_ftreat_pf_n##treat_year c.avg_ftreat_pf_n#am_tf_n##treat_year if `s_spill', ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year firm_emp_2009_5#treat_year mode_union#treat_year) ///
                vce(cluster identificad)

// placebo 
reghdfe lr_remmedr c.avg_ftreat_pf_n##placebo_year c.avg_ftreat_pf_n#am_tf_n##placebo_year if `s_spill' & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year  firm_emp_2009_5#treat_year mode_union#treat_year) ///
                vce(cluster identificad)
		
// ONLY MODE UNION:


// main DiD	
reghdfe lr_remmedr c.avg_ftreat_pf_n##treat_year c.avg_ftreat_pf_n#am_tf_n##treat_year if `s_spill', ///
                absorb(identificad treat_year  mode_union#treat_year) ///
                vce(cluster identificad)

// placebo 
reghdfe lr_remmedr c.avg_ftreat_pf_n##placebo_year c.avg_ftreat_pf_n#am_tf_n##placebo_year if `s_spill' & year<=2011, ///
                absorb(identificad placebo_year  mode_union#treat_year) ///
                vce(cluster identificad)
		
		
// ONLY MODE UNION + LAGGED CONTROLS:


local s_spill "lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 "
local interactions "am_tn_pre am_lfe am_tf_n"
// main DiD	
reghdfe lr_remmedr c.avg_ftreat_pf_n##treat_year c.avg_ftreat_pf_n#am_tf_n##treat_year if `s_spill', ///
                absorb(identificad treat_year firm_emp_2009#treat_year totalflows_n_2009#treat_year mode_union#treat_year) ///
                vce(cluster identificad)

// placebo 
reghdfe lr_remmedr c.avg_ftreat_pf_n##placebo_year c.avg_ftreat_pf_n#am_tf_n##placebo_year if `s_spill' & year<=2011, ///
                absorb(identificad placebo_year firm_emp_2009#placebo_year totalflows_n_2009#placebo_year mode_union#treat_year) ///
                vce(cluster identificad)	
		

// WITHOUT MODE UNION		
		
// main DiD	
reghdfe lr_remmedr c.avg_ftreat_pf_n##treat_year c.avg_ftreat_pf_n#am_tf_n##treat_year if `s_spill', ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year firm_emp_2009_5#treat_year totalflows_n_2009_5#treat_year) ///
                vce(cluster identificad)

// placebo 
reghdfe lr_remmedr c.avg_ftreat_pf_n##placebo_year c.avg_ftreat_pf_n#am_tf_n##placebo_year if `s_spill' & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year  firm_emp_2009_5#treat_year totalflows_n_2009_5#placebo_year) ///
                vce(cluster identificad)

		
// main DiD	
reghdfe lr_remmedr c.avg_ftreat_pf_n##treat_year c.avg_ftreat_pf_n#am_tf_n##treat_year if `s_spill', ///
                absorb(identificad treat_year industry1#treat_year mode_base_month#treat_year microregion#treat_year firm_emp_2009_5#treat_year ) ///
                vce(cluster identificad)

// placebo 
reghdfe lr_remmedr c.avg_ftreat_pf_n##placebo_year c.avg_ftreat_pf_n#am_tf_n##placebo_year if `s_spill' & year<=2011, ///
                absorb(identificad placebo_year industry1#placebo_year mode_base_month#placebo_year microregion#placebo_year  firm_emp_2009_5#treat_year) ///
                vce(cluster identificad)	
		
	
	

