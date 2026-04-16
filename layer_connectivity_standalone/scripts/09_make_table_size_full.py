"""
Assemble size-split layer spillover table — zero-filled employment variant.

Reads CSVs produced by 07_layer_spillover_size_full.do and outputs:
  Tables/layer_connectivity/table_size_full.tex
  Tables/layer_connectivity/table_size_full.csv

Differences from 09_make_table_size_specs.py:
  - Reads *_full_layer_spill.csv files (zero-employment cells included)
  - Employment outcome is l1p_layer_emp = ln(1 + layer_emp), valid at zero
  - Firmrestr employment outcome l_firm_emp remapped to l1p_layer_emp column

Usage:
  ~/.conda/envs/venv_python312/bin/python Programs/layer_connectivity/09_make_table_size_full.py
"""

from pathlib import Path
import pandas as pd

# ── Paths ───────────────────────────────────────────────────────────────────────
PROJ   = Path(__file__).resolve().parent.parent.parent
TABLES = PROJ / "Tables" / "layer_connectivity"

# ── Load one CSV ────────────────────────────────────────────────────────────────
def load_csv(path: Path) -> pd.DataFrame:
    rows = []
    with open(path) as f:
        for i, line in enumerate(f):
            line = line.rstrip("\n")
            if i == 0:
                continue
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


# ── Configuration ───────────────────────────────────────────────────────────────
LAYERS = ["edu", "edu2", "gender", "race"]
LAYER_LABELS = {
    "edu":    "3-bin education (no HS / HS / higher)",
    "edu2":   "2-bin education (no HS / has HS)",
    "gender": "Gender (female / male)",
    "race":   "Race (non-white / white)",
}

SIZES       = ["small", "large"]
SIZE_LABELS = {"small": "Small", "large": "Large"}

# (col_index, file_template, section_key, size)
COLS = [
    (0, "results_spill_layer_{layer}_size_{size}_full_layer_spill.csv",         "spill",     "small"),
    (1, "results_spill_layer_{layer}_size_{size}_full_layer_spill.csv",         "spill",     "large"),
    (2, "results_spill_layer_cross_{layer}_size_{size}_full_layer_spill.csv",   "cross",     "small"),
    (3, "results_spill_layer_cross_{layer}_size_{size}_full_layer_spill.csv",   "cross",     "large"),
    (4, "results_spill_firmrestr_{layer}_size_{size}_full_layer_spill.csv",     "firmrestr", "small"),
    (5, "results_spill_firmrestr_{layer}_size_{size}_full_layer_spill.csv",     "firmrestr", "large"),
]

# Firmrestr CSVs use firm-level outcome names; remap to generic layer outcome keys
FIRMRESTR_OUTCOME_REMAP = {
    "lr_remdezr_w":   "lr_remdezr_layer",
    "lr_remdezr_h_w": "lr_remdezr_h_layer",
    "l_firm_emp":     "l1p_layer_emp",
}

OUTCOMES      = ["lr_remdezr_layer", "lr_remdezr_h_layer", "l1p_layer_emp"]
OUTCOME_SHORT = ["Log Dec. wage", "Log hourly wage", r"$\ln(1+\text{emp.})$"]

STAT_ROWS = [
    ("n_obs",    "Observations"),
    ("n_cells",  "Layers $\\times$ firms"),
    ("n_firms",  "Firms"),
    ("pre_pval", "Pre-trend F-test $p$-value"),
]

# ── Load all data ───────────────────────────────────────────────────────────────
data: dict = {}
missing_files: list = []

for layer in LAYERS:
    for col_idx, file_tpl, section_key, size in COLS:
        fpath = TABLES / file_tpl.format(layer=layer, size=size)
        if not fpath.exists():
            missing_files.append(str(fpath))
            continue
        df = load_csv(fpath)
        for _, row in df.iterrows():
            outcome = row["outcome"]
            if section_key == "firmrestr" and outcome in FIRMRESTR_OUTCOME_REMAP:
                outcome = FIRMRESTR_OUTCOME_REMAP[outcome]
            key = (layer, col_idx, outcome, row["row_type"])
            data[key] = row["value"]

