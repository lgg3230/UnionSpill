********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR:  LUIS GOMES
* PROGRAM: GET WAGE PERCENTILES AND MERGE BACK INTO FIRM LEVEL DATASET
* INPUTS: WORKER-LEVEL DATASET RESTRICTED TO LAGOS SAMPLE
* OUTPUTS: FIRM-LEVEL DATASET WITH WAGE PERCENTILES
********************************************************************************

use "$rais_firm/lagos_sample_workers.dta", clear

keep PIS cnpj_year identificad year lr_remdezr lr_remmedr r_remdezr_h  r_remmedr_h r_remdezr r_remmedr // added r_remdezr_h and r_remmedr_h, r_remdezr, r_remmedr

gen lr_remdezr_h = log(r_remdezr_h)
label var lr_remdezr_h "log real hourly december wages"

gen lr_remmedr_h  = log(r_remmedr_h)
label var lr_remmedr_h "log real hourly average wages"

*-----------------------------*
* Worker spell / firm history *
*-----------------------------*

sort identificad year lr_remdezr

sort PIS year

forvalues y = 2009/2016 {
    cap drop has_year_`y'
    gen has_year_`y' = 0
    
    bysort PIS: replace has_year_`y' = 1 if year == `y'
    
    cap drop present_in_`y'
    bysort PIS: egen present_in_`y' = max(has_year_`y')
}

order PIS year present_in_*

gen present_in_1114 = present_in_2011 * present_in_2012 * present_in_2013 * present_in_2014

destring PIS, generate(PIS_d)

forvalues t = 2009/2016 {
    cap drop firmy`t'
    cap drop firmy`t'_all
    bysort PIS: gen  firmy`t'     = identificad if year == `t'
    bysort PIS: egen firmy`t'_all = mode(firmy`t')
}

order PIS year identificad firmy*

sort PIS year 

cap drop non_switch_1114
gen non_switch_1114 = cond((firmy2011_all == firmy2012_all) ///
                        & (firmy2012_all == firmy2013_all)  ///
                        & (firmy2013_all == firmy2014_all)  ///
                        & !missing(firmy2011_all), 1, 0)

gen switchers_1112 = cond((firmy2012_all != firmy2013_all) & !missing(firmy2011_all), 1, 0)

*-----------------------------*
* Stayers vs. switchers means *
*-----------------------------*

bys cnpj_year: egen lr_remdezr_stayers   = mean(lr_remdezr)   if non_switch_1114 == 1
bys cnpj_year: egen lr_remmedr_stayers   = mean(lr_remmedr)   if non_switch_1114 == 1

bys cnpj_year: egen lr_remdezr_switchers = mean(lr_remdezr)   if switchers_1112 == 1
bys cnpj_year: egen lr_remmedr_switchers = mean(lr_remmedr)   if switchers_1112 == 1

*---------------------------------------------*
* Percentiles: log December wage (lr_remdezr) *
*---------------------------------------------*

egen lr_remdezr_p90 = pctile(lr_remdezr), by(cnpj_year) p(90)
label var lr_remdezr_p90 "lr_remdezr: p90 by cnpj_year"

egen lr_remdezr_p80 = pctile(lr_remdezr), by(cnpj_year) p(80)
label var lr_remdezr_p80 "lr_remdezr: p80 by cnpj_year"

egen lr_remdezr_p75 = pctile(lr_remdezr), by(cnpj_year) p(75)
label var lr_remdezr_p75 "lr_remdezr: p75 by cnpj_year"

egen lr_remdezr_p50 = pctile(lr_remdezr), by(cnpj_year) p(50)
label var lr_remdezr_p50 "lr_remdezr: p50 by cnpj_year"

egen lr_remdezr_p25 = pctile(lr_remdezr), by(cnpj_year) p(25)
label var lr_remdezr_p25 "lr_remdezr: p25 by cnpj_year"

egen lr_remdezr_p20 = pctile(lr_remdezr), by(cnpj_year) p(20)
label var lr_remdezr_p20 "lr_remdezr: p20 by cnpj_year"

egen lr_remdezr_p10 = pctile(lr_remdezr), by(cnpj_year) p(10)
label var lr_remdezr_p10 "lr_remdezr: p10 by cnpj_year"



*----------------------------------------------------*
* Percentiles: log average monthly wage (lr_remmedr) *
*----------------------------------------------------*

egen lr_remmedr_p90 = pctile(lr_remmedr), by(cnpj_year) p(90)
label var lr_remmedr_p90 "lr_remmedr: p90 by cnpj_year"

egen lr_remmedr_p80 = pctile(lr_remmedr), by(cnpj_year) p(80)
label var lr_remmedr_p80 "lr_remmedr: p80 by cnpj_year"

