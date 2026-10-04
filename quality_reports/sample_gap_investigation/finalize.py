from pathlib import Path
import json,hashlib,subprocess,platform,sys,re,datetime
import pandas as pd,pyreadstat,duckdb,pyarrow
R=Path(__file__).resolve().parents[2];O=R/'quality_reports/sample_gap_investigation'
r=pd.read_csv(O/'reconciliation.csv',dtype={'identificad':str,'identificad_8':str,'modal_municipio':str,'observed_published_municipio':str,'baseline_worker_mode_municipio':str})
r['identificad_8']=r.identificad.str[:8]
r['evidence']=r.evidence.map(lambda x:';'.join(dict.fromkeys(x.split(';'))))
r['baseline_worker_mode_municipio']=r.baseline_worker_mode_municipio.str.removesuffix('.0')
assert r.identificad.str.len().eq(14).all()
may=pd.read_csv(O/'older_balpan_file_cases.csv',dtype={'identificad':str}).set_index('identificad');aug=set(pd.read_csv(O/'older_lagos_sample_merge_worker_cases.csv',dtype={'identificad':str}).identificad)
r['observed_may2025_lagos_sample_f']=r.identificad.map(may.lagos_sample_f);r['observed_august2025_unbalanced_sample_inclusion']=r.identificad.isin(aug).astype(int);r['older_sample_source_status']='observed older sample artifacts; not October flags';r.to_csv(O/'reconciliation.csv',index=False)
assert len(r)==48 and r.identificad.nunique()==48
assert (r.status=='missing').sum()==29 and (r.status=='additional').sum()==19
assert r.loc[r.status=='additional','legacy_cba_pre2012_avg'].isna().all()
assert r.modal_pos_emp.eq(1).all() and r.modal_in_balanced_panel.eq(1).all()
assert r.loc[r.status=='missing','published_geo_control_lagos_sample_avg'].eq(1).all()
assert r.loc[r.status=='missing','observed_may2025_lagos_sample_f'].eq(0).all()
assert r.loc[r.status=='additional','observed_may2025_lagos_sample_f'].eq(1).all()
validation={'case_count':48,'unique_ids':48,'missing':29,'additional':19,'D1_matches_preserved_modal_case_membership':True,'D2_changed_membership':int(r.municipality_control_changes_membership.sum()),'D3_restores_missing':29,'D3_peer_comparison':json.loads((O/'published_control_summary.json').read_text()),'older_sample_full_score':json.loads((O/'older_membership_summary.json').read_text()),'stata_runs':{}}
for name in ['modal','raw','published']:
 s=(O/f'run_{name}_cases.log').read_text();errors=re.findall(r'^r\(\d+\);',s,re.M);assert not errors,(name,errors);assert s.rstrip().endswith('end of do-file');validation['stata_runs'][name]={'normal_completion':True,'stata_errors':errors}
# Independently recompute exactly the pre/post date rules (including Stata missing ordering for end date).
for source in ['legacy','modal','raw_control','published_municipio']:
 d=pd.read_csv(O/f'{source}_case_panel.csv',dtype={'identificad':str});bad=[]
 for i,g in d.groupby('identificad'):
  f=g.avg_file_date;e=g.end_date_stata;day=lambda x:(pd.Timestamp(x)-pd.Timestamp('1960-01-01')).days
  early=f[f.between(day('2009-01-01'),day('2009-12-31'))].min();pre=pd.notna(early) and f.between(early+1,day('2012-01-01')).any();post=((f>=day('2012-01-01'))&f.notna()&((e>=day('2012-12-31'))|e.isna())).any()
  if int(pre)!=int(g.cba_pre2012_avg.iloc[0]) or int(post)!=int(g.cba_post2012_avg.iloc[0]):bad.append(i)
 assert not bad,(source,bad);validation[source+'_date_flag_disagreements']=bad
(O/'validation.json').write_text(json.dumps(validation,indent=2))
def md5(p):
 h=hashlib.md5()
 with p.open('rb') as f:
  for b in iter(lambda:f.read(8388608),b''):h.update(b)
 return h.hexdigest()
