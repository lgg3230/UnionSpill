"""
Assemble disentangling tables from 11_disentangling_layers.do output.

Column organization (restructured):
  For each layer definition (edu2, gender, race):
    For each regressor lv_r:
      For each outcome:
        Columns: [cross-layer lv_o (all lv != lv_r), own-layer lv_o=lv_r, firm-level]
        = (n_lv + 1) columns per outcome per regressor

Layer-level regressions (section=layer_firm_year):
  outcome key = {out_prefix}_{lv_o}  (e.g. lr_remdezr_layer_no_hs)
  row_types   = c_{lv_r}_main, c_{lv_r}_main_se, c_{lv_r}_pre, c_{lv_r}_pre_se,
                c_{lv_r}_pre_ftest, c_{lv_r}_n_obs, c_{lv_r}_n_firms

Firm-level regressions (section=firm_firm_year):
  outcome key = {firm_outcome}        (e.g. lr_remdezr_w)
  row_types   = c_{lv}_main, c_{lv}_main_se, c_{lv}_pre, c_{lv}_pre_se,
                c_{lv}_pre_ftest, c_{lv}_n_obs, c_{lv}_n_firms

Output:
  Tables/layer_connectivity/table_disentangle_demog.tex / .csv

Usage:
  ~/.conda/envs/venv_python312/bin/python Programs/layer_connectivity/12_make_table_disentangle.py
"""

from pathlib import Path
import pandas as pd

PROJ   = Path(__file__).resolve().parent.parent.parent
TABLES = PROJ / "Tables" / "layer_connectivity"
TEX_TABLES = TABLES / "tex_tables"

# ── CSV loader ────────────────────────────────────────────────────────────────
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

# ── Configuration ─────────────────────────────────────────────────────────────
LAYER_VALS = {
    "edu2":   ["no_hs",   "has_hs"],
    "gender": ["female",  "male"],
    "race":   ["nonwhite","white"],
}

LV_LABELS = {
    "no_hs":    "No HS",
    "has_hs":   "Has HS",
    "female":   "Female",
    "male":     "Male",
    "nonwhite": "Non-white",
    "white":    "White",
}

LAYER_LABELS = {
    "edu2":   "2-bin education (no HS / has HS)",
    "gender": "Gender (female / male)",
    "race":   "Race (non-white / white)",
}

# edu excluded: 3-bin would make the table unmanageably wide
LAYER_GROUPS = {
    "demog": (["edu2", "gender", "race"], "Education and demographic layers"),
}

# (short label, layer-outcome prefix, firm-outcome key)
OUTCOMES = [
    ("Log Dec. wage",   "lr_remdezr_layer",  "lr_remdezr_w"),
    ("Log hourly wage", "lr_remdezr_h_layer", "lr_remdezr_h_w"),
    ("Log employment",  "l_layer_emp",        "l_firm_emp"),
]

LAYER_SECTION = "layer_firm_year"
FIRM_SECTION  = "firm_firm_year"

# ── Formatting helpers ────────────────────────────────────────────────────────
def fmt_coef(v: str) -> str:
    return v.strip() if v.strip() not in ("--", "") else "--"

def fmt_se(v: str) -> str:
    s = v.strip()
    if s in ("--", ""):
        return "--"
    try:
        return f"({float(s):.4f})"
    except ValueError:
        return s

def fmt_stat(v: str, is_pval: bool = False) -> str:
    s = v.strip()
    if s in ("--", ""):
        return "---"
    if is_pval:
        try:
            return f"{float(s):.3f}"
        except ValueError:
            return s
    return s

# ── Load data ─────────────────────────────────────────────────────────────────
LAYERS_NEEDED = ["edu2", "gender", "race"]
data: dict = {}
missing: list = []

for layer in LAYERS_NEEDED:
    fpath = TABLES / f"results_disentangle_{layer}_layer_spill.csv"
    if not fpath.exists():
        missing.append(str(fpath))
        continue
    for _, row in load_csv(fpath).iterrows():
        data[(layer, row["section"], row["outcome"], row["row_type"])] = row["value"]

if missing:
    print("WARNING — missing files (run 11_disentangling_layers.do first):")
    for f in missing:
        print(f"  {f}")
    if len(missing) == len(LAYERS_NEEDED):
        raise SystemExit("No data found.")

def get(layer, section, outcome, row_type, default="--"):
    return data.get((layer, section, outcome, row_type), default)

