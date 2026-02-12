#!/bin/bash
#SBATCH --job-name=08_bilateral
#SBATCH --account=kellogg
#SBATCH --array=13,28
#SBATCH --partition=kellogg
#SBATCH --time=03:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=500G
#SBATCH --output=/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/bilateral_combined_results/slurm_%A_%a.log
#SBATCH --error=/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/bilateral_combined_results/slurm_%A_%a.err
#
# 08: Run 29 bilateral regressions (gravity + pretreatment) on separate nodes.
#
# Index mapping:
#   0-8:   Gravity univariate (9 proximity)
#   9-12:  Gravity univariate (4 dummies)
#   13:    Gravity multivariate (all 13 vars)
#   14:    Pretreat univariate (early connectivity)
#   15-23: Pretreat univariate (9 proximity)
#   24-27: Pretreat univariate (4 dummies)
#   28:    Pretreat multivariate (all 14 vars)
#
# Usage:
#   sbatch Programs/conn_descriptives/08_submit.sh
#
# Monitor:
#   squeue -u $USER -n 08_bilateral
#
# After completion, merge results:
#   ~/.conda/envs/venv_python312/bin/python Programs/conn_descriptives/08_merge.py

echo "============================================"
echo "SLURM Job ID: $SLURM_JOB_ID"
echo "Array Task ID: $SLURM_ARRAY_TASK_ID"
echo "Node: $(hostname)"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Memory: $SLURM_MEM_PER_NODE MB"
echo "Start: $(date)"
echo "============================================"

mkdir -p /gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/bilateral_combined_results

~/.conda/envs/venv_python312/bin/python \
    /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/conn_descriptives/08_bilateral_worker.py \
    $SLURM_ARRAY_TASK_ID

echo ""
echo "End: $(date)"
echo "============================================"
