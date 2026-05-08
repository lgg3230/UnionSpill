********************************************************************************
* treated_cba_similarity_pretreat_ref_uncorr_w.do
*
* MIRROR of treated_cba_similarity.do, with the similarity outcome computed
* against a FIXED pre-treatment reference vector (untreated partners' clauses
* in cba_period == 2) instead of a moving same-period reference.
*
* For each (treated firm i, cba_period t):
*   sim_{it} = sim(x_{it}, ref_i)
* where ref_i = Sigma_{j in U(i)} w_{ij} * x_{j,2} / Sigma_{j in U(i)} w_{ij}
* j ranges over UNTREATED firms with bilateral flows to i (w_{ij}, focal-firm
* corrected per-worker connectivity averaged across 2007-2011 year-pairs).
*
* Pipeline:
*   1. Load + setup variables (mirrors treated_cba_similarity.do)
*   2. Export intermediate clause data for Python (cba_clauses_by_period_treated.dta)
*   3. Python computes pretreat reference + similarities
*      (treated_cba_similarity_pretreat_ref_uncorr_w_prep.py)
*   4. Merge similarity panel and run panel regressions
*
* Output:
*   Tables/cba_similarity/results_spill_treated_pretreat_ref_uncorr_w_cba_similarity.csv
*   Tables/cba_similarity/results_spill_treated_pretreat_ref_uncorr_w_ln_cba_similarity.csv
*   Tables/cba_similarity/treated_pretreat_ref_uncorr_w_cba_similarity_table.tex
*   Tables/cba_similarity/treated_pretreat_ref_uncorr_w_ln_cba_similarity_table.tex
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
cap mkdir "$logs/cba_similarity"
log using "$logs/cba_similarity/treated_cba_similarity_pretreat_ref_uncorr_w_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
di "Stata version: `c(stata_version)'"

cap mkdir "$tables/cba_similarity"

********************************************************************************
* SECTION 1: LOAD DATA + MERGE TOTALFLOWS
********************************************************************************

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

preserve
    import delimited "$rais_aux/totalflows_wide_2007_2011.csv", clear
    tostring identificad, replace format(%014.0f) force
    tempfile totalflows_wide
    save `totalflows_wide'
restore

merge m:1 identificad using `totalflows_wide', keep(master match) nogen

