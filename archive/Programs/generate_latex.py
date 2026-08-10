#!/usr/bin/env python3
"""
Generate LaTeX document assembling Union Spillovers results
"""

import csv
import pandas as pd
import os
from pathlib import Path

# Specification order
SPECS_PERFECT = ["TFPE_BIN_5", "TFPE_BIN_10", "TFPE_BIN_4", "TFPE_BIN_20"]
SPECS_ROBUST = ["TFPE_LIN_YR", "TF_LIN_YR", "EMP_BIN_4", "EMP_BIN_5", "EMP_LIN_YR", "TF_BIN_4", "TF_BIN_5"]
SPECS = SPECS_PERFECT + SPECS_ROBUST

# Outcome definitions
MAIN_OUTCOMES = ["lr_remdezr_w", "lr_remdezr_h_w", "l_firm_emp", "numb_clauses"]

# Union control variants (for spillover robustness)
UNION_CONTROL_OUTCOMES = {
    "lr_remdezr_w": ["lr_remdezr_w", "lr_remdezr_w_union", "lr_remdezr_w_unionexp"],
    "lr_remdezr_h_w": ["lr_remdezr_h_w", "lr_remdezr_h_w_union", "lr_remdezr_h_w_unionexp"],
    "l_firm_emp": ["l_firm_emp", "l_firm_emp_union", "l_firm_emp_unionexp"]
}

PCT_OUTCOMES_DEC = [
    "lr_remdezr_w_p10", "lr_remdezr_w_p20", "lr_remdezr_w_p25",
    "lr_remdezr_w_p50", "lr_remdezr_w_p75", "lr_remdezr_w_p80", "lr_remdezr_w_p90"
]

PCT_OUTCOMES_HOUR = [
    "lr_remdezr_h_w_p10", "lr_remdezr_h_w_p20", "lr_remdezr_h_w_p25",
    "lr_remdezr_h_w_p50", "lr_remdezr_h_w_p75", "lr_remdezr_h_w_p80", "lr_remdezr_h_w_p90"
]

RATIO_OUTCOMES_DEC = [
    "lr_remdezr_w_p90p10", "lr_remdezr_w_p80p20", "lr_remdezr_w_p75p25",
    "lr_remdezr_w_p90p50", "lr_remdezr_w_p80p50", "lr_remdezr_w_p75p50"
]

RATIO_OUTCOMES_HOUR = [
    "lr_remdezr_h_w_p90p10", "lr_remdezr_h_w_p80p20", "lr_remdezr_h_w_p75p25",
    "lr_remdezr_h_w_p90p50", "lr_remdezr_h_w_p80p50", "lr_remdezr_h_w_p75p50"
]

# Readable labels
OUTCOME_LABELS = {
    "lr_remdezr_w": "Dec Wages",
    "lr_remdezr_h_w": "Hourly Wages",
    "l_firm_emp": "Employment",
    "numb_clauses": "CBA Clauses",
    "lr_remdezr_w_p10": "P10",
    "lr_remdezr_w_p20": "P20",
    "lr_remdezr_w_p25": "P25",
    "lr_remdezr_w_p50": "P50",
    "lr_remdezr_w_p75": "P75",
    "lr_remdezr_w_p80": "P80",
    "lr_remdezr_w_p90": "P90",
    "lr_remdezr_h_w_p10": "P10",
    "lr_remdezr_h_w_p20": "P20",
    "lr_remdezr_h_w_p25": "P25",
    "lr_remdezr_h_w_p50": "P50",
    "lr_remdezr_h_w_p75": "P75",
    "lr_remdezr_h_w_p80": "P80",
    "lr_remdezr_h_w_p90": "P90",
    "lr_remdezr_w_p90p10": "P90/P10",
    "lr_remdezr_w_p80p20": "P80/P20",
    "lr_remdezr_w_p75p25": "P75/P25",
    "lr_remdezr_w_p90p50": "P90/P50",
    "lr_remdezr_w_p80p50": "P80/P50",
    "lr_remdezr_w_p75p50": "P75/P50",
    "lr_remdezr_h_w_p90p10": "P90/P10",
    "lr_remdezr_h_w_p80p20": "P80/P20",
    "lr_remdezr_h_w_p75p25": "P75/P25",
    "lr_remdezr_h_w_p90p50": "P90/P50",
    "lr_remdezr_h_w_p80p50": "P80/P50",
    "lr_remdezr_h_w_p75p50": "P75/P50",
}

