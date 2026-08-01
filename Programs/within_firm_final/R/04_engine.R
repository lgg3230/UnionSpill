# ------------------------------------------------------------------------------
# 05_engine.R -- R port of Luis_og/scripts/05a_within_firm_estimates.do
#
# Section numbers in the comments refer to the do-file, so the two can be read
# side by side. Produces the same four CSVs:
#   a6_group<sfx>.csv, a6_partition<sfx>.csv, a7<sfx>.csv, a8<sfx>.csv
# ------------------------------------------------------------------------------

GROUPS <- list(edu2   = c("no_hs",  "has_hs"),
               gender = c("female", "male"),
               ten2   = c("lt12mo", "ge12mo"))

#' Fixed-effect sets, mirroring the `local bins` / `local abs` construction.
fes_firm <- function(outcome) {
  bins <- if (outcome == "emp")
    list(c("l_firm_emp_pre4", "year"), c("totalflows_pw_pre4", "year"))
  else
    list(c("wage_pre4_firm", "year"), c("l_firm_emp_pre4", "year"),
         c("totalflows_pw_pre4", "year"))
  c(list("identificad"), bins,
    list(c("industry1_num", "year"), c("mode_base_month_num", "year"),
         c("microregion_num", "year")))
}

fes_layer <- function(outcome, kind) {
  bins <- if (outcome == "emp")
    list(c("l_layer_emp_pre4", "year"), c("layer_totalflows_pw_pre4", "year"))
  else
    list(c("wage_pre4_layer", "year"), c("l_layer_emp_pre4", "year"),
         c("layer_totalflows_pw_pre4", "year"))
  tail <- if (kind == "within")
    list(c("firm_id", "year"))
  else
    list(c("industry1_num", "year"), c("mode_base_month_num", "year"),
         c("microregion_num", "year"))
  c(list("firm_layer_id"), bins, tail)
}


