"""
Assemble comparison table across layer spillover specifications.

Reads CSVs produced by 07_layer_spillover.do and outputs:
  Tables/layer_connectivity/table_layer_specs.tex
  Tables/layer_connectivity/table_layer_specs.csv

Specs included:
  (1) Within-firm FE     — firm×year FE, layer connectivity
                           results_spill_layer_{edu,edu2}_layer_spill.csv
  (2) Cross-firm FE      — micro×year + industry×year + mode×year FE
                           results_spill_layer_cross_{edu,edu2}_layer_spill.csv
  (3) Firm-level restr.  — firm-level outcomes, standard FE, restricted sample
                           results_spill_firmrestr_{edu,edu2}_layer_spill.csv

Usage:
  ~/.conda/envs/venv_python312/bin/python Programs/layer_connectivity/08_make_table_layer_specs.py
"""

from pathlib import Path
import pandas as pd

# ── Paths ──────────────────────────────────────────────────────────────────────
PROJ   = Path(__file__).resolve().parent.parent.parent
TABLES = PROJ / "Tables" / "layer_connectivity"

# ── Load one CSV (semicolon-separated data rows, comma header) ─────────────────
def load_csv(path: Path) -> pd.DataFrame:
    """Read do-file output CSV. Header is comma-separated; data rows are
    semicolon-separated quoted fields."""
    rows = []
    with open(path) as f:
        for i, line in enumerate(f):
            line = line.rstrip("\n")
            if i == 0:
                continue  # skip header — cols are spec/section/outcome/row_type/value
            parts = [p.strip('"') for p in line.split(";")]
            if len(parts) >= 5:
                rows.append({
                    "spec":     parts[0],
                    "section":  parts[1],
                    "outcome":  parts[2],
                    "row_type": parts[3],
                    "value":    parts[4],
                })
    return pd.DataFrame(rows)


# ── Spec configuration ─────────────────────────────────────────────────────────
SPECS = [
    {
        "label":       "(1) Within-firm FE",
        "sublabel":    "firm$\\times$year FE",
        "file_tpl":    "results_spill_layer_{layer}_layer_spill.csv",
        "section_key": "spill",
        "outcomes":    ["lr_remdezr_layer", "lr_remdezr_h_layer", "l_layer_emp"],
        "outcome_labels": {
            "lr_remdezr_layer":   "Log Dec. wage (layer avg.)",
            "lr_remdezr_h_layer": "Log hourly wage (layer avg.)",
            "l_layer_emp":        "Log employment (layer)",
        },
    },
    {
        "label":       "(2) Cross-firm FE",
        "sublabel":    "micro$\\times$yr + ind$\\times$yr + mode$\\times$yr",
        "file_tpl":    "results_spill_layer_cross_{layer}_layer_spill.csv",
        "section_key": "cross",
        "outcomes":    ["lr_remdezr_layer", "lr_remdezr_h_layer", "l_layer_emp"],
        "outcome_labels": {
            "lr_remdezr_layer":   "Log Dec. wage (layer avg.)",
            "lr_remdezr_h_layer": "Log hourly wage (layer avg.)",
            "l_layer_emp":        "Log employment (layer)",
        },
    },
    {
        "label":       "(3) Firm-level (restricted)",
        "sublabel":    "firm FE + standard controls",
        "file_tpl":    "results_spill_firmrestr_{layer}_layer_spill.csv",
        "section_key": "firmrestr",
        "outcomes":    ["lr_remdezr_w", "lr_remdezr_h_w", "l_firm_emp"],
        "outcome_labels": {
            "lr_remdezr_w":   "Log Dec. wage (firm avg.)",
            "lr_remdezr_h_w": "Log hourly wage (firm avg.)",
            "l_firm_emp":     "Log employment (firm)",
        },
    },
]

