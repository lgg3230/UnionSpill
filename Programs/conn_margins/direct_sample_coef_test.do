/*
================================================================================
direct_sample_coef_test.do
Test whether the DIRECT-effect wage coefficient differs across control-group
definitions (Panels A, B, C of Main_Results_pct_tfpw_07_11.do).

A, B, C share the same treated firms and differ only in the control group:
  A: controls = zero-connectivity untreated   (totaltreat_pw_n == 0)
  B: controls = low-connectivity untreated     (totaltreat_pw_n <= 0.01)
  C: controls = all untreated
A's controls subset B's subset C's, so beta_A, beta_B, beta_C are estimated on
OVERLAPPING samples and are correlated; a naive z-test with the separate SEs is
invalid. We test beta_A=beta_C and beta_B=beta_C with a stacked regression: two
copies of the data (the small sample and C), each with its OWN fixed effects
(samp#FE), and the DiD term interacted with the sample indicator. The triple
interaction treat_ultra#post#samp equals (beta_C - beta_small); clustering on the
firm id accounts for firms that appear in both stacks.

Outcomes: lr_remdezr_w, lr_remdezr_h_w.
================================================================================
*/

version 17.0
set more off
set varabbrev off

global main      "/kellogg/proj/lgg3230/UnionSpill"
global rais_firm "$main/Data/CBA_RAIS_firm_level"
global rais_aux  "$main/Data/RAIS_aux"
global tables    "$main/Tables"
global logs      "$main/Logs"

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/conn_margins/direct_sample_coef_test_`d'_`t'.log", replace text

* ── Load + prep (mirror Main_Results direct-effects spec) ─────────────────────

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear
preserve
	import delimited "$rais_aux/totalflows_wide_2007_2011.csv", clear
	tostring identificad, replace format(%014.0f) force
	tempfile tf
	save `tf'
restore
merge m:1 identificad using `tf', keep(master match) nogen
gen double totalflows_pw_pre_07_11 = 0
gen tfc = 0
foreach yp in totalflows_pw_07_08 totalflows_pw_08_09 totalflows_pw_09_10 totalflows_pw_10_11 {
	replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 + `yp' if !missing(`yp')
	replace tfc = tfc + (!missing(`yp'))
}
replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11/tfc if tfc>0
replace totalflows_pw_pre_07_11 = . if tfc==0
drop tfc

keep if year >= 2009
keep if lagos_sample_avg == 1

cap drop treat_year
gen byte treat_year = (year >= 2012)

cap drop firm_emp_pre_o
cap drop firm_emp_pre
cap drop l_firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year,2009,2011)
	bys identificad: egen firm_emp_pre   = min(firm_emp_pre_o)
	drop firm_emp_pre_o
	gen double l_firm_emp_pre = ln(firm_emp_pre)
}
foreach v in lr_remdezr_w lr_remdezr_h_w {
	cap drop `v'_pre_o
	cap drop `v'_pre
	quietly {
		bys identificad: egen `v'_pre_o = mean(`v') if inrange(year,2009,2011)
		bys identificad: egen `v'_pre   = min(`v'_pre_o)
		drop `v'_pre_o
	}
}
cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
quietly {
	egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) if year==2009 & in_balanced_panel==1, group(4)
	bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
	drop l_firm_emp_pre4_o
}
foreach v in lr_remdezr_w lr_remdezr_h_w {
	cap drop `v'_pre4_o
	cap drop `v'_pre4
	quietly {
		egen `v'_pre4_o = cut(`v'_pre) if year==2009 & in_balanced_panel==1, group(4)
		bys identificad: egen `v'_pre4 = min(`v'_pre4_o)
		drop `v'_pre4_o
	}
}
cap drop totalflows_pw_pre_07_114_o
cap drop totalflows_pw_pre_07_114
quietly {
	egen totalflows_pw_pre_07_114_o = cut(totalflows_pw_pre_07_11) if year==2009 & in_balanced_panel==1, group(4)
	bys identificad: egen totalflows_pw_pre_07_114 = min(totalflows_pw_pre_07_114_o)
	drop totalflows_pw_pre_07_114_o
	replace totalflows_pw_pre_07_114 = 0 if missing(totalflows_pw_pre_07_114)
}

cap drop firm_id
egen firm_id = group(identificad)

* direct-effect samples (conditions passed to the program via globals)
global s_A "(treat_ultra==0 & totaltreat_pw_n==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
global s_B "(treat_ultra==0 & totaltreat_pw_n<=0.01 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"
global s_C "(treat_ultra==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"

tempfile base
save `base'
global basefile "`base'"

tempname fh
file open `fh' using "$tables/conn_margins/direct_sample_coef_test.csv", write replace
file write `fh' "outcome,comparison,b_small,b_C,diff_C_minus_small,se_diff,p_diff" _n
file close `fh'

* ── program: stacked test of beta(small sample) vs beta(C) ───────────────────
* args: outcome  slabel   (reads $scond = small-sample condition, $s_C = C)
capture program drop _stacktest
program define _stacktest
	args outcome slabel
	preserve
		use "$basefile", clear
		keep if $s_C
		gen byte samp = 1
		tempfile cpart
		save `cpart'

		use "$basefile", clear
		keep if $scond
		gen byte samp = 0
		append using `cpart'

		local absorb "i.samp#i.firm_id i.samp#i.industry1#i.year i.samp#i.mode_base_month#i.year i.samp#i.microregion#i.year i.samp#i.`outcome'_pre4#i.year i.samp#i.l_firm_emp_pre4#i.year i.samp#i.totalflows_pw_pre_07_114#i.year"

		reghdfe `outcome' i.treat_ultra##i.treat_year##i.samp, ///
			absorb(`absorb') vce(cluster firm_id)

		local b_small = _b[1.treat_ultra#1.treat_year]
		local diff    = _b[1.treat_ultra#1.treat_year#1.samp]
		local b_C     = `b_small' + `diff'
		local se_diff = _se[1.treat_ultra#1.treat_year#1.samp]
		test 1.treat_ultra#1.treat_year#1.samp = 0
		local p_diff = r(p)

		di _newline "==== `outcome': `slabel' vs C ===="
		di " beta_`slabel' = " %9.5f `b_small' "   beta_C = " %9.5f `b_C' ///
			"   diff(C-`slabel') = " %9.5f `diff' "   se = " %9.5f `se_diff' "   p = " %6.4f `p_diff'

		tempname fh2
		file open `fh2' using "$tables/conn_margins/direct_sample_coef_test.csv", write append
		file write `fh2' `"`outcome',`slabel'_vs_C,`b_small',`b_C',`diff',`se_diff',`p_diff'"' _n
		file close `fh2'
	restore
end

foreach outcome in lr_remdezr_w lr_remdezr_h_w {
	global scond "$s_A"
	_stacktest `outcome' A
	global scond "$s_B"
	_stacktest `outcome' B
}

di _newline "======================================================="
type "$tables/conn_margins/direct_sample_coef_test.csv"

capture log close
shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && ///
	notify "direct sample test done" "A-vs-C and B-vs-C wage coefficient tests complete"
