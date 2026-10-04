from pathlib import Path
import pandas as pd,pyreadstat,json,numpy as np
R=Path(__file__).resolve().parents[2];O=R/'quality_reports/sample_gap_investigation';X=R/'Data/sample_gap_investigation';ids=set(pd.read_csv(O/'discrepant_ids.csv',dtype=str).identificad)
B=set(pd.read_csv(O/'baseline_worker_keys.csv',dtype={'identificad':str}).identificad);M=set(pd.read_csv(R/'archive/Data/baseline_2026-09-06/final_modal_firms.csv',dtype=str).identificad)
flags=['pos_emp','cba2009_avg','cba_pre2012_avg','cba_post2012_avg','lagos_sample_avg','in_balanced_panel','treat_ultra']
d,_=pyreadstat.read_dta(str(X/'modal/rais_firm/cba_rais_firm_2007_2016.dta'),disable_datetime_conversion=True)
d=d[d.identificad.isin(ids)].copy();assert not d.duplicated(['identificad','year']).any()
d[['identificad','year','municipio','union_id','avg_file_date','min_file_date','max_file_date','start_date_stata','end_date_stata']+flags].to_csv(O/'modal_case_panel.csv',index=False)
l=pd.read_csv(O/'legacy_case_panel.csv',dtype={'identificad':str,'municipio':str,'union_id':str})
raw=pd.read_csv(O/'raw_municipality_history.csv',dtype={'identificad':str,'municipio':str});mode=pd.read_csv(O/'modal_dictionary.csv',dtype=str).set_index('identificad')
rows=[]
for i in sorted(ids):
 a=d[d.identificad==i];old=l[l.identificad==i];row={'identificad':i,'identificad_8':i[:8],'status':'missing' if i in B else 'additional','baseline_included':int(i in B),'modal_included':int(i in M),'legacy_source_status':'observed_published_panel' if len(old) else 'absent_from_published_filtered_panel; historical_flags_unavailable','modal_source_status':'isolated_reconstruction_D1','legacy_join_key':None,'legacy_join_key_status':'unavailable','modal_municipio':mode.loc[i,'modemun'],'modal_tie_status':'full-population dictionary observed; worker-frequency ties not recomputed; code uses numeric minmode and excludes missing values'}
 for f in flags:
  assert a[f].nunique(dropna=False)==1,(i,f)
  row['modal_'+f]=a[f].iloc[0];row['legacy_'+f]=old[f].iloc[0] if len(old) else None
 inclusion=int(row['modal_lagos_sample_avg']==1 and row['modal_in_balanced_panel']==1)
 assert inclusion==int(i in M),(i,'membership disagrees with full-modal list')
 fail=[f for f in ['cba_pre2012_avg','cba_post2012_avg','pos_emp','in_balanced_panel'] if row['modal_'+f]!=1]
 row['final_exclusion_reason']=';'.join(fail) if fail else 'passes_all_rebuilt_conditions; historical_exclusion_unobserved'
 row['implicated_stage']='1020 CBA linkage/aggregation -> 1030 date eligibility; exact historical divergence unresolved'
 row['evidence']='modal_case_panel.csv;legacy_case_panel.csv;raw_municipality_history.csv;cba_matches_modal.csv;run_modal_cases.log'
 hist=raw[(raw.identificad==i)&(raw.year>=2009)];row['raw_distinct_municipalities_2009_2016']=hist.municipio.nunique();rows.append(row)
pd.DataFrame(rows).to_csv(O/'reconciliation.csv',index=False)
match,_=pyreadstat.read_dta(str(X/'modal/CBA/cba_estab_firm.dta'),disable_datetime_conversion=True)
cols=['identificad','identificad_8','municipio','state','pair_id','contract_id','union_id','start_year','file_year','end_year','start_date_stata','file_date_stata','end_date_stata','codigo_municipio']
match[match.identificad.isin(ids)][cols].to_csv(O/'cba_matches_modal.csv',index=False)
print(pd.DataFrame(rows).groupby(['status','final_exclusion_reason']).size().to_string());print('exception',pd.DataFrame(rows).query('status=="missing" and modal_cba_pre2012_avg==1').to_string(index=False))
# Root-scoped raw coverage agreement, treating row order/index as immaterial.
a=pd.read_csv(O/'legacy_exploded_root_records.csv',dtype=str,keep_default_na=False);b=pd.read_csv(O/'rebuilt_exploded_root_records.csv',dtype=str,keep_default_na=False)
cols=sorted(set(a.columns)&set(b.columns)-{'index'});aa=set(map(tuple,a[cols].values));bb=set(map(tuple,b[cols].values));result={'columns':cols,'legacy_rows':len(a),'rebuilt_rows':len(b),'legacy_unique_records':len(aa),'rebuilt_unique_records':len(bb),'legacy_only':len(aa-bb),'rebuilt_only':len(bb-aa)}
(O/'exploded_comparison.json').write_text(json.dumps(result,indent=2));print('coverage compare',result)
