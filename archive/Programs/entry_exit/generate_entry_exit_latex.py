"""
generate_entry_exit_latex.py
----------------------------
Produces LaTeX tables for the entry/exit exercise.

For each of panels A, B, C (direct effects) and D (spillover effects):
  - Reads the two CSV files (full unbalanced panel; firms present all pretreat years)
  - Generates one table with 8 columns: 4 outcomes × 2 panel samples
    Columns: (1) l_firm_emp [full], (2) lr_remdezr_w [full],
             (3) lr_remdezr_h_w [full], (4) numb_clauses [full]
             (5) l_firm_emp [pretreat], (6) lr_remdezr_w [pretreat],
             (7) lr_remdezr_h_w [pretreat], (8) numb_clauses [pretreat]

Outputs:
  Tables/entry_exit/direct_panelA_entry_exit.tex
  Tables/entry_exit/direct_panelB_entry_exit.tex
  Tables/entry_exit/direct_panelC_entry_exit.tex
  Tables/entry_exit/spill_entry_exit.tex
"""

from pathlib import Path
import pandas as pd

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
root      = Path(__file__).resolve().parent.parent.parent
tables_in = root / "Tables" / "entry_exit"
tables_out = tables_in

SPEC = "entry_exit"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def fmt(val, ndigits=4):
    """Format a float, or return blank for missing."""
    try:
        f = float(val)
        if pd.isna(f):
            return ""
        return f"{f:.{ndigits}f}"
    except (ValueError, TypeError):
        return ""


def stars(val):
    """Extract trailing stars from a value string like '0.0234**'."""
    val = str(val).strip('"').strip()
    for s in ["***", "**", "*"]:
        if val.endswith(s):
            return s
    return ""


def coef_str(val):
    """Return numeric part of a starred string."""
    val = str(val).strip('"').strip()
    for s in ["***", "**", "*"]:
        if val.endswith(s):
            val = val[: -len(s)]
    try:
        return fmt(val)
    except Exception:
        return ""


def read_csv(path):
    """Read semicolon-delimited result CSV; return dict keyed (outcome, row_type).

    The Stata writer uses a comma-delimited header but semicolon-delimited data
    rows, and value fields have a trailing quote.  We skip the header and assign
    column names manually, then strip all stray quotes and whitespace.
    """
    if not path.exists():
        return {}
    df = pd.read_csv(
        path, sep=";", header=None, skiprows=1,
        names=["spec", "section", "outcome", "row_type", "value"],
        dtype=str,
    )
    # Strip whitespace then all quote characters from every cell
    df = df.apply(lambda col: col.str.strip().str.replace('"', '', regex=False))
    out = {}
    for _, row in df.iterrows():
        key = (row["outcome"], row["row_type"])
        out[key] = row["value"]
    return out


def get(d, outcome, row_type):
    return d.get((outcome, row_type), "")


def se_row(val):
    """Format SE in parentheses."""
    s = fmt(val)
    return f"({s})" if s else ""


