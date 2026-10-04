from pathlib import Path
import pandas as pd,pyreadstat,json,hashlib,subprocess,re,datetime
R=Path(__file__).resolve().parents[3];O=Path(__file__).resolve().parent;S=R/'Data/sample_gap_investigation/semantics_recovery';W=R/'Data/sample_gap_investigation/wide_2007_2016';B=R/'archive/Data/baseline_2026-09-06'
def fingerprint(p,hash_bytes=False):
 p=Path(p);st=p.stat();out={'path':str(p),'resolved_path':str(p.resolve()),'bytes':st.st_size,'mtime':datetime.datetime.fromtimestamp(st.st_mtime).isoformat()}
 if p.suffix=='.dta':
  _,m=pyreadstat.read_dta(str(p),metadataonly=True);out.update(rows=m.number_rows,stata_timestamp=str(m.creation_time))
 if hash_bytes:
  h=hashlib.md5()
  with p.open('rb') as f:
   for chunk in iter(lambda:f.read(8*1024*1024),b''):h.update(chunk)
  out['md5']=h.hexdigest()
 return out
logs={'stata_semantics':'SEMANTICS COMPLETE','supplemental_semantics':'SUPPLEMENTAL SEMANTICS COMPLETE','profile_actual_spells':'ACTUAL SPELL PROFILES COMPLETE','build_full_worker_counts':'FULL WORKER COUNTS COMPLETE','prepare_full_annual':'FULL ANNUAL INPUTS COMPLETE','build_wide_dictionary':'WIDE DICTIONARY COMPLETE','validate_current_mode':'CURRENT MODE VALIDATION COMPLETE','uncertain_mode_eligibility':'UNCERTAIN ELIGIBILITY COMPLETE','run_wide_full':'FULL WIDE CANDIDATE COMPLETE','extract_wide_case_panels':'WIDE CASE EXTRACTION COMPLETE','compare_full_historical_cba':'FULL HISTORICAL CBA INPUT EQUIVALENCE COMPLETE','verify_cba_build':'ISOLATED CBA VERIFICATION BUILD COMPLETE','compare_cba_builds':'INDEPENDENT CBA BUILDS AGREE ON ALL MEMBERSHIP INPUTS','verify_full_merge':'FULL MERGE CONSISTENCY COMPLETE','validate_cba_keys':'FIRM CBA ROOTS ALL NONMISSING','independent_eligibility_check':'INDEPENDENT ELIGIBILITY CHECK COMPLETE'}
for name,marker in logs.items():
 t=(O/f'{name}.log').read_text();assert marker in t,name;assert not re.search(r'^r\(\d+\);',t,re.M),name
v=json.loads((O/'wide_membership_validation.json').read_text());g=json.loads((O/'wide_dictionary_validation.json').read_text());u=pd.read_csv(O/'uncertain_mode_eligibility.csv',dtype={'identificad':str})
assert len(u)==10 and u.potential_cba_rows.eq(0).all()
assert g['published_municipality_differences']==0 and g['discrepancy_robust_modes']==48
assert v['missing']==0 and v['additional']==0 and v['candidate']==16472
assert v['original_discrepancies_resolved']==48
assert v['any_difference_rows']==0 and v['compared_published_id_year_rows']==131776
assert len(pd.read_csv(O/'case_recovery_summary.csv',dtype={'identificad':str}))==48
protected=[fingerprint(R/'Data/CBA_RAIS_firm_level/lagos_sample_sep24.dta',True),fingerprint(B/'lagos_sample_sep24_LEGACY_Oct2025.dta',True),fingerprint(B/'worker_panel_lagos_BASELINE.parquet',True)]
assert [x['md5'] for x in protected]==['232e8af202087211d276af84bb22cd6c']*2+['8b324dc4e6866c69b2b22c3b6109954b']
inputs=[]
for y in range(2007,2017):
 inputs.append(fingerprint(B/f'rais_firm_rawmuni_backup/rais_firm_{y}.dta'))
 p=R/f'Data/RAIS_aux/worker_estab_{y}.dta' if y<=2011 else Path(f'/kellogg/proj/lgg3230/RAIS/output/data/full/RAIS_{y}.dta')
 inputs.append(fingerprint(p))
for name in ['cba_firm_exploded.dta','cba_coverage_clean.dta']:inputs.append(fingerprint(R/'Data/CBA'/name,True))
inputs.append(fingerprint(R/'Data/IBGE/mun_microregion_ibge.dta',True))
inputs.append(fingerprint(B/'legacy_cba/cba_firm_exploded.dta',True))
inputs.append(fingerprint(R/'Data/RAIS_aux/rais_mode_mun_ind.dta',True))
code=[fingerprint(p,True) for p in sorted(O.iterdir()) if p.suffix in ['.do','.py','.patch']]
code.extend(fingerprint(p,True) for p in [O.parent/'1020_suffix.do',R/'Programs/sample_construction/1010_rais_clean.do',R/'Programs/sample_construction/1030_merge_cba_rais.do'])
outputs=[fingerprint(W/'rais_aux/rais_mode_mun_ind.dta',True),fingerprint(W/'rais_firm/eligible_panel.dta',True)]
manifest={'git_head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip(),'historical_before_commit':'786d43c01a99a076141a27c8ef400146a1a580d3','historical_window_change_commit':'ecf87cdedea266f2aaefba7e323b4f1d4f5648cd','protected_hashes_verified':protected,'upstream_inputs':inputs,'code':code,'key_outputs':outputs,'large_raw_inputs_fingerprint_limit':'Raw RAIS and annual worker/firm files are recorded by path, bytes, filesystem time, Stata timestamp and row count; no claim of byte identity with missing October 2025 raw-input snapshots.','membership_validation':v,'dictionary_validation':g,'uncertain_modes_without_any_firm_CBA_root_match':10,'historical_exploded_cba_full_record_match':{'rows':5523176,'variables':7},'independent_temp_isolated_CBA_builds_agree_on_all_membership_inputs':True,'full_population_RAIS_CBA_merge_consistency_checked':True,'historical_provenance_limit':'The preserved source directly records the 2007 pool and its later change to 2009, but is a work-in-progress snapshot with a commented dictionary-writing block; no October 6 execution log or original geographic dictionary was found.'}
(O/'recovery_manifest.json').write_text(json.dumps(manifest,indent=2));print('RECOVERY VALIDATED; protected hashes unchanged',flush=True)
