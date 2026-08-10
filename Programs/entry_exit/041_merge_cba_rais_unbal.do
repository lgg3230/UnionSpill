********************************************************************************
* PROJECT: UNION SPILLOVERS — ENTRY/EXIT PIPELINE
* AUTHOR: LUIS GOMES
* PROGRAM: BUILD UNBALANCED PANEL FROM EXISTING CBA-RAIS MERGE
*
* Rather than re-merging from raw files, this derives the unbalanced panel
* directly from $rais_firm/cba_rais_firm_2007_2016.dta, which was produced
* by the original 1040_merge_cba_rais.do and already contains all CBA
* indicators and RAIS outcomes.
*
* KEY DIFFERENCE vs original 041:
*   lagos_sample_unbal_avg = (cba_pre2012_avg == 1 & cba_post2012_avg == 1)
*   — drops the pos_emp == 1 requirement, so firms that enter or exit during
*     2009-2014 qualify for the sample.
*
* INPUT:  $rais_firm/cba_rais_firm_2007_2016.dta
*
* OUTPUT: $rais_firm/cba_rais_firm_unbal_2009_2016.dta
*         $rais_aux/entry_exit_treat.csv   (for MATLAB)
********************************************************************************

use "$rais_firm/cba_rais_firm_2007_2016.dta", clear

// Keep analysis years only
keep if inrange(year, 2009, 2016)

// ── Unbalanced lagos sample: CBA conditions only, no pos_emp ─────────────────
//
// The original cba_rais_firm_2007_2016.dta already contains cba_pre2012_avg
// and cba_post2012_avg (generated inside 041 within the foreach filedate loop).
// We just define the new indicator without the pos_emp requirement.

gen lagos_sample_unbal_avg = (cba_pre2012_avg == 1 & cba_post2012_avg == 1)

// ── Treatment indicator for connectivity ─────────────────────────────────────

gen lagos_treat_unbal = (lagos_sample_unbal_avg == 1 & treat_ultra == 1)

// ── Export CSV for MATLAB ─────────────────────────────────────────────────────

preserve
    collapse (first) lagos_treat_unbal, by(identificad)
    gen identificad1 = "1" + identificad
    drop identificad
    rename identificad1 identificad
    export delimited "$rais_aux/entry_exit_treat.csv", replace
restore

// ── Save unbalanced panel ─────────────────────────────────────────────────────

save "$rais_firm/cba_rais_firm_unbal_2009_2016.dta", replace
