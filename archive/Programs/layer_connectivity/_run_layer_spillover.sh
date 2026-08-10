#!/usr/bin/env bash
# Run the layer-level spillover analysis pipeline.
#
# PREREQUISITES (run separately if not done):
#   _run_layer_connectivity.sh  — rebuilds firm_layer_connectivity_{edu,edu2}.dta
#                                 with is_mover / totalflows_layer_pw_n (script 01 ~70 min)
#
# This wrapper runs only the fast steps:
#   1. Python: build firm×layer×year outcomes from worker_panel_lagos.parquet
#   2. Stata:  spillover regressions (02_spillover/01a_layer_spillover.do)
#
# Outputs:
#   Tables/layer_connectivity/results_spill_layer_{edu,edu2}_layer_spill.csv
#   Graphs/layer_connectivity/es_*_spill_{edu,edu2}_{date}.pdf
#   Logs/layer_connectivity/layer_spillover_*.log
set -euo pipefail

PYTHON=~/.conda/envs/venv_python312/bin/python
STATA=/software/Stata/stata17/stata-mp
SCRIPTS=/gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/layer_connectivity
LOGS=/gpfs/kellogg/proj/lgg3230/UnionSpill/Logs/layer_connectivity

PROJ=/gpfs/kellogg/proj/lgg3230/UnionSpill
mkdir -p "$LOGS"
mkdir -p "$PROJ/Tables/layer_connectivity"
mkdir -p "$PROJ/Graphs/layer_connectivity"

echo "=== 00: Build firm×layer×year outcomes ===" | tee "$LOGS/00_outcomes.log"
$PYTHON "$SCRIPTS/00_pipeline/06a_prep_layer_outcomes.py" 2>&1 | tee -a "$LOGS/00_outcomes.log"

echo "=== Stata: layer spillover regressions ===" | tee "$LOGS/stata_spillover.log"
$STATA -b do "$SCRIPTS/02_spillover/01a_layer_spillover.do" 2>&1 | tee -a "$LOGS/stata_spillover.log"

source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh
notify "Layer spillover wrapper done" "outcomes + Stata complete"
