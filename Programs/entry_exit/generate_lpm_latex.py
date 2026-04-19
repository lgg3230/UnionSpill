"""
generate_lpm_latex.py
---------------------
Produces LaTeX tables for the LPM (firm presence) exercise.

Reads:
  Tables/entry_exit/lpm_direct_panel{A,B,C}_{full,pre}_lpm_entry_exit.csv
  Tables/entry_exit/lpm_spill_{full,pre}_lpm_entry_exit.csv

Outputs:
  Tables/entry_exit/lpm_direct_combined_lpm_entry_exit.tex
  Tables/entry_exit/lpm_spill_lpm_entry_exit.tex
"""

from pathlib import Path
import pandas as pd

root       = Path(__file__).resolve().parent.parent.parent
tables_dir = root / "Tables" / "entry_exit"

SPEC    = "lpm_entry_exit"
OUTCOME = "present_in_year"

# ---------------------------------------------------------------------------
# Helpers (same pattern as generate_entry_exit_latex.py)
# ---------------------------------------------------------------------------

def read_csv(path):
    if not path.exists():
        return {}
    df = pd.read_csv(
        path, sep=";", header=None, skiprows=1,
        names=["spec", "section", "outcome", "row_type", "value"],
        dtype=str,
    )
    df = df.apply(lambda col: col.str.strip().str.replace('"', '', regex=False))
    return {(r["outcome"], r["row_type"]): r["value"] for _, r in df.iterrows()}


def get(d, row_type):
    return d.get((OUTCOME, row_type), "")


def fmt(val, ndigits=4):
    try:
        f = float(val)
        return "" if pd.isna(f) else f"{f:.{ndigits}f}"
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
    return fmt(val)


def fmt_n(val):
    try:
        return f"{int(float(val)):,}" if val else ""
    except Exception:
        return val or ""


# ---------------------------------------------------------------------------
# Combined direct effects table (panels A, B, C stacked)
# ---------------------------------------------------------------------------

BASE_NOTE_DIRECT = (
    r"This table reports linear probability model estimates of firm presence"
    r" ($\mathbf{1}[\text{firm active in year } t]$) using the full firm"
    r" $\times$ year balanced panel, including firm-year cells where the firm"
    r" is absent."
    r" \textit{Full unbalanced panel} includes all firms in the Lagos sample."
    r" \textit{Present all pre-treat yrs} restricts to firms observed in every"
    r" year of 2009--2011, isolating the exit margin."
    r" Panel A restricts control firms to those with zero pre-treatment worker"
    r" flows to treated firms; Panel B allows up to 1\%; Panel C uses all"
    r" untreated firms."
    r" Fixed effects absorb firm, industry $\times$ year, microregion $\times$"
    r" year, and CBA base month $\times$ year."
    r" All specifications include pre-treatment quartile bins of log employment"
    r" and of 2007--2011 average pairwise total flows interacted with year fixed"
    r" effects. FE variables for absent firm-years are filled from each firm's"
    r" pre-treatment real observations."
    r" Standard errors clustered at the establishment level."
    r" Significance: $^{*}p{<}0.10$, $^{**}p{<}0.05$, $^{***}p{<}0.01$."
)

BASE_NOTE_SPILL = (
    r"This table reports linear probability model estimates of firm presence"
    r" ($\mathbf{1}[\text{firm active in year } t]$) for the spillover sample"
    r" (untreated firms only). The spillover regressor is a firm's pre-treatment"
    r" exposure to treated firms, measured as pairwise per-worker flows from"
    r" 2007--2011, normalized to the 90th percentile of the spillover sample in 2009."
    r" \textit{Full unbalanced panel} and \textit{Present all pre-treat yrs} as"
    r" in the direct effects table."
    r" Fixed effects and pre-treatment controls as above."
    r" Standard errors clustered at the establishment level."
    r" Significance: $^{*}p{<}0.10$, $^{**}p{<}0.05$, $^{***}p{<}0.01$."
)

PANEL_CONFIGS = [
    ("A", r"Panel A: Zero-connectivity controls"),
    ("B", r"Panel B: Low-connectivity controls ($\leq$1\%)"),
    ("C", r"Panel C: All untreated firms"),
]


