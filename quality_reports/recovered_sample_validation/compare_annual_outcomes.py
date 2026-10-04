from pathlib import Path
import pandas as pd,numpy as np,pyreadstat,json
R=Path(__file__).resolve().parents[2];O=Path(__file__).resolve().parent;X=R/'Data/recovered_sample_validation'
def read(p,cols=None):return pyreadstat.read_dta(str(p),usecols=cols,disable_datetime_conversion=True)[0]
a=read(X/'firm/recovered_preconnectivity.dta');b=read(R/'archive/Data/baseline_2026-09-06/lagos_sample_sep24_LEGACY_Oct2025.dta');a=a.query('in_balanced_panel==1 & lagos_sample_avg==1 & year>=2009 & year<=2016');b=b.query('in_balanced_panel==1 & lagos_sample_avg==1 & year>=2009 & year<=2016');assert len(a)==len(b)==131776
assert set(map(tuple,a[['identificad','year']].to_numpy()))==set(map(tuple,b[['identificad','year']].to_numpy()))
a=a.set_index(['identificad','year']).sort_index();b=b.set_index(['identificad','year']).sort_index();rows=[];examples=[]
for v in sorted(set(a)&set(b)):
 x=a[v];y=b[v];eq=x.eq(y)|(x.isna()&y.isna()); numeric=pd.api.types.is_numeric_dtype(x) and pd.api.types.is_numeric_dtype(y);z=(x-y).abs() if numeric else None
 rows.append({'variable':v,'rows':len(x),'exact_differences':int((~eq).sum()),'missingness_differences':int(x.isna().ne(y.isna()).sum()),'max_abs_difference':float(z.max()) if numeric else None,'differences_over_1e_6':int((z>1e-6).sum()) if numeric else None})
 if (~eq).any():
  ex=pd.DataFrame({'recovered':x[~eq].head(10),'published':y[~eq].head(10)}).reset_index();ex['variable']=v;examples.append(ex)
d=pd.DataFrame(rows);d.to_csv(O/'annual_outcome_field_comparison.csv',index=False)
if examples:pd.concat(examples).to_csv(O/'annual_outcome_difference_examples.csv',index=False)
focus=['firm_emp','l_firm_emp','lr_remdezr','lr_remdezr_h','lr_remmedr','retention','hiring','quits','layoffs','leaves','turnover','separations','numb_clauses','industry1','microregion','municipio','mode_union','mode_base_month'];print(d[d.variable.isin(focus)].to_string(index=False),flush=True)
(O/'annual_outcome_comparison_summary.json').write_text(json.dumps({'matched_rows':len(a),'matched_establishments':a.index.get_level_values(0).nunique(),'common_variables':len(d),'variables_with_differences':int(d.exact_differences.gt(0).sum()),'focus':d[d.variable.isin(focus)].to_dict('records')},indent=2))
