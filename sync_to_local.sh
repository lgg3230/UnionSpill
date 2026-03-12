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
START_TIME=$(date +%s)

# ── Colors ───────────────────────────────────────────────────────────────────
BOLD="\033[1m"
GREEN="\033[1;32m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
GRAY="\033[0;37m"
RESET="\033[0m"

# ── File list (label, remote_path, local_path, size) ─────────────────────────
declare -a FILE_LABELS FILE_REMOTE FILE_LOCAL FILE_SIZES

add_file() {
    FILE_LABELS+=("$1")
    FILE_REMOTE+=("$2")
    FILE_LOCAL+=("$3")
    FILE_SIZES+=("$4")
}

add_dir() {
    FILE_LABELS+=("$1  [dir]")
    FILE_REMOTE+=("$2/")
    FILE_LOCAL+=("$3/")
    FILE_SIZES+=("$4")
}

# Section 1 — Stata regression inputs
add_file "firm_layer_outcomes_edu.dta"                  "$REMOTE_ROOT/Data/layer_connectivity/firm_layer_outcomes_edu.dta"                          "$LOCAL_ROOT/Data/layer_connectivity/firm_layer_outcomes_edu.dta"                          "17 MB"
add_file "firm_layer_outcomes_edu2.dta"                 "$REMOTE_ROOT/Data/layer_connectivity/firm_layer_outcomes_edu2.dta"                         "$LOCAL_ROOT/Data/layer_connectivity/firm_layer_outcomes_edu2.dta"                         "11 MB"
add_file "firm_layer_connectivity_edu2.dta"             "$REMOTE_ROOT/Data/layer_connectivity/final_measures/firm_layer_connectivity_edu2.dta"       "$LOCAL_ROOT/Data/layer_connectivity/final_measures/firm_layer_connectivity_edu2.dta"       " 6 MB"
add_file "lagos_sample_sep24_pct_unionexp_ext_df2.dta"  "$REMOTE_ROOT/Data/CBA_RAIS_firm_level/lagos_sample_sep24_pct_unionexp_ext_df2.dta"          "$LOCAL_ROOT/Data/CBA_RAIS_firm_level/lagos_sample_sep24_pct_unionexp_ext_df2.dta"          "186 MB"
add_file "totalflows_wide_2007_2011.csv"                "$REMOTE_ROOT/Data/RAIS_aux/totalflows_wide_2007_2011.csv"                                   "$LOCAL_ROOT/Data/RAIS_aux/totalflows_wide_2007_2011.csv"                                   " 1 MB"

# Section 2 — Transitions
add_dir  "transitions_base/"                            "$REMOTE_ROOT/Data/layer_connectivity/transitions_base"                                      "$LOCAL_ROOT/Data/layer_connectivity/transitions_base"                                      "160 MB"

# Section 3 — Other intermediates
add_dir  "connectivity_components/"                     "$REMOTE_ROOT/Data/layer_connectivity/connectivity_components"                               "$LOCAL_ROOT/Data/layer_connectivity/connectivity_components"                               "~10 MB"
add_dir  "final_measures/"                              "$REMOTE_ROOT/Data/layer_connectivity/final_measures"                                        "$LOCAL_ROOT/Data/layer_connectivity/final_measures"                                        "~33 MB"
add_file "firm_layer_outcomes_edu.parquet"              "$REMOTE_ROOT/Data/layer_connectivity/firm_layer_outcomes_edu.parquet"                       "$LOCAL_ROOT/Data/layer_connectivity/firm_layer_outcomes_edu.parquet"                       " 7 MB"
add_file "firm_layer_outcomes_edu2.parquet"             "$REMOTE_ROOT/Data/layer_connectivity/firm_layer_outcomes_edu2.parquet"                      "$LOCAL_ROOT/Data/layer_connectivity/firm_layer_outcomes_edu2.parquet"                      " 5 MB"

# Section 4 — RAIS aux small files
add_file "lagos_treat.csv"                              "$REMOTE_ROOT/Data/RAIS_aux/lagos_treat.csv"                                                 "$LOCAL_ROOT/Data/RAIS_aux/lagos_treat.csv"                                                 "<1 MB"
add_file "lagos_control.csv"                            "$REMOTE_ROOT/Data/RAIS_aux/lagos_control.csv"                                               "$LOCAL_ROOT/Data/RAIS_aux/lagos_control.csv"                                               "<1 MB"
add_file "connectivity_treat_2007_2011_agg.parquet"     "$REMOTE_ROOT/Data/RAIS_aux/connectivity_treat_2007_2011_agg.parquet"                        "$LOCAL_ROOT/Data/RAIS_aux/connectivity_treat_2007_2011_agg.parquet"                        "<1 MB"

