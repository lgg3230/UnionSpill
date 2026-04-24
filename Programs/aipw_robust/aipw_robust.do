********************************************************************************
* aipw_robust.do
* Doubly-Robust DiD vs. TWFE comparison
*
* Motivation: Caetano, Callaway, Payne & Rodrigues (2024) show that including
* time-varying covariates as additive TWFE regressors generally fails to identify
* the ATT.  This script re-estimates the main results using:
*
*   Direct effects:    csdid dripw (Sant'Anna & Zhao 2020)
*                      propensity score + outcome regression, no TWFE interactions
*
*   Spillover effects: Continuous DR-DiD (Callaway, Goodman-Bacon & Sant'Anna 2024)
*                      manual two-step implementation:
*                      Step 1  — OR-DiD:  (dY - muhat) ~ C_i
*                      Step 2  — DR-DiD:  (dY - muhat) ~ C_i, IV = c_tilde
*
* The key comparison: TWFE coef vs. DR coef for each year.
* Stable estimates → granular FEs were not distorting the result.
* Diverging estimates → functional-form assumption was doing work.
*
* Outputs
*   Tables/aipw_robust/direct_comparison.csv
*   Tables/aipw_robust/spill_comparison.csv
*   Graphs/aipw_robust/direct_twfe_vs_aipw.pdf
*   Graphs/aipw_robust/spill_twfe_vs_drdid.pdf
********************************************************************************

cap log close
set more off
set varabbrev off

* ── PATHS ────────────────────────────────────────────────────────────────────
local d        = subinstr("`c(current_date)'"," ","_",.)
local t_stamp  = subinstr("`c(current_time)'",":","",.)
log using "$logs/aipw_robust/aipw_`d'_`t_stamp'.log", replace text
di "Started: `c(current_date)' `c(current_time)'"

* ── PACKAGES ─────────────────────────────────────────────────────────────────
foreach pkg in csdid drdid {
    cap which `pkg'
    if _rc {
        di "Installing `pkg'..."
        ssc install `pkg', replace
    }
}

* ── LOAD DATA ────────────────────────────────────────────────────────────────
use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear
keep if year >= 2009 & year <= 2016
keep if lagos_sample_avg == 1 & in_balanced_panel == 1

* ── VARIABLE PREP ────────────────────────────────────────────────────────────

* Log employment
cap drop l_firm_emp
gen double l_firm_emp = ln(firm_emp)

* Numeric panel ID
cap drop id
egen id = group(identificad)

* Pre-treatment averages (2009–2011) — used as covariates in AIPW
foreach var in l_firm_emp lr_remdezr_w {
    cap drop `var'_pre_o
    cap drop `var'_pre
    bys id: egen `var'_pre_o = mean(`var') if inrange(year,2009,2011)
    bys id: egen `var'_pre   = min(`var'_pre_o)
    cap drop `var'_pre_o
}

cap drop firm_emp_pre_o
cap drop firm_emp_pre
bys id: egen firm_emp_pre_o = mean(firm_emp) if inrange(year,2009,2011)
bys id: egen firm_emp_pre   = min(firm_emp_pre_o)
cap drop firm_emp_pre_o

cap drop tf_per_emp_pre
gen double tf_per_emp_pre = totalflows_n / firm_emp_pre if firm_emp_pre > 0

* Connectivity normalization (90th pct among untreated, 2009)
cap drop totaltreat_pw_norm
quietly sum totaltreat_pw_n if treat_ultra==0 & year==2009, detail
scalar conn_p90 = r(p90)
gen double totaltreat_pw_norm = totaltreat_pw_n / conn_p90

* Quartile bins (for TWFE comparison — same as main spec)
cap drop lr_remdezr_w_pre_bins_o
cap drop lr_remdezr_w_pre_bins
quietly egen lr_remdezr_w_pre_bins_o = cut(lr_remdezr_w_pre) if year==2009, group(4)
bys id: egen lr_remdezr_w_pre_bins = min(lr_remdezr_w_pre_bins_o)
cap drop lr_remdezr_w_pre_bins_o

cap drop tf_per_emp_pre_bins_o
cap drop tf_per_emp_pre_bins
quietly egen tf_per_emp_pre_bins_o = cut(tf_per_emp_pre) if year==2009, group(4)
bys id: egen tf_per_emp_pre_bins = min(tf_per_emp_pre_bins_o)
cap drop tf_per_emp_pre_bins_o

cap drop l_firm_emp_pre_bins_o
cap drop l_firm_emp_pre_bins
quietly egen l_firm_emp_pre_bins_o = cut(l_firm_emp_pre) if year==2009, group(8)
bys id: egen l_firm_emp_pre_bins = min(l_firm_emp_pre_bins_o)
cap drop l_firm_emp_pre_bins_o

di "✓ Variable prep complete. N = " _N

********************************************************************************
* SECTION 1 — DIRECT EFFECTS
* Sample: treat_ultra==1 OR (treat_ultra==0 AND totaltreat_pw_n==0)
********************************************************************************

di _newline "════════════════════════════════════════"
di "SECTION 1: DIRECT EFFECTS"
di "════════════════════════════════════════"

preserve

keep if treat_ultra == 1 | (treat_ultra == 0 & totaltreat_pw_n == 0)
drop if missing(l_firm_emp_pre, lr_remdezr_w_pre, tf_per_emp_pre, industry1, mode_base_month)

di "Direct effects sample: " _N " obs, " r(N) " establishments"

* ── 1a: TWFE event study (main spec for comparison) ──────────────────────────
di _newline "--- 1a: TWFE ---"

quietly reghdfe lr_remdezr_w i.treat_ultra##ib2011.year, ///
    absorb(id                            ///
           i.industry1#i.year            ///
           i.mode_base_month#i.year      ///
           i.microregion#i.year          ///
           ib0.tf_per_emp_pre_bins#i.year  ///
           ib0.l_firm_emp_pre_bins#i.year  ///
           ib0.lr_remdezr_w_pre_bins#i.year) ///
    vce(cluster id)

estimates store es_direct_twfe
di "TWFE N=" e(N) "  Establishments=" e(N_clust)

* Extract TWFE coefficients into locals
foreach yr in 2009 2010 2012 2013 2014 2015 2016 {
    local twfe_b_`yr' = _b[1.treat_ultra#`yr'.year]
    local twfe_se_`yr' = _se[1.treat_ultra#`yr'.year]
}

