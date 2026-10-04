from pathlib import Path
import pandas as pd, pyreadstat, json, hashlib, datetime, subprocess, sys
ROOT=Path(__file__).resolve().parents[2]; O=ROOT/'quality_reports/sample_gap_investigation'; X=ROOT/'Data/sample_gap_investigation'; B=ROOT/'archive/Data/baseline_2026-09-06'
for n in ['modal/rais_aux','modal/rais_firm','modal/CBA']: (X/n).mkdir(parents=True,exist_ok=True)
ids=set(pd.read_csv(O/'discrepant_ids.csv',dtype=str).identificad); roots={x[:8] for x in ids}
inputs=[]
def read(p,cols=None):
 p=Path(p); d,m=pyreadstat.read_dta(str(p),usecols=cols,disable_datetime_conversion=True)
 inputs.append({'path':str(p.resolve()),'size':p.stat().st_size,'mtime':datetime.datetime.fromtimestamp(p.stat().st_mtime).isoformat(),'stata_timestamp':str(m.creation_time),'rows':m.number_rows})
 return d
mode=read(ROOT/'Data/RAIS_aux/rais_mode_mun_ind.dta'); mode=mode[mode.identificad.str[:8].isin(roots)]
mode.to_csv(O/'modal_dictionary.csv',index=False)
hist=[]; dicts=[]
for y in range(2007,2017):
 p=B/f'rais_firm_rawmuni_backup/rais_firm_{y}.dta'
 d=read(p,['identificad','identificad_8','municipio','firm_emp','clascnae20','year']); d=d[d.identificad.str[:8].isin(roots)].copy();d['year']=y
 pyreadstat.write_dta(d,str(X/f'modal/rais_firm/rais_firm_{y}.dta'),version=15)
 h=d[d.identificad.isin(ids)].copy();h['source']=str(p.relative_to(ROOT));hist.append(h)
 if y>=2009:
  u=d.merge(mode[['identificad','modemun']],on='identificad',how='inner',validate='one_to_one');u['municipio']=u.modemun;u['state']=u.municipio.str[:2]
  u=u[['identificad','identificad_8','municipio','firm_emp','state']]
  pyreadstat.write_dta(u,str(X/f'modal/rais_aux/unique_firms_{y}.dta'),version=15)
  for label,p2 in [('live',ROOT/f'Data/RAIS_aux/unique_firms_{y}.dta'),('sep24_unknown_provenance',ROOT/f'Data_may2025/rais_aux_sep24/unique_firms_{y}.dta')]:
   a=read(p2,['identificad','identificad_8','municipio','state']);a=a[a.identificad.str[:8].isin(roots)].copy();a['year']=y;a['source_status']=label;dicts.append(a)
 print('raw/dictionaries',y,flush=True)
pd.concat(hist).to_csv(O/'raw_municipality_history.csv',index=False);pd.concat(dicts).to_csv(O/'available_dictionary_records.csv',index=False)
for label,p in [('legacy',B/'lagos_sample_sep24_LEGACY_Oct2025.dta'),('live_muni2009',ROOT/'Data/CBA_RAIS_firm_level/lagos_sample_sep24_test.dta')]:
 d=read(p,['identificad','year','municipio','avg_file_date','min_file_date','max_file_date','end_date_stata','start_date_stata','union_id','pos_emp','cba2009_avg','cba_pre2012_avg','cba_post2012_avg','lagos_sample_avg','in_balanced_panel','treat_ultra']);d[d.identificad.isin(ids)].to_csv(O/f'{label}_case_panel.csv',index=False)
for label,p in [('rebuilt',ROOT/'Data/CBA/cba_firm_exploded.dta'),('legacy',B/'legacy_cba/cba_firm_exploded.dta')]:
 d=read(p);d=d[d.identificad_8.isin(roots)].copy();d.to_csv(O/f'{label}_exploded_root_records.csv',index=False)
 if label=='rebuilt': pyreadstat.write_dta(d,str(X/'modal/CBA/cba_firm_exploded.dta'),version=15)
 print('exploded',label,len(d),flush=True)
# 1020 only reads this file after the selected start point. Symlink is never an output target.
p=X/'modal/CBA/cba_coverage_clean.dta'
if not p.exists(): p.symlink_to(ROOT/'Data/CBA/cba_coverage_clean.dta')
s=(ROOT/'Programs/sample_construction/1020_clean_cba.do').read_text();start=s.index(' use "$cba_dir/cba_firm_exploded.dta", clear');(O/'1020_suffix.do').write_text(s[start:])
run=f'''clear all
set more off
version 17.0
global rais_aux "{X}/modal/rais_aux"
global rais_firm "{X}/modal/rais_firm"
global cba_dir "{X}/modal/CBA"
global ibge "{ROOT}/Data/IBGE"
do "{O}/1020_suffix.do"
do "{ROOT}/Programs/sample_construction/1030_merge_cba_rais.do"
'''
(O/'run_modal_cases.do').write_text(run)
(O/'extraction_inputs.json').write_text(json.dumps(inputs,indent=2))
