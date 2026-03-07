"""
Compare Python/Stata residuals results vs Gui's R output (ground truth).
"""
import re

BASE = "/gpfs/kellogg/proj/lgg3230/UnionSpill/Tables/residuals"

# ── Ground truth from R ──────────────────────────────────────────────────────
R = {
    ("A", "lr_remdezr_w"):     {"main": 0.0259, "main_se": 0.0049, "pre": 0.0000, "pre_pval": 0.746,  "n_obs": 112686},
    ("A", "lr_remdezr_h_w"):   {"main": 0.0284, "main_se": 0.0050, "pre":-0.0012, "pre_pval": 0.709,  "n_obs": 112686},
    ("A", "lr_remdezr_resid"): {"main": 0.0285, "main_se": 0.0052, "pre":-0.0026, "pre_pval": 0.251,  "n_obs": 112686},
    ("A", "lr_hourly_resid"):  {"main": 0.0315, "main_se": 0.0056, "pre":-0.0039, "pre_pval": 0.224,  "n_obs": 112686},

    ("B", "lr_remdezr_w"):     {"main": 0.0177, "main_se": 0.0032, "pre": 0.0042, "pre_pval": 0.192,  "n_obs": 130715},
    ("B", "lr_remdezr_h_w"):   {"main": 0.0201, "main_se": 0.0033, "pre": 0.0048, "pre_pval": 0.184,  "n_obs": 130715},
    ("B", "lr_remdezr_resid"): {"main": 0.0175, "main_se": 0.0032, "pre": 0.0024, "pre_pval": 0.108,  "n_obs": 130715},
    ("B", "lr_hourly_resid"):  {"main": 0.0202, "main_se": 0.0034, "pre": 0.0029, "pre_pval": 0.119,  "n_obs": 130715},

    ("S", "lr_remdezr_w"):     {"main": 0.0050, "main_se": 0.0023, "pre": 0.0020, "pre_pval": 0.728,  "n_obs": 32498},
    ("S", "lr_remdezr_h_w"):   {"main": 0.0066, "main_se": 0.0023, "pre": 0.0016, "pre_pval": 0.793,  "n_obs": 32498},
    ("S", "lr_remdezr_resid"): {"main": 0.0044, "main_se": 0.0021, "pre":-0.0017, "pre_pval": 0.611,  "n_obs": 32498},
    ("S", "lr_hourly_resid"):  {"main": 0.0057, "main_se": 0.0023, "pre":-0.0029, "pre_pval": 0.313,  "n_obs": 32498},
}

# ── Parser ────────────────────────────────────────────────────────────────────
def parse_csv(path):
    """Return dict keyed by (outcome, row_type) -> float value."""
    data = {}
    with open(path) as f:
        for line in f:
            line = line.strip().strip('"')
            if not line or line.startswith("spec,"):
                continue
            parts = [p.strip().strip('"') for p in line.split(";")]
            if len(parts) < 5:
                continue
            _, _, outcome, row_type, value = parts[:5]
            # strip stars, commas, leading/trailing spaces
            value = re.sub(r'[*,]', '', value).strip()
            try:
                data[(outcome, row_type)] = float(value)
            except ValueError:
                pass
    return data

files = {
    "A": {
        "stata":  parse_csv(f"{BASE}/results_direct_panelA_mincer.csv"),
        "python": parse_csv(f"{BASE}/results_direct_panelA_mincer_python.csv"),
    },
    "B": {
        "stata":  parse_csv(f"{BASE}/results_direct_panelB_mincer.csv"),
        "python": parse_csv(f"{BASE}/results_direct_panelB_mincer_python.csv"),
    },
    "S": {
        "stata":  parse_csv(f"{BASE}/results_spill_mincer.csv"),
        "python": parse_csv(f"{BASE}/results_spill_mincer_python.csv"),
    },
}

STATS     = ["main", "main_se", "pre", "pre_pval", "n_obs"]
THRESH    = {"main": 0.001, "main_se": 0.001, "pre": 0.001, "pre_pval": 0.01, "n_obs": 0}
OUTCOMES  = ["lr_remdezr_w", "lr_remdezr_h_w", "lr_remdezr_resid", "lr_hourly_resid"]
PANELS    = [("A","Panel A"), ("B","Panel B"), ("S","Spillover")]