# ── Value lookups ─────────────────────────────────────────────────────────────
def lget(layer, lv_r, lv_o, out_prefix, rt):
    """Layer-level: outcome key = {out_prefix}_{lv_o}, row_type = c_{lv_r}_{rt}."""
    return get(layer, LAYER_SECTION, f"{out_prefix}_{lv_o}", f"c_{lv_r}_{rt}")

def fget(layer, lv_r, out_firm, rt):
    """Firm-level: outcome key = out_firm, row_type = c_{lv_r}_{rt}."""
    return get(layer, FIRM_SECTION, out_firm, f"c_{lv_r}_{rt}")

# ── LaTeX variable label ─────────────────────────────────────────────────────
def lv_latex(lv: str) -> str:
    """Format lv as LaTeX math: $c_{\\text{no\\_hs}}$ etc."""
    tex_name = lv.replace("_", r"\_")
    return f"$c_{{\\text{{{tex_name}}}}}$"

# ── Column order helper ───────────────────────────────────────────────────────
def lv_o_order(lvs: list, lv_r: str) -> list:
    """Own-layer (lv_r) first, then cross-layer (all lv != lv_r)."""
    others = [lv for lv in lvs if lv != lv_r]
    return [lv_r] + others

# ── LaTeX builder ─────────────────────────────────────────────────────────────
def build_latex(layers_subset: list, caption: str, label: str) -> str:
    lines = []
    n_out    = len(OUTCOMES)
    # All layers in subset have n_lv=2; max is 2
    max_n_lv = max(len(LAYER_VALS[la]) for la in layers_subset)
    max_n_reg = max_n_lv  # one regressor per lv value
    # Columns per regressor group = n_out × (n_lv + 1)
    span_per_reg = n_out * (max_n_lv + 1)
    n_data   = max_n_reg * span_per_reg
    ncols    = 1 + n_data

    col_spec = "l" + "c" * n_data
    lines.append(r"\begin{table}[H]")
    lines.append(r"\centering")
    lines.append(r"\caption{" + caption + r"}")
    lines.append(r"\label{" + label + r"}")
    lines.append(r"\resizebox{\textwidth}{!}{%")
    lines.append(r"\begin{tabular}{" + col_spec + r"}")
    lines.append(r"\toprule\toprule")

    # ── Header row 1: outcome sub-groups (span n_lv+1 each) ─────────────────
    h2 = [""]
    for _ in range(max_n_reg):
        for out_label, _, _ in OUTCOMES:
            h2.append(r"\multicolumn{" + str(max_n_lv + 1) + r"}{c}{" + out_label + r"}")
    lines.append(" & ".join(h2) + r" \\")

    cmi2 = []
    col = 2
    for _ in range(max_n_reg * n_out):
        cmi2.append(f"\\cmidrule(lr){{{col}-{col + max_n_lv}}}")
        col += max_n_lv + 1
    lines.append(" ".join(cmi2))

    # ── Header row 3: own/cross/firm labels + sequential numbers ─────────────
    h3 = [""]
    cn = 1
    for _ in range(max_n_reg):
        for _ in OUTCOMES:
            # own-layer column (first)
            h3.append(r"\shortstack{Own layer \\ (" + str(cn) + r")}")
            cn += 1
            # cross-layer columns (all but first)
            for oi in range(max_n_lv - 1):
                h3.append(r"\shortstack{Cross-layer \\ (" + str(cn) + r")}")
                cn += 1
            # firm column
            h3.append(r"\shortstack{Firm \\ (" + str(cn) + r")}")
            cn += 1
    lines.append(" & ".join(h3) + r" \\")
    lines.append(r"\midrule")

    # ── Panels ────────────────────────────────────────────────────────────────
    for pi, layer in enumerate(layers_subset):
        lvs   = LAYER_VALS[layer]
        n_lv  = len(lvs)
        letter = chr(ord("A") + pi)

        lines.append(
            r"\multicolumn{" + str(ncols) + r"}{l}{\textit{Panel "
            + letter + r": " + LAYER_LABELS[layer] + r"}} \\"
        )

        def full_row(row_label, layer_fn, firm_fn, layer=layer, lvs=lvs, n_lv=n_lv):
            cells = [row_label]
            for ri in range(max_n_reg):
                if ri < n_lv:
                    lv_r   = lvs[ri]
                    lv_ord = lv_o_order(lvs, lv_r)
                    for _, out_layer, out_firm in OUTCOMES:
                        for lv_o in lv_ord:
                            cells.append(layer_fn(layer, lv_r, lv_o, out_layer))
                        cells.append(firm_fn(layer, lv_r, out_firm))
                else:
                    cells += [""] * (n_out * (max_n_lv + 1))
            return cells

        # Main coefficient row
        lines.append(" & ".join(full_row(
            r"\quad Connectivity $\times$ Post",
            lambda la, lr, lo, ol: fmt_coef(lget(la, lr, lo, ol, "main")),
            lambda la, lr, of:     fmt_coef(fget(la, lr, of, "main")),
        )) + r" \\")

        # SE row
        lines.append(" & ".join(full_row(
            "",
            lambda la, lr, lo, ol: fmt_se(lget(la, lr, lo, ol, "main_se")),
            lambda la, lr, of:     fmt_se(fget(la, lr, of, "main_se")),
        )) + r" \\")

        # Pre-trend row
        lines.append(" & ".join(full_row(
            r"\quad Pre-trend (placebo)",
            lambda la, lr, lo, ol: fmt_coef(lget(la, lr, lo, ol, "pre")),
            lambda la, lr, of:     fmt_coef(fget(la, lr, of, "pre")),
        )) + r" \\")

        # Pre-trend SE row
        lines.append(" & ".join(full_row(
            "",
            lambda la, lr, lo, ol: fmt_se(lget(la, lr, lo, ol, "pre_se")),
            lambda la, lr, of:     fmt_se(fget(la, lr, of, "pre_se")),
        )) + r" \\")

        STAT_ROWS = [
            ("Observations",
             lambda la, lr, lo, ol: fmt_stat(lget(la, lr, lo, ol, "n_obs")),
             lambda la, lr, of:     fmt_stat(fget(la, lr, of, "n_obs"))),
            ("Firms",
             lambda la, lr, lo, ol: fmt_stat(lget(la, lr, lo, ol, "n_firms")),
             lambda la, lr, of:     fmt_stat(fget(la, lr, of, "n_firms"))),
            ("Pre-trend F-test $p$-value",
             lambda la, lr, lo, ol: fmt_stat(lget(la, lr, lo, ol, "pre_ftest"), is_pval=True),
             lambda la, lr, of:     fmt_stat(fget(la, lr, of, "pre_ftest"), is_pval=True)),
        ]

        for si, (stat_label, lfn, ffn) in enumerate(STAT_ROWS):
            lines.append(" & ".join(full_row(
                r"\quad " + stat_label, lfn, ffn,
            )) + r" \\")

        # Per-panel regressor checkmark rows (below data)
        for ri, lv_r in enumerate(lvs):
            reg_label = r"\quad Regressor: " + lv_latex(lv_r)
            cells = [reg_label]
            for lv_idx in range(max_n_reg):
                mark = r"\checkmark" if lv_idx == ri else "---"
                for _ in OUTCOMES:
                    for _ in range(max_n_lv + 1):
                        cells.append(mark)
            is_last_reg   = ri == len(lvs) - 1
            is_last_panel = pi == len(layers_subset) - 1
            end = r" \\[6pt]" if is_last_reg and not is_last_panel else r" \\"
            lines.append(" & ".join(cells) + end)

    # ── Spec rows (shared across all panels) ──────────────────────────────────
    lines.append(r"\midrule")
    lines.append(r"\midrule")
    lines.append(
        r"\multicolumn{" + str(ncols) + r"}{l}{\textit{Specification}} \\"
    )

    # Level and FE rows (col_marks length = max_n_lv + 1)
    spec_rows = [
        # label,                   per-outcome column marks
        ("Layer-level outcomes",   [r"\checkmark"] * max_n_lv + ["---"]),
        ("Firm-level outcomes",    ["---"] * max_n_lv + [r"\checkmark"]),
        ("Own-layer outcome",      [r"\checkmark"] + ["---"] * (max_n_lv - 1) + ["---"]),
        ("Cross-layer outcome",    ["---"] + [r"\checkmark"] * (max_n_lv - 1) + ["---"]),
        ("Firm FE",                [r"\checkmark"] * (max_n_lv + 1)),
        ("Year FE",                [r"\checkmark"] * (max_n_lv + 1)),
    ]

    for row_label, col_marks in spec_rows:
        cells = [row_label]
        for _ in range(max_n_reg):
            for _ in OUTCOMES:
                cells += col_marks
        lines.append(" & ".join(cells) + r" \\")

    lines.append(r"\bottomrule")
    lines.append(r"\end{tabular}}")

    # Notes
    lines.append(r"\begin{minipage}{\linewidth}")
    lines.append(r"\scriptsize\vspace{4pt}")
    lines.append(
        r"\textit{Notes:} This table tests which worker group's connectivity to treated firms "
        r"drives the spillover effect. Column groups correspond to a specific connectivity variable "
        r"(the regressor), identified by checkmarks at the bottom. "
        r"Layer-level regressions restrict the sample to workers in the indicated layer "
        r"(cross-layer or own-layer as shown) and absorb firm FE and year FE. "
        r"Firm-level regressions collapse to firm$\times$year and absorb firm FE and year FE. "
        r"In all cases the regressor is the focal connectivity variable interacted with a "
        r"post-2012 indicator (S\'{u}mula 277 reform). "
        r"All regressions are restricted to untreated, balanced-panel firms. "
        r"Connectivity is scaled to the 90th percentile of the control sample at 2009. "
        r"Standard errors clustered at the firm level. "
        r"$^{***}p<0.01$, $^{**}p<0.05$, $^{*}p<0.10$."
    )
    lines.append(r"\end{minipage}")
    lines.append(r"\end{table}")
    return "\n".join(lines)