egen lr_remmedr_p75 = pctile(lr_remmedr), by(cnpj_year) p(75)
label var lr_remmedr_p75 "lr_remmedr: p75 by cnpj_year"

egen lr_remmedr_p50 = pctile(lr_remmedr), by(cnpj_year) p(50)
label var lr_remmedr_p50 "lr_remmedr: p50 by cnpj_year"

egen lr_remmedr_p25 = pctile(lr_remmedr), by(cnpj_year) p(25)
label var lr_remmedr_p25 "lr_remmedr: p25 by cnpj_year"

egen lr_remmedr_p20 = pctile(lr_remmedr), by(cnpj_year) p(20)
label var lr_remmedr_p20 "lr_remmedr: p20 by cnpj_year"

egen lr_remmedr_p10 = pctile(lr_remmedr), by(cnpj_year) p(10)
label var lr_remmedr_p10 "lr_remmedr: p10 by cnpj_year"

*------------------------------------------------------------*
* Percentiles: log hourly (or alt) wage (lr_remdezr_h) NEW  *
*------------------------------------------------------------*

egen lr_remdezr_h_p90 = pctile(lr_remdezr_h), by(cnpj_year) p(90)
label var lr_remdezr_h_p90 "lr_remdezr_h: p90 by cnpj_year"

egen lr_remdezr_h_p80 = pctile(lr_remdezr_h), by(cnpj_year) p(80)
label var lr_remdezr_h_p80 "lr_remdezr_h: p80 by cnpj_year"

egen lr_remdezr_h_p75 = pctile(lr_remdezr_h), by(cnpj_year) p(75)
label var lr_remdezr_h_p75 "lr_remdezr_h: p75 by cnpj_year"

egen lr_remdezr_h_p50 = pctile(lr_remdezr_h), by(cnpj_year) p(50)
label var lr_remdezr_h_p50 "lr_remdezr_h: p50 by cnpj_year"

egen lr_remdezr_h_p25 = pctile(lr_remdezr_h), by(cnpj_year) p(25)
label var lr_remdezr_h_p25 "lr_remdezr_h: p25 by cnpj_year"

egen lr_remdezr_h_p20 = pctile(lr_remdezr_h), by(cnpj_year) p(20)
label var lr_remdezr_h_p20 "lr_remdezr_h: p20 by cnpj_year"

egen lr_remdezr_h_p10 = pctile(lr_remdezr_h), by(cnpj_year) p(10)
label var lr_remdezr_h_p10 "lr_remdezr_h: p10 by cnpj_year"

*------------------------------------------------------------*
* Percentiles: log hourly (or alt) wage (lr_remmedr_h) NEW  *
*------------------------------------------------------------*

egen lr_remmedr_h_p90 = pctile(lr_remmedr_h), by(cnpj_year) p(90)
label var lr_remmedr_h_p90 "lr_remmedr_h: p90 by cnpj_year"

egen lr_remmedr_h_p80 = pctile(lr_remmedr_h), by(cnpj_year) p(80)
label var lr_remmedr_h_p80 "lr_remmedr_h: p80 by cnpj_year"

egen lr_remmedr_h_p75 = pctile(lr_remmedr_h), by(cnpj_year) p(75)
label var lr_remmedr_h_p75 "lr_remmedr_h: p75 by cnpj_year"

egen lr_remmedr_h_p50 = pctile(lr_remmedr_h), by(cnpj_year) p(50)
label var lr_remmedr_h_p50 "lr_remmedr_h: p50 by cnpj_year"

egen lr_remmedr_h_p25 = pctile(lr_remmedr_h), by(cnpj_year) p(25)
label var lr_remmedr_h_p25 "lr_remmedr_h: p25 by cnpj_year"

egen lr_remmedr_h_p20 = pctile(lr_remmedr_h), by(cnpj_year) p(20)
label var lr_remmedr_h_p20 "lr_remmedr_h: p20 by cnpj_year"

egen lr_remmedr_h_p10 = pctile(lr_remmedr_h), by(cnpj_year) p(10)
label var lr_remmedr_h_p10 "lr_remmedr_h: p10 by cnpj_year"

*----------------------------------------------------*
* Averages below p10 and above p90 for each measure *
*----------------------------------------------------*

* ============================================================
* Averages in tails (below p25/p20/p10 and above p75/p80/p90)
* ============================================================

* ----------------------------
* Log December wage: lr_remdezr
* ----------------------------

* Below tails
bys cnpj_year: egen lr_remdezr_p25_avg = ///
    mean(lr_remdezr * cond(lr_remdezr <= lr_remdezr_p25, 1, .))
