#!/usr/bin/env python
"""
honest_did_plot.py
Reads Tables/honest_did/honest_did_results.csv (produced by honest_did.do),
computes the breakdown value of Mbar (Delta^RM) and M (Delta^SD) at which the
robust CI first includes zero, writes a summary table (CSV + LaTeX), and makes
sensitivity plots (robust CI band vs Mbar/M, original OLS CI overlaid).

Run with the project conda python:
  ~/.conda/envs/venv_python312/bin/python Programs/honest_did/honest_did_plot.py
"""
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Patch
from matplotlib.lines import Line2D

# ── paths (Programs/honest_did/ -> root) ────────────────────────────────────
HERE        = Path(__file__).resolve().parent
ROOT        = HERE.parent.parent
TABLES_DIR  = ROOT / "Tables" / "honest_did"
GRAPHS_DIR  = ROOT / "Graphs" / "honest_did"
GRAPHS_DIR.mkdir(parents=True, exist_ok=True)
RESULTS_CSV = TABLES_DIR / "honest_did_results.csv"

# ── fonts (Libertinus Serif, text + mathtext; silent fallback) ──────────────
try:
    import matplotlib.font_manager as fm
    _variants = ["LibertinusSerif-Regular.otf", "LibertinusSerif-Italic.otf",
                 "LibertinusSerif-Bold.otf", "LibertinusSerif-BoldItalic.otf"]
    _loaded = False
    for d in ["/kellogg/proj/lgg3230/UnionSpill/Programs/fonts",
              str(HERE.parent / "fonts")]:
        if Path(d).exists():
            for v in _variants:
                fp = Path(d) / v
                if fp.exists():
                    fm.fontManager.addfont(str(fp))
                    _loaded = True
            if _loaded:
                break
    if _loaded:
        plt.rcParams["font.family"]       = "Libertinus Serif"
        plt.rcParams["mathtext.fontset"]  = "custom"
        plt.rcParams["mathtext.rm"]       = "Libertinus Serif"
        plt.rcParams["mathtext.it"]       = "Libertinus Serif:italic"
        plt.rcParams["mathtext.bf"]       = "Libertinus Serif:bold"
        plt.rcParams["mathtext.sf"]       = "Libertinus Serif"
        plt.rcParams["mathtext.cal"]      = "Libertinus Serif:italic"
        plt.rcParams["mathtext.fallback"] = "cm"
except Exception:
    pass

C_ORIG   = "#2166AC"   # original OLS CI (blue)
C_ROBUST = "#B2182B"   # robust honest-DiD CI (red)

OUTCOME_LABEL = {
    "lr_remdezr_w":   "Log wages",
    "lr_remdezr_h_w": "Log hourly wages",
    "l_firm_emp":     "Log employment",
    "numb_clauses":   "# CBA clauses",
}
OUTCOME_ORDER = ["lr_remdezr_w", "lr_remdezr_h_w", "l_firm_emp", "numb_clauses"]
EFFECT_LABEL  = {"direct": "Direct", "spill": "Spillover"}
RESTR_LABEL   = {"rm": r"$\Delta^{RM}$ (relative magnitudes)",
                 "sd": r"$\Delta^{SD}$ (smoothness)"}
RESTR_X       = {"rm": r"$\bar{M}$", "sd": r"$M$"}

# target = which post-period coefficient the sensitivity CI is built around
# (honestdid l_vec). p1 = first post period (the default), ..., avg = average.
TARGET_ORDER  = ["p1", "p2", "p3", "p4", "p5", "avg"]
TARGET_LABEL  = {
    "p1":  "1st post period (yr 2012 / cba 3)",
    "p2":  "2nd post period (yr 2013 / cba 4)",
    "p3":  "3rd post period (yr 2014 / cba 5)",
    "p4":  "4th post period (yr 2015 / cba 6)",
    "p5":  "5th post period (yr 2016; clauses n/a)",
    "avg": "average of post periods",
}