gen double totalflows_pw_pre_07_11 = 0
gen        totalflows_pw_pre_07_11_cnt = 0
foreach yp in totalflows_pw_07_08 totalflows_pw_08_09 totalflows_pw_09_10 totalflows_pw_10_11 {
    replace totalflows_pw_pre_07_11     = totalflows_pw_pre_07_11 + `yp' if !missing(`yp')
    replace totalflows_pw_pre_07_11_cnt = totalflows_pw_pre_07_11_cnt + (!missing(`yp'))
}
replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 / totalflows_pw_pre_07_11_cnt ///
    if totalflows_pw_pre_07_11_cnt > 0
replace totalflows_pw_pre_07_11 = . if totalflows_pw_pre_07_11_cnt == 0
drop totalflows_pw_pre_07_11_cnt

keep if year >= 2009

* Keep BOTH the treated balanced-panel firms (regression sample) AND
* lagos-sample untreated firms (to serve as the reference pool in the prep).
keep if (treat_ultra == 1 & in_balanced_panel == 1) ///
     |  (treat_ultra == 0 & lagos_sample_avg == 1)

di as result "Sample size after restrictions: " _N

********************************************************************************
* SECTION 2: VARIABLE CREATION
********************************************************************************

cap drop cba_period
cap drop pre_treat_cba
cap drop post_treat_cba

gen cba_period = .
replace cba_period = 1 if avg_file_date == earliest2009_avg - 1 & !missing(avg_file_date)
replace cba_period = 2 if avg_file_date == second_cba_avg & !missing(avg_file_date)
replace cba_period = 3 if inrange(avg_file_date, mdy(1,1,2013), mdy(12,31,2013)) & cba_period == .
replace cba_period = 4 if inrange(avg_file_date, mdy(1,1,2014), mdy(12,31,2014)) & cba_period == .
replace cba_period = 5 if inrange(avg_file_date, mdy(1,1,2015), mdy(12,31,2015)) & cba_period == .
replace cba_period = 6 if inrange(avg_file_date, mdy(1,1,2016), mdy(12,31,2016)) & cba_period == .
label var cba_period "CBA negotiation period"

gen pre_treat_cba  = cond(cba_period < 2,  1, 0)
gen post_treat_cba = cond(cba_period >= 3, 1, 0) if !missing(cba_period)

* Sample for the regression: treated balanced-panel firms only
local s_treat "treat_ultra==1 & in_balanced_panel==1"

********************************************************************************
* SECTION 3: PRE-TREATMENT CONTROLS — l_firm_emp_pre, numb_clauses_pre
********************************************************************************

cap drop firm_emp_pre_o
cap drop firm_emp_pre
quietly {
    bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
    bys identificad: egen firm_emp_pre   = min(firm_emp_pre_o)
    drop firm_emp_pre_o
}

cap drop l_firm_emp_pre
gen double l_firm_emp_pre = ln(firm_emp_pre)
label var l_firm_emp_pre "Log pre-treatment firm employment"

cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
quietly {
    egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) if year == 2009 & `s_treat', group(4)
    bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
    drop l_firm_emp_pre4_o
}

cap drop numb_clauses_pre_o
cap drop numb_clauses_pre
quietly {
    bys identificad: egen numb_clauses_pre_o = mean(numb_clauses) if inrange(cba_period, 1, 2)
    bys identificad: egen numb_clauses_pre   = min(numb_clauses_pre_o)
    drop numb_clauses_pre_o
}

cap drop numb_clauses_pre4_o
cap drop numb_clauses_pre4
quietly {
    egen numb_clauses_pre4_o = cut(numb_clauses_pre) if year == 2009 & `s_treat', group(4)
    bys identificad: egen numb_clauses_pre4 = min(numb_clauses_pre4_o)
    drop numb_clauses_pre4_o
}

cap drop totalflows_pw_pre_07_114_o
cap drop totalflows_pw_pre_07_114
quietly {
    egen totalflows_pw_pre_07_114_o = cut(totalflows_pw_pre_07_11) ///
        if year == 2009 & `s_treat', group(4)
    bys identificad: egen totalflows_pw_pre_07_114 = min(totalflows_pw_pre_07_114_o)
    drop totalflows_pw_pre_07_114_o
    replace totalflows_pw_pre_07_114 = 0 if missing(totalflows_pw_pre_07_114)
}

********************************************************************************
* SECTION 4: EXPORT INTERMEDIATE CLAUSE DATA FOR PYTHON
********************************************************************************

di as result "Exporting clause data for Python..."

ds cl_*
local clause_vars `r(varlist)'

preserve
    keep if !missing(cba_period)
    keep identificad cba_period treat_ultra lagos_sample_avg in_balanced_panel `clause_vars'
    foreach v of local clause_vars {
        replace `v' = 0 if missing(`v')
    }
    save "$rais_aux/cba_clauses_by_period_treated.dta", replace
restore

di as result "Clause data exported."

********************************************************************************
* SECTION 5: RUN PYTHON PREP SCRIPT
********************************************************************************

di as result "Running Python pretreat-ref similarity prep (treated mirror)..."
shell ~/.conda/envs/venv_python312/bin/python "$programs/cba_similarity/treated_cba_similarity_pretreat_ref_uncorr_w_prep.py"
di as result "Python prep complete."

********************************************************************************
* SECTION 6: MERGE SIMILARITY PANEL + CONNECTIVITY
********************************************************************************

* Similarity (treated firm × cba_period level)
merge m:1 identificad cba_period using "$rais_aux/treated_cba_similarity_pretreat_ref_uncorr_w_panel.dta", ///
    keep(master match) gen(m_sim)
drop m_sim

* Connectivity to untreated/control (firm-level, time-invariant) — official
* MATLAB-built measure that mirrors totaltreat_pw_n exactly.
preserve
    use "$rais_aux/connectivity_control_2007_2011_agg.dta", clear
    keep identificad totalcontrol_pw_n
    tempfile control_conn
    save `control_conn'
restore

merge m:1 identificad using `control_conn', keep(master match) gen(m_conn)
drop m_conn
replace totalcontrol_pw_n = 0 if missing(totalcontrol_pw_n)

label var cosine          "Cosine similarity to fixed pre-treat untreated avg"
label var bray_curtis     "Bray-Curtis similarity to fixed pre-treat untreated avg"
label var total_variation "Total variation similarity to fixed pre-treat untreated avg"
label var ruzicka         "Ruzicka similarity to fixed pre-treat untreated avg"
label var totalcontrol_pw_n "Per-worker total flows to control firms (2007-2011 avg)"

local sim_outcomes "cosine bray_curtis total_variation ruzicka"

di as result "Treated firm-period obs with similarity:"
foreach v of local sim_outcomes {
    count if !missing(`v') & `s_treat'
    di as text "  `v': " r(N)
}

* Connectivity normalized to 90th percentile in treated balanced panel at year=2009
cap drop totalcontrol_pw_n_p90
cap drop totalcontrol_pw_norm
sum totalcontrol_pw_n if `s_treat' & year == 2009, detail
gen totalcontrol_pw_n_p90 = r(p90)
label var totalcontrol_pw_n_p90 "p90 of totalcontrol_pw_n (treated balanced panel, 2009)"
gen totalcontrol_pw_norm = totalcontrol_pw_n / totalcontrol_pw_n_p90
label var totalcontrol_pw_norm "Connectivity to control, scaled to p90"

di as result "Connectivity normalization: p90 = " %9.4f r(p90)

********************************************************************************
* SECTION 7: PRE-TREATMENT BASELINE BINS FOR SIMILARITY OUTCOMES
********************************************************************************

foreach v of local sim_outcomes {
    cap drop `v'_pre_o
    cap drop `v'_pre
    quietly {
        bys identificad: egen `v'_pre_o = mean(`v') if inrange(cba_period, 1, 2)
        bys identificad: egen `v'_pre   = min(`v'_pre_o)
        drop `v'_pre_o
    }

    cap drop `v'_pre4_o
    cap drop `v'_pre4
    quietly {
        egen `v'_pre4_o = cut(`v'_pre) if year == 2009 & `s_treat', group(4)
        bys identificad: egen `v'_pre4 = min(`v'_pre4_o)
        drop `v'_pre4_o
        replace `v'_pre4 = 0 if missing(`v'_pre4)
    }
}