if missing_files:
    print("WARNING — missing files (run 07_layer_spillover_size_full.do first):")
    for f in missing_files:
        print(f"  {f}")
    if len(missing_files) == len(LAYERS) * len(COLS):
        raise SystemExit("No data found. Exiting.")


def get(layer, col_idx, outcome, row_type, default="--"):
    return data.get((layer, col_idx, outcome, row_type), default)

def fmt_coef(val_str: str) -> str:
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
        return "---"
    if row_type == "pre_pval":
        try:
            return f"{float(v):.3f}"
        except ValueError:
            return v
    return v.strip()


# ── Build LaTeX ─────────────────────────────────────────────────────────────────
N_COLS = len(COLS)

def build_latex() -> str:
    lines = []
    ncols_total = 1 + len(OUTCOMES) * N_COLS

    lines.append(r"\begin{landscape}")
    lines.append(r"\begin{table}[H]")
    lines.append(r"\centering")
    lines.append(r"\caption{Layer spillover effects by firm size (zero-filled employment)}")
    lines.append(r"\label{tab:size_full}")
    lines.append(r"\setlength{\tabcolsep}{3pt}")
    lines.append(r"\resizebox{\textwidth}{!}{%")
    col_spec = "l" + "c" * (len(OUTCOMES) * N_COLS)
    lines.append(r"\begin{tabular}{" + col_spec + r"}")
    lines.append(r"\toprule\toprule")

    # Header row 1 — outcome groups
    h1 = [""]
    for out_label in OUTCOME_SHORT:
        h1.append(r"\multicolumn{" + str(N_COLS) + r"}{c}{" + out_label + r"}")
    lines.append(" & ".join(h1) + r" \\")

    cmi = []
    col = 2
    for _ in OUTCOMES:
        cmi.append(f"\\cmidrule(lr){{{col}-{col+N_COLS-1}}}")
        col += N_COLS
    lines.append(" ".join(cmi))

    # Header row 2 — spec × size labels
    SPEC_LABELS = [
        r"\shortstack{Within-firm\\Small}",
        r"\shortstack{Within-firm\\Large}",
        r"\shortstack{Cross-firm\\Small}",
        r"\shortstack{Cross-firm\\Large}",
        r"\shortstack{Firm-level\\Small}",
        r"\shortstack{Firm-level\\Large}",
    ]
    h2 = [""]
    for _ in OUTCOMES:
        h2.extend(SPEC_LABELS)
    lines.append(" & ".join(h2) + r" \\")
    lines.append(r"\midrule")

    # Panels
    for li, layer in enumerate(LAYERS):
        panel_letter = chr(ord("A") + li)
        lines.append(
            r"\multicolumn{" + str(ncols_total) + r"}{l}{\textit{Panel "
            + panel_letter + r": " + LAYER_LABELS[layer] + r"}} \\"
        )

        def row_cells(label, row_type, fmt_fn):
            cells = [label]
            for outcome in OUTCOMES:
                for col_idx in range(N_COLS):
                    cells.append(fmt_fn(get(layer, col_idx, outcome, row_type)))
            return cells

        lines.append(" & ".join(row_cells(r"\quad Connectivity $\times$ Post", "main",    fmt_coef)) + r" \\")
        lines.append(" & ".join(row_cells("",                                   "main_se", fmt_se))   + r" \\")
        lines.append(" & ".join(row_cells(r"\quad Pre-trend (placebo)",         "pre",     fmt_coef)) + r" \\")
        lines.append(" & ".join(row_cells("",                                   "pre_se",  fmt_se))   + r" \\")

        for ri, (row_type, stat_label) in enumerate(STAT_ROWS):
            cells = [r"\quad " + stat_label]
            for outcome in OUTCOMES:
                for col_idx in range(N_COLS):
                    v = get(layer, col_idx, outcome, row_type, "--")
                    cells.append(fmt_stat(v, row_type))
            is_last = ri == len(STAT_ROWS) - 1
            end = r" \\[6pt]" if is_last and li < len(LAYERS) - 1 else r" \\"
            lines.append(" & ".join(cells) + end)

    lines.append(r"\bottomrule")
    lines.append(r"\end{tabular}}")
    lines.append(r"\begin{minipage}{\linewidth}")
    lines.append(r"\scriptsize\vspace{4pt}")
    lines.append(
        r"\textit{Notes:} This table reports layer-level spillover effects split by firm size, "
        r"comparing small firms (below-median average December employment 2009--2011) to large firms "
        r"(at or above median, corresponding to 31.7 workers). "
        r"The employment outcome is $\ln(1 + \text{layer employment})$, which is defined at zero "
        r"and includes firm--layer--year cells with no workers in that layer; "
        r"wage outcomes are unchanged and condition on positive layer employment. "
        r"All regressions are restricted to untreated, balanced-panel firms. "
        r"Connectivity is scaled to the 90th percentile of the full control sample at 2009 "
        r"(same scale for both size groups) so coefficients are comparable across columns. "
        r"Connectivity is set to zero for firm--layer pairs with no pre-treatment flows through that layer. "
        r"The pre-trend (placebo) coefficient tests whether connectivity predicts differential "
        r"outcomes in 2009--2010 relative to 2011, using only pre-reform years (2009--2011). "
        r"Pre-trend F-test $p$-value tests joint significance of all pre-trend event-study coefficients. "
        r"Within-firm specifications absorb firm$\times$year FE; identification exploits "
        r"cross-layer variation within the same firm--year. "
        r"Cross-firm specifications include microregion$\times$year, industry$\times$year, "
        r"and mode$\times$year FE. "
        r"Firm-level columns (5--6) run the standard firm-level spillover regression restricted to "
        r"firms with pre-treatment flows through the layer and the given size group. "
        r"Standard errors clustered at the firm level. "
        r"$^{***}p<0.01$, $^{**}p<0.05$, $^{*}p<0.10$."
    )
    lines.append(r"\end{minipage}")
    lines.append(r"\end{table}")
    lines.append(r"\end{landscape}")
    return "\n".join(lines)


