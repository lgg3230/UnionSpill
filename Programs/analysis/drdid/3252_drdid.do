********************************************************************************
* UNION SPILLOVERS — DOUBLY ROBUST DiD (Sant'Anna & Zhao 2020)
* Purpose: Re-estimate the main direct and spillover effects with the doubly
*          robust DiD estimator, next to TWFE benchmarks that isolate what
*          changes between the paper's specification and DRDID.
* Estimator: drdid (Rios-Avila, Sant'Anna & Naqvi 2021), the Stata port of
*          the R package DRDID (psantanna.com/DRDID). Panel estimators;
*          influence-function SEs, which are clustered by firm.
* Output:  $tables/results_drdid.csv  one row per design x outcome x estimand x estimator
*          $tables/overlap_drdid.csv  propensity-score support / trimming diagnostics
*          $rais_aux/drdid_firm_wide[$DRDID_TAG].dta  firm-level 2x2 inputs (read by 3253_drdid_crosscheck.R)
* Auto-runs: Programs/analysis/drdid/4350_table_drdid_latex.py
*            Programs/analysis/drdid/4360_figure_drdid_es.py
*
* Design (see also Programs/analysis/drdid/README.md)
*  - 2x2 per estimand. Each firm contributes a base value and a target value:
*      post     target = mean 2012-16, base = mean 2009-11  (= the paper's pooled
*               treat x post coefficient; CBA periods 3-6 vs 1-2 for clauses)
*      placebo  target = mean 2009-10, base = 2011          (= the paper's placebo;
*               CBA period 1 vs 2 for clauses)
*      es_t     target = year t, base = 2011                (event study, ib2011;
*               CBA period k vs 2 for clauses)
*  - Covariates X, all pre-treatment and time-invariant, mirror the paper's
*    absorbed controls: own-outcome 2009-11 quartile, employment quartile,
*    2007-11 flows quartile, base month, and region x industry COARSENED to
*    state (27) and 2-digit industry group (10). The paper's microregion (502)
*    and industry1 (261) cells have no overlap: 1,175 treated firms sit in
*    microregions with no zero-connectivity control, which an outcome
*    regression extrapolates over but a propensity score cannot.
*  - Common support: firms in an X cell with no treated or no control firm are
*    dropped; controls with p(X) >= 0.995 are trimmed (the R package default).
*  - Designs (D = 1 vs D = 0):
*      dA    treated vs zero-connectivity untreated      (paper Panel A)
*      dC    treated vs all untreated                    (paper Panel B / code C)
*      sAny  untreated with connectivity > 0 vs = 0      (spillover, binary)
*      sT1-3 each tercile of positive connectivity vs = 0 (spillover dose)
*    The spillover treatment is binary because DRDID is a binary-treatment
*    estimator; mean_dose rows give E[connectivity (p90-scaled) | D = 1] so the
*    ATT can be read per unit of the paper's regressor.
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/drdid_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"
di "Stata version: `c(stata_version)'"

cap which drdid
if _rc {
	di as error "drdid not installed: ssc install drdid"
	exit 199
}

********************************************************************************
* SECTION 1: PANEL (same construction as 3012_pct_tfpw.do)
********************************************************************************

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

* ── Per-worker pairwise flows 2007-2011 (verbatim from 3012) ───────────────

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

* ── Period indicators (verbatim from 3012) ─────────────────────────────────

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

* ── Connectivity scaling (verbatim from 3012) ──────────────────────────────

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"
cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen totaltreat_pw_n_p90 = r(p90)
gen totaltreat_pw_norm = (totaltreat_pw_n / totaltreat_pw_n_p90)

* ── Pre-treatment means and 4-bin controls (verbatim from 3012) ────────────

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

cap drop l_firm_emp_pre
gen double l_firm_emp_pre = ln(firm_emp_pre)

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

* Every design below is a subset of the balanced panel.
keep if in_balanced_panel == 1

********************************************************************************
* SECTION 2: DESIGN VARIABLES (firm-constant, taken from the 2009 row)
********************************************************************************

sort identificad year
by identificad: gen int  uf     = floor(microregion[1] / 1000)
by identificad: gen int  ind2   = floor(industry1[1] / 100)
by identificad: gen int  month0 = mode_base_month[1]
by identificad: gen double conn0  = totaltreat_pw_n[1]
by identificad: gen double connn0 = totaltreat_pw_norm[1]
by identificad: gen long mreg0  = microregion[1]
by identificad: gen int  ind4   = industry1[1]
label var uf     "State (first two digits of the IBGE microregion code)"
label var ind2   "Industry group (industry1 / 100)"
label var mreg0  "Microregion (2009)"
label var ind4   "Industry, industry1 (2009)"

* Region and industry covariates for DRDID. Default: state and industry group.
* 3254_drdid_fine.do sets the paper's microregion and industry1 instead and
* lets the common-support step discard the cells without overlap.
if "$DRDID_GEO" == "" global DRDID_GEO "uf"
if "$DRDID_IND" == "" global DRDID_IND "ind2"
local geo "$DRDID_GEO"
local ind "$DRDID_IND"
di as result "DRDID region covariate: `geo'; industry covariate: `ind'"
label var month0 "CBA base month"
label var connn0 "Connectivity, scaled to the 2009 p90 among untreated firms"

gen byte exposed = (conn0 > 0) if treat_ultra == 0
label var exposed "Untreated firm with positive connectivity to treated firms"

cap drop dose3_o
cap drop dose3
xtile dose3_o = conn0 if treat_ultra == 0 & conn0 > 0 & year == 2009, nquantiles(3)
bys identificad: egen dose3 = min(dose3_o)
drop dose3_o
label var dose3 "Tercile of positive connectivity (untreated firms)"

* Design definitions: sample and binary treatment.
local designs "dA dC sAny sT1 sT2 sT3"
local smp_dA   "treat_ultra == 1 | (treat_ultra == 0 & conn0 == 0)"
local trt_dA   "treat_ultra"
local smp_dC   "!missing(treat_ultra)"
local trt_dC   "treat_ultra"
local smp_sAny "treat_ultra == 0"
local trt_sAny "exposed"
forvalues k = 1/3 {
	local smp_sT`k' "treat_ultra == 0 & (conn0 == 0 | dose3 == `k')"
	local trt_sT`k' "exposed"
}
* Event studies (DRDID and TWFE) for these designs only.
local es_designs "dA dC sAny"

* Outcomes: short tag, time structure, own-outcome quartile.
local outcomes "lr_remdezr_w lr_remdezr_h_w l_firm_emp numb_clauses"
local tag_lr_remdezr_w   "w"
local tag_lr_remdezr_h_w "hw"
local tag_l_firm_emp     "emp"
local tag_numb_clauses   "cl"

* Optional subsets for quick runs (e.g. global DRDID_OUTCOMES "lr_remdezr_h_w").
if "$DRDID_OUTCOMES" != "" local outcomes "$DRDID_OUTCOMES"
if "$DRDID_DESIGNS"  != "" local designs  "$DRDID_DESIGNS"

********************************************************************************
* SECTION 3: FIRM-LEVEL 2x2 SLOTS
*  slot 1 = base for placebo and event study (2011; CBA period 2)
*  slot 2 = base for pooled post (mean 2009-11; CBA periods 1-2)
*  slot 3 = pooled post target (mean 2012-16; CBA periods 3-6)
*  slot 4 = placebo target (mean 2009-10; CBA period 1)
*  slots 5-11 = event-study targets 2009 2010 2012 2013 2014 2015 2016
*               (clauses: CBA period 1 -> 5, period k >= 3 -> k + 4)
*  Pooled means average the firm's non-missing firm-year rows, which is how
*  the paper's balanced-panel TWFE weights them.
********************************************************************************

foreach y in lr_remdezr_w lr_remdezr_h_w l_firm_emp {
	local g "`tag_`y''"
	quietly {
		egen double y_`g'_1 = mean(cond(year == 2011, `y', .)), by(identificad)
		egen double y_`g'_2 = mean(cond(inrange(year, 2009, 2011), `y', .)), by(identificad)
		egen double y_`g'_3 = mean(cond(inrange(year, 2012, 2016), `y', .)), by(identificad)
		egen double y_`g'_4 = mean(cond(inrange(year, 2009, 2010), `y', .)), by(identificad)
		local s 5
		foreach yr in 2009 2010 2012 2013 2014 2015 2016 {
			egen double y_`g'_`s' = mean(cond(year == `yr', `y', .)), by(identificad)
			local ++s
		}
	}
}

* Clauses: one firm-year row per year, several rows can share a CBA period; the
* period value is the mean over those rows.
quietly {
	egen double y_cl_1 = mean(cond(cba_period == 2, numb_clauses, .)), by(identificad)
	egen double y_cl_2 = mean(cond(inrange(cba_period, 1, 2), numb_clauses, .)), by(identificad)
	egen double y_cl_3 = mean(cond(inrange(cba_period, 3, 6), numb_clauses, .)), by(identificad)
	egen double y_cl_4 = mean(cond(cba_period == 1, numb_clauses, .)), by(identificad)
	egen double y_cl_5 = mean(cond(cba_period == 1, numb_clauses, .)), by(identificad)
	gen double y_cl_6 = .
	forvalues k = 3/6 {
		local s = `k' + 4
		egen double y_cl_`s' = mean(cond(cba_period == `k', numb_clauses, .)), by(identificad)
	}
	gen double y_cl_11 = .
}

