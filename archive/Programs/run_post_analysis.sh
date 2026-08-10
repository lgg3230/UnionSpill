#!/bin/bash
#SBATCH --job-name=post_analysis
#SBATCH --output=/kellogg/proj/lgg3230/UnionSpill/Programs/logs/post_analysis_%j.out
#SBATCH --error=/kellogg/proj/lgg3230/UnionSpill/Programs/logs/post_analysis_%j.err
#SBATCH --time=24:00:00
#SBATCH --mem=128G
#SBATCH --cpus-per-task=4
#SBATCH --partition=kellogg
#SBATCH --account=kellogg

# Post-Treatment Connectivity Analysis Pipeline
# 1. Run MATLAB connectivity to treated (establishment-level)
# 2. Run Stata analysis (IV, correlates, first-stage)

echo "Job started at $(date)"
echo "Running on node: $(hostname)"

mkdir -p /kellogg/proj/lgg3230/UnionSpill/Programs/logs

cd /kellogg/proj/lgg3230/UnionSpill

# Step 1: Run MATLAB connectivity to treated
echo "=== Step 1: MATLAB connectivity to treated ==="
echo "Started at $(date)"
/software/matlab/R2020b/bin/matlab -nojvm < Programs/connectivity_treat_lagos_post.m

# Check if output exists
if [ -f "Data/RAIS_aux/connectivity_treat_2011_2016.csv" ]; then
    echo "MATLAB connectivity to treated completed successfully"
else
    echo "ERROR: MATLAB connectivity to treated failed"
    exit 1
fi

# Step 2: Run Stata post-treatment analysis
echo "=== Step 2: Stata post-treatment analysis ==="
echo "Started at $(date)"
/software/Stata/stata17/stata-mp -b do Programs/07_post_connectivity_analysis.do

echo "=== Job completed at $(date) ==="
