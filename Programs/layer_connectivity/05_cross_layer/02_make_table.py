"""
Assemble cross-layer spillover table.

Reads CSVs produced by 01_cross_layer.do and outputs:
  Tables/layer_connectivity/table_cross_layer_specs.tex
  Tables/layer_connectivity/table_cross_layer_specs.csv

Table structure:
  - 4 panels (edu, edu2, gender, race)
  - 6 columns: 3 outcomes × 2 FE specs (base / + layer×year + firm×layer FE)
  - Rows per panel:
      Own connectivity × Post  +  SE
      Cross connectivity × Post  +  SE
      Pre-trend (own)  +  SE
      Pre-trend (cross)  +  SE
      Observations, Layers × firms, Firms, Pre-trend F-test p-value (cross)

Usage:
  ~/.conda/envs/venv_python312/bin/python Programs/layer_connectivity/02_make_table.py
"""

from pathlib import Path
import pandas as pd

PROJ   = Path(__file__).resolve().parent.parent.parent.parent
TABLES = PROJ / "Tables" / "layer_connectivity/05_cross_layer"
TEX_TABLES = TABLES / "tex_tables"

# ── Load one CSV ─────────────────────────────────────────────────────────────────
def load_csv(path: Path) -> pd.DataFrame:
    rows = []
    with open(path) as f:
        for i, line in enumerate(f):
            line = line.rstrip("\n")
            if i == 0:
                continue
            parts = [p.strip('"').strip() for p in line.split(";")]
            if len(parts) >= 5:
                rows.append({
                    "spec":     parts[0],
                    "section":  parts[1],
                    "outcome":  parts[2],
                    "row_type": parts[3],
                    "value":    parts[4],
                })
    return pd.DataFrame(rows)


LAYERS = ["edu", "edu2", "gender", "race"]
LAYER_LABELS = {
    "edu":    "3-bin education (no HS / HS / higher)",
    "edu2":   "2-bin education (no HS / has HS)",
    "gender": "Gender (female / male)",
    "race":   "Race (non-white / white)",
}

OUTCOMES     = ["lr_remdezr_layer", "lr_remdezr_h_layer", "l_layer_emp"]
OUTCOME_SHORT = [r"Log Dec.\ wage", "Log hourly wage", "Log employment"]

FE_SPECS  = ["with_firmyr", "no_firmyr"]
FE_LABELS = {"with_firmyr": "Unit + Firm$\\times$year FE", "no_firmyr": "Unit + Year FE"}

STAT_ROWS = [
    ("n_obs",    "Observations"),
    ("n_cells",  "Layers $\\times$ firms"),
    ("n_firms",  "Firms"),
    ("pre_pval", "Pre-trend $p$-value (cross)"),
]

# ── Load all data ─────────────────────────────────────────────────────────────────
# data[(layer, fe_spec, outcome, row_type)] = value_string
data: dict = {}
missing_files: list = []

for layer in LAYERS:
    fpath = TABLES / f"results_cross_layer_{layer}_layer_spill.csv"
    if not fpath.exists():
        missing_files.append(str(fpath))
        continue
    df = load_csv(fpath)
    for _, row in df.iterrows():
        key = (layer, row["section"], row["outcome"], row["row_type"])
        data[key] = row["value"]

if missing_files:
    print("WARNING — missing files:")
    for f in missing_files:
        print(f"  {f}")
    if len(missing_files) == len(LAYERS):
        raise SystemExit("No data found.")


def get(layer, fe_spec, outcome, row_type, default="--"):
    return data.get((layer, fe_spec, outcome, row_type), default)


def fmt_coef(val_str: str) -> str:
    return val_str.strip() if val_str.strip() != "--" else "--"


def fmt_se(val_str: str) -> str:
    v = val_str.strip()
    if v == "--":
        return "--"
    try:
        return f"({float(v):.4f})"
    except ValueError:
        return v


def fmt_stat(val_str: str, row_type: str) -> str:
    v = val_str.strip()
    if v == "--":
        return "---"
    if row_type == "pre_pval":
        try:
            return f"{float(v):.3f}"
        except ValueError:
            return v
    return v


