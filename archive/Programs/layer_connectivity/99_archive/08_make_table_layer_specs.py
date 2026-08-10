"""
Assemble comparison table across layer spillover specifications.

Reads CSVs produced by 07b_layer_spillover.do and outputs:
  Tables/layer_connectivity/table_layer_specs_lbal.tex
  Tables/layer_connectivity/table_layer_specs_lbal.csv

Specs included:
  (1) Within-firm FE     — firm×year FE, layer connectivity
                           results_spill_layer_{edu2,gender,race}_lbal_layer_spill.csv
  (2) Cross-firm FE      — micro×year + industry×year + mode×year FE
                           results_spill_layer_cross_{edu2,gender,race}_lbal_layer_spill.csv
  (3) Firm-level restr.  — firm-level outcomes, standard FE, restricted sample
                           results_spill_firmrestr_{edu2,gender,race}_lbal_layer_spill.csv

Usage:
  ~/.conda/envs/venv_python312/bin/python Programs/layer_connectivity/08_make_table_layer_specs.py
"""

from pathlib import Path
import pandas as pd

# ── Paths ──────────────────────────────────────────────────────────────────────
PROJ   = Path(__file__).resolve().parent.parent.parent
TABLES = PROJ / "Tables" / "layer_connectivity"
TEX_TABLES = TABLES / "tex_tables"

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
        "file_tpl":    "results_spill_layer_{layer}_lbal_layer_spill.csv",
        "section_key": "spill",
        "outcomes":    ["lr_remdezr_layer", "l_layer_emp"],
        "outcome_labels": {
            "lr_remdezr_layer":   "Log Dec. wage (layer avg.)",
            "l_layer_emp":        "Log employment (layer)",
        },
    },
    {
        "label":       "(2) Cross-firm FE",
        "sublabel":    "micro$\\times$yr + ind$\\times$yr + mode$\\times$yr",
        "file_tpl":    "results_spill_layer_cross_{layer}_lbal_layer_spill.csv",
        "section_key": "cross",
        "outcomes":    ["lr_remdezr_layer", "l_layer_emp"],
        "outcome_labels": {
            "lr_remdezr_layer":   "Log Dec. wage (layer avg.)",
            "l_layer_emp":        "Log employment (layer)",
        },
    },
    {
        "label":       "(3) Firm-level (restricted)",
        "sublabel":    "firm FE",
        "file_tpl":    "results_spill_firmrestr_{layer}_lbal_layer_spill.csv",
        "section_key": "firmrestr",
        "outcomes":    ["lr_remdezr_w", "l_firm_emp"],
        "outcome_labels": {
            "lr_remdezr_w":   "Log Dec. wage (firm avg.)",
            "l_firm_emp":     "Log employment (firm)",
        },
    },
]

LAYERS = ["edu2", "gender", "race"]
LAYER_LABELS = {
    "edu2":   "2-bin education (no HS / has HS)",
    "gender": "Gender (female / male)",
    "race":   "Race (non-white / white)",
}

# Split into two tables
LAYER_GROUPS = {
    "edu":   (["edu2"],             "Education layers"),
    "demog": (["gender", "race"],   "Demographic layers"),
}

OUTCOME_ORDER = [
    # (generic label, spec1_outcome, spec2_outcome, spec3_outcome)
    ("Log Dec. wage",  "lr_remdezr_layer", "lr_remdezr_layer", "lr_remdezr_w"),
    ("Log employment", "l_layer_emp",      "l_layer_emp",      "l_firm_emp"),
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
    print("WARNING — missing files (run 07b_layer_spillover.do first):")
    for f in missing_files:
        print(f"  {f}")
    if len(missing_files) == len(LAYERS) * len(SPECS):
        raise SystemExit("No data found. Exiting.")


def get(layer, si, outcome, row_type, default="--"):
    if outcome is None:
        return default
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
    "Log employment",
]