def write_table(
    fout,
    panel_label,       # e.g. "Panel A: Zero-connectivity controls"
    data_full,         # dict for full-panel results
    data_pre,          # dict for pretreat-panel results
    is_spill=False,
    note_extra="",
):
    outcomes = ["l_firm_emp", "lr_remdezr_w", "lr_remdezr_h_w", "numb_clauses"]
    out_labels = [
        r"\shortstack{Log\\employment}",
        r"\shortstack{Log real\\wage}",
        r"\shortstack{Log hourly\\wage}",
        r"\shortstack{CBA\\clauses}",
    ]

    row_post_label = (
        r"Connectivity $\times$ Post" if is_spill else r"Treated $\times$ Post"
    )
    row_pre_label = (
        r"Connectivity $\times$ Pre" if is_spill else r"Treated $\times$ Pre"
    )

    lines = []
    a = lines.append

    a(r"\begin{table}[H]")
    a(r"\centering")
    a(r"\scriptsize")
    a(r"\caption{" + panel_label + r"}")
    a(r"\begin{tabular}{lcccccccc}")
    a(r"\toprule")

    # Two-tier header
    a(
        r"& \multicolumn{4}{c}{Full unbalanced panel}"
        r" & \multicolumn{4}{c}{Present all pre-treat yrs} \\"
    )
    a(r"\cmidrule(lr){2-5} \cmidrule(lr){6-9}")
    a(
        "& "
        + r" & ".join(out_labels)
        + " & "
        + r" & ".join(out_labels)
        + r" \\"
    )
    a(r"& (1) & (2) & (3) & (4) & (5) & (6) & (7) & (8) \\")
    a(r"\midrule")

    def row_vals(d, row_type):
        return [get(d, o, row_type) for o in outcomes]

    def coef_row_str(d, row_type):
        vals = row_vals(d, row_type)
        cells = []
        for v in vals:
            num  = coef_str(v)
            star = stars(v)
            if num:
                cells.append(f"{num}{star}")
            else:
                cells.append("")
        return cells

    def se_row_str(d, row_type):
        vals = row_vals(d, row_type)
        return [se_row(v) for v in vals]

    # Post-treatment row
    cells_post = coef_row_str(data_full, "main") + coef_row_str(data_pre, "main")
    a(row_post_label + " & " + " & ".join(cells_post) + r" \\")
    cells_se = se_row_str(data_full, "main_se") + se_row_str(data_pre, "main_se")
    a("& " + " & ".join(cells_se) + r" \\[3pt]")

    # Pre-treatment placebo row
    cells_pre = coef_row_str(data_full, "pre") + coef_row_str(data_pre, "pre")
    a(row_pre_label + " & " + " & ".join(cells_pre) + r" \\")
    cells_se = se_row_str(data_full, "pre_se") + se_row_str(data_pre, "pre_se")
    a("& " + " & ".join(cells_se) + r" \\[3pt]")

    a(r"\midrule")

    # N obs
    n_obs_full = [get(data_full, o, "n_obs") for o in outcomes]
    n_obs_pre  = [get(data_pre,  o, "n_obs") for o in outcomes]
    def fmt_n(v):
        try:
            return f"{int(float(v)):,}" if v else ""
        except Exception:
            return v
    a(r"Observations & " + " & ".join(fmt_n(v) for v in n_obs_full + n_obs_pre) + r" \\")

    # N establishments
    n_est_full = [get(data_full, o, "n_estab") for o in outcomes]
    n_est_pre  = [get(data_pre,  o, "n_estab") for o in outcomes]
    a(r"Establishments & " + " & ".join(fmt_n(v) for v in n_est_full + n_est_pre) + r" \\")

    # Pre-trend F-test p-value
    pv_full = [fmt(get(data_full, o, "pre_pval"), 3) for o in outcomes]
    pv_pre  = [fmt(get(data_pre,  o, "pre_pval"), 3) for o in outcomes]
    a(r"Pre-trend $p$-val & " + " & ".join(pv_full + pv_pre) + r" \\")

    a(r"\bottomrule")
    a(r"\end{tabular}")

    # Note
    spill_note = (
        " The spillover regressor is a firm's pre-treatment exposure to treated firms,"
        " measured as pairwise per-worker flows from 2007--2011, normalized to the 90th"
        " percentile of the spillover sample in 2009."
        if is_spill
        else ""
    )
    base_note = (
        r"This table reports difference-in-differences estimates using an unbalanced panel."
        r" \textit{Full unbalanced panel} includes all firms in the Lagos sample that appear"
        r" in at least one year during 2009--2016."
        r" \textit{Present all pre-treat yrs} restricts to firms observed in every year of"
        r" 2009, 2010, and 2011, but allows subsequent exit."
        + spill_note +
        r" Outcomes: log December employment (\textit{Log employment}),"
        r" log real December earnings (\textit{Log real wage}),"
        r" log real hourly earnings (\textit{Log hourly wage})---both wage measures"
        r" computed from the worker-level dataset---and the number of clauses in the"
        r" relevant collective bargaining agreement (\textit{CBA clauses}), which is"
        r" only defined for firms with a CBA."
        r" Hourly wage is unavailable for exiting firms not in the balanced sample."
        r" Fixed effects absorb firm, industry $\times$ year, microregion $\times$ year,"
        r" and CBA base month $\times$ year."
        r" The CBA-clauses specification uses CBA-period fixed effects in place of year fixed effects."
        r" All specifications include pre-treatment quartile bins of the outcome and of"
        r" log employment interacted with year (CBA period) fixed effects, and quartile"
        r" bins of 2007--2011 average pairwise total flows interacted with year fixed"
        r" effects."
        r" Exiting firms that are not in the balanced sample have their industry and CBA base month"
        r" inferred from the CBA dataset and CNAE 2.0 codes in the RAIS 2009 establishment file."
        r" Standard errors clustered at the establishment level."
        r" Significance: $^{*}p{<}0.10$, $^{**}p{<}0.05$, $^{***}p{<}0.01$."
        + (f" {note_extra}" if note_extra else "")
    )
    a(r"\begin{minipage}{\textwidth}")
    a(r"\footnotesize")
    a(r"\medskip")
    a(r"\textit{Notes}: " + base_note)
    a(r"\end{minipage}")
    a(r"\end{table}")

    fout.write("\n".join(lines) + "\n")


