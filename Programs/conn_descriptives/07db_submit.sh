#!/bin/bash
#SBATCH --job-name=07db_pretreat_mv
#SBATCH --account=kellogg
#SBATCH --partition=kellogg
#SBATCH --time=03:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=500G
#SBATCH --output=/gpfs/kellogg/proj/lgg3230/UnionSpill/07db_multivariate.log
#SBATCH --error=/gpfs/kellogg/proj/lgg3230/UnionSpill/07db_multivariate.log
#
# 07db: Run multivariate pretreatment regression (single job).
# Re-standardizes dep var and early connectivity over the full sample.
#
# Usage:
#   sbatch Programs/conn_descriptives/07db_submit.sh
#
# Monitor:
#   squeue -u $USER -n 07db_pretreat_mv
#
# After completion, re-plot:
#   ~/.conda/envs/venv_python312/bin/python Programs/conn_descriptives/5110_figure_bilateral_coefplot.py

echo "============================================"
echo "SLURM Job ID: $SLURM_JOB_ID"
echo "Node: $(hostname)"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Memory: $SLURM_MEM_PER_NODE MB"
echo "Start: $(date)"
echo "============================================"

~/.conda/envs/venv_python312/bin/python \
    /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/conn_descriptives/07db_bilateral_pretreatment_multivariate.py

echo ""
echo "End: $(date)"
echo "============================================"
