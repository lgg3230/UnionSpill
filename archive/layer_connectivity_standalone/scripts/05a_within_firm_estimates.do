********************************************************************************
* UNION SPILLOVERS — WITHIN-FIRM GROUP-LEVEL EXHIBITS (A6 / A7 / A8)
*
* Produces the estimate CSVs behind Tables 10, 11, 12 (log monthly wages) and
* Tables 22, 23, 24 (log hourly wages) of "Replication: Wages vs Hourly Wages":
*
*     $output/a6_group${wf_suffix}.csv     partition,group,avg_emp,avg_wage,avg_flows,conn
*     $output/a6_partition${wf_suffix}.csv partition,pct_both,v_tot,v_wi,v_bw,wi_pct,bw_pct
*     $output/a7${wf_suffix}.csv           partition,col,outcome,b,se,bpre,sepre,n,firms,gxf
*     $output/a8${wf_suffix}.csv           partition,col,p90,outcome,b1,se1,b2,se2,
*                                          bp1,sp1,bp2,sp2,peq,n,firms
*
* This is a standalone port of
*   Programs/layer_connectivity/07_within_firm/01_within_firm_estimates{,_hw}.do
* which is itself a Stata port of Gui's R package (00_functions.R + 01_estimates.R).
* The monthly and hourly variants differ only in which wage variable is read, so
* this file is parameterized by globals rather than duplicated.
*
* TWO CORRECTIONS relative to the May 2026 build of this package:
*   1. CURRENT CONNECTIVITY. The firm regressor totaltreat_pw_n is taken from
*      currentconn_overlay_totaltreat.dta (the recomputable measure), not the
*      frozen legacy column shipped inside the Lagos firm panel. Note that
*      totaltreat_pw_norm as stored is normalized by the LEGACY p90, so it is
*      rebuilt below from the current measure. Using it as-is is a silent bug.
*   2. CORRECTED LOG HOURLY WAGES. firm_layer_outcomes_*.dta now carries
*      lr_remdezr_h_layer = ln((remdezr / (horascontr * 4.348)) / IPCA_year).
*      The May build computed it with DuckDB LOG(), which is base 10, making
*      every hourly group-level magnitude a factor of ln(10) too small.
*
* FAITHFUL-PORT NOTES (must match R for numbers to line up):
*   - Bins use Stata type-2 percentiles (_pctile), i.e. R's stata_pctile().
*     findInterval(x, c(p25,p50,p75)) == (x>=p25)+(x>=p50)+(x>=p75).
*   - reghdfe drops singletons iteratively by default == R drop_singletons().
*   - Connectivity scaled by the firm 90th percentile P90_FIRM.
*   - A8 equality test uses the normal approximation 2*Phi(-|b1-b2|/se(diff)).
*
* Expects globals set by 05_run_within_firm.do (or run_all.do).
********************************************************************************

version 17.0

********************************************************************************
* SECTION 0: PATHS & PARAMETERS
********************************************************************************

* ── Paths: inherited from run_all.do; set manually if running standalone ──────
if "${standalone}" == "" {
	di as error "ERROR: global standalone not set."
	di as error "Run via scripts/05_run_within_firm.do or scripts/run_all.do, or"
	di as error "set it manually before calling this do-file:"
	di as error `"  global standalone "/path/to/layer_connectivity_standalone""'
	exit 198
}
global data       "$standalone/data"
global output     "$standalone/output"
global layer_data "$data"
global conn_data  "$data"
global rais_firm  "$data"
global rais_aux   "$data"
global tables     "$output"

* ── Wage variables: monthly by default, hourly when wf_suffix == "_hw" ────────
if "${wf_wage_firm}"  == "" global wf_wage_firm  "lr_remdezr_w"
if "${wf_wage_layer}" == "" global wf_wage_layer "lr_remdezr_layer"
if "${wf_partitions}" == "" global wf_partitions "edu2 gender ten2"

local wfirm  "$wf_wage_firm"
local wlayer "$wf_wage_layer"
local sfx    "$wf_suffix"

di as result "======================================================================"
di as result "Within-firm group exhibits (A6/A7/A8)"
di as result "  firm wage variable  : `wfirm'"
di as result "  layer wage variable : `wlayer'"
di as result "  partitions          : $wf_partitions"
di as result "  output suffix       : `sfx'"
di as result "======================================================================"

********************************************************************************
* HELPER PROGRAMS
********************************************************************************

* ---- Pre-treatment quartile bin (type-2 percentiles, held constant per unit) --
capture program drop mkprebin
program define mkprebin
    * args: out  src  by1  by2  mode("mean" -> pre = 2009-2011 mean; else raw src)
    args out src by1 by2 mode
    cap drop __pre
    cap drop __preo
    cap drop __bt
    if "`mode'" == "mean" {
        bysort `by1' `by2': egen double __preo = mean(`src') if inrange(year,2009,2011)
        bysort `by1' `by2': egen double __pre  = min(__preo)
    }
    else {
        gen double __pre = `src'
    }
    _pctile __pre if year==2009 & in_balanced_panel==1 & !mi(in_balanced_panel) & !mi(__pre), p(25 50 75)
    local q1 = r(r1)
    local q2 = r(r2)
    local q3 = r(r3)
    gen byte __bt = .
    replace __bt = (__pre>=`q1') + (__pre>=`q2') + (__pre>=`q3') ///
        if year==2009 & in_balanced_panel==1 & !mi(in_balanced_panel) & !mi(__pre)
    bysort `by1' `by2': egen byte `out' = min(__bt)
    replace `out' = 0 if mi(`out')
    cap drop __pre
    cap drop __preo
    cap drop __bt
