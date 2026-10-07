********************************************************************************
* Program:  compare_winsor.do                                          (Task 4)
* Purpose:  Compare headline pooled DIRECT (Panel A) and SPILLOVER wage effects
*           between the baseline firm panel and the winsorized firm panel
*           (worker wages winsorized 1/99 within year before firm aggregation).
* Replicates the exact headline spec from Main_Results_pct_tfpw_07_11.do:
*   direct:    reghdfe Y treat_ultra##i.treat_year if s_direct_A, absorb(absorb)
*   spillover: reghdfe Y c.totaltreat_pw_norm##i.treat_year if s_spill, absorb(absorb)
*   absorb = identificad i.industry1#i.year i.mode_base_month#i.year
*            i.microregion#i.year ib0.Y_pre4#i.year ib0.l_firm_emp_pre4#i.year
*            ib0.totalflows_pw_pre_07_114#i.year
* Outcomes:  lr_remdezr_w (log wages), lr_remdezr_h_w (log hourly wages).
* Output:    Tables/winsor/winsor_compare.csv  (canonical tables untouched)
* Run AFTER 121_get_wage_pctiles_df2_winsor.do has built the winsor panel.
********************************************************************************

version 17.0
set more off

global base      "/Users/luisg/Library/CloudStorage/OneDrive-NorthwesternUniversity/4 - PhD/02_Research/Org_Econ BR/UnionSpillovers/Cluster/UnionSpill"
global rais_firm "$base/Data/CBA_rais_firm_level"
global rais_aux  "$base/Data/RAIS_aux"
global tables    "$base/Tables"
cap mkdir "$tables/winsor"

