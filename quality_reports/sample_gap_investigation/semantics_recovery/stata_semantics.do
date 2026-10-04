clear all
set more off
version 17.0
set seed 12345
set sortseed 54321
input str8 pair float(hours wage tenure active) str6 muni
"allmiss" . . . 1 ""
"allmiss" . . 2 1 "355030"
"negative" 40 -1 2 1 "355030"
"negative" 20 2 2 1 "353650"
"inactive" 44 2 2 0 "355030"
"inactive" 40 2 2 1 "353650"
"wmiss" 40 . 2 1 "355030"
"wmiss" 40 . 2 1 "353650"
"tied" 40 2 2 1 "355030"
"tied" 40 2 2 1 "353650"
end
gen byte empdec=active*(tenure>1)
bys pair: egen maxhours=max(hours)
gen byte rank1=(hours==maxhours & empdec==1)
bys pair: egen maxwage=max(wage*rank1)
gen byte rank2=(wage==maxwage & rank1==1)
gen random=runiform() if rank2==1
bys pair: egen maxrandom=max(random*rank2)
gen byte selected=(random==maxrandom & rank2==1)
list pair hours wage tenure empdec maxhours rank1 maxwage rank2 selected, sepby(pair) noobs
assert empdec==1 if pair=="allmiss"
assert selected==0 if pair=="negative" | pair=="inactive"
assert rank2==1 if pair=="wmiss"
export delimited using "semantics_spells.csv",replace
clear
input byte id float x str6 muni
1 . ""
1 7 "355030"
2 4 "353650"
2 9 "355030"
end
gen order=_n
sort id order
preserve
collapse (first) x muni,by(id)
list,noobs
export delimited using "semantics_first.csv",replace
restore
collapse (firstnm) x muni,by(id)
list,noobs
export delimited using "semantics_firstnm.csv",replace
clear
input byte id str6 municipio
1 "353650"
2 ""
3 "355030"
end
tempfile master usingdata
save `master'
clear
input byte id str6 municipio
1 "355030"
2 "353650"
4 "410180"
end
save `usingdata'
use `master',clear
merge 1:1 id using `usingdata'
list,noobs
assert municipio=="353650" if id==1
assert municipio=="" if id==2
export delimited using "semantics_merge_default.csv",replace
use `master',clear
merge 1:1 id using `usingdata',update
list,noobs
assert municipio=="353650" if id==1 | id==2
export delimited using "semantics_merge_update.csv",replace
clear
input byte id float muni
1 .
1 355030
2 353650
2 355030
end
bys id: egen default_mode=mode(muni)
bys id: egen min_mode=mode(muni),minmode
bys id: egen max_mode=mode(muni),maxmode
list,noobs
assert min_mode==355030 if id==1
assert missing(default_mode) if id==2
assert min_mode==353650 if id==2
export delimited using "semantics_modes.csv",replace
display "SEMANTICS COMPLETE"
