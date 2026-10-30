********************************************************************************
* a7_stacktest.do -- defines _stacktest_a7: test that a Group-Connectivity
* coefficient of Table A7 (column 2, 3, 5 or 6) equals the firm-level
* coefficient of column 1 (wages) or 4 (employment).
*
* Same design as _stacktest in conn_margins/3022_direct_sample_coef_test.do
* (the Table 1 Panel A vs Panel B test). Two copies are stacked:
*   samp = 0  the firm-level sample of column 1/4 (firm x year)
*   samp = 1  the group-level sample of column 2/3/5/6 (group x firm x year)
* Each copy keeps its own fixed effects: every absorbed term of a copy is
* rebuilt as a copy-specific id. In the other copy, terms that are not nested in
* establishments are set to a single constant level, and the unit effects that
* are (establishment, group x establishment, establishment x year) are set to
* the establishment id, which that copy already absorbs. This keeps them nested
* within the cluster, as i.samp#i.firm_id does in 3022, so reghdfe's
* degrees-of-freedom correction matches that of the separate regressions; a
* constant level there would make reghdfe count every unit effect and inflate
* the standard errors. The regressor (connectivity x Post) enters alone and interacted with
* samp, so
*     _b[d]  = firm-level coefficient   (identical to column 1/4)
*     _b[d1] = group minus firm-level   (group coefficient = _b[d] + _b[d1])
* Clustering on the establishment makes each establishment's firm-level and
* group-level observations one cluster, which delivers the covariance between
* the two estimators; the test of d1 = 0 is the cluster-robust Wald test of the
* cross-equation restriction (Wooldridge 2010, Sec. 7.3; Weesie 1999).
*
* Syntax:  _stacktest_a7 firmfile groupfile kind outcome [both]
*   firmfile   firm panel   (FIRM tempfile of 3132 Section 1)
*   groupfile  group panel  (GP tempfile of 3132 Section 4a, one partition)
*   kind       within | overall
*   outcome    wage | emp
*   both       optional: restrict the firm-level copy to firms employing both
*              groups (the same-firm benchmark of 3132 Section 4e)
* Returns r(b_firm) r(b_group) r(diff) r(se_diff) r(p) r(n_firm) r(n_group) r(G)
********************************************************************************

capture program drop _stacktest_a7
program define _stacktest_a7, rclass
    args firmfile groupfile kind oc both
    preserve

    if "`both'" == "both" {
        use "`groupfile'", clear
        keep if s_base==1
        egen byte __lt = tag(identificad layer_id)
        bysort identificad: egen byte __nl = total(__lt)
        keep if __nl==2
        keep identificad
        duplicates drop
        tempfile BOTH
        save `BOTH'
    }

    * ---- copy 0: firm level (column 1 / 4) ---------------------------------
    use "`firmfile'", clear
    local y0 = cond("`oc'"=="emp", "l_firm_emp", "lr_remdezr_h_w")
    keep if treat_ultra==0 & in_balanced_panel==1 & !mi(`y0')
    if "`both'" == "both" merge m:1 identificad using `BOTH', keep(match) nogen
    egen long f0n_1 = group(identificad)
    local t0 `" "l_firm_emp_pre4 year" "totalflows_pw_pre4 year" "industry1_num year" "mode_base_month_num year" "microregion_num year" "'
    if "`oc'"=="wage" local t0 `"`t0' "lr_remdezr_h_w_pre4 year""'
    local k0 0
    foreach t of local t0 {
        local ++k0
        egen long f0_`k0' = group(`t')
    }
    gen double y = `y0'
    gen double d = totaltreat_pw_norm * treat_year
    gen byte samp = 0
    keep identificad y d samp f0_* f0n_*
    tempfile c0
    save `c0'

    * ---- copy 1: group level (column 2/3 or 5/6) ---------------------------
    use "`groupfile'", clear
    local y1 = cond("`oc'"=="emp", "l_layer_emp", "lr_remdezr_h_layer")
    keep if s_base==1 & !mi(`y1') & !mi(conn)
    egen long f1n_1 = group(firm_layer_id)
    if "`kind'"=="within" egen long f1n_2 = group(firm_id year)
    local k1n = cond("`kind'"=="within", 2, 1)
    local t1 `" "layer_id_num l_layer_emp_pre4 year" "layer_id_num layer_totalflows_pw_pre4 year" "layer_id_num mode_base_month_num year" "layer_id_num industry1_num year" "layer_id_num microregion_num year" "'
    if "`oc'"=="wage" local t1 `"`t1' "layer_id_num lr_remdezr_h_layer_pre4 year""'
    if "`kind'"=="overall" {
        local t1 `"`t1' "l_firm_emp_pre4 year" "totalflows_pw_pre4 year""'
        if "`oc'"=="wage" local t1 `"`t1' "lr_remdezr_h_w_pre4 year""'
    }
    local k1 0
    foreach t of local t1 {
        local ++k1
        egen long f1_`k1' = group(`t')
    }
    gen double y = `y1'
    gen double d = conn * treat_year
    gen byte samp = 1
    keep identificad y d samp f1_* f1n_*

    * ---- stack ---------------------------------------------------------------
    append using `c0'
    egen long cl = group(identificad)
    forvalues j = 1/`k0' {
        replace f0_`j' = 0 if samp==1
    }
    forvalues j = 1/`k1' {
        replace f1_`j' = 0 if samp==0
    }
    * offset keeps these levels distinct from the copy's own levels
    replace f0n_1 = 10000000 + cl if samp==1
    forvalues j = 1/`k1n' {
        replace f1n_`j' = 10000000 + cl if samp==0
    }
    gen double d1 = d * samp

    local absorb "f0n_1"
    forvalues j = 1/`k1n' {
        local absorb "`absorb' f1n_`j'"
    }
    forvalues j = 1/`k0' {
        local absorb "`absorb' f0_`j'"
    }
    forvalues j = 1/`k1' {
        local absorb "`absorb' f1_`j'"
    }
    reghdfe y d d1, absorb(`absorb') vce(cluster cl)

    return scalar b_firm  = _b[d]
    return scalar b_group = _b[d] + _b[d1]
    return scalar diff    = _b[d1]
    return scalar se_diff = _se[d1]
    return scalar G       = e(N_clust)
    qui count if e(sample) & samp==0
    return scalar n_firm  = r(N)
    qui count if e(sample) & samp==1
    return scalar n_group = r(N)
    test d1 = 0
    return scalar p = r(p)
    restore
end
