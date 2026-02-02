********************************************************************************
* PROJECT: UNION SPILLOVERS
* PROGRAM: BINSCATTER - GEOGRAPHIC PROXIMITY (LOG DISTANCE)
* PURPOSE: Create binscatter of bilateral connectivity vs -log(geographic distance)
* OUTPUT: binscatter_conn_geo_log_proximity.pdf
********************************************************************************
clear all
set more off
* Set paths
global main "/kellogg/proj/lgg3230"
global rais_aux "$main/UnionSpill/Data/RAIS_aux"
global graphs "$main/UnionSpill/Graphs"
********************************************************************************
* Load bilateral pairs data from CSV
********************************************************************************
import delimited "$rais_aux/bilateral_pairs_descriptives.csv", clear stringcols(1 2)
********************************************************************************
* Create log-distance based geographic proximity
********************************************************************************
* geo_distance is in km (from Haversine formula)
* Replace zero distances with small value to avoid log(0)
gen geo_distance_adj = geo_distance
replace geo_distance_adj = 0.1 if geo_distance == 0 & !missing(geo_distance)
* Create proximity measure: -log(distance)
* Higher values = closer geographically
gen geo_log_proximity = -ln(geo_distance_adj)
* Label variable
label variable geo_log_proximity "Geographic Proximity (-log km)"
********************************************************************************
* Residualize bilateral connectivity (firm i fixed effects)
********************************************************************************
* Use reghdfe to partial out firm i fixed effects
qui reghdfe bilateral_conn_pw, absorb(identificad_i) resid(bilateral_conn_resid)
********************************************************************************
* Generate binscatter (all pairs, including zeros)
********************************************************************************
binscatter bilateral_conn_resid geo_log_proximity, nquantiles(20) ///
    xtitle("Geographic Proximity (-log km)") ///
    ytitle("Bilateral Connectivity (residualized)") ///
    mcolor(navy) lcolor(navy) ///
    plotregion(color(white)) graphregion(color(white))
graph export "$graphs/binscatter_conn_geo_log_proximity.pdf", replace
di _newline "Graph exported to: $graphs/binscatter_conn_geo_log_proximity.pdf"
********************************************************************************
* Summary statistics
********************************************************************************
di _newline "=== Summary Statistics ==="
summarize geo_distance geo_log_proximity bilateral_conn_pw bilateral_conn_resid, detail
