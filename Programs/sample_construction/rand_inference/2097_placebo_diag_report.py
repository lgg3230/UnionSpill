#!/usr/bin/env python
"""
Placebo-diagnostics report — table + figures from 2096_placebo_diag.py output.

Writes:
  Tables/rand_inference/placebo_diag_pvalues.csv / .tex
  Graphs/rand_inference/placebo_imbalance_size_dist.pdf   (subfigure a)
  Graphs/rand_inference/placebo_imbalance_size_smd.pdf    (subfigure b)
  Graphs/rand_inference/placebo_imbalance_flow_dist.pdf   (subfigure c)
  Graphs/rand_inference/placebo_imbalance_flow_smd.pdf    (subfigure d)
  Graphs/rand_inference/placebo_industry_shares.pdf
The four imbalance PDFs are also copied to the paper's Figures/Main for the
four-subfigure environment in Main_Results.tex.
"""
import numpy as np, pandas as pd, json, shutil
from pathlib import Path
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.font_manager as fm
from matplotlib.lines import Line2D
from scipy.stats import gaussian_kde

ROOT  = Path("/gpfs/kellogg/proj/lgg3230/UnionSpill")
OUT   = ROOT / "Data/rand_inference"
TAB   = ROOT / "Tables/rand_inference"; TAB.mkdir(exist_ok=True)
GR    = ROOT / "Graphs/rand_inference"; GR.mkdir(exist_ok=True)
PAPER = ROOT / "UnionSpill-paper/Figures/Main"

for p in ["/kellogg/proj/lgg3230/UnionSpill/Programs/fonts/LibertinusSerif-Regular.otf",
          "/kellogg/proj/lgg3230/UnionSpill/fonts/LibertinusSerif-Regular.otf"]:
    if Path(p).exists():
        fm.fontManager.addfont(p); plt.rcParams["font.family"] = "Libertinus Serif"; break
plt.rcParams.update({"font.size": 12})
BLUE, RED, GRAY, BLACK = "#2166AC", "#B2182B", "#666666", "#111111"

SCHEMES = ["none", "intermediate", "fine_vingtile", "control_match"]
SCH_LAB1 = {
    "none":          "No stratification",
    "intermediate":  "Intermediate (ind.$\\times$size$_4\\times$flow$_4$)",
    "fine_vingtile": "Fine (ind.$\\times$size$_{20}\\times$flow$_{20}$)",
    "control_match": "Control-spec match (+micro.$\\times$month)",
}
SCH_COL  = {"none": "#B2182B", "intermediate": "#EF8A62",
            "fine_vingtile": "#67A9CF", "control_match": "#2166AC"}
BROAD_LAB = {1: "Farming/fishing", 2: "Extractive", 3: "Manufacturing", 4: "Utilities",
             5: "Construction", 6: "Trade/commerce", 7: "Transportation", 8: "Hospitality",
             9: "Communication", 10: "Banking/finance", 11: "Real estate", 12: "Professional",
             13: "Administrative", 14: "Public admin.", 15: "Education", 16: "Health",
             17: "Culture/sports", 18: "Other"}

summ = json.load(open(OUT / "placebo_diag_summary.json"))
npz  = {s: np.load(OUT / f"placebo_diag_{s}.npz") for s in SCHEMES}
groups = list(summ["_meta"]["groups"])

keys = pd.read_csv(OUT / "firm_keys_2009_ext.csv", dtype={"identificad": str})
keys = keys[keys.in_balanced_panel == 1].copy()
_istr = keys.industry1.astype("Int64").astype(str)
keys["ind2"]  = pd.to_numeric(_istr.str.slice(1, 3), errors="coerce")
def broad_industry(b):
    if pd.isna(b): return -1
    b = int(b)
    rng = [(1,1,3),(2,5,9),(3,10,33),(4,35,39),(5,41,43),(6,45,47),(7,49,53),(8,55,56),
           (9,58,63),(10,64,66),(11,68,68),(13,80,82),(14,84,84),(15,85,85),(16,86,88),
           (17,90,91),(18,92,99)]
    for g,lo,hi in rng:
        if lo<=b<=hi: return g
    if (69<=b<=75) or (77<=b<=79): return 12
    return -1
