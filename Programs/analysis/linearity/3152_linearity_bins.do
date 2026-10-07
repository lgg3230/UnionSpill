/*
================================================================================
3152_linearity_bins.do — Binned-connectivity spillover DiD (linearity check)

Replaces the linear term Connectivity x Post of the headline spillover DiD
(3012_pct_tfpw.do PART D) with indicators for connectivity groups x Post. The
omitted baseline is zero-connectivity firms. Positive connectivity is split
three ways:
    A  2 groups: below vs at-or-above the median
    B  3 groups: terciles (low, medium, high)
    C  4 groups: quartiles
Cutoffs are computed ONCE, at the firm level (one row per firm, year == 2009),
among s_spill firms outside the baseline (default: totaltreat_pw_n > 0), with xtile. Every outcome uses the
same firm-to-group assignment. Ties at a cutoff follow xtile's rule.

Run through a wrapper that sets the globals:
  3151_linearity_bins.do        baseline = zero connectivity (totaltreat_pw_n == 0)
  3153_linearity_bins_lt01.do   baseline = totaltreat_pw_n < 0.01
BASELINE GLOBALS (optional; both empty = zero-connectivity baseline):
  $base_lt     raw-connectivity threshold: baseline is totaltreat_pw_n < $base_lt,
               groups split the establishments at or above it
  $out_suffix  appended to every output name (e.g. _lt01)

SPECIFICATION (per outcome x breakdown), sample and FE identical to 3012:
  reghdfe Y pg1 ... pgk if s_spill,     pg = 1{group g} x Post, g = 1..k
    absorb(identificad i.industry1#i.year i.mode_base_month#i.year
           i.microregion#i.year ib0.Y_pre4#i.year ib0.l_firm_emp_pre4#i.year
           ib0.totalflows_pw_pre_07_114#i.year) vce(cluster identificad)
  numb_clauses: #i.cba_period, post_treat_cba, if s_spill & !missing(cba_period).
  Group main effects are absorbed by the firm FE; group 0 (zero connectivity)
  is the omitted category of the explicit pg dummies.
Also runs the linear benchmark (c.conn##i.treat_year = 3012) per outcome so the
implied effect beta_linear x mean connectivity can be compared with each group.

Data prep (Sections 1-2) is copied verbatim from 3142_linearity_twfe.do, which
copies 3012.

Output ($tables = Tables/linearity/):
  linearity_bins$out_suffix.csv          one row per outcome x breakdown x group (group 0 = base)
  linearity_bins_cutoffs$out_suffix.csv  xtile cutpoints per breakdown, raw and normalized
  -> table:  4250_table_linearity_bins_latex.py
  -> figure: 4260_figure_linearity_bins.py
================================================================================
*/

version 17.0
set more off
set varabbrev off

* Paths come from the wrapper 3151_linearity_bins.do.

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
cap mkdir "$logs"
cap mkdir "$tables"
log using "$logs/linearity_bins${out_suffix}_`d'_`t'.log", replace text

* Baseline group: zero connectivity unless the wrapper sets $base_lt
if "$base_lt" == "" {
	local base_cond "totaltreat_pw_n == 0"
}
else {
	local base_cond "totaltreat_pw_n < $base_lt"
}
local grp_cond "!(`base_cond') & !missing(totaltreat_pw_n)"
di "Baseline group: `base_cond'   |   grouped: `grp_cond'   |   suffix: '$out_suffix'"

di "Started: `c(current_date)' `c(current_time)'"

