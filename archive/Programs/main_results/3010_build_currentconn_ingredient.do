********************************************************************************
* PROJECT: UNION SPILLOVERS
* PROGRAM: BUILD currentconn_overlay_totaltreat.dta
*
* Tier-C sub-stage. Produces the ingredient consumed by
* 3020_build_currentconn_overlay_panel.do, which until now existed only as a 3.4 MB
* binary of unrecorded provenance sitting in two in-tree copies
* (archive/Programs/within_firm_final/data/ and archive/layer_connectivity_standalone/data/,
* byte-identical, md5 25b12592be9874082f51b1eecfe6e876).
*
* It is not an unrecorded input at all: its totaltreat_pw_n is the firm-level
* current measure from the committed connectivity stage, broadcast across the
* panel's firm-years. Verified 2026-08-07 -- 0 value mismatches across the
* 17,834 firms present in both, out of 17,836.
*
* INPUTS
*   $rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta   frozen panel
*       supplies the identificad-year spine and the frozen legacy column.
*   $rais_aux/connectivity_treat_2007_2011_agg.dta           tier-A output of
*       1050_yearly_employers.do + 1052_connectivity_treat_lagos.m. Firm-level (no
*       year), 3,607,222 rows, carries totaltreat_pw_n.
*
* OUTPUT
*   $cc_ingredient_out   currentconn_overlay_totaltreat.dta
*       identificad year totaltreat_pw_n_frozen totaltreat_pw_n
*       140,773 obs, uniquely keyed on identificad-year.
*
* THE ZERO RULE
*   Panel firms absent from the connectivity aggregate get totaltreat_pw_n = 0:
*   absence from the treat-connectivity file means no flows to treated firms.
*   Exactly 2 firms are in this position (09155391000279, 76639384002445), and
*   in the reference ingredient both carry 0 with a missing legacy value, which
*   is what this rule reproduces. The rule is asserted below, not assumed.
********************************************************************************

version 17.0
set more off
set varabbrev off

if "$main" == "" global main "/kellogg/proj/lgg3230"
if "$rais_firm" == "" global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
if "$rais_aux" == "" global rais_aux "$main/UnionSpill/Data/RAIS_aux"
if "$cc_ingredient_out" == "" ///
    global cc_ingredient_out "$rais_aux/currentconn_overlay_totaltreat.dta"

local frozen "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta"
local agg    "$rais_aux/connectivity_treat_2007_2011_agg.dta"

foreach f in "`frozen'" "`agg'" {
    capture confirm file "`f'"
    if _rc {
        di as error "MISSING input: `f'"
        exit 601
    }
}

di as result _newline "3010_build_currentconn_ingredient.do"
di as text "  spine : `frozen'"
di as text "  conn  : `agg'"
di as text "  out   : $cc_ingredient_out"

********************************************************************************
* 1. Spine: every firm-year in the panel, carrying the legacy value
********************************************************************************

use identificad year totaltreat_pw_n using "`frozen'", clear
isid identificad year
local n_in = _N
rename totaltreat_pw_n totaltreat_pw_n_frozen
label var totaltreat_pw_n_frozen "totaltreat_pw_n: frozen legacy value, pre-overlay"

********************************************************************************
* 2. Current firm-level measure, broadcast across years
********************************************************************************

preserve
    use identificad totaltreat_pw_n using "`agg'", clear
    * The aggregate is firm-level but ships one row per flow record; collapse to
    * the firm. Values are constant within firm, so firstnm is exact -- asserted.
    bysort identificad: egen double _mn = min(totaltreat_pw_n)
    bysort identificad: egen double _mx = max(totaltreat_pw_n)
    assert _mn == _mx | mi(_mn)
    drop _mn
    drop _mx
    bysort identificad: keep if _n == 1
    tempfile CONN
    quietly save `CONN'
restore

merge m:1 identificad using `CONN', keep(master match) generate(_mg_conn)
assert _N == `n_in'

* The zero rule, asserted rather than assumed: every unmatched firm-year must
* have a missing legacy value, which is what makes 0 the right fill.
quietly count if _mg_conn == 1 & !mi(totaltreat_pw_n_frozen)
if r(N) > 0 {
    di as error "ERROR: " r(N) " firm-years absent from the connectivity aggregate"
    di as error "carry a NONMISSING legacy value. The zero rule does not apply to"
    di as error "them and this script would silently invent a 0. Investigate."
    exit 459
}
quietly count if _mg_conn == 1
di as text "[zero rule] " r(N) " firm-years absent from the aggregate, set to 0"
replace totaltreat_pw_n = 0 if _mg_conn == 1
drop _mg_conn

label var totaltreat_pw_n "Current recomputable total flows"

********************************************************************************
* 3. Save
********************************************************************************

order identificad year totaltreat_pw_n_frozen totaltreat_pw_n
sort identificad year
isid identificad year
label data "Current-connectivity overlay: recomputed totaltreat_pw_n (frozen = legacy value)"
save "$cc_ingredient_out", replace

di as result _newline "SAVED: $cc_ingredient_out"
di as text "  `=_N' obs"