# ── Build flat CSV ───────────────────────────────────────────────────────────────
def build_csv() -> pd.DataFrame:
    col_labels = ["within_small", "within_large", "cross_small", "cross_large",
                  "firmrestr_small", "firmrestr_large"]
    rows = []
    for layer in LAYERS:
        for outcome in OUTCOMES:
            for col_idx, col_label in enumerate(col_labels):
                rows.append({
                    "layer":    layer,
                    "outcome":  outcome,
                    "spec":     col_label,
                    "main":     fmt_coef(get(layer, col_idx, outcome, "main")),
                    "main_se":  fmt_se(get(layer, col_idx, outcome, "main_se")),
                    "pre":      fmt_coef(get(layer, col_idx, outcome, "pre")),
                    "pre_se":   fmt_se(get(layer, col_idx, outcome, "pre_se")),
                    "n_obs":    fmt_stat(get(layer, col_idx, outcome, "n_obs"),    "n_obs"),
                    "n_firms":  fmt_stat(get(layer, col_idx, outcome, "n_firms"),  "n_firms"),
                    "pre_pval": fmt_stat(get(layer, col_idx, outcome, "pre_pval"), "pre_pval"),
                })
    return pd.DataFrame(rows)


# ── Write outputs ────────────────────────────────────────────────────────────────
TABLES.mkdir(parents=True, exist_ok=True)

tex_out = TABLES / "table_size_full.tex"
csv_out = TABLES / "table_size_full.csv"

tex = build_latex()
tex_out.write_text(tex)
print(f"Wrote: {tex_out}")

df_out = build_csv()
df_out.to_csv(csv_out, index=False)
print(f"Wrote: {csv_out}")

print()
print(df_out.to_string(index=False))
