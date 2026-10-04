from pathlib import Path
import pandas as pd,pyreadstat,json,duckdb
R=Path(__file__).resolve().parents[2];O=R/'quality_reports/sample_gap_investigation';X=R/'Data/sample_gap_investigation';ids=set(pd.read_csv(O/'discrepant_ids.csv',dtype=str).identificad)
cols=['identificad','year','municipio','union_id','avg_file_date','min_file_date','max_file_date','start_date_stata','end_date_stata','pos_emp','cba2009_avg','cba_pre2012_avg','cba_post2012_avg','lagos_sample_avg','in_balanced_panel','treat_ultra']
d,_=pyreadstat.read_dta(str(X/'raw/rais_firm/cba_rais_firm_2007_2016.dta'),usecols=cols,disable_datetime_conversion=True);d=d[d.identificad.isin(ids)];d.to_csv(O/'raw_control_case_panel.csv',index=False)
rec=pd.read_csv(O/'reconciliation.csv',dtype={'identificad':str,'identificad_8':str,'modal_municipio':str});raw=d.drop_duplicates('identificad').set_index('identificad')
for f in ['cba2009_avg','cba_pre2012_avg','cba_post2012_avg','lagos_sample_avg','in_balanced_panel']:
 rec['raw_control_'+f]=rec.identificad.map(raw[f])
rec['municipality_control_changes_membership']=rec.modal_lagos_sample_avg!=rec.raw_control_lagos_sample_avg
rec['raw_control_agrees_with_baseline']=rec.raw_control_lagos_sample_avg==rec.baseline_included
rec['controlled_mechanism_status']=rec.municipality_control_changes_membership.map({True:'municipality/state key alone changes membership in D2',False:'raw-per-year contrast does not change membership; historical cause unresolved'})
rec.to_csv(O/'reconciliation.csv',index=False)
print(rec.groupby(['status','municipality_control_changes_membership','raw_control_agrees_with_baseline']).size().to_string())
print('unchanged:',rec.loc[~rec.municipality_control_changes_membership,'identificad'].tolist())
cols=['identificad','identificad_8','municipio','state','pair_id','contract_id','union_id','start_year','file_year','end_year','start_date_stata','file_date_stata','end_date_stata','codigo_municipio']
a,_=pyreadstat.read_dta(str(X/'raw/CBA/cba_estab_firm.dta'),usecols=cols,disable_datetime_conversion=True);a[a.identificad.isin(ids)].to_csv(O/'cba_matches_raw_control.csv',index=False)
# Baseline worker records are supplemental observations, NOT replacements for the raw annual backup.
c=duckdb.connect();idtable=pd.DataFrame({'identificad':sorted(ids)});c.register('ids',idtable)
a=c.execute('select identificad,year,municipio,count(*) n_workers from read_parquet(?) semi join ids using(identificad) group by all order by identificad,year,municipio',[str(R/'archive/Data/baseline_2026-09-06/worker_panel_lagos_BASELINE.parquet')]).df();a.to_csv(O/'baseline_worker_municipality_counts.csv',index=False)
summary=[]
for i,g in a.groupby('identificad'):
 counts=g.groupby('municipio').n_workers.sum();top=counts[counts==counts.max()].index.tolist();summary.append({'identificad':i,'source':'preserved baseline worker panel, not selected-spell reconstruction','modal_municipio':min(top),'n_tied_modes':len(top),'n_municipalities':len(counts),'mode_worker_rows':int(counts.max()),'n_missing_municipality_rows':int(g.loc[g.municipio.isna(),'n_workers'].sum())})
pd.DataFrame(summary).to_csv(O/'baseline_worker_modal_diagnostic.csv',index=False)
