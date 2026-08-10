********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: MASTER DO FILE
********************************************************************************

// PRELIMINAIRES

set more off
set varabbrev off
clear all
macro drop _all
version 17.0

// DIRECTORIES

// Main:

global klc "/kellogg/proj/lgg3230"
global luis "/Users/luisg/Library/CloudStorage/OneDrive-NorthwesternUniversity/4 - PhD/02_Research/Org_Econ BR/UnionSpillovers/Replication_Mar 2"

if "`c(username)'"=="luisg"{
	global main "$luis"
}

if "`c(username)'"=="lgg3230"{
	global main "$klc"
}

// Subfolders:


global rais_raw_dir "$main/RAIS/output/data/full"
global emp_assoc "$main/UnionSpill/Data/stata_emp_assoc"
global rais_emp_merge "$main/UnionSpill/Data/RAIS_emp_merge"
global cba_dir "$main/UnionSpill/Data/CBA"
global cba_rais_fir "$main/UnionSpill/Data/CBA_RAIS/cba_rais_firm"
global cba_rais_mun "$main/UnionSpill/Data/CBA_RAIS/cba_rais_muni"
global cba_rais_sta "$main/UnionSpill/Data/CBA_RAIS/cba_rais_stat"
global cba_rais_nac "$main/UnionSpill/Data/CBA_RAIS/cba_rais_nati"
global cba_rais_tot "$main/UnionSpill/Data/CBA_RAIS/cba_rais_total"
global rais_aux "$main/UnionSpill/Data/RAIS_aux"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"

global programs "$main/UnionSpill/Programs"
global tables "$main/UnionSpill/Tables"
global graphs "$main/UnionSpill/Graphs"

// CONTROL WHICH PROGRAMS RUN

local 011_rais_to_firm   = 0
local 02_clean_emp_assoc = 0
local 031_clean_cba      = 0
local 041_merge_cba_rais = 0
local 05_flows           = 0
local 07_flow_sample     = 0
local 08_direct_effects  = 0 

// RUN PROGRAMS

// Clean rais dataset, mergen with emploer association and collapse to firm level:

if (`011_rais_to_firm'  ==1) do "$programs/011_rais_to_firm.do";
if (`02_clean_emp_assoc'==1) do "$programs/02_clean_emp_assoc.do";
if (`031_clean_cba'     ==1) do "$programs/031_clean_cba.do";
if (`041_merge_cba_rais'==1) do "$programs/041_merge_cba_rais.do";




