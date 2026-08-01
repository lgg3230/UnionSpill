# Within-Firm Tenure/Layer Exhibits

This folder reproduces the within-firm group-level spillover exhibits used in
the paper and the replication wage-vs-hourly report.

The tenure-only standalone entry point is:

```bash
bash Programs/layer_connectivity/_run_tenure_standalone.sh
```

That script rebuilds the `ten2` connectivity measure, rebuilds the corrected
tenure layer outcomes, runs the tenure-only monthly and hourly Stata estimates,
and writes tenure-only TeX fragments.

Main generated tenure outputs:

- `Data/layer_connectivity/final_measures/firm_layer_connectivity_ten2.{dta,parquet}`
- `Data/layer_connectivity/firm_layer_outcomes_ten2.{dta,parquet}`
- `Tables/layer_connectivity/07_within_firm/a7_ten2.csv`
- `Tables/layer_connectivity/07_within_firm/a7_hw_ten2.csv`
- `quality_reports/replication/hourly_variant_currentconn/frag/t_groupspecs_tenure.tex`
- `quality_reports/replication/hourly_variant_currentconn/frag/t_groupspecs_tenure_hw.tex`

The hourly layer outcome is computed in
`../00_pipeline/06z_prep_outcomes_unified.py` as:

```text
log((remdezr / (horascontr * 4.348)) / IPCA_year)
```

The all-partition wrappers remain available:

```bash
/software/Stata/stata17/stata-mp -b do Programs/layer_connectivity/07_within_firm/_run_within_firm.do
/software/Stata/stata17/stata-mp -b do Programs/layer_connectivity/07_within_firm/_run_within_firm_hw.do
```
