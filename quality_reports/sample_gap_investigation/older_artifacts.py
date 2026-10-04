"""Read older surviving artifacts, keeping their vintages distinct from October."""
from pathlib import Path
import pandas as pd,pyreadstat,pyarrow.parquet as pq,duckdb,json
R=Path(__file__).resolve().parents[2];O=R/'quality_reports/sample_gap_investigation';ids=set(pd.read_csv(O/'discrepant_ids.csv',dtype=str).identificad)
meta=[]
for f in ['spill_samples','lagos_sample_merge_worker','balpan_file','balpan_no','balpan_start']:
 p=R/f'Data/RAIS_aux/{f}.dta';d,m=pyreadstat.read_dta(str(p),disable_datetime_conversion=True);d['identificad']=d.identificad.map(lambda x:x[1:] if len(x)==15 else x);d[d.identificad.isin(ids)].to_csv(O/f'older_{f}_cases.csv',index=False);meta.append({'path':str(p),'rows':m.number_rows,'embedded_timestamp':str(m.creation_time),'columns':m.column_names})
p=R/'Data/CBA/collapsed_cba_firm.dta';cols=['identificad','identificad_8','active_year','municipio','union_id','file_date_stata','start_date_stata','end_date_stata','pair_id','employer_id'];d,m=pyreadstat.read_dta(str(p),usecols=cols,disable_datetime_conversion=True);d[d.identificad.isin(ids)].to_csv(O/'older_april2025_cba_cases.csv',index=False);meta.append({'path':str(p),'rows':m.number_rows,'embedded_timestamp':str(m.creation_time),'note':'older schema and m:m producer; not proven published input'})
for p in sorted((R/'Data/CBA_RAIS_firm_level/fullrais_panel').glob('*.parquet')):
 f=pq.ParquetFile(p);meta.append({'path':str(p),'columns':f.schema.names,'rows':f.metadata.num_rows})
c=duckdb.connect();idtable=pd.DataFrame({'identificad':sorted(ids)});c.register('ids',idtable);p=R/'Data/RAIS_aux/worker_estab_all_years.parquet';d=c.execute('select identificad, min(municipio) muni_min,max(municipio) muni_max,min(modemun) mode_min,max(modemun) mode_max,count(*) n_rows from read_parquet(?) semi join ids using(identificad) group by identificad',[str(p)]).df();d.to_csv(O/'nov2025_worker_excerpt_cases.csv',index=False);meta.append({'path':str(p),'range':c.execute('select min(identificad),max(identificad),min(year),max(year),count(*) from read_parquet(?)',[str(p)]).fetchall()})
(O/'extended_older_artifact_metadata.json').write_text(json.dumps(meta,indent=2))