# ── CSV builder ───────────────────────────────────────────────────────────────
def build_csv(layers_subset: list) -> pd.DataFrame:
    rows = []
    for layer in layers_subset:
        lvs = LAYER_VALS[layer]
        for lv_r in lvs:
            for out_label, out_layer, out_firm in OUTCOMES:
                # Layer-level columns: cross first, then own
                for lv_o in lv_o_order(lvs, lv_r):
                    is_own = (lv_o == lv_r)
                    rows.append({
                        "layer":     layer,
                        "regressor": lv_r,
                        "outcome":   out_label,
                        "level":     "own_layer" if is_own else "cross_layer",
                        "lv_o":      lv_o,
                        "main":      fmt_coef(lget(layer, lv_r, lv_o, out_layer, "main")),
                        "main_se":   fmt_se(  lget(layer, lv_r, lv_o, out_layer, "main_se")),
                        "pre":       fmt_coef(lget(layer, lv_r, lv_o, out_layer, "pre")),
                        "pre_se":    fmt_se(  lget(layer, lv_r, lv_o, out_layer, "pre_se")),
                        "pre_ftest": fmt_stat(lget(layer, lv_r, lv_o, out_layer, "pre_ftest"), is_pval=True),
                        "n_obs":     fmt_stat(lget(layer, lv_r, lv_o, out_layer, "n_obs")),
                        "n_firms":   fmt_stat(lget(layer, lv_r, lv_o, out_layer, "n_firms")),
                    })
                # Firm-level column
                rows.append({
                    "layer":     layer,
                    "regressor": lv_r,
                    "outcome":   out_label,
                    "level":     "firm",
                    "lv_o":      "firm",
                    "main":      fmt_coef(fget(layer, lv_r, out_firm, "main")),
                    "main_se":   fmt_se(  fget(layer, lv_r, out_firm, "main_se")),
                    "pre":       fmt_coef(fget(layer, lv_r, out_firm, "pre")),
                    "pre_se":    fmt_se(  fget(layer, lv_r, out_firm, "pre_se")),
                    "pre_ftest": fmt_stat(fget(layer, lv_r, out_firm, "pre_ftest"), is_pval=True),
                    "n_obs":     fmt_stat(fget(layer, lv_r, out_firm, "n_obs")),
                    "n_firms":   fmt_stat(fget(layer, lv_r, out_firm, "n_firms")),
                })
    return pd.DataFrame(rows)


# ── Write outputs ─────────────────────────────────────────────────────────────
TABLES.mkdir(parents=True, exist_ok=True)

CAPTIONS = {
    "demog": "Disentangling layer spillover effects --- education and demographics",
}
LABELS = {
    "demog": "tab:disentangle_demog",
}

for group_key, (layers_subset, _) in LAYER_GROUPS.items():
    tex_out = TEX_TABLES / f"table_disentangle_{group_key}.tex"
    csv_out = TABLES / f"table_disentangle_{group_key}.csv"

    tex = build_latex(layers_subset, CAPTIONS[group_key], LABELS[group_key])
    tex_out.write_text(tex)
    print(f"Wrote: {tex_out}")

    df_out = build_csv(layers_subset)
    df_out.to_csv(csv_out, index=False)
    print(f"Wrote: {csv_out}")
    print()
    print(df_out.to_string(index=False))
    print()
