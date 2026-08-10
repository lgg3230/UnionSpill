
"""
Script to convert MEGA_*.csv files (containing regression results) into LaTeX table format.
These CSV files appear to contain results from difference-in-differences analyses with
multiple specifications (Direct effects, Spillover effects, etc.).
"""

import argparse
import re
from pathlib import Path
import pandas as pd

def clean_headers(df):
    """
    Clean and standardize column headers in the dataframe.
    
    Args:
        df: Input dataframe with potentially messy column headers
        
    Returns:
        Cleaned dataframe with standardized column names
    """
    df = df.copy()
    # Remove quotes and equal signs from column names (common in Stata output)
    df.columns = [c.replace('="','').replace('"','') for c in df.columns]
    
    # Rename the first column to 'var' (contains variable names/row labels)
    first_col = df.columns[0]
    df = df.rename(columns={first_col: 'var'})
    
    # Convert all data to strings and strip whitespace
    for c in df.columns:
        df[c] = df[c].astype(str).str.strip()
    return df

def detect_pf_pw(filename: str):
    """
    Detect whether the CSV file contains 'pf' (percentage flows) or 'pw' (percentage workers) results.
    This determines which column mapping to use for extracting results.
    
    Args:
        filename: Name of the CSV file
        
    Returns:
        "pf" for percentage flows or "pw" for percentage workers (defaults to "pf")
    """
    fn = filename.lower()
    # Check for percentage flows indicators
    is_pf = ("_pf_" in fn) or ("avg_ftreat_pf" in fn) or ("totaltreat_pf" in fn)
    # Check for percentage workers indicators  
    is_pw = ("_pw_" in fn) or ("avg_ftreat_pw" in fn) or ("totaltreat_pw" in fn)
    
    if is_pf and not is_pw:
        return "pf"
    if is_pw and not is_pf:
        return "pw"
    return "pf"  # Default to pf if unclear

# Column mapping for percentage flows (pf) results
# Each tuple contains (post_coef_col, pre_coef_col) and the specification label
COL_PAIRS_PF = [((1,2), "Direct"),                    # Columns (1) and (2) for direct treatment effects
                ((3,4), "Spillover"),                 # Columns (3) and (4) for spillover effects
                ((5,6), "Spillover -- Small Firms"),  # Columns (5) and (6) for small firms spillover
                ((7,8), "Spillover -- Large Firms"),  # Columns (7) and (8) for large firms spillover
                ((13,14), "Spillover -- Outflows"),   # Columns (13) and (14) for outflows spillover
                ((15,16), "Spillover -- Inflows")]    # Columns (15) and (16) for inflows spillover

# Column mapping for percentage workers (pw) results
# Same specifications but different column numbers due to different CSV structure
COL_PAIRS_PW = [((1,2), "Direct"),                    # Columns (1) and (2) for direct treatment effects
                ((3,4), "Spillover"),                 # Columns (3) and (4) for spillover effects
                ((5,6), "Spillover -- Small Firms"),  # Columns (5) and (6) for small firms spillover
                ((7,8), "Spillover -- Large Firms"),  # Columns (7) and (8) for large firms spillover
                ((9,10), "Spillover -- Outflows"),    # Columns (9) and (10) for outflows spillover
                ((11,12), "Spillover -- Inflows")]    # Columns (11) and (12) for inflows spillover

def cname(k): 
    """
    Convert column index to column name format used in CSV files.
    
    Args:
        k: Column index number
        
    Returns:
        Column name in format "(k)" where k is the column number
    """
    return f"({k})"