def load_csv_robust(filepath):
    """Load CSV with robust handling of commas in numbers"""
    rows = []
    with open(filepath, 'r') as f:
        reader = csv.reader(f)
        header = next(reader)
        for row in reader:
            if len(row) > 5:
                row = row[:4] + [','.join(row[4:])]
            rows.append(row)
    
    df = pd.DataFrame(rows, columns=header)
    df['value'] = df['value'].str.strip().str.strip('"')
    return df

def get_table_data(df, outcomes):
    """Extract table data for a list of outcomes"""
    table_data = {}
    for outcome in outcomes:
        outcome_data = df[df['outcome'] == outcome]
        if len(outcome_data) == 0:
            continue
        
        data_dict = {}
        for _, row in outcome_data.iterrows():
            data_dict[row['row_type']] = row['value']
        
        table_data[outcome] = data_dict
    
    return table_data

def format_table_row_oriented(table_data, outcomes, caption, label):
    """Generate LaTeX table in row-oriented format"""
    
    # Filter to available outcomes
    available_outcomes = [o for o in outcomes if o in table_data]
    if len(available_outcomes) == 0:
        return f"\\begin{{center}}\\textit{{No data available for {caption}}}\\end{{center}}\n\n"
    
    n_cols = len(available_outcomes)
    col_spec = "l" + "c" * n_cols
    
    latex = "\\begin{table}[H]\n"
    latex += "\\centering\n"
    latex += "\\begin{threeparttable}\n"
    latex += f"\\caption{{{caption}}}\n"
    latex += f"\\label{{{label}}}\n"
    latex += f"\\begin{{tabular}}{{{col_spec}}}\n"
    latex += "\\toprule\n"
    
    # Header row
    latex += " & " + " & ".join([OUTCOME_LABELS.get(o, o) for o in available_outcomes]) + " \\\\\n"
    latex += "\\midrule\n"
    
    # Post × Treatment row
    latex += "Post $\\times$ Treatment"
    for outcome in available_outcomes:
        val = table_data[outcome].get('main', '--')
        latex += f" & {val}"
    latex += " \\\\\n"
    
    # Std error row
    latex += "(Std. Error)"
    for outcome in available_outcomes:
        val = table_data[outcome].get('main_se', '--')
        latex += f" & ({val})"
    latex += " \\\\\n"
    
    latex += "\\addlinespace\n"
    
    # Pre × Treatment row
    latex += "Pre $\\times$ Treatment"
    for outcome in available_outcomes:
        val = table_data[outcome].get('pre', '--')
        latex += f" & {val}"
    latex += " \\\\\n"
    
    # Std error row
    latex += "(Std. Error)"
    for outcome in available_outcomes:
        val = table_data[outcome].get('pre_se', '--')
        latex += f" & ({val})"
    latex += " \\\\\n"
    
    latex += "\\addlinespace\n"
    
    # Observations row
    latex += "Num Obs"
    for outcome in available_outcomes:
        val = table_data[outcome].get('n_obs', '--')
        latex += f" & {val}"
    latex += " \\\\\n"
    
    # Establishments row
    latex += "Num Establishments"
    for outcome in available_outcomes:
        val = table_data[outcome].get('n_estab', '--')
        latex += f" & {val}"
    latex += " \\\\\n"
    
    latex += "\\bottomrule\n"
    latex += "\\end{tabular}\n"
    latex += "\\begin{tablenotes}[flushleft]\n"
    latex += "\\small\n"
    latex += "\\item Notes: *** p$<$0.01, ** p$<$0.05, * p$<$0.10. "
    latex += "Standard errors clustered at the firm level.\n"
    latex += "\\end{tablenotes}\n"
    latex += "\\end{threeparttable}\n"
    latex += "\\end{table}\n\n"
    
    return latex

