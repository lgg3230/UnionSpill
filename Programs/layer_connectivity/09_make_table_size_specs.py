"""
Assemble size-split layer spillover table.

Reads CSVs produced by 07_layer_spillover_size.do and outputs:
  Tables/layer_connectivity/table_size_specs.tex
  Tables/layer_connectivity/table_size_specs.csv

Structure:
  - 4 panels (edu, edu2, gender, race)
  - Columns: 3 outcomes × 4 sub-columns
      (1) within-firm small   (2) within-firm large
      (3) cross-firm small    (4) cross-firm large

Usage:
  ~/.conda/envs/venv_python312/bin/python Programs/layer_connectivity/09_make_table_size_specs.py
"""

from pathlib import Path
import pandas as pd

# ── Paths ───────────────────────────────────────────────────────────────────────
PROJ   = Path(__file__).resolve().parent.parent.parent
TABLES = PROJ / "Tables" / "layer_connectivity"

# ── Load one CSV (same format as 07_layer_spillover_size.do output) ─────────────
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

SIZES      = ["small", "large"]
SIZE_LABELS = {"small": "Small", "large": "Large"}

# (col_index, file_template, section_key, size)
COLS = [
    (0, "results_spill_layer_{layer}_size_{size}_layer_spill.csv",       "spill", "small"),
    (1, "results_spill_layer_{layer}_size_{size}_layer_spill.csv",       "spill", "large"),
    (2, "results_spill_layer_cross_{layer}_size_{size}_layer_spill.csv", "cross", "small"),
    (3, "results_spill_layer_cross_{layer}_size_{size}_layer_spill.csv", "cross", "large"),
]

OUTCOMES = ["lr_remdezr_layer", "lr_remdezr_h_layer", "l_layer_emp"]
OUTCOME_SHORT = ["Log Dec. wage", "Log hourly wage", "Log employment"]

STAT_ROWS = [
    ("n_obs",    "Observations"),
    ("n_cells",  "Layers $\\times$ firms"),
    ("n_firms",  "Firms"),
    ("pre_pval", "Pre-trend F-test $p$-value"),
]

# ── Load all data ───────────────────────────────────────────────────────────────
# data[(layer, col_idx, outcome, row_type)] = value_string
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
            key = (layer, col_idx, row["outcome"], row["row_type"])
            data[key] = row["value"]

if missing_files:
    print("WARNING — missing files (run 07_layer_spillover_size.do first):")
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
N_COLS = len(COLS)   # 4 sub-columns per outcome group

def build_latex() -> str:
    lines = []
    ncols_total = 1 + len(OUTCOMES) * N_COLS  # 1 + 3*4 = 13

    lines.append(r"\begin{table}[htbp]")
    lines.append(r"\centering")
    lines.append(r"\caption{Layer spillover effects by firm size}")
    lines.append(r"\label{tab:size_specs}")
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
    lines.append(r"\footnotesize\vspace{4pt}")
    lines.append(
        r"\textit{Notes:} All regressions restricted to untreated, balanced-panel firms in the Lagos sample. "
        r"Small firms have average December employment 2009--2011 below the median (31.7 workers); "
        r"large firms are at or above the median. "
        r"Connectivity is scaled to the 90th percentile of the full control sample at 2009 "
        r"(same scale for both size groups). "
        r"The pre-trend (placebo) coefficient uses a fictitious treatment onset at 2010, "
        r"estimated on the pre-reform period (2007--2011) only. "
        r"Pre-trend F-test $p$-value tests joint significance of all pre-trend event-study coefficients. "
        r"Within-firm specifications absorb firm$\times$year FE; identification exploits "
        r"cross-layer variation within the same firm--year. "
        r"Cross-firm specifications include microregion$\times$year, industry$\times$year, "
        r"and mode$\times$year FE. "
        r"Standard errors clustered at the firm level. "
        r"$^{***}p<0.01$, $^{**}p<0.05$, $^{*}p<0.10$."
    )
    lines.append(r"\end{minipage}")
    lines.append(r"\end{table}")
    return "\n".join(lines)


# ── Build flat CSV ───────────────────────────────────────────────────────────────
def build_csv() -> pd.DataFrame:
    col_labels = ["within_small", "within_large", "cross_small", "cross_large"]
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

tex_out = TABLES / "table_size_specs.tex"
csv_out = TABLES / "table_size_specs.csv"

tex = build_latex()
tex_out.write_text(tex)
print(f"Wrote: {tex_out}")

df_out = build_csv()
df_out.to_csv(csv_out, index=False)
print(f"Wrote: {csv_out}")

print()
print(df_out.to_string(index=False))