* ── 1b: AIPW via csdid (dripw) ───────────────────────────────────────────────
di _newline "--- 1b: AIPW (csdid dripw) ---"
di "(Covariates enter propensity score + outcome regression, not as TWFE FEs)"

cap drop gvar_direct
gen int gvar_direct = 2012 if treat_ultra == 1
replace gvar_direct = 0    if treat_ultra == 0

* Covariates: same information as TWFE spec, entered as flexible predictors
* Industry (2-digit) and month as dummies; size/wages/flows as continuous
csdid lr_remdezr_w i.industry1 i.mode_base_month ///
    c.l_firm_emp_pre c.lr_remdezr_w_pre c.tf_per_emp_pre, ///
    ivar(id) time(year) gvar(gvar_direct) method(dripw) ///
    vce(cluster id) level(95)

estat event, window(-2 4) estore(es_direct_aipw)
matrix aipw_direct_res = r(table)

di "AIPW: stored"

* ── 1c: Write comparison CSV ──────────────────────────────────────────────────
di _newline "--- 1c: Writing direct comparison CSV ---"

tempname fh
file open `fh' using "$tables/aipw_robust/direct_comparison.csv", write replace
file write `fh' "year,twfe_coef,twfe_se,aipw_coef,aipw_se" _n

* Map event-time to calendar year: e(-2)=2009, e(-1)=2010, e(0)=2012, ..., e(4)=2016
* csdid estat event stores as t=-2,-1,0,1,...
local yr_map "2009 2010 2012 2013 2014 2015 2016"
local et_map "-2 -1 0 1 2 3 4"