def breakdown(m, lb, ub):
    """Smallest M at which the robust CI first includes zero (lb<=0<=ub).
    Linear interpolation between grid points on lb. Returns (value, status).
    status: 'broken_at_zero' | float-in-grid | 'robust_beyond_grid'."""
    order = np.argsort(m)
    m, lb, ub = m[order], lb[order], ub[order]
    includes0 = (lb <= 0) & (ub >= 0)
    if includes0[0]:
        return m[0], "at_min"
    for i in range(1, len(m)):
        if includes0[i]:
            # interpolate where lb crosses 0 between i-1 and i
            if lb[i] != lb[i-1]:
                frac = lb[i-1] / (lb[i-1] - lb[i])
                bd = m[i-1] + frac * (m[i] - m[i-1])
            else:
                bd = m[i]
            return float(bd), "in_grid"
    return m[-1], "beyond_grid"   # never includes 0 within the grid


def main():
    df = pd.read_csv(RESULTS_CSV)
    if "target" not in df.columns:        # backward compat with old CSVs
        df["target"] = "p1"
    failed = df[df["is_original"].astype(str) == "FAILED"]
    df = df[df["is_original"].astype(str) != "FAILED"].copy()
    for c in ["m", "lb", "ub", "is_original"]:
        df[c] = pd.to_numeric(df[c], errors="coerce")

    summary = []
    for (effect, outcome, restr, target), g in df.groupby(
            ["effect", "outcome", "restriction", "target"]):
        og = g[g["is_original"] == 1]
        grid = g[g["is_original"] == 0].sort_values("m")
        if grid.empty:
            continue
        bd, status = breakdown(grid["m"].values, grid["lb"].values, grid["ub"].values)
        og_lb = float(og["lb"].iloc[0]) if not og.empty else np.nan
        og_ub = float(og["ub"].iloc[0]) if not og.empty else np.nan
        summary.append(dict(effect=effect, outcome=outcome, restriction=restr,
                            target=target, breakdown=bd, status=status,
                            grid_max=float(grid["m"].max()),
                            og_lb=og_lb, og_ub=og_ub))
    # mark failed specs in the summary too
    for _, r in failed.iterrows():
        summary.append(dict(effect=r["effect"], outcome=r["outcome"],
                            restriction=r["restriction"], target=r.get("target", "p1"),
                            breakdown=np.nan, status="FAILED", grid_max=np.nan,
                            og_lb=np.nan, og_ub=np.nan))
    sm = pd.DataFrame(summary)

    # ── flag fragile RM breakdowns (Mbar<1 = not robust to post=pre violations) ─
    def flag(row):
        if row["status"] == "FAILED":
            return "infeasible"
        # numb_clauses rests on a single pre-period (CBA-period structure)
        caveat = " [1 pre-period]" if row["outcome"] == "numb_clauses" else ""
        # If the ORIGINAL OLS CI already includes zero, the effect is not
        # significant to begin with: breakdown is mechanically 0 and the
        # honest-DiD exercise is uninformative about it (not "fragility").
        if (not np.isnan(row["og_lb"])) and (row["og_lb"] <= 0 <= row["og_ub"]):
            return "OLS n.s." + caveat
        if row["status"] == "beyond_grid":
            return "robust>grid" + caveat
        if row["restriction"] == "rm":
            if row["breakdown"] < 0.5:  return "VERY FRAGILE" + caveat
            if row["breakdown"] < 1.0:  return "fragile" + caveat
            return "ok" + caveat
        return caveat.strip()  # SD scale-dependent: report numeric only
    sm["flag"] = sm.apply(flag, axis=1)

    sm = sm.sort_values(["restriction", "target", "effect", "outcome"])
    sm.to_csv(TABLES_DIR / "honest_did_breakdown.csv", index=False)
    print(sm.to_string(index=False))

    # headline LaTeX table uses the first post period (p1, the honestdid default)
    write_latex(sm[sm["target"] == "p1"])

    targets = [t for t in TARGET_ORDER if t in set(df["target"].unique())]
    for restr in ["rm", "sd"]:
        for target in targets:
            plot_grid(df[df["target"] == target],
                      sm[sm["target"] == target], restr, target)

    if not sm.empty:
        frag = sm[sm["flag"].isin(["VERY FRAGILE", "fragile", "infeasible (1 pre-period)"])]
        if not frag.empty:
            print("\n*** SPECS TO DIG INTO (low/infeasible breakdown) ***")
            print(frag[["effect", "outcome", "restriction", "breakdown", "flag"]].to_string(index=False))