tempname fh
postfile `fh' str10 sample str14 outcome str10 effect ///
    double(b_post se_post p_post b_pre se_pre p_pre) long(n_obs n_estab) ///
    using "$tables/winsor/winsor_compare_tmp.dta", replace

foreach src in baseline winsor {

    if "`src'" == "baseline" use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear
    else                     use "$rais_firm/winsor/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear
    di as result "================= PANEL SOURCE: `src' ================="

    * ── totalflows merge (for extra_year control) ──────────────────────────────
    preserve
        import delimited "$rais_aux/totalflows_wide_2007_2011.csv", clear
        tostring identificad, replace format(%014.0f) force
        tempfile tfw
        save `tfw'
    restore
    capture confirm string variable identificad
    if _rc tostring identificad, replace format(%014.0f) force
    merge m:1 identificad using `tfw', keep(master match) nogen

    gen double totalflows_pw_pre_07_11 = 0
    gen totalflows_pw_pre_07_11_cnt = 0
    foreach yp in totalflows_pw_07_08 totalflows_pw_08_09 totalflows_pw_09_10 totalflows_pw_10_11 {
        replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 + `yp' if !missing(`yp')
        replace totalflows_pw_pre_07_11_cnt = totalflows_pw_pre_07_11_cnt + (!missing(`yp'))
    }
    replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 / totalflows_pw_pre_07_11_cnt ///
        if totalflows_pw_pre_07_11_cnt > 0
    replace totalflows_pw_pre_07_11 = . if totalflows_pw_pre_07_11_cnt == 0
    drop totalflows_pw_pre_07_11_cnt

    keep if year >= 2009
    keep if lagos_sample_avg == 1

    * ── period indicators ──────────────────────────────────────────────────────
    cap drop placebo_year
    gen byte placebo_year = (year < 2011)
    cap drop treat_year
    gen byte treat_year = (year >= 2012)

    * ── connectivity scaling ───────────────────────────────────────────────────
    local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"
    cap drop totaltreat_pw_n_p90
    cap drop totaltreat_pw_norm
    sum totaltreat_pw_n if `s_spill' & year == 2009, detail
    gen totaltreat_pw_n_p90 = r(p90)
    gen totaltreat_pw_norm = totaltreat_pw_n / totaltreat_pw_n_p90

    * ── pre-treatment means + 4-bin controls ───────────────────────────────────
    cap drop firm_emp_pre_o
    cap drop firm_emp_pre
    bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year,2009,2011)
    bys identificad: egen firm_emp_pre   = min(firm_emp_pre_o)
    drop firm_emp_pre_o
    cap drop l_firm_emp_pre
    gen double l_firm_emp_pre = ln(firm_emp_pre)

    foreach outcome in lr_remdezr_w lr_remdezr_h_w {
        cap drop `outcome'_pre_o
        cap drop `outcome'_pre
        bys identificad: egen `outcome'_pre_o = mean(`outcome') if inrange(year,2009,2011)
        bys identificad: egen `outcome'_pre   = min(`outcome'_pre_o)
        drop `outcome'_pre_o
    }

    cap drop l_firm_emp_pre4_o
    cap drop l_firm_emp_pre4
    egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) if year==2009 & in_balanced_panel==1, group(4)
    bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
    drop l_firm_emp_pre4_o

    foreach v in lr_remdezr_w lr_remdezr_h_w {
        cap drop `v'_pre4_o
        cap drop `v'_pre4
        egen `v'_pre4_o = cut(`v'_pre) if year==2009 & in_balanced_panel==1, group(4)
        bys identificad: egen `v'_pre4 = min(`v'_pre4_o)
        drop `v'_pre4_o
    }

    cap drop totalflows_pw_pre_07_114_o
    cap drop totalflows_pw_pre_07_114
    egen totalflows_pw_pre_07_114_o = cut(totalflows_pw_pre_07_11) if year==2009 & in_balanced_panel==1, group(4)
    bys identificad: egen totalflows_pw_pre_07_114 = min(totalflows_pw_pre_07_114_o)
    drop totalflows_pw_pre_07_114_o
    replace totalflows_pw_pre_07_114 = 0 if missing(totalflows_pw_pre_07_114)

    * ── specs ──────────────────────────────────────────────────────────────────
    local s_direct_A "(treat_ultra==0 & totaltreat_pw_n==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
    local conn       "totaltreat_pw_norm"
    local base_fe    "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
    local extra_year "ib0.totalflows_pw_pre_07_114#i.year"

    foreach outcome in lr_remdezr_w lr_remdezr_h_w {

        local absorb "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"

        * ===== DIRECT (Panel A) =====
        reghdfe `outcome' treat_ultra##i.treat_year if `s_direct_A', ///
            absorb(`absorb') vce(cluster identificad)
        local b_post  = _b[1.treat_ultra#1.treat_year]
        local se_post = _se[1.treat_ultra#1.treat_year]
        local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
        local n_obs   = e(N)
        local n_estab = e(N_clust)
        reghdfe `outcome' treat_ultra##i.placebo_year if `s_direct_A' & year <= 2011, ///
            absorb(`absorb') vce(cluster identificad)
        local b_pre  = _b[1.treat_ultra#1.placebo_year]
        local se_pre = _se[1.treat_ultra#1.placebo_year]
        local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))
        post `fh' ("`src'") ("`outcome'") ("direct_A") (`b_post') (`se_post') (`p_post') (`b_pre') (`se_pre') (`p_pre') (`n_obs') (`n_estab')

        * ===== SPILLOVER =====
        reghdfe `outcome' c.`conn'##i.treat_year if `s_spill', ///
            absorb(`absorb') vce(cluster identificad)
        local b_post  = _b[1.treat_year#c.`conn']
        local se_post = _se[1.treat_year#c.`conn']
        local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
        local n_obs   = e(N)
        local n_estab = e(N_clust)
        reghdfe `outcome' c.`conn'##i.placebo_year if `s_spill' & year <= 2011, ///
            absorb(`absorb') vce(cluster identificad)
        local b_pre  = _b[1.placebo_year#c.`conn']
        local se_pre = _se[1.placebo_year#c.`conn']
        local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))
        post `fh' ("`src'") ("`outcome'") ("spill") (`b_post') (`se_post') (`p_post') (`b_pre') (`se_pre') (`p_pre') (`n_obs') (`n_estab')
    }
}
postclose `fh'

preserve
    use "$tables/winsor/winsor_compare_tmp.dta", clear
    gen stars_post = "***"*(p_post<.01) + "**"*(p_post<.05 & p_post>=.01) + "*"*(p_post<.10 & p_post>=.05)
    order sample outcome effect b_post se_post stars_post p_post b_pre se_pre p_pre n_obs n_estab
    sort outcome effect sample
    export delimited using "$tables/winsor/winsor_compare.csv", replace
    list sample outcome effect b_post se_post stars_post b_pre, sep(0) noobs
restore
erase "$tables/winsor/winsor_compare_tmp.dta"

di "=== compare_winsor.do done -> Tables/winsor/winsor_compare.csv ==="
