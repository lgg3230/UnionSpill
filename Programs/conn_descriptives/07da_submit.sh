#!/bin/bash
#SBATCH --job-name=07da_pretreat
#SBATCH --account=kellogg
#SBATCH --array=0-13
#SBATCH --partition=kellogg
#SBATCH --time=03:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=180G
#SBATCH --output=/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/pretreat_univariate_results/slurm_%A_%a.log
#SBATCH --error=/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/pretreat_univariate_results/slurm_%A_%a.err
#
# 07da: Distribute univariate pretreatment regressions across cluster nodes.
# Each array task runs ONE regression on a separate node.
#
# Variables (index -> name):
#   0  z_bilateral_conn_early_pre
#   1  z_cep_proximity
#   2  z_turnover_proximity
#   3  z_size_proximity
#   4  z_wage_proximity
#   5  z_female_proximity
#   6  z_nonwhite_proximity
#   7  z_educ_proximity
#   8  z_hs_proximity
#   9  same_microregion
#  10  same_union
#  11  same_industry
#  12  same_industry_micro
#  13  z_clauses_proximity
#
# Usage:
#   sbatch Programs/conn_descriptives/07da_submit.sh
#
# Monitor:
#   squeue -u $USER -n 07da_pretreat
#
# After completion, merge results:
#   ~/.conda/envs/venv_python312/bin/python Programs/conn_descriptives/07da_merge.py

echo "============================================"
echo "SLURM Job ID: $SLURM_JOB_ID"
echo "Array Task ID: $SLURM_ARRAY_TASK_ID"
echo "Node: $(hostname)"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Memory: $SLURM_MEM_PER_NODE MB"
echo "Start: $(date)"
echo "============================================"

# Create output directory
mkdir -p /gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/pretreat_univariate_results

# Run the worker
~/.conda/envs/venv_python312/bin/python \
    /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/conn_descriptives/07da_worker.py \
    $SLURM_ARRAY_TASK_ID

echo ""
echo "End: $(date)"
echo "============================================"
