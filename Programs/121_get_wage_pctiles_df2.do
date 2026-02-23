********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR:  LUIS GOMES
* PROGRAM: GET WAGE PERCENTILES AND MERGE BACK INTO FIRM LEVEL DATASET
* INPUTS: WORKER-LEVEL DATASET RESTRICTED TO LAGOS SAMPLE
* OUTPUTS: FIRM-LEVEL DATASET WITH WAGE PERCENTILES
********************************************************************************

use "$rais_firm/worker_year_pre_new_vs_nonnew_dec26.dta", clearf

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


mmerge identificad year using "$rais_firm/lagos_sample_sep24_pct_unionexp.dta", type(1:1)

save "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", replace