keys["broad"] = keys.ind2.map(broad_industry)
tr = keys.treat_ultra == 1

# ══════════════════════════════════════════════════════════════════════════════
# 1. TABLE
# ══════════════════════════════════════════════════════════════════════════════
rows = []
for s in SCHEMES:
    d = summ[s]
    rows.append(dict(scheme=SCH_LAB1[s], n_est_firms=d["n_est_firms"], n_swappable=d["n_swappable"],
                     n_mixed_strata=d["n_mixed_strata"],
                     p_wages=d["outcomes"]["lr_remdezr_w"]["p_two"],
                     p_hourly=d["outcomes"]["lr_remdezr_h_w"]["p_two"]))
tbl = pd.DataFrame(rows)
tbl.to_csv(TAB / "placebo_diag_pvalues.csv", index=False)

b_w = summ["none"]["outcomes"]["lr_remdezr_w"]["delta_obs"]
b_h = summ["none"]["outcomes"]["lr_remdezr_h_w"]["delta_obs"]
R   = summ["_meta"]["R"]; n_treated = summ["none"]["n_treated_permuted"]
def star(p): return "$^{***}$" if p<.01 else "$^{**}$" if p<.05 else "$^{*}$" if p<.10 else ""
lines = [r"\begin{table}[H]", r"\centering", r"\scriptsize",
    r"\caption{Randomization-inference p-values for the spillover estimate under four treated-set stratifications}",
    r"\label{tab:placebo_diag}", r"\begin{tabular}{lccccc}", r"\toprule",
    r"Stratification & \shortstack{Firms in\\estimation} & \shortstack{Treated firms\\swappable} & "
    r"\shortstack{Mixed\\strata} & \shortstack{$p$\\(log wages)} & \shortstack{$p$\\(log hourly)} \\", r"\midrule"]
for _, r in tbl.iterrows():
    lines.append(f"{r.scheme} & {int(r.n_est_firms):,} & {int(r.n_swappable):,} & {int(r.n_mixed_strata):,} & "
                 f"{r.p_wages:.3f}{star(r.p_wages)} & {r.p_hourly:.3f}{star(r.p_hourly)} \\\\")
lines += [r"\bottomrule", r"\end{tabular}",
    r"\begin{minipage}{0.92\textwidth}\vspace{4pt}\scriptsize",
    f"This table reports two-sided randomization-inference p-values for the spillover coefficient under four "
    f"schemes for reshuffling the treated label across firms. In every scheme the treated label is permuted "
    f"within strata of predetermined destination-firm characteristics, holding the number of treated firms "
    f"fixed at {n_treated:,}, and placebo connectivity is rebuilt as $C_i^{{(r)}}=\\sum_j W_{{ij}} D_j^{{(r)}}$. "
    f"Industry cells use the true two-digit CNAE division. The observed estimate is $\\hat\\beta={b_w:.4f}$ "
    f"(log wages) and $\\hat\\beta={b_h:.4f}$ (log hourly wages), identical across schemes by construction. "
    f"`Treated firms swappable' counts treated firms that share a stratum with at least one untreated firm "
    f"(only these can change status); the remainder are frozen. Based on {R:,} placebo draws. "
    f"$^{{*}}p<0.10$, $^{{**}}p<0.05$, $^{{***}}p<0.01$.",
    r"\end{minipage}", r"\end{table}"]
(TAB / "placebo_diag_pvalues.tex").write_text("\n".join(lines))
print("wrote table:", TAB / "placebo_diag_pvalues.tex")
print(tbl.to_string(index=False))