forvalues i = 1/7 {
    local yr  : word `i' of `yr_map'
    local et  : word `i' of `et_map'

    local twfe_b  = `twfe_b_`yr''
    local twfe_se = `twfe_se_`yr''

    * aipw_direct_res columns: Pre_avg(1), Post_avg(2), Tm2(3)..Tp4(9)
    * event times Tm2..Tp4 start at column 3, so offset by 2
    local aipw_b  = aipw_direct_res[1, `i'+2]
    local aipw_se = aipw_direct_res[2, `i'+2]

    file write `fh' "`yr'," %9.5f (`twfe_b') "," %9.5f (`twfe_se') "," ///
        %9.5f (`aipw_b') "," %9.5f (`aipw_se') _n
}
file close `fh'
di "✓ Saved: Tables/aipw_robust/direct_comparison.csv"

* ── 1d: Event study comparison plot ──────────────────────────────────────────
di _newline "--- 1d: Comparison plot ---"

* Build TWFE event-study dataset for plotting
* (can't nest preserve; save current data to tempfile instead)
tempfile direct_data
save `direct_data'

    * Event-time → calendar year mapping already in locals
    local nyr = 7
    local yrs "2009 2010 2012 2013 2014 2015 2016"
    local ets "-2 -1 0 1 2 3 4"

    clear
    set obs `nyr'
    gen event_time = .
    gen twfe_b  = .
    gen twfe_lo = .
    gen twfe_hi = .
    gen aipw_b  = .
    gen aipw_lo = .
    gen aipw_hi = .

    forvalues i = 1/`nyr' {
        local yr : word `i' of `yrs'
        local et : word `i' of `ets'

        replace event_time = `et'  in `i'
        replace twfe_b     = `twfe_b_`yr'' in `i'
        replace twfe_lo    = `twfe_b_`yr'' - 1.96*`twfe_se_`yr'' in `i'
        replace twfe_hi    = `twfe_b_`yr'' + 1.96*`twfe_se_`yr'' in `i'
        replace aipw_b     = aipw_direct_res[1,`i'+2] in `i'
        replace aipw_lo    = aipw_direct_res[1,`i'+2] - 1.96*aipw_direct_res[2,`i'+2] in `i'
        replace aipw_hi    = aipw_direct_res[1,`i'+2] + 1.96*aipw_direct_res[2,`i'+2] in `i'
    }

    twoway (rcap twfe_lo twfe_hi event_time, lcolor(blue%50)) ///
           (scatter twfe_b event_time, mcolor(blue) mfcolor(white) msymbol(circle) msize(medlarge)) ///
           (rcap aipw_lo aipw_hi event_time, lcolor(red%50)) ///
           (scatter aipw_b event_time, mcolor(red) mfcolor(red) msymbol(diamond) msize(medlarge)), ///
        yline(0, lcolor(gray) lpattern(dash)) ///
        xline(-0.5, lcolor(black) lpattern(dash)) ///
        xlabel(-2(1)4, labsize(small)) ///
        ylabel(, format(%5.3f) labsize(small)) ///
        xtitle("Years relative to reform", size(small)) ///
        ytitle("Coefficient (log wages)", size(small)) ///
        legend(order(2 "TWFE" 4 "AIPW (dripw)") pos(6) row(1) size(small) symxsize(4)) ///
        graphregion(color(white)) bgcolor(white) ///
        note("Direct effects: treated vs. zero-connectivity control" ///
             "AIPW covariates: industry, month, log emp, log wage, per-worker flows", size(vsmall))

    graph export "$graphs/aipw_robust/direct_twfe_vs_aipw.pdf", replace
    di "✓ Saved: Graphs/aipw_robust/direct_twfe_vs_aipw.pdf"

use `direct_data', clear   // back to direct-effects sample

restore  // back to full sample

********************************************************************************
* SECTION 2 — SPILLOVER EFFECTS (Continuous Treatment DR-DiD)
* Sample: treat_ultra==0 (all untreated firms)
* Three estimators compared:
*   TWFE   : reghdfe with interacted FEs
*   OR-DiD : (dY - muhat) ~ totaltreat_pw_norm  [outcome regression only]
*   DR-DiD : (dY - muhat) ~ totaltreat_pw_norm, IV = c_tilde  [doubly robust]
********************************************************************************

di _newline "════════════════════════════════════════"
di "SECTION 2: SPILLOVER EFFECTS (Continuous DR-DiD)"
di "════════════════════════════════════════"

preserve

keep if treat_ultra == 0
drop if missing(l_firm_emp_pre, lr_remdezr_w_pre, tf_per_emp_pre, industry1, mode_base_month)

di "Spillover sample: " _N " obs"

* ── 2a: TWFE event study ─────────────────────────────────────────────────────
di _newline "--- 2a: TWFE ---"

quietly reghdfe lr_remdezr_w c.totaltreat_pw_norm##ib2011.year, ///
    absorb(id                            ///
           i.industry1#i.year            ///
           i.mode_base_month#i.year      ///
           i.microregion#i.year          ///
           ib0.tf_per_emp_pre_bins#i.year  ///
           ib0.l_firm_emp_pre_bins#i.year  ///
           ib0.lr_remdezr_w_pre_bins#i.year) ///
    vce(cluster id)

estimates store es_spill_twfe
di "Spillover TWFE N=" e(N)

foreach yr in 2009 2010 2012 2013 2014 2015 2016 {
    local twfe_b_`yr'  = _b[`yr'.year#c.totaltreat_pw_norm]
    local twfe_se_`yr' = _se[`yr'.year#c.totaltreat_pw_norm]
}

