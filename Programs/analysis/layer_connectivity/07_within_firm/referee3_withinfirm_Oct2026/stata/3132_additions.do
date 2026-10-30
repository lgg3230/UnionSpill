********************************************************************************
* 3132_additions.do -- the four blocks to paste into
*   Programs/analysis/layer_connectivity/07_within_firm/3132_within_firm_hourly.do
* to add the "Test: = Firm-level (p-value)" row of Table A7.
*
* NOT a standalone do-file. Copy a7_stacktest.do into the same folder as 3132,
* then paste each block at the place indicated. Nothing else in 3132 changes,
* and no existing output changes: the blocks only add a new CSV,
*   $tables/a7_tests_hw`table_suffix'.csv
* with one row per partition x column (within/overall) x outcome (wage/emp):
*   partition kind outcome b_firm b_group diff se_diff p n_firm n_group clusters
* b_group equals the A7 coefficient, b_firm the column (1)/(4) coefficient, and
* p is the p-value printed in brackets in the table.
********************************************************************************


*-------------------------------------------------------------------------------
* BLOCK 1 -- after the helper programs, just before "SECTION 1: BUILD FIRM-LEVEL
*            PANEL"
*-------------------------------------------------------------------------------
do "$programs/a7_stacktest.do"


*-------------------------------------------------------------------------------
* BLOCK 2 -- in SECTION 2 (OPEN POSTFILES), after the existing postfile lines
*-------------------------------------------------------------------------------
tempname A7T
tempfile A7Tdta
postfile `A7T' str10 partition str8 kind str6 outcome ///
    double(b_firm b_group diff se_diff p) long(n_firm n_group clusters) ///
    using "`A7Tdta'", replace


*-------------------------------------------------------------------------------
* BLOCK 3 -- inside the partition loop, at the end of 4c (after the A7
*            within/overall loop, just before "4d. Build firm-level group
*            connectivity constants")
*-------------------------------------------------------------------------------
    foreach kind in within overall {
        foreach oc in wage emp {
            _stacktest_a7 "`FIRM'" "`GP'" `kind' `oc'
            post `A7T' ("`p'") ("`kind'") ("`oc'") (r(b_firm)) (r(b_group)) ///
                (r(diff)) (r(se_diff)) (r(p)) (r(n_firm)) (r(n_group)) (r(G))
        }
    }


*-------------------------------------------------------------------------------
* BLOCK 4 -- in SECTION 5, after the existing postclose/export lines
*-------------------------------------------------------------------------------
postclose `A7T'
use `A7Tdta', clear
export delimited using "$tables/a7_tests_hw`table_suffix'.csv", replace