* Log similarity outcomes
foreach v of local sim_outcomes {
    cap drop ln_`v'
    gen double ln_`v' = ln(`v') if `v' > 0
    label var ln_`v' "Log `v' similarity"
}

local ln_sim_outcomes "ln_cosine ln_bray_curtis ln_total_variation ln_ruzicka"

di as result "Treated firm-period obs with log similarity (zeros dropped):"
foreach v of local ln_sim_outcomes {
    count if !missing(`v') & `s_treat'
    di as text "  `v': " r(N)
}

foreach v of local ln_sim_outcomes {
    cap drop `v'_pre_o
    cap drop `v'_pre
    quietly {
        bys identificad: egen `v'_pre_o = mean(`v') if inrange(cba_period, 1, 2)
        bys identificad: egen `v'_pre   = min(`v'_pre_o)
        drop `v'_pre_o
    }
    cap drop `v'_pre4_o
    cap drop `v'_pre4
    quietly {
        egen `v'_pre4_o = cut(`v'_pre) if year == 2009 & `s_treat', group(4)
        bys identificad: egen `v'_pre4 = min(`v'_pre4_o)
        drop `v'_pre4_o
        replace `v'_pre4 = 0 if missing(`v'_pre4)
    }
}

********************************************************************************
* SECTION 8: SPEC MACROS
********************************************************************************

local spec              "treated_pretreat_ref_uncorr_w_cba_similarity_tfpw_07_11"
local conn              "totalcontrol_pw_norm"
local base_fe_cba       "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period"
local base_fe_cba_union "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period i.mode_union#i.cba_period"
local extra_cba         "ib0.totalflows_pw_pre_07_114#i.cba_period"

********************************************************************************
* SECTION 9: INITIALIZE OUTPUT CSVs
********************************************************************************

capture erase "$tables/cba_similarity/results_spill_treated_pretreat_ref_uncorr_w_cba_similarity.csv"
tempname fh
file open `fh' using "$tables/cba_similarity/results_spill_treated_pretreat_ref_uncorr_w_cba_similarity.csv", write replace
file write `fh' "spec;section;outcome;row_type;value" _n
file close `fh'

capture erase "$tables/cba_similarity/results_spill_treated_pretreat_ref_uncorr_w_ln_cba_similarity.csv"
tempname fh
file open `fh' using "$tables/cba_similarity/results_spill_treated_pretreat_ref_uncorr_w_ln_cba_similarity.csv", write replace
file write `fh' "spec;section;outcome;row_type;value" _n
file close `fh'

********************************************************************************
* SECTION 10: RECIPROCAL EFFECTS — LEVELS
********************************************************************************

