from pathlib import Path
import pyreadstat,pandas as pd,json
R=Path(__file__).resolve().parents[2];O=R/'quality_reports/sample_gap_investigation';B=set(pd.read_csv(O/'baseline_worker_keys.csv',dtype={'identificad':str}).identificad);M=set(pd.read_csv(R/'archive/Data/baseline_2026-09-06/final_modal_firms.csv',dtype=str).identificad)
a,_=pyreadstat.read_dta(str(R/'Data/RAIS_aux/lagos_sample_merge_worker.dta'));a['identificad']=a.identificad.map(lambda x:x[1:] if len(x)==15 else x);print('August total',len(a),a.lagos_sample_avg.value_counts().to_dict(),flush=True)
b,_=pyreadstat.read_dta(str(R/'Data/RAIS_aux/bal_pan.dta'));b=b[b.in_balanced_panel==1];ids=set(a.identificad)&set(b.identificad)
out={'august_sample_ids_before_balance':a.identificad.nunique(),'balanced_using_live_rais_presence':len(ids),'missing_baseline':len(B-ids),'additional_baseline':len(ids-B),'symmetric_difference_vs_preserved_modal':len(ids^M),'restriction_caveat':'August sample combined with September 2026 balance flags, not an observed historical balanced export'}
(O/'older_membership_summary.json').write_text(json.dumps(out,indent=2));pd.DataFrame({'identificad':sorted(ids)}).to_csv(O/'august_sample_with_current_balance.csv',index=False);print(out)
