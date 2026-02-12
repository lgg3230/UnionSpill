#!/bin/bash
#SBATCH --job-name=07e_fe_v2
#SBATCH --account=kellogg
#SBATCH --array=0-2
#SBATCH --partition=kellogg
#SBATCH --time=03:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=180G
#SBATCH --output=/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/fe_tests_v2/slurm_%A_%a.log
#SBATCH --error=/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/fe_tests_v2/slurm_%A_%a.err
#
# 07e v2: FE tests with correct standardization (float64, 271M-sample z-scores)
#
# Array tasks:
#   0 = no FE
#   1 = two-way FE (identificad_i + identificad_j)
#   2 = one-way FE (identificad_i)
#
# Usage:
#   sbatch Programs/07e_submit_v2.sh
#
# Monitor:
#   squeue -u $USER -n 07e_fe_v2
#
# After completion, merge results:
#   ~/.conda/envs/venv_python312/bin/python Programs/07e_merge_v2.py

echo "============================================"
echo "SLURM Job ID: $SLURM_JOB_ID"
echo "Array Task ID: $SLURM_ARRAY_TASK_ID"
echo "Node: $(hostname)"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Memory: $SLURM_MEM_PER_NODE MB"
echo "Start: $(date)"
echo "============================================"

mkdir -p /gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/fe_tests_v2

~/.conda/envs/venv_python312/bin/python \
    /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/07e_bilateral_fe_tests_v2.py \
    $SLURM_ARRAY_TASK_ID

echo ""
echo "End: $(date)"
echo "============================================"