di _newline(2)
di as result "-----------------------------------------------------------------------"
di as result "RECIPROCAL EFFECTS (TREATED → UNTREATED PRE-TREAT REFERENCE)"
di as result "-----------------------------------------------------------------------"

local csv_spill "$tables/cba_similarity/results_spill_treated_pretreat_ref_uncorr_w_cba_similarity.csv"

foreach fe_variant in base union {
    if "`fe_variant'" == "base" {
        local cur_base_fe "`base_fe_cba'"
        local cur_spec    "`spec'"
    }
    else {
        local cur_base_fe "`base_fe_cba_union'"
        local cur_spec    "`spec'_union"
    }

    foreach outcome of local sim_outcomes {

        di as text "  Estimating: `outcome' (treated mirror, pretreat-ref, `fe_variant')"

        local absorb_cba "`cur_base_fe' ib0.`outcome'_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

        reghdfe `outcome' c.`conn'##post_treat_cba ///
            if `s_treat' & !missing(cba_period) & !missing(`outcome'), ///
            absorb(`absorb_cba') vce(cluster identificad)

        local b_post  = _b[1.post_treat_cba#c.`conn']
        local se_post = _se[1.post_treat_cba#c.`conn']
        local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
        local n_obs   = e(N)
        local n_estab = e(N_clust)

        qui sum `outcome' if e(sample) & cba_period == 2
        local base_mean = cond(r(N) > 0, r(mean), .)

        reghdfe `outcome' c.`conn'##pre_treat_cba ///
            if `s_treat' & !missing(cba_period) & cba_period <= 2 & !missing(`outcome'), ///
            absorb(`absorb_cba') vce(cluster identificad)

        local b_pre  = _b[1.pre_treat_cba#c.`conn']
        local se_pre = _se[1.pre_treat_cba#c.`conn']
        local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

        local stars_post ""
        if `p_post' < 0.01                           local stars_post "***"
        else if (`p_post' < 0.05 & `p_post' > 0.01) local stars_post "**"
        else if (`p_post' < 0.10 & `p_post' > 0.05) local stars_post "*"

        local stars_pre ""
        if `p_pre' < 0.01                            local stars_pre "***"
        else if (`p_pre' < 0.05 & `p_pre' > 0.01)   local stars_pre "**"
        else if (`p_pre' < 0.10 & `p_pre' > 0.05)   local stars_pre "*"

        reghdfe `outcome' c.`conn'##ib2.cba_period ///
            if `s_treat' & !missing(cba_period) & !missing(`outcome'), ///
            absorb(`absorb_cba') vce(cluster identificad)
        testparm c.`conn'#1.cba_period
        local pre_ftest_pval = r(p)

        tempname fh
        file open `fh' using "`csv_spill'", write append
        file write `fh' `""`cur_spec'";"spill";"`outcome'";"main";"'   %9.4f (`b_post') `"`stars_post'"' _n
        file write `fh' `""`cur_spec'";"spill";"`outcome'";"main_se";"' %9.4f (`se_post') _n
        file write `fh' `""`cur_spec'";"spill";"`outcome'";"pre";"'    %9.4f (`b_pre') `"`stars_pre'"'  _n
        file write `fh' `""`cur_spec'";"spill";"`outcome'";"pre_se";"'  %9.4f (`se_pre') _n
        file write `fh' `""`cur_spec'";"spill";"`outcome'";"baseline_mean";"' %9.4f (`base_mean') _n
        file write `fh' `""`cur_spec'";"spill";"`outcome'";"n_obs";"'   %12.0fc (`n_obs') _n
        file write `fh' `""`cur_spec'";"spill";"`outcome'";"n_estab";"' %12.0fc (`n_estab') _n
        file write `fh' `""`cur_spec'";"spill";"`outcome'";"pre_pval";"' %9.4f (`pre_ftest_pval') _n
        file close `fh'
    }
}

di as result _newline "Level regressions complete."

********************************************************************************
* SECTION 11: RECIPROCAL EFFECTS — LOG SIMILARITY
********************************************************************************

di _newline(2)
di as result "-----------------------------------------------------------------------"
di as result "RECIPROCAL EFFECTS — LOG SIMILARITY (PRETREAT REFERENCE)"
di as result "-----------------------------------------------------------------------"

local spec_ln "treated_pretreat_ref_uncorr_w_ln_cba_similarity_tfpw_07_11"
local csv_ln  "$tables/cba_similarity/results_spill_treated_pretreat_ref_uncorr_w_ln_cba_similarity.csv"

foreach fe_variant in base union {
    if "`fe_variant'" == "base" {
        local cur_base_fe "`base_fe_cba'"
        local cur_spec_ln "`spec_ln'"
    }
    else {
        local cur_base_fe "`base_fe_cba_union'"
        local cur_spec_ln "`spec_ln'_union"
    }

    foreach outcome of local ln_sim_outcomes {

        di as text "  Estimating: `outcome' (treated mirror, log, pretreat-ref, `fe_variant')"

        local absorb_cba "`cur_base_fe' ib0.`outcome'_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

        reghdfe `outcome' c.`conn'##post_treat_cba ///
            if `s_treat' & !missing(cba_period) & !missing(`outcome'), ///
            absorb(`absorb_cba') vce(cluster identificad)

        local b_post  = _b[1.post_treat_cba#c.`conn']
        local se_post = _se[1.post_treat_cba#c.`conn']
        local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
        local n_obs   = e(N)
        local n_estab = e(N_clust)

        qui sum `outcome' if e(sample) & cba_period == 2
        local base_mean = cond(r(N) > 0, r(mean), .)

        reghdfe `outcome' c.`conn'##pre_treat_cba ///
            if `s_treat' & !missing(cba_period) & cba_period <= 2 & !missing(`outcome'), ///
            absorb(`absorb_cba') vce(cluster identificad)

        local b_pre  = _b[1.pre_treat_cba#c.`conn']
        local se_pre = _se[1.pre_treat_cba#c.`conn']
        local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

        local stars_post ""
        if `p_post' < 0.01                           local stars_post "***"
        else if (`p_post' < 0.05 & `p_post' > 0.01) local stars_post "**"
        else if (`p_post' < 0.10 & `p_post' > 0.05) local stars_post "*"

        local stars_pre ""
        if `p_pre' < 0.01                            local stars_pre "***"
        else if (`p_pre' < 0.05 & `p_pre' > 0.01)   local stars_pre "**"
        else if (`p_pre' < 0.10 & `p_pre' > 0.05)   local stars_pre "*"

        reghdfe `outcome' c.`conn'##ib2.cba_period ///
            if `s_treat' & !missing(cba_period) & !missing(`outcome'), ///
            absorb(`absorb_cba') vce(cluster identificad)
        testparm c.`conn'#1.cba_period
        local pre_ftest_pval = r(p)

        tempname fh
        file open `fh' using "`csv_ln'", write append
        file write `fh' `""`cur_spec_ln'";"spill";"`outcome'";"main";"'   %9.4f (`b_post') `"`stars_post'"' _n
        file write `fh' `""`cur_spec_ln'";"spill";"`outcome'";"main_se";"' %9.4f (`se_post') _n
        file write `fh' `""`cur_spec_ln'";"spill";"`outcome'";"pre";"'    %9.4f (`b_pre') `"`stars_pre'"'  _n
        file write `fh' `""`cur_spec_ln'";"spill";"`outcome'";"pre_se";"'  %9.4f (`se_pre') _n
        file write `fh' `""`cur_spec_ln'";"spill";"`outcome'";"baseline_mean";"' %9.4f (`base_mean') _n
        file write `fh' `""`cur_spec_ln'";"spill";"`outcome'";"n_obs";"'   %12.0fc (`n_obs') _n
        file write `fh' `""`cur_spec_ln'";"spill";"`outcome'";"n_estab";"' %12.0fc (`n_estab') _n
        file write `fh' `""`cur_spec_ln'";"spill";"`outcome'";"pre_pval";"' %9.4f (`pre_ftest_pval') _n
        file close `fh'
    }
}

di as result _newline "Log regressions complete."

********************************************************************************
* SECTION 12: COMPLETION + AUTO-RUN PYTHON FOR LATEX TABLES
********************************************************************************

log close

shell ~/.conda/envs/venv_python312/bin/python "$programs/cba_similarity/generate_treated_pretreat_ref_uncorr_w_similarity_latex.py"
shell ~/.conda/envs/venv_python312/bin/python "$programs/cba_similarity/generate_treated_pretreat_ref_uncorr_w_ln_similarity_latex.py"

shell source "$programs/notify.sh" && notify "treated_cba_similarity_pretreat_ref_uncorr_w done" "Treated mirror pretreat-ref similarity regressions and tables complete"
