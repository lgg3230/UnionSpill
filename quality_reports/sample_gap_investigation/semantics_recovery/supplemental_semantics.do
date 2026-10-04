clear all
set more off
version 17.0
input float x str6 s
. ""
.a "."
0 "0"
2 "2"
12 "12"
end
assert .>12 & .a>. & missing(.a)
assert ""<"0" & "12"<"2"
assert missing("") & !missing(".")
assert (x>1)==1 if missing(x)
gen end_date=.
gen file_date=mdy(7,1,2013)
gen byte post=(file_date>=mdy(1,1,2012) & end_date>=mdy(12,31,2012) & !missing(file_date))
assert post==1
replace file_date=.
replace post=(file_date>=mdy(1,1,2012) & end_date>=mdy(12,31,2012) & !missing(file_date))
assert post==0
sort x
assert x==0 if _n==1
sort s
assert s=="" if _n==1
export delimited using "supplemental_semantics.csv",replace
display "SUPPLEMENTAL SEMANTICS COMPLETE"
