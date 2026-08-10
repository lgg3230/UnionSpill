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

Outcomes shown per panel (appended vertically):
  1. present_in_year  — firm active in year t (full 2009–2016 window)
  2. entry_bw         — buffer-window firm entry (2011–2014 only)
  3. exit_bw          — buffer-window firm exit  (2011–2014 only)
"""

from pathlib import Path
import pandas as pd

root       = Path(__file__).resolve().parent.parent.parent
tables_dir = root / "Tables" / "entry_exit"

SPEC = "lpm_entry_exit"

OUTCOME_LABELS = {
    "present_in_year": "Firm active in year",
    "entry_bw":        "Firm entry (buffer window, 2011--2014)",
    "exit_bw":         "Firm exit (buffer window, 2011--2014)",
}

# ---------------------------------------------------------------------------
# Helpers
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


def get(d, outcome, row_type):
    return d.get((outcome, row_type), "")


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
# Notes
# ---------------------------------------------------------------------------

BASE_NOTE_DIRECT = (
    r"This table reports linear probability model estimates of three firm-level"
    r" outcomes using the full firm $\times$ year expanded panel (including"
    r" firm-year cells where the firm is absent)."
    r" \textit{Firm active in year} equals 1 if the firm has real observations"
    r" in year $t$ (2009--2016)."
    r" \textit{Firm entry} and \textit{Firm exit} follow the buffer-window"
    r" definition of Bassier (2023): entry equals 1 if the firm is absent in"
    r" $t-2$ and $t-1$ and present in $t$, $t+1$, and $t+2$; exit equals 1 if"
    r" the firm is present in $t-2$, $t-1$, and $t$ and absent in $t+1$ and"
    r" $t+2$. Buffer-window outcomes are only defined for 2011--2014 given the"
    r" 2009--2016 data range; no pre-trend test is reported for these outcomes."
    r" \textit{Full unbalanced panel} includes all firms in the Lagos sample."
    r" \textit{Present all pre-treat yrs} restricts to firms observed in every"
    r" year of 2009--2011."
    r" Panel A restricts control firms to zero pre-treatment worker flows to"
    r" treated firms; Panel B allows up to 1\%; Panel C uses all untreated firms."
    r" Fixed effects: firm, industry $\times$ year, microregion $\times$ year,"
    r" CBA base month $\times$ year, pre-treatment employment quartile $\times$"
    r" year, and pre-treatment total-flows quartile $\times$ year."
    r" Standard errors clustered at the establishment level."
    r" Significance: $^{*}p{<}0.10$, $^{**}p{<}0.05$, $^{***}p{<}0.01$."
)

BASE_NOTE_SPILL = (
    r"This table reports linear probability model spillover estimates for the"
    r" same three outcomes as the direct-effects table (see notes there for"
    r" outcome definitions)."
    r" The sample is untreated firms only. The spillover regressor is a firm's"
    r" pre-treatment exposure to treated firms (pairwise per-worker flows"
    r" 2007--2011, normalized to the 90th percentile of the spillover sample"
    r" in 2009)."
    r" Fixed effects and pre-treatment controls as in the direct-effects table."
    r" Standard errors clustered at the establishment level."
    r" Significance: $^{*}p{<}0.10$, $^{**}p{<}0.05$, $^{***}p{<}0.01$."
)

PANEL_CONFIGS = [
    ("A", r"Panel A: Zero-connectivity controls"),
    ("B", r"Panel B: Low-connectivity controls ($\leq$1\%)"),
    ("C", r"Panel C: All untreated firms"),
]

OUTCOMES = ["present_in_year", "entry_bw", "exit_bw"]


# ---------------------------------------------------------------------------
# Outcome sub-block helper
# ---------------------------------------------------------------------------

def outcome_block(lines, d_full, d_pre, outcome, is_direct):
    """Append rows for one outcome within a panel block."""
    a = lines.append
    label = OUTCOME_LABELS[outcome]
    has_pre = (outcome == "present_in_year")   # only present_in_year has placebo/F-test

    a(r"\multicolumn{3}{l}{\textit{Outcome: " + label + r"}} \\")

    # Post row
    key = "main" if is_direct else "main"
    c_full = coef_str(get(d_full, outcome, "main")) + stars(get(d_full, outcome, "main"))
    c_pre_ = coef_str(get(d_pre,  outcome, "main")) + stars(get(d_pre,  outcome, "main"))
    row_label = r"Treated $\times$ Post" if is_direct else r"Connectivity $\times$ Post"
    a(row_label + r" & " + c_full + r" & " + c_pre_ + r" \\")

    se_full = f"({fmt(get(d_full, outcome, 'main_se'))})" if fmt(get(d_full, outcome, 'main_se')) else ""
    se_pre_ = f"({fmt(get(d_pre,  outcome, 'main_se'))})" if fmt(get(d_pre,  outcome, 'main_se')) else ""
    a(r"& " + se_full + r" & " + se_pre_ + r" \\[3pt]")

    if has_pre:
        row_label_pre = r"Treated $\times$ Pre" if is_direct else r"Connectivity $\times$ Pre"
        b_full = coef_str(get(d_full, outcome, "pre")) + stars(get(d_full, outcome, "pre"))
        b_pre_ = coef_str(get(d_pre,  outcome, "pre")) + stars(get(d_pre,  outcome, "pre"))
        a(row_label_pre + r" & " + b_full + r" & " + b_pre_ + r" \\")
        bse_full = f"({fmt(get(d_full, outcome, 'pre_se'))})" if fmt(get(d_full, outcome, 'pre_se')) else ""
        bse_pre_ = f"({fmt(get(d_pre,  outcome, 'pre_se'))})" if fmt(get(d_pre,  outcome, 'pre_se')) else ""
        a(r"& " + bse_full + r" & " + bse_pre_ + r" \\[3pt]")

    a(r"Observations   & " + fmt_n(get(d_full, outcome, "n_obs"))   + r" & " + fmt_n(get(d_pre, outcome, "n_obs"))   + r" \\")
    a(r"Establishments & " + fmt_n(get(d_full, outcome, "n_estab")) + r" & " + fmt_n(get(d_pre, outcome, "n_estab")) + r" \\")

    if has_pre:
        a(r"Pre-trend $p$-val & " + fmt(get(d_full, outcome, "pre_pval"), 3) + r" & " + fmt(get(d_pre, outcome, "pre_pval"), 3) + r" \\")


# ---------------------------------------------------------------------------
# Direct effects table
# ---------------------------------------------------------------------------

def write_direct_combined(fout, panels_data):
    lines = []
    a = lines.append

    a(r"\begin{table}[H]")
    a(r"\centering")
    a(r"\scriptsize")
    a(r"\caption{Direct Effects: Firm Presence, Entry, and Exit (LPM)}")
    a(r"\begin{tabular}{lcc}")
    a(r"\toprule")
    a(r"& \shortstack{Full\\unbalanced panel} & \shortstack{Present all\\pre-treat yrs} \\")
    a(r"& (1) & (2) \\")

    for label, d_full, d_pre in panels_data:
        a(r"\midrule")
        a(r"\multicolumn{3}{l}{\textit{" + label + r"}} \\")
        for outcome in OUTCOMES:
            a(r"\midrule")
            outcome_block(lines, d_full, d_pre, outcome, is_direct=True)

    a(r"\bottomrule")
    a(r"\end{tabular}")
    a(r"\begin{minipage}{\textwidth}")
    a(r"\footnotesize")
    a(r"\medskip")
    a(r"\textit{Notes}: " + BASE_NOTE_DIRECT)
    a(r"\end{minipage}")
    a(r"\end{table}")

    fout.write("\n".join(lines) + "\n")


# ---------------------------------------------------------------------------
# Spillover table
# ---------------------------------------------------------------------------

def write_spill(fout, d_full, d_pre):
    lines = []
    a = lines.append

    a(r"\begin{table}[H]")
    a(r"\centering")
    a(r"\scriptsize")
    a(r"\caption{Spillover Effects: Firm Presence, Entry, and Exit (LPM)}")
    a(r"\begin{tabular}{lcc}")
    a(r"\toprule")
    a(r"& \shortstack{Full\\unbalanced panel} & \shortstack{Present all\\pre-treat yrs} \\")
    a(r"& (1) & (2) \\")

    for outcome in OUTCOMES:
        a(r"\midrule")
        outcome_block(lines, d_full, d_pre, outcome, is_direct=False)

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