label var lr_remdezr_p25_avg "lr_remdezr: mean below p25 by cnpj_year"

bys cnpj_year: egen lr_remdezr_p20_avg = ///
    mean(lr_remdezr * cond(lr_remdezr <= lr_remdezr_p20, 1, .))
label var lr_remdezr_p20_avg "lr_remdezr: mean below p20 by cnpj_year"

bys cnpj_year: egen lr_remdezr_p10_avg = ///
    mean(lr_remdezr * cond(lr_remdezr <= lr_remdezr_p10, 1, .))
label var lr_remdezr_p10_avg "lr_remdezr: mean below p10 by cnpj_year"

* Above tails
bys cnpj_year: egen lr_remdezr_p75_avg = ///
    mean(lr_remdezr * cond(lr_remdezr >= lr_remdezr_p75, 1, .))
label var lr_remdezr_p75_avg "lr_remdezr: mean above p75 by cnpj_year"

bys cnpj_year: egen lr_remdezr_p80_avg = ///
    mean(lr_remdezr * cond(lr_remdezr >= lr_remdezr_p80, 1, .))
label var lr_remdezr_p80_avg "lr_remdezr: mean above p80 by cnpj_year"

bys cnpj_year: egen lr_remdezr_p90_avg = ///
    mean(lr_remdezr * cond(lr_remdezr >= lr_remdezr_p90, 1, .))
label var lr_remdezr_p90_avg "lr_remdezr: mean above p90 by cnpj_year"


* ----------------------------------
* Log average monthly wage: lr_remmedr
* ----------------------------------

* Below tails
bys cnpj_year: egen lr_remmedr_p25_avg = ///
    mean(lr_remmedr * cond(lr_remmedr <= lr_remmedr_p25, 1, .))
label var lr_remmedr_p25_avg "lr_remmedr: mean below p25 by cnpj_year"

bys cnpj_year: egen lr_remmedr_p20_avg = ///
    mean(lr_remmedr * cond(lr_remmedr <= lr_remmedr_p20, 1, .))
label var lr_remmedr_p20_avg "lr_remmedr: mean below p20 by cnpj_year"

bys cnpj_year: egen lr_remmedr_p10_avg = ///
    mean(lr_remmedr * cond(lr_remmedr <= lr_remmedr_p10, 1, .))
label var lr_remmedr_p10_avg "lr_remmedr: mean below p10 by cnpj_year"

* Above tails
bys cnpj_year: egen lr_remmedr_p75_avg = ///
    mean(lr_remmedr * cond(lr_remmedr >= lr_remmedr_p75, 1, .))
label var lr_remmedr_p75_avg "lr_remmedr: mean above p75 by cnpj_year"

bys cnpj_year: egen lr_remmedr_p80_avg = ///
    mean(lr_remmedr * cond(lr_remmedr >= lr_remmedr_p80, 1, .))
label var lr_remmedr_p80_avg "lr_remmedr: mean above p80 by cnpj_year"

bys cnpj_year: egen lr_remmedr_p90_avg = ///
    mean(lr_remmedr * cond(lr_remmedr >= lr_remmedr_p90, 1, .))
label var lr_remmedr_p90_avg "lr_remmedr: mean above p90 by cnpj_year"


* ----------------------------------------
* Log hourly / alternative wage: lr_remdezr_h
* ----------------------------------------

* Below tails
bys cnpj_year: egen lr_remdezr_h_p25_avg = ///
    mean(lr_remdezr_h * cond(lr_remdezr_h <= lr_remdezr_h_p25, 1, .))
label var lr_remdezr_h_p25_avg "lr_remdezr_h: mean below p25 by cnpj_year"

bys cnpj_year: egen lr_remdezr_h_p20_avg = ///
    mean(lr_remdezr_h * cond(lr_remdezr_h <= lr_remdezr_h_p20, 1, .))
label var lr_remdezr_h_p20_avg "lr_remdezr_h: mean below p20 by cnpj_year"

bys cnpj_year: egen lr_remdezr_h_p10_avg = ///
    mean(lr_remdezr_h * cond(lr_remdezr_h <= lr_remdezr_h_p10, 1, .))
label var lr_remdezr_h_p10_avg "lr_remdezr_h: mean below p10 by cnpj_year"

* Above tails
bys cnpj_year: egen lr_remdezr_h_p75_avg = ///
    mean(lr_remdezr_h * cond(lr_remdezr_h >= lr_remdezr_h_p75, 1, .))
label var lr_remdezr_h_p75_avg "lr_remdezr_h: mean above p75 by cnpj_year"

