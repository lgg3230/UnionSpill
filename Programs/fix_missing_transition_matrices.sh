#!/bin/bash
#SBATCH --job-name=fix_employers
#SBATCH --output=/kellogg/proj/lgg3230/UnionSpill/Programs/logs/fix_employers_%j.out
#SBATCH --error=/kellogg/proj/lgg3230/UnionSpill/Programs/logs/fix_employers_%j.err
#SBATCH --time=01:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=4
#SBATCH --partition=kellogg
#SBATCH --account=kellogg

# Fix missing employers_2015_2016 transition matrix

echo "Job started at $(date)"
echo "Running on node: $(hostname)"

mkdir -p /kellogg/proj/lgg3230/UnionSpill/Programs/logs

cd /kellogg/proj/lgg3230/UnionSpill

# Run fix script
/software/Stata/stata17/stata-mp -b do Programs/05_fix_employers_2015_2016.do

echo "Job completed at $(date)"
