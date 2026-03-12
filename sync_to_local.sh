#!/usr/bin/env bash
# sync_to_local.sh
# Download UnionSpill data files from Kellogg cluster to local machine.
# Run this from your LOCAL computer (Mac), not from the cluster.
#
# Usage:
#   bash sync_to_local.sh             # essential files only (~380 MB)
#   bash sync_to_local.sh --full      # include large RAIS files (~11 GB extra)

set -euo pipefail

# ── CONFIGURE THESE ──────────────────────────────────────────────────────────
REMOTE_USER="lgg3230"
REMOTE_HOST="kellogg.northwestern.edu"
REMOTE_ROOT="/kellogg/proj/lgg3230/UnionSpill"
REMOTE_RAIS="/kellogg/proj/lgg3230/RAIS/output/data/full"

LOCAL_ROOT="/Users/luisg/Library/CloudStorage/OneDrive-NorthwesternUniversity/4 - PhD/02_Research/Org_Econ BR/UnionSpillovers/Cluster/UnionSpill"
# ─────────────────────────────────────────────────────────────────────────────

FULL=false
if [[ "${1:-}" == "--full" ]]; then
    FULL=true
fi

SRC="${REMOTE_USER}@${REMOTE_HOST}"

rsync_file() {
    local remote_path="$1"
    local local_path="$2"
    mkdir -p "$(dirname "$local_path")"
    echo "  -> $(basename "$remote_path")"
    rsync -avz --progress "${SRC}:${remote_path}" "${local_path}"
}

rsync_dir() {
    local remote_dir="$1"
    local local_dir="$2"
    mkdir -p "$local_dir"
    echo "  -> $(basename "$remote_dir")/"
    rsync -avz --progress "${SRC}:${remote_dir}/" "${local_dir}/"
}

echo "============================================================"
echo " SECTION 1: Stata regression inputs (~220 MB)"
echo "============================================================"

rsync_file "$REMOTE_ROOT/Data/layer_connectivity/firm_layer_outcomes_edu.dta" \
           "$LOCAL_ROOT/Data/layer_connectivity/firm_layer_outcomes_edu.dta"

rsync_file "$REMOTE_ROOT/Data/layer_connectivity/firm_layer_outcomes_edu2.dta" \
           "$LOCAL_ROOT/Data/layer_connectivity/firm_layer_outcomes_edu2.dta"

rsync_file "$REMOTE_ROOT/Data/layer_connectivity/final_measures/firm_layer_connectivity_edu2.dta" \
           "$LOCAL_ROOT/Data/layer_connectivity/final_measures/firm_layer_connectivity_edu2.dta"

rsync_file "$REMOTE_ROOT/Data/CBA_RAIS_firm_level/lagos_sample_sep24_pct_unionexp_ext_df2.dta" \
           "$LOCAL_ROOT/Data/CBA_RAIS_firm_level/lagos_sample_sep24_pct_unionexp_ext_df2.dta"

rsync_file "$REMOTE_ROOT/Data/RAIS_aux/totalflows_wide_2007_2011.csv" \
           "$LOCAL_ROOT/Data/RAIS_aux/totalflows_wide_2007_2011.csv"

echo ""
echo "============================================================"
echo " SECTION 2: Transitions parquets (~160 MB)"
echo " (needed to re-run Python scripts 02-06)"
echo "============================================================"

rsync_dir "$REMOTE_ROOT/Data/layer_connectivity/transitions_base" \
          "$LOCAL_ROOT/Data/layer_connectivity/transitions_base"

echo ""
echo "============================================================"
echo " SECTION 3: All other layer_connectivity intermediates (~35 MB)"
echo " (connectivity_components, final_measures, outcomes)"
echo "============================================================"

rsync_dir "$REMOTE_ROOT/Data/layer_connectivity/connectivity_components" \
          "$LOCAL_ROOT/Data/layer_connectivity/connectivity_components"

rsync_dir "$REMOTE_ROOT/Data/layer_connectivity/final_measures" \
          "$LOCAL_ROOT/Data/layer_connectivity/final_measures"

rsync_file "$REMOTE_ROOT/Data/layer_connectivity/firm_layer_outcomes_edu.parquet" \
           "$LOCAL_ROOT/Data/layer_connectivity/firm_layer_outcomes_edu.parquet"

rsync_file "$REMOTE_ROOT/Data/layer_connectivity/firm_layer_outcomes_edu2.parquet" \
           "$LOCAL_ROOT/Data/layer_connectivity/firm_layer_outcomes_edu2.parquet"

echo ""
echo "============================================================"
echo " SECTION 4: RAIS aux small files"
echo "============================================================"

rsync_file "$REMOTE_ROOT/Data/RAIS_aux/lagos_treat.csv" \
           "$LOCAL_ROOT/Data/RAIS_aux/lagos_treat.csv"

rsync_file "$REMOTE_ROOT/Data/RAIS_aux/lagos_control.csv" \
           "$LOCAL_ROOT/Data/RAIS_aux/lagos_control.csv"

rsync_file "$REMOTE_ROOT/Data/RAIS_aux/connectivity_treat_2007_2011_agg.parquet" \
           "$LOCAL_ROOT/Data/RAIS_aux/connectivity_treat_2007_2011_agg.parquet"

if $FULL; then
    echo ""
    echo "============================================================"
    echo " SECTION 5 (--full): Large RAIS files (~11 GB)"
    echo " (only needed to re-run script 01 from scratch)"
    echo "============================================================"

    rsync_file "$REMOTE_RAIS/RAIS_2007.parquet" \
               "$LOCAL_ROOT/Data/RAIS_raw/RAIS_2007.parquet"

    rsync_file "$REMOTE_RAIS/RAIS_2008.parquet" \
               "$LOCAL_ROOT/Data/RAIS_raw/RAIS_2008.parquet"

    echo ""
    echo "============================================================"
    echo " SECTION 6 (--full): yearly_employers parquets (~2.7 GB)"
    echo "============================================================"

    for year in 2007 2008 2009 2010 2011; do
        rsync_file "$REMOTE_ROOT/Data/RAIS_aux/yearly_employers_${year}.parquet" \
                   "$LOCAL_ROOT/Data/RAIS_aux/yearly_employers_${year}.parquet"
    done

    echo ""
    echo "============================================================"
    echo " SECTION 7 (--full): worker_panel_lagos.parquet (~1.2 GB)"
    echo "============================================================"

    rsync_file "$REMOTE_ROOT/Data/CBA_RAIS_firm_level/worker_panel_lagos.parquet" \
               "$LOCAL_ROOT/Data/CBA_RAIS_firm_level/worker_panel_lagos.parquet"

    echo ""
    echo "Full download complete (~11.5 GB total)."
else
    echo ""
    echo "Essential download complete (~380 MB)."
    echo "To also download large RAIS files (~11 GB extra), run:"
    echo "  bash sync_to_local.sh --full"
fi
