version 17.0
set more off
adopath ++ "/gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/honest_did/ado"

matrix b = (0.01, -0.02, 0.08, 0.10, 0.12, 0.11, 0.13)
matrix V = I(7) * 0.0016
forvalues i = 1/7 {
    forvalues j = 1/7 {
        if `i' != `j' matrix V[`i',`j'] = 0.0004
    }
}

di as result "=== RM, extract CI via mata ==="
honestdid, b(b) vcov(V) numpre(2) delta(rm) mvec(0(0.25)2) method(C-LF)
local obj `s(HonestEventStudy)'
di "obj name = `obj'"
tempname CI
mata: st_matrix("`CI'", `obj'.CI)
matrix list `CI'

di as result "=== SD, C-LF, adaptive grid ==="
honestdid, b(b) vcov(V) numpre(2) delta(sd) mvec(0(0.008)0.16) method(C-LF)
local obj `s(HonestEventStudy)'
tempname CI2
mata: st_matrix("`CI2'", `obj'.CI)
matrix list `CI2'

di as result "=== 1 pre-period (numpre=1) RM feasibility check ==="
matrix b2 = (-0.02, 0.08, 0.10, 0.12, 0.11)
matrix V2 = I(5)*0.0016
forvalues i=1/5 {
 forvalues j=1/5 {
  if `i'!=`j' matrix V2[`i',`j']=0.0004
 }
}
capture noisily honestdid, b(b2) vcov(V2) numpre(1) delta(rm) mvec(0(0.25)2) method(C-LF)
di "RM numpre=1 rc = " _rc
capture noisily honestdid, b(b2) vcov(V2) numpre(1) delta(sd) mvec(0(0.008)0.16) method(C-LF)
di "SD numpre=1 rc = " _rc

di as result "=== TEST DONE ==="
