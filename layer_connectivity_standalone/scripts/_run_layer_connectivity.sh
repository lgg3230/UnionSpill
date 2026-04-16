#!/usr/bin/env bash
# Run the full layer connectivity pipeline for edu (3-bin) and edu2 (2-bin).
# Logs go to Logs/layer_connectivity/.
set -euo pipefail

PYTHON=~/.conda/envs/venv_python312/bin/python
SCRIPTS=/gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/layer_connectivity
LOGS=/gpfs/kellogg/proj/lgg3230/UnionSpill/Logs/layer_connectivity

mkdir -p "$LOGS"

echo "=== 00: Cache DTA files as parquet (RAIS 2007 2008 + yearly_employers + aux) ===" | tee "$LOGS/00_cache.log"
$PYTHON "$SCRIPTS/00_cache_rais_parquet.py" --years 2007 2008 2>&1 | tee -a "$LOGS/00_cache.log"

echo "=== 01: Build edu transitions (3-bin) ===" | tee "$LOGS/01_edu.log"
$PYTHON "$SCRIPTS/01_build_transitions.py" --layer edu 2>&1 | tee -a "$LOGS/01_edu.log"

echo "=== 01b: Remap edu → edu2 (2-bin) ===" | tee "$LOGS/01b_edu2.log"
$PYTHON "$SCRIPTS/01b_remap_edu2.py" 2>&1 | tee -a "$LOGS/01b_edu2.log"

echo "=== 02: Aggregate edu ===" | tee "$LOGS/02_edu.log"
$PYTHON "$SCRIPTS/02_aggregate.py" --layer edu 2>&1 | tee -a "$LOGS/02_edu.log"

echo "=== 02: Aggregate edu2 ===" | tee "$LOGS/02_edu2.log"
$PYTHON "$SCRIPTS/02_aggregate.py" --layer edu2 2>&1 | tee -a "$LOGS/02_edu2.log"

echo "=== 03: Compute N edu ===" | tee "$LOGS/03_edu.log"
$PYTHON "$SCRIPTS/03_compute_n.py" --layer edu 2>&1 | tee -a "$LOGS/03_edu.log"

echo "=== 03: Compute N edu2 ===" | tee "$LOGS/03_edu2.log"
$PYTHON "$SCRIPTS/03_compute_n.py" --layer edu2 2>&1 | tee -a "$LOGS/03_edu2.log"

source /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/notify.sh
notify "Layer connectivity done" "edu (3-bin) + edu2 (2-bin) complete"
