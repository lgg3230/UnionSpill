********************************************************************************
* _setup.do -- shared environment setup for every analysis/ wrapper and for
* 0000_master.do. Run with `do "$root/Programs/analysis/_setup.do"` after the
* caller has set $root and its own $tables / $graphs / $logs.
*
*   1. Remembers $root in ~/.unionspill_root, so a later Stata session started
*      outside the project (e.g. the GUI) still finds it.
*   2. Finds a Python interpreter that can import the packages the table and
*      figure scripts need, unless $python_exe or env UNIONSPILL_PYTHON is set.
*   3. Creates $tables, $graphs and $logs (and missing parents): a fresh copy
*      of the project has no Logs/ subfolders and no untracked Tables/ or
*      Graphs/ ones.
********************************************************************************

local _home : env HOME
if `"`_home'"' == "" local _home : env USERPROFILE
local _home = subinstr(`"`_home'"', "\", "/", .)

* -- 1. Remember the project root ---------------------------------------------
if `"`_home'"' != "" {
	tempname _rf
	cap file open `_rf' using `"`_home'/.unionspill_root"', write text replace
	if !_rc {
		file write `_rf' `"$root"' _n
		file close `_rf'
	}
}

* -- 2. Python ------------------------------------------------------------------
* Candidates in order; the first that imports pandas, numpy and matplotlib wins.
* Interpreters under OneDrive / CloudStorage are skipped: a virtualenv synced by
* OneDrive can hang on import while files are fetched on demand.
if `"$python_exe"' == "" global python_exe : env UNIONSPILL_PYTHON
if `"$python_exe"' == "" {
	local _cands ""
	if c(os) == "Windows" {
		local _lad : env LOCALAPPDATA
		local _pd  : env ProgramData
		foreach _b in "`_home'/anaconda3" "`_home'/miniconda3" "`_home'/miniforge3" ///
		              "`_pd'/anaconda3" "`_pd'/miniconda3" {
			local _cands `"`_cands' "`_b'/python.exe""'
		}
		local _pyroot "`_lad'/Programs/Python"
		local _vers ""
		cap local _vers : dir `"`_pyroot'"' dirs "Python3*"
		foreach _v of local _vers {
			local _cands `"`_cands' "`_pyroot'/`_v'/python.exe""'
		}
		tempfile _where
		cap shell where python > "`_where'" 2>NUL
		cap {
			tempname _wh
			file open `_wh' using "`_where'", read text
			file read `_wh' _line
			while r(eof) == 0 {
				local _cands `"`_cands' "`_line'""'
				file read `_wh' _line
			}
			file close `_wh'
		}
	}
	else {
		local _cands `"/home/lgg3230/.conda/envs/venv_python312/bin/python"'
		foreach _b in "`_home'/miniconda3" "`_home'/anaconda3" "`_home'/miniforge3" ///
		              "`_home'/mambaforge" "`_home'/opt/anaconda3" "`_home'/opt/miniconda3" ///
		              "/opt/anaconda3" "/opt/miniconda3" "/opt/conda" {
			local _cands `"`_cands' "`_b'/bin/python3""'
		}
		local _cands `"`_cands' "/opt/homebrew/bin/python3" "/usr/local/bin/python3""'
		local _cands `"`_cands' "/Library/Frameworks/Python.framework/Versions/Current/bin/python3""'
		* python3 as the login shell resolves it
		tempfile _which
		cap shell command -v python3 > "`_which'" 2>/dev/null
		cap {
			tempname _wh
			file open `_wh' using "`_which'", read text
			file read `_wh' _line
			file close `_wh'
			if `"`_line'"' != "" local _cands `"`_cands' "`_line'""'
		}
		* conda environments
		foreach _e in "`_home'/.conda/envs" "`_home'/miniconda3/envs" "`_home'/anaconda3/envs" ///
		              "`_home'/miniforge3/envs" "`_home'/opt/anaconda3/envs" "/opt/anaconda3/envs" {
			local _envs ""
			cap local _envs : dir `"`_e'"' dirs "*"
			foreach _v of local _envs {
				local _cands `"`_cands' "`_e'/`_v'/bin/python""'
			}
		}
		local _cands `"`_cands' "/usr/bin/python3""'
	}

	tempfile _probe
	foreach _c of local _cands {
		local _c = subinstr(`"`_c'"', "\", "/", .)
		if strpos(`"`_c'"', "CloudStorage") | strpos(`"`_c'"', "OneDrive") | strpos(`"`_c'"', "WindowsApps") continue
		if !fileexists(`"`_c'"') continue
		cap erase "`_probe'"
		if c(os) == "Windows" shell "`_c'" -I -c "import pandas, numpy, matplotlib; open(r'`_probe'', 'w').write('ok')" 2>NUL
		else                  shell "`_c'" -I -c "import pandas, numpy, matplotlib; open(r'`_probe'', 'w').write('ok')" > /dev/null 2>&1
		if fileexists("`_probe'") {
			* quote paths with spaces so `shell $python_exe "script.py"` still works
			if strpos(`"`_c'"', " ") global python_exe `""`_c'""'
			else                     global python_exe `"`_c'"'
			continue, break
		}
	}
	if `"$python_exe"' == "" {
		di as error "No Python with pandas, numpy and matplotlib found; table and figure steps will fail."
		di as error "Install them (pip install pandas numpy matplotlib) or set env UNIONSPILL_PYTHON."
		global python_exe = cond(c(os) == "Windows", "python", "python3")
	}
}
di as text "python: $python_exe"

* -- 3. Output folders ------------------------------------------------------------
foreach _g in tables graphs logs {
	if `"${`_g'}"' == "" continue
	local _rel = subinstr(`"${`_g'}"', `"$root/"', "", 1)
	local _acc `"$root"'
	foreach _part in `=subinstr(`"`_rel'"', "/", " ", .)' {
		local _acc `"`_acc'/`_part'"'
		cap mkdir `"`_acc'"'
	}
}
