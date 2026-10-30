/*
================================================================================
3166_firm_size_pure_control_cutoff.do — Pre-treatment firm size of the
treated group and of each pure-control group (fine cutoff set)

Firm size = firm_emp_pre, mean employment over 2009-2011 (as in 3012/3162),
one row per firm (year == 2009), balanced-panel Lagos sample. Groups:
    treated     treat_ultra == 1
    zero        untreated, totaltreat_pw_n == 0
    fixed_001   untreated, totaltreat_pw_n <= 0.01
    p05 ... p95 untreated, totaltreat_pw_n <= vingtile of positive connectivity
    all         every untreated firm
The control groups are cumulative, as in the estimation samples. Cutoffs are
recomputed exactly as in 3162 (_pctile, nq(20)) and the control-firm counts
are checked against 3162's cutoff file, so the groups are the ones estimated.

Called by 3162 (fine set). Also runs on its own: with $tables / $rais_firm
unset, it uses the project root found from the working directory.

Input:  $rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta
        $tables/pure_control_cutoff_cutoffs.csv   (count check)
Output: $tables/pure_control_cutoff_size.csv
        group,cutoff,n_firms,mean,p25,p50,p75
  -> table: 4272_table_pure_control_cutoff_size_latex.py
================================================================================
*/

version 17.0
set more off
set varabbrev off

if `"$tables"' == "" | `"$rais_firm"' == "" {
	if `"$root"' == "" {
		local _d = subinstr(`"`c(pwd)'"', "\", "/", .)
		while `"`_d'"' != "" & !fileexists(`"`_d'/Programs/0000_master.do"') {
			local _d = substr(`"`_d'"', 1, max(strrpos(`"`_d'"', "/") - 1, 0))
		}
		global root `"`_d'"'
	}
	if !fileexists(`"$root/Programs/0000_master.do"') {
		di as error "Project root not found: run from inside the project or set \$tables and \$rais_firm."
		exit 601
	}
	global tables    "$root/Tables/pure_control_cutoff_fine"
	global rais_firm "$root/Data/CBA_RAIS_firm_level"
}

* Control-firm counts from 3162, to check the groups below.
import delimited using "$tables/pure_control_cutoff_cutoffs.csv", ///
	clear varnames(1) stringcols(_all)
forvalues i = 1/`=_N' {
	local n_`=sample[`i']' = real(n_ctrl_firms[`i'])
}

use identificad year firm_emp treat_ultra totaltreat_pw_n lagos_sample_avg in_balanced_panel ///
	using "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear
keep if year >= 2009 & lagos_sample_avg == 1 & in_balanced_panel == 1

bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
bys identificad: egen firm_emp_pre = min(firm_emp_pre_o)
keep if year == 2009
assert !missing(firm_emp_pre)

* Cutoffs as in 3162: vingtiles of positive connectivity among untreated firms.
quietly _pctile totaltreat_pw_n if treat_ultra == 0 & totaltreat_pw_n > 0 & !missing(totaltreat_pw_n), nq(20)
local quantiles ""
forvalues k = 1/19 {
	local q = "p" + string(5*`k', "%02.0f")
	scalar c_`q' = r(r`k')
	local quantiles "`quantiles' `q'"
}
scalar c_zero      = 0
scalar c_fixed_001 = 0.01
scalar c_all       = .
scalar c_treated   = .

local cond_treated   "treat_ultra == 1"
local cond_zero      "treat_ultra == 0 & totaltreat_pw_n == 0"
local cond_fixed_001 "treat_ultra == 0 & totaltreat_pw_n <= 0.01"
local cond_all       "treat_ultra == 0"
foreach q of local quantiles {
	local cond_`q' "treat_ultra == 0 & totaltreat_pw_n <= scalar(c_`q')"
}

tempname fh
file open `fh' using "$tables/pure_control_cutoff_size.csv", write replace
file write `fh' "group,cutoff,n_firms,mean,p25,p50,p75" _n
foreach g in treated zero fixed_001 `quantiles' all {
	quietly summarize firm_emp_pre if `cond_`g'', detail
	if "`g'" != "treated" {
		if r(N) != `n_`g'' {
			di as error "`g': `r(N)' firms here vs `n_`g'' in 3162's cutoff file."
			exit 9
		}
	}
	local c = strtrim(string(scalar(c_`g'), "%20.15g"))
	file write `fh' "`g',`c',`r(N)'," %20.15g (r(mean)) "," %20.15g (r(p25)) "," ///
		%20.15g (r(p50)) "," %20.15g (r(p75)) _n
	di "  `g': N `r(N)'  mean " %8.1f (r(mean)) "  median " %8.1f (r(p50))
}
file close `fh'