# ══════════════════════════════════════════════════════════════════════════════
# 2. IMBALANCE — four standalone panels
# ══════════════════════════════════════════════════════════════════════════════
def panel_dist(rawv, obsk, lab, fname):
    fig, ax = plt.subplots(figsize=(5.4, 4.0))
    xt = keys.loc[tr, rawv].dropna().values
    xu = keys.loc[~tr, rawv].dropna().values
    lo, hi = np.percentile(np.concatenate([xt, xu]), [0.5, 99.5])
    grid = np.linspace(lo, hi, 200)
    kt, ku = gaussian_kde(xt)(grid), gaussian_kde(xu)(grid)
    ax.plot(grid, kt, color=RED, lw=2, label="Treated"); ax.fill_between(grid, kt, color=RED, alpha=0.12)
    ax.plot(grid, ku, color=BLUE, lw=2, label="Untreated"); ax.fill_between(grid, ku, color=BLUE, alpha=0.12)
    obs = float(npz["none"][obsk])
    ax.set_title(f"Standardized difference (treated $-$ untreated) $= {obs:+.3f}$", fontsize=11)
    ax.set_xlabel(lab); ax.set_ylabel("Density"); ax.legend(frameon=False, fontsize=10)
    for sp in ["top", "right"]: ax.spines[sp].set_visible(False)
    fig.tight_layout(); fig.savefig(GR / fname); plt.close(fig)

def panel_smd(smdk, obsk, lab, fname, legend_loc):
    fig, ax = plt.subplots(figsize=(5.4, 4.0))
    obs = float(npz["none"][obsk])
    allv = np.concatenate([npz[s][smdk] for s in SCHEMES] + [[obs]])
    g2 = np.linspace(allv.min(), allv.max(), 200)
    for s in SCHEMES:
        v = npz[s][smdk]
        if v.std() < 1e-9: ax.axvline(v.mean(), color=SCH_COL[s], lw=1.5, alpha=0.7)
        else: ax.plot(g2, gaussian_kde(v)(g2), color=SCH_COL[s], lw=1.9)
    # observed value — made prominent
    ax.axvline(obs, color=BLACK, lw=3, ls=(0, (5, 2)), zorder=6)
    ymax = ax.get_ylim()[1]
    ax.annotate(f"Observed = {obs:+.3f}", xy=(obs, ymax*0.92),
                xytext=(0.5, 0.98) if legend_loc == "upper left" else (0.02, 0.98),
                textcoords="axes fraction", color=BLACK, fontsize=10, fontweight="bold",
                va="top", ha="left",
                arrowprops=dict(arrowstyle="->", color=BLACK, lw=1.3))
    handles = [Line2D([0], [0], color=SCH_COL[s], lw=2, label=SCH_LAB1[s]) for s in SCHEMES]
    handles.append(Line2D([0], [0], color=BLACK, lw=3, ls=(0, (5, 2)), label="Observed (real treated set)"))
    ax.legend(handles=handles, frameon=False, fontsize=8.5, loc=legend_loc)
    ax.set_title("Placebo imbalance across draws vs. observed", fontsize=11)
    ax.set_xlabel(f"{lab}: standardized mean difference (treated $-$ untreated)")
    ax.set_ylabel("Density across draws")
    for sp in ["top", "right"]: ax.spines[sp].set_visible(False)
    fig.tight_layout(); fig.savefig(GR / fname); plt.close(fig)

panel_dist("l_firm_emp", "obs_smd_size", "Log employment (size)", "placebo_imbalance_size_dist.pdf")
panel_smd("smd_size", "obs_smd_size", "Log employment (size)", "placebo_imbalance_size_smd.pdf", "upper right")
panel_dist("totalflows_pw_pre_07_11", "obs_smd_flow", "Flows per worker", "placebo_imbalance_flow_dist.pdf")
panel_smd("smd_flow", "obs_smd_flow", "Flows per worker", "placebo_imbalance_flow_smd.pdf", "upper left")
IMG = ["placebo_imbalance_size_dist.pdf", "placebo_imbalance_size_smd.pdf",
       "placebo_imbalance_flow_dist.pdf", "placebo_imbalance_flow_smd.pdf"]
print("wrote 4 imbalance panels:", ", ".join(IMG))

