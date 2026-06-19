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

# ── fonts (Libertinus Serif if available; silent fallback) ──────────────────
try:
    import matplotlib.font_manager as fm
    for fp in ["/kellogg/proj/lgg3230/UnionSpill/Programs/fonts/LibertinusSerif-Regular.otf",
               str(HERE.parent / "fonts" / "LibertinusSerif-Regular.otf")]:
        if Path(fp).exists():
            fm.fontManager.addfont(fp)
            plt.rcParams["font.family"] = "Libertinus Serif"
            break
except Exception:
    pass

C_ORIG   = "#2166AC"   # original OLS CI (blue)
C_ROBUST = "#B2182B"   # robust honest-DiD CI (red)

OUTCOME_LABEL = {
    "lr_remdezr_w":   "Log monthly earnings",
    "lr_remdezr_h_w": "Log hourly earnings",
    "l_firm_emp":     "Log employment",
    "numb_clauses":   "# CBA clauses",
}
OUTCOME_ORDER = ["lr_remdezr_w", "lr_remdezr_h_w", "l_firm_emp", "numb_clauses"]
EFFECT_LABEL  = {"direct": "Direct", "spill": "Spillover"}
RESTR_LABEL   = {"rm": r"$\Delta^{RM}$ (relative magnitudes)",
                 "sd": r"$\Delta^{SD}$ (smoothness)"}
RESTR_X       = {"rm": r"$\bar{M}$", "sd": r"$M$"}


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
    failed = df[df["is_original"].astype(str) == "FAILED"]
    df = df[df["is_original"].astype(str) != "FAILED"].copy()
    for c in ["m", "lb", "ub", "is_original"]:
        df[c] = pd.to_numeric(df[c], errors="coerce")

    summary = []
    for (effect, outcome, restr), g in df.groupby(["effect", "outcome", "restriction"]):
        og = g[g["is_original"] == 1]
        grid = g[g["is_original"] == 0].sort_values("m")
        if grid.empty:
            continue
        bd, status = breakdown(grid["m"].values, grid["lb"].values, grid["ub"].values)
        og_lb = float(og["lb"].iloc[0]) if not og.empty else np.nan
        og_ub = float(og["ub"].iloc[0]) if not og.empty else np.nan
        summary.append(dict(effect=effect, outcome=outcome, restriction=restr,
                            breakdown=bd, status=status,
                            grid_max=float(grid["m"].max()),
                            og_lb=og_lb, og_ub=og_ub))
    # mark failed specs in the summary too
    for _, r in failed.iterrows():
        summary.append(dict(effect=r["effect"], outcome=r["outcome"],
                            restriction=r["restriction"], breakdown=np.nan,
                            status="FAILED", grid_max=np.nan,
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

    sm = sm.sort_values(["restriction", "effect", "outcome"])
    sm.to_csv(TABLES_DIR / "honest_did_breakdown.csv", index=False)
    print(sm.to_string(index=False))

    write_latex(sm)
    for restr in ["rm", "sd"]:
        plot_grid(df, sm, restr)

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


def plot_grid(df, sm, restr):
    """4x2 grid (rows=outcomes, cols=direct/spill) of robust CI band vs M."""
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
                ax.text(0.5, 0.5, "infeasible\n(1 pre-period)",
                        ha="center", va="center", transform=ax.transAxes,
                        fontsize=9, color="gray")
                ax.set_xticks([]); ax.set_yticks([])
            else:
                m = grid["m"].values
                ax.fill_between(m, grid["lb"], grid["ub"], color=C_ROBUST,
                                alpha=0.18, label="Robust CI")
                ax.plot(m, grid["lb"], color=C_ROBUST, lw=1.5)
                ax.plot(m, grid["ub"], color=C_ROBUST, lw=1.5)
                if not og.empty:
                    ax.axhspan(float(og["lb"].iloc[0]), float(og["ub"].iloc[0]),
                               color=C_ORIG, alpha=0.15, label="Original OLS CI")
                ax.axhline(0, color="black", lw=0.8)
                # breakdown marker
                row = sm[(sm["restriction"] == restr) & (sm["effect"] == effect) &
                         (sm["outcome"] == outcome)]
                if not row.empty and row["status"].iloc[0] in ("in_grid", "at_min"):
                    bd = row["breakdown"].iloc[0]
                    ax.axvline(bd, color="gray", ls="--", lw=1.0)
                    ax.text(bd, ax.get_ylim()[1], f" {RESTR_X[restr]}*={bd:.2f}",
                            ha="left", va="top", fontsize=7, color="gray")
                ax.set_xlim(m.min(), m.max())
            if ri == 0:
                ax.set_title(EFFECT_LABEL[effect], fontsize=11, fontweight="bold")
            if ci == 0:
                ax.set_ylabel(OUTCOME_LABEL[outcome], fontsize=9, fontweight="bold")
            if ri == len(OUTCOME_ORDER) - 1:
                ax.set_xlabel(RESTR_X[restr], fontsize=10)

    handles = [Patch(facecolor=C_ROBUST, alpha=0.18, label="Robust CI"),
               Patch(facecolor=C_ORIG, alpha=0.15, label="Original OLS CI"),
               Line2D([0], [0], color="gray", ls="--", lw=1.0, label="Breakdown")]
    fig.legend(handles=handles, loc="lower center", ncol=3, frameon=False,
               bbox_to_anchor=(0.5, -0.01))
    fig.tight_layout(rect=[0, 0.03, 1, 1])
    out = GRAPHS_DIR / f"honest_did_{restr}.pdf"
    fig.savefig(out, bbox_inches="tight")
    fig.savefig(out.with_suffix(".png"), dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