extra=[]
manifest={line.split('  ',1)[1]:line.split('  ',1)[0] for line in (R/'archive/Data/baseline_2026-09-06/manifest_data.md5').read_text().splitlines() if '  ' in line}
for rel in ['Data/RAIS_aux/lagos_sample_merge_worker.dta','Data/RAIS_aux/balpan_file.dta','Data/RAIS_aux/balpan_no.dta','Data/RAIS_aux/balpan_start.dta','Data/CBA/collapsed_cba_firm.dta','Data/RAIS_aux/bal_pan.dta']:
 p=R/rel;_,m=pyreadstat.read_dta(str(p),metadataonly=True);hash_=md5(p);extra.append({'path':str(p.resolve()),'bytes':p.stat().st_size,'md5':hash_,'pre_rerun_manifest_md5':manifest.get(rel),'matches_pre_rerun_manifest':hash_==manifest[rel] if rel in manifest else None,'embedded_timestamp':str(m.creation_time)})
(O/'older_input_fingerprints.json').write_text(json.dumps(extra,indent=2))
inputs=json.loads((O/'input_fingerprints.json').read_text())+json.loads((O/'reference_fingerprints.json').read_text())+extra
for f in ['extract.py','compare.py','1020_suffix.do','run_modal_cases.do','prepare_raw_control.py','run_raw_cases.do','reconcile.py','control_results.py','join_details.py','enrich_cases.py','prepare_published_control.py','run_published_cases.do','published_control_results.py','older_membership.py','older_artifacts.py','finalize.py']:
 inputs.append({'path':str(O/f),'md5':md5(O/f)})
# Fingerprint the actual compact annual inputs; original raw source metadata is retained separately.
for kind in ['modal','raw','published_municipio']:
 for p in sorted((R/f'Data/sample_gap_investigation/{kind}/rais_aux').glob('unique_firms_*.dta')):
  inputs.append({'path':str(p),'md5':md5(p)})
for p in sorted((R/'Data/sample_gap_investigation/modal/rais_firm').glob('rais_firm_*.dta')):
 inputs.append({'path':str(p),'md5':md5(p)})
# Baseline file identity rechecked after all experiments; production code untouched.
assert md5(R/'archive/Data/baseline_2026-09-06/lagos_sample_sep24_LEGACY_Oct2025.dta')=='232e8af202087211d276af84bb22cd6c'
assert md5(R/'Data/CBA_RAIS_firm_level/lagos_sample_sep24.dta')=='232e8af202087211d276af84bb22cd6c'
run={'date':str(datetime.datetime.now().astimezone()),'status':'completed isolated diagnostics; historical producer unresolved','root':str(R),'git_revision':subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip(),'relevant_working_tree_diff':'relevant_code_diff.patch (empty)','preexisting_changes':'working_tree_status.txt','python':sys.version,'python_executable':sys.executable,'packages':{'pandas':pd.__version__,'pyreadstat':pyreadstat.__version__,'duckdb':duckdb.__version__,'pyarrow':pyarrow.__version__},'stata':'Stata/MP 17; /software/Stata/stata17/stata-mp','commands_document':'README.md','output_tree':str(R/'Data/sample_gap_investigation'),'keys':{'membership':'identificad','panel':['identificad','year'],'CBA_source':['pair_id','contract_id'],'geographic_joins':'root+municipality / root+state / root, selected by start_year'},'sample':'lagos_sample_avg==1 & in_balanced_panel==1; year in 2009..2016; both treatment arms','baseline_worker_extraction':'all rows in existing 2009..2016 artifact; distinct establishment IDs','diagnostic_years':'2007..2016 RAIS; 2009..2016 joins','diagnostic_roots':42,'full_candidate_reconstruction_run':False,'references_and_code':inputs,'extracted_input_metadata':'extraction_inputs.json','validation':'validation.json'}
(O/'run_manifest.json').write_text(json.dumps(run,indent=2));print(json.dumps(validation,indent=2))