# ══════════════════════════════════════════════════════════════════════════════
# 3. INDUSTRY SHARES — bars are the draw-averaged placebo shares, per scheme
# ══════════════════════════════════════════════════════════════════════════════
xpos  = np.arange(len(groups))
xlabs = [BROAD_LAB.get(g, str(g)) for g in groups]
obs_share = npz["none"]["obs_shares"]                       # observed treated composition

fig, axes = plt.subplots(2, 2, figsize=(12, 8.5), sharex=True, sharey=True)
for ax, s in zip(axes.flat, SCHEMES):
    shr = npz[s]["shares"]                                  # (nGroups, R)
    mean = shr.mean(1)
    lo = np.percentile(shr, 2.5, axis=1); hi = np.percentile(shr, 97.5, axis=1)
    yerr = [np.clip(mean - lo, 0, None), np.clip(hi - mean, 0, None)]
    ax.bar(xpos, mean, width=0.68, color=SCH_COL[s], alpha=0.75,
           yerr=yerr, capsize=2, ecolor=GRAY, label="Placebo mean (avg. across draws)")
    ax.plot(xpos, obs_share, "D", color=BLACK, ms=5, label="Observed treated", zorder=5)
    ax.set_title(SCH_LAB1[s], fontsize=11)
    ax.set_ylabel("Share of treated set")
    ax.legend(frameon=False, fontsize=8.5, loc="upper right")
    for sp in ["top", "right"]: ax.spines[sp].set_visible(False)
for ax in axes[1, :]:
    ax.set_xticks(xpos); ax.set_xticklabels(xlabs, rotation=55, ha="right", fontsize=8.5)
fig.suptitle("Industry composition of the treated set: draw-averaged placebo shares vs. observed", fontsize=13)
fig.tight_layout(rect=[0, 0, 1, 0.97])
fig.savefig(GR / "placebo_industry_shares.pdf"); plt.close(fig)
print("wrote figure:", GR / "placebo_industry_shares.pdf")

# ══════════════════════════════════════════════════════════════════════════════
# 4. fig:randinf histograms — new methodology, intermediate scheme
# ══════════════════════════════════════════════════════════════════════════════
HSCHEME = "intermediate"
for outcome in ["lr_remdezr_w", "lr_remdezr_h_w"]:
    dr = npz[HSCHEME][f"delta_{outcome}"]
    r  = summ[HSCHEME]["outcomes"][outcome]
    d0, p = r["delta_obs"], r["p_two"]
    fig, ax = plt.subplots(figsize=(5.2, 3.6))
    ax.hist(dr, bins=45, color=BLUE, alpha=0.55, edgecolor="white", linewidth=0.4)
    ax.axvline(0, color="gray", lw=0.8, ls=":")
    ax.axvline(d0, color=RED, lw=2)
    ymax = ax.get_ylim()[1]
    ax.text(d0, ymax * 0.97, f"  observed $\\hat\\beta={d0:.4f}$", color=RED,
            fontsize=9, ha="left", va="top")
    ax.text(0.03, 0.97, f"$p={p:.3f}$ (two-sided)\n{R:,} placebo draws",
            transform=ax.transAxes, va="top", ha="left", fontsize=9)
    ax.set_xlabel("Placebo spillover coefficient $\\hat\\beta^{(r)}$")
    ax.set_ylabel("Frequency")
    for sp in ["top", "right"]: ax.spines[sp].set_visible(False)
    fig.tight_layout()
    f = GR / f"perm_hist_{outcome}.pdf"
    fig.savefig(f); plt.close(fig)
    if PAPER.exists(): shutil.copy(f, PAPER / f"perm_hist_{outcome}.pdf")
    print("wrote", f)

# ── copy the placebo-imbalance (SMD) panels to the paper ─────────────────────
# only the "placebo imbalance vs. observed" panels go in the paper figure; the
# real-sample distribution panels are kept in Graphs/ for reference only.
PAPER_IMG = ["placebo_imbalance_size_smd.pdf", "placebo_imbalance_flow_smd.pdf"]
if PAPER.exists():
    for f in PAPER_IMG:
        shutil.copy(GR / f, PAPER / f)
    print("copied SMD panels to", PAPER, ":", ", ".join(PAPER_IMG))
