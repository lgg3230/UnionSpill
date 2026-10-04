from pathlib import Path
import pandas as pd,pyreadstat,json
R=Path(__file__).resolve().parents[3];O=Path(__file__).resolve().parent;X=R/'Data/sample_gap_investigation/semantics_recovery';B=R/'archive/Data/baseline_2026-09-06'
l,_=pyreadstat.read_dta(str(B/'lagos_sample_sep24_LEGACY_Oct2025.dta'),usecols=['identificad','municipio']);l=l.drop_duplicates('identificad').rename(columns={'municipio':'published_municipio'});l['published_municipio']=pd.to_numeric(l.published_municipio)
a=[]
for y in [2007,2008]:
 d,_=pyreadstat.read_dta(str(X/f'worker_municipality_modes_{y}.dta'));d['year']=y;a.append(d)
e=pd.concat(a).sort_values('year').drop_duplicates('identificad');m=l.merge(e,on='identificad',validate='one_to_one');m['agrees']=m.published_municipio.eq(m.selected_mode)
ids=set(pd.read_csv(O.parent/'discrepant_ids.csv',dtype=str).identificad);m['discrepant']=m.identificad.isin(ids);m.to_csv(O/'early_modes_vs_published.csv',index=False)
print(m.groupby(['discrepant','agrees']).size().to_string());print(m[m.discrepant].to_string(index=False))
# 2007 support for the 46 published root peers rejected by first-annual-value test.
p=pd.read_csv(O.parent/'root_peer_first_municipality_check.csv',dtype={'identificad':str});bad=set(p.loc[~p.first_equals_published,'identificad']);c,_=pyreadstat.read_dta(str(X/'worker_municipality_counts_2007.dta'));c=c[c.identificad.isin(bad)];c=c.merge(l,on='identificad');c['equals_published']=c.municipio.eq(c.published_municipio);c.to_csv(O/'rejected_first_year_peer_worker_support.csv',index=False);print('46 peers: any 2007 worker supports published key',c[c.equals_published].identificad.nunique())