def format_figure_grid(spec, section):
    """Generate 2x2 figure grid for main outcomes"""
    
    section_name = "Direct Effects" if section == "direct" else "Spillover Effects"
    
    latex = "\\begin{figure}[H]\n"
    latex += "\\centering\n"
    
    for i, outcome in enumerate(MAIN_OUTCOMES):
        filename = f"es_{section}_{outcome}_{spec}.pdf"
        
        latex += "\\begin{subfigure}[b]{0.48\\textwidth}\n"
        latex += "\\centering\n"
        latex += f"\\IfFileExists{{./figures/{filename}}}{{\n"
        latex += f"  \\includegraphics[width=\\textwidth]{{./figures/{filename}}}\n"
        latex += f"}}{{\\textit{{Figure not available: {filename}}}}}\n"
        latex += f"\\caption{{{OUTCOME_LABELS[outcome]}}}\n"
        latex += "\\end{subfigure}\n"
        
        if i % 2 == 0:
            latex += "\\hfill\n"
        else:
            latex += "\n\n"
    
    latex += f"\\caption{{Event Study Plots: {section_name} ({spec})}}\n"
    latex += f"\\label{{fig:{section}_{spec}}}\n"
    latex += "\\end{figure}\n\n"
    
    return latex

def format_union_controls_table(table_data, spec):
    """Generate union controls robustness table for spillover effects"""
    
    # Outcomes to include (excluding numb_clauses)
    outcomes_base = ["lr_remdezr_w", "lr_remdezr_h_w", "l_firm_emp"]
    
    # Check if we have union control data
    has_union_data = False
    for outcome in outcomes_base:
        if f"{outcome}_union" in table_data or f"{outcome}_unionexp" in table_data:
            has_union_data = True
            break
    
    if not has_union_data:
        return f"\\begin{{center}}\\textit{{Union controls robustness not estimated for {spec}}}\\end{{center}}\n\n"
    
    latex = "\\begin{table}[H]\n"
    latex += "\\centering\n"
    latex += "\\begin{threeparttable}\n"
    latex += f"\\caption{{Union Controls Robustness: Spillover Effects ({spec})}}\n"
    latex += f"\\label{{tab:spill_union_{spec}}}\n"
    latex += "\\begin{tabular}{lccc}\n"
    latex += "\\toprule\n"
    latex += " & Dec Wages & Hourly Wages & Employment \\\\\n"
    latex += "\\midrule\n"
    latex += "\\textbf{Panel A: Baseline (No Union Controls)} \\\\\n"
    
    # Baseline row
    latex += "Post $\\times$ Treatment"
    for outcome in outcomes_base:
        if outcome in table_data:
            val = table_data[outcome].get('main', '--')
            latex += f" & {val}"
        else:
            latex += " & --"
    latex += " \\\\\n"
    
    # Baseline SE row
    latex += "(Std. Error)"
    for outcome in outcomes_base:
        if outcome in table_data:
            val = table_data[outcome].get('main_se', '--')
            latex += f" & ({val})"
        else:
            latex += " & --"
    latex += " \\\\\n"
    
    latex += "\\addlinespace\n"
    latex += "\\textbf{Panel B: With Union Fixed Effects} \\\\\n"
    
    # Union FE row
    latex += "Post $\\times$ Treatment"
    for outcome in outcomes_base:
        outcome_union = f"{outcome}_union"
        if outcome_union in table_data:
            val = table_data[outcome_union].get('main', '--')
            latex += f" & {val}"
        else:
            latex += " & --"
    latex += " \\\\\n"
    
    # Union FE SE row
    latex += "(Std. Error)"
    for outcome in outcomes_base:
        outcome_union = f"{outcome}_union"
        if outcome_union in table_data:
            val = table_data[outcome_union].get('main_se', '--')
            latex += f" & ({val})"
        else:
            latex += " & --"
    latex += " \\\\\n"
    
    latex += "\\addlinespace\n"
    latex += "\\textbf{Panel C: With Union Exposure Controls} \\\\\n"
    
    # Union Exp row
    latex += "Post $\\times$ Treatment"
    for outcome in outcomes_base:
        outcome_exp = f"{outcome}_unionexp"
        if outcome_exp in table_data:
            val = table_data[outcome_exp].get('main', '--')
            latex += f" & {val}"
        else:
            latex += " & --"
    latex += " \\\\\n"
    
    # Union Exp SE row
    latex += "(Std. Error)"
    for outcome in outcomes_base:
        outcome_exp = f"{outcome}_unionexp"
        if outcome_exp in table_data:
            val = table_data[outcome_exp].get('main_se', '--')
            latex += f" & ({val})"
        else:
            latex += " & --"
    latex += " \\\\\n"
    
    latex += "\\bottomrule\n"
    latex += "\\end{tabular}\n"
    latex += "\\begin{tablenotes}[flushleft]\n"
    latex += "\\small\n"
    latex += "\\item Notes: *** p$<$0.01, ** p$<$0.05, * p$<$0.10. "
    latex += "Panel A shows baseline spillover estimates. "
    latex += "Panel B includes union fixed effects (i.mode\\_union$\\times$year). "
    latex += "Panel C controls for union exposure to treatment (treat\\_union\\_exp\\_all$\\times$year). "
    latex += "Standard errors clustered at the firm level.\n"
    latex += "\\end{tablenotes}\n"
    latex += "\\end{threeparttable}\n"
    latex += "\\end{table}\n\n"
    
    return latex