def write_latex(sm):
    """One LaTeX table: breakdown Mbar (RM) and M (SD) for all 8 specs."""
    rm = sm[sm["restriction"] == "rm"].set_index(["effect", "outcome"])
    sd = sm[sm["restriction"] == "sd"].set_index(["effect", "outcome"])
    lines = []
    lines.append(r"\begin{table}[H]")
    lines.append(r"\centering")
    lines.append(r"\scriptsize")
    lines.append(r"\caption{Rambachan--Roth (2023) honest-DiD breakdown values}")
    lines.append(r"\label{tab:honest_did_breakdown}")
    lines.append(r"\begin{tabular}{llcc}")
    lines.append(r"\hline\hline")
    lines.append(r"Effect & Outcome & $\bar{M}$ breakdown ($\Delta^{RM}$) & $M$ breakdown ($\Delta^{SD}$) \\")
    lines.append(r"\hline")
    for effect in ["direct", "spill"]:
        for outcome in OUTCOME_ORDER:
            key = (effect, outcome)
            def cell(tab):
                if key not in tab.index:
                    return "--"
                r = tab.loc[key]
                dag = r"$^{\dagger}$" if outcome == "numb_clauses" else ""
                fl = str(r.get("flag", ""))
                if r["status"] == "FAILED":
                    return r"n/a" + dag
                if fl.startswith("OLS n.s."):
                    return r"n.s." + dag   # original OLS CI already includes 0
                if r["status"] == "beyond_grid":
                    return rf"$>{r['grid_max']:.2f}${dag}"
                star = r"$^{\ast}$" if fl.startswith(("fragile", "VERY FRAGILE")) else ""
                return rf"{r['breakdown']:.3f}{star}{dag}"
            lines.append(rf"{EFFECT_LABEL[effect]} & {OUTCOME_LABEL[outcome]} & {cell(rm)} & {cell(sd)} \\")
        lines.append(r"\hline")
    lines.append(r"\end{tabular}")
    note = (r"\begin{minipage}{0.92\textwidth}\scriptsize This table reports the "
            r"breakdown value of the sensitivity parameter at which the Rambachan--Roth "
            r"robust confidence interval first includes zero, for each of the 8 main "
            r"event-study specifications (estimated standalone with establishment-clustered "
            r"VCV). $\Delta^{RM}$ bounds the post-treatment differential trend by $\bar{M}$ "
            r"times the largest pre-treatment differential; its grid ($0$--$2$) is comparable "
            r"across outcomes. $\Delta^{SD}$ bounds the curvature of the differential trend in "
            r"outcome units, so $M$ is not comparable across outcomes. All CIs use the C-LF "
            r"(conditional least-favorable) method. ``n.s.'' marks specs whose original OLS CI "
            r"already includes zero, for which the breakdown value is mechanically zero and "
            r"uninformative. $^{\ast}$ $\bar{M}<1$ (result not robust "
            r"to a post-period violation as large as pre-period violations). $^{\dagger}$ "
            r"numb\_clauses has a single pre-period (CBA-period structure), so its breakdown "
            r"values rest on one pre-treatment coefficient and should be read with caution. "
            r"\end{minipage}")
    lines.append(note)
    lines.append(r"\end{table}")
    (TABLES_DIR / "honest_did_breakdown.tex").write_text("\n".join(lines))
    print(f"wrote {TABLES_DIR/'honest_did_breakdown.tex'}")


def _bd_caption(row, restr):
    """Short caption: the value of M at which the robust CI first crosses zero."""
    x  = RESTR_X[restr]
    st = row["status"]
    if st == "FAILED":
        return "infeasible (1 pre-period)"
    if str(row.get("flag", "")).startswith("OLS n.s."):
        return "OLS CI already includes 0"
    if st == "beyond_grid":
        return f"no 0-crossing for {x} $\\leq$ {row['grid_max']:.3g}"
    return f"crosses 0 at {x} = {row['breakdown']:.3g}"


