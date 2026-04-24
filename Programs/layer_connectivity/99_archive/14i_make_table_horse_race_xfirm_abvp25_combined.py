"""
Assemble a single horse race table (cross-firm FE, above-p25 both layers)
with three panels — one per layer definition (edu2, gender, race).

Reads:
  Tables/layer_connectivity/results_horse_race_{edu2,gender,race}_xfirm_abvp25.csv

Output:
  Tables/layer_connectivity/table_horse_race_xfirm_abvp25_combined.tex
  Tables/layer_connectivity/table_horse_race_xfirm_abvp25_combined.csv

Usage:
  ~/.conda/envs/venv_python312/bin/python Programs/layer_connectivity/14i_make_table_horse_race_xfirm_abvp25_combined.py
"""

from pathlib import Path
import pandas as pd

PROJ   = Path(__file__).resolve().parent.parent.parent
TABLES = PROJ / "Tables" / "layer_connectivity"

LAYER_CONFIG = {
    "edu2": {
        "lv1":        "no_hs",
        "lv2":        "has_hs",
        "lv1_label":  "No HS",
        "lv2_label":  "Has HS",
        "lv1_tex":    r"no\_hs",
        "lv2_tex":    r"has\_hs",
        "panel_desc": "Education (no HS / has HS)",
    },
    "gender": {
        "lv1":        "female",
        "lv2":        "male",
        "lv1_label":  "Female",
        "lv2_label":  "Male",
        "lv1_tex":    "female",
        "lv2_tex":    "male",
        "panel_desc": "Gender (female / male)",
    },
    "race": {
        "lv1":        "nonwhite",
        "lv2":        "white",
        "lv1_label":  "Non-white",
        "lv2_label":  "White",
        "lv1_tex":    "nonwhite",
        "lv2_tex":    "white",
        "panel_desc": "Race (non-white / white)",
    },
}

LAYERS = ["edu2", "gender", "race"]


# ── CSV loader ─────────────────────────────────────────────────────────────────
def load_csv(path: Path) -> dict:
    data = {}
    with open(path) as f:
        for i, line in enumerate(f):
            line = line.rstrip("\n")
            if i == 0:
                continue
            parts = [p.strip('"') for p in line.split(";")]
            if len(parts) >= 5:
                key = (parts[1], parts[2], parts[3])  # (section, outcome, row_type)
                data[key] = parts[4]
    return data


# ── Formatting ─────────────────────────────────────────────────────────────────
def get(data, section, outcome, row_type, default="--"):
    return data.get((section, outcome, row_type), default)

def fmt_coef(v):
    return v.strip() if v.strip() not in ("--", "") else "--"

def fmt_se(v):
    s = v.strip()
    if s in ("--", ""):
        return "--"
    try:
        return f"({float(s):.4f})"
    except ValueError:
        return s

def fmt_stat(v, is_pval=False):
    s = v.strip()
    if s in ("--", ""):
        return "---"
    if is_pval:
        try:
            return f"{float(s):.3f}"
        except ValueError:
            return s
    return s

def fmt_n(v):
    s = v.strip()
    if s in ("--", ""):
        return "---"
    try:
        return f"{int(float(s)):,}"
    except ValueError:
        return s


# ── Panel builder ──────────────────────────────────────────────────────────────
def panel_rows(data: dict, cfg: dict, panel_letter: str) -> list:
    lv1, lv2 = cfg["lv1"], cfg["lv2"]
    lv1_tex, lv2_tex = cfg["lv1_tex"], cfg["lv2_tex"]
    lv1_lbl, lv2_lbl = cfg["lv1_label"], cfg["lv2_label"]

    # Column layout: [lv1_wage, lv2_wage, firm_wage, lv1_emp, lv2_emp, firm_emp]
    WAGE_COLS = [
        ("layer_cross_firm", f"lr_remdezr_layer_{lv1}"),
        ("layer_cross_firm", f"lr_remdezr_layer_{lv2}"),
        ("firm_cross_firm",  "lr_remdezr_w"),
    ]
    EMP_COLS = [
        ("layer_cross_firm", f"l_layer_emp_{lv1}"),
        ("layer_cross_firm", f"l_layer_emp_{lv2}"),
        ("firm_cross_firm",  "l_firm_emp"),
    ]
    ALL_COLS = WAGE_COLS + EMP_COLS

    lines = []

    # Panel header
    lines.append(
        r"\multicolumn{7}{l}{\textit{Panel " + panel_letter
        + r": " + cfg["panel_desc"] + r"}} \\"
    )

    # Layer-specific column sub-headers (lv1, lv2, Firm × 2 outcome groups)
    sub = [r"\quad"]
    for lbl in [lv1_lbl, lv2_lbl, "Firm", lv1_lbl, lv2_lbl, "Firm"]:
        sub.append(r"\textit{" + lbl + r"}")
    lines.append(" & ".join(sub) + r" \\[-2pt]")
    lines.append(r"\cmidrule(lr){2-4}\cmidrule(lr){5-7}")

    def coef_row(row_label, rt_coef, rt_se):
        cells = [row_label]
        for sec, out in ALL_COLS:
            cells.append(fmt_coef(get(data, sec, out, rt_coef)))
        lines.append(" & ".join(cells) + r" \\")
        cells = [""]
        for sec, out in ALL_COLS:
            cells.append(fmt_se(get(data, sec, out, rt_se)))
        lines.append(" & ".join(cells) + r" \\")

    coef_row(
        rf"\quad $c_{{\text{{{lv1_tex}}}}} \times \text{{Post}}$",
        f"c_{lv1}_main", f"c_{lv1}_main_se",
    )
    coef_row(
        rf"\quad $c_{{\text{{{lv2_tex}}}}} \times \text{{Post}}$",
        f"c_{lv2}_main", f"c_{lv2}_main_se",
    )
    coef_row(
        rf"\quad Pre: $c_{{\text{{{lv1_tex}}}}}$",
        f"c_{lv1}_pre", f"c_{lv1}_pre_se",
    )
    coef_row(
        rf"\quad Pre: $c_{{\text{{{lv2_tex}}}}}$",
        f"c_{lv2}_pre", f"c_{lv2}_pre_se",
    )

    for stat_label, rt, fmt_fn in [
        (r"\quad Observations", "n_obs",   fmt_n),
        (r"\quad Firms",        "n_firms",  fmt_n),
        (rf"\quad Pre-F $p$: $c_{{\text{{{lv1_tex}}}}}$",
         f"c_{lv1}_pre_ftest", lambda v: fmt_stat(v, is_pval=True)),
        (rf"\quad Pre-F $p$: $c_{{\text{{{lv2_tex}}}}}$",
         f"c_{lv2}_pre_ftest", lambda v: fmt_stat(v, is_pval=True)),
    ]:
        cells = [stat_label]
        for sec, out in ALL_COLS:
            cells.append(fmt_fn(get(data, sec, out, rt)))
        lines.append(" & ".join(cells) + r" \\")

    return lines


