"""
Assemble horse race table from 13f_horse_race_binary.do output.

Panels:
  A. edu2
  B. gender
  C. race

Output:
  Tables/layer_connectivity/table_horse_race_binary.tex
  Tables/layer_connectivity/table_horse_race_binary.csv
"""

from pathlib import Path
import pandas as pd

PROJ = Path(__file__).resolve().parent.parent.parent
TABLES = PROJ / "Tables" / "layer_connectivity"
TEX_TABLES = TABLES / "tex_tables"
CSV_IN = TABLES / "results_horse_race_binary.csv"

PANELS = [
    {"key": "edu2", "title": "2-bin education (no HS / has HS)", "v1": "no_hs", "v2": "has_hs", "lab1": "No HS", "lab2": "Has HS"},
    {"key": "gender", "title": "Gender (female / male)", "v1": "female", "v2": "male", "lab1": "Female", "lab2": "Male"},
    {"key": "race", "title": "Race (white / nonwhite)", "v1": "white", "v2": "nonwhite", "lab1": "White", "lab2": "Nonwhite"},
]


def load_csv(path: Path) -> dict:
    data = {}
    with open(path) as f:
        for i, line in enumerate(f):
            line = line.rstrip("\n")
            if i == 0:
                continue
            parts = [p.strip('"') for p in line.split(";")]
            if len(parts) >= 6:
                data[(parts[1], parts[2], parts[3], parts[4])] = parts[5]
    return data


def get(data, panel, section, outcome, row_type, default="--"):
    return data.get((panel, section, outcome, row_type), default)


def tex_name(s: str) -> str:
    """Escape underscores for use inside LaTeX \\text{}."""
    return s.replace("_", r"\_")


def fmt_coef(v: str) -> str:
    return v.strip() if v.strip() not in ("", "--") else "--"


def fmt_se(v: str) -> str:
    s = v.strip()
    if s in ("", "--"):
        return "--"
    try:
        return f"({float(s):.4f})"
    except ValueError:
        return s


def fmt_stat(v: str, is_pval: bool = False) -> str:
    s = v.strip()
    if s in ("", "--"):
        return "---"
    if is_pval:
        try:
            return f"{float(s):.3f}"
        except ValueError:
            return s
    return s


def fmt_n(v: str) -> str:
    s = v.strip()
    if s in ("", "--"):
        return "---"
    try:
        return f"{int(float(s)):,}"
    except ValueError:
        return s


def panel_cols(panel_cfg: dict):
    v1 = panel_cfg["v1"]
    v2 = panel_cfg["v2"]
    lab1 = panel_cfg["lab1"]
    lab2 = panel_cfg["lab2"]
    return [
        (lab1, "layer_firm_year", f"lr_remdezr_layer_{v1}"),
        (lab2, "layer_firm_year", f"lr_remdezr_layer_{v2}"),
        ("Firm", "firm_firm_year", "lr_remdezr_w"),
        (lab1, "layer_firm_year", f"l_layer_emp_{v1}"),
        (lab2, "layer_firm_year", f"l_layer_emp_{v2}"),
        ("Firm", "firm_firm_year", "l_firm_emp"),
    ]