def plot_grid(df, sm, restr, target):
    """4x2 grid (rows=outcomes, cols=direct/spill): Rambachan--Roth sensitivity
    plot -- one robust confidence INTERVAL per chosen value of M (not a continuous
    band), with the original OLS CI shown as a separate interval on the left.
    `df`/`sm` are already filtered to a single target post period."""
    sub = df[(df["restriction"] == restr)]
    fig, axes = plt.subplots(len(OUTCOME_ORDER), 2,
                             figsize=(10, 2.4 * len(OUTCOME_ORDER)),
                             squeeze=False)
    for ri, outcome in enumerate(OUTCOME_ORDER):
        for ci, effect in enumerate(["direct", "spill"]):
            ax = axes[ri][ci]
            g = sub[(sub["outcome"] == outcome) & (sub["effect"] == effect)]
            og = g[g["is_original"] == 1]
            grid = g[g["is_original"] == 0].sort_values("m")
            if grid.empty:
                ax.text(0.5, 0.5, "n/a",
                        ha="center", va="center", transform=ax.transAxes,
                        fontsize=10, color="gray")
                ax.set_xticks([]); ax.set_yticks([])
            else:
                m   = grid["m"].values
                lb  = grid["lb"].values
                ub  = grid["ub"].values
                xs  = np.arange(len(m))
                cen = 0.5 * (lb + ub)
                has_og = not og.empty
                x_og   = -1.3
                # ── original OLS CI as a separate interval on the left ──────────
                if has_og:
                    o_lb = float(og["lb"].iloc[0]); o_ub = float(og["ub"].iloc[0])
                    o_c  = 0.5 * (o_lb + o_ub)
                    ax.errorbar([x_og], [o_c], yerr=[[o_c - o_lb], [o_ub - o_c]],
                                fmt="none", ecolor=C_ORIG, elinewidth=1.6,
                                capsize=3, capthick=1.6, label="Original OLS CI")
                    ax.axvline(-0.65, color="gray", lw=0.6, ls=":")
                # ── robust CI: one interval per chosen M (no center point) ──────
                ax.errorbar(xs, cen, yerr=[cen - lb, ub - cen], fmt="none",
                            ecolor=C_ROBUST, elinewidth=1.6, capsize=3,
                            capthick=1.6, label="Robust CI")
                ax.axhline(0, color="black", lw=0.8)
                # x ticks: original + (thinned) M labels
                step = 1 if len(m) <= 10 else int(np.ceil(len(m) / 8))
                tick_x   = ([x_og] if has_og else []) + list(xs[::step])
                tick_lab = (["Orig."] if has_og else []) + [f"{v:g}" for v in m[::step]]
                ax.set_xticks(tick_x)
                ax.set_xticklabels(tick_lab, fontsize=6.5)
                ax.set_xlim((x_og - 0.5) if has_og else -0.5, len(m) - 0.5)
            # breakdown caption underneath each panel
            srow = sm[(sm["restriction"] == restr) & (sm["effect"] == effect) &
                      (sm["outcome"] == outcome)]
            if not srow.empty:
                ax.text(0.5, -0.17, _bd_caption(srow.iloc[0], restr),
                        transform=ax.transAxes, ha="center", va="top",
                        fontsize=7.5, color="dimgray")
            if ri == 0:
                ax.set_title(EFFECT_LABEL[effect], fontsize=11, fontweight="bold")
            if ci == 0:
                ax.set_ylabel(OUTCOME_LABEL[outcome], fontsize=9, fontweight="bold")
            if ri == len(OUTCOME_ORDER) - 1:
                ax.set_xlabel(RESTR_X[restr], fontsize=10, labelpad=24)

    handles = [
        Line2D([0], [0], color=C_ROBUST, lw=1.8, label=f"Robust CI (per {RESTR_X[restr]})"),
        Line2D([0], [0], color=C_ORIG, lw=1.8, label="Original OLS CI"),
    ]
    fig.legend(handles=handles, loc="lower center", ncol=2, frameon=False,
               bbox_to_anchor=(0.5, -0.01))
    fig.suptitle(f"{RESTR_LABEL[restr]}   —   target: {TARGET_LABEL.get(target, target)}",
                 fontsize=12, y=0.998)
    fig.tight_layout(rect=[0, 0.03, 1, 0.975], h_pad=3.0)
    out = GRAPHS_DIR / f"honest_did_{restr}_{target}.pdf"
    fig.savefig(out, bbox_inches="tight")
    fig.savefig(out.with_suffix(".png"), dpi=150, bbox_inches="tight")
    if target == "p1":                    # also keep the default-named figure
        alt = GRAPHS_DIR / f"honest_did_{restr}.pdf"
        fig.savefig(alt, bbox_inches="tight")
        fig.savefig(alt.with_suffix(".png"), dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
