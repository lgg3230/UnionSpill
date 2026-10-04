from pathlib import Path
R=Path(__file__).resolve().parents[3]
W=R/'Data/sample_gap_investigation/wide_2007_2016'
for name in ['rais_aux','rais_firm','CBA','CBA_verified']:(W/name).mkdir(parents=True,exist_ok=True)
(R/'Data/sample_gap_investigation/semantics_recovery').mkdir(parents=True,exist_ok=True)
for name in ['cba_firm_exploded.dta','cba_coverage_clean.dta']:
 p=W/'CBA'/name; source=R/'Data/CBA'/name
 if not p.exists():p.symlink_to(source)
 assert p.is_symlink() and p.resolve()==source.resolve()

for name in ["cba_firm_exploded.dta","cba_coverage_clean.dta"]:
 p=W/"CBA_verified"/name;source=R/"Data/CBA"/name
 if not p.exists():p.symlink_to(source)
 assert p.is_symlink() and p.resolve()==source.resolve()