def extract_pair_at_offset(df, k_post, k_pre, offset):
    """
    Extract coefficient values and standard errors for post and pre treatment periods
    from specific columns in the dataframe, accounting for an offset.
    
    Args:
        df: Dataframe containing regression results
        k_post: Column index for post-treatment coefficient
        k_pre: Column index for pre-treatment coefficient  
        offset: Column offset to apply (used to differentiate Panel A vs Panel B)
        
    Returns:
        Tuple of (post_coef, post_se, pre_coef, pre_se) - cleaned values
    """
    # Calculate actual column names with offset
    c_post = cname(k_post + offset)  # Post-treatment coefficient column
    c_pre  = cname(k_pre + offset)   # Pre-treatment coefficient column
    
    def first_nonempty(col):
        """
        Find the first non-empty value in a column.
        
        Args:
            col: Column name
            
        Returns:
            Tuple of (index, value) of first non-empty entry
        """
        ser = df[col].replace(["", "nan", "None"], pd.NA)
        idx = ser.first_valid_index()
        return idx, (None if idx is None else ser.loc[idx])
    
    # Extract coefficient values
    idx_post, v_post = first_nonempty(c_post)
    idx_pre, v_pre = first_nonempty(c_pre)
    
    # Extract standard errors (typically in row below coefficient)
    se_post = df[c_post].shift(-1).loc[idx_post] if idx_post is not None else None
    se_pre = df[c_pre].shift(-1).loc[idx_pre] if idx_pre is not None else None
    
    def clean(s):
        """
        Clean and format coefficient/SE values by removing quotes and whitespace.
        
        Args:
            s: Raw value to clean
            
        Returns:
            Cleaned string value
        """
        if s is None or pd.isna(s): 
            return ""
        s = str(s).replace('="','').replace('"','').strip()
        return s
    
    return (clean(v_post), clean(se_post), clean(v_pre), clean(se_pre))

def build_panel(df, col_pairs, offset):
    """
    Build a panel of results by extracting coefficients and standard errors
    for all specifications defined in col_pairs.
    
    Args:
        df: Dataframe containing regression results
        col_pairs: List of (column_pairs, label) tuples defining specifications
        offset: Column offset to apply (differentiates Panel A vs Panel B)
        
    Returns:
        Tuple of (headers, post_coefs, post_ses, pre_coefs, pre_ses) lists
    """
    headers = []    # Specification labels (e.g., "Direct", "Spillover")
    post = []       # Post-treatment coefficients
    postse = []     # Post-treatment standard errors
    pre = []        # Pre-treatment coefficients  
    prese = []      # Pre-treatment standard errors
    
    # Extract results for each specification
    for (pair, label) in col_pairs:
        k_post, k_pre = pair  # Column indices for post and pre coefficients
        v_post, se_post, v_pre, se_pre = extract_pair_at_offset(df, k_post, k_pre, offset)
        
        headers.append(label)
        post.append(v_post)
        postse.append(se_post)
        pre.append(v_pre)
        prese.append(se_pre)
    
    return headers, post, postse, pre, prese

def pull_stat_row(df, label_regex, col_pairs, offset):
    """
    Extract statistics (like sample size, number of firms) from rows matching a regex pattern.
    
    Args:
        df: Dataframe containing regression results
        label_regex: Regex pattern to match row labels (e.g., "Observations", "Sample Size")
        col_pairs: List of column pairs defining specifications
        offset: Column offset to apply
        
    Returns:
        List of values for each specification, or None if no matching rows found
    """
    # Find rows where the 'var' column matches the regex pattern
    m = df[df["var"].str.contains(label_regex, case=False, na=False)]
    if m.empty: 
        return None
    
    # Get the first matching row
    row = m.iloc[0]
    vals = []
    
    # Extract values for each specification
    for i in range(len(col_pairs)):
        k_post = col_pairs[i][0][0]  # Get the post-treatment column index
        c = cname(k_post + offset)   # Calculate column name with offset
        v = str(row.get(c, "")).replace('="','').replace('"','').strip()
        vals.append(v)
    
    return vals

