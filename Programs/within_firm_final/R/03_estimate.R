# ------------------------------------------------------------------------------
# 04_estimate.R -- reghdfe-equivalent estimation in fixest.
#
# WHY THIS FILE EXISTS
# --------------------
# fixest and reghdfe agree on the point estimate but not on the standard error,
# because they count degrees of freedom differently. reghdfe scales the cluster
# sandwich by
#
#       q = (N - 1) / (N - K) * G / (G - 1),      K = p + 1 + df_a
#
# where p is the number of estimated slopes, the 1 is the constant, and df_a is
# the absorbed degrees of freedom NET of redundancy as reghdfe accounts for it:
#
#   * a fixed-effect dimension nested within the cluster variable contributes 0
#     (reghdfe flags these with "*"). Here that covers identificad,
#     firm_layer_id and firm_id#year.
#   * of the remaining dimensions -- all of which are of the form X # year --
#     the first contributes (levels - 1), i.e. it gives up only the constant,
#     and every later one contributes (levels - n_years), because the year
#     margin is already spanned by the first.
#
# Both rules were read off the "Absorbed degrees of freedom" tables that reghdfe
# printed into Luis's run logs and were verified to reproduce Stata's standard
# error to 2e-8 relative on the headline A7 regression.
# ------------------------------------------------------------------------------

#' Is fixed-effect dimension `fe` nested within `cluster`?
#' True when every level of the FE maps to exactly one cluster value.
fe_is_nested <- function(dt, fe_key, cluster_key) {
  length(unique(paste(fe_key, cluster_key, sep = "\r"))) == length(unique(fe_key))
}

#' Build the integer key for one fixed-effect dimension.
fe_key <- function(dt, v) {
  if (length(v) == 1L) as.character(dt[[v]])
  else do.call(paste, c(lapply(v, function(z) as.character(dt[[z]])), sep = "\r"))
}

#' Connected components of the bipartite graph between two fixed-effect keys.
#'
#' This is the object reghdfe calls a "mobility group". Levels of the first key
#' form one side, levels of the second the other, and an observation is an edge.
.fe_components <- function(ka, kb) {
  a <- as.integer(factor(ka))
  b <- as.integer(factor(kb))
  as.integer(igraph::components(
    igraph::make_graph(rbind(a, b + max(a)), directed = FALSE))$no)
}

#' reghdfe's absorbed degrees of freedom for this sample and FE set.
#'
#' Two rules, both taken from reghdfe and both verified against the "Absorbed
#' degrees of freedom" tables in the original Stata logs:
#'
#'   * a dimension nested within the cluster variable contributes 0 (reghdfe
#'     flags these with "*"). Here that covers identificad, firm_layer_id and
#'     establishment x year.
#'   * every other dimension contributes (levels - redundancy). The first
#'     contributes levels - 1, giving up only the constant. For each later one,
#'     the redundancy is the number of connected components of the bipartite
#'     graph it forms with an earlier dimension, maximised over earlier
#'     dimensions.
#'
#' The components rule matters. A simpler "redundancy = number of years" rule is
#' right for plain X # year terms but wrong once a dimension carries the group
#' as well, where the graph splits by (group, year) and the redundancy doubles.
#' It also reproduces the redundancy of 16 that reghdfe reports for
#' microregion # year in the original specification, which the simpler rule
#' cannot.
#'
#' Checked: the firm-level A7 regression gives dfa = 3803, matching the Stata
#' log (31 + 24 + 24 + 1544 + 88 + 2092), with redundancies 1, 8, 8, 8, 8, 8.
compute_dfa <- function(dt, fes, cluster = "identificad") {
  ck <- as.character(dt[[cluster]])
  keys <- list()
  dfa <- 0L
  for (v in fes) {
    k <- fe_key(dt, v)
    if (fe_is_nested(dt, k, ck)) next          # "*" rows: contribute nothing
    lev <- length(unique(k))
    red <- if (!length(keys)) 1L
           else max(vapply(keys, function(h) .fe_components(h, k), integer(1)))
    dfa <- dfa + lev - red
    keys[[length(keys) + 1L]] <- k
  }
  dfa
}

#' Format a FE list as the right-hand side of a fixest formula.
fe_rhs <- function(fes) {
  paste(vapply(fes, function(v) paste(v, collapse = "^"), character(1)),
        collapse = " + ")
}

