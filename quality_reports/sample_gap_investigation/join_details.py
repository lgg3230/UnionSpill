from pathlib import Path
import pandas as pd,pyreadstat
R=Path(__file__).resolve().parents[2];O=R/'quality_reports/sample_gap_investigation';X=R/'Data/sample_gap_investigation';rec=pd.read_csv(O/'reconciliation.csv',dtype=str);ids=set(rec.identificad)
c=pd.read_csv(O/'rebuilt_exploded_root_records.csv',dtype=str,keep_default_na=False)
c['municipio_coverage']=c.codigo_municipio.str.strip().str[:6];c['state_coverage']=c.codigo_municipio.str.strip().str[:2];c['start_year']=c.start_year.astype(float).astype(int)
c=c[c.start_year.between(2009,2016)&c.codigo_municipio.str.strip().ne('')].drop_duplicates()
t=[]
for y in range(2009,2017):
 d,_=pyreadstat.read_dta(str(X/f'modal/rais_aux/unique_firms_{y}.dta'));d=d[d.identificad.isin(ids)];d=d.rename(columns={'municipio':'modal_municipio','state':'modal_state'});d['start_year']=y
 a,_=pyreadstat.read_dta(str(X/f'raw/rais_aux/unique_firms_{y}.dta'),usecols=['identificad','municipio','state']);a=a.rename(columns={'municipio':'raw_municipio','state':'raw_state'});d=d.merge(a,on='identificad',validate='one_to_one');t.append(d)
a=pd.concat(t).merge(c,on=['identificad_8','start_year'],validate='many_to_many');a['coverage_level']='municipality';a.loc[a.municipio_coverage.str.len()==2,'coverage_level']='state';a.loc[a.municipio_coverage=='000000','coverage_level']='national'
for v in ['modal','raw']:
 a[v+'_join_matches']=((a.coverage_level=='municipality')&a.municipio_coverage.eq(a[v+'_municipio']))|((a.coverage_level=='state')&a.state_coverage.eq(a[v+'_state']))|(a.coverage_level=='national')
cols=['pair_id','contract_id','union_id','file_date_stata','start_date_stata','end_date_stata'];s,_=pyreadstat.read_dta(str(R/'Data/CBA/cba_coverage_clean.dta'),usecols=cols,disable_datetime_conversion=True)
a=a.merge(s,on=['pair_id','contract_id'],how='left',validate='many_to_one');a['source_status']='controlled_join_diagnostic; historical_assignment_unavailable';a.to_csv(O/'cba_join_outcomes.csv',index=False)
print('candidate rows',len(a),'modal matched',a.modal_join_matches.sum(),'raw matched',a.raw_join_matches.sum())
# Compact human-readable chronology for the priority case, retaining explicit sources.
frames=[]
for name in ['legacy','modal','raw_control']:
 d=pd.read_csv(O/f'{name}_case_panel.csv',dtype={'identificad':str,'union_id':str});d=d[d.identificad=='01029312000190'].copy();d['source_status']=name
 for col in ['avg_file_date','end_date_stata']:
  d[col+'_iso']=pd.to_datetime(d[col],unit='D',origin='1960-01-01').dt.strftime('%Y-%m-%d')
 frames.append(d[['identificad','year','source_status','union_id','avg_file_date_iso','end_date_stata_iso','cba_pre2012_avg','cba_post2012_avg']])
pd.concat(frames).sort_values(['source_status','year']).to_csv(O/'priority_case_chronology.csv',index=False)
