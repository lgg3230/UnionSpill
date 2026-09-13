********************************************************************************
* RESTORED TO THE CHAIN 2026-09-06 (defect A13)
*
* Commit 074cb45 moved this script to archive/ on the finding that nothing
* consumed its output. That finding was wrong: it writes unique_firms_{y}.dta,
* which 1020_clean_cba.do:158,163,168 joins against, so CBA cleaning could not
* run at all from scratch. 074cb45's own message flags this as a known regression.
*
* NUMBERED 1011, NOT 1020. The master's invariant is that numbering is dependency
* order -- no script reads a file written by a higher-numbered script. This reads
* unique_estab_{y}.dta from 1010 and is read by 1020, so it must sort between
* them. Renumbering 1020-1050 to open a slot would rename 65 files and rewrite
* references in 76, which is not a change worth making immediately before a
* multi-day production run. 1011 follows the existing helper convention
* (1021/1022 under 1020, 1041-1045 under 1040) and satisfies the invariant.
*
* INPUT : $emp_assoc/SIC 38970 - {2010-2011,2012-2013,2014-2015,2016-2018}.txt
*         $rais_aux/unique_estab_{2009..2016}.dta   (1010, BRANCH 3)
* OUTPUT: $emp_assoc/emp_assoc_{2009..2018}.dta
*         $rais_aux/unique_firms_{2009..2016}.dta   (consumed by 1020)
********************************************************************************

********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: CLEAN EMPLOYER ASSOCIATION-ESTABLISHMENT CROSSWALK
* INPUT: TXT FILES FROM buscalai https://buscalai.cgu.gov.br/PedidosLai/DetalhePedido?id=2294721
* OUTPUT: YEARLY DTA DATASETS WITH FIRMS AND THEIR EMPLOYER ASSOCIATION ID

// ONLY KEEPS ASSOC COUNT==1. THIS REMOVE .05% OF FIRMS PER YEARL
// MEANS WE ARE ASSUMING THE FIRMS WITH ASSOC COUNT>1 ARE NOT COVERED BY AN EMP ASSOC
// THIS UNDERESTIMATES EMP ASSOC COVERAGE.

// SOLUTIONS: 1)FOR THESE ESTABS, CHOOSE MODAL EMP ASSOC ACROSS YEARS  
// 	      2) KEEP OBS WHERE THE SAME ESTAB NEGOTIATES WITH MORE THAN ONE EMP ASSOC
//		MERGE WITH CBA DATASET USING EMP ASSOC (SO WE HAVE THE SAME ESTAB MATCHED TO MANY CBA THROUGH MANY EMP ASSOCS)
//		PROCEED AS BEFORE, CHOOSING THE MODAL WORKER UNION PER ESTAB
********************************************************************************


import delimited using "$emp_assoc/SIC 38970 - 2010-2011.txt", delimiter(";") clear // imports employer association-establishment crosswalk

generate identificad = ustrregexra(cnpjcei,"[\.\/\-]","") // removes dots, slashes and dashes from estab id, replaces with nothing
generate clean_asso_cnpj = ustrregexra(cnpjcontrsindical,"[\.\/\-]","") // does the same to emp association id


label variable clean_asso_cnpj `"employer association identifier, no dots nor dashes"'
label variable identificad `"firm identifier, no dots nor dashes"'

preserve // they have an yearly crosswalk, so in order to separate data, we need to preserve it

keep if ano==2010 

duplicates drop identificad clean_asso_cnpj, force // drop duplicates in terms of estab id and employer association id

egen assoc_count = count(clean_asso_cnpj), by(identificad) // counts the number of employer association per estab id

keep if assoc_count==1 // only keep estabs that have a single employer association. 

keep identificad clean_asso_cnpj // only keep data we will be using

save "$emp_assoc/emp_assoc_2010.dta", replace // we only have 2010 onwards, so use 2010 for 2009
save "$emp_assoc/emp_assoc_2009.dta", replace

restore

// procedure is the same for the remaining datasets:

preserve

keep if ano==2011
duplicates drop identificad clean_asso_cnpj, force

