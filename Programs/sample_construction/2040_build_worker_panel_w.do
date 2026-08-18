********************************************************************************
* PROJECT: UNION SPILLOVERS
* PROGRAM: BUILD THE _w WORKER PANEL FOR 2030
*
* Closes the second tier-B gap. 2030 reads
* worker_year_pre_new_vs_nonnew_dec26.dta, which is absent from disk with no
* producer. It is not a distinct dataset: 2020 and 2030 compute the SAME wage
* percentiles by cnpj_year from the same object, 2020 under bare variable names
* and 2030 under _w names. Memory reference_w_suffix_workers_panel records that
* _w means "built from the sample workers panel" -- which is exactly
* lagos_sample_workers.dta, the output of 2010.
*
* So this script is a rename shim, not a reconstruction.
*
*   IN   $rais_firm/lagos_sample_workers.dta      (2010, rebuilt from 1050+1060)
*   OUT  $worker_w_out                            (default: the name 2030 wants)
*
* THE LOG / LEVEL TRAP -- the reason this is a separate script and not a
* one-liner. 2030 applies OPPOSITE conventions to two near-identically named
* hourly variables:
*
*   r_remdezr_h_w   treated as a LOG    (2030:17  rename r_remdezr_h_w lr_remdezr_h_w
*                                        2030:19  gen r_remdezr_h_w = exp(...))
*   r_remmedr_h_w   treated as a LEVEL  (2030:22  gen lr_remmedr_h_w = log(...))
*
* The worker panel supplies both as levels, so exactly one of them must be
* logged here. Getting this backwards would not error -- it would silently
* scale one wage series by exp(), and the percentiles built on it would be
* wrong in a way no downstream check would catch. The assertion at the end
* guards it.
********************************************************************************

version 17.0
set more off
set varabbrev off

if "$main" == "" global main "/kellogg/proj/lgg3230"
if "$rais_firm" == "" global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
if "$worker_w_out" == "" ///
    global worker_w_out "$rais_firm/worker_year_pre_new_vs_nonnew_dec26.dta"

local src "$rais_firm/lagos_sample_workers.dta"
capture confirm file "`src'"
if _rc {
    di as error "MISSING `src' -- run 2010_merge_lagos_worker.do first."
    exit 601
}

di as result _newline "2040_build_worker_panel_w.do"
di as text "  in  : `src'"
di as text "  out : $worker_w_out"

use identificad year lr_remdezr lr_remmedr r_remdezr_h r_remmedr_h using "`src'", clear
di as text "[in] `=_N' worker-year rows"

rename identificad identificad_w
rename lr_remdezr  lr_remdezr_w
rename lr_remmedr  lr_remmedr_w

* r_remdezr_h_w must arrive as a LOG, because 2030 exponentiates it.
gen double r_remdezr_h_w = ln(r_remdezr_h) if r_remdezr_h > 0 & !mi(r_remdezr_h)
label var r_remdezr_h_w "log hourly Dec wage (2030 expects a log under this name)"
drop r_remdezr_h

* r_remmedr_h_w must arrive as a LEVEL, because 2030 logs it.
rename r_remmedr_h r_remmedr_h_w
label var r_remmedr_h_w "hourly average wage, LEVEL (2030 logs it)"

********************************************************************************
* Guard the log/level convention.
*
* A naive magnitude cutoff does NOT work here: these are HOURLY wages, so a
* level of about R$10/hour and a log of about 2.4 are only a factor of four
* apart. The first version of this guard used "level > 20" and produced a false
* positive on real data.
*
* The sound test is that the two series must live on the same scale once the
* log is undone: exp(r_remdezr_h_w) is an hourly Dec wage and r_remmedr_h_w is
* an hourly average wage, so their medians should agree within a small factor.
* If the convention were inverted, they would differ by orders of magnitude.
********************************************************************************

quietly summarize r_remdezr_h_w, detail
local med_log = r(p50)
quietly summarize r_remmedr_h_w, detail
local med_lvl = r(p50)
local implied = exp(`med_log')
local ratio   = `implied' / `med_lvl'
di as text "  median r_remdezr_h_w (a LOG)        = " %9.4f `med_log'
di as text "  implied level exp(.)                = " %9.2f `implied'
di as text "  median r_remmedr_h_w (a LEVEL)      = " %9.2f `med_lvl'
di as text "  ratio implied/level (expect ~1)     = " %9.3f `ratio'

if `ratio' < 0.2 | `ratio' > 5 {
    di as error "exp(r_remdezr_h_w) = `implied' and r_remmedr_h_w = `med_lvl' are not"
    di as error "on the same scale (ratio `ratio'). The log/level convention is inverted."
    exit 459
}
di as result "[guard] log/level convention OK"

compress
save "$worker_w_out", replace
di as result _newline "SAVED: $worker_w_out"
di as text "  `=_N' obs"