# ── Build combined LaTeX table ─────────────────────────────────────────────────
def build_latex(all_data: dict) -> str:
    lines = []

    caption = (
        r"Horse race: layer connectivity simultaneously (cross-firm FE, above-p25 both layers)"
    )
    label = "tab:horse_race_xfirm_abvp25_combined"

    lines.append(r"\begin{table}[H]")
    lines.append(r"\centering")
    lines.append(r"\caption{" + caption + r"}")
    lines.append(r"\label{" + label + r"}")
    lines.append(r"\scriptsize")
    lines.append(r"\begin{threeparttable}")
    lines.append(r"\begin{tabular}{lcccccc}")
    lines.append(r"\toprule\toprule")

    # Top-level outcome headers
    lines.append(r" & \multicolumn{3}{c}{Log Dec.\ wage} & \multicolumn{3}{c}{Log employment} \\")
    lines.append(r"\cmidrule(lr){2-4}\cmidrule(lr){5-7}")
    lines.append(r" & (1) & (2) & (3) & (4) & (5) & (6) \\")
    lines.append(r"\midrule")

    for pi, layer in enumerate(LAYERS):
        panel_letter = chr(ord("A") + pi)
        cfg = LAYER_CONFIG[layer]
        data = all_data[layer]
        lines += panel_rows(data, cfg, panel_letter)
        if pi < len(LAYERS) - 1:
            lines.append(r"\\[-2pt]")

    lines.append(r"\midrule")

    # FE checkmarks — same for all columns
    chk = r"\checkmark"
    for row_label, marks in [
        (r"Microregion $\times$ Year FE", [chk]*6),
        (r"Industry $\times$ Year FE",    [chk]*6),
        (r"Mode $\times$ Year FE",        [chk]*6),
        ("Layer-level",  [chk, chk, "---", chk, chk, "---"]),
        ("Firm-level",   ["---", "---", chk, "---", "---", chk]),
    ]:
        lines.append(" & ".join([row_label] + marks) + r" \\")

    lines.append(r"\bottomrule")
    lines.append(r"\end{tabular}")
    lines.append(r"\begin{tablenotes}[flushleft]")
    lines.append(
        r"\item \textit{Notes:} Each panel includes both layer connectivity variables simultaneously. "
        r"Panel A partitions workers by 2-bin education (no HS / has HS); "
        r"Panel B by gender (female / male); "
        r"Panel C by race (non-white / white). "
        r"The sample is restricted to firms where both layers had above-p25 average employment "
        r"in the pre-treatment period (2009--2011), where p25 is the 25th percentile of "
        r"average pre-treatment layer employment across firms with both layers present. "
        r"Columns (1)--(2) and (4)--(5) are layer-level regressions restricted to the indicated "
        r"worker layer; columns (3) and (6) are firm-level regressions collapsed to firm$\times$year. "
        r"All specifications absorb microregion$\times$year, industry$\times$year, and "
        r"mode$\times$year fixed effects. "
        r"The post-treatment indicator equals one for years $\geq 2012$ (S\'{u}mula 277 reform). "
        r"All regressions restricted to untreated, balanced-panel firms. "
        r"Connectivity scaled to the 90th percentile of the control sample at 2009. "
        r"Standard errors clustered at the firm level. "
        r"$^{***}p<0.01$, $^{**}p<0.05$, $^{*}p<0.10$."
    )
    lines.append(r"\end{tablenotes}")
    lines.append(r"\end{threeparttable}")
    lines.append(r"\end{table}")
    return "\n".join(lines)


# ── Main ───────────────────────────────────────────────────────────────────────
TABLES.mkdir(parents=True, exist_ok=True)

all_data = {}
for layer in LAYERS:
    csv_in = TABLES / f"results_horse_race_{layer}_xfirm_abvp25.csv"
    if not csv_in.exists():
        raise SystemExit(f"Missing: {csv_in}. Run 13f first.")
    all_data[layer] = load_csv(csv_in)
    print(f"Loaded {len(all_data[layer])} entries from {csv_in.name}")

tex = build_latex(all_data)

tex_out = TABLES / "table_horse_race_xfirm_abvp25_combined.tex"
tex_out.write_text(tex)
print(f"Wrote: {tex_out}")
