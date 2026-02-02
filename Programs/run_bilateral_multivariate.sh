#!/bin/bash
#SBATCH --job-name=bilateral_multi
#SBATCH --output=/gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/logs/bilateral_multi_%j.out
#SBATCH --error=/gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/logs/bilateral_multi_%j.err
#SBATCH --time=08:00:00
#SBATCH --mem=64G
#SBATCH --cpus-per-task=4
#SBATCH --partition=kellogg
#SBATCH --account=kellogg

# ==============================================================================
# Bilateral Connectivity Multivariate Regressions Pipeline
# ==============================================================================
# This script runs multivariate regressions for:
# 1. Pre-treatment bilateral connectivity (2007-2011)
# 2. Post-treatment bilateral connectivity (2011-2015) with pre-treatment control
#
# Regressors:
# - Continuous: z_size_proximity, z_hs_proximity, z_female_proximity,
#               z_nonwhite_proximity, z_wage_proximity, z_educ_proximity,
#               z_clauses_proximity, z_geo_proximity
# - Dummies: same_industry, same_union, same_microregion, same_industry_micro
# - Post only: z_bilateral_conn_pre
#
# Output:
# - Coefficient CSV files for Python coefplots
# - LaTeX tables (separate for continuous/dummies)
# - Coefficient plots (PDF)
# ==============================================================================

echo "=============================================="
echo "Bilateral Multivariate Regressions Pipeline"
echo "=============================================="
echo "Job started at $(date)"
echo "Running on node: $(hostname)"
echo ""

# Create logs directory if needed
mkdir -p /gpfs/kellogg/proj/lgg3230/UnionSpill/Programs/logs

# Change to project directory
cd /gpfs/kellogg/proj/lgg3230/UnionSpill

# ==============================================================================
# STEP 1: Pre-treatment bilateral regression
# ==============================================================================
echo "=============================================="
echo "STEP 1: Pre-treatment bilateral regression"
echo "=============================================="
echo "Started at $(date)"

/software/Stata/stata17/stata-mp -b do Programs/06_bilateral_multivariate.do

# Check for errors
if [ -f "Data/RAIS_aux/bilateral_multivariate_coefficients_pre.csv" ]; then
    echo "SUCCESS: Pre-treatment regression completed"
    echo "Output: Data/RAIS_aux/bilateral_multivariate_coefficients_pre.csv"
else
    echo "ERROR: Pre-treatment regression failed. Check log file."
    exit 1
fi

# ==============================================================================
# STEP 2: Pre-treatment coefficient plots (Python)
# ==============================================================================
echo ""
echo "=============================================="
echo "STEP 2: Pre-treatment coefficient plots"
echo "=============================================="
echo "Started at $(date)"

# Load Python module if needed (adjust for your cluster)
module load python/anaconda3 2>/dev/null || true

python Programs/06_bilateral_multivariate_coefplot.py

# Check for output
if [ -f "Graphs/coefplot_bilateral_continuous_pre_multi.pdf" ]; then
    echo "SUCCESS: Pre-treatment plots created"
else
    echo "WARNING: Pre-treatment plots may not have been created"
fi

# ==============================================================================
# STEP 3: Post-treatment bilateral regression
# ==============================================================================
echo ""
echo "=============================================="
echo "STEP 3: Post-treatment bilateral regression"
echo "=============================================="
echo "Started at $(date)"

/software/Stata/stata17/stata-mp -b do Programs/07b_bilateral_multivariate_post.do

# Check for errors
if [ -f "Data/RAIS_aux/bilateral_multivariate_coefficients_post.csv" ]; then
    echo "SUCCESS: Post-treatment regression completed"
    echo "Output: Data/RAIS_aux/bilateral_multivariate_coefficients_post.csv"
else
    echo "ERROR: Post-treatment regression failed. Check log file."
    exit 1
fi

# ==============================================================================
# STEP 4: Post-treatment coefficient plots (Python)
# ==============================================================================
echo ""
echo "=============================================="
echo "STEP 4: Post-treatment coefficient plots"
echo "=============================================="
echo "Started at $(date)"

python Programs/07b_bilateral_multivariate_coefplot_post.py

# Check for output
if [ -f "Graphs/coefplot_bilateral_continuous_post_multi.pdf" ]; then
    echo "SUCCESS: Post-treatment plots created"
else
    echo "WARNING: Post-treatment plots may not have been created"
fi

# ==============================================================================
# SUMMARY
# ==============================================================================
echo ""
echo "=============================================="
echo "PIPELINE COMPLETE"
echo "=============================================="
echo "Finished at $(date)"
echo ""
echo "Output files:"
echo ""
echo "Pre-treatment (2007-2011):"
echo "  Coefficients: Data/RAIS_aux/bilateral_multivariate_coefficients_pre.csv"
echo "  Tables:       Tables/bilateral_multivariate_continuous_pre.tex"
echo "                Tables/bilateral_multivariate_dummies_pre.tex"
echo "  Plots:        Graphs/coefplot_bilateral_continuous_pre_multi.pdf"
echo "                Graphs/coefplot_bilateral_dummies_pre_multi.pdf"
echo "  LaTeX figure: Graphs/figure_bilateral_coefplot_pre_multi.tex"
echo ""
echo "Post-treatment (2011-2015):"
echo "  Coefficients: Data/RAIS_aux/bilateral_multivariate_coefficients_post.csv"
echo "  Tables:       Tables/bilateral_multivariate_continuous_post.tex"
echo "                Tables/bilateral_multivariate_dummies_post.tex"
echo "                Tables/bilateral_multivariate_pre_conn_post.tex"
echo "  Plots:        Graphs/coefplot_bilateral_continuous_post_multi.pdf"
echo "                Graphs/coefplot_bilateral_dummies_post_multi.pdf"
echo "                Graphs/coefplot_bilateral_pre_conn_post_multi.pdf"
echo "  LaTeX figure: Graphs/figure_bilateral_coefplot_post_multi.tex"
echo ""
echo "=============================================="
