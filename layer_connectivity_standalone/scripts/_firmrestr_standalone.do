********************************************************************************
* STANDALONE: FIRM-LEVEL RESTRICTED SPEC FROM 07_layer_spillover.do
* Replicates Section 2i exactly (no outer loop).
*
* Sample: control firms in the balanced panel (lagos_sample_avg==1,
*         treat_ultra==0, in_balanced_panel==1) that have non-missing
*         layer_treat_pw_n in firm_layer_connectivity_edu2.dta.
*
* Outcomes: lr_remdezr_w, lr_remdezr_h_w, l_firm_emp
* Treatment: totaltreat_pw_norm_r (P90-scaled, computed in restricted sample)
* FE: identificad + industry×year + mode×year + microregion×year
*     + outcome_pre4×year + l_firm_emp_pre4×year + totalflows_pw_pre4_r×year
********************************************************************************
* ── Paths ────────────────────────────────────────────────────────────────────
global main       "/kellogg/proj/lgg3230"
global rais_firm  "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global rais_aux   "$main/UnionSpill/Data/RAIS_aux"
global layer_data "$main/UnionSpill/Data/layer_connectivity"
global tables     "$main/UnionSpill/Tables/layer_connectivity"
global logs       "$main/UnionSpill/Logs/layer_connectivity"

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/firmrestr_standalone_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"

local layer "edu2"

* ── Step 1: Get restricted firm set from layer connectivity ──────────────────
* Connectivity file is firm×layer (no year). Pull firm attributes from a
* single year of the panel (2009) to get treat_ultra, in_balanced_panel, etc.
preserve
use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear
keep if year == 2009
keep identificad treat_ultra in_balanced_panel lagos_sample_avg
tempfile firm_attrs
save `firm_attrs'
restore

use "$layer_data/final_measures/firm_layer_connectivity_edu2.dta", clear

merge m:1 identificad using `firm_attrs', keep(master match) nogen

keep if treat_ultra == 0 & in_balanced_panel == 1 & lagos_sample_avg == 1 ///
      & !missing(layer_treat_pw_n)
keep identificad
duplicates drop
count
di as result "  Restricted sample: `r(N)' unique firms (non-missing layer_treat_pw_n)"
tempfile restr_firms
save `restr_firms'

* ── Step 2: Load totalflows wide CSV ─────────────────────────────────────────
import delimited "$rais_aux/totalflows_wide_2007_2011.csv", stringcols(1) clear
tempfile tfwide
save `tfwide'

* ── Step 3: Build firm-level panel ───────────────────────────────────────────
use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear
keep if year >= 2009

merge m:1 identificad using `tfwide', keep(master match) nogen

keep if lagos_sample_avg == 1

count
di as result "  Firm-panel obs (full sample, before layer restriction): `r(N)'"

* ── Step 4: Encode categorical FE variables ──────────────────────────────────
capture confirm string variable industry1
if !_rc encode industry1,       gen(industry1_num)
else     gen industry1_num     = industry1

capture confirm string variable mode_base_month
if !_rc encode mode_base_month, gen(mode_base_month_num)
else     gen mode_base_month_num = mode_base_month

capture confirm string variable microregion
if !_rc encode microregion,     gen(microregion_num)
else     gen microregion_num   = microregion

* ── Step 5: Treatment period indicators ──────────────────────────────────────
cap drop treat_year
cap drop placebo_year
gen byte treat_year   = (year >= 2012)
gen byte placebo_year = (year < 2011)

* ── Step 6: Firm connectivity scaling (P90 anchored to FULL spillover sample) ──
local s_spill_r "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"
sum totaltreat_pw_n if `s_spill_r' & year == 2009, detail
gen double totaltreat_pw_norm_r = totaltreat_pw_n / r(p90)
label var totaltreat_pw_norm_r "Firm connectivity (scaled to P90, full spillover sample)"

* ── Step 7: Pre-treatment firm employment bins ────────────────────────────────
bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
bys identificad: egen firm_emp_pre   = min(firm_emp_pre_o)
drop firm_emp_pre_o
gen double l_firm_emp_pre = ln(firm_emp_pre)
* (bins for l_firm_emp_pre4 computed in Step 8b on full sample)

* ── Step 8: Pre-treatment totalflows bins ─────────────────────────────────────
gen double totalflows_pw_pre_07_11     = 0
gen        totalflows_pw_pre_07_11_cnt = 0
foreach yp in totalflows_pw_07_08 totalflows_pw_08_09 ///
              totalflows_pw_09_10 totalflows_pw_10_11 {
	replace totalflows_pw_pre_07_11     = totalflows_pw_pre_07_11 + `yp' if !missing(`yp')
	replace totalflows_pw_pre_07_11_cnt = totalflows_pw_pre_07_11_cnt + (!missing(`yp'))
}
replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 / totalflows_pw_pre_07_11_cnt ///
	if totalflows_pw_pre_07_11_cnt > 0
replace totalflows_pw_pre_07_11 = . if totalflows_pw_pre_07_11_cnt == 0
drop totalflows_pw_pre_07_11_cnt
egen totalflows_pw_pre4_r_o = cut(totalflows_pw_pre_07_11) ///
	if year == 2009 & in_balanced_panel == 1, group(4)
bys identificad: egen totalflows_pw_pre4_r = min(totalflows_pw_pre4_r_o)
drop totalflows_pw_pre4_r_o
replace totalflows_pw_pre4_r = 0 if missing(totalflows_pw_pre4_r)

* ── Step 8b: Pre-treatment outcome bins (FULL sample, to match main spec) ─────
* Wage outcomes: compute _pre (mean 2009-2011) then quartile bins
foreach outcome in lr_remdezr_w lr_remdezr_h_w {
	cap drop `outcome'_pre_o `outcome'_pre `outcome'_pre4_o `outcome'_pre4
	bys identificad: egen `outcome'_pre_o = mean(`outcome') if inrange(year, 2009, 2011)
	bys identificad: egen `outcome'_pre   = min(`outcome'_pre_o)
	drop `outcome'_pre_o
	egen `outcome'_pre4_o = cut(`outcome'_pre) ///
		if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen `outcome'_pre4 = min(`outcome'_pre4_o)
	drop `outcome'_pre4_o
	replace `outcome'_pre4 = 0 if missing(`outcome'_pre4)
}
* l_firm_emp: _pre already created in Step 7 as ln(firm_emp_pre); only need bins
cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) ///
	if year == 2009 & in_balanced_panel == 1, group(4)
bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
drop l_firm_emp_pre4_o
replace l_firm_emp_pre4 = 0 if missing(l_firm_emp_pre4)

* ── Step 9: Restrict to layer firms ───────────────────────────────────────────
merge m:1 identificad using `restr_firms', keep(match) nogen
count
di as result "  Firm-panel obs after layer restriction: `r(N)'"

di as result "Variables created."

* ── FE macros ─────────────────────────────────────────────────────────────────
local conn_r    "totaltreat_pw_norm_r"
local base_fe_r "identificad i.industry1_num#i.year i.mode_base_month_num#i.year i.microregion_num#i.year"
local extra_r   "ib0.totalflows_pw_pre4_r#i.year"

* ── Output CSV ────────────────────────────────────────────────────────────────
local csv_r "$tables/results_spill_firmrestr_`layer'_standalone.csv"
capture erase "`csv_r'"
tempname fhr
file open  `fhr' using "`csv_r'", write replace
file write `fhr' "spec,section,outcome,row_type,value" _n
file close `fhr'
di as result "Output: `csv_r'"

********************************************************************************
* REGRESSIONS
********************************************************************************

foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {

	di as text "  Estimating: `outcome'"

	* _pre and _pre4 already computed on full sample in Step 8b above

	local absorb_r "`base_fe_r' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_r'"

	* Post-treatment spillover
	reghdfe `outcome' c.`conn_r'##i.treat_year if `s_spill_r', ///
		absorb(`absorb_r') vce(cluster identificad)

	local b_post_r  = _b[1.treat_year#c.`conn_r']
	local se_post_r = _se[1.treat_year#c.`conn_r']
	local p_post_r  = 2*ttail(e(df_r), abs(`b_post_r'/`se_post_r'))
	local n_obs_r   = e(N)
	local n_firms_r = e(N_clust)

	local stars_post_r ""
	if `p_post_r' < 0.01                             local stars_post_r "***"
	else if (`p_post_r' < 0.05 & `p_post_r' > 0.01) local stars_post_r "**"
	else if (`p_post_r' < 0.10 & `p_post_r' > 0.05) local stars_post_r "*"

	* Pre-treatment placebo
	reghdfe `outcome' c.`conn_r'##i.placebo_year ///
		if `s_spill_r' & year <= 2011, ///
		absorb(`absorb_r') vce(cluster identificad)

	local b_pre_r  = _b[1.placebo_year#c.`conn_r']
	local se_pre_r = _se[1.placebo_year#c.`conn_r']
	local p_pre_r  = 2*ttail(e(df_r), abs(`b_pre_r'/`se_pre_r'))

	local stars_pre_r ""
	if `p_pre_r' < 0.01                             local stars_pre_r "***"
	else if (`p_pre_r' < 0.05 & `p_pre_r' > 0.01)  local stars_pre_r "**"
	else if (`p_pre_r' < 0.10 & `p_pre_r' > 0.05)  local stars_pre_r "*"

	* Event study (pre-trend F-test)
	reghdfe `outcome' c.`conn_r'##ib2011.year if `s_spill_r', ///
		absorb(`absorb_r') vce(cluster identificad)

	testparm c.`conn_r'#i(2009 2010).year
	local pre_ftest_pval_r = r(p)

	* Write to CSV
	tempname fhr
	file open  `fhr' using "`csv_r'", write append
	file write `fhr' `""firmrestr_`layer'";"firmrestr";"`outcome'";"main";"'    %9.4f (`b_post_r')         `"`stars_post_r'""' _n
	file write `fhr' `""firmrestr_`layer'";"firmrestr";"`outcome'";"main_se";"' %9.4f (`se_post_r')        `"""'              _n
	file write `fhr' `""firmrestr_`layer'";"firmrestr";"`outcome'";"pre";"'     %9.4f (`b_pre_r')          `"`stars_pre_r'""' _n
	file write `fhr' `""firmrestr_`layer'";"firmrestr";"`outcome'";"pre_se";"'  %9.4f (`se_pre_r')         `"""'              _n
	file write `fhr' `""firmrestr_`layer'";"firmrestr";"`outcome'";"n_obs";"'   %12.0fc (`n_obs_r')        `"""'              _n
	file write `fhr' `""firmrestr_`layer'";"firmrestr";"`outcome'";"n_firms";"' %12.0fc (`n_firms_r')      `"""'              _n
	file write `fhr' `""firmrestr_`layer'";"firmrestr";"`outcome'";"pre_pval";"'%9.4f (`pre_ftest_pval_r') `"""'              _n
	file close `fhr'

	di as result "  Done: `outcome' — post=`b_post_r' (`se_post_r'), pre=`b_pre_r' (`se_pre_r')"
}

log close
di as result "Finished: `c(current_date)' `c(current_time)'"
shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "firmrestr standalone done" "firm-level restricted spec complete"
