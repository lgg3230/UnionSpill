clear all
set more off
version 17.0
use identificad PIS municipio horascontr remdezr remmedr tempempr empem3112 dtadmissao tpvinculo ocup2002 causadesli mesdesli clascnae20 if inlist(substr(identificad,1,8),"00233342","00297598","01029312","02869763","02917443","02948030","03380763","03422881") | inlist(substr(identificad,1,8),"03768023","04060243","04270071","04616941","04819724","04861051","04867587","05508838") | inlist(substr(identificad,1,8),"07760479","07831987","08370059","09140351","10249238","19531052","29167442","30259220") | inlist(substr(identificad,1,8),"31895683","44215952","45024551","52502945","55450456","57612731","60444437","60620366") | inlist(substr(identificad,1,8),"60701190","60723061","61079232","61486650","62324132","65206526","66970229","68283175") | inlist(substr(identificad,1,8),"72537616","97191902") using "/kellogg/proj/lgg3230/RAIS/output/data/full/RAIS_2009.dta",clear
save "/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/sample_gap_investigation/semantics_recovery/raw_spells_2009.dta",replace
display "RAW SPELL EXTRACT COMPLETE"