#' Fit one absorbed regression with reghdfe semantics.
#'
#' @param dat   estimation sample (already subset by the caller's `if` condition)
#' @param y     outcome name
#' @param xs    named list: coefficient name -> numeric vector of the regressor
#' @param fes   list of FE dimensions (character vectors)
#' @return list(b, V, n, G, dfa, keep) with V the reghdfe-scaled cluster VCOV
reghdfe_fit <- function(dat, y, xs, fes, cluster = "identificad") {

  dat <- copy(dat)
  for (nm in names(xs)) set(dat, j = nm, value = xs[[nm]])

  # reghdfe drops singletons iteratively across all FE dimensions, before
  # anything else. This changes N, G and therefore the small-sample correction.
  keep <- drop_singletons_idx(dat, fes)
  dat <- dat[keep]

  fml <- as.formula(sprintf("%s ~ %s | %s", y,
                            paste(names(xs), collapse = " + "), fe_rhs(fes)))
  m <- feols(fml, data = dat, fixef.rm = "none", notes = FALSE,
             warn = FALSE, cluster = as.formula(paste0("~", cluster)))

  N <- m$nobs
  G <- length(unique(as.character(dat[[cluster]])))
  dfa <- compute_dfa(dat, fes, cluster)
  K <- length(xs) + 1L + dfa                      # slopes + constant + absorbed

  # raw cluster sandwich, then reghdfe's correction
  V_raw <- vcov(m, cluster = as.formula(paste0("~", cluster)),
                ssc = ssc(adj = FALSE, cluster.adj = FALSE, fixef.K = "none"))
  q <- (N - 1) / (N - K) * G / (G - 1)
  V <- q * V_raw

  list(b = coef(m), V = V, n = N, G = G, dfa = dfa, K = K, dat = dat)
}

#' Port of the do-file's `didcol`: single-regressor DiD plus pre-treatment placebo.
#'
#' @param gxf character vector naming the group x firm identifier, or NULL
#' @param extra optional character vector of column names to include as ADDITIONAL
#'   right-hand-side regressors (not fixed effects). Used for firm connectivity
#'   interacted with year, which is a continuous-by-year term rather than a
#'   factor. They are estimated but never reported; only `did` is extracted.
didcol <- function(dmain, dpre, y, conn, fes, gxf = NULL, extra = NULL) {
  xm <- setNames(list(dmain[[conn]] * dmain$treat_year), "did")
  xp <- setNames(list(dpre[[conn]]  * dpre$placebo_year), "did")
  for (v in extra) {
    # a control that is constant in the estimation window carries no
    # information and would be collinear with the fixed effects
    if (length(unique(dmain[[v]])) > 1) xm[[v]] <- dmain[[v]]
    if (length(unique(dpre[[v]]))  > 1) xp[[v]] <- dpre[[v]]
  }
  fm <- reghdfe_fit(dmain, y, xm, fes)
  fp <- reghdfe_fit(dpre,  y, xp, fes)
  gxfn <- if (is.null(gxf)) NA_integer_ else length(unique(fe_key(fm$dat, gxf)))
  list(b     = unname(fm$b[["did"]]),
       se    = unname(sqrt(fm$V["did", "did"])),
       bpre  = unname(fp$b[["did"]]),
       sepre = unname(sqrt(fp$V["did", "did"])),
       n = fm$n, firms = fm$G, gxf = gxfn)
}

#' Port of the do-file's `didrace`: two regressors jointly, with an equality
#' test using the normal approximation 2 * Phi(-|b1 - b2| / se(diff)).
didrace <- function(dmain, dpre, y, r1, r2, fes) {
  xm <- list(dmain[[r1]] * dmain$treat_year, dmain[[r2]] * dmain$treat_year)
  xp <- list(dpre[[r1]]  * dpre$placebo_year, dpre[[r2]]  * dpre$placebo_year)
  names(xm) <- names(xp) <- c("d1", "d2")

  fm <- reghdfe_fit(dmain, y, xm, fes)
  fp <- reghdfe_fit(dpre,  y, xp, fes)

  diff   <- unname(fm$b[["d1"]] - fm$b[["d2"]])
  v_diff <- fm$V["d1", "d1"] + fm$V["d2", "d2"] - 2 * fm$V["d1", "d2"]
  peq    <- 2 * pnorm(-abs(diff / sqrt(v_diff)))

  list(b1 = unname(fm$b[["d1"]]), se1 = unname(sqrt(fm$V["d1", "d1"])),
       b2 = unname(fm$b[["d2"]]), se2 = unname(sqrt(fm$V["d2", "d2"])),
       bp1 = unname(fp$b[["d1"]]), sp1 = unname(sqrt(fp$V["d1", "d1"])),
       bp2 = unname(fp$b[["d2"]]), sp2 = unname(sqrt(fp$V["d2", "d2"])),
       peq = peq, n = fm$n, firms = fm$G)
}