def build_latex(data: dict, caption: str, label: str) -> str:
    lines = [
        r"\begin{table}[H]",
        r"\centering",
        r"\caption{" + caption + r"}",
        r"\label{" + label + r"}",
        r"\resizebox{\textwidth}{!}{%",
        r"\begin{tabular}{lcccccc}",
        r"\toprule\toprule",
        r" & \multicolumn{3}{c}{Log Dec.\ wage} & \multicolumn{3}{c}{Log employment} \\",
        r"\cmidrule(lr){2-4}\cmidrule(lr){5-7}",
        r" & Group 1 & Group 2 & Firm & Group 1 & Group 2 & Firm \\",
        r"\midrule",
    ]

    for pi, panel in enumerate(PANELS):
        cols = panel_cols(panel)
        lines.append(
            r"\multicolumn{7}{l}{\textit{Panel "
            + chr(ord("A") + pi)
            + r": "
            + panel["title"]
            + r"}} \\"
        )
        lines.append(" & ".join(["", panel["lab1"], panel["lab2"], "Firm", panel["lab1"], panel["lab2"], "Firm"]) + r" \\")

        for label_row, row_type, se_type in [
            (rf"$c_{{\text{{{tex_name(panel['v1'])}}}}} \times \text{{Post}}$", f"c_{panel['v1']}_main", f"c_{panel['v1']}_main_se"),
            (rf"$c_{{\text{{{tex_name(panel['v2'])}}}}} \times \text{{Post}}$", f"c_{panel['v2']}_main", f"c_{panel['v2']}_main_se"),
            (rf"Pre: $c_{{\text{{{tex_name(panel['v1'])}}}}}$", f"c_{panel['v1']}_pre", f"c_{panel['v1']}_pre_se"),
            (rf"Pre: $c_{{\text{{{tex_name(panel['v2'])}}}}}$", f"c_{panel['v2']}_pre", f"c_{panel['v2']}_pre_se"),
        ]:
            cells = [label_row]
            for _, section, outcome in cols:
                cells.append(fmt_coef(get(data, panel["key"], section, outcome, row_type)))
            lines.append(" & ".join(cells) + r" \\")
            cells = [""]
            for _, section, outcome in cols:
                cells.append(fmt_se(get(data, panel["key"], section, outcome, se_type)))
            lines.append(" & ".join(cells) + r" \\")

        for stat_label, row_type, fmt_fn in [
            ("Observations", "n_obs", fmt_n),
            ("Firms", "n_firms", fmt_n),
            (rf"Pre-F $p$: $c_{{\text{{{tex_name(panel['v1'])}}}}}$", f"c_{panel['v1']}_pre_ftest", lambda v: fmt_stat(v, True)),
            (rf"Pre-F $p$: $c_{{\text{{{tex_name(panel['v2'])}}}}}$", f"c_{panel['v2']}_pre_ftest", lambda v: fmt_stat(v, True)),
        ]:
            cells = [stat_label]
            for _, section, outcome in cols:
                cells.append(fmt_fn(get(data, panel["key"], section, outcome, row_type)))
            lines.append(" & ".join(cells) + r" \\")

        if pi < len(PANELS) - 1:
            lines.append(r"\\[4pt]")

    lines += [
        r"\midrule",
        " & ".join(["Firm FE"] + [r"\checkmark"] * 6) + r" \\",
        " & ".join(["Year FE"] + [r"\checkmark"] * 6) + r" \\",
        " & ".join(["Layer-level", r"\checkmark", r"\checkmark", "---", r"\checkmark", r"\checkmark", "---"]) + r" \\",
        " & ".join(["Firm-level", "---", "---", r"\checkmark", "---", "---", r"\checkmark"]) + r" \\",
        r"\bottomrule",
        r"\end{tabular}}",
        r"\begin{minipage}{\linewidth}",
        r"\scriptsize\vspace{4pt}",
        r"\textit{Notes:} Each panel reports horse-race regressions that include both layer-connectivity variables "
        r"simultaneously. Columns (1)--(2) and (4)--(5) are layer-level regressions by outcome layer; "
        r"columns (3) and (6) are firm-level regressions. All regressions are restricted to untreated firms in the "
        r"balanced firm panel, but do not require balanced layer presence across all years. "
        r"Connectivity is scaled to the 90th percentile of the control sample at 2009. "
        r"Standard errors clustered at the firm level. "
        r"$^{***}p<0.01$, $^{**}p<0.05$, $^{*}p<0.10$.",
        r"\end{minipage}",
        r"\end{table}",
    ]
    return "\n".join(lines)


def build_csv(data: dict) -> pd.DataFrame:
    rows = []
    for panel in PANELS:
        cols = panel_cols(panel)
        row_types = [
            f"c_{panel['v1']}_main",
            f"c_{panel['v1']}_main_se",
            f"c_{panel['v2']}_main",
            f"c_{panel['v2']}_main_se",
            f"c_{panel['v1']}_pre",
            f"c_{panel['v1']}_pre_se",
            f"c_{panel['v2']}_pre",
            f"c_{panel['v2']}_pre_se",
            f"c_{panel['v1']}_pre_ftest",
            f"c_{panel['v2']}_pre_ftest",
            "n_obs",
            "n_firms",
        ]
        for row_type in row_types:
            for col_label, section, outcome in cols:
                rows.append(
                    {
                        "panel": panel["key"],
                        "column": col_label,
                        "section": section,
                        "outcome": outcome,
                        "row_type": row_type,
                        "value": get(data, panel["key"], section, outcome, row_type),
                    }
                )
    return pd.DataFrame(rows)


if not CSV_IN.exists():
    raise SystemExit(f"ERROR: results file not found — run 13f_horse_race_binary.do first:\n  {CSV_IN}")

data = load_csv(CSV_IN)
TABLES.mkdir(parents=True, exist_ok=True)

tex_out = TEX_TABLES / "table_horse_race_binary.tex"
csv_out = TABLES / "table_horse_race_binary.csv"
tex_out.write_text(build_latex(data, "Horse race across binary layers", "tab:horse_race_binary"))
build_csv(data).to_csv(csv_out, index=False)

print(f"Wrote: {tex_out}")
print(f"Wrote: {csv_out}")