def write_direct_combined(fout, panels_data):
    """panels_data: list of (label, data_full, data_pre)."""
    lines = []
    a = lines.append

    a(r"\begin{table}[H]")
    a(r"\centering")
    a(r"\scriptsize")
    a(r"\caption{Direct Effects: Firm Presence (LPM)}")
    a(r"\begin{tabular}{lcc}")
    a(r"\toprule")
    a(r"& \shortstack{Full\\unbalanced panel} & \shortstack{Present all\\pre-treat yrs} \\")
    a(r"& (1) & (2) \\")

    for label, d_full, d_pre in panels_data:
        a(r"\midrule")
        a(r"\multicolumn{3}{l}{\textit{" + label + r"}} \\")
        a(r"\midrule")

        # Post row
        c_full = coef_str(get(d_full, "main")) + stars(get(d_full, "main"))
        c_pre_ = coef_str(get(d_pre,  "main")) + stars(get(d_pre,  "main"))
        a(r"Treated $\times$ Post & " + c_full + r" & " + c_pre_ + r" \\")

        se_full = f"({fmt(get(d_full, 'main_se'))})" if fmt(get(d_full, 'main_se')) else ""
        se_pre_ = f"({fmt(get(d_pre,  'main_se'))})" if fmt(get(d_pre,  'main_se')) else ""
        a(r"& " + se_full + r" & " + se_pre_ + r" \\[3pt]")

        # Pre/placebo row
        b_full = coef_str(get(d_full, "pre")) + stars(get(d_full, "pre"))
        b_pre_ = coef_str(get(d_pre,  "pre")) + stars(get(d_pre,  "pre"))
        a(r"Treated $\times$ Pre & " + b_full + r" & " + b_pre_ + r" \\")

        bse_full = f"({fmt(get(d_full, 'pre_se'))})" if fmt(get(d_full, 'pre_se')) else ""
        bse_pre_ = f"({fmt(get(d_pre,  'pre_se'))})" if fmt(get(d_pre,  'pre_se')) else ""
        a(r"& " + bse_full + r" & " + bse_pre_ + r" \\[3pt]")

        a(r"\midrule")
        a(r"Observations   & " + fmt_n(get(d_full, "n_obs"))   + r" & " + fmt_n(get(d_pre, "n_obs"))   + r" \\")
        a(r"Establishments & " + fmt_n(get(d_full, "n_estab")) + r" & " + fmt_n(get(d_pre, "n_estab")) + r" \\")
        a(r"Pre-trend $p$-val & " + fmt(get(d_full, "pre_pval"), 3) + r" & " + fmt(get(d_pre, "pre_pval"), 3) + r" \\")

    a(r"\bottomrule")
    a(r"\end{tabular}")
    a(r"\begin{minipage}{\textwidth}")
    a(r"\footnotesize")
    a(r"\medskip")
    a(r"\textit{Notes}: " + BASE_NOTE_DIRECT)
    a(r"\end{minipage}")
    a(r"\end{table}")

    fout.write("\n".join(lines) + "\n")


def write_spill(fout, d_full, d_pre):
    lines = []
    a = lines.append

    a(r"\begin{table}[H]")
    a(r"\centering")
    a(r"\scriptsize")
    a(r"\caption{Spillover Effects: Firm Presence (LPM)}")
    a(r"\begin{tabular}{lcc}")
    a(r"\toprule")
    a(r"& \shortstack{Full\\unbalanced panel} & \shortstack{Present all\\pre-treat yrs} \\")
    a(r"& (1) & (2) \\")
    a(r"\midrule")

    # Post row
    c_full = coef_str(get(d_full, "main")) + stars(get(d_full, "main"))
    c_pre_ = coef_str(get(d_pre,  "main")) + stars(get(d_pre,  "main"))
    a(r"Connectivity $\times$ Post & " + c_full + r" & " + c_pre_ + r" \\")

    se_full = f"({fmt(get(d_full, 'main_se'))})" if fmt(get(d_full, 'main_se')) else ""
    se_pre_ = f"({fmt(get(d_pre,  'main_se'))})" if fmt(get(d_pre,  'main_se')) else ""
    a(r"& " + se_full + r" & " + se_pre_ + r" \\[3pt]")

    # Pre/placebo row
    b_full = coef_str(get(d_full, "pre")) + stars(get(d_full, "pre"))
    b_pre_ = coef_str(get(d_pre,  "pre")) + stars(get(d_pre,  "pre"))
    a(r"Connectivity $\times$ Pre & " + b_full + r" & " + b_pre_ + r" \\")

    bse_full = f"({fmt(get(d_full, 'pre_se'))})" if fmt(get(d_full, 'pre_se')) else ""
    bse_pre_ = f"({fmt(get(d_pre,  'pre_se'))})" if fmt(get(d_pre,  'pre_se')) else ""
    a(r"& " + bse_full + r" & " + bse_pre_ + r" \\[3pt]")

    a(r"\midrule")
    a(r"Observations   & " + fmt_n(get(d_full, "n_obs"))   + r" & " + fmt_n(get(d_pre, "n_obs"))   + r" \\")
    a(r"Establishments & " + fmt_n(get(d_full, "n_estab")) + r" & " + fmt_n(get(d_pre, "n_estab")) + r" \\")
    a(r"Pre-trend $p$-val & " + fmt(get(d_full, "pre_pval"), 3) + r" & " + fmt(get(d_pre, "pre_pval"), 3) + r" \\")

    a(r"\bottomrule")
    a(r"\end{tabular}")
    a(r"\begin{minipage}{\textwidth}")
    a(r"\footnotesize")
    a(r"\medskip")
    a(r"\textit{Notes}: " + BASE_NOTE_SPILL)
    a(r"\end{minipage}")
    a(r"\end{table}")

    fout.write("\n".join(lines) + "\n")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

panels_data = []
for panel, label in PANEL_CONFIGS:
    d_full = read_csv(tables_dir / f"lpm_direct_panel{panel}_full_{SPEC}.csv")
    d_pre  = read_csv(tables_dir / f"lpm_direct_panel{panel}_pre_{SPEC}.csv")
    panels_data.append((label, d_full, d_pre))

out_direct = tables_dir / f"lpm_direct_combined_{SPEC}.tex"
with open(out_direct, "w") as f:
    write_direct_combined(f, panels_data)
print(f"Wrote {out_direct}")

d_spill_full = read_csv(tables_dir / f"lpm_spill_full_{SPEC}.csv")
d_spill_pre  = read_csv(tables_dir / f"lpm_spill_pre_{SPEC}.csv")

out_spill = tables_dir / f"lpm_spill_{SPEC}.tex"
with open(out_spill, "w") as f:
    write_spill(f, d_spill_full, d_spill_pre)
print(f"Wrote {out_spill}")

print("Done.")
