from pathlib import Path
import pandas as pd,pyreadstat
R=Path(__file__).resolve().parents[2];O=R/'quality_reports/sample_gap_investigation';X=R/'Data/sample_gap_investigation'
l,_=pyreadstat.read_dta(str(R/'archive/Data/baseline_2026-09-06/lagos_sample_sep24_LEGACY_Oct2025.dta'),usecols=['identificad','municipio','year']);assert l.groupby('identificad').municipio.nunique().max()==1
l=l.drop_duplicates('identificad').set_index('identificad').municipio
hist=[]
for n in ['rais_aux','rais_firm','CBA']:(X/'published_municipio'/n).mkdir(parents=True,exist_ok=True)
for y in range(2007,2017):
 p=X/f'published_municipio/rais_firm/rais_firm_{y}.dta'
 if not p.exists():p.symlink_to(X/f'modal/rais_firm/rais_firm_{y}.dta')
 a,_=pyreadstat.read_dta(str(X/f'modal/rais_firm/rais_firm_{y}.dta'),usecols=['identificad','municipio']);a['year']=y;hist.append(a)
 if y>=2009:
  d,_=pyreadstat.read_dta(str(X/f'modal/rais_aux/unique_firms_{y}.dta'));d['municipio']=d.identificad.map(l).fillna(d.municipio);d['state']=d.municipio.str[:2];pyreadstat.write_dta(d,str(X/f'published_municipio/rais_aux/unique_firms_{y}.dta'),version=15)
for name in ['cba_firm_exploded.dta','cba_coverage_clean.dta']:
 p=X/f'published_municipio/CBA/{name}'
 if not p.exists():p.symlink_to((X/f'modal/CBA/{name}').resolve())
s=(O/'run_modal_cases.do').read_text().replace(f'{X}/modal/',f'{X}/published_municipio/');(O/'run_published_cases.do').write_text(s)
a=pd.concat(hist).sort_values('year').drop_duplicates('identificad').set_index('identificad');a['published_municipio']=a.index.map(l);a=a[a.published_municipio.notna()];a['first_equals_published']=a.municipio.eq(a.published_municipio);a.to_csv(O/'root_peer_first_municipality_check.csv');print('published root peers',len(a),'first agrees',a.first_equals_published.sum());print(a[~a.first_equals_published].head(10).to_string())