def generate_spec_section(spec, data_direct, data_spill):
    """Generate LaTeX for one specification section"""
    
    # Readable spec name
    spec_name = spec.replace("_", " ")
    
    latex = f"\\section{{{spec_name}}}\n\n"
    
    # ===========================
    # Direct Effects Subsection
    # ===========================
    latex += "\\subsection{Direct Effects}\n\n"
    
    # Figure grid
    latex += format_figure_grid(spec, "direct")
    latex += "\\clearpage\n\n"
    
    if data_direct is not None:
        # Main outcomes table
        table_data = get_table_data(data_direct, MAIN_OUTCOMES)
        latex += format_table_row_oriented(
            table_data, 
            MAIN_OUTCOMES,
            f"Main Outcomes: Direct Effects ({spec})",
            f"tab:direct_main_{spec}"
        )
        
        # Percentiles table
        table_data_dec = get_table_data(data_direct, PCT_OUTCOMES_DEC)
        table_data_hour = get_table_data(data_direct, PCT_OUTCOMES_HOUR)
        
        latex += format_table_row_oriented(
            table_data_dec,
            PCT_OUTCOMES_DEC,
            f"Percentiles: December Wages - Direct Effects ({spec})",
            f"tab:direct_pct_dec_{spec}"
        )
        
        latex += format_table_row_oriented(
            table_data_hour,
            PCT_OUTCOMES_HOUR,
            f"Percentiles: Hourly Wages - Direct Effects ({spec})",
            f"tab:direct_pct_hour_{spec}"
        )
        
        # Ratios table
        table_data_dec = get_table_data(data_direct, RATIO_OUTCOMES_DEC)
        table_data_hour = get_table_data(data_direct, RATIO_OUTCOMES_HOUR)
        
        latex += format_table_row_oriented(
            table_data_dec,
            RATIO_OUTCOMES_DEC,
            f"Dispersion Ratios: December Wages - Direct Effects ({spec})",
            f"tab:direct_ratio_dec_{spec}"
        )
        
        latex += format_table_row_oriented(
            table_data_hour,
            RATIO_OUTCOMES_HOUR,
            f"Dispersion Ratios: Hourly Wages - Direct Effects ({spec})",
            f"tab:direct_ratio_hour_{spec}"
        )
    else:
        latex += "\\begin{center}\\textit{Data file not available for direct effects}\\end{center}\n\n"
    
    latex += "\\clearpage\n\n"
    
    # ===========================
    # Spillover Effects Subsection
    # ===========================
    latex += "\\subsection{Spillover Effects}\n\n"
    
    # Figure grid
    latex += format_figure_grid(spec, "spill")
    latex += "\\clearpage\n\n"
    
    if data_spill is not None:
        # Main outcomes table
        table_data = get_table_data(data_spill, MAIN_OUTCOMES)
        latex += format_table_row_oriented(
            table_data,
            MAIN_OUTCOMES,
            f"Main Outcomes: Spillover Effects ({spec})",
            f"tab:spill_main_{spec}"
        )
        
        # Percentiles table
        table_data_dec = get_table_data(data_spill, PCT_OUTCOMES_DEC)
        table_data_hour = get_table_data(data_spill, PCT_OUTCOMES_HOUR)
        
        latex += format_table_row_oriented(
            table_data_dec,
            PCT_OUTCOMES_DEC,
            f"Percentiles: December Wages - Spillover Effects ({spec})",
            f"tab:spill_pct_dec_{spec}"
        )
        
        latex += format_table_row_oriented(
            table_data_hour,
            PCT_OUTCOMES_HOUR,
            f"Percentiles: Hourly Wages - Spillover Effects ({spec})",
            f"tab:spill_pct_hour_{spec}"
        )
        
        # Ratios table
        table_data_dec = get_table_data(data_spill, RATIO_OUTCOMES_DEC)
        table_data_hour = get_table_data(data_spill, RATIO_OUTCOMES_HOUR)
        
        latex += format_table_row_oriented(
            table_data_dec,
            RATIO_OUTCOMES_DEC,
            f"Dispersion Ratios: December Wages - Spillover Effects ({spec})",
            f"tab:spill_ratio_dec_{spec}"
        )
        
        latex += format_table_row_oriented(
            table_data_hour,
            RATIO_OUTCOMES_HOUR,
            f"Dispersion Ratios: Hourly Wages - Spillover Effects ({spec})",
            f"tab:spill_ratio_hour_{spec}"
        )
        
        # Union controls robustness table
        all_union_outcomes = []
        for base_outcome in ["lr_remdezr_w", "lr_remdezr_h_w", "l_firm_emp"]:
            all_union_outcomes.extend([base_outcome, f"{base_outcome}_union", f"{base_outcome}_unionexp"])
        
        table_data_union = get_table_data(data_spill, all_union_outcomes)
        latex += format_union_controls_table(table_data_union, spec)
    else:
        latex += "\\begin{center}\\textit{Data file not available for spillover effects}\\end{center}\n\n"
    
    latex += "\\clearpage\n\n"
    
    return latex

