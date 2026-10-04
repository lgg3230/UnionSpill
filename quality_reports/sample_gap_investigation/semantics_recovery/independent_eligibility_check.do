clear all
set more off
version 17.0
local W "/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/sample_gap_investigation/wide_2007_2016"
* Independent eligibility check after ALL root/union operations. For balanced
* establishments every RAIS year exists and is positive, as asserted below.
* RAIS-only rows have missing filing dates and contribute zero to every date
* restriction; omitting them cannot alter these within-establishment flags.
forvalues y=2009/2016 {
 use firm_emp using "`W'/rais_firm/rais_firm_`y'.dta",clear
 assert firm_emp>0 & !missing(firm_emp)
}
use identificad active_year avg_file_date end_date_stata using "`W'/CBA_verified/collapsed_cba_firm_updated.dta",clear
keep if inrange(active_year,2009,2016) & identificad!=""
isid identificad active_year
merge m:1 identificad using "`W'/rais_aux/bal_pan.dta"
keep if _merge==3 & in_balanced_panel==1
drop _merge
gen pos_emp=1
foreach filedate in avg {
    
    // 1a. Indicator for having a CBA in 2009 using current file_date definition
    bysort identificad: egen cba2009_`filedate' = max(inrange(`filedate'_file_date, mdy(1,1,2009), mdy(12,31,2009)))

    // 1b. Count the number of CBAs negotiated before 2012 using current file_date definition
    // mark cba's negotiated in 2009:
    bys identificad: gen filled2009_`filedate' = inrange(`filedate'_file_date, mdy(1,1,2009), mdy(12,31,2009))

    // get the earliest file date within those filed in 2009:
    bys identificad: egen first_2009_cba_`filedate' = min(`filedate'_file_date) if filled2009_`filedate'==1
    format first_2009_cba_`filedate' %td

    // just expand to all years of the same establishment to compare each row's filing date individually
    bys identificad: egen earliest2009_`filedate' = min(first_2009_cba_`filedate')
    // add 1 to avoid counting earliest 2009 cba again
    replace earliest2009_`filedate' = earliest2009_`filedate'+1
    format earliest2009_`filedate' %td
    drop first_2009_cba_`filedate'

    // marks rows where the file date is post the earliest 2009 cba filing date, but before 2012
    bys identificad: gen tag_post2009_pre2012_`filedate' = inrange(`filedate'_file_date,earliest2009_`filedate',mdy(1,1,2012))
    // counts how many filing dates after the first 2009 and before 2012 there are
    bys identificad: egen count_2009_2012_`filedate' = total(tag_post2009_pre2012_`filedate')

    // retrieves the filing dates of the cba's after the earliest 2009
    gen file_2009_2012_`filedate'=.
    replace file_2009_2012_`filedate'=`filedate'_file_date if tag_post2009_pre2012_`filedate'==1
    format file_2009_2012_`filedate' %td 

    // gets the second earliest cba negotiated within a establishment on the sample years.
    bys identificad: egen second_cba_`filedate' = min(file_2009_2012_`filedate')
    format second_cba_`filedate' %td 

    // Condition 1: Firm must have at least one CBA in 2009 AND at least another different one before 2012
    gen cba_pre2012_`filedate' = (cba2009_`filedate' == 1 & count_2009_2012_`filedate' >= 1)

    // 1c. Indicator for having a CBA in 2012 or later using current file_date definition
    bysort identificad: egen cba_post2012_`filedate' = max(`filedate'_file_date >= mdy(1,1,2012) & end_date_stata>= mdy(12,31,2012) & !missing(`filedate'_file_date))

    // Generate Lagos sample for this file date definition:
    gen lagos_sample_`filedate' = (cba_pre2012_`filedate' == 1 & cba_post2012_`filedate' == 1 & pos_emp == 1)
}




keep if lagos_sample_avg==1
keep identificad
bys identificad: keep if _n==1
export delimited using "independent_eligibility_ids.csv",replace
count
display "INDEPENDENT ELIGIBILITY CHECK COMPLETE"
