/*
================================================================================
3162_pure_control_cutoff.do — Direct effects vs the pure-control connectivity cutoff

Re-estimates the headline direct effects (3012_pct_tfpw.do Panels A-C) for the
four main outcomes while widening the pure-control group from zero
connectivity to untreated firms with totaltreat_pw_n <= c:

    zero       c = 0                      (= 3012 Panel A, published Panel A)
    fixed_001  c = 0.01                   (= 3012 Panel B)
    all        no cutoff                  (= 3012 Panel C, published Panel B)
    q1_4       c = p25 of positive connectivity
    t1_3       c = p33
    q2_4       c = p50
    t2_3       c = p67
    q3_4       c = p75
    p80        c = p80
    p90        c = p90

Samples are CUMULATIVE: the controls at cutoff c are every untreated firm with
connectivity <= c, zeros included. The treated group is the same everywhere.
Cutoffs are computed ONCE, at the firm level (one row per firm, year == 2009),
among untreated balanced-panel firms with totaltreat_pw_n > 0, with _pctile --
the same cutpoints as 3152_linearity_bins.do's xtile groups (p80 and p90 from
_pctile, p(80 90), same percentile definition). totaltreat_pw_n is
constant within firm, so the row-level restriction equals the firm-level one.

SPECIFICATION: identical to 3012 for every column. Only the sample changes.
The _pre4 outcome / size / flow bins are built once on the full balanced panel
(as in 3012) and are NOT recomputed per subsample.
  Post:    reghdfe Y treat_ultra##i.treat_year if s, absorb(base_fe
             ib0.Y_pre4#i.year ib0.l_firm_emp_pre4#i.year extra_year)
             vce(cluster identificad)
  Placebo: same on year <= 2011 with placebo_year = (year < 2011)
  numb_clauses: #i.cba_period, post_treat_cba / pre_treat_cba (cba_period <= 2)

ORDER AND GATE: zero, fixed_001 and all run first. 3163_verify_baseline.py
then compares them with the published CSVs; if any number differs, the run
stops before the quantile cutoffs are estimated.

Data prep (Sections 1-2) is copied from 3012 (turnover merge and the
percentile/ratio/union variables omitted: none enters these regressions).

Output ($tables = Tables/pure_control_cutoff/):
  pure_control_cutoff_cutoffs.csv   one row per sample: cutoff and firm counts
  pure_control_cutoff.csv           spec,section,outcome,row_type,value (long,
                                    full precision, no stars)
  verify_baseline.txt               replication check (from 3163)
  -> table:  4270_table_pure_control_cutoff_latex.py
  -> figure: 4280_figure_pure_control_cutoff.py (one PDF per outcome)
             4290_latex_figure_pure_control_cutoff.py (2x2 subfigure wrapper)
================================================================================
*/

version 17.0
set more off
set varabbrev off

* Paths come from the wrapper 3161_pure_control_cutoff.do.

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
cap mkdir "$logs"
cap mkdir "$tables"
cap mkdir "$graphs"
log using "$logs/pure_control_cutoff_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
di "Input panel: $rais_firm"

********************************************************************************
* SECTION 1: DATA (from 3012, turnover merge omitted)
********************************************************************************

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

preserve
	import delimited "$rais_aux/totalflows_wide_2007_2011.csv", clear
	tostring identificad, replace format(%014.0f) force
	tempfile totalflows_wide
	save `totalflows_wide'
restore
merge m:1 identificad using `totalflows_wide', keep(master match) nogen

* Average per-worker pairwise flows 2007-2011 (missing-safe: average over
* non-missing year pairs only; NaN means zero flows, not truly missing).
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

di as result "Sample size after restrictions: " _N

********************************************************************************
* SECTION 2: VARIABLE CREATION (from 3012)
********************************************************************************

* ── a) Treatment & CBA period indicators ──────────────────────────────────────

cap drop placebo_year
gen byte placebo_year = (year < 2011)

