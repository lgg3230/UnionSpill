#!/bin/bash
#SBATCH --job-name=bilateral_post
#SBATCH --output=/kellogg/proj/lgg3230/UnionSpill/Programs/logs/bilateral_post_%j.out
#SBATCH --error=/kellogg/proj/lgg3230/UnionSpill/Programs/logs/bilateral_post_%j.err
#SBATCH --time=12:00:00
#SBATCH --mem=64G
#SBATCH --cpus-per-task=4
#SBATCH --partition=kellogg
#SBATCH --account=kellogg

# Post-Treatment Bilateral Connectivity Analysis (2011-2016)
# Step 1: Create missing transition matrices (Stata)
# Step 2: Run bilateral connectivity within sample establishments (MATLAB)

echo "Job started at $(date)"
echo "Running on node: $(hostname)"

mkdir -p /kellogg/proj/lgg3230/UnionSpill/Programs/logs

cd /kellogg/proj/lgg3230/UnionSpill

# Step 1: Create missing transition matrices (2011-2012 and 2015-2016)
echo "=== Step 1: Creating missing transition matrices ==="
echo "Started at $(date)"
/software/Stata/stata17/stata-mp -b do Programs/05_fix_employers_2015_2016.do

# Check if Stata completed successfully
if [ -f "Data/RAIS_aux/employers_2011_2012.csv" ] && [ -f "Data/RAIS_aux/employers_2015_2016.csv" ]; then
    echo "Transition matrices created successfully"
else
    echo "ERROR: Missing transition matrix files. Check Stata log."
    exit 1
fi

# Step 2: Run bilateral connectivity MATLAB script
echo "=== Step 2: Running MATLAB bilateral connectivity ==="
echo "Started at $(date)"
/software/matlab/R2020b/bin/matlab -nojvm < Programs/bilateral_connectivity_post.m

echo "=== Job completed at $(date) ==="
