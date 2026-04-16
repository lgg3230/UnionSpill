#!/bin/bash
# Wait for all layer spillover Stata jobs to finish, then run table generators.

PROJ="/kellogg/proj/lgg3230/UnionSpill"
PYTHON="$HOME/.conda/envs/venv_python312/bin/python"
NOTIFY="$PROJ/Programs/notify.sh"

PIDS_07=(2670703 2671529 2672093 2672598)
PID_CROSS=2661477

log() { echo "$(date '+%Y-%m-%d %H:%M:%S')  $*"; }

wait_pid() {
    local pid=$1 label=$2
    while kill -0 "$pid" 2>/dev/null; do
        sleep 30
    done
    log "Finished: $label (PID $pid)"
}

# ── Wait for the four 07_* jobs ───────────────────────────────────────────────
log "Waiting for 07_layer_spillover.do (PID 2670703)..."
wait_pid 2670703 "07_layer_spillover"

log "Waiting for 07_layer_spillover_size.do (PID 2671529)..."
wait_pid 2671529 "07_layer_spillover_size"

log "Waiting for 07_layer_spillover_size100.do (PID 2672093)..."
wait_pid 2672093 "07_layer_spillover_size100"

log "Waiting for 07_layer_spillover_size_full.do (PID 2672598)..."
wait_pid 2672598 "07_layer_spillover_size_full"

log "All 07_* jobs done. Running table generators..."

# ── Table generators for 07_* outputs ────────────────────────────────────────
cd "$PROJ"

log "Running 08_make_table_layer_specs.py..."
$PYTHON Programs/layer_connectivity/08_make_table_layer_specs.py \
    && log "08 done." || log "ERROR: 08_make_table_layer_specs.py failed"

log "Running 09_make_table_size_specs.py..."
$PYTHON Programs/layer_connectivity/09_make_table_size_specs.py \
    && log "09 done." || log "ERROR: 09_make_table_size_specs.py failed"

log "Running 09b_make_table_size100_specs.py..."
$PYTHON Programs/layer_connectivity/09b_make_table_size100_specs.py \
    && log "09b done." || log "ERROR: 09b_make_table_size100_specs.py failed"

log "Running 09_make_table_size_full.py..."
$PYTHON Programs/layer_connectivity/09_make_table_size_full.py \
    && log "09_full done." || log "ERROR: 09_make_table_size_full.py failed"

source "$NOTIFY" && notify "07 tables done" "layer specs, size, size100, size_full tables regenerated"

# ── Wait for cross-layer job ──────────────────────────────────────────────────
log "Waiting for 10_cross_layer_spillover.do (PID $PID_CROSS)..."
wait_pid $PID_CROSS "10_cross_layer_spillover"

log "Cross-layer done. Running 10_make_table_cross_layer.py..."
$PYTHON Programs/layer_connectivity/10_make_table_cross_layer.py \
    && log "10 done." || log "ERROR: 10_make_table_cross_layer.py failed"

source "$NOTIFY" && notify "All layer tables done" "cross-layer table regenerated — all jobs complete"

log "All done."