cap drop treat_year
gen byte treat_year = (year >= 2012)

cap drop cba_period
cap drop pre_treat_cba
cap drop post_treat_cba

gen cba_period = .
replace cba_period = 1 if avg_file_date == earliest2009_avg - 1 & !missing(avg_file_date)
replace cba_period = 2 if avg_file_date == second_cba_avg & !missing(avg_file_date)
replace cba_period = 3 if inrange(avg_file_date, mdy(1,1,2013), mdy(12,31,2013)) & cba_period == .
replace cba_period = 4 if inrange(avg_file_date, mdy(1,1,2014), mdy(12,31,2014)) & cba_period == .
replace cba_period = 5 if inrange(avg_file_date, mdy(1,1,2015), mdy(12,31,2015)) & cba_period == .
replace cba_period = 6 if inrange(avg_file_date, mdy(1,1,2016), mdy(12,31,2016)) & cba_period == .

gen pre_treat_cba = cond(cba_period < 2, 1, 0)
gen post_treat_cba = cond(cba_period >= 3, 1, 0) if !missing(cba_period)

* industry1 is numeric in the overlay panel but a string in the rebuilt one;
* i.industry1 needs numeric. No-op on the overlay.
capture confirm string variable industry1
if _rc == 0 {
	destring industry1, replace force
}

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

cap drop numb_clauses_pre_o
cap drop numb_clauses_pre
quietly {
	bys identificad: egen numb_clauses_pre_o = mean(numb_clauses) if inrange(cba_period, 1, 2)
	bys identificad: egen numb_clauses_pre = min(numb_clauses_pre_o)
	drop numb_clauses_pre_o
}

* Log pre-treatment employment (overwrite mean(l_firm_emp) with ln(mean(firm_emp)))
cap drop l_firm_emp_pre
gen double l_firm_emp_pre = ln(firm_emp_pre)

* ── c) 4-bin controls (full balanced panel, fixed across samples) ─────────────

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
* SECTION 3: CUTOFFS (firm level, untreated balanced firms, positive connectivity)
********************************************************************************

local s_pool "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"
local pos    "totaltreat_pw_n > 0 & !missing(totaltreat_pw_n)"

* Connectivity must be constant within firm for a row-level restriction to
* select whole firms.
cap drop conn_sd
bys identificad: egen conn_sd = sd(totaltreat_pw_n)
quietly sum conn_sd
assert r(max) == 0 | r(N) == 0
drop conn_sd

* _pctile with nq(k) gives the same cutpoints as xtile (3152). Kept as scalars
* so the sample restriction uses full double precision.
quietly _pctile totaltreat_pw_n if `s_pool' & year == 2009 & `pos', nq(4)
scalar c_q1_4 = r(r1)
scalar c_q2_4 = r(r2)
scalar c_q3_4 = r(r3)
quietly _pctile totaltreat_pw_n if `s_pool' & year == 2009 & `pos', nq(3)
scalar c_t1_3 = r(r1)
scalar c_t2_3 = r(r2)
quietly _pctile totaltreat_pw_n if `s_pool' & year == 2009 & `pos', p(80 90)
scalar c_p80 = r(r1)
scalar c_p90 = r(r2)

* Estimation order: the three replication columns first (verification gate),
* then the quantile cutoffs.
local samples "zero fixed_001 all q1_4 t1_3 q2_4 t2_3 q3_4 p80 p90"

local cond_zero      "totaltreat_pw_n == 0"
local cond_fixed_001 "totaltreat_pw_n <= 0.01"
local cond_all       "1"
foreach q in q1_4 t1_3 q2_4 t2_3 q3_4 p80 p90 {
	local cond_`q' "totaltreat_pw_n <= scalar(c_`q')"
}

scalar c_zero      = 0
scalar c_fixed_001 = 0.01
scalar c_all       = .

