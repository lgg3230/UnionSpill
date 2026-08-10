********************************************************************************
* PROJECT: UNION SPILLOVERS
* PROGRAM: BUILD THE CURRENT-CONNECTIVITY OVERLAY PANEL
*
* Closes hazard H1 of quality_reports/sample_provenance.md: every published
* exhibit loads the overlay panel, and until now no script in Programs/ built
* it. The recipe existed only inlined inside two estimators --
* archive/layer_connectivity_standalone/scripts/05a_within_firm_estimates.do:190-199
* (Stata) and archive/Programs/within_firm_final/R/02_build.R:29-41 (R port) -- both of
* which apply it in memory at estimation time and never persist the result.
* This script factors that block out into the build step it always should have
* been.
*
* INPUTS
*   $rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta   frozen panel
*       140,773 obs x 550 vars. Protected input: it has no producer either
*       (sample_provenance H2), so this script never writes to $rais_firm.
*   $cc_ingredient   currentconn_overlay_totaltreat.dta
*       140,773 obs x 4 vars (identificad year totaltreat_pw_n_frozen
*       totaltreat_pw_n), uniquely keyed on identificad-year, a 1:1 cover of
*       the panel.
*
* OUTPUT
*   $rais_firm_overlay/lagos_sample_sep24_pct_unionexp_ext_df2.dta
*       140,773 obs x 551 vars -- the frozen panel with totaltreat_pw_n
*       replaced by the current recomputable measure and the old value kept as
*       totaltreat_pw_n_frozen. No rows are dropped; no other column changes.
*
* WHAT THIS SCRIPT DELIBERATELY DOES NOT DO
*   It does not rebuild totaltreat_pw_norm. The published overlay carries that
*   column on the LEGACY p90 divisor, and every consumer rebuilds it in-script
*   (4012_pct_tfpw.do:141-146, 4122_within_firm.do:254-257,
*   4102_sample_descriptives.do:128-131, 13_pctiles_specs.do:38-41). Rebuilding it
*   here would silently change the stored column relative to the published
*   artifact. The two p90s are printed below so the discrepancy is visible in
*   the log rather than latent -- see memory: project_currentconn_overlay_trap.
********************************************************************************

version 17.0
set more off
set varabbrev off

********************************************************************************
* Paths -- overridable by a caller (0000_master.do sets all of these)
********************************************************************************

if "$main" == "" global main "/kellogg/proj/lgg3230"
if "$rais_firm" == "" global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
if "$rais_firm_overlay" == "" ///
    global rais_firm_overlay "$main/UnionSpill/Data/CBA_RAIS_firm_level_currentconn_overlay"

* The canonical ingredient now lives under Data/RAIS_aux/, built by
* 3010_build_currentconn_ingredient.do and verified value-identical to the two
* historical in-tree copies (cf _all silent). Those copies moved to archive/
* when the tree was cleaned, so they are kept here only as provenance
* fallbacks -- the chain no longer depends on them.
if "$cc_ingredient" == "" {
    foreach cand in ///
        "$main/UnionSpill/Data/RAIS_aux/currentconn_overlay_totaltreat.dta" ///
        "$main/UnionSpill/archive/Programs/within_firm_final/data/currentconn_overlay_totaltreat.dta" ///
        "$main/UnionSpill/archive/layer_connectivity_standalone/data/currentconn_overlay_totaltreat.dta" {
        if "$cc_ingredient" == "" {
            capture confirm file "`cand'"
            if _rc == 0 global cc_ingredient "`cand'"
        }
    }
}

local frozen "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta"
local target "$rais_firm_overlay/lagos_sample_sep24_pct_unionexp_ext_df2.dta"

********************************************************************************
* Preflight
********************************************************************************

capture confirm file "`frozen'"
if _rc {
    di as error "MISSING frozen panel: `frozen'"
    exit 601
}
if "$cc_ingredient" == "" {
    di as error "MISSING currentconn_overlay_totaltreat.dta -- set global cc_ingredient."
    exit 601
}
capture confirm file "$cc_ingredient"
if _rc {
    di as error "MISSING ingredient: $cc_ingredient"
    exit 601
}

