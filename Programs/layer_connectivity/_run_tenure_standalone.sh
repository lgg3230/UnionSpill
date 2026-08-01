#!/usr/bin/env bash
# Self-contained tenure layer pipeline.
#
# Rebuilds the ten2 layer connectivity measure and the tenure within-firm
# exhibits used by the paper/replication outputs. The hourly outcome is computed
# in 06z_prep_outcomes_unified.py as:
#   log((remdezr / (horascontr * 4.348)) / IPCA_year)
#
# Set SKIP_CONNECTIVITY=1 to reuse an existing ten2 connectivity cache and
# rerun only outcomes, estimates, and fragments.
#
# Outputs:
#   Data/layer_connectivity/final_measures/firm_layer_connectivity_ten2.{dta,parquet}
#   Data/layer_connectivity/firm_layer_outcomes_ten2.{dta,parquet}
#   Tables/layer_connectivity/07_within_firm/a{6,7,8}*_ten2*.csv
#   quality_reports/replication/hourly_variant_currentconn/frag/t_groupspecs_tenure*.tex

set -euo pipefail

PROJ=/gpfs/kellogg/proj/lgg3230/UnionSpill
PYTHON=/gpfs/home/lgg3230/.conda/envs/venv_python312/bin/python
STATA=/software/Stata/stata17/stata-mp
SCRIPTS=$PROJ/Programs/layer_connectivity/00_pipeline
WF=$PROJ/Programs/layer_connectivity/07_within_firm
LOGS=$PROJ/Logs/layer_connectivity/tenure_standalone
FRAG=$PROJ/quality_reports/replication/hourly_variant_currentconn/frag

mkdir -p "$LOGS" "$FRAG"

run_py() {
    local label=$1
    shift
    echo "=== ${label} ===" | tee "$LOGS/${label}.log"
    "$PYTHON" -u "$@" 2>&1 | tee -a "$LOGS/${label}.log"
}

run_stata() {
    local label=$1
    local dofile=$2
    echo "=== ${label} ===" | tee "$LOGS/${label}.log"
    "$STATA" -b do "$dofile"
    cat "${dofile%.do}.log" >> "$LOGS/${label}.log" 2>/dev/null || true
}

if [[ "${SKIP_CONNECTIVITY:-0}" != "1" ]]; then
    run_py "01_ten2_transitions" "$SCRIPTS/01a_build_transitions.py" --layer ten2
    run_py "02_ten2_aggregate" "$SCRIPTS/02a_aggregate.py" --layer ten2
    run_py "03_ten2_compute_n" "$SCRIPTS/03a_compute_n.py" --layer ten2
else
    test -f "$PROJ/Data/layer_connectivity/final_measures/firm_layer_connectivity_ten2.dta"
    echo "=== skipping ten2 connectivity rebuild; using existing final_measures cache ===" \
        | tee "$LOGS/00_skip_connectivity.log"
fi
run_py "06_ten2_corrected_outcomes" "$SCRIPTS/06z_prep_outcomes_unified.py" --layer ten2

run_stata "07_tenure_within_firm" "$WF/_run_tenure.do"
run_stata "07_tenure_within_firm_hw" "$WF/_run_tenure_hw.do"

run_py "08_tenure_fragments" "$WF/02_make_tables.py" \
    --partitions ten2 \
    --monthly-csv "$PROJ/Tables/layer_connectivity/07_within_firm/a7_ten2.csv" \
    --hourly-csv "$PROJ/Tables/layer_connectivity/07_within_firm/a7_hw_ten2.csv" \
    --monthly-out "$FRAG/t_groupspecs_tenure.tex" \
    --hourly-out "$FRAG/t_groupspecs_tenure_hw.tex"

echo "Tenure standalone pipeline complete."
