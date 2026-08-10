********************************************************************************
* Wrapper: 5152_recentered_eventstudy.do for one outcome.
*
* Usage:  stata-mp -b do 5151_recentered_eventstudy.do <outcome>
*   e.g.  stata-mp -b do 5151_recentered_eventstudy.do lr_remdezr_w      (monthly)
*         stata-mp -b do 5151_recentered_eventstudy.do lr_remdezr_h_w    (hourly)
*
* Defaults to the monthly outcome when called with no argument, matching the
* script's historical behaviour. Draft.tex cites the HOURLY pair
* (h_recentered_spill.pdf, h_recentered_cf.pdf), which could not be produced
* before the export filenames were parameterized in 2026-08.
********************************************************************************

set more off
set varabbrev off

local outcome "`1'"
if "`outcome'" == "" local outcome "lr_remdezr_w"

if !inlist("`outcome'", "lr_remdezr_w", "lr_remdezr_h_w") {
    di as error "Unrecognized outcome '`outcome''."
    di as error "Expected lr_remdezr_w (monthly) or lr_remdezr_h_w (hourly)."
    exit 198
}

global rec_outcome "`outcome'"
di as result "[_run_recentered] outcome = $rec_outcome"

do "/kellogg/proj/lgg3230/UnionSpill/Programs/rand_inference/5152_recentered_eventstudy.do"
