#!/bin/bash
# _run_worker_wages.sh — Run the full worker_wages pipeline
# Usage: bash Programs/worker_wages/_run_worker_wages.sh

set -e

GIT_ROOT=$(git rev-parse --show-toplevel)
cd "$GIT_ROOT"

mkdir -p Data/worker_wages Logs/worker_wages Tables/worker_wages Graphs/worker_wages

echo "============================================================"
echo "WORKER WAGES PIPELINE"
echo "Started: $(date)"
echo "============================================================"

echo ""
echo "Step 1: Data preparation (Python/DuckDB)"
~/.conda/envs/venv_python312/bin/python Programs/worker_wages/01_prep_data.py

echo ""
echo "Step 2: Regressions (Stata)"
module load stata/17
stata-mp -b do Programs/worker_wages/02_regressions.do

echo ""
echo "============================================================"
echo "PIPELINE COMPLETE: $(date)"
echo "============================================================"

source Programs/notify.sh && notify "worker_wages pipeline done" "all steps complete — $(date)"
