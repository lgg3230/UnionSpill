"""Validation only. Published artifacts never enter dictionary construction."""
from pathlib import Path
import pandas as pd, pyreadstat, json, subprocess, hashlib
R=Path(__file__).resolve().parents[3]; O=Path(__file__).resolve().parent; S=R/'Data/sample_gap_investigation/semantics_recovery'; W=R/'Data/sample_gap_investigation/wide_2007_2016'
def read(p,cols=None):return pyreadstat.read_dta(str(p),usecols=cols,disable_datetime_conversion=True)[0]
a=read(S/'wide_mode_audit.dta'); ids=set(pd.read_csv(O.parent/'discrepant_ids.csv',dtype=str).identificad)
l=read(R/'archive/Data/baseline_2026-09-06/lagos_sample_sep24_LEGACY_Oct2025.dta',['identificad','municipio','lagos_sample_avg','in_balanced_panel']);l=l.query('lagos_sample_avg==1 & in_balanced_panel==1').drop_duplicates('identificad');l['published_municipio']=pd.to_numeric(l.municipio,errors='coerce');l=l.merge(a,on='identificad',how='left',validate='one_to_one');l['agrees']=l.published_municipio.eq(l.modemun_numeric);l.to_csv(O/'independent_wide_mode_vs_published.csv',index=False)
uncertain=a[a.robust.eq(0)].copy();history=[];votes=[]
for y in range(2007,2017):
 d=read(W/f'rais_firm/rais_firm_{y}.dta',['identificad','firm_emp']);d=d[d.identificad.isin(set(uncertain.identificad)|ids)];d['year']=y;history.append(d)
 d=read(S/f'worker_municipality_counts_{y}.dta',['identificad','municipio','workers']);d=d[d.identificad.isin(ids)];d['year']=y;votes.append(d)
h=pd.concat(history); counts=h[h.year.ge(2009)].groupby('identificad').year.nunique();uncertain['years_present_2009_2016']=uncertain.identificad.map(counts).fillna(0);uncertain.to_csv(O/'uncertain_modes_with_balance.csv',index=False)
pd.concat(votes).to_csv(O/'discrepancy_worker_votes_by_year.csv',index=False)
c=pd.read_csv(O.parent/'reconciliation.csv',dtype={'identificad':str});c=c.merge(a[['identificad','modemun_numeric','workers','runner_votes','total_ambiguous','robust']],on='identificad',how='left',validate='one_to_one');c.to_csv(O/'wide_reconciliation.csv',index=False)
f=pd.read_csv(O/'actual_2009_semantic_flags_by_establishment.csv',dtype={'identificad':str});flags={col:int(f[col].sum()) for col in f.columns if col!='identificad'}
out={'pooled_establishments':len(a),'published_baseline_establishments':len(l),'independent_published_municipality_agreement':int(l.agrees.sum()),'published_municipality_differences':int((~l.agrees).sum()),'uncertain_modes':len(uncertain),'uncertain_balanced_modes':int(uncertain.years_present_2009_2016.eq(8).sum()),'discrepancy_robust_modes':int(c.robust.eq(1).sum()),'actual_2009_root_spell_semantics':flags,'actual_2009_reversed_sort_municipality_changes':len(pd.read_csv(O/'actual_2009_sort_sensitive_municipalities.csv'))}
(O/'wide_dictionary_validation.json').write_text(json.dumps(out,indent=2));print(json.dumps(out,indent=2),flush=True)