* ── 2b: First differences relative to 2011 ───────────────────────────────────
di _newline "--- 2b: First differences (dY = Y_t - Y_2011) ---"

cap drop Y_base_o
cap drop Y_base
cap drop dY
bys id: egen Y_base_o = min(cond(year==2011, lr_remdezr_w, .))
bys id: egen Y_base   = min(Y_base_o)
gen double dY = lr_remdezr_w - Y_base
cap drop Y_base_o

* ── 2c: Residualize connectivity on covariates ───────────────────────────────
* Fit on 2011 cross-section (C_i is time-invariant; 2011 avoids post-treatment data)
di _newline "--- 2c: Residualizing connectivity ---"

cap drop c_tilde_2011
cap drop c_tilde
quietly reg totaltreat_pw_norm i.industry1 i.microregion i.mode_base_month ///
    c.l_firm_emp_pre c.lr_remdezr_w_pre c.tf_per_emp_pre if year == 2011
predict c_tilde_2011 if year == 2011, residuals
bys id: egen c_tilde = max(c_tilde_2011)   // broadcast to all years
cap drop c_tilde_2011

di "  c_tilde R² of connectivity on X: " %6.4f (e(r2))

* ── 2d: Year-by-year OR-DiD and DR-DiD ──────────────────────────────────────
di _newline "--- 2d: Year-by-year OR-DiD and DR-DiD ---"
di _newline "year  | TWFE        | OR-DiD      | DR-DiD (IV)"
di         "      | coef    se  | coef    se  | coef    se"
di         "{hline 65}"

* Initialize output file
tempname fh
file open `fh' using "$tables/aipw_robust/spill_comparison.csv", write replace
file write `fh' "year,twfe_coef,twfe_se,ordid_coef,ordid_se,drdid_coef,drdid_se" _n

* Matrices to collect for plotting
local nyr 7
local yrs "2009 2010 2012 2013 2014 2015 2016"

