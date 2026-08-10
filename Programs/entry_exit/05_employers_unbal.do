********************************************************************************
* PROJECT: UNION SPILLOVERS — ENTRY/EXIT PIPELINE
* AUTHOR: LUIS GOMES
* PROGRAM: AGGREGATE CONNECTIVITY (UNBALANCED) AND BUILD ANALYSIS DATASET
*
* Runs after:
*   041_merge_cba_rais_unbal.do  → produces cba_rais_firm_unbal_2007_2016.dta
*                                   and entry_exit_treat.csv for MATLAB
*   connectivity_treat_unbal.m   → produces connectivity_treat_unbal_2007_2011.csv
*
* The employers_yyyy_yyyy.csv worker-flow files from 1050_yearly_employers.do
* are reused as-is (worker flows do not change).
*
* OUTPUT: $rais_firm/cba_rais_firm_unbal_flows.dta
********************************************************************************

// ── 1. Import treat connectivity and compute aggregate measures ───────────────

import delimited "$rais_aux/connectivity_treat_unbal_2007_2011.csv", clear

// Recover RAIS 14-digit identificad from 15-digit MATLAB string
format identificad1 %21.0f
gen identificad1_s = string(identificad1, "%015.0f")
gen identificad = substr(identificad1_s, 2, 14)
drop identificad1
drop identificad1_s
order identificad

// ── proportion of flows going to treated (NaN-aware, year-pair level) ─────────

foreach yp in "2007_2008" "2008_2009" "2009_2010" "2010_2011" {
    gen flowtreat_pf_`yp'_n = totaltreat_`yp' / totalflows_`yp' ///
        if totalflows_`yp' > 0
}

// Average proportion across year-pairs (NaN-aware)
gen avg_ftreat_pf_n  = 0
gen avg_ftreat_count = 0

foreach yp in "2007_2008" "2008_2009" "2009_2010" "2010_2011" {
    replace avg_ftreat_pf_n  = avg_ftreat_pf_n  + flowtreat_pf_`yp'_n ///
        if !missing(flowtreat_pf_`yp'_n)
    replace avg_ftreat_count = avg_ftreat_count + 1 ///
        if !missing(flowtreat_pf_`yp'_n)
}

replace avg_ftreat_pf_n = avg_ftreat_pf_n / avg_ftreat_count ///
    if avg_ftreat_count > 0
replace avg_ftreat_pf_n = . if avg_ftreat_count == 0
drop avg_ftreat_count

// ── aggregate level flows (sum across year-pairs) ─────────────────────────────

foreach prefix in totalout totalin totalflows outtreat intreat totaltreat {
    ds `prefix'_2*
    local vars `r(varlist)'
    // level only (exclude _pw_ variables)
    local lvars
    foreach v of local vars {
        if strpos("`v'", "_pw_") == 0 local lvars `lvars' `v'
    }
    gen `prefix' = 0
    foreach v of local lvars {
        replace `prefix' = `prefix' + `v'
    }
    // NaN-aware version
    gen `prefix'_n       = 0
    gen `prefix'_count_n = 0
    foreach v of local lvars {
        replace `prefix'_n       = `prefix'_n + `v'       if !missing(`v')
        replace `prefix'_count_n = `prefix'_count_n + 1   if !missing(`v')
    }
    replace `prefix'_n = . if `prefix'_count_n == 0
    drop `prefix'_count_n
}

// ── per-worker averages (NaN-aware) ───────────────────────────────────────────

foreach prefix in totalout totalin totalflows outtreat intreat totaltreat {
    local pw `prefix'_pw
    ds `pw'_2*
    local vars `r(varlist)'

    gen `pw'_n       = 0
    gen `pw'_count_n = 0
    foreach v of local vars {
        replace `pw'_n       = `pw'_n + `v'     if !missing(`v')
        replace `pw'_count_n = `pw'_count_n + 1 if !missing(`v')
    }
    replace `pw'_n = `pw'_n / `pw'_count_n if `pw'_count_n > 0
    replace `pw'_n = . if `pw'_count_n == 0
    drop `pw'_count_n
}

// ── NaN-aware proportion ───────────────────────────────────────────────────────

gen totaltreat_pf_n = totaltreat_n / totalflows_n

save "$rais_aux/connectivity_treat_unbal_agg.dta", replace

// ── 2. Merge connectivity to the unbalanced firm panel ────────────────────────

// The unbalanced panel is a parquet — use Python to do the merge and
// save a .dta; see 05_employers_unbal_merge.py. This do-file expects
// $rais_firm/cba_rais_firm_unbal_flows.dta to already exist.
use "$rais_firm/cba_rais_firm_unbal_flows.dta", clear

// ── 3. Fill connectivity zeros for firms with no pre-period flows ─────────────

foreach var in totalout totalin totalflows outtreat intreat totaltreat ///
               totalout_pw totalin_pw totalflows_pw outtreat_pw intreat_pw totaltreat_pw {
    replace `var' = 0 if `var' == .
}

// ── 4. Derived connectivity measures ─────────────────────────────────────────

gen totaltreat_pf = totaltreat / totalflows

// ── 5. Baseline values and quintiles ─────────────────────────────────────────

local outcomes "l_firm_emp lr_remdezr lr_remmedr"

foreach outcome of local outcomes {
    cap drop `outcome'_2011_a
    cap drop `outcome'_2011
    gen `outcome'_2011_a = `outcome' if year==2011
    bys identificad: egen `outcome'_2011 = max(`outcome'_2011_a)
    drop `outcome'_2011_a
}

// ── 6. Save ───────────────────────────────────────────────────────────────────

save "$rais_firm/cba_rais_firm_unbal_flows.dta", replace