# ── Build LaTeX ───────────────────────────────────────────────────────────────────
def build_latex() -> str:
    lines = []
    n_cols = 1 + len(OUTCOMES) * len(FE_SPECS)  # 1 label + 6 data cols

    lines.append(r"\begin{table}[H]")
    lines.append(r"\centering")
    lines.append(r"\caption{Cross-layer spillover effects}")
    lines.append(r"\label{tab:cross_layer_specs}")
    col_spec = "l" + "c" * (len(OUTCOMES) * len(FE_SPECS))
    lines.append(r"\resizebox{\textwidth}{!}{%")
    lines.append(r"\begin{tabular}{" + col_spec + r"}")
    lines.append(r"\toprule\toprule")

    # ── Header row 1: outcome groups ──────────────────────────────────────────
    header1 = [""]
    for out_label in OUTCOME_SHORT:
        header1.append(r"\multicolumn{2}{c}{" + out_label + r"}")
    lines.append(" & ".join(header1) + r" \\")

    # Cmidrules under each outcome pair
    cmidrules = []
    for k in range(len(OUTCOMES)):
        start = 2 + k * 2
        end   = start + 1
        cmidrules.append(rf"\cmidrule(lr){{{start}-{end}}}")
    lines.append(" ".join(cmidrules))

    # ── Header row 2: FE spec labels ──────────────────────────────────────────
    header2 = [""]
    for _ in OUTCOMES:
        for fe in FE_SPECS:
            header2.append(FE_LABELS[fe])
    lines.append(" & ".join(header2) + r" \\")
    lines.append(r"\midrule")

    # ── Panel rows ────────────────────────────────────────────────────────────
    for li, layer in enumerate(LAYERS):
        panel_letter = chr(ord("A") + li)
        lines.append(
            r"\multicolumn{" + str(n_cols) + r"}{l}{\textit{Panel "
            + panel_letter + r": " + LAYER_LABELS[layer] + r"}} \\"
        )

        def data_cells(row_type, fmt_fn):
            cells = []
            for outcome in OUTCOMES:
                for fe in FE_SPECS:
                    cells.append(fmt_fn(get(layer, fe, outcome, row_type)))
            return cells

        rows_spec = [
            (r"\quad Own connectivity $\times$ Post",   "own_main",      fmt_coef),
            ("",                                         "own_main_se",   fmt_se),
            (r"\quad Cross connectivity $\times$ Post", "cross_main",    fmt_coef),
            ("",                                         "cross_main_se", fmt_se),
            (r"\quad Pre-trend (own)",                  "own_pre",       fmt_coef),
            ("",                                         "own_pre_se",    fmt_se),
            (r"\quad Pre-trend (cross)",                "cross_pre",     fmt_coef),
            ("",                                         "cross_pre_se",  fmt_se),
        ]
        for label, row_type, fmt_fn in rows_spec:
            cells = [label] + data_cells(row_type, fmt_fn)
            lines.append(" & ".join(cells) + r" \\")

        for ri, (row_type, stat_label) in enumerate(STAT_ROWS):
            cells = [r"\quad " + stat_label]
            for outcome in OUTCOMES:
                for fe in FE_SPECS:
                    v = get(layer, fe, outcome, row_type, "--")
                    cells.append(fmt_stat(v, row_type))
            is_last = ri == len(STAT_ROWS) - 1
            end = r" \\[6pt]" if is_last and li < len(LAYERS) - 1 else r" \\"
            lines.append(" & ".join(cells) + end)

    lines.append(r"\midrule")

    # ── Specification rows ────────────────────────────────────────────────────
    lines.append(r"\multicolumn{" + str(n_cols) + r"}{l}{\textit{Specification}} \\")
    spec_rows = [
        ("Firm $\\times$ layer (unit) FE", [r"\checkmark"] * 6),
        ("Firm $\\times$ year FE",         [r"\checkmark", ""] * 3),
        ("Year FE",                        ["", r"\checkmark"] * 3),
        ("Own connectivity",               [r"\checkmark"] * 6),
        ("Cross connectivity",             [r"\checkmark"] * 6),
    ]
    for label, vals in spec_rows:
        lines.append(" & ".join([label] + vals) + r" \\")

    lines.append(r"\bottomrule")
    lines.append(r"\end{tabular}}")

    lines.append(r"\begin{minipage}{\linewidth}")
    lines.append(r"\scriptsize\vspace{4pt}")
    lines.append(
        r"\textit{Notes:} This table tests whether connectivity of other layers within the same firm "
        r"spills over to a focal layer's outcomes. "
        r"Each observation is a firm--layer--year cell. "
        r"The balanced panel includes all layers for every spillover-sample firm; "
        r"firms absent from a given layer receive zero employment "
        r"($\ln(1+0)=0$) and missing wages. "
        r"Own connectivity is the layer's direct per-worker connectivity to treated firms, "
        r"scaled to the P90 of the spillover sample. "
        r"Cross connectivity is the employment-share-weighted sum of other layers' connectivity: "
        r"$\text{cross\_conn}_{i,B}=\sum_{A\neq B}\text{conn}_{i,A}\times(\bar{n}_{i,A}/\bar{n}_{i,B})$, "
        r"scaled to its own P90; observations with $\bar{n}_{i,B}=0$ are dropped. "
        r"Both specifications include firm$\times$layer FE (the cross-section unit FE "
        r"for the firm$\times$layer panel, absorbing time-invariant heterogeneity of each firm--layer pair). "
        r"The first specification additionally includes firm$\times$year FE, "
        r"so identification comes from within-firm cross-layer variation in connectivity. "
        r"The second specification replaces firm$\times$year FE with aggregate year FE, "
        r"so identification uses cross-firm cross-layer variation over time. "
        r"Pre-trend placebo uses years 2009--2010 relative to 2011. "
        r"Standard errors clustered at the firm level. "
        r"$^{***}p<0.01$, $^{**}p<0.05$, $^{*}p<0.10$."
    )
    lines.append(r"\end{minipage}")
    lines.append(r"\end{table}")
    return "\n".join(lines)


