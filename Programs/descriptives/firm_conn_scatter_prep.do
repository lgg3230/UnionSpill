********************************************************************************
* Program:  firm_conn_scatter_prep.do
* Purpose:  Firm-level frame relating connectivity-to-treated to pre-treatment
*           (2009-2011) firm characteristics, for descriptive scatter/binscatter
*           plots + a connectivity histogram. Produces SEPARATE control and
*           treated firm sets. Y-variables are 2011 values (not 2009-2011 means).
* Sample matching: the CONTROL (spillover) set is restricted to the e(sample) of
*           the headline spillover log-wage event study from
*           4012_pct_tfpw.do (so it matches the ~4,085-firm
*           estimation sample, not a looser balance-panel count). The TREATED set
*           is treated firms in the balanced Lagos panel with non-missing wages.
* Characteristics: lr_remdezr_w (log wages), l_firm_emp (log emp),
*           turnover=turnover_u (separation rate), hiring=hiring_rate_u,
*           churn=(sep+hire)/avg_emp, retention=retention_u,
*           prop_female=1-male_prop, prop_non_white=1-white_prop.
* Output:   Tables/descriptives/firm_conn_scatter.csv (cols: identificad,
*           treat_ultra, in_spill, totaltreat_pw_n + 8 characteristics)
********************************************************************************

version 17.0
set more off

global base "/Users/luisg/Library/CloudStorage/OneDrive-NorthwesternUniversity/4 - PhD/02_Research/Org_Econ BR/UnionSpillovers/Cluster/UnionSpill"
global rais_firm "$base/Data/CBA_rais_firm_level"
global rais_aux  "$base/Data/RAIS_aux"
global tables    "$base/Tables"

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear
keep if year >= 2009
keep if lagos_sample_avg == 1

* ============================ CONNECTIVITY (normalized) =======================
local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"
cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen totaltreat_pw_n_p90 = r(p90)
gen totaltreat_pw_norm  = totaltreat_pw_n / totaltreat_pw_n_p90

* ============================ CONTROLS (to reproduce e(sample)) ===============
cap drop firm_emp_pre_o
cap drop firm_emp_pre
bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year,2009,2011)
bys identificad: egen firm_emp_pre   = min(firm_emp_pre_o)
drop firm_emp_pre_o
cap drop l_firm_emp_pre
gen double l_firm_emp_pre = ln(firm_emp_pre)

cap drop lr_remdezr_w_pre_o
cap drop lr_remdezr_w_pre
bys identificad: egen lr_remdezr_w_pre_o = mean(lr_remdezr_w) if inrange(year,2009,2011)
bys identificad: egen lr_remdezr_w_pre   = min(lr_remdezr_w_pre_o)
drop lr_remdezr_w_pre_o

cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) if year==2009 & in_balanced_panel==1, group(4)
bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
drop l_firm_emp_pre4_o

cap drop lr_remdezr_w_pre4_o
cap drop lr_remdezr_w_pre4
egen lr_remdezr_w_pre4_o = cut(lr_remdezr_w_pre) if year==2009 & in_balanced_panel==1, group(4)
bys identificad: egen lr_remdezr_w_pre4 = min(lr_remdezr_w_pre4_o)
drop lr_remdezr_w_pre4_o

* NOTE: the headline spec also absorbs ib0.totalflows_pw_pre_07_114#i.year, but
* that control is built from an upstream year-pair-flows merge not in this
* dataset and is ZERO-FILLED when missing (Main_Results line 216), so it adds FE
* cells without dropping observations -> omitting it leaves e(sample) essentially
* unchanged. Dropped here to keep the sample-reproduction self-contained.

* ============================ SPILLOVER WAGE e(SAMPLE) ========================
local conn       "totaltreat_pw_norm"
local base_fe    "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local absorb     "`base_fe' ib0.lr_remdezr_w_pre4#i.year ib0.l_firm_emp_pre4#i.year"

reghdfe lr_remdezr_w c.`conn'##ib2011.year if `s_spill', ///
    absorb(`absorb') vce(cluster identificad)

cap drop espill
gen byte espill = e(sample)
cap drop in_spill
bys identificad: egen byte in_spill = max(espill)
di "==== unique establishments in spillover wage e(sample): ===="
preserve
    keep if espill==1
    egen tag = tag(identificad)
    count if tag==1
restore

* treated set flag: treated, balanced Lagos panel, non-missing wage
cap drop in_treat
gen byte in_treat = (treat_ultra==1 & in_balanced_panel==1 & !missing(lr_remdezr_w))

* ============================ MERGE CORRECTED TURNOVER ========================
preserve
    import delimited "$rais_aux/corrected_turnover_sample.csv", clear
    keep identificad year turnover_u retention_u hiring_rate_u separations_u hired_u avg_emp
    tostring identificad, replace format(%014.0f) force
    gen double churn  = (separations_u + hired_u)/avg_emp if avg_emp>0 & !missing(avg_emp)
    rename turnover_u   turnover
    rename retention_u  retention
    rename hiring_rate_u hiring
    keep identificad year turnover retention hiring churn
    tempfile turn
    save `turn'
restore
merge 1:1 identificad year using `turn', keep(master match) nogen

* composition shares
gen double prop_female    = 1 - male_prop
gen double prop_non_white = 1 - white_prop

* ============================ 2011 CROSS-SECTION =============================
* y-variables are taken at year == 2011 (one obs per balanced-panel firm), NOT
* averaged over 2009-2011. Connectivity is the time-invariant pre-reform measure
* (firm max, robust to any single-year missingness).
cap drop conn_firm
bys identificad: egen double conn_firm = max(totaltreat_pw_n)
keep if year == 2011
replace totaltreat_pw_n = conn_firm

keep identificad treat_ultra in_spill in_treat totaltreat_pw_n ///
     lr_remdezr_w l_firm_emp turnover hiring churn retention prop_female prop_non_white
order identificad treat_ultra in_spill in_treat totaltreat_pw_n ///
      lr_remdezr_w l_firm_emp turnover hiring churn retention prop_female prop_non_white

di "==== firm-level frame ===="
count
di "control / spillover e(sample) firms:"
count if in_spill==1
di "treated set firms:"
count if in_treat==1

export delimited using "$tables/descriptives/firm_conn_scatter.csv", replace
di "=== firm_conn_scatter_prep.do done ==="
