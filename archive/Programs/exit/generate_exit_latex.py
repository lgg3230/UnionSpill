"""
generate_exit_latex.py
----------------------
Produces a LaTeX table for the firm survival (exit) exercise.

Reads 4 CSVs (direct×{full,pre} + spillover×{full,pre}) from Tables/exit/
and writes a 4-column table:

  (1) Treated × Post / Pre       — direct, full unbalanced panel
  (2) Treated × Post / Pre       — direct, present all pre-treat yrs
  (3) Connectivity × Post / Pre  — spillover, full unbalanced panel
  (4) Connectivity × Post / Pre  — spillover, present all pre-treat yrs

Output: Tables/exit/exit_exit.tex
"""

from pathlib import Path
import pandas as pd

root       = Path(__file__).resolve().parent.parent.parent
tables_in  = root / "Tables" / "exit"
tables_out = tables_in

SPEC = "exit"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def fmt(val, ndigits=4):
    try:
        f = float(val)
        if pd.isna(f):
            return ""
        return f"{f:.{ndigits}f}"
    except (ValueError, TypeError):
        return ""


def stars(val):
    val = str(val).strip('"').strip()
    for s in ["***", "**", "*"]:
        if val.endswith(s):
            return s
    return ""


def coef_str(val):
    val = str(val).strip('"').strip()
    for s in ["***", "**", "*"]:
        if val.endswith(s):
            val = val[: -len(s)]
    try:
        return fmt(val)
    except Exception:
        return ""


def read_csv(path):
    if not path.exists():
        return {}
    df = pd.read_csv(
        path, sep=";", header=None, skiprows=1,
        names=["spec", "section", "outcome", "row_type", "value"],
        dtype=str,
    )
    df = df.apply(lambda col: col.str.strip().str.replace('"', '', regex=False))
    out = {}
    for _, row in df.iterrows():
        key = (row["outcome"], row["row_type"])
        out[key] = row["value"]
    return out


def get(d, row_type, outcome="present_in_year"):
    return d.get((outcome, row_type), "")


def se_row(val):
    s = fmt(val)
    return f"({s})" if s else ""


def fmt_n(v):
    try:
        return f"{int(float(v)):,}" if v else ""
    except Exception:
        return v


def fmt_pval(v):
    """Show value or dash if missing/non-numeric."""
    try:
        f = float(v)
        if pd.isna(f):
            return r"---"
        return f"{f:.3f}"
    except (ValueError, TypeError):
        return r"---"


# ---------------------------------------------------------------------------
# Load data
# ---------------------------------------------------------------------------

d_dir_full = read_csv(tables_in / f"results_exit_direct_full_{SPEC}.csv")
d_dir_pre  = read_csv(tables_in / f"results_exit_direct_pre_{SPEC}.csv")
d_spl_full = read_csv(tables_in / f"results_exit_spill_full_{SPEC}.csv")
d_spl_pre  = read_csv(tables_in / f"results_exit_spill_pre_{SPEC}.csv")

cols = [
    ("Direct",    "Full unbalanced panel",     d_dir_full, "Treated"),
    ("Direct",    "Present all pre-treat yrs", d_dir_pre,  "Treated"),
    ("Spillover", "Full unbalanced panel",      d_spl_full, "Connectivity"),
    ("Spillover", "Present all pre-treat yrs",  d_spl_pre,  "Connectivity"),
]

# ---------------------------------------------------------------------------
# Build LaTeX
# ---------------------------------------------------------------------------

lines = []
a = lines.append

a(r"\begin{table}[H]")
a(r"\centering")
a(r"\scriptsize")
a(r"\caption{Firm Survival}")
a(r"\begin{tabular}{lcccc}")
a(r"\toprule")

# Tier-1 header
a(r"& \multicolumn{2}{c}{Direct} & \multicolumn{2}{c}{Spillover} \\")
a(r"\cmidrule(lr){2-3} \cmidrule(lr){4-5}")

# Tier-2 header
a(
    r"& \shortstack{Full\\unbalanced} & \shortstack{Present all\\pre-treat yrs}"
    r" & \shortstack{Full\\unbalanced} & \shortstack{Present all\\pre-treat yrs} \\"
)
a(r"& (1) & (2) & (3) & (4) \\")
a(r"\midrule")

