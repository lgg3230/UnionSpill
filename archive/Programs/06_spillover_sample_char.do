********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: SPILLOVER EFFECTS ESTIMATES ON WAGES/EMPLOYMENT, WITH CONNECTIVITY MEASURED AS FLOW COUNTS (ROUGH MEASURE)
* INPUT: MERGED CBA RAIS, WITH CONNECTIVITY MEASURES
* OUTPUT:TWFE ESTIMATES FOR ROUGHT SPILLOVER EFFECTS 
********************************************************************************

use "$rais_firm/cba_rais_firm_2009_2016.dta",clear 

keep if year==2009 // 2.8 M estabs remaining

keep if in_balanced_panel==1 // 1.4 M estabs remaining

////////////////////////////////////////////////////////////////////////////////
// computing group sizes

count if lagos_sample==1 // 16,365 estabs

count if treat_ultra==1 // 31,756 estabs

count if top10_linklagos_pw==1 // 181,638 estabs (!)

count if top10_linklagos_pw==1 & lagos_sample==1 & treat_ultra==1 // 9,829 estabs

count if top10_linklagos_pw==1 & lagos_sample==1 & treat_ultra==0 // 3,093 estabs

count if top10_linklagos_pw==1 & lagos_sample==0 & treat_ultra==1 // 8,577 estabs

count if top10_linklagos_pw==0 & lagos_sample==1 & treat_ultra==1 // 2,373 estabs

////////////////////////////////////////////////////////////////////////////////
// among those with high connectivity, see if there is any concentration of high
// connectivity to treatment too much in the treatment groups
// how much of the high treat connectivity are in and out of the treated group?

count if missing(totaltreat_pw) & top10_linklagos_pw==1


preserve
keep if top10_linklagos_pw==1
count
qui sum totaltreat_pw, detail
scalar med_treat_pw = r(p50)
gen high_med_treat_pw = cond(totaltreat_pw>= med_treat_pw,1,0)
tab high_med_treat_pw treat_ultra

restore



