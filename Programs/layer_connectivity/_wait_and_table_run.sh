#!/bin/bash
# Wait for all layer spillover Stata jobs to finish, then run table generators.

PROJ="/kellogg/proj/lgg3230/UnionSpill"
PYTHON="$HOME/.conda/envs/venv_python312/bin/python"
NOTIFY="$PROJ/Programs/notify.sh"

PID_07=3206212
PID_SIZE=3206213
PID_SIZE100=3206214
PID_SIZE_FULL=3206215
PID_FIRMRESTR=3206216
PID_CROSS=3206218

log() { echo "$(date '+%Y-%m-%d %H:%M:%S')  $*"; }

wait_pid() {
    local pid=$1 label=$2
    while kill -0 "$pid" 2>/dev/null; do
        sleep 30
    done
    log "Finished: $label (PID $pid)"
}

log "Waiting for 02_spillover/01a_layer_spillover.do..."
wait_pid $PID_07 "07_layer_spillover"

log "Waiting for 07_layer_spillover_size.do..."
wait_pid $PID_SIZE "07_layer_spillover_size"

log "Waiting for 07_layer_spillover_size100.do..."
wait_pid $PID_SIZE100 "07_layer_spillover_size100"

log "Waiting for 07_layer_spillover_size_full.do..."
wait_pid $PID_SIZE_FULL "07_layer_spillover_size_full"

log "Waiting for _firmrestr_standalone.do..."
wait_pid $PID_FIRMRESTR "_firmrestr_standalone"

log "All 07_* jobs done. Running table generators..."
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

log "Waiting for 01_cross_layer.do..."
wait_pid $PID_CROSS "10_cross_layer_spillover"

log "Cross-layer done. Running 02_make_table.py..."
$PYTHON Programs/layer_connectivity/02_make_table.py \
    && log "10 done." || log "ERROR: 02_make_table.py failed"

source "$NOTIFY" && notify "All layer tables done" "cross-layer table regenerated — all jobs complete"

log "All done."