LAYERS = ["edu", "edu2", "gender", "race"]
LAYER_LABELS = {
    "edu":    "3-bin education (no HS / HS / higher)",
    "edu2":   "2-bin education (no HS / has HS)",
    "gender": "Gender (female / male)",
    "race":   "Race (non-white / white)",
}

OUTCOME_ORDER = [
    # (generic label, spec1_outcome, spec2_outcome, spec3_outcome)
    ("Log Dec. wage",   "lr_remdezr_layer", "lr_remdezr_layer", "lr_remdezr_w"),
    ("Log hourly wage", "lr_remdezr_h_layer", "lr_remdezr_h_layer", "lr_remdezr_h_w"),
    ("Log employment",  "l_layer_emp",      "l_layer_emp",      "l_firm_emp"),
]

STAT_ROWS = [
    ("n_obs",    "Observations"),
    ("n_cells",  "Layers $\\times$ firms"),
    ("n_firms",  "Firms"),
    ("pre_pval", "Pre-trend F-test $p$-value"),
]


# ── Load all data ──────────────────────────────────────────────────────────────
# data[(layer, spec_idx, outcome, row_type)] = value_string
data: dict = {}
missing_files: list = []

for layer in LAYERS:
    for si, spec in enumerate(SPECS):
        fpath = TABLES / spec["file_tpl"].format(layer=layer)
        if not fpath.exists():
            missing_files.append(str(fpath))
            continue
        df = load_csv(fpath)
        for _, row in df.iterrows():
            key = (layer, si, row["outcome"], row["row_type"])
            data[key] = row["value"]

if missing_files:
    print("WARNING — missing files (run 07_layer_spillover.do first):")
    for f in missing_files:
        print(f"  {f}")
    if len(missing_files) == len(LAYERS) * len(SPECS):
        raise SystemExit("No data found. Exiting.")


def get(layer, si, outcome, row_type, default="--"):
    return data.get((layer, si, outcome, row_type), default)


def fmt_coef(val_str: str) -> str:
    """Return value string stripped of spaces."""
    return val_str.strip() if val_str.strip() != "--" else "--"


def fmt_se(val_str: str) -> str:
    if val_str.strip() == "--":
        return "--"
    try:
        return f"({float(val_str.strip()):.4f})"
    except ValueError:
        return val_str.strip()


def fmt_stat(val_str: str, row_type: str) -> str:
    v = val_str.strip()
    if v == "--":
        return "--"
    if row_type == "pre_pval":
        try:
            return f"{float(v):.3f}"
        except ValueError:
            return v
    else:
        # n_obs, n_firms — strip trailing spaces
        return v.strip()


# ── Build LaTeX ────────────────────────────────────────────────────────────────
n_spec = len(SPECS)

# Shorter outcome labels for column headers
OUTCOME_SHORT = [
    "Log Dec. wage",
    "Log hourly wage",
    "Log employment",
]

