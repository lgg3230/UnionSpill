"""Reproduce complete-baseline membership comparison; no production writes."""
from pathlib import Path
import pandas as pd, pyreadstat, duckdb,json
R=Path(__file__).resolve().parents[2];O=R/'quality_reports/sample_gap_investigation';B=R/'archive/Data/baseline_2026-09-06'
c=duckdb.connect(); c.execute('PRAGMA threads=4')
k=c.execute('SELECT DISTINCT identificad,year FROM read_parquet(?) ORDER BY identificad,year',[str(B/'worker_panel_lagos_BASELINE.parquet')]).df();k.to_csv(O/'baseline_worker_keys.csv',index=False)
b=set(k.identificad);m=set(pd.read_csv(B/'final_modal_firms.csv',dtype=str).identificad)
cols=['identificad','year','lagos_sample_avg','in_balanced_panel','treat_ultra','cba_pre2012_avg','cba_post2012_avg','pos_emp'];panels={}
for name,p in [('legacy',B/'lagos_sample_sep24_LEGACY_Oct2025.dta'),('rebuilt',R/'Data/CBA_RAIS_firm_level/lagos_sample_sep24_test.dta')]:
 d,_=pyreadstat.read_dta(str(p),usecols=cols);d.to_csv(O/f'{name}_panel_flags.csv',index=False);panels[name]=d
 assert not d.duplicated(['identificad','year']).any()
l=panels['legacy'].query('lagos_sample_avg==1 & in_balanced_panel==1');r=panels['rebuilt'].query('lagos_sample_avg==1 & in_balanced_panel==1');live=set(r.identificad)
assert set(l.identificad)==b
rows=[]
for i in sorted(b|m): rows.append({'identificad':i,'baseline_included':i in b,'modal_included':i in m,'live_muni2009_included':i in live})
pd.DataFrame(rows).to_csv(O/'full_membership_comparison.csv',index=False)
pd.DataFrame({'identificad':sorted(b^m)}).to_csv(O/'discrepant_ids.csv',index=False)
out={'baseline':len(b),'modal':len(m),'missing':len(b-m),'additional':len(m-b),'common':len(b&m),'live':len(live),'live_missing':len(b-live),'live_additional':len(live-b),'worker_rows_unique_keys':len(k),'worker_keys_by_year':k.groupby('year').size().to_dict(),'baseline_vs_legacy_eligible_id_difference':0,'legacy_common_modal_rows':len(l[l.identificad.isin(b&m)]),'legacy_common_modal_by_year':l[l.identificad.isin(b&m)].groupby('year').size().to_dict(),'legacy_duplicate_keys':0,'live_duplicate_keys':0}
(O/'comparison_summary.json').write_text(json.dumps(out,indent=2));print(out)
