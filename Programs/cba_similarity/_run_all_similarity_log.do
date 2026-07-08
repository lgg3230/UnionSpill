* Master runner: all similarity LOG variants EXCEPT cba_similarity (headline,
* run separately). Sets globals once, then runs each _log.do in sequence.
* Each script is wrapped in capture so one failure does not abort the rest.
set more off
set varabbrev off

if "`c(username)'" == "lgg3230" {
	global main "/kellogg/proj/lgg3230"
}
else if "`c(username)'" == "luisg" {
	global main "/Users/luisg/Library/CloudStorage/OneDrive-NorthwesternUniversity/4 - PhD/02_Research/Org_Econ BR/UnionSpillovers/Cluster"
}
else {
	di as error "Unknown username: `c(username)'. Set global main manually."
	exit 1
}

global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global rais_aux  "$main/UnionSpill/Data/RAIS_aux"
global tables    "$main/UnionSpill/Tables"
global graphs    "$main/UnionSpill/Graphs"
global logs      "$main/UnionSpill/Logs"
global programs  "$main/UnionSpill/Programs"

local scripts ///
	cba_similarity_avg ///
	cba_similarity_corr_w ///
	cba_similarity_pretreat_ref ///
	cba_similarity_pretreat_ref_uncorr_w ///
	cba_similarity_focal_frozen ///
	cba_self_similarity ///
	treated_cba_similarity ///
	treated_cba_self_similarity ///
	treated_cba_similarity_pretreat_ref ///
	treated_cba_similarity_pretreat_ref_uncorr_w

foreach s of local scripts {
	di as result _newline(2) "=========================================================="
	di as result ">>> Running `s'_log.do"
	di as result "=========================================================="
	capture noisily do "$programs/cba_similarity/`s'_log.do"
	if _rc {
		di as error ">>> `s'_log.do FAILED with rc = `_rc' — continuing"
	}
}

shell source "$programs/notify.sh" && notify "similarity_log batch done" "All similarity log1p variants finished (check logs for any failures)"