# ---------------------------------------------------------------------------
# COMBINED DIRECT EFFECTS TABLE (panels A, B, C in one table)
# ---------------------------------------------------------------------------

PANEL_CONFIGS = [
    ("A", r"Panel A: Zero-connectivity controls"),
    ("B", r"Panel B: Low-connectivity controls ($\leq$1\%)"),
    ("C", r"Panel C: All untreated firms"),
]


def write_direct_combined(fout, panels_data):
    """Three-panel combined direct effects table.

    panels_data: list of (panel_label, data_full, data_pre) in order A, B, C.
    """
    outcomes = ["l_firm_emp", "lr_remdezr_w", "lr_remdezr_h_w", "numb_clauses"]
    out_labels = [
        r"\shortstack{Log\\employment}",
        r"\shortstack{Log real\\wage}",
        r"\shortstack{Log hourly\\wage}",
        r"\shortstack{CBA\\clauses}",
    ]

    lines = []
    a = lines.append

    a(r"\begin{table}[H]")
    a(r"\centering")
    a(r"\scriptsize")
    a(r"\caption{Direct Effects}")
    a(r"\begin{tabular}{lcccccccc}")
    a(r"\toprule")

    # Column header (printed once at top)
    a(
        r"& \multicolumn{4}{c}{Full unbalanced panel}"
        r" & \multicolumn{4}{c}{Present all pre-treat yrs} \\"
    )
    a(r"\cmidrule(lr){2-5} \cmidrule(lr){6-9}")
    a(
        "& "
        + " & ".join(out_labels)
        + " & "
        + " & ".join(out_labels)
        + r" \\"
    )
    a(r"& (1) & (2) & (3) & (4) & (5) & (6) & (7) & (8) \\")

    def coef_cells(d, row_type):
        cells = []
        for o in outcomes:
            v = get(d, o, row_type)
            num  = coef_str(v)
            star = stars(v)
            cells.append(f"{num}{star}" if num else "")
        return cells

    def se_cells(d, row_type):
        return [se_row(get(d, o, row_type)) for o in outcomes]

    def n_cells(d, row_type):
        cells = []
        for o in outcomes:
            v = get(d, o, row_type)
            try:
                cells.append(f"{int(float(v)):,}" if v else "")
            except Exception:
                cells.append(v)
        return cells

    def pval_cells(d):
        return [fmt(get(d, o, "pre_pval"), 3) for o in outcomes]

    for panel_label, data_full, data_pre in panels_data:
        a(r"\midrule")
        a(
            r"\multicolumn{9}{l}{\textit{"
            + panel_label
            + r"}} \\"
        )
        a(r"\midrule")

        # Post row
        post = coef_cells(data_full, "main") + coef_cells(data_pre, "main")
        a(r"Treated $\times$ Post & " + " & ".join(post) + r" \\")
        se_p = se_cells(data_full, "main_se") + se_cells(data_pre, "main_se")
        a("& " + " & ".join(se_p) + r" \\[3pt]")

        # Pre row
        pre = coef_cells(data_full, "pre") + coef_cells(data_pre, "pre")
        a(r"Treated $\times$ Pre & " + " & ".join(pre) + r" \\")
        se_r = se_cells(data_full, "pre_se") + se_cells(data_pre, "pre_se")
        a("& " + " & ".join(se_r) + r" \\[3pt]")

        a(r"\midrule")

        # Stats
        nobs = n_cells(data_full, "n_obs") + n_cells(data_pre, "n_obs")
        a(r"Observations & " + " & ".join(nobs) + r" \\")
        nest = n_cells(data_full, "n_estab") + n_cells(data_pre, "n_estab")
        a(r"Establishments & " + " & ".join(nest) + r" \\")
        pv = pval_cells(data_full) + pval_cells(data_pre)
        a(r"Pre-trend $p$-val & " + " & ".join(pv) + r" \\")

    a(r"\bottomrule")
    a(r"\end{tabular}")

    base_note = (
        r"This table reports difference-in-differences estimates using an unbalanced panel."
        r" \textit{Full unbalanced panel} includes all firms in the Lagos sample that appear"
        r" in at least one year during 2009--2016."
        r" \textit{Present all pre-treat yrs} restricts to firms observed in every year of"
        r" 2009, 2010, and 2011, but allows subsequent exit."
        r" Panel A restricts control firms to those with zero pre-treatment worker flows to"
        r" treated firms; Panel B allows up to 1\%; Panel C uses all untreated firms."
        r" Outcomes: log December employment (\textit{Log employment}),"
        r" log real December earnings (\textit{Log real wage}),"
        r" log real hourly earnings (\textit{Log hourly wage})---both wage measures"
        r" computed from the worker-level dataset---and the number of clauses in the"
        r" relevant collective bargaining agreement (\textit{CBA clauses}), which is"
        r" only defined for firms with a CBA."
        r" Hourly wage is unavailable for exiting firms not in the balanced sample."
        r" Fixed effects absorb firm, industry $\times$ year, microregion $\times$ year,"
        r" and CBA base month $\times$ year."
        r" The CBA-clauses specification uses CBA-period fixed effects in place of year fixed effects."
        r" All specifications include pre-treatment quartile bins of the outcome and of log employment"
        r" interacted with year (CBA period) fixed effects, and quartile bins of 2007--2011 average"
        r" pairwise total flows interacted with year fixed effects."
        r" Exiting firms not in the balanced sample have their industry inferred from CNAE 2.0 codes"
        r" in the RAIS 2009 establishment file."
        r" Standard errors clustered at the establishment level."
        r" Significance: $^{*}p{<}0.10$, $^{**}p{<}0.05$, $^{***}p{<}0.01$."
    )

    a(r"\begin{minipage}{\textwidth}")
    a(r"\footnotesize")
    a(r"\medskip")
    a(r"\textit{Notes}: " + base_note)
    a(r"\end{minipage}")
    a(r"\end{table}")

    fout.write("\n".join(lines) + "\n")


