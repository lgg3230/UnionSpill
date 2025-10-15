**********************,**************************************************************************************************************
*Project: Union Spillovers )
*Program: Homogenizing RAIS variables for appending
*Author: Luis Gustavo Gomes
*Date: Nov 27, 2024

*Objective: Restrict each of the relevant RAIS datasets to the variables that are common among all so that the appending goes smoothly  

************************************************************************************************************************************
**SET ENVIRONMENT
************************************************************************************************************************************

clear all
clear matrix
set maxvar 20000
set more off

global rais_raw_dir "/kellogg/proj/lgg3230/RAIS/output/data/full"
global rais_hom_dir "/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_homog/"

************************************************************************************************************************************
**RAW DATA
************************************************************************************************************************************
 
 
foreach i in 2009 2010 2011 2012 2013 2014 2015 2016 2017{
	use "$rais_raw_dir/RAIS_`i'.dta"
	
	
	* Generate year variables
	
	gen year = `i'
	gen identificad_8 = substr(identificad,1,8)
	
	* Generate age variable for databases that do not have it
	
	
	cap confirm var idade
	if _rc{
		gen dob_date = date(dtnascimento,"DMY")
		format dob_date %td
		gen anonasc = year(dob_date)
		gen idade = year - anonasc
		drop anonasc dob_date
	*gen idade=.
	}
	
	* checkif variable dtnascimento exist. if not, create it
	
	cap confirm var dtnascimento
	if _rc{
		gen dtnascimento=.
	}
	
	keep year PIS CPF numectps nome identificad identificad_8 radiccnpj municipio tpvinculo empem3112 tipoadm dtadmissao causadesli mesdesli ocup2002 grinstrucao genero dtnascimento idade nacionalidad portdefic tpdefic raca_cor remdezembro remmedia remdezr remmedr tempempr tiposal salcontr ultrem horascontr clascnae20 sbclas20 tamestab natjuridica tipoestbl indceivinc ceivinc indalvara indpat indsimples qtdiasafas causafast1 causafast2 causafast3 diainiaf1 diainiaf2 diainiaf3 diafimaf1 diafimaf2 diafimaf3 mesiniaf1 mesiniaf2 mesiniaf3 mesfimaf1 mesfimaf2 mesfimaf3
	
	order year PIS CPF numectps nome identificad identificad_8 radiccnpj municipio tpvinculo empem3112 tipoadm dtadmissao causadesli mesdesli ocup2002 grinstrucao genero dtnascimento idade nacionalidad portdefic tpdefic raca_cor remdezembro remmedia remdezr remmedr tempempr tiposal salcontr ultrem horascontr clascnae20 sbclas20 tamestab natjuridica tipoestbl indceivinc ceivinc indalvara indpat indsimples qtdiasafas causafast1 causafast2 causafast3 diainiaf1 diainiaf2 diainiaf3 diafimaf1 diafimaf2 diafimaf3 mesiniaf1 mesiniaf2 mesiniaf3 mesfimaf1 mesfimaf2 mesfimaf3
	
	cd $rais_hom_dir
	save "RAIS_`i'_hom", replace
	
}
