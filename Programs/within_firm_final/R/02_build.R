# ------------------------------------------------------------------------------
# 03_build.R -- panel construction, porting sections 1, 1b, 1c and 4a of
#               Luis_og/scripts/05a_within_firm_estimates.do
# ------------------------------------------------------------------------------

#' Sections 1 / 1b / 1c: firm-level panel, current-connectivity overlay,
#' P90 scale and the normalized firm regressor.
#'
#' @param wfirm name of the firm wage variable for this pass
#'              ("lr_remdezr_w" monthly, "lr_remdezr_h_w" hourly)
# Columns exercise 5 touches, matching the do-file's keep-list plus the hourly
# wage variable.
FIRM_VARS <- c("identificad", "year", "lr_remdezr_w", "lr_remdezr_h_w",
               "l_firm_emp", "treat_ultra", "in_balanced_panel",
               "lagos_sample_avg", "industry1", "mode_base_month",
               "microregion", "totaltreat_pw_n", "firm_emp")

build_firm_panel <- function(wfirm) {

  tf <- read_csv_input("totalflows_wide_2007_2011", colClasses = list(character = "identificad"))
  d  <- read_data("lagos_sample_sep24_pct_unionexp_ext_df2", FIRM_VARS)

  keepv <- c("identificad", "year", wfirm, "l_firm_emp", "treat_ultra",
             "in_balanced_panel", "lagos_sample_avg", "industry1",
             "mode_base_month", "microregion", "totaltreat_pw_n", "firm_emp")
  d <- d[, ..keepv]
  d <- d[lagos_sample_avg == 1 & year >= 2009]

  # -- Section 1b: current-connectivity overlay --------------------------------
  setnames(d, "totaltreat_pw_n", "totaltreat_pw_n_legacy")
  ov <- read_data("currentconn_overlay_totaltreat")[, .(identificad, year, totaltreat_pw_n)]
  n_before <- nrow(d)
  d <- merge(d, ov, by = c("identificad", "year"), all.x = TRUE, sort = FALSE)
  stopifnot(nrow(d) == n_before)                       # merge 1:1
  if (anyNA(d$totaltreat_pw_n) && d[, sum(is.na(totaltreat_pw_n))] > 0) {
    # the do-file hard-errors if any firm-year is unmatched by the overlay
    stop(sprintf("%d firm-year rows not matched by the connectivity overlay.",
                 d[, sum(is.na(totaltreat_pw_n))]))
  }
  msg("[overlay] totaltreat_pw_n replaced by the current recomputable measure (%d rows)",
      nrow(d))

  # -- pre-treatment total flows -----------------------------------------------
  # Stata's `merge m:1` errors if the using side is not uniquely keyed; R's
  # merge would silently fan out. Guard explicitly.
  n_before <- nrow(d)
  d <- merge(d, tf, by = "identificad", all.x = TRUE, sort = FALSE)
  stopifnot(nrow(d) == n_before)
  ypairs <- c("totalflows_pw_07_08", "totalflows_pw_08_09",
              "totalflows_pw_09_10", "totalflows_pw_10_11")
  M <- as.matrix(d[, ..ypairs])
  cnt <- rowSums(!is.na(M))
  d[, tf_pre := ifelse(cnt > 0, rowSums(M, na.rm = TRUE) / cnt, NA_real_)]

  d[, treat_year   := as.integer(year >= 2012)]
  d[, placebo_year := as.integer(year <  2011)]

  d[, industry1_num       := industry1]
  d[, mode_base_month_num := mode_base_month]
  d[, microregion_num     := microregion]

  # -- firm pre-treatment quartile bins ----------------------------------------
  mkprebin(d, "wage_pre4_firm",     wfirm,        "identificad", "mean")
  mkprebin(d, "l_firm_emp_pre4",    "l_firm_emp", "identificad", "mean")
  mkprebin(d, "totalflows_pw_pre4", "tf_pre",     "identificad", "raw")

  # -- Section 1c: P90 scale ----------------------------------------------------
  p90 <- stata_pctile(
    d[treat_ultra == 0 & in_balanced_panel == 1 & year == 2009 &
        !is.na(totaltreat_pw_n), totaltreat_pw_n], 90)
  msg("P90_FIRM (current firm measure) = %9.5f", p90)

  d[, totaltreat_pw_norm := totaltreat_pw_n / p90]

  list(dt = d, p90 = p90)
}


#' Section 4a: group-level ("layer") panel for one partition.
#'
#' @param p     partition: "edu2", "gender" or "ten2"
#' @param wlayer group wage variable for this pass
#' @param p90   P90_FIRM from build_firm_panel (group connectivity is scaled by
#'              the FIRM p90, not the group's own)
#' @param tie tie-break for the group-level quartile bins, "up" (`>=`, the
#'   literal do-file transcription) or "down" (`>`). See SPEC.md section 4.
#'   The FIRM-level bins always use "up". See SPEC.md section 4.
build_layer_panel <- function(p, wlayer, p90, tie = "up") {

  d <- read_data(sprintf("firm_layer_outcomes_%s", p))
  d <- d[year >= 2009]

  cn <- read_data(sprintf("firm_layer_connectivity_%s", p))[
    , .(identificad, layer_id, layer_treat_pw_n, totalflows_layer_pw_n)]
  n_before <- nrow(d)
  d <- merge(d, cn, by = c("identificad", "layer_id"), all.x = TRUE, sort = FALSE)
  stopifnot(nrow(d) == n_before)                       # Stata m:1 guard

  fm <- read_data("lagos_sample_sep24_pct_unionexp_ext_df2", FIRM_VARS)[
    , .(identificad, year, treat_ultra, in_balanced_panel, lagos_sample_avg,
        firm_emp, industry1, mode_base_month, microregion)]
  d <- merge(d, fm, by = c("identificad", "year"), all.x = TRUE, sort = FALSE)
  stopifnot(nrow(d) == n_before)                       # Stata m:1 guard
  d <- d[lagos_sample_avg == 1]

  d[, treat_year   := as.integer(year >= 2012)]
  d[, placebo_year := as.integer(year <  2011)]
  d[, s_base := as.integer(lagos_sample_avg == 1 & treat_ultra == 0 &
                             in_balanced_panel == 1)]

  d[, industry1_num       := industry1]
  d[, mode_base_month_num := mode_base_month]
  d[, microregion_num     := microregion]
  d[, firm_id       := identificad]
  d[, firm_layer_id := paste(identificad, layer_id, sep = "\r")]

  mkprebin(d, "wage_pre4_layer",          wlayer,
           c("identificad", "layer_id"), "mean", tie)
  mkprebin(d, "l_layer_emp_pre4",         "l_layer_emp",
           c("identificad", "layer_id"), "mean", tie)
  mkprebin(d, "layer_totalflows_pw_pre4", "totalflows_layer_pw_n",
           c("identificad", "layer_id"), "raw",  tie)

  d[, conn := layer_treat_pw_n / p90]
  d
}