def build_latex() -> str:
    lines = []
    n_outcomes = len(OUTCOME_ORDER)
    # Panels = layers; columns = outcomes × specs
    ncols = 1 + n_outcomes * n_spec  # 1 + 3*3 = 10

    lines.append(r"\begin{table}[htbp]")
    lines.append(r"\centering")
    lines.append(r"\caption{Layer spillover effects --- specification comparison}")
    lines.append(r"\label{tab:layer_specs}")
    lines.append(r"\footnotesize")
    col_spec = "l" + "".join(["ccc"] * n_outcomes)
    lines.append(r"\begin{tabular}{" + col_spec + r"}")
    lines.append(r"\toprule")

    # Header row 1 — outcome labels as multicolumn groups
    header1 = [""]
    for out_label in OUTCOME_SHORT:
        header1.append(r"\multicolumn{" + str(n_spec) + r"}{c}{" + out_label + r"}")
    lines.append(" & ".join(header1) + r" \\")

    # Cmidrules for outcome groups
    cmi = []
    col = 2
    for _ in OUTCOME_ORDER:
        cmi.append(f"\\cmidrule(lr){{{col}-{col+n_spec-1}}}")
        col += n_spec
    lines.append(" ".join(cmi))

    # Header row 2 — (1)(2)(3) repeating for each outcome group
    header2 = [""]
    for _ in OUTCOME_ORDER:
        for i in range(1, n_spec + 1):
            header2.append(f"({i})")
    lines.append(" & ".join(header2) + r" \\")
    lines.append(r"\midrule")

    # One panel per layer bin specification
    for li, layer in enumerate(LAYERS):
        # Panel header
        panel_letter = chr(ord("A") + li)
        lines.append(
            r"\multicolumn{" + str(ncols) + r"}{l}{\textit{Panel "
            + panel_letter
            + r": " + LAYER_LABELS[layer] + r"}} \\"
        )

        def row_cells(label, row_type, fmt_fn):
            cells = [label]
            for oi, (_, out0, out1, out2) in enumerate(OUTCOME_ORDER):
                out_per_spec = [out0, out1, out2]
                for si in range(n_spec):
                    cells.append(fmt_fn(get(layer, si, out_per_spec[si], row_type)))
            return cells

        # Coefficient and SE rows
        lines.append(" & ".join(row_cells(r"\quad Connectivity $\times$ Post", "main", fmt_coef)) + r" \\")
        lines.append(" & ".join(row_cells("", "main_se", fmt_se)) + r" \\")
        lines.append(" & ".join(row_cells(r"\quad Pre-trend (placebo)", "pre", fmt_coef)) + r" \\")
        lines.append(" & ".join(row_cells("", "pre_se", fmt_se)) + r" \\")

        # Stat rows
        for ri, (row_type, stat_label) in enumerate(STAT_ROWS):
            stat_cells = [r"\quad " + stat_label]
            for oi, (_, out0, out1, out2) in enumerate(OUTCOME_ORDER):
                out_per_spec = [out0, out1, out2]
                for si in range(n_spec):
                    outcome = out_per_spec[si]
                    v = get(layer, si, outcome, row_type, "--")
                    if row_type == "n_cells" and si == 2:
                        stat_cells.append("---")
                    else:
                        stat_cells.append(fmt_stat(v, row_type) if v != "--" else "---")
            is_last_stat = ri == len(STAT_ROWS) - 1
            end = r" \\[6pt]" if is_last_stat and li < len(LAYERS) - 1 else r" \\"
            lines.append(" & ".join(stat_cells) + end)

    lines.append(r"\midrule")

    # Checkmark panel — specs (1)(2)(3) repeat identically across outcome groups
    lines.append(r"\multicolumn{" + str(ncols) + r"}{l}{\textit{Specification}} \\")

    CHECKMARK_ROWS = [
        ("Layer-level outcomes",            lambda si: si in (0, 1)),
        ("Firm-level outcomes",             lambda si: si == 2),
        ("Firm $\\times$ year FE",          lambda si: si == 0),
        ("Microregion $\\times$ year FE",   lambda si: si == 1),
        ("Industry $\\times$ year FE",      lambda si: si == 1),
        ("Mode $\\times$ year FE",          lambda si: si == 1),
        ("Firm FE",                         lambda si: si == 2),
        ("Standard controls",               lambda si: si == 2),
    ]

    for label, condition in CHECKMARK_ROWS:
        cells = [label]
        for _ in OUTCOME_ORDER:
            for si in range(n_spec):
                cells.append(r"\checkmark" if condition(si) else "---")
        lines.append(" & ".join(cells) + r" \\")

    lines.append(r"\bottomrule")
    lines.append(r"\end{tabular}")
    lines.append(r"\begin{minipage}{\linewidth}")
    lines.append(r"\footnotesize")
    lines.append(r"\vspace{4pt}")
    lines.append(
        r"\textit{Notes:} All regressions restricted to untreated, balanced-panel firms in the Lagos sample. "
        r"Connectivity is scaled to the 90th percentile of the control sample at 2009 and is "
        r"interacted with a post-2012 indicator (S\'{u}mula 277 reform). The pre-trend (placebo) coefficient "
        r"uses a fictitious treatment onset at 2010, estimated on the pre-reform period (2007--2011) only. "
        r"The pre-trend F-test $p$-value tests the joint significance of all pre-trend event-study "
        r"coefficients; small values indicate detectable pre-trends."
    )
    lines.append(r"")
    lines.append(
        r"\textit{Outcome levels.} Columns (1) and (2) use \textit{layer-level} outcomes: "
        r"each observation is a firm--layer--year cell, and the connectivity measure captures the share "
        r"of that layer's outflows reaching treated firms. "
        r"Column (3) uses \textit{firm-level} outcomes and the aggregate firm-level connectivity, "
        r"restricted to the subset of firms present in the layer sample."
    )
    lines.append(r"")
    lines.append(
        r"\textit{Fixed effects.} Within-firm specification (1) absorbs firm$\times$year FE; "
        r"identification comes from cross-layer variation within the same firm--year. "
        r"Cross-firm specification (2) includes microregion$\times$year, industry$\times$year, "
        r"and mode$\times$year FE, controlling for local labor-market trends, sector shocks, and "
        r"contract-type composition. "
        r"Firm-level specification (3) includes firm FE together with a standard set of "
        r"time-varying controls (log employment, wage quartile, and sector trends)."
    )
    lines.append(r"")
    lines.append(
        r"\textit{Layer definitions.} Panel A groups workers into three education bins: "
        r"no high-school diploma (no HS), completed high school (HS), and tertiary or above (higher). "
        r"Panel B collapses HS and higher into a single group (2-bin partition). "
        r"Panel C partitions workers by gender (female / male). "
        r"Panel D classifies workers as non-white or white."
    )
    lines.append(r"")
    lines.append(
        r"Standard errors clustered at the firm level. "
        r"$^{***}p<0.01$, $^{**}p<0.05$, $^{*}p<0.10$."
    )
    lines.append(r"\end{minipage}")
    lines.append(r"\end{table}")
    return "\n".join(lines)