total_checks = 0
passed_stata = 0
passed_python = 0
discrepancies = []

PANEL_LABEL = {"A": "Panel A", "B": "Panel B", "S": "Spillover"}

def fmt(v, row_type):
    if v is None:
        return "  None  "
    if row_type == "n_obs":
        return f"{int(v):>9,}"
    return f"{v:>9.4f}"

header_printed = False

for panel_key, panel_name in PANELS:
    print(f"\n{'='*100}")
    print(f"{panel_name}  (R N = {R[(panel_key,'lr_remdezr_resid')]['n_obs']:,})")
    print(f"{'='*100}")
    print(f"{'Outcome':<22} {'Stat':<10} {'R (truth)':>10} {'Stata':>10} {'Python':>10} {'Diff(Stata)':>12} {'Diff(Py)':>12} {'Flag'}")
    print("-"*100)

    for outcome in OUTCOMES:
        key = (panel_key, outcome)
        r_row = R[key]
        stata_d  = files[panel_key]["stata"]
        python_d = files[panel_key]["python"]

        for stat in STATS:
            r_val    = r_row.get(stat)
            stata_v  = stata_d.get((outcome, stat))
            python_v = python_d.get((outcome, stat))

            diff_stata  = abs(stata_v  - r_val) if stata_v  is not None and r_val is not None else None
            diff_python = abs(python_v - r_val) if python_v is not None and r_val is not None else None

            thr = THRESH[stat]
            flag_stata  = "WARN" if diff_stata  is not None and diff_stata  > thr else "ok"
            flag_python = "WARN" if diff_python is not None and diff_python > thr else "ok"
            flag = ""
            if flag_stata == "WARN" or flag_python == "WARN":
                flag = "WARNING"

            total_checks += 1
            if flag_stata  == "ok": passed_stata  += 1
            if flag_python == "ok": passed_python += 1

            if flag:
                discrepancies.append(f"{panel_name} | {outcome} | {stat}: R={r_val}, Stata={stata_v}, Py={python_v}")

            ds = f"{diff_stata:.4f}"  if diff_stata  is not None else "  None"
            dp = f"{diff_python:.4f}" if diff_python is not None else "  None"
            if stat == "n_obs":
                ds = f"{diff_stata:.0f}"  if diff_stata  is not None else "None"
                dp = f"{diff_python:.0f}" if diff_python is not None else "None"

            print(f"{outcome:<22} {stat:<10} {fmt(r_val, stat):>10} {fmt(stata_v, stat):>10} {fmt(python_v, stat):>10} {ds:>12} {dp:>12} {flag}")

        print()

# ── Summary ───────────────────────────────────────────────────────────────────
print(f"\n{'='*100}")
print("SUMMARY")
print(f"{'='*100}")
print(f"Stata  vs R: {passed_stata}  / {total_checks} statistics match within threshold")
print(f"Python vs R: {passed_python} / {total_checks} statistics match within threshold")

if discrepancies:
    print("\nDiscrepancies:")
    for d in discrepancies:
        print(f"  {d}")
else:
    print("\nNo discrepancies found beyond thresholds.")

# ── Python == Stata check ─────────────────────────────────────────────────────
print(f"\n{'='*100}")
print("Python vs Stata (are they identical?)")
print(f"{'='*100}")
diffs = []
for panel_key, panel_name in PANELS:
    stata_d  = files[panel_key]["stata"]
    python_d = files[panel_key]["python"]
    for outcome in OUTCOMES:
        for stat in STATS:
            sv = stata_d.get((outcome, stat))
            pv = python_d.get((outcome, stat))
            if sv is not None and pv is not None:
                d = abs(sv - pv)
                if d > 0:
                    diffs.append(f"{panel_name} | {outcome} | {stat}: Stata={sv}, Python={pv}, diff={d:.6f}")

if diffs:
    print(f"Found {len(diffs)} differences between Stata and Python:")
    for d in diffs:
        print(f"  {d}")
else:
    print("Python and Stata results are IDENTICAL for all parsed values.")