egen long fid = group(identificad)

tempfile panel
save `panel'

* Firm-level file: one row per firm.
keep if year == 2011
keep identificad fid treat_ultra exposed dose3 conn0 connn0 uf ind2 mreg0 ind4 month0 ///
	lr_remdezr_w_pre4 lr_remdezr_h_w_pre4 l_firm_emp_pre4 numb_clauses_pre4 ///
	totalflows_pw_pre_07_114 y_*
isid fid

********************************************************************************
* SECTION 4: COMMON SUPPORT AND TRIMMING
*  _support restricts a 0/1 sample variable (one row per firm in the sample) to
*  X cells that hold both treated and control firms, iterating until stable,
*  then trims controls with logit p(X) >= 0.995 (the R package's trim.level).
*  It runs here once per design x outcome on the pooled-post sample (these are
*  the diagnostics in overlap_drdid.csv and the TWFE benchmark samples), and
*  again inside every 2x2 in Section 7, whose subsample can lose cells.
********************************************************************************

capture program drop _support
program define _support, rclass
	syntax varname, TReat(varname) XCAT(varlist) [TRIM(real 0.995)]
	local s `varlist'
	quietly count if `s' & `treat' == 1
	local nt_in = r(N)
	quietly count if `s' & `treat' == 0
	local nc_in = r(N)

	tempvar h0 h1 ps
	local changed 1
	while `changed' {
		local changed 0
		foreach v of local xcat {
			cap drop `h0'
			cap drop `h1'
			quietly bys `v': egen byte `h0' = max(`treat' == 0 & `s')
			quietly bys `v': egen byte `h1' = max(`treat' == 1 & `s')
			quietly count if `s' & (!`h0' | !`h1')
			if r(N) > 0 {
				local changed 1
				quietly replace `s' = 0 if `s' & (!`h0' | !`h1')
			}
		}
	}
	quietly count if `s' & `treat' == 1
	return scalar drop_t = `nt_in' - r(N)
	quietly count if `s' & `treat' == 0
	return scalar drop_c = `nc_in' - r(N)

	local xfv ""
	foreach v of local xcat {
		local xfv "`xfv' i.`v'"
	}
	quietly logit `treat' `xfv' if `s'
	quietly predict double `ps' if `s', pr
	quietly count if `s' & `treat' == 0 & `ps' >= `trim'
	return scalar trim_c = r(N)
	quietly replace `s' = 0 if `s' & `treat' == 0 & `ps' >= `trim'

	quietly count if `s' & `treat' == 1
	return scalar n_treat = r(N)
	quietly count if `s' & `treat' == 0
	return scalar n_ctrl = r(N)
	quietly _pctile `ps' if `s' & `treat' == 1, percentiles(1 50 99)
	return scalar pt1  = r(r1)
	return scalar pt50 = r(r2)
	return scalar pt99 = r(r3)
	quietly _pctile `ps' if `s' & `treat' == 0, percentiles(50 99)
	return scalar pc50 = r(r1)
	return scalar pc99 = r(r2)
	quietly sum `ps' if `s' & `treat' == 0
	return scalar pcmax = r(max)
	return scalar nt_in = `nt_in'
	return scalar nc_in = `nc_in'
