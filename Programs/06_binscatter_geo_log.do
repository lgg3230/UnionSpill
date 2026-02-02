********************************************************************************
* PROJECT: UNION SPILLOVERS
* AUTHOR: LUIS GOMES
* PROGRAM: GEOGRAPHIC PROXIMITY BINSCATTER (LOG DISTANCE)
* OUTPUT: binscatter_conn_geo_proximity_log.pdf
********************************************************************************

* Load bilateral pairs data (assumes already merged with coordinates)
use "$rais_aux/bilateral_pairs_merged.dta", clear

* Compute geographic proximity as -log(distance)
* Add small constant to avoid log(0) for same-municipality pairs
gen geo_proximity_log = -log(geo_distance + 1)
label var geo_proximity_log "Geographic proximity (-log(km + 1))"

* Standardize variables
qui sum bilateral_conn_pw
gen z_bilateral_conn_pw = (bilateral_conn_pw - r(mean)) / r(sd)

qui sum geo_proximity_log
gen z_geo_proximity_log = (geo_proximity_log - r(mean)) / r(sd)

* Residualize bilateral connectivity (firm i FE)
qui reghdfe bilateral_conn_pw, absorb(identificad_i) resid(bilateral_conn_resid)

* Run individual regression with firm i FE for slope coefficient
qui reghdfe z_bilateral_conn_pw z_geo_proximity_log, absorb(identificad_i) vce(robust)
local coef = _b[z_geo_proximity_log]
local se = _se[z_geo_proximity_log]

* Display results
di "Coefficient: " %7.4f `coef'
di "Std. Error:  " %7.4f `se'

* Set scheme
set scheme s2color

* Create binscatter with coefficient annotation
binscatter bilateral_conn_resid geo_proximity_log, nquantiles(20) ///
    xtitle("Geographic Proximity (-log(km + 1))") ///
    ytitle("Bilateral Connectivity (residualized)") ///
    mcolor(navy) lcolor(navy) ///
    plotregion(color(white)) graphregion(color(white)) ///
    note("{it:β} = `: di %7.4f `coef'' (`: di %7.4f `se'')", size(small))

graph export "$graphs/binscatter_conn_geo_proximity_log.pdf", replace
di "Saved: $graphs/binscatter_conn_geo_proximity_log.pdf"