quietly count if `s_pool' & year == 2009
local n_pool = r(N)
quietly count if `s_pool' & year == 2009 & `pos'
local n_pos = r(N)
quietly count if lagos_sample_avg==1 & treat_ultra==1 & in_balanced_panel==1 & year == 2009
local n_treat_firms = r(N)

tempname fc
file open `fc' using "$tables/pure_control_cutoff_cutoffs.csv", write replace
file write `fc' "sample,cutoff_raw,n_ctrl_firms,n_ctrl_positive,share_positive_le,n_at_cutoff,n_untreated_total,n_positive_total,n_treated_firms" _n
foreach s of local samples {
	quietly count if `s_pool' & year == 2009 & (`cond_`s'')
	local nc = r(N)
	quietly count if `s_pool' & year == 2009 & (`cond_`s'') & `pos'
	local ncp = r(N)
	local shp = `ncp' / `n_pos'
	if "`s'" == "all" | "`s'" == "zero" {
		local nat = .
	}
	else {
		quietly count if `s_pool' & year == 2009 & totaltreat_pw_n == scalar(c_`s')
		local nat = r(N)
	}
	file write `fc' "`s'," %20.15g (scalar(c_`s')) ",`nc',`ncp'," %10.6f (`shp') ",`nat',`n_pool',`n_pos',`n_treat_firms'" _n
	di "  `s': cutoff " %10.6f (scalar(c_`s')) "  control firms `nc' (positive `ncp', " %5.3f (`shp') " of positive)  at cutoff `nat'"
}
file close `fc'

********************************************************************************
* SECTION 4: ESTIMATION
********************************************************************************

local spec       "pure_control_cutoff"
local base_fe    "identificad i.industry1#i.year i.mode_base_month#i.year i.microregion#i.year"
local base_fe_cba "identificad i.industry1#i.cba_period i.mode_base_month#i.cba_period i.microregion#i.cba_period"
local extra_year "ib0.totalflows_pw_pre_07_114#i.year"
local extra_cba  "ib0.totalflows_pw_pre_07_114#i.cba_period"

local csv "$tables/pure_control_cutoff.csv"
tempname fh
file open `fh' using "`csv'", write replace
file write `fh' "spec,section,outcome,row_type,value" _n
file close `fh'

* Stale verification flag must not let a failed check pass.
cap erase "$tables/verify_pass.flag"

local outcomes "lr_remdezr_w lr_remdezr_h_w l_firm_emp numb_clauses"

foreach s of local samples {

	local s_use "(treat_ultra==0 & `cond_`s'' | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1"

	di _newline "============================================================"
	di "Sample `s': controls with `cond_`s''"
	di "============================================================"

	foreach outcome of local outcomes {

		if "`outcome'" == "numb_clauses" {
			local absorb "`base_fe_cba' ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"
			local samp_post "`s_use' & !missing(cba_period)"
			local samp_pre  "`s_use' & !missing(cba_period) & cba_period <= 2"
			local x_post    "i.treat_ultra##post_treat_cba"
			local x_pre     "i.treat_ultra##pre_treat_cba"
			local b_post_nm "1.treat_ultra#1.post_treat_cba"
			local b_pre_nm  "1.treat_ultra#1.pre_treat_cba"
		}
		else {
			local absorb "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_firm_emp_pre4#i.year `extra_year'"
			local samp_post "`s_use'"
			local samp_pre  "`s_use' & year <= 2011"
			local x_post    "treat_ultra##i.treat_year"
			local x_pre     "treat_ultra##i.placebo_year"
			local b_post_nm "1.treat_ultra#1.treat_year"
			local b_pre_nm  "1.treat_ultra#1.placebo_year"
		}

		di as text "  Estimating: `outcome' (sample `s')"

		* Post-treatment
		reghdfe `outcome' `x_post' if `samp_post', ///
			absorb(`absorb') vce(cluster identificad)

		scalar s_b_post  = _b[`b_post_nm']
		scalar s_se_post = _se[`b_post_nm']
		scalar s_p_post  = 2*ttail(e(df_r), abs(s_b_post/s_se_post))
		local n_obs   = e(N)
		local n_estab = e(N_clust)

		* Pre-treatment mean and establishment counts on this column's
		* estimation sample, taken before the placebo replaces e(sample).
		cap drop est_s
		gen byte est_s = e(sample)
		quietly sum `outcome' if est_s & inrange(year, 2009, 2011)
		scalar s_mean_pre = r(mean)
		cap drop ftag
		egen byte ftag = tag(identificad) if est_s
		quietly count if ftag == 1 & treat_ultra == 0
		local n_estab_ctrl = r(N)
		quietly count if ftag == 1 & treat_ultra == 1
		local n_estab_treat = r(N)
		drop est_s
		drop ftag

		* Pre-treatment placebo
		reghdfe `outcome' `x_pre' if `samp_pre', ///
			absorb(`absorb') vce(cluster identificad)

		scalar s_b_pre  = _b[`b_pre_nm']
		scalar s_se_pre = _se[`b_pre_nm']
		scalar s_p_pre  = 2*ttail(e(df_r), abs(s_b_pre/s_se_pre))

		file open `fh' using "`csv'", write append
		file write `fh' "`spec',`s',`outcome',cutoff," %20.15g (scalar(c_`s')) _n
		file write `fh' "`spec',`s',`outcome',main," %20.15g (s_b_post) _n
		file write `fh' "`spec',`s',`outcome',main_se," %20.15g (s_se_post) _n
		file write `fh' "`spec',`s',`outcome',main_p," %20.15g (s_p_post) _n
		file write `fh' "`spec',`s',`outcome',pre," %20.15g (s_b_pre) _n
		file write `fh' "`spec',`s',`outcome',pre_se," %20.15g (s_se_pre) _n
		file write `fh' "`spec',`s',`outcome',pre_p," %20.15g (s_p_pre) _n
		file write `fh' "`spec',`s',`outcome',mean_pre," %20.15g (s_mean_pre) _n
		file write `fh' "`spec',`s',`outcome',n_obs,`n_obs'" _n
		file write `fh' "`spec',`s',`outcome',n_estab,`n_estab'" _n
		file write `fh' "`spec',`s',`outcome',n_estab_ctrl,`n_estab_ctrl'" _n
		file write `fh' "`spec',`s',`outcome',n_estab_treat,`n_estab_treat'" _n
		file close `fh'
	}

	* ── Verification gate after the three replication columns ──────────────
	if "`s'" == "all" {
		shell $python_exe "$programs/analysis/pure_control_cutoff/3163_verify_baseline.py" "$tables"
		capture confirm file "$tables/verify_pass.flag"
		if _rc {
			di as error "Replication check FAILED: see $tables/verify_baseline.txt."
			di as error "Quantile cutoffs not estimated."
			log close
			shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && ///
				notify "3162_pure_control_cutoff FAILED" "replication check failed; see verify_baseline.txt"
			exit 9
		}
		di as result "Replication check passed: zero / 0.01 / all match the published CSVs."
	}
}

di _newline "======================================================="
di "PURE-CONTROL CUTOFF RESULTS"
di "======================================================="
type "$tables/pure_control_cutoff_cutoffs.csv"

di "Finished: `c(current_date)' `c(current_time)'"
log close

* ── Table and figure ──────────────────────────────────────────────────────────
shell $python_exe "$programs/analysis/pure_control_cutoff/4270_table_pure_control_cutoff_latex.py" --preview
shell $python_exe "$programs/analysis/pure_control_cutoff/4280_figure_pure_control_cutoff.py"
shell $python_exe "$programs/analysis/pure_control_cutoff/4290_latex_figure_pure_control_cutoff.py" --preview

shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && ///
	notify "3162_pure_control_cutoff done" "direct effects by pure-control cutoff complete"
