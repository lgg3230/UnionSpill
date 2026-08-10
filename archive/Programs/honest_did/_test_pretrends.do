version 17.0
set more off
matrix b = (0.01, -0.02, 0.08, 0.10, 0.12, 0.11, 0.13)
matrix V = I(7)*0.0016
forvalues i=1/7 {
 forvalues j=1/7 {
  if `i'!=`j' matrix V[`i',`j']=0.0004
 }
}
di as result "=== power(0.5) ==="
pretrends, b(b) vcov(V) numpre(2) power(0.5) nocoefplot
di "r(slope) = " r(slope)
di "r(Power) = " r(Power)
local obj `r(PreTrendsResults)'
di "obj = `obj'"
tempname ES
mata: st_matrix("`ES'", `obj'.ES)
matrix list `ES'

di as result "=== power(0.8) ==="
pretrends, b(b) vcov(V) numpre(2) power(0.8) nocoefplot
di "r(slope80) = " r(slope)
di as result "=== DONE ==="