def compute_sample_size_if_missing(N_vals, F_vals, years=8):
    """
    Compute sample size (observations) if missing by multiplying number of firms by years.
    
    Args:
        N_vals: List of observation counts (may be missing/empty)
        F_vals: List of firm counts 
        years: Number of years in the panel (default 8)
        
    Returns:
        List of sample sizes, computed from firms*years if N_vals is missing
    """
    if F_vals is None: 
        return N_vals
    
    out = []
    for n, f in zip(N_vals or [""]*len(F_vals), F_vals):
        n_clean = (n or "").strip()  # Clean observation count
        f_clean = (f or "").strip()  # Clean firm count
        
        # If observations missing but firm count available, compute observations
        if n_clean == "" and f_clean != "":
            try:
                # Extract number from firm count string and multiply by years
                f_int = int(re.sub(r"[^0-9]", "", f_clean))
                # Format with commas, then replace commas with LaTeX-friendly formatting
                out.append(f"{f_int*years:,}".replace(",", "{,}"))
            except:
                # If parsing fails, use original N value
                out.append(n)
        else:
            # Use original N value if available
            out.append(n)
    
    return out

def latex_makecell(label):
    """
    Convert specification labels to LaTeX formatted headers using makecell for multi-line headers.
    
    Args:
        label: Specification label (e.g., "Spillover -- Small Firms")
        
    Returns:
        LaTeX formatted header string
    """
    if "Small Firms" in label:
        return r"\makecell{\textbf{Spillover --}\\\textbf{Small Firms}}"
    if "Large Firms" in label:
        return r"\makecell{\textbf{Spillover --}\\\textbf{Large Firms}}"
    if "Outflows" in label:
        return r"\makecell{\textbf{Spillover --}\\\textbf{Outflows}}"
    if "Inflows" in label:
        return r"\makecell{\textbf{Spillover --}\\\textbf{Inflows}}"
    if label == "Spillover":
        return r"\textbf{Spillover}"
    if label == "Direct":
        return r"\textbf{Direct}"
    return r"\textbf{" + label + "}"