ESSENTIAL_COUNT=${#FILE_LABELS[@]}

if $FULL; then
    add_file "RAIS_2007.parquet"                        "$REMOTE_RAIS/RAIS_2007.parquet"                                                             "$LOCAL_ROOT/Data/RAIS_raw/RAIS_2007.parquet"                                               "3.3 GB"
    add_file "RAIS_2008.parquet"                        "$REMOTE_RAIS/RAIS_2008.parquet"                                                             "$LOCAL_ROOT/Data/RAIS_raw/RAIS_2008.parquet"                                               "3.6 GB"
    for year in 2007 2008 2009 2010 2011; do
        add_file "yearly_employers_${year}.parquet"     "$REMOTE_ROOT/Data/RAIS_aux/yearly_employers_${year}.parquet"                                "$LOCAL_ROOT/Data/RAIS_aux/yearly_employers_${year}.parquet"                                "~500 MB"
    done
    add_file "worker_panel_lagos.parquet"               "$REMOTE_ROOT/Data/CBA_RAIS_firm_level/worker_panel_lagos.parquet"                           "$LOCAL_ROOT/Data/CBA_RAIS_firm_level/worker_panel_lagos.parquet"                           "1.2 GB"
fi

TOTAL=${#FILE_LABELS[@]}

# ── Header ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║         UnionSpill — Cluster → Local Sync                    ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo -e "  Remote : ${CYAN}${SRC}${RESET}"
echo -e "  Local  : ${CYAN}${LOCAL_ROOT}${RESET}"
if $FULL; then
    echo -e "  Mode   : ${YELLOW}FULL (~11.5 GB)${RESET}"
else
    echo -e "  Mode   : essential (~380 MB)  ${GRAY}[run with --full for large RAIS files]${RESET}"
fi
echo -e "  Files  : ${TOTAL}"
echo ""

# ── Section labels by index ───────────────────────────────────────────────────
section_label() {
    local i=$1
    if   [[ $i -lt 5 ]];               then echo "Stata regression inputs"
    elif [[ $i -lt 6 ]];               then echo "Transitions parquets"
    elif [[ $i -lt 10 ]];              then echo "Layer connectivity intermediates"
    elif [[ $i -lt 13 ]];              then echo "RAIS aux (small files)"
    elif [[ $i -lt 15 ]];              then echo "Large RAIS parquets (--full)"
    elif [[ $i -lt 20 ]];              then echo "yearly_employers parquets (--full)"
    else                                    echo "worker_panel_lagos (--full)"
    fi
}

CURRENT_SECTION=""

# ── Download loop ─────────────────────────────────────────────────────────────
for i in "${!FILE_LABELS[@]}"; do
    label="${FILE_LABELS[$i]}"
    remote="${FILE_REMOTE[$i]}"
    local="${FILE_LOCAL[$i]}"
    size="${FILE_SIZES[$i]}"

    # Print section header when section changes
    sec=$(section_label $i)
    if [[ "$sec" != "$CURRENT_SECTION" ]]; then
        CURRENT_SECTION="$sec"
        echo ""
        echo -e "${BOLD}── ${sec} ──────────────────────────────────────────${RESET}"
    fi

    # File counter + label
    num=$((i + 1))
    echo -e "  ${GRAY}[${num}/${TOTAL}]${RESET} ${BOLD}${label}${RESET} ${GRAY}(${size})${RESET}"

    # Create local dir
    if [[ "$local" == */ ]]; then
        mkdir -p "$local"
        rsync -az --progress "${SRC}:${remote}" "${local}"
    else
        mkdir -p "$(dirname "$local")"
        rsync -az --progress "${SRC}:${remote}" "${local}"
    fi

    echo -e "  ${GREEN}✓ done${RESET}"
done

# ── Summary ───────────────────────────────────────────────────────────────────
END_TIME=$(date +%s)
ELAPSED=$(( END_TIME - START_TIME ))
MINS=$(( ELAPSED / 60 ))
SECS=$(( ELAPSED % 60 ))

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║  ${GREEN}All done!${RESET}${BOLD}  ${TOTAL} files  |  elapsed: ${MINS}m ${SECS}s$(printf '%*s' $((28 - ${#TOTAL} - ${#MINS} - ${#SECS})) '')║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo ""

if ! $FULL; then
    echo -e "${GRAY}To also download large RAIS files (~11 GB extra):${RESET}"
    echo -e "${GRAY}  bash sync_to_local.sh --full${RESET}"
    echo ""
fi
