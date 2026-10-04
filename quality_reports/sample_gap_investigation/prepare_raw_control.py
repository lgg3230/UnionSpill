from pathlib import Path
import pyreadstat
R=Path(__file__).resolve().parents[2];O=R/'quality_reports/sample_gap_investigation';X=R/'Data/sample_gap_investigation'
for n in ['rais_aux','rais_firm','CBA']:(X/'raw'/n).mkdir(parents=True,exist_ok=True)
for y in range(2007,2017):
 p=X/f'raw/rais_firm/rais_firm_{y}.dta'
 if not p.exists():p.symlink_to(X/f'modal/rais_firm/rais_firm_{y}.dta')
 if y>=2009:
  d,_=pyreadstat.read_dta(str(X/f'modal/rais_aux/unique_firms_{y}.dta'))
  a,_=pyreadstat.read_dta(str(X/f'modal/rais_firm/rais_firm_{y}.dta'),usecols=['identificad','municipio'])
  d=d.drop(columns=['municipio','state']).merge(a,on='identificad',validate='one_to_one');d['state']=d.municipio.str[:2]
  pyreadstat.write_dta(d,str(X/f'raw/rais_aux/unique_firms_{y}.dta'),version=15)
for name in ['cba_firm_exploded.dta','cba_coverage_clean.dta']:
 p=X/f'raw/CBA/{name}'
 if not p.exists(): p.symlink_to((X/f'modal/CBA/{name}').resolve())
s=(O/'run_modal_cases.do').read_text().replace(f'{X}/modal/',f'{X}/raw/')
(O/'run_raw_cases.do').write_text(s)
