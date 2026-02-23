********************************************************************************
* BLOCK-LEVEL DiD DISTRIBUTION:   β_b from Y = α_i + τ_t + β_b*(Post × C) + ε
*   Block = industry1 × microregion × mode_base_month × mode_union
*   Outcome: lr_remdezr
*   "C"     : totaltreat_pw_n
********************************************************************************

* --- Load same sample as your event-study snippet
use "$rais_firm/lagos_sample_sep24.dta", clear
// use "$rais_firm/labor_analysis_sample_aug6.dta", clear
keep if lagos_sample_avg==1
gen placebo_year = (year<2011)
keep if year>=2009

* Precompute firm pre-emp (you already had this upstream; keep for reproducibility)
bys identificad: egen firm_emp_pre_o = mean(firm_emp) if year<=2011
bys identificad: egen firm_emp_pre   = min(firm_emp_pre_o)

* summay of firm_emp_pre:
cap drop med_firm_emp_pre
sum firm_emp_pre if year==2009 & treat_ultra==0 & in_balanced_panel==1, detail
gen med_firm_emp_pre = r(p50)
sum med_firm_emp_pre

* --- Analysis sample (same filters you used)
gen byte in_spill = (lagos_sample_avg==1 & in_balanced_panel==1 & treat_ultra==0 & firm_emp_pre>med_firm_emp_pre)

* --- Define blocks
egen long block = group(industry1 microregion mode_base_month mode_union) if in_spill

* --- Keep only blocks with actual identifying variation:
*     - must have both pre (year<=2011) and post (year>=2012)
*     - must have variation in treat_year (0 and 1) within the block
*     - must have variation in C (totaltreat_pw_n) within the block

reghdfe lr_remdezr c.totaltreat_pw_n##treat_year if in_spill==1, absorb (identificad treat_year industry1#treat_year microregion#treat_year mode_base_month#treat_year mode_union#treat_year) vce(cluster identificad)

preserve
keep if in_spill
bys block: egen pre_any  = max(year<=2011)
bys block: egen post_any = max(year>=2012)
bys block: egen ty_min   = min(treat_year)
bys block: egen ty_max   = max(treat_year)
bys block: egen c_sd     = sd(totaltreat_pf_n)
gen byte ok_block = (pre_any & post_any & ty_min==0 & ty_max==1 & c_sd>0)
keep block ok_block
duplicates drop
tempfile okblocks
save `okblocks'
restore

* --- Restrict to usable blocks
merge m:1 block using `okblocks', nogen
keep if ok_block==1 & in_spill==1


* Run the within-block DiD and collect coefficients
* - Absorb firm & year within each block (mirrors your pooled spec on those FEs)
* - Cluster by firm; statsby will still run, but blocks with 1 cluster will yield missing SE/coef
tempfile bres
statsby ///
    b = _b[1.treat_year#c.totaltreat_pw_n] ///
    se = _se[1.treat_year#c.totaltreat_pw_n] ///
    N = e(N), ///
    by(block) saving(`bres', replace): ///
    reghdfe lr_remdezr c.totaltreat_pw_n##treat_year ///
        if ok_block==1 & in_spill==1, ///
        absorb(identificad year) vce(cluster identificad)

* Load results, drop failed blocks (missing b)
use `bres', clear
drop if missing(b)

* Quick diagnostics
count
di as text "Estimated block-level slopes for " r(N) " blocks."

* Plot distribution (hist + kernel)
twoway (histogram b, fraction bin(100)) ///
       (kdensity  b), ///
       title("Distribution of Block DiD Slopes: Post × totaltreat_pw_n") ///
       ytitle("Fraction of blocks") xtitle("β_b") ///
       xline(0, lpattern(dash)) legend(off) graphregion(color(white)) bgcolor(white)
	   
graph export "$graphs/block_DiD_dist_lr_remdezr.png", as(png) replace

sum b
* --- Optional: label a few extremes for inspection
sort b
list block b se N in 1/10, abbrev(20)
gsort -b
list block b se N in 1/10, abbrev(20)

* --- Optional: weighted by precision (1/se^2) or sample size
gen w_N   = N
gen w_iv  = 1/(se^2) if se>0

* Precision-weighted mean of block β_b (should be close to your pooled β)
summ b [aw=w_iv]
di as res "Precision-weighted mean β_b = " %9.4f r(mean)

* Save table for later
save "$rais_aux/block_did_lr_remdezr.dta", replace