matrix twfe_b  = J(`nyr',1,.)
matrix ordid_b = J(`nyr',1,.)
matrix drdid_b = J(`nyr',1,.)
matrix twfe_lo = J(`nyr',1,.)
matrix ordid_lo= J(`nyr',1,.)
matrix drdid_lo= J(`nyr',1,.)
matrix twfe_hi = J(`nyr',1,.)
matrix ordid_hi= J(`nyr',1,.)
matrix drdid_hi= J(`nyr',1,.)

local i = 0
foreach yr of local yrs {
    local ++i

    * ── Step 1: Outcome regression on zero-conn firms ──
    cap drop muhat
    quietly reg dY i.industry1 i.microregion i.mode_base_month ///
        c.l_firm_emp_pre c.lr_remdezr_w_pre c.tf_per_emp_pre ///
        if year == `yr' & totaltreat_pw_n == 0
    predict muhat if year == `yr', xb

    * DR-adjusted outcome
    cap drop dr_Y
    gen double dr_Y = dY - muhat if year == `yr'

    * ── Step 2: OR-DiD ────────────────────────────────
    quietly reg dr_Y c.totaltreat_pw_norm if year == `yr', vce(cluster id)
    local b_or   = _b[totaltreat_pw_norm]
    local se_or  = _se[totaltreat_pw_norm]

    * ── Step 3: DR-DiD via IV (c_tilde instruments C_i) ──
    quietly ivregress 2sls dr_Y (totaltreat_pw_norm = c_tilde) ///
        if year == `yr', vce(cluster id)
    local b_dr   = _b[totaltreat_pw_norm]
    local se_dr  = _se[totaltreat_pw_norm]

    * Store in matrices
    matrix twfe_b[`i',1]   = `twfe_b_`yr''
    matrix ordid_b[`i',1]  = `b_or'
    matrix drdid_b[`i',1]  = `b_dr'
    matrix twfe_lo[`i',1]  = `twfe_b_`yr'' - 1.96*`twfe_se_`yr''
    matrix ordid_lo[`i',1] = `b_or'  - 1.96*`se_or'
    matrix drdid_lo[`i',1] = `b_dr'  - 1.96*`se_dr'
    matrix twfe_hi[`i',1]  = `twfe_b_`yr'' + 1.96*`twfe_se_`yr''
    matrix ordid_hi[`i',1] = `b_or'  + 1.96*`se_or'
    matrix drdid_hi[`i',1] = `b_dr'  + 1.96*`se_dr'

    di %4.0f (`yr') "  | " %7.4f (`twfe_b_`yr'') " " %6.4f (`twfe_se_`yr'') ///
             "  | " %7.4f (`b_or')  " " %6.4f (`se_or')  ///
             "  | " %7.4f (`b_dr')  " " %6.4f (`se_dr')

    file write `fh' "`yr'," %9.5f (`twfe_b_`yr'') "," %9.5f (`twfe_se_`yr'') "," ///
        %9.5f (`b_or') "," %9.5f (`se_or') "," ///
        %9.5f (`b_dr') "," %9.5f (`se_dr') _n

    cap drop muhat
    cap drop dr_Y
}
file close `fh'
di "✓ Saved: Tables/aipw_robust/spill_comparison.csv"

* ── 2e: Spillover comparison plot ────────────────────────────────────────────
di _newline "--- 2e: Spillover comparison plot ---"

local event_times "-2 -1 0 1 2 3 4"

* (can't nest preserve; save to tempfile)
tempfile spill_data
save `spill_data'

    clear
    set obs `nyr'
    gen event_time = .
    gen twfe_b_v   = .
    gen twfe_lo_v  = .
    gen twfe_hi_v  = .
    gen ordid_b_v  = .
    gen ordid_lo_v = .
    gen ordid_hi_v = .
    gen drdid_b_v  = .
    gen drdid_lo_v = .
    gen drdid_hi_v = .

    forvalues i = 1/`nyr' {
        local et : word `i' of `event_times'
        replace event_time = `et'      in `i'
        replace twfe_b_v   = twfe_b[`i',1]   in `i'
        replace twfe_lo_v  = twfe_lo[`i',1]  in `i'
        replace twfe_hi_v  = twfe_hi[`i',1]  in `i'
        replace ordid_b_v  = ordid_b[`i',1]  in `i'
        replace ordid_lo_v = ordid_lo[`i',1] in `i'
        replace ordid_hi_v = ordid_hi[`i',1] in `i'
        replace drdid_b_v  = drdid_b[`i',1]  in `i'
        replace drdid_lo_v = drdid_lo[`i',1] in `i'
        replace drdid_hi_v = drdid_hi[`i',1] in `i'
    }

    * Offset event times slightly so CIs don't overlap
    gen et_twfe  = event_time - 0.15
    gen et_ordid = event_time
    gen et_drdid = event_time + 0.15

    twoway ///
        (rcap twfe_lo_v  twfe_hi_v  et_twfe,  lcolor(blue%50) lwidth(thin)) ///
        (scatter twfe_b_v  et_twfe,  mc(blue) mfc(white) ms(circle)  msz(medium)) ///
        (rcap ordid_lo_v ordid_hi_v et_ordid, lcolor(forest_green%50) lwidth(thin)) ///
        (scatter ordid_b_v et_ordid, mc(forest_green) mfc(forest_green) ms(triangle) msz(medium)) ///
        (rcap drdid_lo_v drdid_hi_v et_drdid, lcolor(red%50) lwidth(thin)) ///
        (scatter drdid_b_v et_drdid, mc(red) mfc(red) ms(diamond) msz(medium)), ///
        yline(0, lcolor(gray) lpattern(dash)) ///
        xline(-0.5, lcolor(black) lpattern(dash)) ///
        xlabel(-2(1)4, labsize(small)) ///
        ylabel(, format(%6.4f) labsize(small)) ///
        xtitle("Years relative to reform", size(small)) ///
        ytitle("Effect per unit of connectivity (log wages)", size(small)) ///
        legend(order(2 "TWFE" 4 "OR-DiD" 6 "DR-DiD (IV)") ///
               pos(6) row(1) size(small) symxsize(4)) ///
        graphregion(color(white)) bgcolor(white) ///
        note("Spillover effects: all untreated firms. Connectivity normalized to 90th pct = 1." ///
             "OR-DiD: outcome reg on zero-conn firms. DR-DiD: additionally instruments C_i with c_tilde.", ///
             size(vsmall))

    graph export "$graphs/aipw_robust/spill_twfe_vs_drdid.pdf", replace
    di "✓ Saved: Graphs/aipw_robust/spill_twfe_vs_drdid.pdf"

use `spill_data', clear   // back to spillover sample

restore  // back to full sample

********************************************************************************
* SECTION 3 — SUMMARY TABLE
* DiD ATT (pooled post) for quick comparison
********************************************************************************

di _newline "════════════════════════════════════════"
di "SECTION 3: POOLED DiD SUMMARY"
di "════════════════════════════════════════"

* Direct effects: pooled post coefficient
preserve
keep if treat_ultra == 1 | (treat_ultra == 0 & totaltreat_pw_n == 0)
drop if missing(l_firm_emp_pre, lr_remdezr_w_pre, tf_per_emp_pre, industry1, mode_base_month)

cap drop treat_year
gen byte treat_year = (year >= 2012)
cap drop gvar_direct
gen int gvar_direct = 2012 if treat_ultra == 1
replace gvar_direct = 0    if treat_ultra == 0

* TWFE pooled
quietly reghdfe lr_remdezr_w treat_ultra##i.treat_year, ///
    absorb(id i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year ///
           ib0.tf_per_emp_pre_bins#i.year ib0.l_firm_emp_pre_bins#i.year ///
           ib0.lr_remdezr_w_pre_bins#i.year) ///
    vce(cluster id)
local b_direct_twfe  = _b[1.treat_ultra#1.treat_year]
local se_direct_twfe = _se[1.treat_ultra#1.treat_year]

* AIPW pooled (csdid ATT aggregated)
quietly csdid lr_remdezr_w i.industry1 i.mode_base_month ///
    c.l_firm_emp_pre c.lr_remdezr_w_pre c.tf_per_emp_pre, ///
    ivar(id) time(year) gvar(gvar_direct) method(dripw) ///
    vce(cluster id) level(95)
estat simple
matrix simple_aipw = r(table)
local b_direct_aipw  = simple_aipw[1,1]
local se_direct_aipw = simple_aipw[2,1]

restore

* Spillover: pooled post coefficient
preserve
keep if treat_ultra == 0
drop if missing(l_firm_emp_pre, lr_remdezr_w_pre, tf_per_emp_pre, industry1, mode_base_month)

cap drop treat_year
gen byte treat_year = (year >= 2012)

* TWFE pooled
quietly reghdfe lr_remdezr_w c.totaltreat_pw_norm##i.treat_year, ///
    absorb(id i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year ///
           ib0.tf_per_emp_pre_bins#i.year ib0.l_firm_emp_pre_bins#i.year ///
           ib0.lr_remdezr_w_pre_bins#i.year) ///
    vce(cluster id)
local b_spill_twfe  = _b[1.treat_year#c.totaltreat_pw_norm]
local se_spill_twfe = _se[1.treat_year#c.totaltreat_pw_norm]

* DR-DiD pooled: run on post-period only, using 2011-averaged baseline
cap drop Y_base_o
cap drop Y_base
cap drop dY
bys id: egen Y_base_o = min(cond(year==2011, lr_remdezr_w, .))
bys id: egen Y_base   = min(Y_base_o)
gen double dY = lr_remdezr_w - Y_base
cap drop Y_base_o

cap drop c_tilde_2011
cap drop c_tilde
quietly reg totaltreat_pw_norm i.industry1 i.microregion i.mode_base_month ///
    c.l_firm_emp_pre c.lr_remdezr_w_pre c.tf_per_emp_pre if year == 2011
predict c_tilde_2011 if year == 2011, residuals
bys id: egen c_tilde = max(c_tilde_2011)
cap drop c_tilde_2011

* Pooled post-period: stack 2012-2016, outcome reg on zero-conn, IV estimate
cap drop muhat_pooled
quietly reg dY i.industry1 i.microregion i.mode_base_month ///
    c.l_firm_emp_pre c.lr_remdezr_w_pre c.tf_per_emp_pre i.year ///
    if inrange(year,2012,2016) & totaltreat_pw_n == 0
predict muhat_pooled if inrange(year,2012,2016), xb

cap drop dr_Y_pooled
gen double dr_Y_pooled = dY - muhat_pooled if inrange(year,2012,2016)

* OR-DiD pooled
quietly reg dr_Y_pooled c.totaltreat_pw_norm if inrange(year,2012,2016), vce(cluster id)
local b_spill_ordid  = _b[totaltreat_pw_norm]
local se_spill_ordid = _se[totaltreat_pw_norm]

* DR-DiD pooled (IV)
quietly ivregress 2sls dr_Y_pooled (totaltreat_pw_norm = c_tilde) ///
    if inrange(year,2012,2016), vce(cluster id)
local b_spill_drdid  = _b[totaltreat_pw_norm]
local se_spill_drdid = _se[totaltreat_pw_norm]

restore

* Print summary
di _newline "════════════════════════════════════════════════════════════════"
di "POOLED POST-TREATMENT DiD ESTIMATES — LOG WAGES"
di "════════════════════════════════════════════════════════════════"
di "DIRECT EFFECTS:"
di "  TWFE    : " %7.4f (`b_direct_twfe')  " (" %6.4f (`se_direct_twfe') ")"
di "  AIPW    : " %7.4f (`b_direct_aipw')  " (" %6.4f (`se_direct_aipw') ")"
di ""
di "SPILLOVER EFFECTS (at 90th pct connectivity):"
di "  TWFE    : " %7.4f (`b_spill_twfe')   " (" %6.4f (`se_spill_twfe')  ")"
di "  OR-DiD  : " %7.4f (`b_spill_ordid')  " (" %6.4f (`se_spill_ordid') ")"
di "  DR-DiD  : " %7.4f (`b_spill_drdid')  " (" %6.4f (`se_spill_drdid') ")"
di "════════════════════════════════════════════════════════════════"

* Save summary CSV
tempname fh
file open `fh' using "$tables/aipw_robust/summary.csv", write replace
file write `fh' "spec,estimator,coef,se" _n
file write `fh' "direct,TWFE,"     %9.5f (`b_direct_twfe')  "," %9.5f (`se_direct_twfe')  _n
file write `fh' "direct,AIPW,"     %9.5f (`b_direct_aipw')  "," %9.5f (`se_direct_aipw')  _n
file write `fh' "spillover,TWFE,"  %9.5f (`b_spill_twfe')   "," %9.5f (`se_spill_twfe')   _n
file write `fh' "spillover,OR-DiD,"  %9.5f (`b_spill_ordid')  "," %9.5f (`se_spill_ordid')  _n
file write `fh' "spillover,DR-DiD,"  %9.5f (`b_spill_drdid')  "," %9.5f (`se_spill_drdid')  _n
file close `fh'
di "✓ Saved: Tables/aipw_robust/summary.csv"

********************************************************************************
* NOTIFY AND CLOSE
********************************************************************************

di _newline "Finished: `c(current_date)' `c(current_time)'"
log close

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && ///
    notify "AIPW robust done" "aipw_robust.do complete — check Tables/aipw_robust/"
