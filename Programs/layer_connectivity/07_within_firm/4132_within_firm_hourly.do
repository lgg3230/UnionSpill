********************************************************************************
* 01b_within_firm_estimates_hw.do
* V2 within-firm specification ported from Programs/within_firm_final/R/04_engine.R.
* Produces the estimate CSVs for Tables A6, A7, A8 (edu2, gender, ten2):
*     $tables/a7_hw.csv        (schema: partition,col,outcome,b,se,bpre,sepre,n,firms,gxf)
*     $tables/a8_hw.csv        (partition,col,p90,outcome,b1,se1,b2,se2,bp1,sp1,bp2,sp2,peq,n,firms)
*     $tables/a6_group_hw.csv  (partition,group,avg_emp,avg_wage,avg_flows,conn)
*     $tables/a6_partition_hw.csv (partition,pct_both,v_tot,v_wi,v_bw,wi_pct,bw_pct)
*
* FAITHFUL-PORT NOTES (must match R for numbers to line up):
*   - Bins use Stata type-2 percentiles (_pctile), i.e. R's stata_pctile().
*     findInterval(x, c(p25,p50,p75)) == (x>=p25)+(x>=p50)+(x>=p75).
*   - reghdfe drops singletons iteratively by default == R drop_singletons().
*   - Connectivity scaled by the firm 90th percentile P90_FIRM.
*   - A8 equality test uses the normal approximation 2*Phi(-|b1-b2|/se(diff)).
* Expects globals set by _run_within_firm.do.
********************************************************************************

version 17.0

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

