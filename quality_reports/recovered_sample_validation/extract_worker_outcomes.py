from pathlib import Path
import pandas as pd,pyreadstat,pyarrow as pa,pyarrow.parquet as pq,json,time
R=Path(__file__).resolve().parents[2];O=Path(__file__).resolve().parent;X=R/'Data/recovered_sample_validation';ids=set(pd.read_csv(O/'recovered_unbalanced_ids.csv',dtype=str).identificad)
source=R/'archive/Data/baseline_2026-09-06/worker_estab_all_years.dta';cols=['PIS','identificad','year','lr_remdezr','lr_remmedr','r_remdezr','r_remmedr','r_remdezr_h','r_remmedr_h'];p=X/'firm/recovered_worker_wages.parquet';writer=None;seen=kept=0;start=time.time()
for d,m in pyreadstat.read_file_in_chunks(pyreadstat.read_dta,str(source),chunksize=2000000,usecols=cols,disable_datetime_conversion=True):
 seen+=len(d);d=d[d.identificad.isin(ids)].copy();kept+=len(d)
 if len(d):
  table=pa.Table.from_pandas(d,preserve_index=False)
  if writer is None:writer=pq.ParquetWriter(str(p),table.schema,compression='zstd')
  writer.write_table(table)
 print(json.dumps({'scanned':seen,'kept':kept,'minutes':round((time.time()-start)/60,2)}),flush=True)
if writer:writer.close()
d=pd.read_parquet(p);d['cnpj_year']=d.identificad+d.year.astype(int).astype(str);pyreadstat.write_dta(d,str(X/'firm/worker_wages.dta'),version=15)
(O/'worker_extraction_summary.json').write_text(json.dumps({'source':str(source),'scanned':seen,'selected':kept,'establishments':len(ids),'published_worker_panel_used_as_input':False},indent=2));print('RECOVERED WORKER WAGES EXTRACTED',flush=True)
