********************************************************************************
* WRAPPER: descriptives pipeline
* Runs 22_sample_descriptives.do then make_table_descriptives.py
********************************************************************************

* ── Set globals if running standalone ───────────────────────────────────────
if "$main" == "" {
    global klc  "/kellogg/proj/lgg3230"
    global main "$klc"
}

global rais_firm  "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global rais_aux   "$main/UnionSpill/Data/RAIS_aux"
global tables     "$main/UnionSpill/Tables"
global graphs     "$main/UnionSpill/Graphs"
global logs       "$main/UnionSpill/Logs"
global programs   "$main/UnionSpill/Programs"

* ── Step 1: Stata descriptives ───────────────────────────────────────────────
do "$programs/descriptives/22_sample_descriptives.do"

* ── Step 2: Python LaTeX table ───────────────────────────────────────────────
shell ~/.conda/envs/venv_python312/bin/python ///
    "$programs/descriptives/make_table_descriptives.py"
