# ------------------------------------------------------------------------------
# 02_functions.R -- Stata-fidelity helpers for the port of
#                   Luis_og/scripts/05a_within_firm_estimates.do
#
# The three places where a naive R translation silently diverges from Stata are
# handled explicitly here:
#
#   1. stata_pctile()  -- Stata's _pctile is R's quantile(type = 2), NOT the
#                         R default (type 7). It drives every pre-treatment
#                         quartile bin and the P90 connectivity scale.
#   2. mkprebin()      -- reproduces the egen min()/mean() propagation of the
#                         do-file, including the "bin = 0 if missing" fallback.
#   3. didcol/didrace  -- reghdfe's cluster VCE small-sample correction, which
#                         is not fixest's default. See 03_vcov.R.
# ------------------------------------------------------------------------------

# --- 1. Stata percentiles ------------------------------------------------------

#' Stata's _pctile / summarize, detail percentile.
#'
#' Stata definition: with n non-missing sorted values and percentile p, let
#' i = n * p / 100. If i is an integer the result is (x[i] + x[i+1]) / 2,
#' otherwise it is x[ceiling(i)]. This is R's quantile(type = 2).
stata_pctile <- function(x, p) {
  x <- x[!is.na(x)]
  n <- length(x)
  if (n == 0L) return(rep(NA_real_, length(p)))
  x <- sort(x)
  vapply(p, function(pp) {
    i <- n * pp / 100
    # integrality test with a tolerance, because n*p/100 is floating point
    if (abs(i - round(i)) < 1e-9) {
      i <- round(i)
      if (i >= n) x[n] else (x[i] + x[i + 1L]) / 2
    } else {
      x[ceiling(i)]
    }
  }, numeric(1))
}

# --- 2. Pre-treatment quartile bins -------------------------------------------

#' Port of the do-file's `mkprebin` program.
#'
#' @param dt   data.table, modified by reference (adds column `out`)
#' @param out  name of the bin column to create
#' @param src  source variable
#' @param by   character vector of grouping variables (firm, or firm x layer)
#' @param mode "mean" -> pre value is the 2009-2011 within-group mean of `src`;
#'             anything else -> pre value is `src` as it stands
#'
#' Stata semantics reproduced exactly:
#'   - `egen mean(src) if inrange(year,2009,2011)` then `egen min(.)` by group
#'     makes the pre-period mean constant within group (min ignores missing).
#'   - cutpoints come from `_pctile` on year==2009 & in_balanced_panel==1 rows.
#'   - the bin is formed only on those same rows, then `egen min()` propagates
#'     it to every row of the group.
#'   - groups that never contribute a 2009 balanced-panel row get bin 0.
#' @param tie how to place units sitting EXACTLY on a cutpoint. "up" uses
#'   `>=`, which is the literal transcription of the do-file. "down" uses `>`.
#'   This is not cosmetic: `l_layer_emp` is the log of small integer headcounts,
#'   so its 2009-2011 group means pile up on identical doubles and 116-203
#'   firm-layers per partition sit exactly on a quartile cutpoint. Which side
#'   they fall on moves the group-level coefficients by 1-7 percent. Stata's
#'   answer depends on a 1-ulp disagreement about the cutpoint and is not
#'   consistent across cutpoints, so neither setting is "correct"; the pair
#'   brackets the fragility. See SPEC.md section 4.
mkprebin <- function(dt, out, src, by, mode = "mean", tie = "up") {
  if (identical(mode, "mean")) {
    dt[, `__preo` := {
      v <- get(src); v[!(year >= 2009 & year <= 2011)] <- NA_real_
      rep(if (all(is.na(v))) NA_real_ else mean(v, na.rm = TRUE), .N)
    }, by = by]
    dt[, `__pre` := `__preo`]
    dt[, `__preo` := NULL]
  } else {
    dt[, `__pre` := as.numeric(get(src))]
  }

  sel <- dt[, year == 2009 & !is.na(in_balanced_panel) & in_balanced_panel == 1 &
              !is.na(`__pre`)]
  qs <- stata_pctile(dt[["__pre"]][sel], c(25, 50, 75))

  dt[, `__bt` := NA_integer_]
  if (identical(tie, "down")) {
    dt[sel, `__bt` := as.integer((`__pre` > qs[1]) + (`__pre` > qs[2]) +
                                   (`__pre` > qs[3]))]
  } else {
    dt[sel, `__bt` := as.integer((`__pre` >= qs[1]) + (`__pre` >= qs[2]) +
                                   (`__pre` >= qs[3]))]
  }
  # egen min() by group: ignores missing, propagates to all rows
  dt[, (out) := {
    b <- `__bt`
    rep(if (all(is.na(b))) NA_integer_ else min(b, na.rm = TRUE), .N)
  }, by = by]
  dt[is.na(get(out)), (out) := 0L]
  dt[, c("__pre", "__bt") := NULL]
  invisible(qs)
}

# --- 3. Iterative singleton removal (reghdfe semantics) ------------------------

#' Drop singleton observations the way reghdfe does.
#'
#' reghdfe removes, iteratively and across ALL fixed-effect dimensions, every
#' observation that is alone in one of its fixed-effect cells, repeating until
#' no singletons remain anywhere. fixest's `fixef.rm = "singleton"` stops
#' earlier, which is why it keeps 9 more observations than reghdfe in the
#' headline A7 firm regression.
#'
#' Singletons are perfectly absorbed and so do not move the point estimate, but
#' they DO change N, the cluster count and hence the small-sample correction on
#' the standard error.
#'
#' @param dt  data.table (not modified)
#' @param fes list of character vectors; each element names the columns whose
#'            interaction defines one fixed-effect dimension
#' @return integer vector of row indices to keep
drop_singletons_idx <- function(dt, fes) {
  keep <- rep(TRUE, nrow(dt))
  # Precompute an integer key per FE dimension once; grouping on integers is
  # far cheaper than re-pasting strings on every sweep.
  keys <- lapply(fes, function(v) {
    if (length(v) == 1L) as.integer(factor(dt[[v]]))
    else as.integer(factor(do.call(paste, c(lapply(v, function(z) dt[[z]]), sep = "\r"))))
  })
  repeat {
    changed <- FALSE
    for (k in keys) {
      kk <- k[keep]
      tb <- tabulate(kk, nbins = max(k, na.rm = TRUE))
      bad <- tb == 1L
      if (any(bad)) {
        idx <- which(keep)[bad[kk]]
        keep[idx] <- FALSE
        changed <- TRUE
      }
    }
    if (!changed) break
  }
  which(keep)
}

# --- 4. Small utilities --------------------------------------------------------

#' Stata `egen tag(vars)`: 1 on the first row of each group, 0 elsewhere.
n_distinct_groups <- function(dt, vars) {
  uniqueN(dt, by = vars)
}

