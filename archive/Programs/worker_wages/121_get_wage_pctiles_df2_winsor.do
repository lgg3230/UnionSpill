********************************************************************************
* PROJECT: UNION SPILLOVERS                                            (Task 4)
* PROGRAM: 121_get_wage_pctiles_df2_winsor.do
* PURPOSE: Winsorization-robustness variant of 121_get_wage_pctiles_df2.do.
*          Winsorizes WORKER-LEVEL log wages at the 1st/99th pctile WITHIN YEAR
*          BEFORE aggregating to the firm level, then rebuilds the firm panel.
* OUTPUT:  $rais_firm/winsor/lagos_sample_sep24_pct_unionexp_ext_df2.dta
*          (separate folder -> CANNOT overwrite the canonical firm panel)
* NOTE:    Winsorizing the log wage at 1/99 is identical to winsorizing the wage
*          level at 1/99 (monotone transform caps the same observations).
********************************************************************************

version 17.0
set more off

global base      "/Users/luisg/Library/CloudStorage/OneDrive-NorthwesternUniversity/4 - PhD/02_Research/Org_Econ BR/UnionSpillovers/Cluster/UnionSpill"
global rais_firm "$base/Data/CBA_rais_firm_level"
cap mkdir "$rais_firm/winsor"

use "$rais_firm/worker_year_pre_new_vs_nonnew_dec26.dta", clear

keep if year>=2009

tostring year, generate(year_st)
gen cnpj_year = identificad_w + "_" + year_st

rename r_remdezr_h_w lr_remdezr_h_w
gen r_remdezr_h_w = exp(lr_remdezr_h_w)
label var r_remdezr_h_w "worker's dec wages, deflated to 2015 prices"

gen lr_remmedr_h_w = log(r_remmedr_h_w)
label var lr_remmedr_h_w "log worker's average wages (over the year), deflated to 2015 prices"

* ============================ WINSORIZE (1/99 within year) ====================
* worker-level log wages, capped at the within-year 1st and 99th percentiles
local wvars lr_remdezr_w lr_remmedr_w lr_remdezr_h_w lr_remmedr_h_w
foreach v of local wvars {
    cap drop `v'_wlo
    cap drop `v'_whi
    egen double `v'_wlo = pctile(`v'), by(year) p(1)
    egen double `v'_whi = pctile(`v'), by(year) p(99)
    replace `v' = `v'_wlo if `v' < `v'_wlo & !missing(`v')
    replace `v' = `v'_whi if `v' > `v'_whi & !missing(`v')
    drop `v'_wlo
    drop `v'_whi
}
* keep r_remdezr_h_w (level) consistent with the winsorized log
replace r_remdezr_h_w = exp(lr_remdezr_h_w)

local log_wages "lr_remdezr_w lr_remmedr_w lr_remdezr_h_w lr_remmedr_h_w"

foreach y of local log_wages{
foreach q in 10 20 25 50 75 80 90 {

    cap drop `y'_p`q'
    egen `y'_p`q' = pctile(`y'), by(cnpj_year) p(`q')
    label var `y'_p`q' "`y': p`q' by cnpj_year"

}
}

collapse (firstnm) identificad_w year lr_remdezr_w_p10 lr_remdezr_w_p20 lr_remdezr_w_p25 lr_remdezr_w_p50 lr_remdezr_w_p75 lr_remdezr_w_p80 lr_remdezr_w_p90 lr_remmedr_w_p10 lr_remmedr_w_p20 lr_remmedr_w_p25 lr_remmedr_w_p50 lr_remmedr_w_p75 lr_remmedr_w_p80 lr_remmedr_w_p90 lr_remdezr_h_w_p10 lr_remdezr_h_w_p20 lr_remdezr_h_w_p25 lr_remdezr_h_w_p50 lr_remdezr_h_w_p75 lr_remdezr_h_w_p80 lr_remdezr_h_w_p90 lr_remmedr_h_w_p10 lr_remmedr_h_w_p20 lr_remmedr_h_w_p25 lr_remmedr_h_w_p50 lr_remmedr_h_w_p75 lr_remmedr_h_w_p80 lr_remmedr_h_w_p90 (mean) lr_remdezr_w lr_remmedr_w lr_remdezr_h_w lr_remmedr_h_w r_remdezr_h_w, by(cnpj_year)

count if missing(lr_remdezr_w)

rename identificad_w identificad

mmerge identificad year using "$rais_firm/lagos_sample_sep24_pct_unionexp.dta", type(1:1)

save "$rais_firm/winsor/lagos_sample_sep24_pct_unionexp_ext_df2.dta", replace

di "=== 121_get_wage_pctiles_df2_winsor.do done -> winsor/ panel saved ==="