egen assoc_count = count(clean_asso_cnpj), by(identificad)

keep if assoc_count==1
keep identificad clean_asso_cnpj

save "$emp_assoc/emp_assoc_2011.dta", replace

restore

/* Process the 2012-2013 file */
import delimited using "$emp_assoc/SIC 38970 - 2012-2013.txt", delimiter(";") clear

generate identificad = ustrregexra(cnpjcei,"[\.\/\-]","")
generate clean_asso_cnpj = ustrregexra(cnpjcontrsindical,"[\.\/\-]","")

label variable clean_asso_cnpj `"employer association identifier, no dots nor dashes"'
label variable identificad `"firm identifier, no dots nor dashes"'

preserve
keep if ano==2012
duplicates drop identificad clean_asso_cnpj, force

egen assoc_count = count(clean_asso_cnpj), by(identificad)

keep if assoc_count==1
keep identificad clean_asso_cnpj
save "$emp_assoc/emp_assoc_2012.dta", replace
restore

preserve
keep if ano==2013
duplicates drop identificad clean_asso_cnpj, force

egen assoc_count = count(clean_asso_cnpj), by(identificad)

keep if assoc_count==1
keep identificad clean_asso_cnpj
save "$emp_assoc/emp_assoc_2013.dta", replace
restore

/* Process the 2014-2015 file */
import delimited using "$emp_assoc/SIC 38970 - 2014-2015.txt", delimiter(";") clear

generate identificad = ustrregexra(cnpjcei,"[\.\/\-]","")
generate clean_asso_cnpj = ustrregexra(cnpjcontrsindical,"[\.\/\-]","")

label variable clean_asso_cnpj `"employer association identifier, no dots nor dashes"'
label variable identificad `"firm identifier, no dots nor dashes"'

preserve
keep if ano==2014
duplicates drop identificad clean_asso_cnpj, force

egen assoc_count = count(clean_asso_cnpj), by(identificad)

keep if assoc_count==1
keep identificad clean_asso_cnpj
save "$emp_assoc/emp_assoc_2014.dta", replace
restore

preserve
keep if ano==2015
duplicates drop identificad clean_asso_cnpj, force

egen assoc_count = count(clean_asso_cnpj), by(identificad)

keep if assoc_count==1
keep identificad clean_asso_cnpj
save "$emp_assoc/emp_assoc_2015.dta", replace
restore

/* Process the 2016-2018 file */
import delimited using "$emp_assoc/SIC 38970 - 2016-2018.txt", delimiter(";") clear

generate identificad = ustrregexra(cnpjcei,"[\.\/\-]","")
generate clean_asso_cnpj = ustrregexra(cnpjcontrsindical,"[\.\/\-]","")

label variable clean_asso_cnpj `"employer association identifier, no dots nor dashes"'
label variable identificad `"firm identifier, no dots nor dashes"'

preserve
keep if ano==2016
duplicates drop identificad clean_asso_cnpj, force

egen assoc_count = count(clean_asso_cnpj), by(identificad)

keep if assoc_count==1
keep identificad clean_asso_cnpj
save "$emp_assoc/emp_assoc_2016.dta", replace
restore

preserve
keep if ano==2017
duplicates drop identificad clean_asso_cnpj, force

egen assoc_count = count(clean_asso_cnpj), by(identificad)

keep if assoc_count==1
keep identificad clean_asso_cnpj
save "$emp_assoc/emp_assoc_2017.dta", replace
restore

preserve
keep if ano==2018
duplicates drop identificad clean_asso_cnpj, force

egen assoc_count = count(clean_asso_cnpj), by(identificad)

keep if assoc_count==1
keep identificad clean_asso_cnpj
save "$emp_assoc/emp_assoc_2018.dta", replace
restore

// merges the emp assoc id to the estab id to the collapsed rais datasets
forvalues i=2009/2016{
	use "$rais_aux/unique_estab_`i'.dta", clear
	merge 1:1 identificad using "$emp_assoc/emp_assoc_`i'.dta"
	drop _merge
	save "$rais_aux/unique_firms_`i'.dta", replace
}


