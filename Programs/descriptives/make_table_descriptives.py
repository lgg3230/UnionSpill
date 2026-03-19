"""
make_table_descriptives.py
--------------------------
Reads descriptive_stats_2011.csv and descriptive_stats_pretreat.csv from
Tables/descriptives/ and produces two LaTeX tables:
  table_descriptives_2011.tex
  table_descriptives_pretreat.tex

Row format in the CSVs (semicolon-delimited):
  statistic;Overall;Treated;Untreated;Untreated_Conn;Untreated_Zero
"""

from pathlib import Path
import csv

# ── Paths ────────────────────────────────────────────────────────────────────
SCRIPT_DIR   = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent.parent
TABLES_DIR   = PROJECT_ROOT / "Tables" / "descriptives"

# ── Helper: read CSV into an ordered dict keyed by statistic name ─────────────
def read_csv(path: Path) -> dict:
    data = {}
    with open(path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f, delimiter=";")
        for row in reader:
            key = row["statistic"].strip()
            data[key] = {
                "Overall":        row["Overall"].strip(),
                "Treated":        row["Treated"].strip(),
                "Untreated":      row["Untreated"].strip(),
                "Untreated_Conn": row["Untreated_Conn"].strip(),
                "Untreated_Zero": row["Untreated_Zero"].strip(),
            }
    return data


# ── Helper: format a value for a given row type ───────────────────────────────
def fmt(value: str, row_type: str) -> str:
    """Return a nicely formatted string for the LaTeX table cell."""
    try:
        v = float(value)
    except (ValueError, TypeError):
        return "--"

    if row_type == "count_large":   # N establishments, total workers
        return f"{v:,.0f}"
    elif row_type == "count":        # mean estab size, network size
        return f"{v:,.1f}"
    elif row_type == "prop":         # proportions in [0,1]
        return f"{v:.2f}"
    elif row_type == "wage":         # wages in BRL
        return f"{v:,.0f}"
    elif row_type == "clauses":      # clause count
        return f"{v:.1f}"
    elif row_type == "ratio":        # p90/p10 etc.
        return f"{v:.2f}"
    elif row_type == "conn":         # connectivity (small decimals)
        return f"{v:.3f}"
    elif row_type == "flows":        # total flows per worker
        return f"{v:.3f}"
    elif row_type == "years":        # age / tenure
        return f"{v:.1f}"
    elif row_type == "int":          # integer-like (median network size)
        return f"{int(round(v))}"
    else:
        return f"{v:.3f}"


# ── Row spec: (csv_key, display_label, fmt_type) ─────────────────────────────
# Panels are separated by None entries (produce blank rows in LaTeX).

PANEL_A = [
    ("N establishments",  "Number of establishments",   "count_large"),
    ("Total workers",     "Total workers",               "count_large"),
    ("Mean estab size",   "Mean establishment size",     "count"),
]

PANEL_B = [
    ("Share 1-10 emp",    "1--10 employees",   "prop"),
    ("Share 11-30 emp",   "11--30 employees",  "prop"),
    ("Share 31-100 emp",  "31--100 employees", "prop"),
    ("Share 101+ emp",    "101+ employees",    "prop"),
]

PANEL_C = [
    ("Prop high school",    "High school",        "prop"),
    ("Prop higher ed",      "Higher education",   "prop"),
    ("Prop female",         "Female",             "prop"),
    ("Prop non-white",      "Non-white",          "prop"),
    ("Mean worker age",     "Mean age (years)",   "years"),
    ("Mean worker tenure",  "Mean tenure (years)", "years"),
]

PANEL_D = [
    ("Mean dec wages",       "Mean wages (2015, BRL)",       "wage"),
    ("Mean of median wages", "Mean of within-firm median",   "wage"),
    ("Mean clause count",    "Mean clause count",            "clauses"),
]

PANEL_E = [
    ("p90/p10", "p90/p10", "ratio"),
    ("p90/p50", "p90/p50", "ratio"),
    ("p50/p10", "p50/p10", "ratio"),
]

PANEL_F = [
    ("Mean connectivity",         "Mean connectivity",               "conn"),
    ("Median connectivity",       "Median connectivity",             "conn"),
    ("Mean total flows pw 07-11", "Mean total worker flows pw",      "flows"),
    ("Mean network size",         "Mean network size",               "count"),
    ("Median network size",       "Median network size",             "int"),
    ("Mean treated connections",  "Mean treated connections",        "count"),
]

PANELS = [
    ("Panel A: Sample Characteristics",               PANEL_A),
    ("Panel B: Firm Size (\\% of firms)",             PANEL_B),
    ("Panel C: Workforce Demographics",               PANEL_C),
    ("Panel D: Wages and Collective Bargaining",      PANEL_D),
    ("Panel E: Within-Firm Wage Inequality",          PANEL_E),
    ("Panel F: Worker Flows and Network Structure",   PANEL_F),
]

COLS = ["Overall", "Treated", "Untreated", "Untreated_Conn", "Untreated_Zero"]


