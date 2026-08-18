********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR:  LUIS GOMES
* PROGRAM: GET WAGE PERCENTILES AND MERGE BACK INTO FIRM LEVEL DATASET
* INPUTS: WORKER-LEVEL DATASET RESTRICTED TO LAGOS SAMPLE
* OUTPUTS: FIRM-LEVEL DATASET WITH WAGE PERCENTILES
********************************************************************************

use "$rais_firm/worker_year_pre_new_vs_nonnew_dec26.dta", clear

keep if year>=2009

tostring year, generate(year_st)

gen cnpj_year = identificad_w + "_" + year_st

rename r_remdezr_h_w lr_remdezr_h_w

gen r_remdezr_h_w = exp(lr_remdezr_h_w)
label var r_remdezr_h_w "worker's dec wages, deflated to 2015 prices"

gen lr_remmedr_h_w = log(r_remmedr_h_w)
label var lr_remmedr_h_w "log worker's average wages (over the year), deflated to 2015 prices"


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


* mmerge (community command, ~/ado/plus) aborts here with a glibc
* "corrupted size vs. prev_size" heap corruption on this data. Native
* merge 1:1 is equivalent for our purposes -- mmerge's default is
* unmatched(both) and it creates _merge with the same 1/2/3 coding, and
* _merge is carried into the published panel so it must survive.
* Reproduce mmerge's _merge handling. Native merge raises r(110) here
* because BOTH sides carry _merge: the master from 2010's merge, and
* the using Lagos panel from its own build. Dropping the master's copy
* is not enough. So: merge under a temporary flag name, drop the copy
* the using side brings in as data, then rename the fresh flag to
* _merge -- which is what mmerge left behind and what the published
* panel carries.
cap drop _merge
cap drop _mg_tmp
* keep(master match): the analysis panel is the firm-years that HAVE worker
* data, i.e. 2009-2016. The using side additionally carries 2007-2008,
* which the worker panel does not cover. Keeping them would give 174,110
* rows against the published 140,773.
merge 1:1 identificad year using "$rais_firm/lagos_sample_sep24_pct_unionexp.dta", keep(master match) generate(_mg_tmp)
cap drop _merge
rename _mg_tmp _merge

* Output is caller-overridable. The tier-B rebuild points this at a scratch
* path so the frozen panel survives as the comparison baseline; it is the
* only artifact that can tell us whether the rebuild reproduces the paper.
if "$panel_out" == "" ///
    global panel_out "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta"
* ZERO RULE, enforced at panel build. 1050 now applies this at the connectivity
* merge, but a panel built from an older 1050 output would still carry missing
* connectivity for the two firms absent from the treat aggregate, and the
* direct-effect samples test totaltreat_pw_n exactly. Idempotent once 1050 has
* been re-run. See the note in 1040_yearly_employers.do.
quietly count if mi(totaltreat_pw_n)
if r(N) > 0 {
    di as text "[zero rule] filling `r(N)' firm-years of missing totaltreat_pw_n"
    replace totaltreat_pw_n = 0 if mi(totaltreat_pw_n)
}
quietly count if mi(totaltreat_pw_n)
assert r(N) == 0

* NORMALIZED CONNECTIVITY -- presence, not value.
* The frozen analysis panel carries totaltreat_pw_n_p90 and totaltreat_pw_norm;
* neither the Lagos firm panel nor this rebuild creates them, so the rebuilt
* panel lacked both and 3122_within_firm died with r(111): its keep list at :213
* names totaltreat_pw_norm, even though :255 drops and regenerates it.
*
* The stored VALUE is vestigial. Every estimator that uses the variable also
* creates it -- 4012:148, 4032:156, 4042, 4052, 4062, 4072, 4082, 4092:118,
* 4112:127, 4122:255, 4132 -- so nothing downstream reads what is written here.
* Checked across all 13 estimators: none consumes it without first recomputing.
* It is created so the panel is a drop-in for the overlay.
cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
preserve
    quietly keep if lagos_sample_avg == 1 & treat_ultra == 0 ///
        & in_balanced_panel == 1 & year == 2009 & !mi(totaltreat_pw_n)
    quietly _pctile totaltreat_pw_n, p(90)
    local p90_conn = r(r1)
restore
gen double totaltreat_pw_n_p90 = `p90_conn'
gen double totaltreat_pw_norm  = totaltreat_pw_n / totaltreat_pw_n_p90
di as text "[norm] totaltreat_pw_n_p90 = " %12.8f `p90_conn' "  (vestigial; consumers recompute)"

save "$panel_out", replace
di as result "SAVED: $panel_out"



