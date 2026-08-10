#!/bin/bash
#SBATCH --job-name=post_connectivity
#SBATCH --output=/kellogg/proj/lgg3230/UnionSpill/Programs/logs/post_connectivity_%j.out
#SBATCH --error=/kellogg/proj/lgg3230/UnionSpill/Programs/logs/post_connectivity_%j.err
#SBATCH --time=48:00:00
#SBATCH --mem=64G
#SBATCH --cpus-per-task=4
#SBATCH --partition=kellogg
#SBATCH --account=kellogg

# Post-Treatment Connectivity Analysis (2011-2016)
# This script runs the Stata and MATLAB code to compute connectivity measures

echo "Job started at $(date)"
echo "Running on node: $(hostname)"

# Create logs directory if it doesn't exist
mkdir -p /kellogg/proj/lgg3230/UnionSpill/Programs/logs

# Change to project directory
cd /kellogg/proj/lgg3230/UnionSpill

# Run Stata master file
echo "Starting Stata processing at $(date)"
/software/Stata/stata17/stata-mp -b do Programs/05_yearly_employers_post_master.do

echo "Job completed at $(date)"
