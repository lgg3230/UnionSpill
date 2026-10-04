from pathlib import Path
import pandas as pd,pyreadstat,json
R=Path(__file__).resolve().parents[3];O=Path(__file__).resolve().parent;W=R/'Data/sample_gap_investigation/wide_2007_2016'
c=pd.read_csv(O/'wide_reconciliation.csv',dtype={'identificad':str,'identificad_8':str})
d,_=pyreadstat.read_dta(str(W/'rais_firm/discrepancy_case_panel.dta'),disable_datetime_conversion=True);d=d[d.year.between(2009,2016)]
flags=['pos_emp','cba2009_avg','cba_pre2012_avg','cba_post2012_avg','lagos_sample_avg','in_balanced_panel','treat_ultra']
for flag in flags:
 assert d.groupby('identificad')[flag].nunique().max()==1
 c['wide_'+flag]=c.identificad.map(d.groupby('identificad')[flag].first())
unions=d.groupby('identificad').union_id.agg(lambda s:';'.join(sorted(set(s)-{''})));c['wide_selected_unions']=c.identificad.map(unions)
ny=d[d.avg_file_date.notna()].groupby('identificad').year.nunique();c['wide_nonmissing_cba_years_2009_2016']=c.identificad.map(ny).fillna(0).astype(int)
def reason(row):
 names=['pos_emp','in_balanced_panel','cba_pre2012_avg','cba_post2012_avg'];failed=[x for x in names if row['wide_'+x]!=1]
 return ';'.join(failed) if failed else 'included'
c['wide_exclusion_reason']=c.apply(reason,axis=1)
cm=pd.read_csv(O/'wide_case_cba_matches.csv',dtype={'identificad':str,'contract_id':str});cc=cm.groupby('identificad').contract_id.nunique();c['wide_matched_distinct_contracts']=c.identificad.map(cc).fillna(0).astype(int)
c['recovered_membership_evidence']='full upstream 2007-2016 worker mode; full population 1020/1030; complete baseline set comparison'
c.to_csv(O/'wide_reconciliation.csv',index=False)
cols=['identificad','status','modal_municipio','modemun_numeric','wide_candidate_included','wide_agrees_with_baseline','wide_exclusion_reason','wide_selected_unions','wide_cba2009_avg','wide_cba_pre2012_avg','wide_cba_post2012_avg','wide_in_balanced_panel','wide_treat_ultra','workers','runner_votes','total_ambiguous','robust'];c[cols].to_csv(O/'case_recovery_summary.csv',index=False)
summary={'case_count':len(c),'case_years_with_nonmissing_avg_filing_and_missing_end_date':int((d.avg_file_date.notna()&d.end_date_stata.isna()).sum()),'restored_missing':int((c.status.eq('missing')&c.wide_candidate_included).sum()),'removed_additional':int((c.status.eq('additional')&~c.wide_candidate_included).sum()),'additional_exclusion_reasons':c[c.status.eq('additional')].wide_exclusion_reason.value_counts().to_dict(),'all_48_change_municipality':bool(pd.to_numeric(c.modal_municipio).ne(c.modemun_numeric).all()),'all_48_robust_modes':bool(c.robust.eq(1).all())};(O/'case_recovery_validation.json').write_text(json.dumps(summary,indent=2));print(json.dumps(summary,indent=2))
v=pd.read_csv(O/'discrepancy_worker_votes_by_year.csv',dtype={'identificad':str});v['window']=v.year.map(lambda y:'2007-2008' if y<2009 else '2009-2016');v.groupby(['identificad','municipio','window'],as_index=False).workers.sum().to_csv(O/'discrepancy_worker_votes_by_window.csv',index=False)
lines=['# All 48 original membership discrepancies','', 'Municipalities and flags in the recovered candidate are computed from upstream inputs. For the 19 additional IDs, the historical exclusion is observed but its original date flags are unavailable; the recovered exclusion mechanism is inferred and tested against that membership.','', '| Establishment | Original discrepancy | Geographic key: 2009–16 → 2007–16 | Pooled winner / runner votes | Pre-2012 flag: old → recovered | Post-2012 flag: old → recovered | Recovered outcome |','|---|---|---|---:|---:|---:|---|']
for _,z in c.sort_values('identificad').iterrows():
 votes=f"{int(z.workers)} / {int(z.runner_votes)}"+(' (minmode)' if z.workers==z.runner_votes else '')
 lines.append(f"| {z.identificad} | {z.status} | {int(z.modal_municipio)} → {int(z.modemun_numeric)} | {votes} | {int(z.modal_cba_pre2012_avg)} → {int(z.wide_cba_pre2012_avg)} | {int(z.modal_cba_post2012_avg)} → {int(z.wide_cba_post2012_avg)} | {z.wide_exclusion_reason} |")
(O/'case_recovery_table.md').write_text('\n'.join(lines)+'\n')
f=pd.read_csv(O/'actual_2009_semantic_flags_by_establishment.csv',dtype={'identificad':str});c[['identificad','status']].merge(f,on='identificad',how='left',validate='one_to_one').to_csv(O/'discrepancy_2009_semantic_flags.csv',index=False)