def build_table_tex(csv_path: Path, size_cmd="\\tiny", years=8):
    """
    Main function to convert a MEGA CSV file into LaTeX table format.
    
    Args:
        csv_path: Path to the MEGA_*.csv file
        size_cmd: LaTeX size command (default \tiny)
        years: Number of years in panel for computing sample sizes
        
    Returns:
        Complete LaTeX table as string
    """
    # Load and clean the CSV data
    df = pd.read_csv(csv_path)
    df = clean_headers(df)
    
    # Determine column mapping based on filename
    flavor = detect_pf_pw(csv_path.name)
    col_pairs = COL_PAIRS_PF if flavor == "pf" else COL_PAIRS_PW

    # Extract results for Panel A (Log December Earnings) - offset 16
    headers_A, post_A, postse_A, pre_A, prese_A = build_panel(df, col_pairs, offset=16)
    
    # Extract results for Panel B (Log Employment) - offset 0  
    headers_B, post_B, postse_B, pre_B, prese_B = build_panel(df, col_pairs, offset=0)

    # Extract sample statistics for Panel A
    N_A = pull_stat_row(df, r"(Observations|Sample Size|N obs)", col_pairs, offset=16)
    F_A = pull_stat_row(df, r"(Number of establishments|Number of firms|N firms|Establishments)", col_pairs, offset=16)
    
    # Extract sample statistics for Panel B
    N_B = pull_stat_row(df, r"(Observations|Sample Size|N obs)", col_pairs, offset=0)
    F_B = pull_stat_row(df, r"(Number of establishments|Number of firms|N firms|Establishments)", col_pairs, offset=0)

    # Handle missing sample sizes
    if N_A is None and F_A is not None: N_A = [""]*len(F_A)
    if N_B is None and F_B is not None: N_B = [""]*len(F_B)
    
    # Compute sample sizes if missing
    N_A = compute_sample_size_if_missing(N_A, F_A, years=years) if N_A is not None else None
    N_B = compute_sample_size_if_missing(N_B, F_B, years=years) if N_B is not None else None

    # Build LaTeX table structure
    lines = []
    
    # Table environment and formatting
    lines.append(r"\begin{table}[htbp]")
    lines.append(r"\centering")
    
    # Caption and label
    caption = f"Summary of Results – {csv_path.stem.replace('_', ' ')}"
    lines.append(r"\caption{" + caption + "}")
    lines.append(r"\label{tab:" + csv_path.stem + "}")
    
    # Size command and table structure
    lines.append(size_cmd)
    lines.append(r"\begin{tabular}{l" + "c"*len(headers_A) + "}")  # One left-aligned + multiple centered columns
    lines.append(r"\toprule")
    
    # Column headers
    lines.append("  & " + " & ".join([f"({i+1})" for i in range(len(headers_A))]) + r" \\")  # Column numbers
    lines.append("  & " + " & ".join([latex_makecell(h) for h in headers_A]) + r" \\")  # Specification labels
    lines.append(r"\midrule")
    
    # Panel A: Log December Earnings
    lines.append(r"\multicolumn{3}{l}{\textbf{Panel A: Log December Earnings}} &&& \\[1pt] &&&&&& \\")
    lines.append("Main Effect " + " & " + " & ".join(post_A) + r" \\")  # Post-treatment coefficients
    lines.append(" & " + " & ".join(postse_A) + r" \\[5pt]")  # Standard errors in parentheses
    lines.append("Pre Period " + " & " + " & ".join(pre_A) + r" \\")  # Pre-treatment coefficients
    lines.append(" & " + " & ".join(prese_A) + r" \\[1pt] \hline\\")  # Standard errors
    
    # Sample statistics for Panel A
    if N_A is not None and any(x for x in N_A): 
        lines.append("Sample Size " + " & " + " & ".join(N_A) + r" \\")
    if F_A is not None and any(x for x in F_A): 
        lines.append("Number of establishments " + " & " + " & ".join(F_A) + r" \\")
    
    lines.append(r"\addlinespace[5pt]")
    lines.append(r"\midrule")
    
    # Panel B: Log Employment
    lines.append(r"\multicolumn{3}{l}{\textbf{Panel B: Log Employment}} &&&\\[1pt]")
    lines.append("Main Effect " + " & " + " & ".join(post_B) + r" \\")  # Post-treatment coefficients
    lines.append(" & " + " & ".join(postse_B) + r" \\[5pt]")  # Standard errors
    lines.append("Pre Period " + " & " + " & ".join(pre_B) + r" \\")  # Pre-treatment coefficients
    lines.append(" & " + " & ".join(prese_B) + r" \\[1pt] \hline \\")  # Standard errors
    
    # Sample statistics for Panel B
    if N_B is not None and any(x for x in N_B): 
        lines.append("Sample Size " + " & " + " & ".join(N_B) + r" \\")
    if F_B is not None and any(x for x in F_B): 
        lines.append("Number of establishments " + " & " + " & ".join(F_B) + r" \\")
    
    # Close table
    lines.append(r"\bottomrule")
    lines.append(r"\end{tabular}")
    lines.append(r"\end{table}")
    
    return "\n".join(lines)

def main():
    """
    Command-line interface for converting MEGA CSV files to LaTeX tables.
    
    Usage examples:
        python make_table_from_mega.py --csv MEGA_A_2_p0911.csv
        python make_table_from_mega.py --csv MEGA_A_2_p0911.csv --out custom_table.tex --size_cmd "\\scriptsize"
    """
    ap = argparse.ArgumentParser(description="Convert MEGA CSV regression results to LaTeX tables")
    ap.add_argument("--csv", required=True, help="Path to a MEGA_*.csv file")
    ap.add_argument("--out", default=None, help="Output .tex path (default: same name as CSV with .table.tex extension)")
    ap.add_argument("--size_cmd", default="\\tiny", help="LaTeX size command (e.g., \\scriptsize, \\small)")
    ap.add_argument("--years", type=int, default=8, help="Number of years in panel (used to compute sample sizes if missing)")
    
    args = ap.parse_args()

    # Process the CSV file
    csv_path = Path(args.csv)
    tex = build_table_tex(csv_path, size_cmd=args.size_cmd, years=args.years)
    
    # Determine output path
    out = Path(args.out) if args.out else csv_path.with_suffix(".table.tex")
    
    # Write LaTeX table to file
    out.write_text(tex)
    print(f"Wrote {out}")

if __name__ == "__main__":
    main()
