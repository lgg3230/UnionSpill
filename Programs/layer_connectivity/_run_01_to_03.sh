#!/usr/bin/env bash
set -euo pipefail

PROJ=/gpfs/kellogg/proj/lgg3230/UnionSpill
PYTHON=/gpfs/home/lgg3230/.conda/envs/venv_python312/bin/python
SCRIPTS=$PROJ/Programs/layer_connectivity/00_pipeline
LOGS=$PROJ/Logs/layer_connectivity

mkdir -p "$LOGS"

echo "=== 01: Build edu transitions ===" | tee "$LOGS/01_edu.log"
$PYTHON "$SCRIPTS/01a_build_transitions.py" --layer edu 2>&1 | tee -a "$LOGS/01_edu.log"

echo "=== 01b: Remap edu → edu2 ===" | tee "$LOGS/01b_edu2.log"
$PYTHON "$SCRIPTS/01b_remap_edu2.py" 2>&1 | tee -a "$LOGS/01b_edu2.log"

echo "=== 01c: Total flows layer ===" | tee "$LOGS/01c.log"
$PYTHON "$SCRIPTS/01c_totalflows_layer.py" 2>&1 | tee -a "$LOGS/01c.log"

echo "=== 02: Aggregate edu ===" | tee "$LOGS/02_edu.log"
$PYTHON "$SCRIPTS/02a_aggregate.py" --layer edu 2>&1 | tee -a "$LOGS/02_edu.log"

echo "=== 02: Aggregate edu2 ===" | tee "$LOGS/02_edu2.log"
$PYTHON "$SCRIPTS/02a_aggregate.py" --layer edu2 2>&1 | tee -a "$LOGS/02_edu2.log"

echo "=== 03: Compute N edu ===" | tee "$LOGS/03_edu.log"
$PYTHON "$SCRIPTS/03a_compute_n.py" --layer edu 2>&1 | tee -a "$LOGS/03_edu.log"

echo "=== 03: Compute N edu2 ===" | tee "$LOGS/03_edu2.log"
$PYTHON "$SCRIPTS/03a_compute_n.py" --layer edu2 2>&1 | tee -a "$LOGS/03_edu2.log"

source "$PROJ/Programs/notify.sh"
notify "Layer connectivity done" "01–03 complete (edu + edu2)"