def build_latex(layers_subset: list, caption: str, label: str) -> str:
    lines = []
    n_outcomes = len(OUTCOME_ORDER)
    # Panels = layers; columns = outcomes × specs
    ncols = 1 + n_outcomes * n_spec  # 1 + 3*3 = 10

    lines.append(r"\begin{table}[H]")
    lines.append(r"\centering")
    lines.append(r"\caption{" + caption + r"}")
    lines.append(r"\label{" + label + r"}")
    col_spec = "l" + "".join(["ccc"] * n_outcomes)
    lines.append(r"\resizebox{\textwidth}{!}{%")
    lines.append(r"\begin{tabular}{" + col_spec + r"}")
    lines.append(r"\toprule\toprule")

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

    # Header row 2 — sequential numbering (1)–(n_outcomes*n_spec)
    header2 = [""]
    for col_num in range(1, n_outcomes * n_spec + 1):
        header2.append(f"({col_num})")
    lines.append(" & ".join(header2) + r" \\")
    lines.append(r"\midrule")

    # One panel per layer bin specification
    for li, layer in enumerate(layers_subset):
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
            end = r" \\[6pt]" if is_last_stat and li < len(layers_subset) - 1 else r" \\"
            lines.append(" & ".join(stat_cells) + end)

    lines.append(r"\midrule")

    # Checkmark panel — specs (1)(2)(3) repeat identically across outcome groups
    lines.append(r"\multicolumn{" + str(ncols) + r"}{l}{\textit{Specification}} \\")

    CHECKMARK_ROWS = [
        ("Layer-level outcomes",            lambda si: si in (0, 1)),
        ("Firm-level outcomes",             lambda si: si == 2),
        ("Firm $\\times$ year FE",          lambda si: si == 0),
        ("Firm-level FE",                   lambda si: si == 1),
        ("Firm FE",                         lambda si: si == 2),
    ]

    for label, condition in CHECKMARK_ROWS:
        cells = [label]
        for _ in OUTCOME_ORDER:
            for si in range(n_spec):
                cells.append(r"\checkmark" if condition(si) else "---")
        lines.append(" & ".join(cells) + r" \\")

    lines.append(r"\bottomrule")
    lines.append(r"\end{tabular}}")
    lines.append(r"\begin{minipage}{\linewidth}")
    lines.append(r"\scriptsize\vspace{4pt}")
    lines.append(
        r"\textit{Notes:} This table compares spillover effects of layer-level connectivity to treated firms "
        r"across three specifications and three worker-partitioning schemes. "
        r"All regressions are restricted to untreated firms in the balanced firm panel and, for layer-level specifications, "
        r"to firms with positive employment in all layers in all years 2009--2016. "
        r"Connectivity is scaled to the 90th percentile of the control sample at 2009 and is "
        r"interacted with a post-2012 indicator (S\'{u}mula 277 reform). The pre-trend (placebo) coefficient "
        r"tests whether connectivity predicts differential outcomes in 2009--2010 relative to 2011, "
        r"using only pre-reform years (2009--2011). "
        r"The pre-trend F-test $p$-value tests the joint significance of all pre-trend event-study "
        r"coefficients; small values indicate detectable pre-trends."
    )
    lines.append(r"")
    # Build sequential column references for notes
    within_cols  = ", ".join(f"({1 + oi*n_spec})"     for oi in range(n_outcomes))
    cross_cols   = ", ".join(f"({2 + oi*n_spec})"     for oi in range(n_outcomes))
    firm_cols    = ", ".join(f"({3 + oi*n_spec})"     for oi in range(n_outcomes))
    layer_cols   = ", ".join(
        f"({1 + oi*n_spec}) and ({2 + oi*n_spec})" for oi in range(n_outcomes)
    )
    lines.append(
        r"\textit{Outcome levels.} Columns " + within_cols + r" and " + cross_cols
        + r" use \textit{layer-level} outcomes: "
        r"each observation is a firm--layer--year cell, and the connectivity measure captures the share "
        r"of that layer's outflows reaching treated firms. "
        r"Columns " + firm_cols + r" use \textit{firm-level} outcomes and the aggregate firm-level connectivity, "
        r"restricted to the subset of firms present in the layer sample."
    )
    lines.append(r"")
    lines.append(
        r"\textit{Fixed effects.} Columns " + within_cols
        + r" (within-firm) absorb firm$\times$year FE; "
        r"identification comes from cross-layer variation within the same firm--year. "
        r"Columns " + cross_cols
        + r" (cross-firm) include firm-level FE: microregion$\times$year, industry$\times$year, "
        r"and mode$\times$year, controlling for local labor-market trends, sector shocks, and "
        r"contract-type composition. "
        r"Columns " + firm_cols
        + r" (firm-level) include firm FE and year FE."
    )
    lines.append(r"")
    lines.append(
        r"\textit{Layer definitions.} Panel A partitions workers by 2-bin education: "
        r"no high-school diploma (no HS) versus completed high school or more. "
        r"Panel B partitions workers by gender (female / male). "
        r"Panel C classifies workers as non-white or white."
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
def build_csv(layers_subset: list) -> pd.DataFrame:
    rows = []
    for layer in layers_subset:
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

CAPTIONS = {
    "edu":   "Layer spillover effects with balanced layer panels --- education layers",
    "demog": "Layer spillover effects with balanced layer panels --- demographic layers",
}
LABELS = {
    "edu":   "tab:layer_specs_lbal_edu",
    "demog": "tab:layer_specs_lbal_demog",
}

for group_key, (layers_subset, _) in LAYER_GROUPS.items():
    tex_out = TEX_TABLES / f"table_layer_specs_lbal_{group_key}.tex"
    csv_out = TABLES / f"table_layer_specs_lbal_{group_key}.csv"

    tex = build_latex(layers_subset, CAPTIONS[group_key], LABELS[group_key])
    tex_out.write_text(tex)
    print(f"Wrote: {tex_out}")

    df_out = build_csv(layers_subset)
    df_out.to_csv(csv_out, index=False)
    print(f"Wrote: {csv_out}")

    print()
    print(df_out.to_string(index=False))
    print()

# Also keep the combined table for backwards compatibility
tex_out_all = TEX_TABLES / "table_layer_specs_lbal.tex"
csv_out_all = TABLES / "table_layer_specs_lbal.csv"
tex_all = build_latex(LAYERS, "Layer spillover effects with balanced layer panels --- specification comparison", "tab:layer_specs_lbal")
tex_out_all.write_text(tex_all)
df_all = build_csv(LAYERS)
df_all.to_csv(csv_out_all, index=False)
print(f"Wrote: {tex_out_all}")
print(f"Wrote: {csv_out_all}")
