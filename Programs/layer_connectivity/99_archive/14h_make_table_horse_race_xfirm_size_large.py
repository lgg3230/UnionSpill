"""
Assemble horse race tables (cross-firm FE, large firms — above-median firm employment)
from 13g_horse_race_xfirm_size_large.do output — one table per layer + one combined.

Reads:
  Tables/layer_connectivity/results_horse_race_{edu2,gender,race}_xfirm_size_large.csv

Outputs (per layer):
  Tables/layer_connectivity/table_horse_race_{edu2,gender,race}_xfirm_size_large.tex / .csv

Combined (all three panels):
  Tables/layer_connectivity/table_horse_race_all_xfirm_size_large.tex / .csv

Usage:
  ~/.conda/envs/venv_python312/bin/python Programs/layer_connectivity/14h_make_table_horse_race_xfirm_size_large.py
"""

from pathlib import Path
import pandas as pd

PROJ   = Path(__file__).resolve().parent.parent.parent
TABLES = PROJ / "Tables" / "layer_connectivity"

# ── Layer configuration ────────────────────────────────────────────────────────
LAYER_CONFIG = {
    "edu2": {
        "lv1":        "no_hs",
        "lv2":        "has_hs",
        "lv1_label":  "No HS",
        "lv2_label":  "Has HS",
        "lv1_tex":    r"no\_hs",
        "lv2_tex":    r"has\_hs",
        "panel_desc": "2-bin education",
        "caption":    r"Horse race: $c_{\text{no\_hs}}$ vs.\ $c_{\text{has\_hs}}$ simultaneously (cross-firm FE, large firms)",
        "label":      "tab:horse_race_edu2_xfirm_size_large",
    },
    "gender": {
        "lv1":        "female",
        "lv2":        "male",
        "lv1_label":  "Female",
        "lv2_label":  "Male",
        "lv1_tex":    "female",
        "lv2_tex":    "male",
        "panel_desc": "gender",
        "caption":    r"Horse race: $c_{\text{female}}$ vs.\ $c_{\text{male}}$ simultaneously (cross-firm FE, large firms)",
        "label":      "tab:horse_race_gender_xfirm_size_large",
    },
    "race": {
        "lv1":        "nonwhite",
        "lv2":        "white",
        "lv1_label":  "Non-white",
        "lv2_label":  "White",
        "lv1_tex":    "nonwhite",
        "lv2_tex":    "white",
        "panel_desc": "race",
        "caption":    r"Horse race: $c_{\text{nonwhite}}$ vs.\ $c_{\text{white}}$ simultaneously (cross-firm FE, large firms)",
        "label":      "tab:horse_race_race_xfirm_size_large",
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


# ── LaTeX builder ──────────────────────────────────────────────────────────────
def build_latex(data: dict, cfg: dict, caption: str, label: str) -> str:
    lv1, lv2 = cfg["lv1"], cfg["lv2"]
    lv1_tex, lv2_tex = cfg["lv1_tex"], cfg["lv2_tex"]
    lv1_lbl, lv2_lbl = cfg["lv1_label"], cfg["lv2_label"]

    WAGE_COLS = [
        (lv1_lbl, "layer_cross_firm", f"lr_remdezr_layer_{lv1}"),
        (lv2_lbl, "layer_cross_firm", f"lr_remdezr_layer_{lv2}"),
        ("Firm",   "firm_cross_firm",  "lr_remdezr_w"),
    ]
    EMP_COLS = [
        (lv1_lbl, "layer_cross_firm", f"l_layer_emp_{lv1}"),
        (lv2_lbl, "layer_cross_firm", f"l_layer_emp_{lv2}"),
        ("Firm",   "firm_cross_firm",  "l_firm_emp"),
    ]
    ALL_COLS = WAGE_COLS + EMP_COLS

    lines = []
    col_spec = "l" + "c" * len(ALL_COLS)
    lines.append(r"\begin{table}[H]")
    lines.append(r"\centering")
    lines.append(r"\caption{" + caption + r"}")
    lines.append(r"\label{" + label + r"}")
    lines.append(r"\resizebox{\textwidth}{!}{%")
    lines.append(r"\begin{tabular}{" + col_spec + r"}")
    lines.append(r"\toprule\toprule")

    lines.append(r" & \multicolumn{3}{c}{Log Dec.\ wage} & \multicolumn{3}{c}{Log employment} \\")
    lines.append(r"\cmidrule(lr){2-4}\cmidrule(lr){5-7}")

    h2 = [""]
    for ci, (col_label, _, _) in enumerate(ALL_COLS, start=1):
        h2.append(r"\shortstack{" + col_label + r" \\ (" + str(ci) + r")}")
    lines.append(" & ".join(h2) + r" \\")
    lines.append(r"\midrule")

    def coef_block(rt_lv1_coef, rt_lv1_se, rt_lv2_coef, rt_lv2_se,
                   tex_lv1_row, tex_lv2_row):
        result = []
        for tex_row, rt_coef, rt_se in [
            (tex_lv1_row, rt_lv1_coef, rt_lv1_se),
            (tex_lv2_row, rt_lv2_coef, rt_lv2_se),
        ]:
            cells = [tex_row]
            for _, section, outcome in ALL_COLS:
                cells.append(fmt_coef(get(data, section, outcome, rt_coef)))
            result.append(" & ".join(cells) + r" \\")
            cells = [""]
            for _, section, outcome in ALL_COLS:
                cells.append(fmt_se(get(data, section, outcome, rt_se)))
            result.append(" & ".join(cells) + r" \\")
        return result

    lines += coef_block(
        f"c_{lv1}_main", f"c_{lv1}_main_se",
        f"c_{lv2}_main", f"c_{lv2}_main_se",
        rf"$c_{{\text{{{lv1_tex}}}}} \times \text{{Post}}$",
        rf"$c_{{\text{{{lv2_tex}}}}} \times \text{{Post}}$",
    )
    lines += coef_block(
        f"c_{lv1}_pre", f"c_{lv1}_pre_se",
        f"c_{lv2}_pre", f"c_{lv2}_pre_se",
        rf"Pre: $c_{{\text{{{lv1_tex}}}}}$",
        rf"Pre: $c_{{\text{{{lv2_tex}}}}}$",
    )

    for stat_label, rt, fmt_fn in [
        ("Observations",                            "n_obs",              fmt_n),
        ("Firms",                                   "n_firms",            fmt_n),
        (rf"Pre-F $p$: $c_{{\text{{{lv1_tex}}}}}$", f"c_{lv1}_pre_ftest", lambda v: fmt_stat(v, is_pval=True)),
        (rf"Pre-F $p$: $c_{{\text{{{lv2_tex}}}}}$", f"c_{lv2}_pre_ftest", lambda v: fmt_stat(v, is_pval=True)),
    ]:
        cells = [stat_label]
        for _, section, outcome in ALL_COLS:
            cells.append(fmt_fn(get(data, section, outcome, rt)))
        lines.append(" & ".join(cells) + r" \\")

    lines.append(r"\midrule")
    checkmarks_layer = [r"\checkmark", r"\checkmark", "---", r"\checkmark", r"\checkmark", "---"]
    checkmarks_firm  = ["---", "---", r"\checkmark", "---", "---", r"\checkmark"]
    checkmarks_all   = [r"\checkmark"] * 6
    for row_label, marks in [
        (r"Microregion $\times$ Year FE", checkmarks_all),
        (r"Industry $\times$ Year FE",    checkmarks_all),
        (r"Mode $\times$ Year FE",        checkmarks_all),
        ("Layer-level",                   checkmarks_layer),
        ("Firm-level",                    checkmarks_firm),
    ]:
        lines.append(" & ".join([row_label] + marks) + r" \\")

    lines.append(r"\bottomrule")
    lines.append(r"\end{tabular}}")
    lines.append(r"\begin{minipage}{\linewidth}")
    lines.append(r"\scriptsize\vspace{4pt}")
    lines.append(
        r"\textit{Notes:} This table includes both " + cfg["panel_desc"]
        + r" layer connectivity variables ($c_{\text{" + lv1_tex + r"}}$ and $c_{\text{" + lv2_tex + r"}}$) "
        r"simultaneously in each regression. "
        r"The sample is restricted to firms with average December employment in 2009--2011 "
        r"at or above the median of the untreated balanced-panel sample (large firms). "
        r"Connectivity is scaled to the 90th percentile of the full untreated balanced-panel "
        r"sample at 2009. "
        r"Columns (1)--(2) and (4)--(5) are layer-level regressions restricted to the indicated "
        r"worker layer and absorb microregion$\times$year, industry$\times$year, and "
        r"mode$\times$year fixed effects. "
        r"Columns (3) and (6) are firm-level regressions that collapse to firm$\times$year "
        r"and absorb microregion$\times$year, industry$\times$year, and mode$\times$year "
        r"fixed effects. "
        r"The post-treatment indicator equals one for years $\geq 2012$ (S\'{u}mula 277 reform). "
        r"All regressions are restricted to untreated, balanced-panel firms. "
        r"Standard errors clustered at the firm level. "
        r"$^{***}p<0.01$, $^{**}p<0.05$, $^{*}p<0.10$."
    )
    lines.append(r"\end{minipage}")
    lines.append(r"\end{table}")
    return "\n".join(lines)


# ── CSV builder ────────────────────────────────────────────────────────────────
def build_csv(data: dict, cfg: dict) -> pd.DataFrame:
    lv1, lv2 = cfg["lv1"], cfg["lv2"]
    WAGE_COLS = [
        (cfg["lv1_label"], "layer_cross_firm", f"lr_remdezr_layer_{lv1}"),
        (cfg["lv2_label"], "layer_cross_firm", f"lr_remdezr_layer_{lv2}"),
        ("Firm",           "firm_cross_firm",  "lr_remdezr_w"),
    ]
    EMP_COLS = [
        (cfg["lv1_label"], "layer_cross_firm", f"l_layer_emp_{lv1}"),
        (cfg["lv2_label"], "layer_cross_firm", f"l_layer_emp_{lv2}"),
        ("Firm",           "firm_cross_firm",  "l_firm_emp"),
    ]
    ALL_COLS = WAGE_COLS + EMP_COLS
    row_types = [
        f"c_{lv1}_main", f"c_{lv1}_main_se", f"c_{lv2}_main", f"c_{lv2}_main_se",
        f"c_{lv1}_pre",  f"c_{lv1}_pre_se",  f"c_{lv2}_pre",  f"c_{lv2}_pre_se",
        f"c_{lv1}_pre_ftest", f"c_{lv2}_pre_ftest", "n_obs", "n_firms",
    ]
    rows = []
    for rt in row_types:
        for col_label, section, outcome in ALL_COLS:
            rows.append({
                "col_label": col_label, "section": section,
                "outcome": outcome, "row_type": rt,
                "value": get(data, section, outcome, rt),
            })
    return pd.DataFrame(rows)


# ── Combined three-panel LaTeX builder ────────────────────────────────────────
def build_combined_latex(all_data: dict) -> str:
    """One table with Panel A (edu2), Panel B (gender), Panel C (race)."""
    PANEL_ORDER = [
        ("edu2",   "A", "2-bin education"),
        ("gender", "B", "Gender"),
        ("race",   "C", "Race"),
    ]
    # Fixed 6 columns; layer labels appear in row labels, not column headers
    COL_HEADERS = ["(1)", "(2)", "(3)", "(4)", "(5)", "(6)"]

    lines = []
    col_spec = "l" + "c" * 6
    lines.append(r"\begin{table}[H]")
    lines.append(r"\centering")
    lines.append(r"\caption{Horse race: both layer connectivities simultaneously (cross-firm FE, large firms)}")
    lines.append(r"\label{tab:horse_race_all_xfirm_size_large}")
    lines.append(r"\resizebox{\textwidth}{!}{%")
    lines.append(r"\begin{tabular}{" + col_spec + r"}")
    lines.append(r"\toprule\toprule")

    lines.append(r" & \multicolumn{3}{c}{Log Dec.\ wage} & \multicolumn{3}{c}{Log employment} \\")
    lines.append(r"\cmidrule(lr){2-4}\cmidrule(lr){5-7}")
    lines.append(" & " + " & ".join(COL_HEADERS) + r" \\")
    lines.append(r"\midrule")

    for layer, panel_letter, panel_desc in PANEL_ORDER:
        cfg  = LAYER_CONFIG[layer]
        data = all_data[layer]
        lv1, lv2 = cfg["lv1"], cfg["lv2"]
        lv1_tex, lv2_tex = cfg["lv1_tex"], cfg["lv2_tex"]

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

        def row(label, rt, fmt_fn):
            cells = [label]
            for section, outcome in ALL_COLS:
                cells.append(fmt_fn(get(data, section, outcome, rt)))
            return " & ".join(cells) + r" \\"

        # Panel header
        lines.append(
            r"\multicolumn{7}{l}{\textit{Panel " + panel_letter
            + r": " + panel_desc + r" ("
            + cfg["lv1_label"] + r" / " + cfg["lv2_label"] + r")}} \\"
        )

        lines.append(row(rf"$c_{{\text{{{lv1_tex}}}}} \times \text{{Post}}$", f"c_{lv1}_main",    fmt_coef))
        lines.append(row("",                                                   f"c_{lv1}_main_se", fmt_se))
        lines.append(row(rf"$c_{{\text{{{lv2_tex}}}}} \times \text{{Post}}$", f"c_{lv2}_main",    fmt_coef))
        lines.append(row("",                                                   f"c_{lv2}_main_se", fmt_se))
        lines.append(row(rf"Pre: $c_{{\text{{{lv1_tex}}}}}$",                 f"c_{lv1}_pre",     fmt_coef))
        lines.append(row("",                                                   f"c_{lv1}_pre_se",  fmt_se))
        lines.append(row(rf"Pre: $c_{{\text{{{lv2_tex}}}}}$",                 f"c_{lv2}_pre",     fmt_coef))
        lines.append(row("",                                                   f"c_{lv2}_pre_se",  fmt_se))
        lines.append(row(r"\quad Observations",                                "n_obs",            fmt_n))
        lines.append(row(r"\quad Firms",                                       "n_firms",          fmt_n))
        lines.append(row(rf"\quad Pre-F $p$: $c_{{\text{{{lv1_tex}}}}}$",     f"c_{lv1}_pre_ftest", lambda v: fmt_stat(v, is_pval=True)))
        is_last = (panel_letter == "C")
        end = r" \\" if is_last else r" \\[6pt]"
        lines.append(
            row(rf"\quad Pre-F $p$: $c_{{\text{{{lv2_tex}}}}}$", f"c_{lv2}_pre_ftest",
                lambda v: fmt_stat(v, is_pval=True)).rstrip(r"\\") + end
        )

    lines.append(r"\midrule")
    checkmarks_layer = [r"\checkmark", r"\checkmark", "---", r"\checkmark", r"\checkmark", "---"]
    checkmarks_firm  = ["---", "---", r"\checkmark", "---", "---", r"\checkmark"]
    checkmarks_all   = [r"\checkmark"] * 6
    for row_label, marks in [
        (r"Microregion $\times$ Year FE", checkmarks_all),
        (r"Industry $\times$ Year FE",    checkmarks_all),
        (r"Mode $\times$ Year FE",        checkmarks_all),
        ("Layer-level",                   checkmarks_layer),
        ("Firm-level",                    checkmarks_firm),
    ]:
        lines.append(" & ".join([row_label] + marks) + r" \\")

    lines.append(r"\bottomrule")
    lines.append(r"\end{tabular}}")
    lines.append(r"\begin{minipage}{\linewidth}")
    lines.append(r"\scriptsize\vspace{4pt}")
    lines.append(
        r"\textit{Notes:} Each panel includes both layer connectivity variables simultaneously. "
        r"The sample is restricted to firms with average December employment in 2009--2011 "
        r"at or above the median of the untreated balanced-panel sample (large firms). "
        r"Connectivity is scaled to the 90th percentile of the full untreated balanced-panel "
        r"sample at 2009. "
        r"Columns (1)--(2) and (4)--(5) are layer-level regressions and absorb "
        r"microregion$\times$year, industry$\times$year, and mode$\times$year fixed effects. "
        r"Columns (3) and (6) collapse to firm$\times$year and absorb the same fixed effects. "
        r"The post-treatment indicator equals one for years $\geq 2012$ (S\'{u}mula 277 reform). "
        r"All regressions are restricted to untreated, balanced-panel firms. "
        r"Standard errors clustered at the firm level. "
        r"$^{***}p<0.01$, $^{**}p<0.05$, $^{*}p<0.10$."
    )
    lines.append(r"\end{minipage}")
    lines.append(r"\end{table}")
    return "\n".join(lines)


# ── Main ───────────────────────────────────────────────────────────────────────
TABLES.mkdir(parents=True, exist_ok=True)

all_data = {}

for layer in LAYERS:
    cfg     = LAYER_CONFIG[layer]
    csv_in  = TABLES / f"results_horse_race_{layer}_xfirm_size_large.csv"
    tex_out = TABLES / f"table_horse_race_{layer}_xfirm_size_large.tex"
    csv_out = TABLES / f"table_horse_race_{layer}_xfirm_size_large.csv"

    if not csv_in.exists():
        print(f"WARNING: {csv_in.name} not found — skipping {layer}. Run 13g first.")
        continue

    data = load_csv(csv_in)
    all_data[layer] = data
    print(f"Loaded {len(data)} entries from {csv_in.name}")

    tex = build_latex(data, cfg, cfg["caption"], cfg["label"])
    tex_out.write_text(tex)
    print(f"Wrote: {tex_out}")

    df_out = build_csv(data, cfg)
    df_out.to_csv(csv_out, index=False)
    print(f"Wrote: {csv_out}")
    print()

# Combined table (only if all three layers loaded)
if set(LAYERS) <= set(all_data):
    tex_combined = build_combined_latex(all_data)
    out_combined = TABLES / "table_horse_race_all_xfirm_size_large.tex"
    out_combined.write_text(tex_combined)
    print(f"Wrote: {out_combined}")
