#!/usr/bin/env python3
"""
Bilateral pair-cell variance decomposition + within/between predictability.

Scales to 100M+ rows because it never materializes row-level residuals.
Requires: duckdb, pyarrow (duckdb usually pulls pyarrow indirectly).
"""

import argparse
import math
import duckdb


DEFAULT_PATH = "/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/bilateral_regression_data.parquet"


# ---------- helpers ----------
def pick_first(existing_cols, candidates):
    cand_lower = {c.lower(): c for c in existing_cols}
    for c in candidates:
        if c in existing_cols:
            return c
        if c.lower() in cand_lower:
            return cand_lower[c.lower()]
    return None


def safe_div(a, b):
    if b is None or b == 0 or (isinstance(b, float) and (math.isnan(b) or math.isinf(b))):
        return float("nan")
    return a / b


def fmt(x, nd=6):
    if x is None:
        return "None"
    if isinstance(x, float) and (math.isnan(x) or math.isinf(x)):
        return "nan"
    return f"{x:.{nd}f}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--path", default=DEFAULT_PATH, help="Parquet path")
    ap.add_argument("--pre", default=None, help="pre variable (default auto-detect)")
    ap.add_argument("--post", default=None, help="post variable (default auto-detect)")
    ap.add_argument("--cell_i", default=None, help="cell id for i (industry×microregion), default auto-detect")
    ap.add_argument("--cell_j", default=None, help="cell id for j (industry×microregion), default auto-detect")
    ap.add_argument("--where", default="1=1", help="optional SQL WHERE filter, e.g. 'sample==1'")
    ap.add_argument("--use_hash_cells", action="store_true",
                    help="if cell_i/cell_j are strings, hash them into BIGINT for paircell (tiny collision risk)")
    args = ap.parse_args()

    con = duckdb.connect(database=":memory:")
    con.execute("PRAGMA threads=8")  # adjust if you want; harmless if fewer cores

    # Inspect schema to auto-detect columns
    cols = [r[0] for r in con.execute(f"DESCRIBE SELECT * FROM read_parquet('{args.path}')").fetchall()]

    # Default candidates (edit if you want, but this should work with your names)
    pre_col = args.pre or pick_first(cols, [
        "bilateral_conn_pre", "connectivity_pre", "conn_pre", "bilateral_pre", "flows_conn_pre"
    ])
    post_col = args.post or pick_first(cols, [
        "bilateral_conn_post", "connectivity_post", "conn_post", "bilateral_post", "flows_conn_post"
    ])

    # These are your "industry-microregion i/j" cell identifiers.
    # We construct them from industry1_* and microregion_* columns.
    cell_i_col = args.cell_i or "cell_i_expr"
    cell_j_col = args.cell_j or "cell_j_expr"

    # Check if we have the component columns to build cells
    has_components = all(c in cols for c in ["industry1_i", "microregion_i", "industry1_j", "microregion_j"])
    use_constructed_cells = (cell_i_col == "cell_i_expr") and has_components

    if pre_col is None or post_col is None:
        raise SystemExit(
            f"Could not auto-detect pre/post columns.\n"
            f"Found columns include e.g.: {cols[:30]} ...\n"
            f"Please pass --pre and --post explicitly."
        )
    if not use_constructed_cells and (cell_i_col == "cell_i_expr" or cell_j_col == "cell_j_expr"):
        raise SystemExit(
            f"Could not find cell columns or components (industry1_*, microregion_*).\n"
            f"Please pass --cell_i and --cell_j explicitly."
        )

    # Build SQL expressions for cell ids used to make unordered paircell.
    if use_constructed_cells:
        # Construct cell from industry1 and microregion
        ci_expr = "hash(industry1_i, microregion_i)::UBIGINT"
        cj_expr = "hash(industry1_j, microregion_j)::UBIGINT"
        cell_i_col = "(industry1_i, microregion_i)"
        cell_j_col = "(industry1_j, microregion_j)"
        cell_not_null = "industry1_i IS NOT NULL AND microregion_i IS NOT NULL AND industry1_j IS NOT NULL AND microregion_j IS NOT NULL"
    elif args.use_hash_cells:
        ci_expr = f"hash({cell_i_col})::UBIGINT"
        cj_expr = f"hash({cell_j_col})::UBIGINT"
        cell_not_null = f"{cell_i_col} IS NOT NULL AND {cell_j_col} IS NOT NULL"
    else:
        ci_expr = f"{cell_i_col}"
        cj_expr = f"{cell_j_col}"
        cell_not_null = f"{cell_i_col} IS NOT NULL AND {cell_j_col} IS NOT NULL"

    # Unordered paircell expression (BIGINT). Uses (min,max) + hash to keep it compact.
    # We hash the (min,max) tuple to avoid overflow concerns if ci/cj are large.
    paircell_expr = f"hash(least({ci_expr},{cj_expr}), greatest({ci_expr},{cj_expr}))::UBIGINT"

    where = args.where

    # -------- 1) global moments --------
    # First, count total rows and rows dropped due to NULLs
    count_sql = f"""
    SELECT
      COUNT(*) AS n_total,
      SUM(CASE WHEN {pre_col} IS NULL THEN 1 ELSE 0 END) AS n_pre_null,
      SUM(CASE WHEN {post_col} IS NULL THEN 1 ELSE 0 END) AS n_post_null,
      SUM(CASE WHEN NOT ({cell_not_null}) THEN 1 ELSE 0 END) AS n_cell_null
    FROM read_parquet('{args.path}')
    WHERE {where}
    """
    n_total, n_pre_null, n_post_null, n_cell_null = con.execute(count_sql).fetchone()

    global_sql = f"""
    SELECT
      COUNT(*)::UBIGINT AS N,
      SUM({pre_col})::DOUBLE  AS sum_x,
      SUM({post_col})::DOUBLE AS sum_y,
      SUM(({pre_col})*({pre_col}))::DOUBLE   AS sum_x2,
      SUM(({post_col})*({post_col}))::DOUBLE AS sum_y2,
      SUM(({pre_col})*({post_col}))::DOUBLE  AS sum_xy
    FROM read_parquet('{args.path}')
    WHERE {where}
      AND {pre_col} IS NOT NULL AND {post_col} IS NOT NULL
      AND {cell_not_null}
    """
    N, sum_x, sum_y, sum_x2, sum_y2, sum_xy = con.execute(global_sql).fetchone()

    mx = sum_x / N
    my = sum_y / N

    SST_x = sum_x2 - N * mx * mx
    SST_y = sum_y2 - N * my * my

    # -------- 2) group table (paircell means/counts) --------
    con.execute("DROP TABLE IF EXISTS grp")
    grp_sql = f"""
    CREATE TEMP TABLE grp AS
    SELECT
      {paircell_expr} AS paircell,
      COUNT(*)::UBIGINT AS n_g,
      AVG({pre_col})::DOUBLE  AS mx_g,
      AVG({post_col})::DOUBLE AS my_g
    FROM read_parquet('{args.path}')
    WHERE {where}
      AND {pre_col} IS NOT NULL AND {post_col} IS NOT NULL
      AND {cell_not_null}
    GROUP BY 1
    """
    con.execute(grp_sql)

    # Verify group table has same total observations as global query
    # Also count singleton pair-cells (n_g = 1)
    grp_stats = con.execute("""
        SELECT
            SUM(n_g) AS n_total,
            COUNT(*) AS n_groups,
            SUM(CASE WHEN n_g = 1 THEN 1 ELSE 0 END) AS n_singletons,
            SUM(CASE WHEN n_g = 1 THEN n_g ELSE 0 END) AS n_obs_in_singletons
        FROM grp
    """).fetchone()
    n_grp_total, n_groups, n_singletons, n_obs_in_singletons = grp_stats

    if n_grp_total != N:
        print(f"WARNING: Group total ({n_grp_total}) != Global N ({N}). Some observations may be lost!")

    # Scalars from grp: sums needed for within/between SS and cross-products
    agg_sql = """
    SELECT
      SUM(n_g * (mx_g*mx_g))::DOUBLE AS sum_n_mx2,
      SUM(n_g * (my_g*my_g))::DOUBLE AS sum_n_my2,
      SUM(n_g * (mx_g*my_g))::DOUBLE AS sum_n_mxmy,
      SUM(n_g * ((mx_g - ?) * (mx_g - ?)))::DOUBLE AS SSB_x,
      SUM(n_g * ((my_g - ?) * (my_g - ?)))::DOUBLE AS SSB_y
    FROM grp
    """
    sum_n_mx2, sum_n_my2, sum_n_mxmy, SSB_x, SSB_y = con.execute(
        agg_sql, [mx, mx, my, my]
    ).fetchone()

    SSE_x = SST_x - SSB_x
    SSE_y = SST_y - SSB_y

    share_x_between = safe_div(SSB_x, SST_x)
    share_x_within  = safe_div(SSE_x, SST_x)
    share_y_between = safe_div(SSB_y, SST_y)
    share_y_within  = safe_div(SSE_y, SST_y)

    # -------- 3) Step 2a1: within regression stats (demeaned) --------
    Sxx_w = sum_x2 - sum_n_mx2
    Syy_w = sum_y2 - sum_n_my2
    Sxy_w = sum_xy - sum_n_mxmy

    beta_w = safe_div(Sxy_w, Sxx_w)
    R2_w = safe_div((Sxy_w * Sxy_w), (Sxx_w * Syy_w))

    # -------- 4) Step 2b1: between regression on means, weighted by n_g --------
    between_sql = """
    SELECT
      SUM(n_g)::DOUBLE AS W,
      SUM(n_g * mx_g)::DOUBLE AS Wx,
      SUM(n_g * my_g)::DOUBLE AS Wy,
      SUM(n_g * mx_g * mx_g)::DOUBLE AS Wxx,
      SUM(n_g * my_g * my_g)::DOUBLE AS Wyy,
      SUM(n_g * mx_g * my_g)::DOUBLE AS Wxy
    FROM grp
    """
    W, Wx, Wy, Wxx, Wyy, Wxy = con.execute(between_sql).fetchone()

    xbar = Wx / W
    ybar = Wy / W

    SSX_b = Wxx - W * xbar * xbar
    SSY_b = Wyy - W * ybar * ybar
    SXY_b = Wxy - W * xbar * ybar

    beta_b = safe_div(SXY_b, SSX_b)
    R2_b = safe_div((SXY_b * SXY_b), (SSX_b * SSY_b))

    # -------- print results --------
    print("=== Inputs ===")
    print(f"path      : {args.path}")
    print(f"pre       : {pre_col}")
    print(f"post      : {post_col}")
    print(f"cell_i    : {cell_i_col}")
    print(f"cell_j    : {cell_j_col}")
    print(f"where     : {where}")
    print(f"use_hash_cells: {args.use_hash_cells}")
    print()

    print("=== Observation counts ===")
    print(f"Total rows (after where filter) = {n_total}")
    print(f"  Dropped: pre is NULL           = {n_pre_null}")
    print(f"  Dropped: post is NULL          = {n_post_null}")
    print(f"  Dropped: cell components NULL  = {n_cell_null}")
    print(f"  Used in analysis               = {N}")
    print(f"  Number of pair-cells           = {n_groups}")
    print(f"  Singleton pair-cells (n=1)     = {n_singletons} ({100*n_singletons/n_groups:.2f}% of pair-cells)")
    print(f"  Obs in singleton pair-cells    = {n_obs_in_singletons} ({100*n_obs_in_singletons/N:.2f}% of obs)")
    print()

    print("=== Global moments ===")
    print(f"N      = {N}")
    print(f"mean_x = {fmt(mx)}")
    print(f"mean_y = {fmt(my)}")
    print(f"SST_x  = {fmt(SST_x, nd=3)}")
    print(f"SST_y  = {fmt(SST_y, nd=3)}")
    print()

    print("=== Step 1: PRE variance shares by paircell ===")
    print(f"between share (pre) = {fmt(share_x_between, nd=6)}")
    print(f"within  share (pre) = {fmt(share_x_within,  nd=6)}")
    print()

    print("=== Step 2: POST variance shares by paircell ===")
    print(f"between share (post) = {fmt(share_y_between, nd=6)}")
    print(f"within  share (post) = {fmt(share_y_within,  nd=6)}")
    print()

    print("=== Step 2a1: within-post explained by within-pre ===")
    print(f"beta_within = {fmt(beta_w, nd=6)}")
    print(f"R2_within   = {fmt(R2_w,   nd=6)}")
    print()

    print("=== Step 2b1: between-post explained by between-pre (weighted by n_g) ===")
    print(f"beta_between = {fmt(beta_b, nd=6)}")
    print(f"R2_between   = {fmt(R2_b,   nd=6)}")
    print()

    # Optional: a quick integrity check (shares should sum ~1 when SST>0)
    if SST_x > 0:
        print(f"check pre shares sum  = {fmt(share_x_between + share_x_within, nd=6)}")
    if SST_y > 0:
        print(f"check post shares sum = {fmt(share_y_between + share_y_within, nd=6)}")


if __name__ == "__main__":
    main()