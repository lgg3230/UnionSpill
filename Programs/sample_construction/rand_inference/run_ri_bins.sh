#!/bin/bash
#SBATCH --job-name=ri_bins
#SBATCH --output=/kellogg/proj/lgg3230/UnionSpill/Programs/logs/ri_bins_%j.out
#SBATCH --error=/kellogg/proj/lgg3230/UnionSpill/Programs/logs/ri_bins_%j.err
#SBATCH --time=12:00:00
#SBATCH --mem=64G
#SBATCH --cpus-per-task=4
#SBATCH --partition=kellogg
#SBATCH --account=kellogg

# Randomization inference within industry x negotiation-month cells split by
# pre-treatment size / wage bins (Referee 3). Run from the project root:
#   sbatch Programs/sample_construction/rand_inference/run_ri_bins.sh
# Set REBUILD_FRAME=1 to rerun 2091 first (spill_frame.dta, firm_keys_2009_ext.csv),
# e.g. when 2108 reports check 1 FAIL.
# Steps: [2091] -> 2107 bins -> 2108 mu + checks -> 4153 recentered ES + table
#        -> 2093 permutation p-values (spillover + direct) -> 2109 table

set -euo pipefail
ROOT=/kellogg/proj/lgg3230/UnionSpill
PY=~/.conda/envs/venv_python312/bin/python
STATA=/software/Stata/stata17/stata-mp
RI=Programs/sample_construction/rand_inference
SCHEMES="ind_month ind_month_size4 ind_month_size10 ind_month_size20 ind_month_wage4 ind_month_wage10 ind_month_wage20"
export UNIONSPILL_PYTHON=$PY
mkdir -p $ROOT/Programs/logs $ROOT/Logs/rand_inference $ROOT/Tables/rand_inference
cd $ROOT
echo "Job started at $(date) on $(hostname)"

if [ "${REBUILD_FRAME:-0}" = "1" ]; then
    echo "=== 2091 regression frame ==="; $STATA -b do $RI/2091_export_regression_frame.do
fi

echo "=== 2107 bin keys ==="
$STATA -b do $RI/2107_export_bin_keys.do
grep -q "Exported firm_bins_pre.csv" 2107_export_bin_keys.log || { echo "2107 failed"; tail -30 2107_export_bin_keys.log; exit 1; }

echo "=== 2108 expected exposure (bins) ==="
$PY $RI/2108_expected_exposure_bins.py

echo "=== 4153 recentered event studies + table ==="
$STATA -b do Programs/analysis/rand_inference/4153_recentered_bins.do
grep -q "Table written" 4153_recentered_bins.log || { echo "4153 failed"; tail -30 4153_recentered_bins.log; exit 1; }

echo "=== 2093 permutation engine ==="
for s in $SCHEMES; do
    $PY $RI/2093_permutation_engine.py --mode spillover --coarseness $s
    $PY $RI/2093_permutation_engine.py --mode direct    --coarseness $s
done

echo "=== 2109 permutation table ==="
$PY $RI/2109_perm_bins_table.py

mv -f 2107_export_bin_keys.log 4153_recentered_bins.log $ROOT/Logs/rand_inference/ 2>/dev/null || true
echo "=== Job completed at $(date) ==="
source $ROOT/Programs/notify.sh && notify "RI bins done" "run_ri_bins.sh" || true
