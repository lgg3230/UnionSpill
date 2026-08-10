********************************************************************************
* _test_honestdid.do  --  smoke test that patched honestdid runs on ECOS only
********************************************************************************
version 17.0
set more off
adopath ++ "/gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/honest_did/ado"
which honestdid

* Synthetic event study: 2 pre-periods, 5 post-periods (reference omitted).
* betahat ordered chronologically: [t-2, t-1, t+1, t+2, t+3, t+4, t+5]
matrix b = (0.01, -0.02, 0.08, 0.10, 0.12, 0.11, 0.13)
matrix list b

* A simple positive-definite covariance (diagonal-ish) for 7 coefs.
matrix V = I(7) * 0.0016
forvalues i = 1/7 {
    forvalues j = 1/7 {
        if `i' != `j' matrix V[`i',`j'] = 0.0004
    }
}
matrix list V

di as result "=== Relative magnitudes (delta=rm, method C-LF) ==="
honestdid, b(b) vcov(V) numpre(2) delta(rm) mvec(0(0.5)2) method(C-LF)
matrix list r(Results)

di as result "=== Smoothness (delta=sd, method C-LF to avoid OSQP/FLCI) ==="
honestdid, b(b) vcov(V) numpre(2) delta(sd) mvec(0(0.01)0.05) method(C-LF)
matrix list r(Results)

di as result "=== TEST OK ==="