********************************************************************************
* SECTION 1: DATA (verbatim from 3012, turnover merge omitted)
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
gen totalflows_pw_pre_07_11_cnt = 0
foreach yp in totalflows_pw_07_08 totalflows_pw_08_09 totalflows_pw_09_10 totalflows_pw_10_11 {
	replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 + `yp' if !missing(`yp')
	replace totalflows_pw_pre_07_11_cnt = totalflows_pw_pre_07_11_cnt + (!missing(`yp'))
}
replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 / totalflows_pw_pre_07_11_cnt ///
	if totalflows_pw_pre_07_11_cnt > 0
replace totalflows_pw_pre_07_11 = . if totalflows_pw_pre_07_11_cnt == 0
drop totalflows_pw_pre_07_11_cnt

keep if year >= 2009
keep if lagos_sample_avg == 1

********************************************************************************
* SECTION 2: VARIABLE CREATION (verbatim from 3012)
********************************************************************************

* ── a) Treatment & CBA period indicators ──────────────────────────────────────

cap drop treat_year
gen byte treat_year = (year >= 2012)

cap drop cba_period
cap drop post_treat_cba
gen cba_period = .
replace cba_period = 1 if avg_file_date == earliest2009_avg - 1 & !missing(avg_file_date)
replace cba_period = 2 if avg_file_date == second_cba_avg & !missing(avg_file_date)
replace cba_period = 3 if inrange(avg_file_date, mdy(1,1,2013), mdy(12,31,2013)) & cba_period == .
replace cba_period = 4 if inrange(avg_file_date, mdy(1,1,2014), mdy(12,31,2014)) & cba_period == .
replace cba_period = 5 if inrange(avg_file_date, mdy(1,1,2015), mdy(12,31,2015)) & cba_period == .
replace cba_period = 6 if inrange(avg_file_date, mdy(1,1,2016), mdy(12,31,2016)) & cba_period == .
gen post_treat_cba = cond(cba_period >= 3, 1, 0) if !missing(cba_period)

* industry1 is stored as a string in the rebuilt panel; i.industry1 needs numeric
capture confirm string variable industry1
if _rc == 0 {
	destring industry1, replace force
}

* ── Connectivity scaling ──────────────────────────────────────────────────────

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen totaltreat_pw_n_p90 = r(p90)
gen totaltreat_pw_norm = (totaltreat_pw_n / totaltreat_pw_n_p90)

* ── b) Pre-treatment means ────────────────────────────────────────────────────

cap drop firm_emp_pre_o
cap drop firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre = min(firm_emp_pre_o)
	drop firm_emp_pre_o
}

foreach outcome in lr_remdezr_w lr_remdezr_h_w l_firm_emp {
	cap drop `outcome'_pre_o
	cap drop `outcome'_pre
	quietly {
		bys identificad: egen `outcome'_pre_o = mean(`outcome') if inrange(year, 2009, 2011)
		bys identificad: egen `outcome'_pre = min(`outcome'_pre_o)
		drop `outcome'_pre_o
	}
}

capture confirm variable numb_clauses
if _rc == 0 {
	cap drop numb_clauses_pre_o
	cap drop numb_clauses_pre
	quietly {
		bys identificad: egen numb_clauses_pre_o = mean(numb_clauses) if inrange(cba_period, 1, 2)
		bys identificad: egen numb_clauses_pre = min(numb_clauses_pre_o)
		drop numb_clauses_pre_o
	}
}

* Log pre-treatment employment (overwrite mean(l_firm_emp) with ln(mean(firm_emp)))
cap drop l_firm_emp_pre
gen double l_firm_emp_pre = ln(firm_emp_pre)

* ── 4-bin controls ────────────────────────────────────────────────────────────

cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
quietly {
	egen l_firm_emp_pre4_o = cut(l_firm_emp_pre) if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen l_firm_emp_pre4 = min(l_firm_emp_pre4_o)
	drop l_firm_emp_pre4_o
}

foreach v in lr_remdezr_w lr_remdezr_h_w numb_clauses {
	cap drop `v'_pre4_o
	cap drop `v'_pre4
	quietly {
		egen `v'_pre4_o = cut(`v'_pre) if year == 2009 & in_balanced_panel == 1, group(4)
		bys identificad: egen `v'_pre4 = min(`v'_pre4_o)
		drop `v'_pre4_o
	}
}

cap drop totalflows_pw_pre_07_114_o
cap drop totalflows_pw_pre_07_114
quietly {
	egen totalflows_pw_pre_07_114_o = cut(totalflows_pw_pre_07_11) ///
		if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen totalflows_pw_pre_07_114 = min(totalflows_pw_pre_07_114_o)
	drop totalflows_pw_pre_07_114_o
	replace totalflows_pw_pre_07_114 = 0 if missing(totalflows_pw_pre_07_114)
}

********************************************************************************
* SECTION 3: CONNECTIVITY GROUPS (firm level, among non-baseline connectivity)
********************************************************************************

preserve
	keep if `s_spill' & year == 2009
	keep identificad totaltreat_pw_n totaltreat_pw_norm totaltreat_pw_n_p90
	isid identificad

	* Cutpoints, written for the table notes: _pctile with the same nq() is
	* what xtile uses, so r(r1)..r(r(k-1)) are its exact cutoffs (an
	* establishment at a cutoff goes to the lower group). Reported both raw and
	* normalized (1 = 90th percentile among untreated establishments, 2009).
	local p90 = totaltreat_pw_n_p90[1]
	tempname fc
	file open `fc' using "$tables/linearity_bins_cutoffs${out_suffix}.csv", write replace
	file write `fc' "breakdown,cut,cutoff_raw,cutoff_norm" _n

	foreach k in 2 3 4 {
		cap drop cg`k'
		xtile cg`k' = totaltreat_pw_n if `grp_cond', nq(`k')
		replace cg`k' = 0 if `base_cond'
		_pctile totaltreat_pw_n if `grp_cond', nq(`k')
		forvalues c = 1/`=`k'-1' {
			local cr = r(r`c')
			local cn = `cr' / `p90'
			file write `fc' "`k',`c',`cr',`cn'" _n
			di "  cutoff `c' of `k': " %9.6f `cr' "  (normalized " %6.4f `cn' ")"
		}
		di _newline "Connectivity groups, `k' groups among non-baseline connectivity (firm level, 2009):"
		tabstat totaltreat_pw_norm, by(cg`k') statistics(n min max mean) format(%9.4f)
	}

	file close `fc'

	keep identificad cg2 cg3 cg4
	tempfile cgroups
	save `cgroups'
restore
merge m:1 identificad using `cgroups', keep(master match) nogen

********************************************************************************
* SECTION 4: ESTIMATION
********************************************************************************

local conn "totaltreat_pw_norm"
local csv  "$tables/linearity_bins${out_suffix}.csv"

tempname fh
file open `fh' using "`csv'", write replace
file write `fh' "outcome,breakdown,group,coef,se,pval,mean_conn,min_conn,max_conn,n_firms_group,n_obs,n_estab,beta_linear,se_linear" _n
file close `fh'

local outcomes "lr_remdezr_w lr_remdezr_h_w l_firm_emp"
capture confirm variable numb_clauses
if _rc == 0 local outcomes "`outcomes' numb_clauses"

foreach outcome of local outcomes {

	* ── Outcome-specific time structure (as in 3012) ─────────────────────────
	if "`outcome'" == "numb_clauses" {
		local tvar "cba_period"
		local post "post_treat_cba"
		local samp "`s_spill' & !missing(cba_period)"
	}
	else {
		local tvar "year"
		local post "treat_year"
		local samp "`s_spill'"
	}

	local absorb_full "identificad i.industry1#i.`tvar' i.mode_base_month#i.`tvar' i.microregion#i.`tvar' ib0.`outcome'_pre4#i.`tvar' ib0.l_firm_emp_pre4#i.`tvar' ib0.totalflows_pw_pre_07_114#i.`tvar'"

	di _newline "============================================================"
	di "Binned-connectivity spillover DiD: `outcome'"
	di "============================================================"

	* ── Linear benchmark (= 3012 PART D) ─────────────────────────────────────
	reghdfe `outcome' c.`conn'##i.`post' if `samp', ///
		absorb(`absorb_full') vce(cluster identificad)
	local b_lin  = _b[1.`post'#c.`conn']
	local se_lin = _se[1.`post'#c.`conn']

	* ── Binned regressions ──────────────────────────────────────────────────
	foreach k in 2 3 4 {

		di _newline "  -- `outcome' | `k' connectivity groups"

		* Explicit group x Post dummies for groups 1..k. Zero connectivity
		* (group 0) is omitted by construction. Do NOT use ib0.cg#1.post: in a
		* pure interaction Stata ignores the ib0 base, keeps 0.cg#1.post and
		* drops the TOP group for collinearity with the year FE, so every
		* coefficient becomes relative to the highest-connectivity group.
		forvalues g = 1/`k' {
			cap drop pg`g'
			gen byte pg`g' = (cg`k' == `g') * `post' if !missing(cg`k')
		}

		reghdfe `outcome' pg1-pg`k' if `samp', ///
			absorb(`absorb_full') vce(cluster identificad)

		local n_obs   = e(N)
		local n_estab = e(N_clust)
		local df_r    = e(df_r)

		cap drop est_s
		gen byte est_s = e(sample)
		cap drop ftag
		egen byte ftag = tag(identificad) if est_s

		forvalues g = 0/`k' {
			if `g' == 0 {
				local b  = 0
				local se = .
				local p  = .
			}
			else {
				local b  = _b[pg`g']
				local se = _se[pg`g']
				local p  = 2 * ttail(`df_r', abs(`b' / `se'))
			}
			quietly summarize `conn' if ftag == 1 & cg`k' == `g'
			local nf = r(N)
			local mc = r(mean)
			local mn = r(min)
			local mx = r(max)

			file open `fh' using "`csv'", write append
			file write `fh' "`outcome',`k',`g',`b',`se',`p',`mc',`mn',`mx',`nf',`n_obs',`n_estab',`b_lin',`se_lin'" _n
			file close `fh'
		}
		drop est_s ftag
		forvalues g = 1/`k' {
			drop pg`g'
		}
	}
}

di _newline "======================================================="
di "BINNED-CONNECTIVITY RESULTS"
di "======================================================="
type "`csv'"

di "Finished: `c(current_date)' `c(current_time)'"
capture log close

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && ///
	notify "3152_linearity_bins$out_suffix done" "binned-connectivity spillover DiD complete"
