#!/usr/bin/env bash
set -euo pipefail

cd /kellogg/proj/lgg3230/UnionSpill

PY=python3.8

$PY Programs/main_data_pipeline_duckdb/10_ingest_rais_to_parquet.py --years 2009 2010
$PY Programs/main_data_pipeline_duckdb/20_select_yearly_employers_duckdb.py --years 2009 2010
$PY Programs/main_data_pipeline_duckdb/30_build_transitions_duckdb.py --start-years 2009
$PY Programs/main_data_pipeline_duckdb/90_compare_employer_selection.py --years 2009 2010 --transition-start 2009
