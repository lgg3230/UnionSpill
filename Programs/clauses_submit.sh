#!/bin/bash
#
# Submit all 4 regression jobs to run in parallel after adding z_clauses_proximity.
#
# Prerequisites: Run add_clauses_to_parquet.py first to add clauses to both parquets.
#
# Usage:
#   bash Programs/clauses_submit.sh
#
# Monitor:
#   squeue -u $USER

set -e

PROJ="/gpfs/kellogg/proj/lgg3230/UnionSpill"
PYTHON="$HOME/.conda/envs/venv_python312/bin/python"
LOG_DIR="$PROJ"

echo "============================================"
echo "Submitting 4 clauses regression jobs"
echo "============================================"

# Job 1: Gravity multivariate (06b) - reruns full multivariate with clauses
JOB1=$(sbatch --parsable \
    --job-name=06b_gravity_mv \
    --account=kellogg \
    --partition=kellogg \
    --time=03:00:00 \
    --nodes=1 --ntasks=1 \
    --cpus-per-task=16 \
    --mem=500G \
    --output="${LOG_DIR}/06b_gravity_multivariate.log" \
    --error="${LOG_DIR}/06b_gravity_multivariate.log" \
    --wrap="${PYTHON} ${PROJ}/Programs/06b_bilateral_regression_multivariate.py")
echo "Job 1 (06b gravity multivariate): $JOB1"

# Job 2: Gravity univariate for clauses only
JOB2=$(sbatch --parsable \
    --job-name=06a_clauses_uv \
    --account=kellogg \
    --partition=kellogg \
    --time=03:00:00 \
    --nodes=1 --ntasks=1 \
    --cpus-per-task=8 \
    --mem=180G \
    --output="${LOG_DIR}/06a_clauses_univariate.log" \
    --error="${LOG_DIR}/06a_clauses_univariate.log" \
    --wrap="${PYTHON} ${PROJ}/Programs/clauses_univariate_gravity.py")
echo "Job 2 (clauses univariate gravity): $JOB2"

# Job 3: Pretreat multivariate (07db) - reruns full multivariate with clauses
JOB3=$(sbatch --parsable \
    --job-name=07db_pretreat_mv \
    --account=kellogg \
    --partition=kellogg \
    --time=03:00:00 \
    --nodes=1 --ntasks=1 \
    --cpus-per-task=16 \
    --mem=500G \
    --output="${LOG_DIR}/07db_multivariate.log" \
    --error="${LOG_DIR}/07db_multivariate.log" \
    --wrap="${PYTHON} ${PROJ}/Programs/07db_bilateral_pretreatment_multivariate.py")
echo "Job 3 (07db pretreat multivariate): $JOB3"

# Job 4: Pretreat univariate for clauses only (index 13)
mkdir -p "${PROJ}/Data/RAIS_aux/pretreat_univariate_results"
JOB4=$(sbatch --parsable \
    --job-name=07da_clauses \
    --account=kellogg \
    --partition=kellogg \
    --time=03:00:00 \
    --nodes=1 --ntasks=1 \
    --cpus-per-task=8 \
    --mem=180G \
    --output="${PROJ}/Data/RAIS_aux/pretreat_univariate_results/slurm_clauses.log" \
    --error="${PROJ}/Data/RAIS_aux/pretreat_univariate_results/slurm_clauses.err" \
    --wrap="${PYTHON} ${PROJ}/Programs/07da_worker.py 13")
echo "Job 4 (07da pretreat univariate clauses): $JOB4"

echo ""
echo "============================================"
echo "All 4 jobs submitted. Monitor with: squeue -u \$USER"
echo ""
echo "After all jobs complete:"
echo "  1. Merge pretreat univariate results:"
echo "     ${PYTHON} Programs/07da_merge.py"
echo "  2. Regenerate combined coefplot:"
echo "     ${PYTHON} Programs/06_bilateral_coefplot_combined.py"
echo "============================================"