* The published overlay is the artifact every number in the paper rests on.
* Refuse to overwrite it unless the caller has said so explicitly.
capture confirm file "`target'"
if _rc == 0 & "$overlay_allow_overwrite" != "1" {
    di as error "REFUSING to overwrite the published overlay panel:"
    di as error "  `target'"
    di as error "Set  global overlay_allow_overwrite = 1  to proceed, or set"
    di as error "global rais_firm_overlay to a scratch directory to build a copy"
    di as error "for comparison. See work item 2 of the replication plan."
    exit 602
}

di as result _newline "3020_build_currentconn_overlay_panel.do"
di as text "  frozen     : `frozen'"
di as text "  ingredient : $cc_ingredient"
di as text "  target     : `target'"

********************************************************************************
* 1. Frozen panel, unrestricted
********************************************************************************

use "`frozen'", clear
local n_in = _N
di as text "[in] frozen panel: `n_in' obs, `c(k)' vars"

isid identificad year

* Keep the pre-swap value under its own name so the swap is auditable in the
* saved file. Rename in place rather than clone: in the published artifact
* totaltreat_pw_n_frozen sits at position 90 -- the slot the legacy column
* occupied -- and the current measure is appended at 551. A rename reproduces
* that layout and preserves the float storage type for free.
cap drop totaltreat_pw_n_frozen
rename totaltreat_pw_n totaltreat_pw_n_frozen
label var totaltreat_pw_n_frozen "totaltreat_pw_n: frozen legacy value, pre-overlay"

* p90 implied by the legacy measure, on the spillover sample at 2009. This is
* the divisor baked into the panel's stored totaltreat_pw_norm. Expected value
* 0.02932389; the current measure gives 0.02925788 (printed in section 3).
preserve
    quietly keep if treat_ultra == 0 & in_balanced_panel == 1 & year == 2009 ///
        & !mi(totaltreat_pw_n_frozen)
    quietly _pctile totaltreat_pw_n_frozen, p(90)
    local p90_legacy = r(r1)
restore

********************************************************************************
* 2. Overlay swap
********************************************************************************

* NO `update replace` HERE, DELIBERATELY. With `update` in play, Stata's
* keep(master match) resolves "match" to result code 3 ONLY, so rows coded 4
* (missing updated) and 5 (nonmissing conflict) are dropped BEFORE the merge
* report is printed -- and the report then cheerfully shows "conflict 0".
* Those are exactly the 2,220 firm-years where the current measure differs from
* the legacy one, i.e. the entire content of the overlay. Renaming the master
* column first (above) removes the name collision, so a plain merge suffices
* and nothing can be silently dropped.
merge 1:1 identificad year using "$cc_ingredient", ///
    keepusing(totaltreat_pw_n) keep(master match) ///
    generate(_mg_overlay)

quietly count if _mg_overlay != 3
if r(N) > 0 {
    di as error "ERROR: " r(N) " firm-year rows not matched by the connectivity overlay."
    di as error "currentconn_overlay_totaltreat.dta must cover every firm-year in the panel."
    exit 459
}
drop _mg_overlay
label var totaltreat_pw_n "Current recomputable total flows"

assert _N == `n_in'
di as result "[overlay] totaltreat_pw_n replaced by the current recomputable measure"

********************************************************************************
* 3. The normalization trap, made visible
********************************************************************************

preserve
    quietly keep if treat_ultra == 0 & in_balanced_panel == 1 & year == 2009 ///
        & !mi(totaltreat_pw_n)
    quietly _pctile totaltreat_pw_n, p(90)
    local p90_current = r(r1)
restore

di as result _newline "p90 on the spillover sample at 2009 (untreated, balanced):"
di as text  "  legacy  measure : " %12.8f `p90_legacy'
di as text  "  current measure : " %12.8f `p90_current'
di as text  "  stored totaltreat_pw_norm is on the LEGACY divisor and is NOT rebuilt"
di as text  "  here. Consumers must rebuild it -- see the header note."

********************************************************************************
* 4. Save
********************************************************************************

label data "Lagos firm panel, current-connectivity overlay (totaltreat_pw_n swapped)"
save "`target'", replace

di as result _newline "SAVED: `target'"
di as text "  `=_N' obs, `c(k)' vars"
