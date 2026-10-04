from pathlib import Path
import pandas as pd,pyreadstat,duckdb,json
R=Path(__file__).resolve().parents[3];O=Path(__file__).resolve().parent;X=R/'Data/sample_gap_investigation';c=duckdb.connect();c.execute('PRAGMA threads=4')
l,_=pyreadstat.read_dta(str(R/'archive/Data/baseline_2026-09-06/lagos_sample_sep24_LEGACY_Oct2025.dta'),usecols=['identificad','municipio']);l=l.drop_duplicates('identificad').rename(columns={'municipio':'published_municipio'});l.published_municipio=pd.to_numeric(l.published_municipio)
# Diagnostic only: observed baseline worker records plus upstream early-year selected workers.
a=c.execute('select identificad,municipio,count(*) workers from read_parquet(?) group by identificad,municipio',[str(R/'archive/Data/baseline_2026-09-06/worker_panel_lagos_BASELINE.parquet')]).df();ids=set(a.identificad);chunks=[a]
for y in [2007,2008]:
 d,_=pyreadstat.read_dta(str(X/f'semantics_recovery/worker_municipality_counts_{y}.dta'),usecols=['identificad','municipio','workers']);chunks.append(d[d.identificad.isin(ids)])
a=pd.concat(chunks).groupby(['identificad','municipio'],as_index=False).workers.sum();a=a.sort_values(['identificad','workers','municipio'],ascending=[True,False,True]);a=a.drop_duplicates('identificad').rename(columns={'municipio':'wide_worker_mode'});a=a.merge(l,on='identificad');a['agrees']=a.wide_worker_mode.eq(a.published_municipio);a.to_csv(O/'wide_worker_mode_vs_published.csv',index=False)
print('baseline wide worker mode agreement',a.agrees.value_counts().to_dict(),flush=True)
# Cheap approximation for all root peers, explicitly not worker-exact where within-year municipality varies.
chunks=[]
for y in range(2007,2017):
 d,_=pyreadstat.read_dta(str(X/f'modal/rais_firm/rais_firm_{y}.dta'),usecols=['identificad','municipio','firm_emp']);chunks.append(d)
a=pd.concat(chunks);a.municipio=pd.to_numeric(a.municipio);a=a.groupby(['identificad','municipio'],as_index=False).firm_emp.sum().sort_values(['identificad','firm_emp','municipio'],ascending=[True,False,True]).drop_duplicates('identificad');a=a.merge(l,on='identificad');a['agrees']=a.municipio.eq(a.published_municipio);a.to_csv(O/'wide_annual_weighted_proxy_vs_published.csv',index=False);print('root peer wide annual weighted proxy agreement',a.agrees.value_counts().to_dict(),flush=True)
