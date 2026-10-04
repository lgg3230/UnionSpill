from pathlib import Path
import hashlib,json
R=Path(__file__).resolve().parents[2];O=R/'quality_reports/sample_gap_investigation'
files=[R/'archive/Data/baseline_2026-09-06/worker_panel_lagos_BASELINE.parquet',R/'archive/Data/baseline_2026-09-06/legacy_cba/cba_firm_exploded.dta',R/'Data/CBA/cba_firm_exploded.dta',R/'Data/CBA/cba_coverage_clean.dta',R/'Data/RAIS_aux/rais_mode_mun_ind.dta']+list((R/'Programs/sample_construction').glob('10[123]*'))+[R/'Programs/0000_master.do']
a=[]
for p in files:
 if not p.is_file(): continue
 h=hashlib.md5()
 with p.open('rb') as f:
  for b in iter(lambda:f.read(8388608),b''):h.update(b)
 a.append({'path':str(p.resolve()),'md5':h.hexdigest(),'bytes':p.stat().st_size});print(p.name,h.hexdigest(),flush=True)
(O/'input_fingerprints.json').write_text(json.dumps(a,indent=2))