def generate_latex_document(data_dir):
    """Generate complete LaTeX document"""
    
    # Load all data
    all_data = {}
    for spec in SPECS:
        all_data[spec] = {}
        
        # Load direct effects
        direct_file = Path(data_dir) / f"results_direct_{spec}.csv"
        if direct_file.exists():
            all_data[spec]['direct'] = load_csv_robust(direct_file)
        else:
            all_data[spec]['direct'] = None
        
        # Load spillover effects
        spill_file = Path(data_dir) / f"results_spill_{spec}.csv"
        if spill_file.exists():
            all_data[spec]['spill'] = load_csv_robust(spill_file)
        else:
            all_data[spec]['spill'] = None
    
    # Start LaTeX document
    latex = r"""\documentclass[12pt,letterpaper]{article}

% Packages
\usepackage[margin=1in]{geometry}
\usepackage{graphicx}
\usepackage{booktabs}
\usepackage{threeparttable}
\usepackage{caption}
\usepackage{subcaption}
\usepackage{amsmath}
\usepackage{amssymb}
\usepackage{hyperref}
\usepackage{pdflscape}
\usepackage{longtable}
\usepackage{array}
\usepackage{float}  % For [H] placement specifier

% Settings
\hypersetup{
    colorlinks=true,
    linkcolor=blue,
    citecolor=blue,
    urlcolor=blue
}

\begin{document}

% Title page
\begin{titlepage}
\centering
\vspace*{2cm}

{\Huge\bfseries Union Spillovers:\\Collective Bargaining Effects on\\Connected Firms\par}

\vspace{2cm}

{\Large Final Results Compendium\par}

\vspace{1cm}

{\large \today\par}

\vfill

{\large Luis Lagos\\
Northwestern University\\
Kellogg School of Management\par}

\end{titlepage}

% Table of contents
\tableofcontents
\clearpage

"""
    
    # Generate sections for each specification
    for spec in SPECS:
        latex += generate_spec_section(
            spec,
            all_data[spec]['direct'],
            all_data[spec]['spill']
        )
    
    # End document
    latex += "\\end{document}\n"
    
    return latex

def main():
    import sys
    
    data_dir = sys.argv[1] if len(sys.argv) > 1 else "/mnt/user-data/uploads"
    output_file = sys.argv[2] if len(sys.argv) > 2 else "/mnt/user-data/outputs/UnionSpillovers_Results.tex"
    
    print("Generating LaTeX document...")
    print(f"Data directory: {data_dir}")
    print(f"Output file: {output_file}")
    
    latex_content = generate_latex_document(data_dir)
    
    with open(output_file, 'w') as f:
        f.write(latex_content)
    
    print(f"✓ LaTeX document generated: {output_file}")
    print(f"  Document length: {len(latex_content)} characters")
    print(f"  {len(SPECS)} specifications included")

if __name__ == "__main__":
    main()
