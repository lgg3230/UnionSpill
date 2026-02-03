#!/bin/bash
#
# Run bilateral connectivity gravity analysis
# Step 1: Data preparation with Python/DuckDB (fast)
# Step 2: Regressions with Stata/reghdfe
#

set -e  # Exit on error

echo "========================================"
echo "BILATERAL CONNECTIVITY GRAVITY ANALYSIS"
echo "========================================"

# Paths
PROJ_DIR="/kellogg/proj/lgg3230/UnionSpill"
PYTHON="~/.conda/envs/venv_python312/bin/python"

# Step 1: Data preparation with DuckDB
echo ""
echo "[Step 1] Running data preparation (Python/DuckDB)..."
echo "----------------------------------------"
$PYTHON "$PROJ_DIR/Programs/06_bilateral_data_prep.py"

# Step 2: Regressions with Stata
echo ""
echo "[Step 2] Running regressions (Stata/reghdfe)..."
echo "----------------------------------------"
module load stata/17
cd "$PROJ_DIR"
stata-mp -b do Programs/06_bilateral_regression.do

echo ""
echo "========================================"
echo "ANALYSIS COMPLETE"
echo "========================================"
echo ""
echo "Output files:"
echo "  - /tmp/bilateral_pairs_gravity_ready.parquet (TEMPORARY - will be cleaned)"
echo "  - Data/RAIS_aux/bilateral_univariate_coefficients_gravity.csv"
echo "  - Data/RAIS_aux/bilateral_multivariate_coefficients_gravity.csv"
echo "  - Graphs/coefplot_bilateral_gravity.pdf"
echo "  - Tables/bilateral_regression_gravity.tex"