# ── Build flat CSV for quick inspection ───────────────────────────────────────
def build_csv() -> pd.DataFrame:
    rows = []
    for layer in LAYERS:
        for out_label, out0, out1, out2 in OUTCOME_ORDER:
            out_per_spec = [out0, out1, out2]
            for si, spec in enumerate(SPECS):
                outcome = out_per_spec[si]
                rows.append({
                    "layer":      layer,
                    "spec":       spec["label"],
                    "outcome":    out_label,
                    "main":       fmt_coef(get(layer, si, outcome, "main")),
                    "main_se":    fmt_se(get(layer, si, outcome, "main_se")),
                    "pre":        fmt_coef(get(layer, si, outcome, "pre")),
                    "pre_se":     fmt_se(get(layer, si, outcome, "pre_se")),
                    "n_obs":      fmt_stat(get(layer, si, outcome, "n_obs"), "n_obs"),
                    "n_firms":    fmt_stat(get(layer, si, outcome, "n_firms"), "n_firms"),
                    "pre_pval":   fmt_stat(get(layer, si, outcome, "pre_pval"), "pre_pval"),
                })
    return pd.DataFrame(rows)


# ── Write outputs ──────────────────────────────────────────────────────────────
TABLES.mkdir(parents=True, exist_ok=True)

tex_out = TABLES / "table_layer_specs.tex"
csv_out = TABLES / "table_layer_specs.csv"

tex = build_latex()
tex_out.write_text(tex)
print(f"Wrote: {tex_out}")

df_out = build_csv()
df_out.to_csv(csv_out, index=False)
print(f"Wrote: {csv_out}")

# Print preview
print()
print(df_out.to_string(index=False))