end

* ---- encode a categorical to <name>_num (numeric passthrough if already numeric)
capture program drop encnum
program define encnum
    args src
    cap drop `src'_num
    capture confirm string variable `src'
    if !_rc  encode `src', gen(`src'_num)
    else     gen long `src'_num = `src'
end

* ---- single-regressor DiD + placebo (A7 columns) -----------------------------
capture program drop didcol
program define didcol, rclass
    * args: y  conn  absorb  ifmain  ifpre  gxfvar("" = none)
    args y conn absorb ifmain ifpre gxf
    reghdfe `y' c.`conn'#c.treat_year if `ifmain', absorb(`absorb') vce(cluster identificad)
    return scalar b     = _b[c.`conn'#c.treat_year]
    return scalar se    = _se[c.`conn'#c.treat_year]
    return scalar n     = e(N)
    return scalar firms = e(N_clust)
    if "`gxf'" != "" {
        cap drop __insamp
        cap drop __tag
        gen byte __insamp = e(sample)
        egen byte __tag = tag(`gxf') if __insamp==1
        qui count if __tag==1
        return scalar gxf = r(N)
        cap drop __insamp
        cap drop __tag
    }
    else return scalar gxf = .
    reghdfe `y' c.`conn'#c.placebo_year if `ifpre', absorb(`absorb') vce(cluster identificad)
    return scalar bpre  = _b[c.`conn'#c.placebo_year]
    return scalar sepre = _se[c.`conn'#c.placebo_year]
end

* ---- two-regressor horse race + equality test (A8 columns) --------------------
capture program drop didrace
program define didrace, rclass
    * args: y  r1  r2  absorb  ifmain  ifpre
    args y r1 r2 absorb ifmain ifpre
    reghdfe `y' c.`r1'#c.treat_year c.`r2'#c.treat_year if `ifmain', absorb(`absorb') vce(cluster identificad)
    return scalar b1    = _b[c.`r1'#c.treat_year]
    return scalar se1   = _se[c.`r1'#c.treat_year]
    return scalar b2    = _b[c.`r2'#c.treat_year]
    return scalar se2   = _se[c.`r2'#c.treat_year]
    return scalar n     = e(N)
    return scalar firms = e(N_clust)
    lincom _b[c.`r1'#c.treat_year] - _b[c.`r2'#c.treat_year]
    return scalar peq = 2*normal(-abs(r(estimate)/r(se)))
    reghdfe `y' c.`r1'#c.placebo_year c.`r2'#c.placebo_year if `ifpre', absorb(`absorb') vce(cluster identificad)
    return scalar bp1 = _b[c.`r1'#c.placebo_year]
    return scalar sp1 = _se[c.`r1'#c.placebo_year]
    return scalar bp2 = _b[c.`r2'#c.placebo_year]
    return scalar sp2 = _se[c.`r2'#c.placebo_year]
end

********************************************************************************
* SECTION 1: BUILD FIRM-LEVEL PANEL (build_firm_panel) -> tempfile FIRM
********************************************************************************

import delimited "$rais_aux/totalflows_wide_2007_2011.csv", stringcols(1) clear
tempfile tfwide
save `tfwide'

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear
keep identificad year `wfirm' l_firm_emp treat_ultra in_balanced_panel ///
     lagos_sample_avg industry1 mode_base_month microregion totaltreat_pw_n firm_emp
keep if lagos_sample_avg == 1 & year >= 2009

********************************************************************************
* SECTION 1b: CURRENT-CONNECTIVITY OVERLAY
* The Lagos firm panel ships a frozen legacy totaltreat_pw_n. Replace it with
* the current recomputable measure. totaltreat_pw_norm is NOT taken from the
* panel at all -- it is rebuilt from the current measure in Section 1c, because
* the stored column is normalized by the legacy p90.
********************************************************************************

rename totaltreat_pw_n totaltreat_pw_n_legacy
merge 1:1 identificad year using "$data/currentconn_overlay_totaltreat.dta", ///
    keepusing(totaltreat_pw_n) keep(master match) generate(_mg_overlay)
qui count if _mg_overlay != 3
if r(N) > 0 {
    di as error "ERROR: `r(N)' firm-year rows not matched by the connectivity overlay."
    di as error "currentconn_overlay_totaltreat.dta must cover every firm-year in the panel."
    exit 459
}
drop _mg_overlay
di as result "[overlay] totaltreat_pw_n replaced by the current recomputable measure"

merge m:1 identificad using `tfwide', keep(master match) nogen

* tf_pre = mean of the four pre-treatment year-pair flow rates (na.rm)
gen double tf_pre = 0
gen byte   tf_cnt = 0
foreach yp in totalflows_pw_07_08 totalflows_pw_08_09 totalflows_pw_09_10 totalflows_pw_10_11 {
    replace tf_pre = tf_pre + `yp' if !mi(`yp')
    replace tf_cnt = tf_cnt + 1   if !mi(`yp')
}
replace tf_pre = tf_pre / tf_cnt if tf_cnt > 0
replace tf_pre = .               if tf_cnt == 0
drop tf_cnt

gen byte treat_year   = (year >= 2012)
gen byte placebo_year = (year < 2011)

* encode categorical FE
encnum industry1
encnum mode_base_month
encnum microregion

* firm pre-treatment quartile bins (firm-level, one by-var)
mkprebin wage_pre4_firm    `wfirm'    identificad "" mean
mkprebin l_firm_emp_pre4   l_firm_emp identificad "" mean
mkprebin totalflows_pw_pre4 tf_pre    identificad "" raw

********************************************************************************
* SECTION 1c: P90 SCALE AND NORMALIZED FIRM REGRESSOR
* P90 of the current firm connectivity among untreated balanced-panel firms
* @2009 (one row per firm-year, so year==2009 gives one row per firm).
********************************************************************************

preserve
    keep if treat_ultra==0 & in_balanced_panel==1 & year==2009 & !mi(totaltreat_pw_n)
    _pctile totaltreat_pw_n, p(90)
    global P90_FIRM = r(r1)
restore
di as result "P90_FIRM (current firm measure) = " %9.5f $P90_FIRM

gen double totaltreat_pw_norm = totaltreat_pw_n / $P90_FIRM
di as result "[overlay] totaltreat_pw_norm rebuilt from current totaltreat_pw_n"

tempfile FIRM
save `FIRM'

********************************************************************************
* SECTION 2: OPEN POSTFILES
********************************************************************************

tempname A7 A8 A6G A6P
tempfile A7dta A8dta A6Gdta A6Pdta
postfile `A7' str10 partition str12 col str6 outcome ///
    double(b se bpre sepre) long(n firms gxf) using "`A7dta'", replace
postfile `A8' str10 partition str8 col str6 p90 str6 outcome ///
    double(b1 se1 b2 se2 bp1 sp1 bp2 sp2 peq) long(n firms) using "`A8dta'", replace
postfile `A6G' str10 partition str10 group double(avg_emp avg_wage avg_flows conn) ///
    using "`A6Gdta'", replace
postfile `A6P' str10 partition double(pct_both v_tot v_wi v_bw wi_pct bw_pct) ///
    using "`A6Pdta'", replace

local partitions "$wf_partitions"

********************************************************************************
* SECTION 3: A7 FIRM-LEVEL FULL-SAMPLE COLUMN (headline; identical across panels)
********************************************************************************

use `FIRM', clear
foreach y in `wfirm' l_firm_emp {
    local oc = cond("`y'"=="l_firm_emp","emp","wage")
    if "`y'"=="l_firm_emp" local bins "i.l_firm_emp_pre4#i.year i.totalflows_pw_pre4#i.year"
    else                   local bins "i.wage_pre4_firm#i.year i.l_firm_emp_pre4#i.year i.totalflows_pw_pre4#i.year"
    local abs "identificad `bins' i.industry1_num#i.year i.mode_base_month_num#i.year i.microregion_num#i.year"
    local cond "treat_ultra==0 & in_balanced_panel==1 & !mi(`y')"
    didcol `y' totaltreat_pw_norm "`abs'" `"`cond'"' `"`cond' & year<=2011"' ""
    * write same firm_full row under each partition (mirrors R output layout)
    foreach p in `partitions' {
        post `A7' ("`p'") ("firm_full") ("`oc'") (r(b)) (r(se)) (r(bpre)) (r(sepre)) (r(n)) (r(firms)) (.)
    }
}

********************************************************************************
* SECTION 4: LOOP OVER PARTITIONS
********************************************************************************

foreach p in `partitions' {

    if "`p'"=="edu2"   local g1 "no_hs"
    if "`p'"=="edu2"   local g2 "has_hs"
    if "`p'"=="gender" local g1 "female"
    if "`p'"=="gender" local g2 "male"
    if "`p'"=="ten2"   local g1 "lt12mo"
    if "`p'"=="ten2"   local g2 "ge12mo"

    di as result _newline "==================== PARTITION: `p' (`g1'/`g2') ===================="

    * ------------------------------------------------------------------
    * 4a. Build group-level panel (prep_layer)
    * ------------------------------------------------------------------
    use "$layer_data/firm_layer_outcomes_`p'.dta", clear
    keep if year >= 2009
    merge m:1 identificad layer_id using "$conn_data/firm_layer_connectivity_`p'.dta", ///
        keepusing(layer_treat_pw_n totalflows_layer_pw_n) keep(master match) nogen
    merge m:1 identificad year using "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", ///
        keepusing(treat_ultra in_balanced_panel lagos_sample_avg firm_emp industry1 mode_base_month microregion) ///
        keep(master match) nogen
    keep if lagos_sample_avg == 1

    gen byte treat_year   = (year >= 2012)
    gen byte placebo_year = (year < 2011)
    gen byte s_base = (lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1)

    encnum industry1
    encnum mode_base_month
    encnum microregion
    egen firm_id        = group(identificad)
    egen firm_layer_id  = group(identificad layer_id)

    * group-level pre-treatment quartile bins (by firm x layer)
    mkprebin wage_pre4_layer            `wlayer'              identificad layer_id mean
    mkprebin l_layer_emp_pre4           l_layer_emp           identificad layer_id mean
    mkprebin layer_totalflows_pw_pre4   totalflows_layer_pw_n identificad layer_id raw

    * firm-P90-scaled group connectivity
    gen double conn = layer_treat_pw_n / $P90_FIRM

    tempfile GP
    save `GP'

    * ------------------------------------------------------------------
    * 4b. A6: group-level descriptives
    * ------------------------------------------------------------------
    preserve
        keep if s_base==1 & inrange(year,2009,2011)
        gen double wlev = exp(`wlayer')
        * cell = one obs per firm x layer: means over 2009-2011 + conn (constant)
        collapse (mean) E=layer_emp wlev=wlev flows=totalflows_layer_pw_n ///
                 (firstnm) conn=layer_treat_pw_n, by(identificad layer_id)
        * group descriptives (cells with non-missing conn)
        foreach gg in `g1' `g2' {
            quietly summarize E     if layer_id=="`gg'" & !mi(conn)
            local aemp = r(mean)
            quietly summarize wlev  if layer_id=="`gg'" & !mi(conn)
            local awage = r(mean)
            quietly summarize flows if layer_id=="`gg'" & !mi(conn)
            local aflow = r(mean)
            quietly summarize conn  if layer_id=="`gg'" & !mi(conn)
            local aconn = r(mean)
            post `A6G' ("`p'") ("`gg'") (`aemp') (`awage') (`aflow') (`aconn')
        }
        * pct firms with both groups (among firms appearing with non-missing conn)
        keep if !mi(conn)
        bysort identificad: gen byte __ng = _N
        egen byte __ftag = tag(identificad)
        quietly summarize __ftag
        local n_firms_any = r(sum)
        quietly count if __ng==2 & __ftag==1
        local n_firms_both = r(N)
        local pct_both = `n_firms_both' / `n_firms_any'
        * variance decomposition on firms with >=2 groups
        keep if __ng >= 2
        quietly summarize conn
        local N   = r(N)
        local gm  = r(mean)
        bysort identificad: egen double __fmean = mean(conn)
        gen double __tot = (conn - `gm')^2
        gen double __wi  = (conn - __fmean)^2
        gen double __bw  = (__fmean - `gm')^2
        quietly summarize __tot
        local vtot = r(sum)/(`N'-1)
        quietly summarize __wi
        local vwi  = r(sum)/(`N'-1)
        quietly summarize __bw
        local vbw  = r(sum)/(`N'-1)
        post `A6P' ("`p'") (`pct_both') (`vtot') (`vwi') (`vbw') (`vwi'/`vtot') (`vbw'/`vtot')
    restore

    * ------------------------------------------------------------------
    * 4c. A7: within-firm and overall group columns (firm-P90 connectivity)
    * ------------------------------------------------------------------
    use `GP', clear
    foreach kind in within overall {
        foreach y in `wlayer' l_layer_emp {
            local oc = cond("`y'"=="l_layer_emp","emp","wage")
            if "`y'"=="l_layer_emp" local bins "i.l_layer_emp_pre4#i.year i.layer_totalflows_pw_pre4#i.year"
            else                    local bins "i.wage_pre4_layer#i.year i.l_layer_emp_pre4#i.year i.layer_totalflows_pw_pre4#i.year"
            if "`kind'"=="within" local fes "i.firm_layer_id `bins' i.firm_id#i.year"
            else                  local fes "i.firm_layer_id `bins' i.industry1_num#i.year i.mode_base_month_num#i.year i.microregion_num#i.year"
            local cond "s_base==1 & !mi(`y') & !mi(conn)"
            didcol `y' conn "`fes'" `"`cond'"' `"`cond' & year<=2011"' "firm_layer_id"
            post `A7' ("`p'") ("`kind'") ("`oc'") (r(b)) (r(se)) (r(bpre)) (r(sepre)) (r(n)) (r(firms)) (r(gxf))
        }
    }

    * ------------------------------------------------------------------
    * 4d. Build firm-level group connectivity constants (c1_raw, c2_raw)
    *     and the both-groups firm set, plus the A8 firm-column scales.
    * ------------------------------------------------------------------
    use `GP', clear
    * scales from s_base @2009 per group
    _pctile layer_treat_pw_n if s_base==1 & year==2009 & layer_id=="`g1'", p(90)
    local p90_1 = r(r1)
    _pctile layer_treat_pw_n if s_base==1 & year==2009 & layer_id=="`g2'", p(90)
    local p90_2 = r(r1)
    quietly summarize layer_treat_pw_n if s_base==1 & year==2009 & layer_id=="`g1'"
    local sd_1 = r(sd)
    quietly summarize layer_treat_pw_n if s_base==1 & year==2009 & layer_id=="`g2'"
    local sd_2 = r(sd)

    * both-groups firm set (s_base, 2 distinct layers)
    preserve
        keep if s_base==1
        egen byte __lt = tag(identificad layer_id)
        bysort identificad: egen byte __nl = total(__lt)
        keep if __nl==2
        keep identificad
        duplicates drop
        gen byte inboth = 1
        tempfile BOTH
        save `BOTH'
    restore

    * firm-level c1_raw / c2_raw = each group's layer_treat_pw_n (constant per firm)
    preserve
        keep identificad layer_id layer_treat_pw_n
        duplicates drop
        gen double c1_raw = layer_treat_pw_n if layer_id=="`g1'"
        gen double c2_raw = layer_treat_pw_n if layer_id=="`g2'"
        collapse (firstnm) c1_raw c2_raw, by(identificad)
        tempfile CW
        save `CW'
    restore

    * ------------------------------------------------------------------
    * 4e. A7: firm-level partition-sample column (footnote benchmark)
    * ------------------------------------------------------------------
    use `FIRM', clear
    merge m:1 identificad using `BOTH', keep(master match) nogen
    keep if inboth==1
    foreach y in `wfirm' l_firm_emp {
        local oc = cond("`y'"=="l_firm_emp","emp","wage")
        if "`y'"=="l_firm_emp" local bins "i.l_firm_emp_pre4#i.year i.totalflows_pw_pre4#i.year"
        else                   local bins "i.wage_pre4_firm#i.year i.l_firm_emp_pre4#i.year i.totalflows_pw_pre4#i.year"
        local abs "identificad `bins' i.industry1_num#i.year i.mode_base_month_num#i.year i.microregion_num#i.year"
        local cond "treat_ultra==0 & in_balanced_panel==1 & !mi(`y')"
        didcol `y' totaltreat_pw_norm "`abs'" `"`cond'"' `"`cond' & year<=2011"' ""
        post `A7' ("`p'") ("firm") ("`oc'") (r(b)) (r(se)) (r(bpre)) (r(sepre)) (r(n)) (r(firms)) (.)
    }

    * ------------------------------------------------------------------
    * 4f. A8: firm-outcome horse race under own / firm / per-SD scaling
    * ------------------------------------------------------------------
    foreach mode in own firm sd {
        if "`mode'"=="own"  local s1 = `p90_1'
        if "`mode'"=="own"  local s2 = `p90_2'
        if "`mode'"=="sd"   local s1 = `sd_1'
        if "`mode'"=="sd"   local s2 = `sd_2'
        if "`mode'"=="firm" local s1 = $P90_FIRM
        if "`mode'"=="firm" local s2 = $P90_FIRM

        use `FIRM', clear
        merge m:1 identificad using `CW', keep(master match) nogen
        gen double cG1 = c1_raw / (`s1')
        gen double cG2 = c2_raw / (`s2')
        keep if treat_ultra==0 & in_balanced_panel==1 & !mi(cG1) & !mi(cG2)
        foreach y in `wfirm' l_firm_emp {
            local oc = cond("`y'"=="l_firm_emp","emp","wage")
            if "`y'"=="l_firm_emp" local bins "i.l_firm_emp_pre4#i.year i.totalflows_pw_pre4#i.year"
            else                   local bins "i.wage_pre4_firm#i.year i.l_firm_emp_pre4#i.year i.totalflows_pw_pre4#i.year"
            local abs "identificad `bins' i.industry1_num#i.year i.mode_base_month_num#i.year i.microregion_num#i.year"
            local cond "!mi(`y')"
            didrace `y' cG1 cG2 "`abs'" `"`cond'"' `"`cond' & year<=2011"'
            post `A8' ("`p'") ("firm") ("`mode'") ("`oc'") (r(b1)) (r(se1)) (r(b2)) (r(se2)) ///
                (r(bp1)) (r(sp1)) (r(bp2)) (r(sp2)) (r(peq)) (r(n)) (r(firms))
        }
    }

    * ------------------------------------------------------------------
    * 4g. A8: group-outcome horse race (each group's own outcome), firm-P90
    * ------------------------------------------------------------------
    use `GP', clear
    merge m:1 identificad using `CW', keep(master match) nogen
    gen double cG1 = c1_raw / $P90_FIRM
    gen double cG2 = c2_raw / $P90_FIRM
    local gi 1
    foreach gl in `g1' `g2' {
        foreach y in `wlayer' l_layer_emp {
            local oc = cond("`y'"=="l_layer_emp","emp","wage")
            if "`y'"=="l_layer_emp" local bins "i.l_layer_emp_pre4#i.year i.layer_totalflows_pw_pre4#i.year"
            else                    local bins "i.wage_pre4_layer#i.year i.l_layer_emp_pre4#i.year i.layer_totalflows_pw_pre4#i.year"
            local abs "i.firm_layer_id `bins' i.industry1_num#i.year i.mode_base_month_num#i.year i.microregion_num#i.year"
            local cond `"s_base==1 & layer_id=="`gl'" & !mi(`y') & !mi(cG1) & !mi(cG2)"'
            didrace `y' cG1 cG2 "`abs'" `"`cond'"' `"`cond' & year<=2011"'
            post `A8' ("`p'") ("g`gi'") ("firm") ("`oc'") (r(b1)) (r(se1)) (r(b2)) (r(se2)) ///
                (r(bp1)) (r(sp1)) (r(bp2)) (r(sp2)) (r(peq)) (r(n)) (r(firms))
        }
        local ++gi
    }

    di as result "done: `p'"
}

********************************************************************************
* SECTION 5: CLOSE POSTFILES
********************************************************************************

postclose `A7'
postclose `A8'
postclose `A6G'
postclose `A6P'

* export the four estimate datasets to CSV (Python builds the LaTeX)
use `A7dta',  clear
export delimited using "$tables/a7`sfx'.csv", replace
use `A8dta',  clear
export delimited using "$tables/a8`sfx'.csv", replace
use `A6Gdta', clear
export delimited using "$tables/a6_group`sfx'.csv", replace
use `A6Pdta', clear
export delimited using "$tables/a6_partition`sfx'.csv", replace

di as result "Wrote a7`sfx'.csv, a8`sfx'.csv, a6_group`sfx'.csv, a6_partition`sfx'.csv to $tables"

********************************************************************************
* END
********************************************************************************
