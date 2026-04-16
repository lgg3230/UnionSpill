# Phase 1 Results: Employer Selection Parity

Run date: 2026-04-14

Command:

```bash
bash Programs/main_data_pipeline_duckdb/run_phase1_2009_2010.sh
```

Outputs:

- `Data/main_pipeline_duckdb/staging/rais_selected_2009.parquet`
- `Data/main_pipeline_duckdb/staging/rais_selected_2010.parquet`
- `Data/main_pipeline_duckdb/yearly_employers/yearly_employers_2009.parquet`
- `Data/main_pipeline_duckdb/yearly_employers/yearly_employers_2010.parquet`
- `Data/main_pipeline_duckdb/transitions/employers_2009_2010.parquet`
- `Data/main_pipeline_duckdb/transitions/employers_2009_2010.csv`
- `Data/main_pipeline_duckdb/reports/comparison_2009_2010.json`

## Timing

- 2009 RAIS ingestion: skipped in final run because staging Parquet already existed.
- 2010 RAIS ingestion: skipped in final run because staging Parquet already existed.
- 2009 yearly employer selection: 54.5 seconds.
- 2010 yearly employer selection: 60.7 seconds.
- 2009-2010 transition build: 46.5 seconds.

Initial ingestion from Stata `.dta` to Parquet took about 169 seconds for 2009
and 173 seconds for 2010.

## Parity Summary

The DuckDB shadow pipeline is close but not yet identical to the Stata output.
It contains all workers selected by the Stata yearly files for the 2009 and 2010
test years, plus a small number of extra workers.

| Check | Stata rows | DuckDB rows | Stata-only PIS | DuckDB-only PIS | Different employer IDs among shared PIS |
| --- | ---: | ---: | ---: | ---: | ---: |
| yearly 2009 | 38,088,831 | 38,196,644 | 0 | 107,813 | 9,375 |
| yearly 2010 | 40,641,969 | 40,757,851 | 0 | 115,882 | 13,433 |
| transition 2009-2010 | 30,455,590 | 30,627,893 | 0 | 172,303 | 7,114 origin; 9,345 destination |

Firm employment counts are not yet at parity:

- 2009: 1,918,235 shared workers have different `firm_emp`.
- 2010: 1,976,854 shared workers have different `firm_emp`.

## Interpretation

The current DuckDB implementation uses deterministic hash tie-breakers where the
Stata code uses `runiform()` after `set seed 12345`. Some employer ID
differences are therefore expected among exact ties.

However, the DuckDB-only workers and `firm_emp` differences mean phase 1 has not
yet proven full replacement parity. The next diagnostic should isolate workers
with duplicate active December spells and exact ties in hours, tenure, and hourly
wages. Until those cases are reconciled, the Stata output should remain the
reference output for the main data pipeline.