# ── Post-treatment row ─────────────────────────────────────────────────────
post_cells = []
for _, _, d, _ in cols:
    v    = get(d, "main")
    num  = coef_str(v)
    star = stars(v)
    post_cells.append(f"{num}{star}" if num else "")

a(r"$\beta_{\text{post}}$ & " + " & ".join(post_cells) + r" \\")

se_cells = [se_row(get(d, "main_se")) for _, _, d, _ in cols]
a("& " + " & ".join(se_cells) + r" \\[3pt]")

# ── Pre-treatment placebo ──────────────────────────────────────────────────
pre_cells = []
for _, _, d, _ in cols:
    v    = get(d, "pre")
    num  = coef_str(v)
    star = stars(v)
    pre_cells.append(f"{num}{star}" if num else "")

a(r"$\beta_{\text{pre}}$ & " + " & ".join(pre_cells) + r" \\")
se_cells_pre = [se_row(get(d, "pre_se")) for _, _, d, _ in cols]
a("& " + " & ".join(se_cells_pre) + r" \\[3pt]")

a(r"\midrule")

# ── Stats ──────────────────────────────────────────────────────────────────
nobs  = [fmt_n(get(d, "n_obs"))   for _, _, d, _ in cols]
nest  = [fmt_n(get(d, "n_estab")) for _, _, d, _ in cols]
pvals = [fmt_pval(get(d, "pre_pval")) for _, _, d, _ in cols]

a(r"Observations & "      + " & ".join(nobs)  + r" \\")
a(r"Establishments & "    + " & ".join(nest)  + r" \\")
a(r"Pre-trend $p$-val & " + " & ".join(pvals) + r" \\")

a(r"\midrule")
a(
    r"& \multicolumn{2}{c}{Regressor: Treated} "
    r"& \multicolumn{2}{c}{Regressor: Connectivity} \\"
)
a(r"\bottomrule")
a(r"\end{tabular}")

# ── Note ───────────────────────────────────────────────────────────────────
note = (
    r"This table reports difference-in-differences estimates where the outcome"
    r" is a dummy equal to one if the firm has real observations in a given year"
    r" (i.e., has not exited the dataset)."
    r" \textit{Full unbalanced panel} includes all firms in the Lagos sample"
    r" that appear in at least one year during 2009--2016."
    r" \textit{Present all pre-treat yrs} restricts to firms observed in every"
    r" year of 2009, 2010, and 2011."
    r" Columns (1)--(2) report the coefficient on Treated $\times$ Post (or Pre)"
    r" from the direct specification; columns (3)--(4) report the coefficient on"
    r" Connectivity $\times$ Post (or Pre) from the spillover specification, where"
    r" connectivity is the firm's pre-treatment exposure to treated firms"
    r" (pairwise per-worker flows 2007--2011, normalized to the 90th percentile"
    r" of the spillover sample in 2009)."
    r" All specifications include firm fixed effects, industry $\times$ year,"
    r" microregion $\times$ year, and CBA base month $\times$ year fixed effects."
    r" Pre-treatment quartile bins of log employment and of 2007--2011 average"
    r" pairwise total flows per worker are interacted with year fixed effects."
    r" Specifications include only the interaction term (not the main effects of"
    r" the treatment indicator or year), as the main effects are absorbed by the"
    r" firm and year-interacted fixed effects."
    r" Pre-trend $p$-val is from an F-test on the 2009 and 2010 interaction"
    r" coefficients in the event-study regression."
    r" A dash (---) indicates the test is not identified: in the"
    r" \textit{Present all pre-treat yrs} sample all firms have"
    r" \texttt{present\_in\_year}$=1$ in every pre-treatment year by construction,"
    r" so the pre-treatment interaction coefficients are collinear and cannot be"
    r" estimated. Standard errors clustered at the establishment level."
    r" Significance: $^{*}p{<}0.10$, $^{**}p{<}0.05$, $^{***}p{<}0.01$."
)

a(r"\begin{minipage}{\textwidth}")
a(r"\footnotesize")
a(r"\medskip")
a(r"\textit{Notes}: " + note)
a(r"\end{minipage}")
a(r"\end{table}")

out_path = tables_out / f"exit_{SPEC}.tex"
with open(out_path, "w") as f:
    f.write("\n".join(lines) + "\n")

print(f"Wrote {out_path}")
print("Done.")
