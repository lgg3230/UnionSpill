#!/usr/bin/env bash
set -euo pipefail

PROJ=/gpfs/kellogg/proj/lgg3230/UnionSpill
PYTHON=/gpfs/home/lgg3230/.conda/envs/venv_python312/bin/python
SCRIPTS=$PROJ/Programs/layer_connectivity
LOGS=$PROJ/Logs/layer_connectivity

mkdir -p "$LOGS"

for layer in gender race; do
    echo "=== 01d: Build ${layer} transitions ===" | tee "$LOGS/01d_${layer}.log"
    $PYTHON "$SCRIPTS/01d_build_demog_transitions.py" --layer "$layer" 2>&1 | tee -a "$LOGS/01d_${layer}.log"

    echo "=== 02d: Aggregate ${layer} ===" | tee "$LOGS/02d_${layer}.log"
    $PYTHON "$SCRIPTS/02d_aggregate_demog.py" --layer "$layer" 2>&1 | tee -a "$LOGS/02d_${layer}.log"

    echo "=== 03d: Compute N ${layer} ===" | tee "$LOGS/03d_${layer}.log"
    $PYTHON "$SCRIPTS/03d_compute_n_demog.py" --layer "$layer" 2>&1 | tee -a "$LOGS/03d_${layer}.log"
done

source "$PROJ/Programs/notify.sh"
notify "Demog layers done" "gender + race complete"
