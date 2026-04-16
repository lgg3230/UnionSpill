# DuckDB Shadow Pipeline

This folder contains a parallel, non-destructive prototype for the expensive
worker-employer selection stage in `Programs/main_data_pipeline/50_05_yearly_employers.do`.

It writes to:

`Data/main_pipeline_duckdb/`

and does not overwrite Stata pipeline outputs.

## Phase 1 Target

Test whether the DuckDB implementation selects the same yearly employer records
and adjacent-year employer transitions as the current Stata output.

Initial test pair:

- yearly employer selection: 2009 and 2010
- transition file: 2009-2010

## Scripts

- `00_config.py`: paths and common constants.
- `10_ingest_rais_to_parquet.py`: reads selected RAIS columns from `.dta` and writes Parquet.
- `20_select_yearly_employers_duckdb.py`: performs the Stata-like worker-employer selection in DuckDB.
- `30_build_transitions_duckdb.py`: joins selected yearly employers into adjacent-year transitions.
- `90_compare_employer_selection.py`: compares DuckDB outputs to existing Stata outputs.
- `run_phase1_2009_2010.sh`: runs the first 2009-2010 shadow test.
- `PHASE1_RESULTS.md`: records the first parity run and current mismatch counts.

## Tie-Breaking Note

The Stata code uses `runiform()` with `set seed 12345` to break exact ties. This
prototype uses deterministic DuckDB hashes as tie-breakers. If mismatches are
concentrated among exact ties, the remaining gap is likely tie-breaking rather
than core selection logic.
