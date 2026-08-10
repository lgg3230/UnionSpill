********************************************************************************
* SUBGROUP ANALYSIS — three sanity-check exercises
*
* Exercise A: CBA similarity recomputed at subgroup level (spillover only)
* Exercise B: Clause counts by subgroup — direct (Panels A/B/C) + spillover
* Exercise C: Composition shares (sg / numb_clauses) — direct (A/B/C) + spillover
*
* All regressions use cba_period spec with canonical FEs.
********************************************************************************

capture log close
local d = subinstr("`c(current_date)'"," ","_",.)
local t = subinstr("`c(current_time)'",":","",.)
log using "$logs/clause_types/subgroup_analysis_`d'_`t'.log", replace text

di "Started: `c(current_date)' `c(current_time)'"

********************************************************************************
* SECTION 1: LOAD DATA
********************************************************************************

use "$rais_firm/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear

preserve
	import delimited "$rais_aux/totalflows_wide_2007_2011.csv", clear
	tostring identificad, replace format(%014.0f) force
	tempfile totalflows_wide
	save `totalflows_wide'
restore

merge m:1 identificad using `totalflows_wide', keep(master match) nogen

gen double totalflows_pw_pre_07_11 = 0
gen        totalflows_pw_pre_07_11_cnt = 0
foreach yp in totalflows_pw_07_08 totalflows_pw_08_09 totalflows_pw_09_10 totalflows_pw_10_11 {
	replace totalflows_pw_pre_07_11     = totalflows_pw_pre_07_11 + `yp' if !missing(`yp')
	replace totalflows_pw_pre_07_11_cnt = totalflows_pw_pre_07_11_cnt + (!missing(`yp'))
}
replace totalflows_pw_pre_07_11 = totalflows_pw_pre_07_11 / totalflows_pw_pre_07_11_cnt ///
	if totalflows_pw_pre_07_11_cnt > 0
replace totalflows_pw_pre_07_11 = . if totalflows_pw_pre_07_11_cnt == 0
drop totalflows_pw_pre_07_11_cnt

keep if year >= 2009
keep if lagos_sample_avg == 1

********************************************************************************
* SECTION 2: VARIABLE CREATION
********************************************************************************

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

gen pre_treat_cba  = cond(cba_period < 2,  1, 0)
gen post_treat_cba = cond(cba_period >= 3, 1, 0) if !missing(cba_period)

local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

cap drop totaltreat_pw_n_p90
cap drop totaltreat_pw_norm
sum totaltreat_pw_n if `s_spill' & year == 2009, detail
gen totaltreat_pw_n_p90 = r(p90)
gen totaltreat_pw_norm  = totaltreat_pw_n / totaltreat_pw_n_p90

cap drop firm_emp_pre_o
cap drop firm_emp_pre
quietly {
	bys identificad: egen firm_emp_pre_o = mean(firm_emp) if inrange(year, 2009, 2011)
	bys identificad: egen firm_emp_pre   = min(firm_emp_pre_o)
	drop firm_emp_pre_o
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

cap drop numb_clauses_pre_o
cap drop numb_clauses_pre
quietly {
	bys identificad: egen numb_clauses_pre_o = mean(numb_clauses) if inrange(cba_period, 1, 2)
	bys identificad: egen numb_clauses_pre   = min(numb_clauses_pre_o)
	drop numb_clauses_pre_o
}
cap drop numb_clauses_pre4_o
cap drop numb_clauses_pre4
quietly {
	egen numb_clauses_pre4_o = cut(numb_clauses_pre) if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen numb_clauses_pre4 = min(numb_clauses_pre4_o)
	drop numb_clauses_pre4_o
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

********************************************************************************
* SECTION 3: CREATE SUBGROUP COUNT AND SHARE VARIABLES
********************************************************************************

di as result "Creating subgroup variables..."

local sg_ids "11 12 13 14 21 22 23 24 31 32 33 34 41 42 43 51 61 62 71 72 73 81 82 91"

local sg11_vars "cl_11des_sal cl_11iso_sal cl_11pis_sal cl_11rea_cor"
local sg12_vars "cl_12pag_sal"
local sg13_vars "cl_13rem_dsr cl_13sal_est cl_13sal_pro"
local sg14_vars "cl_14out_nor"
local sg21_vars "cl_21dec_ter cl_21gra_fun cl_21out_gra"
local sg22_vars "cl_22adi_hor cl_22adi_ins cl_22adi_not cl_22adi_pen cl_22adi_per cl_22adi_sob cl_22adi_tem cl_22out_adi"
local sg23_vars "cl_23aju_cus cl_23aux_ali cl_23aux_cre cl_23aux_doe cl_23aux_edu cl_23aux_hab cl_23aux_mat cl_23aux_mor cl_23aux_sau cl_23aux_tra cl_23out_aux"
local sg24_vars "cl_24apo cl_24com cl_24emp cl_24par_nos cl_24pre cl_24sal_fam cl_24seg_vid"
local sg31_vars "cl_31avi_pre cl_31des_dem cl_31sus_con"
local sg32_vars "cl_32con_tem cl_32est_apr"
local sg33_vars "cl_33maoobr_fai cl_33maoobr_fem cl_33maoobr_jov cl_33maoobr_tem cl_33nor_par cl_33out_gru cl_33por_nec"
local sg34_vars "cl_34out_nor"
local sg41_vars "cl_41ada_fun cl_41atr_fun cl_41ava_des cl_41out_nor cl_41par_dos cl_41pla_car cl_41qua_for cl_41tra_set"
local sg42_vars "cl_42ass_mor cl_42ass_sex cl_42fer_equ cl_42igu_opo cl_42nor_dis cl_42out_nor"
local sg43_vars "cl_43est_abo cl_43est_aci cl_43est_ado cl_43est_apo cl_43est_apr cl_43est_ger cl_43est_mae cl_43est_pai cl_43est_por cl_43est_ser cl_43out_est cl_43pol_man cl_43pol_par cl_43pro_pro"
local sg51_vars "cl_51aut_tra cl_51com_jor cl_51con_jor cl_51des_sem cl_51dur_hor cl_51fal cl_51int_par cl_51jor_esp cl_51out_dis cl_51pro_red cl_51sob cl_51tur_ini"
local sg61_vars "cl_61ace_ate cl_61aco_aci cl_61gar_por cl_61out_nor cl_61rea_aci"
local sg62_vars "cl_62cam_edu cl_62cip_com cl_62con_amb cl_62equ_pro cl_62equ_seg cl_62exa_med cl_62ins cl_62man_maq cl_62out_nor cl_62per cl_62pri_soc cl_62pro_sau cl_62tre_par cl_62uni"
local sg71_vars "cl_71dur_con cl_71fer_col cl_71rem_fer"
local sg72_vars "cl_72lic_abo cl_72lic_ado cl_72lic_mat cl_72lic_nao cl_72lic_rem"
local sg73_vars "cl_73out_dis"
local sg81_vars "cl_81ace_inf cl_81ace_sin cl_81gar_dir cl_81lib_emp cl_81out_dis cl_81pro_rel"
local sg82_vars "cl_82com_fab cl_82con_sin cl_82dir_opo cl_82out_dis cl_82rep_sin cl_82sin_cam"
local sg91_vars "cl_91apl_ins cl_91des_ins cl_91mec_sol cl_91out_dis cl_91reg_par cl_91ren_res"

local sg11_lbl "Wage adjustments"
local sg12_lbl "Wage payment"
local sg13_lbl "Other wages"
local sg14_lbl "Other wage rules"
local sg21_lbl "Bonuses"
local sg22_lbl "Pays"
local sg23_lbl "Assistances"
local sg24_lbl "Other incentives"
local sg31_lbl "Separations"
local sg32_lbl "Contract types"
local sg33_lbl "Hiring"
local sg34_lbl "Other contracting"
local sg41_lbl "Staffing"
local sg42_lbl "Working conditions"
local sg43_lbl "Empl. protections"
local sg51_lbl "Workday"
local sg61_lbl "Injuries"
local sg62_lbl "Prevention"
local sg71_lbl "Vacations"
local sg72_lbl "Leaves"
local sg73_lbl "Other time off"
local sg81_lbl "Union-firm relations"
local sg82_lbl "Union organization"
local sg91_lbl "Bargaining"

foreach sg of local sg_ids {
	cap drop sg`sg'
	gen double sg`sg' = 0
	foreach v of local sg`sg'_vars {
		replace sg`sg' = sg`sg' + `v' if !missing(`v')
	}
	replace sg`sg' = . if missing(numb_clauses)
}

foreach sg of local sg_ids {
	cap drop sh`sg'
	gen double sh`sg' = sg`sg' / numb_clauses if numb_clauses > 0
}

di as result "Subgroup variables created."

********************************************************************************
* SECTION 4: EXPORT CLAUSE DATA → PYTHON COMPUTES SUBGROUP SIMILARITY
********************************************************************************

di as result "Exporting clause data for Python..."

ds cl_*
local clause_vars `r(varlist)'

preserve
	keep if !missing(cba_period)
	keep identificad cba_period treat_ultra lagos_sample_avg in_balanced_panel `clause_vars'
	foreach v of local clause_vars {
		replace `v' = 0 if missing(`v')
	}
	save "$rais_aux/cba_clauses_by_period.dta", replace
restore

shell ~/.conda/envs/venv_python312/bin/python "$programs/clause_types/subgroup_prep.py"
di as result "Python subgroup similarity complete."

********************************************************************************
* SECTION 5: MERGE SUBGROUP SIMILARITY
********************************************************************************

merge m:1 identificad cba_period using "$rais_aux/subgroup_similarity_panel.dta", ///
	keep(master match) nogen

label var cosine_sg "Cosine similarity (subgroup level) to connected treated avg"

cap drop cosine_sg_pre_o
cap drop cosine_sg_pre
quietly {
	bys identificad: egen cosine_sg_pre_o = mean(cosine_sg) if inrange(cba_period, 1, 2)
	bys identificad: egen cosine_sg_pre   = min(cosine_sg_pre_o)
	drop cosine_sg_pre_o
}
cap drop cosine_sg_pre4_o
cap drop cosine_sg_pre4
quietly {
	egen cosine_sg_pre4_o = cut(cosine_sg_pre) if year == 2009 & in_balanced_panel == 1, group(4)
	bys identificad: egen cosine_sg_pre4 = min(cosine_sg_pre4_o)
	drop cosine_sg_pre4_o
	replace cosine_sg_pre4 = 0 if missing(cosine_sg_pre4)
}

********************************************************************************
* SECTION 6: FIXED EFFECTS AND SAMPLE MACROS
********************************************************************************

local spec        "subgroup"
local conn        "totaltreat_pw_norm"
local base_fe_cba "identificad i.industry1#i.cba_period i.microregion#i.cba_period i.mode_base_month#i.cba_period"
local extra_cba   "ib0.totalflows_pw_pre_07_114#i.cba_period"
local absorb_base "`base_fe_cba' ib0.numb_clauses_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

* Regression samples (treated + panel-specific control group)
local s_direct_A "(treat_ultra==0 & totaltreat_pw_n==0   | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1 & !missing(cba_period)"
local s_direct_B "(treat_ultra==0 & totaltreat_pw_n<=0.01 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1 & !missing(cba_period)"
local s_direct_C "(treat_ultra==0 | treat_ultra==1) & lagos_sample_avg==1 & in_balanced_panel==1 & !missing(cba_period)"
local s_spill    "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1 & !missing(cba_period)"

* Baseline mean samples (untreated control group pre-treatment, per panel)
local s_pre_A "treat_ultra==0 & totaltreat_pw_n==0   & lagos_sample_avg==1 & in_balanced_panel==1"
local s_pre_B "treat_ultra==0 & totaltreat_pw_n<=0.01 & lagos_sample_avg==1 & in_balanced_panel==1"
local s_pre_C "treat_ultra==0 & lagos_sample_avg==1 & in_balanced_panel==1"

********************************************************************************
* SECTION 7: EXERCISE A — SUBGROUP-LEVEL SIMILARITY (SPILLOVER)
********************************************************************************

di _newline(2)
di as result "========================================================"
di as result "EXERCISE A: Subgroup-level cosine similarity (spillover)"
di as result "========================================================"

capture erase "$tables/clause_types/results_spill_subgroup_similarity.csv"
tempname fh
file open `fh' using "$tables/clause_types/results_spill_subgroup_similarity.csv", write replace
file write `fh' "spec,section,outcome,row_type,value" _n
file close `fh'

local absorb_sim "`base_fe_cba' ib0.cosine_sg_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

reghdfe cosine_sg c.`conn'##post_treat_cba if `s_spill', ///
	absorb(`absorb_sim') vce(cluster identificad)

local b_post  = _b[1.post_treat_cba#c.`conn']
local se_post = _se[1.post_treat_cba#c.`conn']
local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
local n_obs   = e(N)
local n_estab = e(N_clust)

local stars_post ""
if `p_post' < 0.01                              local stars_post "***"
else if (`p_post' < 0.05 & `p_post' > 0.01)    local stars_post "**"
else if (`p_post' < 0.10 & `p_post' > 0.05)    local stars_post "*"

reghdfe cosine_sg c.`conn'##pre_treat_cba if `s_spill' & cba_period <= 2, ///
	absorb(`absorb_sim') vce(cluster identificad)

local b_pre  = _b[1.pre_treat_cba#c.`conn']
local se_pre = _se[1.pre_treat_cba#c.`conn']
local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

local stars_pre ""
if `p_pre' < 0.01                               local stars_pre "***"
else if (`p_pre' < 0.05 & `p_pre' > 0.01)      local stars_pre "**"
else if (`p_pre' < 0.10 & `p_pre' > 0.05)      local stars_pre "*"

reghdfe cosine_sg c.`conn'##ib2.cba_period if `s_spill', ///
	absorb(`absorb_sim') vce(cluster identificad) tolerance(1e-2)
capture testparm c.`conn'#1.cba_period
local pre_ftest_pval = cond(_rc == 0, r(p), .)

* Baseline mean: spillover sample, pre-treatment periods
quietly sum cosine_sg if `s_spill' & inrange(cba_period, 1, 2)
local mean_pre = r(mean)

tempname fh
file open `fh' using "$tables/clause_types/results_spill_subgroup_similarity.csv", write append
file write `fh' `""`spec'";"spill";"cosine_sg";"main";"'    %9.4f (`b_post') `"`stars_post'""' _n
file write `fh' `""`spec'";"spill";"cosine_sg";"main_se";"' %9.4f (`se_post') `"""' _n
file write `fh' `""`spec'";"spill";"cosine_sg";"pre";"'     %9.4f (`b_pre')  `"`stars_pre'""' _n
file write `fh' `""`spec'";"spill";"cosine_sg";"pre_se";"'  %9.4f (`se_pre') `"""' _n
file write `fh' `""`spec'";"spill";"cosine_sg";"n_obs";"'   %12.0fc (`n_obs') `"""' _n
file write `fh' `""`spec'";"spill";"cosine_sg";"n_estab";"' %12.0fc (`n_estab') `"""' _n
file write `fh' `""`spec'";"spill";"cosine_sg";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""' _n
file write `fh' `""`spec'";"spill";"cosine_sg";"mean_pre";"' %9.4f (`mean_pre') `"""' _n
file close `fh'

di as result "Exercise A complete."

********************************************************************************
* SECTIONS 8–9: HELPER — DIRECT + SPILLOVER LOOP FOR ONE OUTCOME FAMILY
* Exercises B (sg* counts) and C (sh* shares) use identical structure.
* Loop: foreach sg: panels A B C (direct), then spillover.
********************************************************************************

foreach exercise in B C {

	if "`exercise'" == "B" {
		local fam    "sg"
		local ex_lbl "Clause counts by subgroup"
		local csv_A  "$tables/clause_types/results_A_subgroup_counts.csv"
		local csv_B  "$tables/clause_types/results_B_subgroup_counts.csv"
		local csv_C  "$tables/clause_types/results_C_subgroup_counts.csv"
		local csv_sp "$tables/clause_types/results_spill_subgroup_counts.csv"
	}
	if "`exercise'" == "C" {
		local fam    "sh"
		local ex_lbl "Composition shares by subgroup"
		local csv_A  "$tables/clause_types/results_A_subgroup_shares.csv"
		local csv_B  "$tables/clause_types/results_B_subgroup_shares.csv"
		local csv_C  "$tables/clause_types/results_C_subgroup_shares.csv"
		local csv_sp "$tables/clause_types/results_spill_subgroup_shares.csv"
	}

	di _newline(2)
	di as result "========================================================"
	di as result "EXERCISE `exercise': `ex_lbl' (Panels A/B/C + spill)"
	di as result "========================================================"

	foreach csv in `"`csv_A'"' `"`csv_B'"' `"`csv_C'"' `"`csv_sp'"' {
		capture erase `csv'
		tempname fh
		file open `fh' using `csv', write replace
		file write `fh' "spec,section,outcome,label,row_type,value" _n
		file close `fh'
	}

	foreach sg of local sg_ids {

		local outcome "`fam'`sg'"
		local lbl     "`sg`sg'_lbl'"
		di as text "  [`exercise'] `outcome': `lbl'"

		* ── Direct: Panels A, B, C ────────────────────────────────────────────

		foreach panel in A B C {

			if "`panel'" == "A" {
				local s_use     "`s_direct_A'"
				local s_use_pre "`s_pre_A'"
				local section   "direct_A"
				local csv_out   "`csv_A'"
			}
			if "`panel'" == "B" {
				local s_use     "`s_direct_B'"
				local s_use_pre "`s_pre_B'"
				local section   "direct_B"
				local csv_out   "`csv_B'"
			}
			if "`panel'" == "C" {
				local s_use     "`s_direct_C'"
				local s_use_pre "`s_pre_C'"
				local section   "direct_C"
				local csv_out   "`csv_C'"
			}

			reghdfe `outcome' i.treat_ultra##post_treat_cba if `s_use', ///
				absorb(`absorb_base') vce(cluster identificad)

			local b_post  = _b[1.treat_ultra#1.post_treat_cba]
			local se_post = _se[1.treat_ultra#1.post_treat_cba]
			local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
			local n_obs   = e(N)
			local n_estab = e(N_clust)

			local stars_post ""
			if `p_post' < 0.01                              local stars_post "***"
			else if (`p_post' < 0.05 & `p_post' > 0.01)    local stars_post "**"
			else if (`p_post' < 0.10 & `p_post' > 0.05)    local stars_post "*"

			reghdfe `outcome' i.treat_ultra##pre_treat_cba if `s_use' & cba_period <= 2, ///
				absorb(`absorb_base') vce(cluster identificad)

			local b_pre  = _b[1.treat_ultra#1.pre_treat_cba]
			local se_pre = _se[1.treat_ultra#1.pre_treat_cba]
			local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

			local stars_pre ""
			if `p_pre' < 0.01                               local stars_pre "***"
			else if (`p_pre' < 0.05 & `p_pre' > 0.01)      local stars_pre "**"
			else if (`p_pre' < 0.10 & `p_pre' > 0.05)      local stars_pre "*"

			reghdfe `outcome' i.treat_ultra##ib2.cba_period if `s_use', ///
				absorb(`absorb_base') vce(cluster identificad) tolerance(1e-2)
			capture testparm 1.treat_ultra#1.cba_period
			local pre_ftest_pval = cond(_rc == 0, r(p), .)

			* Baseline mean: control group for this panel, pre-treatment periods
			quietly sum `outcome' if `s_use_pre' & inrange(cba_period, 1, 2)
			local mean_pre = r(mean)

			tempname fh
			file open `fh' using "`csv_out'", write append
			file write `fh' `""`spec'";"`section'";"`outcome'";"' `"`lbl'"' `";"main";"'    %9.4f (`b_post') `"`stars_post'""' _n
			file write `fh' `""`spec'";"`section'";"`outcome'";"' `"`lbl'"' `";"main_se";"' %9.4f (`se_post') `"""' _n
			file write `fh' `""`spec'";"`section'";"`outcome'";"' `"`lbl'"' `";"pre";"'     %9.4f (`b_pre')  `"`stars_pre'""' _n
			file write `fh' `""`spec'";"`section'";"`outcome'";"' `"`lbl'"' `";"pre_se";"'  %9.4f (`se_pre') `"""' _n
			file write `fh' `""`spec'";"`section'";"`outcome'";"' `"`lbl'"' `";"n_obs";"'   %12.0fc (`n_obs') `"""' _n
			file write `fh' `""`spec'";"`section'";"`outcome'";"' `"`lbl'"' `";"n_estab";"' %12.0fc (`n_estab') `"""' _n
			file write `fh' `""`spec'";"`section'";"`outcome'";"' `"`lbl'"' `";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""' _n
			file write `fh' `""`spec'";"`section'";"`outcome'";"' `"`lbl'"' `";"mean_pre";"' %9.4f (`mean_pre') `"""' _n
			file close `fh'
		}

		* ── Spillover ─────────────────────────────────────────────────────────

		reghdfe `outcome' c.`conn'##post_treat_cba if `s_spill', ///
			absorb(`absorb_base') vce(cluster identificad)

		local b_post  = _b[1.post_treat_cba#c.`conn']
		local se_post = _se[1.post_treat_cba#c.`conn']
		local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
		local n_obs   = e(N)
		local n_estab = e(N_clust)

		local stars_post ""
		if `p_post' < 0.01                              local stars_post "***"
		else if (`p_post' < 0.05 & `p_post' > 0.01)    local stars_post "**"
		else if (`p_post' < 0.10 & `p_post' > 0.05)    local stars_post "*"

		reghdfe `outcome' c.`conn'##pre_treat_cba if `s_spill' & cba_period <= 2, ///
			absorb(`absorb_base') vce(cluster identificad)

		local b_pre  = _b[1.pre_treat_cba#c.`conn']
		local se_pre = _se[1.pre_treat_cba#c.`conn']
		local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

		local stars_pre ""
		if `p_pre' < 0.01                               local stars_pre "***"
		else if (`p_pre' < 0.05 & `p_pre' > 0.01)      local stars_pre "**"
		else if (`p_pre' < 0.10 & `p_pre' > 0.05)      local stars_pre "*"

		reghdfe `outcome' c.`conn'##ib2.cba_period if `s_spill', ///
			absorb(`absorb_base') vce(cluster identificad) tolerance(1e-2)
		capture testparm c.`conn'#1.cba_period
		local pre_ftest_pval = cond(_rc == 0, r(p), .)

		* Baseline mean: spillover sample, pre-treatment periods
		quietly sum `outcome' if `s_spill' & inrange(cba_period, 1, 2)
		local mean_pre = r(mean)

		tempname fh
		file open `fh' using "`csv_sp'", write append
		file write `fh' `""`spec'";"spill";"`outcome'";"' `"`lbl'"' `";"main";"'    %9.4f (`b_post') `"`stars_post'""' _n
		file write `fh' `""`spec'";"spill";"`outcome'";"' `"`lbl'"' `";"main_se";"' %9.4f (`se_post') `"""' _n
		file write `fh' `""`spec'";"spill";"`outcome'";"' `"`lbl'"' `";"pre";"'     %9.4f (`b_pre')  `"`stars_pre'""' _n
		file write `fh' `""`spec'";"spill";"`outcome'";"' `"`lbl'"' `";"pre_se";"'  %9.4f (`se_pre') `"""' _n
		file write `fh' `""`spec'";"spill";"`outcome'";"' `"`lbl'"' `";"n_obs";"'   %12.0fc (`n_obs') `"""' _n
		file write `fh' `""`spec'";"spill";"`outcome'";"' `"`lbl'"' `";"n_estab";"' %12.0fc (`n_estab') `"""' _n
		file write `fh' `""`spec'";"spill";"`outcome'";"' `"`lbl'"' `";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""' _n
		file write `fh' `""`spec'";"spill";"`outcome'";"' `"`lbl'"' `";"mean_pre";"' %9.4f (`mean_pre') `"""' _n
		file close `fh'
	}

	di as result "Exercise `exercise' complete."
}

di as result "All exercises done."

********************************************************************************
* SECTION 10: ROBUSTNESS — ADD i.mode_union#i.cba_period TO SPILLOVER
********************************************************************************

di _newline(2)
di as result "========================================================"
di as result "SECTION 10: Spillover with union FE (mode_union#cba_period)"
di as result "========================================================"

local absorb_union    "`absorb_base' i.mode_union#i.cba_period"
local absorb_sim_union "`base_fe_cba' i.mode_union#i.cba_period ib0.cosine_sg_pre4#i.cba_period ib0.l_firm_emp_pre4#i.cba_period `extra_cba'"

* ── Exercise A: subgroup-level similarity ────────────────────────────────────

capture erase "$tables/clause_types/results_spill_subgroup_similarity_union.csv"
tempname fh
file open `fh' using "$tables/clause_types/results_spill_subgroup_similarity_union.csv", write replace
file write `fh' "spec,section,outcome,row_type,value" _n
file close `fh'

reghdfe cosine_sg c.`conn'##post_treat_cba if `s_spill', ///
	absorb(`absorb_sim_union') vce(cluster identificad)

local b_post  = _b[1.post_treat_cba#c.`conn']
local se_post = _se[1.post_treat_cba#c.`conn']
local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
local n_obs   = e(N)
local n_estab = e(N_clust)

local stars_post ""
if `p_post' < 0.01                              local stars_post "***"
else if (`p_post' < 0.05 & `p_post' > 0.01)    local stars_post "**"
else if (`p_post' < 0.10 & `p_post' > 0.05)    local stars_post "*"

reghdfe cosine_sg c.`conn'##pre_treat_cba if `s_spill' & cba_period <= 2, ///
	absorb(`absorb_sim_union') vce(cluster identificad)

local b_pre  = _b[1.pre_treat_cba#c.`conn']
local se_pre = _se[1.pre_treat_cba#c.`conn']
local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

local stars_pre ""
if `p_pre' < 0.01                               local stars_pre "***"
else if (`p_pre' < 0.05 & `p_pre' > 0.01)      local stars_pre "**"
else if (`p_pre' < 0.10 & `p_pre' > 0.05)      local stars_pre "*"

reghdfe cosine_sg c.`conn'##ib2.cba_period if `s_spill', ///
	absorb(`absorb_sim_union') vce(cluster identificad) tolerance(1e-2)
capture testparm c.`conn'#1.cba_period
local pre_ftest_pval = cond(_rc == 0, r(p), .)

quietly sum cosine_sg if `s_spill' & inrange(cba_period, 1, 2)
local mean_pre = r(mean)

tempname fh
file open `fh' using "$tables/clause_types/results_spill_subgroup_similarity_union.csv", write append
file write `fh' `""`spec'";"spill";"cosine_sg";"main";"'    %9.4f (`b_post') `"`stars_post'""' _n
file write `fh' `""`spec'";"spill";"cosine_sg";"main_se";"' %9.4f (`se_post') `"""' _n
file write `fh' `""`spec'";"spill";"cosine_sg";"pre";"'     %9.4f (`b_pre')  `"`stars_pre'""' _n
file write `fh' `""`spec'";"spill";"cosine_sg";"pre_se";"'  %9.4f (`se_pre') `"""' _n
file write `fh' `""`spec'";"spill";"cosine_sg";"n_obs";"'   %12.0fc (`n_obs') `"""' _n
file write `fh' `""`spec'";"spill";"cosine_sg";"n_estab";"' %12.0fc (`n_estab') `"""' _n
file write `fh' `""`spec'";"spill";"cosine_sg";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""' _n
file write `fh' `""`spec'";"spill";"cosine_sg";"mean_pre";"' %9.4f (`mean_pre') `"""' _n
file close `fh'

di as result "Section 10 Exercise A complete."

* ── Exercises B and C ────────────────────────────────────────────────────────

foreach exercise in B C {

	if "`exercise'" == "B" {
		local fam    "sg"
		local csv_sp "$tables/clause_types/results_spill_subgroup_counts_union.csv"
	}
	if "`exercise'" == "C" {
		local fam    "sh"
		local csv_sp "$tables/clause_types/results_spill_subgroup_shares_union.csv"
	}

	capture erase "`csv_sp'"
	tempname fh
	file open `fh' using "`csv_sp'", write replace
	file write `fh' "spec,section,outcome,label,row_type,value" _n
	file close `fh'

	foreach sg of local sg_ids {

		local outcome "`fam'`sg'"
		local lbl     "`sg`sg'_lbl'"

		reghdfe `outcome' c.`conn'##post_treat_cba if `s_spill', ///
			absorb(`absorb_union') vce(cluster identificad)

		local b_post  = _b[1.post_treat_cba#c.`conn']
		local se_post = _se[1.post_treat_cba#c.`conn']
		local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
		local n_obs   = e(N)
		local n_estab = e(N_clust)

		local stars_post ""
		if `p_post' < 0.01                              local stars_post "***"
		else if (`p_post' < 0.05 & `p_post' > 0.01)    local stars_post "**"
		else if (`p_post' < 0.10 & `p_post' > 0.05)    local stars_post "*"

		reghdfe `outcome' c.`conn'##pre_treat_cba if `s_spill' & cba_period <= 2, ///
			absorb(`absorb_union') vce(cluster identificad)

		local b_pre  = _b[1.pre_treat_cba#c.`conn']
		local se_pre = _se[1.pre_treat_cba#c.`conn']
		local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

		local stars_pre ""
		if `p_pre' < 0.01                               local stars_pre "***"
		else if (`p_pre' < 0.05 & `p_pre' > 0.01)      local stars_pre "**"
		else if (`p_pre' < 0.10 & `p_pre' > 0.05)      local stars_pre "*"

		reghdfe `outcome' c.`conn'##ib2.cba_period if `s_spill', ///
			absorb(`absorb_union') vce(cluster identificad) tolerance(1e-2)
		capture testparm c.`conn'#1.cba_period
		local pre_ftest_pval = cond(_rc == 0, r(p), .)

		quietly sum `outcome' if `s_spill' & inrange(cba_period, 1, 2)
		local mean_pre = r(mean)

		tempname fh
		file open `fh' using "`csv_sp'", write append
		file write `fh' `""`spec'";"spill";"`outcome'";"' `"`lbl'"' `";"main";"'    %9.4f (`b_post') `"`stars_post'""' _n
		file write `fh' `""`spec'";"spill";"`outcome'";"' `"`lbl'"' `";"main_se";"' %9.4f (`se_post') `"""' _n
		file write `fh' `""`spec'";"spill";"`outcome'";"' `"`lbl'"' `";"pre";"'     %9.4f (`b_pre')  `"`stars_pre'""' _n
		file write `fh' `""`spec'";"spill";"`outcome'";"' `"`lbl'"' `";"pre_se";"'  %9.4f (`se_pre') `"""' _n
		file write `fh' `""`spec'";"spill";"`outcome'";"' `"`lbl'"' `";"n_obs";"'   %12.0fc (`n_obs') `"""' _n
		file write `fh' `""`spec'";"spill";"`outcome'";"' `"`lbl'"' `";"n_estab";"' %12.0fc (`n_estab') `"""' _n
		file write `fh' `""`spec'";"spill";"`outcome'";"' `"`lbl'"' `";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""' _n
		file write `fh' `""`spec'";"spill";"`outcome'";"' `"`lbl'"' `";"mean_pre";"' %9.4f (`mean_pre') `"""' _n
		file close `fh'
	}

	di as result "Section 10 Exercise `exercise' (union FE) complete."
}

di as result "Section 10 complete."

********************************************************************************
* SECTION 11: SAMPLE SELECTION CHECK
* For each outcome: (1) run union FE spec to get e(sample), (2) run baseline
* spec on that exact sample. If baseline results vanish on restricted sample,
* the change was sample selection; if they survive, the union FE was doing work.
********************************************************************************

di _newline(2)
di as result "========================================================"
di as result "SECTION 11: Baseline restricted to union-FE sample"
di as result "========================================================"

* ── Exercise A: subgroup-level similarity ────────────────────────────────────

capture erase "$tables/clause_types/results_spill_subgroup_similarity_restricted.csv"
tempname fh
file open `fh' using "$tables/clause_types/results_spill_subgroup_similarity_restricted.csv", write replace
file write `fh' "spec,section,outcome,row_type,value" _n
file close `fh'

* Step 1: union FE spec → save sample
quietly reghdfe cosine_sg c.`conn'##post_treat_cba if `s_spill', ///
	absorb(`absorb_sim_union') vce(cluster identificad)
cap drop _insample_sim
gen byte _insample_sim = e(sample)

* Step 2: baseline spec on that sample
reghdfe cosine_sg c.`conn'##post_treat_cba if _insample_sim, ///
	absorb(`absorb_sim') vce(cluster identificad)

local b_post  = _b[1.post_treat_cba#c.`conn']
local se_post = _se[1.post_treat_cba#c.`conn']
local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
local n_obs   = e(N)
local n_estab = e(N_clust)

local stars_post ""
if `p_post' < 0.01                              local stars_post "***"
else if (`p_post' < 0.05 & `p_post' > 0.01)    local stars_post "**"
else if (`p_post' < 0.10 & `p_post' > 0.05)    local stars_post "*"

* Pre regression: union FE sample intersected with cba_period <= 2
quietly reghdfe cosine_sg c.`conn'##pre_treat_cba if `s_spill' & cba_period <= 2, ///
	absorb(`absorb_sim_union') vce(cluster identificad)
cap drop _insample_sim_pre
gen byte _insample_sim_pre = e(sample)

reghdfe cosine_sg c.`conn'##pre_treat_cba if _insample_sim_pre, ///
	absorb(`absorb_sim') vce(cluster identificad)

local b_pre  = _b[1.pre_treat_cba#c.`conn']
local se_pre = _se[1.pre_treat_cba#c.`conn']
local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

local stars_pre ""
if `p_pre' < 0.01                               local stars_pre "***"
else if (`p_pre' < 0.05 & `p_pre' > 0.01)      local stars_pre "**"
else if (`p_pre' < 0.10 & `p_pre' > 0.05)      local stars_pre "*"

quietly reghdfe cosine_sg c.`conn'##ib2.cba_period if `s_spill', ///
	absorb(`absorb_sim_union') vce(cluster identificad) tolerance(1e-2)
cap drop _insample_sim_es
gen byte _insample_sim_es = e(sample)

reghdfe cosine_sg c.`conn'##ib2.cba_period if _insample_sim_es, ///
	absorb(`absorb_sim') vce(cluster identificad) tolerance(1e-2)
capture testparm c.`conn'#1.cba_period
local pre_ftest_pval = cond(_rc == 0, r(p), .)

quietly sum cosine_sg if _insample_sim & inrange(cba_period, 1, 2)
local mean_pre = r(mean)

cap drop _insample_sim
cap drop _insample_sim_pre
cap drop _insample_sim_es

tempname fh
file open `fh' using "$tables/clause_types/results_spill_subgroup_similarity_restricted.csv", write append
file write `fh' `""`spec'";"spill";"cosine_sg";"main";"'    %9.4f (`b_post') `"`stars_post'""' _n
file write `fh' `""`spec'";"spill";"cosine_sg";"main_se";"' %9.4f (`se_post') `"""' _n
file write `fh' `""`spec'";"spill";"cosine_sg";"pre";"'     %9.4f (`b_pre')  `"`stars_pre'""' _n
file write `fh' `""`spec'";"spill";"cosine_sg";"pre_se";"'  %9.4f (`se_pre') `"""' _n
file write `fh' `""`spec'";"spill";"cosine_sg";"n_obs";"'   %12.0fc (`n_obs') `"""' _n
file write `fh' `""`spec'";"spill";"cosine_sg";"n_estab";"' %12.0fc (`n_estab') `"""' _n
file write `fh' `""`spec'";"spill";"cosine_sg";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""' _n
file write `fh' `""`spec'";"spill";"cosine_sg";"mean_pre";"' %9.4f (`mean_pre') `"""' _n
file close `fh'

di as result "Section 11 Exercise A complete."

* ── Exercises B and C ────────────────────────────────────────────────────────

foreach exercise in B C {

	if "`exercise'" == "B" {
		local fam    "sg"
		local csv_sp "$tables/clause_types/results_spill_subgroup_counts_restricted.csv"
	}
	if "`exercise'" == "C" {
		local fam    "sh"
		local csv_sp "$tables/clause_types/results_spill_subgroup_shares_restricted.csv"
	}

	capture erase "`csv_sp'"
	tempname fh
	file open `fh' using "`csv_sp'", write replace
	file write `fh' "spec,section,outcome,label,row_type,value" _n
	file close `fh'

	foreach sg of local sg_ids {

		local outcome "`fam'`sg'"
		local lbl     "`sg`sg'_lbl'"

		* Step 1: union FE spec → save e(sample)
		quietly reghdfe `outcome' c.`conn'##post_treat_cba if `s_spill', ///
			absorb(`absorb_union') vce(cluster identificad)
		cap drop _insample
		gen byte _insample = e(sample)

		* Step 2: baseline on that sample
		reghdfe `outcome' c.`conn'##post_treat_cba if _insample, ///
			absorb(`absorb_base') vce(cluster identificad)

		local b_post  = _b[1.post_treat_cba#c.`conn']
		local se_post = _se[1.post_treat_cba#c.`conn']
		local p_post  = 2*ttail(e(df_r), abs(`b_post'/`se_post'))
		local n_obs   = e(N)
		local n_estab = e(N_clust)

		local stars_post ""
		if `p_post' < 0.01                              local stars_post "***"
		else if (`p_post' < 0.05 & `p_post' > 0.01)    local stars_post "**"
		else if (`p_post' < 0.10 & `p_post' > 0.05)    local stars_post "*"

		quietly reghdfe `outcome' c.`conn'##pre_treat_cba if `s_spill' & cba_period <= 2, ///
			absorb(`absorb_union') vce(cluster identificad)
		cap drop _insample_pre
		gen byte _insample_pre = e(sample)

		reghdfe `outcome' c.`conn'##pre_treat_cba if _insample_pre, ///
			absorb(`absorb_base') vce(cluster identificad)

		local b_pre  = _b[1.pre_treat_cba#c.`conn']
		local se_pre = _se[1.pre_treat_cba#c.`conn']
		local p_pre  = 2*ttail(e(df_r), abs(`b_pre'/`se_pre'))

		local stars_pre ""
		if `p_pre' < 0.01                               local stars_pre "***"
		else if (`p_pre' < 0.05 & `p_pre' > 0.01)      local stars_pre "**"
		else if (`p_pre' < 0.10 & `p_pre' > 0.05)      local stars_pre "*"

		quietly reghdfe `outcome' c.`conn'##ib2.cba_period if `s_spill', ///
			absorb(`absorb_union') vce(cluster identificad) tolerance(1e-2)
		cap drop _insample_es
		gen byte _insample_es = e(sample)

		reghdfe `outcome' c.`conn'##ib2.cba_period if _insample_es, ///
			absorb(`absorb_base') vce(cluster identificad) tolerance(1e-2)
		capture testparm c.`conn'#1.cba_period
		local pre_ftest_pval = cond(_rc == 0, r(p), .)

		quietly sum `outcome' if _insample & inrange(cba_period, 1, 2)
		local mean_pre = r(mean)

		cap drop _insample
		cap drop _insample_pre
		cap drop _insample_es

		tempname fh
		file open `fh' using "`csv_sp'", write append
		file write `fh' `""`spec'";"spill";"`outcome'";"' `"`lbl'"' `";"main";"'    %9.4f (`b_post') `"`stars_post'""' _n
		file write `fh' `""`spec'";"spill";"`outcome'";"' `"`lbl'"' `";"main_se";"' %9.4f (`se_post') `"""' _n
		file write `fh' `""`spec'";"spill";"`outcome'";"' `"`lbl'"' `";"pre";"'     %9.4f (`b_pre')  `"`stars_pre'""' _n
		file write `fh' `""`spec'";"spill";"`outcome'";"' `"`lbl'"' `";"pre_se";"'  %9.4f (`se_pre') `"""' _n
		file write `fh' `""`spec'";"spill";"`outcome'";"' `"`lbl'"' `";"n_obs";"'   %12.0fc (`n_obs') `"""' _n
		file write `fh' `""`spec'";"spill";"`outcome'";"' `"`lbl'"' `";"n_estab";"' %12.0fc (`n_estab') `"""' _n
		file write `fh' `""`spec'";"spill";"`outcome'";"' `"`lbl'"' `";"pre_pval";"' %9.4f (`pre_ftest_pval') `"""' _n
		file write `fh' `""`spec'";"spill";"`outcome'";"' `"`lbl'"' `";"mean_pre";"' %9.4f (`mean_pre') `"""' _n
		file close `fh'
	}

	di as result "Section 11 Exercise `exercise' (restricted) complete."
}

di as result "Section 11 complete."

log close
shell source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "subgroup_analysis done" "subgroup_analysis.do finished"