# ── Build LaTeX table ─────────────────────────────────────────────────────────
def build_table(data: dict, caption: str, label: str, notes: str) -> str:
    lines = []
    a = lines.append

    a(r"\begin{table}[H]")
    a(r"\centering")
    a(rf"\caption{{{caption}}}")
    a(rf"\label{{{label}}}")
    a(r"\scriptsize")
    a(r"\begin{threeparttable}")
    a(r"\begin{tabular}{lccccc}")
    a(r"\toprule\toprule")
    a(r" & \multicolumn{1}{c}{Overall} & \multicolumn{1}{c}{Treated} "
      r"& \multicolumn{1}{c}{Untreated} & \multicolumn{2}{c}{Untreated by Connectivity} \\")
    a(r" \cmidrule(lr){5-6}")
    a(r" & & & & Connected & Zero \\")
    a(r" & (1) & (2) & (3) & (4) & (5) \\")
    a(r"\midrule")

    for panel_title, rows in PANELS:
        a(rf"\multicolumn{{6}}{{l}}{{\textit{{{panel_title}}}}} \\[0.5ex]")
        for csv_key, label_str, fmt_type in rows:
            if csv_key not in data:
                # skip silently if variable wasn't in the CSV
                continue
            cells = [fmt(data[csv_key][c], fmt_type) for c in COLS]
            row_str = " & ".join([""] + cells) + r" \\"
            a(f"{label_str}{row_str}")
        a(r"&&&&& \\")

    # Remove trailing blank spacer after last panel
    lines.pop()

    a(r"\bottomrule")
    a(r"\end{tabular}")
    a(r"\scriptsize")
    a(r"\begin{tablenotes}")
    a(rf"    \item \textit{{Notes:}} {notes}")
    a(r"\end{tablenotes}")
    a(r"\end{threeparttable}")
    a(r"\end{table}")

    return "\n".join(lines)


# ── Notes text ────────────────────────────────────────────────────────────────
NOTES_2011 = (
    "This table presents establishment-level descriptive statistics for the "
    "analysis sample measured in 2011, the last pre-treatment year. "
    "Column (1) includes all establishments in the balanced panel. "
    "Column (2) restricts to treated establishments---those covered by collective "
    "bargaining agreements that acquired ultractivity protection under the 2012 reform. "
    "Column (3) includes untreated establishments. "
    "Columns (4) and (5) further decompose the untreated sample by connectivity to "
    "treated establishments in 2011: ``Connected'' establishments (column 4) received "
    "at least one worker from a treated establishment, while ``Zero'' connectivity "
    "establishments (column 5) received none. "
    "Panel B reports the share of establishments in each size bin based on 2011 employment. "
    "Panel C reports establishment-level averages of worker shares by demographic group; "
    "education categories refer to workers' highest completed level. "
    "Mean age and mean tenure are averages across all December employees within the establishment. "
    "Wages are measured as December average earnings in 2015 Brazilian Reais. "
    "Within-firm inequality measures are ratios of within-establishment wage percentiles. "
    "Connectivity measures the share of an establishment's workforce that came from or left "
    "to treated establishments. "
    "Mean total worker flows per worker (pw) is the average yearly per-worker pairwise flow "
    "rate over 2007--2011 (pre-treatment). "
    "Network size is the total number of distinct establishments connected via worker flows; "
    "treated connections is the number of connected establishments that are treated. "
    "Clause count refers to the number of provisions in the establishment's collective "
    "bargaining agreement (measured in the first CBA period)."
)

NOTES_PRETREAT = (
    "This table presents establishment-level descriptive statistics for the "
    "analysis sample, using pre-treatment averages over 2009--2011 at the firm level. "
    "Column (1) includes all establishments in the balanced panel. "
    "Column (2) restricts to treated establishments---those covered by collective "
    "bargaining agreements that acquired ultractivity protection under the 2012 reform. "
    "Column (3) includes untreated establishments. "
    "Columns (4) and (5) further decompose the untreated sample by average connectivity "
    "to treated establishments over 2009--2011: ``Connected'' establishments (column 4) "
    "had positive average connectivity, while ``Zero'' connectivity establishments "
    "(column 5) had none. "
    "Panel B reports the share of establishments in each size bin based on average "
    "pre-treatment employment. "
    "Panel C reports establishment-level averages of worker shares by demographic group; "
    "education categories refer to workers' highest completed level. "
    "Mean age and mean tenure are averages across all December employees within the "
    "establishment, averaged over 2009--2011. "
    "Wages are measured as December average earnings in 2015 Brazilian Reais. "
    "Within-firm inequality measures are ratios of within-establishment wage percentiles. "
    "Connectivity measures the share of an establishment's workforce that came from or left "
    "to treated establishments (pre-treatment average). "
    "Mean total worker flows per worker (pw) is the average yearly per-worker pairwise flow "
    "rate over 2007--2011 (pre-treatment). "
    "Network size is the total number of distinct establishments connected via worker flows; "
    "treated connections is the number of connected establishments that are treated. "
    "Clause count refers to the number of provisions in the establishment's collective "
    "bargaining agreement (measured in the first CBA period)."
)


# ── Main ──────────────────────────────────────────────────────────────────────
def main():
    for suffix, caption, label, notes in [
        (
            "2011",
            "Descriptive Statistics by Treatment and Connectivity Status (2011)",
            "tab:descriptive_stats_2011",
            NOTES_2011,
        ),
        (
            "pretreat",
            "Descriptive Statistics by Treatment and Connectivity Status (Pre-treatment Average, 2009--2011)",
            "tab:descriptive_stats_pretreat",
            NOTES_PRETREAT,
        ),
    ]:
        csv_path = TABLES_DIR / f"descriptive_stats_{suffix}.csv"
        if not csv_path.exists():
            print(f"WARNING: {csv_path} not found — skipping.")
            continue

        data = read_csv(csv_path)
        tex  = build_table(data, caption, label, notes)

        out_path = TABLES_DIR / f"table_descriptives_{suffix}.tex"
        out_path.write_text(tex, encoding="utf-8")
        print(f"Saved: {out_path}")


if __name__ == "__main__":
    main()