end

tempname oh
file open `oh' using "$tables/overlap_drdid.csv", write replace
file write `oh' "design;outcome;n_treat_in;n_ctrl_in;drop_cell_treat;drop_cell_ctrl;trim_ctrl;n_treat;n_ctrl;ps_treat_p01;ps_treat_p50;ps_treat_p99;ps_ctrl_p50;ps_ctrl_p99;ps_ctrl_max" _n

foreach y of local outcomes {
	local g "`tag_`y''"
	* main: the paper's controls (own-outcome quartile first);
	* nolag: the same without the outcome's own 2009-11 level, since conditioning
	* a DiD on pre-period outcome levels is itself a modelling choice.
	if "`y'" == "l_firm_emp" {
		local xcat_`g'       "l_firm_emp_pre4 totalflows_pw_pre_07_114 month0 `geo' `ind'"
		local xcat_nolag_`g' "totalflows_pw_pre_07_114 month0 `geo' `ind'"
	}
	else {
		local xcat_`g'       "`y'_pre4 l_firm_emp_pre4 totalflows_pw_pre_07_114 month0 `geo' `ind'"
		local xcat_nolag_`g' "l_firm_emp_pre4 totalflows_pw_pre_07_114 month0 `geo' `ind'"
	}
	foreach xs in xcat_`g' xcat_nolag_`g' {
		local fv ""
		foreach v of local `xs' {
			local fv "`fv' i.`v'"
		}
		local `xs'_fv "`fv'"
	}

	foreach ds of local designs {
		cap drop D
		gen byte D = (`trt_`ds'') if (`smp_`ds'')
		local s "s_`ds'_`g'"
		gen byte `s' = !missing(D) & !missing(y_`g'_2) & !missing(y_`g'_3)
		foreach v of local xcat_`g' {
			replace `s' = 0 if missing(`v')
		}
		_support `s', treat(D) xcat(`xcat_`g'')
		di as result "`ds' / `y': treated `r(n_treat)' (cell drop `r(drop_t)'), controls `r(n_ctrl)' (cell drop `r(drop_c)', trimmed `r(trim_c)')"
		file write `oh' "`ds';`y';`r(nt_in)';`r(nc_in)';`r(drop_t)';`r(drop_c)';`r(trim_c)';`r(n_treat)';`r(n_ctrl)';" ///
			%9.4f (r(pt1)) ";" %9.4f (r(pt50)) ";" %9.4f (r(pt99)) ";" ///
			%9.4f (r(pc50)) ";" %9.4f (r(pc99)) ";" %9.4f (r(pcmax)) _n
	}
}
file close `oh'
cap drop D

compress
save "$rais_aux/drdid_firm_wide$DRDID_TAG.dta", replace
tempfile firm
save `firm'

********************************************************************************
* SECTION 5: OUTPUT FILE AND HELPERS
********************************************************************************

tempname rh
file open `rh' using "$tables/results_drdid.csv", write replace
file write `rh' "design;outcome;estimand;estimator;b;se;p;n_treat;n_ctrl" _n
file close `rh'

capture program drop _wrow
program define _wrow
	* _wrow design outcome estimand estimator b se n_treat n_ctrl
	args ds y est mth b se nt nc
	local p = .
	if !missing(`b') & !missing(`se') & `se' > 0 local p = 2 * normal(-abs(`b' / `se'))
	tempname fh
	file open `fh' using "$tables/results_drdid.csv", write append
	file write `fh' "`ds';`y';`est';`mth';" %20.12g (`b') ";" %20.12g (`se') ";" ///
		%12.8f (`p') ";`nt';`nc'" _n
	file close `fh'
end

* drdid's improved DR estimator (drimp) fits the propensity score by inverse
* probability tilting (mlexp), and drdid does not pass on mlexp's convergence
* flag. At a solution the tilting weights balance every covariate exactly:
* sum over treated of x = sum over controls of exp(x'b) x. _iptcheck returns
* the largest violation, per treated firm, across the columns of e(iptb). It is
* ~1e-8 when the fit converged and O(1) when it did not (seen in thin clause
* event-study cells, where the R package also fails to converge and falls back
* to a logit).
capture program drop _iptcheck
program define _iptcheck, rclass
	syntax, TReat(varname) TOUSE(string)
	tempname B
	tempvar xb xc wx
	matrix `B' = e(iptb)
	quietly matrix score double `xb' = `B' if `touse'
	quietly count if `touse' & `treat' == 1
	local nt = r(N)
	local worst 0
	local names : colnames `B'
	foreach c of local names {
		cap drop `xc'
		if "`c'" == "_cons" quietly gen byte `xc' = 1
		else {
			* Base and omitted levels ("1b.uf", "3o.uf") carry no condition.
			if !regexm("`c'", "^([0-9]+)\.(.+)$") continue
			local lev = regexs(1)
			local var = regexs(2)
			quietly gen byte `xc' = (`var' == `lev')
		}
		quietly sum `xc' if `touse' & `treat' == 1, meanonly
		local st = r(sum)
		cap drop `wx'
		quietly gen double `wx' = exp(`xb') * `xc' if `touse' & `treat' == 0
		quietly sum `wx', meanonly
		local gap = abs(`st' - r(sum)) / `nt'
		if `gap' > `worst' local worst = `gap'
	}
	return scalar imbalance = `worst'
end

********************************************************************************
* SECTION 6: TWFE BENCHMARKS (firm-year panel)
*  twfe_paper       the paper's specification on the paper's sample
*                   (direct: treat_ultra; spillover: continuous connectivity)
*  twfe_paper_bin   the paper's absorbed controls, binary D, DRDID sample
*  twfe_coarse      DRDID's covariates x period, binary D, DRDID sample
*  Comparing them separates the treatment definition, the sample, the
*  covariates and the estimator.
********************************************************************************

use `panel', clear
merge m:1 fid using `firm', keepusing(s_*) assert(match) nogen

foreach y of local outcomes {
	local g "`tag_`y''"
	if "`y'" == "numb_clauses" {
		local tv    "cba_period"
		local postv "post_treat_cba"
		local plcv  "pre_treat_cba"
		local plcif "cba_period <= 2"
		local base  "2"
		local esper "1 3 4 5 6"
		local pretest "1.D#1.cba_period"
		local tif   "!missing(cba_period)"
	}
	else {
		local tv    "year"
		local postv "treat_year"
		local plcv  "placebo_year"
		local plcif "year <= 2011"
		local base  "2011"
		local esper "2009 2010 2012 2013 2014 2015 2016"
		local pretest "1.D#i(2009 2010).year"
		local tif   "1"
	}
	local fine "identificad i.industry1#i.`tv' i.mode_base_month#i.`tv' i.microregion#i.`tv' ib0.`y'_pre4#i.`tv' ib0.l_firm_emp_pre4#i.`tv' ib0.totalflows_pw_pre_07_114#i.`tv'"
	foreach xs in coarse coarse_nolag {
		local `xs' "identificad"
	}
	foreach v of local xcat_`g' {
		local coarse "`coarse' i.`v'#i.`tv'"
	}
	foreach v of local xcat_nolag_`g' {
		local coarse_nolag "`coarse_nolag' i.`v'#i.`tv'"
	}

	* Paper specification on the paper's samples (replicates Tables/pct_tfpw_cc).
	local s_direct_A "(treat_ultra==0 & totaltreat_pw_n==0 | treat_ultra==1)"
	local s_direct_C "!missing(treat_ultra)"
	foreach pp in A C {
		quietly reghdfe `y' treat_ultra##i.`postv' if `s_direct_`pp'' & `tif', ///
			absorb(`fine') vce(cluster identificad)
		local b  = _b[1.treat_ultra#1.`postv']
		local se = _se[1.treat_ultra#1.`postv']
		cap drop _tg
		egen _tg = tag(identificad) if e(sample)
		quietly count if _tg == 1 & treat_ultra == 1
		local nt = r(N)
		quietly count if _tg == 1 & treat_ultra == 0
		_wrow d`pp' `y' post twfe_paper `b' `se' `nt' `r(N)'
		quietly reghdfe `y' treat_ultra##i.`plcv' if `s_direct_`pp'' & `tif' & `plcif', ///
			absorb(`fine') vce(cluster identificad)
		_wrow d`pp' `y' placebo twfe_paper `=_b[1.treat_ultra#1.`plcv']' `=_se[1.treat_ultra#1.`plcv']' . .
	}
	quietly reghdfe `y' c.totaltreat_pw_norm##i.`postv' if treat_ultra == 0 & `tif', ///
		absorb(`fine') vce(cluster identificad)
	local b  = _b[1.`postv'#c.totaltreat_pw_norm]
	local se = _se[1.`postv'#c.totaltreat_pw_norm]
	cap drop _tg
	egen _tg = tag(identificad) if e(sample)
	quietly count if _tg == 1
	_wrow sAny `y' post twfe_paper_cont `b' `se' `r(N)' .
	quietly reghdfe `y' c.totaltreat_pw_norm##i.`plcv' if treat_ultra == 0 & `tif' & `plcif', ///
		absorb(`fine') vce(cluster identificad)
	_wrow sAny `y' placebo twfe_paper_cont `=_b[1.`plcv'#c.totaltreat_pw_norm]' `=_se[1.`plcv'#c.totaltreat_pw_norm]' . .

	* Binary D on the DRDID sample, with the paper's controls and with DRDID's.
	foreach ds of local designs {
		cap drop D
		gen byte D = (`trt_`ds'') if (`smp_`ds'')
		local s "s_`ds'_`g'"
		foreach ab in paper_bin coarse coarse_nolag {
			if "`ab'" == "paper_bin" local absorb "`fine'"
			else                     local absorb "``ab''"
			quietly reghdfe `y' i.D##i.`postv' if `s' & `tif', absorb(`absorb') vce(cluster identificad)
			local b  = _b[1.D#1.`postv']
			local se = _se[1.D#1.`postv']
			cap drop _tg
			egen _tg = tag(identificad) if e(sample)
			quietly count if _tg == 1 & D == 1
			local nt = r(N)
			quietly count if _tg == 1 & D == 0
			_wrow `ds' `y' post twfe_`ab' `b' `se' `nt' `r(N)'
			quietly reghdfe `y' i.D##i.`plcv' if `s' & `tif' & `plcif', absorb(`absorb') vce(cluster identificad)
			_wrow `ds' `y' placebo twfe_`ab' `=_b[1.D#1.`plcv']' `=_se[1.D#1.`plcv']' . .
		}
		if strpos(" `es_designs' ", " `ds' ") {
			quietly reghdfe `y' i.D##ib`base'.`tv' if `s' & `tif', absorb(`fine') vce(cluster identificad)
			foreach k of local esper {
				_wrow `ds' `y' es_`k' twfe_paper_bin `=_b[1.D#`k'.`tv']' `=_se[1.D#`k'.`tv']' . .
			}
			testparm `pretest'
			_wrow `ds' `y' pretrend_p twfe_paper_bin `r(p)' . . .
		}
		di as result "TWFE done: `ds' / `y'"
	}
}
cap drop D
cap drop _tg

********************************************************************************
* SECTION 7: DRDID (firm level, long over slots)
********************************************************************************

use `firm', clear
reshape long y_w_ y_hw_ y_emp_ y_cl_, i(fid) j(slot)

local methods "reg+stdipw+dripw+drimp"

foreach y of local outcomes {
	local g "`tag_`y''"
	if "`y'" == "numb_clauses" {
		local esslots "5 7 8 9 10"
		local eslab   "1 3 4 5 6"
		local preslots "5"
	}
	else {
		local esslots "5 6 7 8 9 10 11"
		local eslab   "2009 2010 2012 2013 2014 2015 2016"
		local preslots "5 6"
	}

	foreach ds of local designs {
		cap drop D
		gen byte D = (`trt_`ds'') if (`smp_`ds'')
		local s "s_`ds'_`g'"

		* Mean dose of the exposed group (spillover designs).
		if substr("`ds'", 1, 1) == "s" {
			quietly sum connn0 if `s' & D == 1 & slot == 1
			_wrow `ds' `y' mean_dose . `r(mean)' . `r(N)' .
		}

		* List of 2x2s: estimand, base slot, target slot, estimators.
		* List of 2x2s: estimand : base slot : target slot : estimators : covariates.
		local jobs "post:2:3:`methods':main post:2:3:reg+drimp:nolag placebo:1:4:reg+drimp:main"
		if strpos(" `es_designs' ", " `ds' ") {
			local i 0
			foreach sl of local esslots {
				local ++i
				local lab : word `i' of `eslab'
				local jobs "`jobs' es_`lab':1:`sl':reg+drimp:main"
			}
		}

		foreach job of local jobs {
			tokenize "`job'", parse(":")
			local est "`1'"
			local sa  "`3'"
			local sb  "`5'"
			local mlist = subinstr("`7'", "+", " ", .)
			local xset "`9'"
			if "`xset'" == "nolag" {
				local xc  "`xcat_nolag_`g''"
				local xfv "`xcat_nolag_`g'_fv'"
				local sfx "_nolag"
			}
			else {
				local xc  "`xcat_`g''"
				local xfv "`xcat_`g'_fv'"
				local sfx ""
			}

			* This 2x2's sample: firms with both values, then support and trimming
			* re-applied on it (one row per firm, the base slot), then spread to
			* both rows.
			cap drop _ok
			quietly bys fid: egen byte _ok = total(inlist(slot, `sa', `sb') & !missing(y_`g'_))
			quietly replace _ok = (_ok == 2)
			cap drop _js
			gen byte _js = `s' & _ok & slot == `sa'
			_support _js, treat(D) xcat(`xc')
			cap drop _jsf
			quietly bys fid: egen byte _jsf = max(_js)

			foreach m of local mlist {
				local stubopt ""
				if "`m'" == "drimp" & strpos(" `preslots' ", " `sb' ") & substr("`est'", 1, 3) == "es_" {
					local stubopt "stub(r`sb'_) replace"
				}
				* drdid's dripw and stdipw paths hit a Mata conformability error
				* (r(3200)) when the data in memory hold factor levels that the if
				* sample lacks (the tercile designs); they run on a kept copy.
				local sub = inlist("`m'", "dripw", "stdipw")
				if `sub' {
					preserve
					quietly keep if _jsf & inlist(slot, `sa', `sb')
				}
				capture quietly drdid y_`g'_ `xfv' if _jsf & inlist(slot, `sa', `sb'), ///
					ivar(fid) time(slot) treatment(D) `m' `stubopt'
				local rc = _rc
				if `rc' {
					if `sub' restore
					di as error "drdid failed (rc = `rc'): `ds' / `y' / `est' / `m'`sfx'"
					_wrow `ds' `y' `est' dr_`m'`sfx' . . . .
					continue
				}
				local b  = el(e(b), 1, 1)
				local se = sqrt(el(e(V), 1, 1))
				quietly count if e(sample) & slot == `sa' & D == 1
				local nt = r(N)
				quietly count if e(sample) & slot == `sa' & D == 0
				local nc = r(N)
				if `sub' restore
				_wrow `ds' `y' `est' dr_`m'`sfx' `b' `se' `nt' `nc'
				if "`m'" == "drimp" {
					_iptcheck, treat(D) touse(e(sample) & slot == `sa')
					local imb = r(imbalance)
					_wrow `ds' `y' `est' ipt_imbalance`sfx' `imb' . . .
					if `imb' > 1e-4 {
						di as error "drimp did not converge (IPT imbalance `imb'): `ds' / `y' / `est'`sfx'"
						if "`stubopt'" != "" cap drop r`sb'_att
					}
				}
				if "`stubopt'" != "" {
					local b`sb' = `b'
					local se`sb' = `se'
				}
			}
		}

		* Joint pre-trend Wald test from the drimp influence functions
		* (one firm-level IF per pre period; V = cov(IF) / n).
		if strpos(" `es_designs' ", " `ds' ") {
			local k : word count `preslots'
			local ok 1
			foreach sl of local preslots {
				cap confirm variable r`sl'_att
				if _rc local ok 0
			}
			if `ok' {
				preserve
				foreach sl of local preslots {
					quietly bys fid: egen double if_`sl' = mean(r`sl'_att)
				}
				quietly keep if slot == 1
				foreach sl of local preslots {
					quietly drop if missing(if_`sl')
				}
				local n = _N
				* Scale check: sd(IF) / sqrt(n) should reproduce the drdid SE.
				foreach sl of local preslots {
					quietly sum if_`sl'
					di as text "IF scale check `ds'/`y'/slot `sl': sd/sqrt(n) = " %9.6f r(sd)/sqrt(`n') "  drdid se = " %9.6f `se`sl''
				}
				local iflist ""
				foreach sl of local preslots {
					local iflist "`iflist' if_`sl'"
				}
				quietly corr `iflist', covariance
				matrix pjV = r(C) / `n'
				matrix pjb = J(1, `k', .)
				local i 0
				foreach sl of local preslots {
					local ++i
					matrix pjb[1, `i'] = `b`sl''
				}
				matrix pjW = pjb * invsym(pjV) * pjb'
				local pj = chi2tail(`k', el(pjW, 1, 1))
				restore
				_wrow `ds' `y' pretrend_p dr_drimp `pj' . . .
			}
			foreach sl of local preslots {
				cap drop r`sl'_att
			}
		}
		di as result "DRDID done: `ds' / `y'"
	}
}

di _newline(1)
di as result "All estimation complete."

log close
di as result "Finished: `c(current_date)' `c(current_time)'"

* ── Tables and figures ─────────────────────────────────────────────────────
if "$python_exe" == "" global python_exe "python3"
shell $python_exe "$programs/analysis/drdid/4350_table_drdid_latex.py" "$tables" "$DRDID_GEO" "$DRDID_IND"
shell $python_exe "$programs/analysis/drdid/4360_figure_drdid_es.py" "$tables" "$graphs"

********************************************************************************
* END OF DO-FILE
********************************************************************************