* ---- headline-logic pre-treatment bins (added 2026-08-03) -------------------
* Mirrors the bin construction in 4012_pct_tfpw.do so that the
* firm-level columns of A7/A8 are built exactly like the published spillover
* estimates.  Three differences from mkprebin above:
*   (1) size control uses ln(mean(firm_emp)) when mode=="logmean", matching the
*       headline; mkprebin's "mean" mode on l_firm_emp gives mean(ln(.)), which
*       is a different statistic and induces different quartiles.
*   (2) cuts with egen cut(..., group(4)) rather than _pctile + findInterval.
*   (3) zero-fills missing bins only when asked; the headline zero-fills the
*       per-worker-flow bin only, not the size or outcome bins.
* $SIZE_DEF ("logmean" default, "meanlog" alternative) selects the size
* convention so the run can follow either headline definition.
capture program drop mkprebinh
program define mkprebinh
    * args: out  src  by1  by2  mode  zerofill
    args out src by1 by2 mode zerofill
    cap drop __pre
    cap drop __preo
    cap drop __prem
    cap drop __bt
    if "`mode'" == "mean" {
        bysort `by1' `by2': egen double __preo = mean(`src') if inrange(year,2009,2011)
        bysort `by1' `by2': egen double __pre  = min(__preo)
    }
    else if "`mode'" == "logmean" {
        bysort `by1' `by2': egen double __preo = mean(`src') if inrange(year,2009,2011)
        bysort `by1' `by2': egen double __prem = min(__preo)
        gen double __pre = ln(__prem)
    }
    else {
        gen double __pre = `src'
    }
    egen __bt = cut(__pre) if year==2009 & in_balanced_panel==1, group(4)
    bysort `by1' `by2': egen byte `out' = min(__bt)
    if "`zerofill'" == "1" replace `out' = 0 if mi(`out')
    cap drop __pre
    cap drop __preo
    cap drop __prem
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
    * args: y  conn  absorb  ifmain  ifpre  gxfvar("" = none) samplevar("" = none)
    args y conn absorb ifmain ifpre gxf samplevar
    reghdfe `y' c.`conn'#c.treat_year if `ifmain', absorb(`absorb') vce(cluster identificad)
    return scalar b     = _b[c.`conn'#c.treat_year]
    return scalar se    = _se[c.`conn'#c.treat_year]
    return scalar n     = e(N)
    return scalar firms = e(N_clust)
    * Pre-treatment mean on this column's estimation sample (plan 2026-08-01).
    * Unit is whatever the regression uses -- group x firm x year here -- and
    * e(sample) carries the singleton drops. Taken before the placebo below.
    quietly sum `y' if e(sample) & inrange(year, 2009, 2011)
    return scalar meanpre = r(mean)
    if "`samplevar'" != "" {
        cap drop `samplevar'
        gen byte `samplevar' = e(sample)
    }
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
    * Pre-treatment mean on this column's estimation sample (plan 2026-08-01),
    * taken before the placebo regression below replaces e(sample).
    quietly sum `y' if e(sample) & inrange(year, 2009, 2011)
    return scalar meanpre = r(mean)
    lincom _b[c.`r1'#c.treat_year] - _b[c.`r2'#c.treat_year]
    return scalar peq = 2*normal(-abs(r(estimate)/r(se)))
    reghdfe `y' c.`r1'#c.placebo_year c.`r2'#c.placebo_year if `ifpre', absorb(`absorb') vce(cluster identificad)
    return scalar bp1 = _b[c.`r1'#c.placebo_year]
    return scalar sp1 = _se[c.`r1'#c.placebo_year]
    return scalar bp2 = _b[c.`r2'#c.placebo_year]
    return scalar sp2 = _se[c.`r2'#c.placebo_year]
end

* ---- balance table for rows dropped by v2 singleton removal --------------------
capture program drop balance_post
program define balance_post
    * args: posthandle partition col outcome rawcondition samplevar
    args handle partition col outcome cond samplevar
    foreach v in bal_pre_group_emp bal_pre_group_wage bal_group_conn bal_pre_firm_size bal_pre_group_share {
        quietly summarize `v' if (`cond') & `samplevar'==1
        post `handle' ("hourly") ("`partition'") ("`col'") ("`outcome'") ("`v'") ("kept") (r(N)) (r(mean))
        quietly summarize `v' if (`cond') & `samplevar'==0
        post `handle' ("hourly") ("`partition'") ("`col'") ("`outcome'") ("`v'") ("dropped") (r(N)) (r(mean))
    }

    foreach status in 1 0 {
        if `status' == 1 local sname "kept"
        if `status' == 0 local sname "dropped"
        preserve
            keep if (`cond') & `samplevar'==`status'
            keep if !mi(microregion_num)
            local total = _N
            if `total' > 0 {
                contract microregion_num
                local ndist = _N
                gen double __share = _freq / `total'
                gen double __sq = __share^2
                quietly summarize __sq
                local hhi = r(sum)
            }
            else {
                local ndist = 0
                local hhi = .
            }
        restore
        post `handle' ("hourly") ("`partition'") ("`col'") ("`outcome'") ("microregion_distinct") ("`sname'") (`total') (`ndist')
        post `handle' ("hourly") ("`partition'") ("`col'") ("`outcome'") ("microregion_hhi") ("`sname'") (`total') (`hhi')
    }
end

********************************************************************************
* SECTION 1: BUILD FIRM-LEVEL PANEL (build_firm_panel) -> tempfile FIRM
********************************************************************************

import delimited "$rais_aux/totalflows_wide_2007_2011.csv", stringcols(1) clear
tempfile tfwide
save `tfwide'

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear
keep identificad year lr_remdezr_h_w l_firm_emp treat_ultra in_balanced_panel ///
     lagos_sample_avg industry1 mode_base_month microregion totaltreat_pw_n totaltreat_pw_norm firm_emp
keep if lagos_sample_avg == 1 & year >= 2009
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
* headline logic: outcome bin = mean of the log, no zero-fill
mkprebinh lr_remdezr_h_w_pre4 lr_remdezr_h_w identificad "" mean ""
* headline logic: size bin = ln(mean(firm_emp)) by default, no zero-fill
if "$SIZE_DEF" == "meanlog" mkprebinh l_firm_emp_pre4 l_firm_emp identificad "" mean ""
if "$SIZE_DEF" != "meanlog" mkprebinh l_firm_emp_pre4 firm_emp   identificad "" logmean ""
* headline logic: flow bin is raw and IS zero-filled
mkprebinh totalflows_pw_pre4 tf_pre identificad "" raw "1"

* P90 of the official firm connectivity among untreated balanced-panel firms @2009
* (unique firm values; one row per firm-year already, so year==2009 gives one/firm)
preserve
    keep if treat_ultra==0 & in_balanced_panel==1 & year==2009 & !mi(totaltreat_pw_n)
    _pctile totaltreat_pw_n, p(90)
    global P90_FIRM = r(r1)
restore
di as result "P90_FIRM (official firm measure) = " %9.5f $P90_FIRM

* [AUDIT] overlay variant: rebuild the normalized regressor from the CURRENT measure
cap drop totaltreat_pw_norm
gen double totaltreat_pw_norm = totaltreat_pw_n / $P90_FIRM
di as result "[AUDIT] totaltreat_pw_norm rebuilt from current totaltreat_pw_n"


tempfile FIRM
save `FIRM'

********************************************************************************
* SECTION 2: OPEN POSTFILES
********************************************************************************

tempname A7 A8 A6G A6P BAL
tempfile A7dta A8dta A6Gdta A6Pdta BALdta
postfile `A7' str10 partition str12 col str6 outcome ///
    double(b se bpre sepre) long(n firms gxf) double(meanpre) using "`A7dta'", replace
postfile `A8' str10 partition str8 col str6 p90 str6 outcome ///
    double(b1 se1 b2 se2 bp1 sp1 bp2 sp2 peq) long(n firms) double(meanpre) using "`A8dta'", replace
postfile `A6G' str10 partition str10 group double(avg_emp avg_wage avg_flows conn) ///
    using "`A6Gdta'", replace
postfile `A6P' str10 partition double(pct_both v_tot v_wi v_bw wi_pct bw_pct) ///
    using "`A6Pdta'", replace
postfile `BAL' str10 exercise str10 partition str12 col str6 outcome ///
    str32 variable str8 sample long(n) double(value) using "`BALdta'", replace

local partitions "edu2 gender ten2"
if "$partitions" != "" local partitions "$partitions"
local table_suffix "$table_suffix"

********************************************************************************
* SECTION 3: A7 FIRM-LEVEL FULL-SAMPLE COLUMN (headline; identical across panels)
********************************************************************************

use `FIRM', clear
foreach y in lr_remdezr_h_w l_firm_emp {
    local oc = cond("`y'"=="l_firm_emp","emp","wage")
    if "`y'"=="l_firm_emp" local bins "i.l_firm_emp_pre4#i.year i.totalflows_pw_pre4#i.year"
    else                   local bins "i.lr_remdezr_h_w_pre4#i.year i.l_firm_emp_pre4#i.year i.totalflows_pw_pre4#i.year"
    local abs "identificad `bins' i.industry1_num#i.year i.mode_base_month_num#i.year i.microregion_num#i.year"
    local cond "treat_ultra==0 & in_balanced_panel==1 & !mi(`y')"
    didcol `y' totaltreat_pw_norm "`abs'" `"`cond'"' `"`cond' & year<=2011"' ""
    * write same firm_full row under each partition (mirrors R output layout)
    foreach p in `partitions' {
        post `A7' ("`p'") ("firm_full") ("`oc'") (r(b)) (r(se)) (r(bpre)) (r(sepre)) (r(n)) (r(firms)) (.) (r(meanpre))
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
	    encnum layer_id
	    egen firm_id        = group(identificad)
	    egen firm_layer_id  = group(identificad layer_id)

    * group-level pre-treatment quartile bins (by firm x layer)
    mkprebin lr_remdezr_h_layer_pre4      lr_remdezr_h_layer     identificad layer_id mean
    mkprebin l_layer_emp_pre4           l_layer_emp          identificad layer_id mean
    mkprebin layer_totalflows_pw_pre4   totalflows_layer_pw_n identificad layer_id raw

	    * firm-P90-scaled group connectivity
	    gen double conn = layer_treat_pw_n / $P90_FIRM

	    * firm-level pre-treatment bins for the v2 overall column
	    merge m:1 identificad year using `FIRM', ///
	        keepusing(lr_remdezr_h_w_pre4 l_firm_emp_pre4 totalflows_pw_pre4) ///
	        keep(master match) nogen

	    * pre-treatment balance variables for v2 singleton-dropped rows
	    cap drop __bal_wage_level
	    cap drop __bal_group_share
	    cap drop __bal_group_emp_o
	    cap drop __bal_group_wage_o
	    cap drop __bal_firm_size_o
	    cap drop __bal_group_share_o
	    gen double __bal_wage_level = exp(lr_remdezr_h_layer)
	    gen double __bal_group_share = layer_emp / firm_emp if firm_emp > 0
	    bysort identificad layer_id: egen double __bal_group_emp_o = mean(layer_emp) if inrange(year,2009,2011)
	    bysort identificad layer_id: egen double bal_pre_group_emp = min(__bal_group_emp_o)
	    bysort identificad layer_id: egen double __bal_group_wage_o = mean(__bal_wage_level) if inrange(year,2009,2011)
	    bysort identificad layer_id: egen double bal_pre_group_wage = min(__bal_group_wage_o)
	    bysort identificad layer_id: egen double __bal_firm_size_o = mean(firm_emp) if inrange(year,2009,2011)
	    bysort identificad layer_id: egen double bal_pre_firm_size = min(__bal_firm_size_o)
	    bysort identificad layer_id: egen double __bal_group_share_o = mean(__bal_group_share) if inrange(year,2009,2011)
	    bysort identificad layer_id: egen double bal_pre_group_share = min(__bal_group_share_o)
	    gen double bal_group_conn = conn
	    cap drop __bal_wage_level
	    cap drop __bal_group_share
	    cap drop __bal_group_emp_o
	    cap drop __bal_group_wage_o
	    cap drop __bal_firm_size_o
	    cap drop __bal_group_share_o

	    tempfile GP
	    save `GP'

    * ------------------------------------------------------------------
    * 4b. A6: group-level descriptives
    * ------------------------------------------------------------------
    preserve
        keep if s_base==1 & inrange(year,2009,2011)
        gen double wlev = exp(lr_remdezr_h_layer)
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
	        foreach y in lr_remdezr_h_layer l_layer_emp {
	            local oc = cond("`y'"=="l_layer_emp","emp","wage")
	            if "`y'"=="l_layer_emp" local bins "i.layer_id_num#i.l_layer_emp_pre4#i.year i.layer_id_num#i.layer_totalflows_pw_pre4#i.year"
	            else                    local bins "i.layer_id_num#i.lr_remdezr_h_layer_pre4#i.year i.layer_id_num#i.l_layer_emp_pre4#i.year i.layer_id_num#i.layer_totalflows_pw_pre4#i.year"
	            local groupfes "i.layer_id_num#i.mode_base_month_num#i.year i.layer_id_num#i.industry1_num#i.year i.layer_id_num#i.microregion_num#i.year"
	            if "`kind'"=="within" local fes "i.firm_layer_id `bins' i.firm_id#i.year `groupfes'"
	            else {
	                if "`y'"=="l_layer_emp" local firmbins "i.l_firm_emp_pre4#i.year i.totalflows_pw_pre4#i.year"
	                else                    local firmbins "i.lr_remdezr_h_w_pre4#i.year i.l_firm_emp_pre4#i.year i.totalflows_pw_pre4#i.year"
	                local fes "i.firm_layer_id `bins' `groupfes' `firmbins'"
	            }
	            local cond "s_base==1 & !mi(`y') & !mi(conn)"
	            didcol `y' conn "`fes'" `"`cond'"' `"`cond' & year<=2011"' "firm_layer_id" "__v2_keep"
	            post `A7' ("`p'") ("`kind'") ("`oc'") (r(b)) (r(se)) (r(bpre)) (r(sepre)) (r(n)) (r(firms)) (r(gxf)) (r(meanpre))
	            if "`y'"=="lr_remdezr_h_layer" {
	                balance_post `BAL' "`p'" "`kind'" "`oc'" `"`cond'"' "__v2_keep"
	            }
	            cap drop __v2_keep
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
    foreach y in lr_remdezr_h_w l_firm_emp {
        local oc = cond("`y'"=="l_firm_emp","emp","wage")
        if "`y'"=="l_firm_emp" local bins "i.l_firm_emp_pre4#i.year i.totalflows_pw_pre4#i.year"
        else                   local bins "i.lr_remdezr_h_w_pre4#i.year i.l_firm_emp_pre4#i.year i.totalflows_pw_pre4#i.year"
        local abs "identificad `bins' i.industry1_num#i.year i.mode_base_month_num#i.year i.microregion_num#i.year"
        local cond "treat_ultra==0 & in_balanced_panel==1 & !mi(`y')"
        didcol `y' totaltreat_pw_norm "`abs'" `"`cond'"' `"`cond' & year<=2011"' ""
        post `A7' ("`p'") ("firm") ("`oc'") (r(b)) (r(se)) (r(bpre)) (r(sepre)) (r(n)) (r(firms)) (.) (r(meanpre))
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
        foreach y in lr_remdezr_h_w l_firm_emp {
            local oc = cond("`y'"=="l_firm_emp","emp","wage")
            if "`y'"=="l_firm_emp" local bins "i.l_firm_emp_pre4#i.year i.totalflows_pw_pre4#i.year"
            else                   local bins "i.lr_remdezr_h_w_pre4#i.year i.l_firm_emp_pre4#i.year i.totalflows_pw_pre4#i.year"
            local abs "identificad `bins' i.industry1_num#i.year i.mode_base_month_num#i.year i.microregion_num#i.year"
            local cond "!mi(`y')"
            didrace `y' cG1 cG2 "`abs'" `"`cond'"' `"`cond' & year<=2011"'
            post `A8' ("`p'") ("firm") ("`mode'") ("`oc'") (r(b1)) (r(se1)) (r(b2)) (r(se2)) ///
                (r(bp1)) (r(sp1)) (r(bp2)) (r(sp2)) (r(peq)) (r(n)) (r(firms)) (r(meanpre))
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
        foreach y in lr_remdezr_h_layer l_layer_emp {
            local oc = cond("`y'"=="l_layer_emp","emp","wage")
            if "`y'"=="l_layer_emp" local bins "i.l_layer_emp_pre4#i.year i.layer_totalflows_pw_pre4#i.year"
            else                    local bins "i.lr_remdezr_h_layer_pre4#i.year i.l_layer_emp_pre4#i.year i.layer_totalflows_pw_pre4#i.year"
            local abs "i.firm_layer_id `bins' i.industry1_num#i.year i.mode_base_month_num#i.year i.microregion_num#i.year"
            local cond `"s_base==1 & layer_id=="`gl'" & !mi(`y') & !mi(cG1) & !mi(cG2)"'
            didrace `y' cG1 cG2 "`abs'" `"`cond'"' `"`cond' & year<=2011"'
            post `A8' ("`p'") ("g`gi'") ("firm") ("`oc'") (r(b1)) (r(se1)) (r(b2)) (r(se2)) ///
                (r(bp1)) (r(sp1)) (r(bp2)) (r(sp2)) (r(peq)) (r(n)) (r(firms)) (r(meanpre))
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
postclose `BAL'

* export the four estimate datasets to CSV (Python builds the LaTeX)
use `A7dta',  clear
export delimited using "$tables/a7_hw`table_suffix'.csv", replace
use `A8dta',  clear
export delimited using "$tables/a8_hw`table_suffix'.csv", replace
use `A6Gdta', clear
export delimited using "$tables/a6_group_hw`table_suffix'.csv", replace
use `A6Pdta', clear
export delimited using "$tables/a6_partition_hw`table_suffix'.csv", replace
use `BALdta', clear
export delimited using "$tables/singleton_balance_hw`table_suffix'.csv", replace

di as result "Wrote a7_hw`table_suffix'.csv, a8_hw`table_suffix'.csv, a6_group_hw`table_suffix'.csv, a6_partition_hw`table_suffix'.csv, singleton_balance_hw`table_suffix'.csv to $tables"

********************************************************************************
* END
********************************************************************************
