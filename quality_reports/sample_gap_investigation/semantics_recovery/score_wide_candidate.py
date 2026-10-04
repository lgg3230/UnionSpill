"""Score independent full-population candidate against the complete baseline."""
from pathlib import Path
import pandas as pd,pyreadstat,json,duckdb
R=Path(__file__).resolve().parents[3];O=Path(__file__).resolve().parent;W=R/'Data/sample_gap_investigation/wide_2007_2016';B=R/'archive/Data/baseline_2026-09-06'
def read(p,cols=None):return pyreadstat.read_dta(str(p),usecols=cols,disable_datetime_conversion=True)[0]
d=read(W/'rais_firm/eligible_panel.dta');assert not d.duplicated(['identificad','year']).any(); candidate=set(d.identificad)
con=duckdb.connect();con.execute('PRAGMA threads=4');k=con.execute('SELECT DISTINCT identificad,year FROM read_parquet(?)',[str(B/'worker_panel_lagos_BASELINE.parquet')]).df();baseline=set(k.identificad);assert len(baseline)==16472
independent=set(pd.read_csv(O/'independent_eligibility_ids.csv',dtype=str).identificad);assert independent==candidate
(O/'independent_eligibility_validation.json').write_text(json.dumps({'baseline':len(baseline),'independent_candidate':len(independent),'missing':len(baseline-independent),'additional':len(independent-baseline),'missing_ids':sorted(baseline-independent),'additional_ids':sorted(independent-baseline)},indent=2))
missing=baseline-candidate;additional=candidate-baseline
pd.DataFrame({'identificad':sorted(missing)}).to_csv(O/'wide_missing_ids.csv',index=False);pd.DataFrame({'identificad':sorted(additional)}).to_csv(O/'wide_additional_ids.csv',index=False)
pd.DataFrame([{'identificad':i,'baseline_included':i in baseline,'wide_candidate_included':i in candidate} for i in sorted(baseline|candidate)]).to_csv(O/'wide_full_membership_comparison.csv',index=False)
fields=['union_id','avg_file_date','min_file_date','max_file_date','start_date_stata','end_date_stata','cba2009_avg','cba_pre2012_avg','cba_post2012_avg','lagos_sample_avg','in_balanced_panel','treat_ultra']
l=read(B/'lagos_sample_sep24_LEGACY_Oct2025.dta',['identificad','year']+fields);l=l[l.identificad.isin(baseline)&l.year.between(2009,2016)]
m=l.merge(d,on=['identificad','year'],suffixes=('_legacy','_wide'),validate='one_to_one');different=pd.Series(False,index=m.index);counts={}
for f in fields:
 equal=m[f+'_legacy'].eq(m[f+'_wide'])|(m[f+'_legacy'].isna()&m[f+'_wide'].isna());counts[f]=int((~equal).sum());different|=~equal
m[different].to_csv(O/'wide_published_panel_differences.csv',index=False)
c=pd.read_csv(O/'wide_reconciliation.csv',dtype={'identificad':str,'identificad_8':str});c['wide_candidate_included']=c.identificad.isin(candidate);c['wide_agrees_with_baseline']=c.wide_candidate_included.eq(c.baseline_included.eq(1));c['wide_assignment_source']='computed from full upstream 2007-2016 worker votes; not an observed historical dictionary';c.to_csv(O/'wide_reconciliation.csv',index=False)
out={'baseline':len(baseline),'candidate':len(candidate),'common':len(baseline&candidate),'missing':len(missing),'additional':len(additional),'candidate_id_year_rows':len(d),'compared_published_id_year_rows':len(m),'differences_by_field':counts,'any_difference_rows':int(different.sum()),'original_discrepancies_resolved':int(c.wide_agrees_with_baseline.sum()),'candidate_inputs_use_published_ids_or_municipalities':False,'production_pin_changed':False}
(O/'wide_membership_validation.json').write_text(json.dumps(out,indent=2));print(json.dumps(out,indent=2),flush=True)