bys cnpj_year: egen lr_remdezr_h_p80_avg = ///
    mean(lr_remdezr_h * cond(lr_remdezr_h >= lr_remdezr_h_p80, 1, .))
label var lr_remdezr_h_p80_avg "lr_remdezr_h: mean above p80 by cnpj_year"

bys cnpj_year: egen lr_remdezr_h_p90_avg = ///
    mean(lr_remdezr_h * cond(lr_remdezr_h >= lr_remdezr_h_p90, 1, .))
label var lr_remdezr_h_p90_avg "lr_remdezr_h: mean above p90 by cnpj_year"

* ============================================================
* Within cnpj_year standard deviations – wage dispersion
* Naming convention: sd_<wage_var>
* ============================================================

* ----------------------------
* Log wages (monthly)
* ----------------------------
bys cnpj_year: egen sd_lr_remdezr = sd(lr_remdezr)
label var sd_lr_remdezr "sd of lr_remdezr within cnpj_year"

bys cnpj_year: egen sd_lr_remmedr = sd(lr_remmedr)
label var sd_lr_remmedr "sd of lr_remmedr within cnpj_year"


* ----------------------------
* Log hourly wages
* ----------------------------
bys cnpj_year: egen sd_lr_remdezr_h = sd(lr_remdezr_h)
label var sd_lr_remdezr_h "sd of lr_remdezr_h within cnpj_year"

bys cnpj_year: egen sd_lr_remmedr_h = sd(lr_remmedr_h)
label var sd_lr_remmedr_h "sd of lr_remmedr_h within cnpj_year"


* ----------------------------
* Real wages (levels, monthly)
* ----------------------------
bys cnpj_year: egen sd_r_remdezr = sd(r_remdezr)
label var sd_r_remdezr "sd of r_remdezr within cnpj_year"

bys cnpj_year: egen sd_r_remmedr = sd(r_remmedr)
label var sd_r_remmedr "sd of r_remmedr within cnpj_year"


* ----------------------------
* Real hourly wages (levels)
* ----------------------------
bys cnpj_year: egen sd_r_remdezr_h = sd(r_remdezr_h)
label var sd_r_remdezr_h "sd of r_remdezr_h within cnpj_year"

bys cnpj_year: egen sd_r_remmedr_h = sd(r_remmedr_h)
label var sd_r_remmedr_h "sd of r_remmedr_h within cnpj_year"


* ----------------------------
* Order (append to your order)
* ----------------------------
order identificad year cnpj_year lr_remmedr lr_remdezr lr_remdezr_h ///
      lr_remdezr_p10 lr_remdezr_p20 lr_remdezr_p25 lr_remdezr_p75 lr_remdezr_p80 lr_remdezr_p90 ///
      lr_remdezr_p10_avg lr_remdezr_p20_avg lr_remdezr_p25_avg lr_remdezr_p75_avg lr_remdezr_p80_avg lr_remdezr_p90_avg ///
      lr_remmedr_p10 lr_remmedr_p20 lr_remmedr_p25 lr_remmedr_p75 lr_remmedr_p80 lr_remmedr_p90 ///
      lr_remmedr_p10_avg lr_remmedr_p20_avg lr_remmedr_p25_avg lr_remmedr_p75_avg lr_remmedr_p80_avg lr_remmedr_p90_avg ///
      lr_remdezr_h_p10 lr_remdezr_h_p20 lr_remdezr_h_p25 lr_remdezr_h_p75 lr_remdezr_h_p80 lr_remdezr_h_p90 ///
      lr_remdezr_h_p10_avg lr_remdezr_h_p20_avg lr_remdezr_h_p25_avg lr_remdezr_h_p75_avg lr_remdezr_h_p80_avg lr_remdezr_h_p90_avg
rename lr_remdezr lr_remdezr_a

collapse (firstnm) identificad year ///
        lr_remdezr_p* lr_remmedr_p* lr_remdezr_h_p* ///
        lr_remdezr_stayers lr_remmedr_stayers ///
        lr_remdezr_switchers lr_remmedr_switchers ///
		sd_* ///
        (mean) lr_remdezr_a, by(cnpj_year)

isid identificad year

preserve
mmerge identificad year using "$rais_firm/lagos_sample_sep24.dta", type(1:1)

save "$rais_firm/lagos_sample_sep24_pct.dta", replace
restore

mmerge identificad year using "$rais_firm/lagos_sample_sep24_pct_unionexp.dta", type(1:1)

save "$rais_firm/lagos_sample_sep24_pct_unionexp_ext.dta", replace

keep if !missing(lr_remdezr_a)

assert lr_remdezr_a==lr_remdezr if !missing(lr_remdezr_a)