# Load all three panels' data and write the combined table
panels_data = []
for panel, label in PANEL_CONFIGS:
    csv_full = tables_in / f"results_direct_panel{panel}_full_{SPEC}.csv"
    csv_pre  = tables_in / f"results_direct_panel{panel}_pre_{SPEC}.csv"
    panels_data.append((label, read_csv(csv_full), read_csv(csv_pre)))

out_path_direct = tables_out / f"direct_combined_{SPEC}.tex"
with open(out_path_direct, "w") as f:
    write_direct_combined(f, panels_data)
print(f"Wrote {out_path_direct}")

# ---------------------------------------------------------------------------
# SPILLOVER EFFECTS TABLE
# ---------------------------------------------------------------------------

csv_spill_full = tables_in / f"results_spill_full_{SPEC}.csv"
csv_spill_pre  = tables_in / f"results_spill_pre_{SPEC}.csv"

data_spill_full = read_csv(csv_spill_full)
data_spill_pre  = read_csv(csv_spill_pre)

out_path_spill = tables_out / f"spill_{SPEC}.tex"
with open(out_path_spill, "w") as f:
    write_table(
        f,
        "Spillover Effects",
        data_spill_full,
        data_spill_pre,
        is_spill=True,
    )

print(f"Wrote {out_path_spill}")
print("Done.")