#' Run the A6 / A7 / A8 exhibits under the CORE specification.
#'
#' The core specification differs from the shipped one by three additions to the
#' two group-level columns of A7. Nothing is removed. See README.md.
#'
#'   1. The year interactions are allowed to differ by worker group:
#'        layer_id x negotiation-month x year
#'        layer_id x industry x year
#'        layer_id x microregion x year
#'      The plain versions are then dropped from the "overall" column, being
#'      fully nested inside these. In the "within" column the plain versions
#'      never appeared (firm x year absorbs them), but the group-interacted ones
#'      are identified, because the two groups of a firm-year share an industry
#'      and differ in group.
#'
#'   2. The three pre-treatment quartile bins are made group-specific. They are
#'      already computed per firm x group; only their YEAR PATH was common to
#'      both groups. This refines rather than adds, since layer_id x bin x year
#'      nests bin x year.
#'
#'   3. The "overall" column gains the FIRM-level pre-treatment bins x year, the
#'      same ones A7 column (1) uses. The shipped specification substituted
#'      group-level analogues and never carried the firm-level versions. The
#'      "within" column does not need them: firm x year absorbs them.
#'
#' None of this touches A6, the firm-level columns of A7, or any printed row of
#' A8, all of which are firm-level regressions with no group dimension.
#'
#' @param outdir where to write the CSVs (defaults to OUT).
run_within_firm <- function(wfirm, wlayer, sfx,
                            partitions = c("edu2", "gender", "ten2"),
                            outdir = NULL) {

  if (is.null(outdir)) outdir <- OUT

  # Tie-break at the quartile cutpoints. The group-level bins need the strict
  # form; the firm-level bins need the non-strict form. See README.md.
  tie <- "down"

  # The three group-interacted fixed effects (addition 1).
  GROUP_FE <- list(c("layer_id", "mode_base_month_num", "year"),
                   c("layer_id", "industry1_num",       "year"),
                   c("layer_id", "microregion_num",     "year"))
  # Bin variables eligible to be made group-specific (addition 2).
  BIN_VARS <- c("wage_pre4_layer", "l_layer_emp_pre4", "layer_totalflows_pw_pre4")

  msg("======================================================================")
  msg("Within-firm group exhibits (A6/A7/A8)")
  msg("  firm wage variable  : %s", wfirm)
  msg("  layer wage variable : %s", wlayer)
  msg("  output suffix       : '%s'", sfx)
  msg("======================================================================")

  A7 <- list(); A8 <- list(); A6G <- list(); A6P <- list()

  # -- Sections 1 / 1b / 1c ----------------------------------------------------
  fp   <- build_firm_panel(wfirm)
  FIRM <- fp$dt
  P90  <- fp$p90

  # -- Section 3: A7 firm-level full-sample column ------------------------------
  # FSET[[oc]] is the firm set surviving the firm-level regression for that
  # outcome. Kept only as a run-time invariant check: every firm-level cell of
  # A7 and A8 should already be a subset of it, so the core additions (which
  # touch the group columns only) cannot silently change them.
  FSET <- list()
  for (y in c(wfirm, "l_firm_emp")) {
    oc  <- if (y == "l_firm_emp") "emp" else "wage"
    fes <- fes_firm(oc)
    cond <- FIRM[, treat_ultra == 0 & in_balanced_panel == 1 & !is.na(get(y))]
    dm <- FIRM[cond]; dp <- FIRM[cond & FIRM$year <= 2011]
    FSET[[oc]] <- unique(as.character(dm$identificad[drop_singletons_idx(dm, fes)]))
    r <- didcol(dm, dp, y, "totaltreat_pw_norm", fes, gxf = NULL)
    for (p in partitions)
      A7[[length(A7) + 1L]] <- data.table(
        partition = p, col = "firm_full", outcome = oc,
        b = r$b, se = r$se, bpre = r$bpre, sepre = r$sepre,
        n = r$n, firms = r$firms, gxf = NA_integer_)
    msg("  [A7 firm_full %s] b=%.10f se=%.10f n=%d firms=%d", oc, r$b, r$se, r$n, r$firms)
  }

  # -- Section 4: loop over partitions -----------------------------------------
  for (p in partitions) {
    g1 <- GROUPS[[p]][1]; g2 <- GROUPS[[p]][2]
    msg("")
    msg("==================== PARTITION: %s (%s/%s) ====================", p, g1, g2)

    GP <- build_layer_panel(p, wlayer, P90, tie)


    # The firm-level pre-treatment bins are needed for addition 3; they live on
    # the firm panel, so merge them in. Firm connectivity is not used here.
    fcols <- c("identificad", "year", "wage_pre4_firm", "l_firm_emp_pre4",
               "totalflows_pw_pre4")
    nb <- nrow(GP)
    GP <- merge(GP, FIRM[, ..fcols], by = c("identificad", "year"),
                all.x = TRUE, sort = FALSE)
    stopifnot(nrow(GP) == nb)

    # ---- 4b: A6 descriptives -------------------------------------------------
    cell <- GP[s_base == 1 & year >= 2009 & year <= 2011][
      , .(E     = mean(layer_emp, na.rm = TRUE),
          wlev  = mean(exp(get(wlayer)), na.rm = TRUE),
          flows = mean(totalflows_layer_pw_n, na.rm = TRUE),
          conn  = { v <- layer_treat_pw_n[!is.na(layer_treat_pw_n)]
                    if (length(v)) v[1] else NA_real_ }),      # collapse (firstnm)
      by = .(identificad, layer_id)]

    for (gg in c(g1, g2)) {
      s <- cell[layer_id == gg & !is.na(conn)]
      A6G[[length(A6G) + 1L]] <- data.table(
        partition = p, group = gg,
        avg_emp   = mean(s$E,     na.rm = TRUE),
        avg_wage  = mean(s$wlev,  na.rm = TRUE),
        avg_flows = mean(s$flows, na.rm = TRUE),
        conn      = mean(s$conn,  na.rm = TRUE))
    }

    cc <- cell[!is.na(conn)]
    cc[, ng := .N, by = identificad]
    n_firms_any  <- uniqueN(cc$identificad)
    n_firms_both <- uniqueN(cc[ng == 2]$identificad)
    pct_both <- n_firms_both / n_firms_any

    vd <- cc[ng >= 2]
    Nv <- nrow(vd); gm <- mean(vd$conn)
    vd[, fmean := mean(conn), by = identificad]
    v_tot <- sum((vd$conn - gm)^2)        / (Nv - 1)
    v_wi  <- sum((vd$conn - vd$fmean)^2)  / (Nv - 1)
    v_bw  <- sum((vd$fmean - gm)^2)       / (Nv - 1)
    A6P[[length(A6P) + 1L]] <- data.table(
      partition = p, pct_both = pct_both, v_tot = v_tot, v_wi = v_wi,
      v_bw = v_bw, wi_pct = v_wi / v_tot, bw_pct = v_bw / v_tot)

    # ---- 4c: A7 within / overall group columns -------------------------------
    for (kind in c("within", "overall")) {
      for (y in c(wlayer, "l_layer_emp")) {
        oc  <- if (y == "l_layer_emp") "emp" else "wage"
        fes <- fes_layer(oc, kind)

        # (1) group-interacted geography / sector / calendar
        fes <- c(fes, GROUP_FE)
        # (2) pre-treatment bin paths made group-specific
        fes <- lapply(fes, function(v)
          if (length(v) == 2L && v[1] %in% BIN_VARS) c("layer_id", v) else v)
        # drop plain terms now fully nested inside a group-interacted version
        gi <- Filter(function(v) length(v) == 3L && v[1] == "layer_id", fes)
        if (length(gi)) {
          nested <- lapply(gi, function(v) v[-1])
          fes <- fes[!vapply(fes, function(v)
            any(vapply(nested, function(n) identical(v, n), logical(1))), logical(1))]
        }
        # (3) firm-level pre-treatment bins, "overall" only
        if (kind == "overall") {
          fes <- c(fes, if (oc == "emp")
            list(c("l_firm_emp_pre4", "year"), c("totalflows_pw_pre4", "year"))
          else
            list(c("wage_pre4_firm", "year"), c("l_firm_emp_pre4", "year"),
                 c("totalflows_pw_pre4", "year")))
        }

        cond <- GP[, s_base == 1 & !is.na(get(y)) & !is.na(conn)]
        dm <- GP[cond]; dp <- GP[cond & GP$year <= 2011]
        r <- didcol(dm, dp, y, "conn", fes, gxf = "firm_layer_id")
        A7[[length(A7) + 1L]] <- data.table(
          partition = p, col = kind, outcome = oc,
          b = r$b, se = r$se, bpre = r$bpre, sepre = r$sepre,
          n = r$n, firms = r$firms, gxf = r$gxf)
        msg("  [A7 %s %s] b=%.10f se=%.10f n=%d firms=%d gxf=%d",
            kind, oc, r$b, r$se, r$n, r$firms, r$gxf)
      }
    }

    # ---- 4d: firm-level group connectivity constants and scales --------------
    p90_1 <- stata_pctile(GP[s_base == 1 & year == 2009 & layer_id == g1, layer_treat_pw_n], 90)
    p90_2 <- stata_pctile(GP[s_base == 1 & year == 2009 & layer_id == g2, layer_treat_pw_n], 90)
    sd_1  <- sd(GP[s_base == 1 & year == 2009 & layer_id == g1, layer_treat_pw_n], na.rm = TRUE)
    sd_2  <- sd(GP[s_base == 1 & year == 2009 & layer_id == g2, layer_treat_pw_n], na.rm = TRUE)

    # both-groups firm set: s_base rows with two distinct layers
    bs <- unique(GP[s_base == 1, .(identificad, layer_id)])
    BOTH <- bs[, .N, by = identificad][N == 2, .(identificad)]

    # firm-level c1_raw / c2_raw, over all GP rows (not just s_base)
    cwl <- unique(GP[, .(identificad, layer_id, layer_treat_pw_n)])
    CW <- cwl[, .(c1_raw = { v <- layer_treat_pw_n[layer_id == g1 & !is.na(layer_treat_pw_n)]
                             if (length(v)) v[1] else NA_real_ },
                  c2_raw = { v <- layer_treat_pw_n[layer_id == g2 & !is.na(layer_treat_pw_n)]
                             if (length(v)) v[1] else NA_real_ }),
              by = identificad]

    # ---- 4e: A7 firm-level partition-sample column ---------------------------
    FP <- FIRM[identificad %in% BOTH$identificad]
    for (y in c(wfirm, "l_firm_emp")) {
      oc  <- if (y == "l_firm_emp") "emp" else "wage"
      fes <- fes_firm(oc)
      cond <- FP[, treat_ultra == 0 & in_balanced_panel == 1 & !is.na(get(y))]
      dm <- FP[cond]; dp <- FP[cond & FP$year <= 2011]
      # invariant: this firm-level column is already a subset of the
      # firm-level estimation sample
      surv <- unique(as.character(dm$identificad[drop_singletons_idx(dm, fes)]))
      extra <- setdiff(surv, FSET[[oc]])
      msg("  [check] A7 'firm' %s: %d firms, %d outside the firm-level sample",
          oc, length(surv), length(extra))
      r <- didcol(dm, dp, y, "totaltreat_pw_norm", fes, gxf = NULL)
      A7[[length(A7) + 1L]] <- data.table(
        partition = p, col = "firm", outcome = oc,
        b = r$b, se = r$se, bpre = r$bpre, sepre = r$sepre,
        n = r$n, firms = r$firms, gxf = NA_integer_)
    }

    # ---- 4f: A8 firm-outcome horse race, three scalings ----------------------
    FCW <- merge(FIRM, CW, by = "identificad", all.x = TRUE, sort = FALSE)
    for (mode in c("own", "firm", "sd")) {
      s1 <- switch(mode, own = p90_1, sd = sd_1, firm = P90)
      s2 <- switch(mode, own = p90_2, sd = sd_2, firm = P90)
      D <- copy(FCW)
      # Stata returns missing on division by zero; R returns Inf, which would
      # survive the !is.na() filter below and enter the regression.
      stopifnot(is.finite(s1), is.finite(s2), s1 > 0, s2 > 0)
      D[, `:=`(cG1 = c1_raw / s1, cG2 = c2_raw / s2)]
      D <- D[treat_ultra == 0 & in_balanced_panel == 1 & !is.na(cG1) & !is.na(cG2)]
      for (y in c(wfirm, "l_firm_emp")) {
        oc  <- if (y == "l_firm_emp") "emp" else "wage"
        fes <- fes_firm(oc)
        cond <- D[, !is.na(get(y))]
        dm <- D[cond]; dp <- D[cond & D$year <= 2011]
        if (mode == "firm") {
          surv <- unique(as.character(dm$identificad[drop_singletons_idx(dm, fes)]))
          msg("  [check] A8 firm %s: %d firms, %d outside the firm-level sample",
              oc, length(surv), length(setdiff(surv, FSET[[oc]])))
        }
        r <- didrace(dm, dp, y, "cG1", "cG2", fes)
        A8[[length(A8) + 1L]] <- data.table(
          partition = p, col = "firm", p90 = mode, outcome = oc,
          b1 = r$b1, se1 = r$se1, b2 = r$b2, se2 = r$se2,
          bp1 = r$bp1, sp1 = r$sp1, bp2 = r$bp2, sp2 = r$sp2,
          peq = r$peq, n = r$n, firms = r$firms)
      }
    }

    # ---- 4g: group-outcome horse race (computed, not printed by any table) ---
    GCW <- merge(GP, CW, by = "identificad", all.x = TRUE, sort = FALSE)
    GCW[, `:=`(cG1 = c1_raw / P90, cG2 = c2_raw / P90)]
    gi <- 1L
    for (gl in c(g1, g2)) {
      for (y in c(wlayer, "l_layer_emp")) {
        oc  <- if (y == "l_layer_emp") "emp" else "wage"
        fes <- fes_layer(oc, "overall")
        cond <- GCW[, s_base == 1 & layer_id == gl & !is.na(get(y)) &
                      !is.na(cG1) & !is.na(cG2)]
        dm <- GCW[cond]; dp <- GCW[cond & GCW$year <= 2011]
        r <- didrace(dm, dp, y, "cG1", "cG2", fes)
        A8[[length(A8) + 1L]] <- data.table(
          partition = p, col = paste0("g", gi), p90 = "firm", outcome = oc,
          b1 = r$b1, se1 = r$se1, b2 = r$b2, se2 = r$se2,
          bp1 = r$bp1, sp1 = r$sp1, bp2 = r$bp2, sp2 = r$sp2,
          peq = r$peq, n = r$n, firms = r$firms)
      }
      gi <- gi + 1L
    }
    msg("done: %s", p)
  }

  # -- Section 5: write CSVs ----------------------------------------------------
  dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
  w <- function(l, f) {
    d <- rbindlist(l)
    fwrite(d, file.path(outdir, f))
    msg("wrote %s (%d rows)", f, nrow(d))
    d
  }
  list(a7  = w(A7,  sprintf("a7%s.csv", sfx)),
       a8  = w(A8,  sprintf("a8%s.csv", sfx)),
       a6g = w(A6G, sprintf("a6_group%s.csv", sfx)),
       a6p = w(A6P, sprintf("a6_partition%s.csv", sfx)))
}
