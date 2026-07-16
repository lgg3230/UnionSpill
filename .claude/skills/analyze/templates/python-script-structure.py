"""
[NN]_[script_name].py
Purpose: [one sentence]
Project: [Project Name]
Paper: [Author (Year)], Section [X]
Inputs: [Data/analysis_data.parquet]
Outputs: [Tables/reg_main.tex, Graphs/event_study.pdf]
"""

# --- Packages ----------------------------------------------------------------
from pathlib import Path
import numpy as np
import pandas as pd
import statsmodels.api as sm
# import pyfixest as pf          # Panel data with fixed effects
# import linearmodels as lm      # IV, panel models
# import matplotlib.pyplot as plt
# import seaborn as sns
# [add project-specific packages]

# --- Paths -------------------------------------------------------------------
# All paths relative to project root. No os.chdir(), no absolute paths.
ROOT = Path(__file__).resolve().parents[2]  # Adjust depth to reach project root
TABLE_DIR = ROOT / "paper" / "tables"
FIGURE_DIR = ROOT / "paper" / "figures"
TABLE_DIR.mkdir(parents=True, exist_ok=True)
FIGURE_DIR.mkdir(parents=True, exist_ok=True)

# --- Seed --------------------------------------------------------------------
# Single seed per script. SEED defined in 01_setup.py; override here only if
# this script needs an independent stream (document why).
SEED = 12345
np.random.seed(SEED)
# If using sklearn: from sklearn.utils import check_random_state; rng = check_random_state(SEED)

# --- Paper-to-Code Naming Map -----------------------------------------------
# (Include in 01_setup.py; reference here for quick lookup)
# Paper Symbol       | Code Name        | Description
# Y_{it}             | outcome          | [outcome variable]
# D_{it}             | treatment        | [treatment indicator]
# X_{it}             | controls         | [control vector]
# \hat{\beta}        | beta_hat         | [main coefficient]

# --- Data --------------------------------------------------------------------
df = pd.read_parquet(ROOT / "data" / "cleaned" / "analysis_data.parquet")
# Alternative: df = pd.read_csv(ROOT / "data" / "cleaned" / "analysis_data.csv")

print(f"Observations: {len(df)}")
print(f"Variables: {df.shape[1]}")

# --- Analysis ----------------------------------------------------------------
# [Main analysis code here]

# --- Save Intermediate Objects -----------------------------------------------
# Pickle for all computed objects (models, DataFrames, statistics)
# import pickle
# with open(ROOT / "scripts" / "python" / "output" / "model_fit.pkl", "wb") as f:
#     pickle.dump(model_fit, f)

# --- Export Tables -----------------------------------------------------------
# Export bare tabular (no \begin{table} wrapper) -- INV-13
# with open(TABLE_DIR / "reg_main.tex", "w") as f:
#     f.write(tex_output)

# --- Export Figures ----------------------------------------------------------
# No titles inside matplotlib/seaborn -- INV-12. Titles go in LaTeX \caption{}
# fig.savefig(FIGURE_DIR / "fig_main.pdf", bbox_inches="tight")

print("Script complete: [NN]_[script_name].py")