# ── Build flat CSV ─────────────────────────────────────────────────────────────────
def build_csv() -> pd.DataFrame:
    rows = []
    for layer in LAYERS:
        for outcome in OUTCOMES:
            for fe in FE_SPECS:
                rows.append({
                    "layer":         layer,
                    "outcome":       outcome,
                    "fe_spec":       fe,
                    "own_main":      fmt_coef(get(layer, fe, outcome, "own_main")),
                    "own_main_se":   fmt_se(get(layer, fe, outcome, "own_main_se")),
                    "cross_main":    fmt_coef(get(layer, fe, outcome, "cross_main")),
                    "cross_main_se": fmt_se(get(layer, fe, outcome, "cross_main_se")),
                    "own_pre":       fmt_coef(get(layer, fe, outcome, "own_pre")),
                    "own_pre_se":    fmt_se(get(layer, fe, outcome, "own_pre_se")),
                    "cross_pre":     fmt_coef(get(layer, fe, outcome, "cross_pre")),
                    "cross_pre_se":  fmt_se(get(layer, fe, outcome, "cross_pre_se")),
                    "n_obs":         fmt_stat(get(layer, fe, outcome, "n_obs"),    "n_obs"),
                    "n_cells":       fmt_stat(get(layer, fe, outcome, "n_cells"),  "n_cells"),
                    "n_firms":       fmt_stat(get(layer, fe, outcome, "n_firms"),  "n_firms"),
                    "pre_pval":      fmt_stat(get(layer, fe, outcome, "pre_pval"), "pre_pval"),
                })
    return pd.DataFrame(rows)


# ── Write outputs ──────────────────────────────────────────────────────────────────
TABLES.mkdir(parents=True, exist_ok=True)

tex_out = TEX_TABLES / "table_cross_layer_specs.tex"
csv_out = TABLES / "table_cross_layer_specs.csv"

tex = build_latex()
tex_out.write_text(tex)
print(f"Wrote: {tex_out}")

df_out = build_csv()
df_out.to_csv(csv_out, index=False)
print(f"Wrote: {csv_out}")

print()
print(df_out.to_string(index=False))
