from pathlib import Path
import pandas as pd,pyreadstat,json
R=Path(__file__).resolve().parents[2];O=R/'quality_reports/sample_gap_investigation';X=R/'Data/sample_gap_investigation'
fields=['union_id','avg_file_date','min_file_date','max_file_date','start_date_stata','end_date_stata','cba2009_avg','cba_pre2012_avg','cba_post2012_avg','lagos_sample_avg','in_balanced_panel','treat_ultra'];cols=['identificad','year']+fields
l,_=pyreadstat.read_dta(str(R/'archive/Data/baseline_2026-09-06/lagos_sample_sep24_LEGACY_Oct2025.dta'),usecols=cols,disable_datetime_conversion=True)
d,_=pyreadstat.read_dta(str(X/'published_municipio/rais_firm/cba_rais_firm_2007_2016.dta'),usecols=cols,disable_datetime_conversion=True)
# 1030's IBGE merge retains using-only geography rows with blank ID/year.
d=d[d.identificad.ne('')].copy()
m=l.merge(d,on=['identificad','year'],suffixes=('_legacy','_proxy'),validate='one_to_one');counts={};bad=pd.Series(False,index=m.index)
for f in fields:
 a=m[f+'_legacy'];b=m[f+'_proxy'];eq=a.eq(b)|(a.isna()&b.isna());counts[f]=int((~eq).sum());bad|=~eq
m[bad].to_csv(O/'published_control_differences.csv',index=False)
rec=pd.read_csv(O/'reconciliation.csv',dtype={'identificad':str,'identificad_8':str,'modal_municipio':str});ids=set(rec.identificad);d[d.identificad.isin(ids)].to_csv(O/'published_municipio_case_panel.csv',index=False)
z=d.drop_duplicates('identificad').set_index('identificad')
for f in ['cba2009_avg','cba_pre2012_avg','cba_post2012_avg','lagos_sample_avg']:
 rec['published_geo_control_'+f]=rec.identificad.map(z[f])
ld=pd.read_csv(O/'legacy_case_panel.csv',dtype={'identificad':str,'municipio':str}).groupby('identificad').municipio.first();rec['observed_published_municipio']=rec.identificad.map(ld)
for index,row in rec.iterrows():
 if row.status=='missing':
  rec.loc[index,'controlled_mechanism_status']='observed published municipality alone restores inclusion and published union/average/end-date history in D3; historical key provenance unobserved'
  rec.loc[index,'evidence']=row.evidence+';published_municipio_case_panel.csv;published_control_summary.json;run_published_cases.log'
rec.to_csv(O/'reconciliation.csv',index=False)
out={'compared_published_establishments':m.identificad.nunique(),'compared_establishment_years':len(m),'differences_by_field':counts,'any_difference_rows':int(bad.sum()),'note':'D3 uses observed published output municipality as a diagnostic key, not a recovered historical intermediate; nulls compare equal; numeric dates compared exactly'}
(O/'published_control_summary.json').write_text(json.dumps(out,indent=2));print(out)

cols=['identificad','identificad_8','municipio','state','pair_id','contract_id','union_id','start_year','file_year','end_year','start_date_stata','file_date_stata','end_date_stata','codigo_municipio']
a,_=pyreadstat.read_dta(str(X/'published_municipio/CBA/cba_estab_firm.dta'),usecols=cols,disable_datetime_conversion=True)
a=a[a.identificad.isin(ids)].copy();a['source_status']='D3 reconstruction using observed published municipality; not historical match records'
a.to_csv(O/'cba_matches_published_control.csv',index=False)
