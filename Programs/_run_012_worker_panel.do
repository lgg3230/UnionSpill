global klc "/kellogg/proj/lgg3230"
global main "/kellogg/proj/lgg3230"
global rais_raw_dir "$main/RAIS/output/data/full"
global rais_aux     "$main/UnionSpill/Data/RAIS_aux"

do "/kellogg/proj/lgg3230/UnionSpill/Programs/1060_rais_worker_panel.do"

shell ~/.conda/envs/venv_python312/bin/python -c "
import pandas as pd
df = pd.read_stata('/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/worker_estab_all_years.dta', convert_categoricals=False)
print(f'Rows: {len(df)}')
df.to_parquet('/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/worker_estab_all_years.parquet', index=False)
print('Parquet saved.')
"

shell source /kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh && notify "worker_estab_all_years done" "dta + parquet regenerated"
