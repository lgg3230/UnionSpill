from pathlib import Path
import pandas as pd
O=Path(__file__).resolve().parent
r=pd.read_csv(O/'reconciliation.csv',dtype={'identificad':str,'identificad_8':str,'modal_municipio':str});panels={s:pd.read_csv(O/f'{s}_case_panel.csv',dtype={'identificad':str,'union_id':str}) for s in ['legacy','modal','raw_control']};j=pd.read_csv(O/'cba_join_outcomes.csv',dtype={'identificad':str,'contract_id':str});wb=pd.read_csv(O/'baseline_worker_modal_diagnostic.csv',dtype={'identificad':str}).set_index('identificad')
for index,row in r.iterrows():
 i=row.identificad
 for s,p in panels.items():
  a=p[p.identificad==i];r.loc[index,s+'_selected_unions']=';'.join(sorted(a.union_id.dropna().unique())) if len(a) else None
  r.loc[index,s+'_nonmissing_cba_years']=int(a.avg_file_date.notna().sum()) if len(a) else None
 a=j[j.identificad==i]
 for s in ['modal','raw']:
  b=a[a[s+'_join_matches']];r.loc[index,s+'_matched_distinct_contracts']=b.contract_id.nunique()
 if row.status=='missing':
  if row.modal_cba2009_avg==0:r.loc[index,'preperiod_failure_detail']='no synthetic average filing date in calendar 2009'
  elif row.modal_cba_pre2012_avg==0:r.loc[index,'preperiod_failure_detail']='2009 date present, no date at least one day later through 2012-01-01'
  else:r.loc[index,'preperiod_failure_detail']='passes pre-period; fails post-period'
 else:r.loc[index,'preperiod_failure_detail']='passes rebuilt pre-period; historical flag unavailable'
 if i in wb.index:
  r.loc[index,'baseline_worker_mode_municipio']=str(int(wb.loc[i,'modal_municipio']));r.loc[index,'baseline_worker_n_tied_modes']=wb.loc[i,'n_tied_modes']
 r.loc[index,'evidence']=row.evidence+';cba_join_outcomes.csv;raw_control_case_panel.csv;run_raw_cases.log'
r.to_csv(O/'reconciliation.csv',index=False)
print(r.query('status=="missing" and modal_cba2009_avg==1 and modal_cba_pre2012_avg==0')[['identificad','preperiod_failure_detail']].to_string(index=False))
