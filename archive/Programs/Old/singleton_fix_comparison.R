# =============================================================================
# singleton_fix_comparison.R
#
# INVESTIGATION OF R vs STATA COEFFICIENT GAP
# ============================================
# Outcome: lr_remdezr_w | Specs: baseline + 4 flow-bin robustness specs
# Gap: R gives b≈0.0054; Stata gives b≈0.0050 for tf_07_11
#
# HYPOTHESIS 1 (SINGLETON): N gap (33,359 vs 32,495) explained by fixef.rm
#   Status: CONFIRMED (fixef.rm="singleton" reduces N to 32,498; Stata=32,495)
#
# HYPOTHESIS 2 (FORMULA): b gap from ## vs : operator
#   Stata uses ##:  y ~ conn + treat_year + conn#treat_year | FEs
#   R uses :    :  y ~ treat_year:conn | FEs
#   Hypothesis: treat_year main not absorbed, omitting it biases b upward
#   Status: RULED OUT
#   Evidence: Both R (fixest collinearity note) and Stata (reghdfe collinearity
#   note, "(omitted)") drop treat_year and totaltreat_pw_norm main effects —
#   these ARE spanned by the group×year FE structure. Both run interaction-only.
#   Adding treat_year main in R leaves b unchanged (treat_year is dropped).
#
# HYPOTHESIS 3 (BINNING): b gap from ntile (R) vs cut/group (Stata)
#   R   uses dplyr::ntile(var, 4) → strictly equal-count groups
#   Stata uses egen cut(var), group(4) → percentile-cutpoint groups
#   Both methods agree when data is continuous; diverge when there are ties
#   at bin boundaries (count data like total flows is highly susceptible).
#   Status: TESTING (this script)
#
# Reference values (from runs/logs):
#   Stata reghdfe: tf_07_11  b=0.005000 N=32,495
#                  tf_09_11  b=0.005191 N=32,495
#                  tfpw_07_11 b=0.005070 N=32,495
#                  tfpw_09_11 b=0.004904 N=32,495
#   R orig (none): tf_07_11  b=0.0054   N=33,359  (coauthor baseline)
# =============================================================================

library(haven)
library(dplyr)
library(tidyr)
library(fixest)

# ---- Paths ------------------------------------------------------------------
main      <- "/Users/luisg/Library/CloudStorage/OneDrive-NorthwesternUniversity/4 - PhD/02_Research/Org_Econ BR/UnionSpillovers/Replication-Mar-2"
rais_firm <- file.path(main, "UnionSpill/Data/CBA_RAIS_firm_level")
rais_aux  <- file.path(main, "UnionSpill/Data/RAIS_aux")

# ---- Load data --------------------------------------------------------------
cat("Loading main .dta...\n")
df <- read_dta(file.path(rais_firm,
                         "lagos_sample_sep24_pct_unionexp_ext_df2.dta"))

df$identificad <- sprintf("%014.0f", as.numeric(df$identificad))

cat("Loading totalflows_wide_2007_2011.csv...\n")
flows <- read.csv(file.path(rais_aux, "totalflows_wide_2007_2011.csv"))
flows$identificad <- sprintf("%014.0f", flows$identificad)

flows <- flows %>%
  mutate(
    totalflows_pre_07_11    = rowMeans(cbind(totalflows_07_08, totalflows_08_09,
                                             totalflows_09_10, totalflows_10_11),
                                       na.rm = TRUE),
    totalflows_pre_09_11    = rowMeans(cbind(totalflows_09_10, totalflows_10_11),
                                       na.rm = TRUE),
    totalflows_pw_pre_07_11 = rowMeans(cbind(totalflows_pw_07_08, totalflows_pw_08_09,
                                             totalflows_pw_09_10, totalflows_pw_10_11),
                                       na.rm = TRUE),
    totalflows_pw_pre_09_11 = rowMeans(cbind(totalflows_pw_09_10, totalflows_pw_10_11),
                                       na.rm = TRUE)
  ) %>%
  select(identificad,
         totalflows_pre_07_11, totalflows_pre_09_11,
         totalflows_pw_pre_07_11, totalflows_pw_pre_09_11)

df <- df %>% left_join(flows, by = "identificad")

df <- df %>% filter(year >= 2009, lagos_sample_avg == 1)
cat("After filter (year>=2009, lagos_sample_avg==1):", nrow(df), "obs\n")

# Treatment timing
df <- df %>% mutate(treat_year = as.integer(year >= 2012))

# Normalize connectivity to 90th pct (spillover sample, year==2009)
p90_conn <- df %>%
  filter(treat_ultra == 0, in_balanced_panel == 1, year == 2009) %>%
  summarise(p90 = quantile(totaltreat_pw_n, 0.90, na.rm = TRUE)) %>%
  pull(p90)
cat(sprintf("p90_conn = %.6f\n", p90_conn))
df <- df %>% mutate(totaltreat_pw_norm = totaltreat_pw_n / p90_conn)

# Pre-treatment averages
for (v in c("lr_remdezr_w", "l_firm_emp")) {
  pre_name <- paste0(v, "_pre")
  df <- df %>%
    group_by(identificad) %>%
    mutate(!!pre_name := mean(.data[[v]][year %in% 2009:2011], na.rm = TRUE)) %>%
    ungroup()
}

# ---- Binning functions ------------------------------------------------------

# Method A (ORIGINAL R — coauthor): ntile creates strictly equal-count groups.
# Bins: 0,1,2,3 from ntile(var,4)-1. Firms not in 2009 cross-section get 0.
make_bins_ntile <- function(data, var, g = 4) {
  bin_name <- paste0(var, g)
  ref <- data %>%
    filter(year == 2009, in_balanced_panel == 1) %>%
    transmute(identificad,
              !!bin_name := as.integer(ntile(.data[[var]], g) - 1L))
  data %>%
    left_join(ref, by = "identificad", suffix = c("", ".new")) %>%
    { nm <- paste0(bin_name, ".new")
      if (nm %in% names(.))
        mutate(., !!bin_name := coalesce(.data[[bin_name]], .data[[nm]])) %>%
          select(-all_of(nm))
      else . } %>%
    mutate(!!bin_name := replace_na(.data[[bin_name]], 0L))
}

# Method B (STATA-STYLE): cut() with percentile breakpoints.
# Stata's cut(var, group(4)): assigns obs to group j if cut[j-1] <= x < cut[j]
# (right-open [a,b) intervals). Stata's pctile default ≈ R quantile type=6.
# Using right=FALSE in R's cut() mirrors Stata's right-open assignment so that
# ties at cut points fall into the LOWER group, matching Stata behavior.
make_bins_cut <- function(data, var, g = 4) {
  bin_name <- paste0(var, g)
  ref_vals <- data %>%
    filter(year == 2009, in_balanced_panel == 1) %>%
    pull(!!sym(var))
  ref_vals <- ref_vals[!is.na(ref_vals)]

  # type=6 (Weibull/Hazen) is closest to Stata's pctile default
  probs  <- seq(0, 1, length.out = g + 1)
  breaks <- quantile(ref_vals, probs = probs, type = 6)
  # Open extreme endpoints so all obs are captured
  breaks[1]           <- -Inf
  breaks[length(breaks)] <- Inf
  # Drop duplicate breaks (count data can have identical percentiles)
  breaks <- unique(breaks)

  ref <- data %>%
    filter(year == 2009, in_balanced_panel == 1) %>%
    transmute(
      identificad,
      !!bin_name := {
        vals <- .data[[var]]
        # right=FALSE: [a,b) — ties at right boundary fall to lower group
        as.integer(cut(vals, breaks = breaks,
                       include.lowest = TRUE, right = FALSE,
                       labels = FALSE)) - 1L
      }
    )
  data %>%
    left_join(ref, by = "identificad", suffix = c("", ".new")) %>%
    { nm <- paste0(bin_name, ".new")
      if (nm %in% names(.))
        mutate(., !!bin_name := coalesce(.data[[bin_name]], .data[[nm]])) %>%
          select(-all_of(nm))
      else . } %>%
    mutate(!!bin_name := replace_na(.data[[bin_name]], 0L))
}

# ---- Build datasets with each binning method --------------------------------
df_ntile <- df
df_cut   <- df

bins_vars <- c("lr_remdezr_w_pre", "l_firm_emp_pre",
               "totalflows_pre_07_11",    "totalflows_pre_09_11",
               "totalflows_pw_pre_07_11", "totalflows_pw_pre_09_11")

for (v in bins_vars) {
  df_ntile <- make_bins_ntile(df_ntile, v)
  df_cut   <- make_bins_cut(df_cut,   v)
}

# Check bin agreement
cat("\n--- Bin agreement (ntile vs cut) across binned vars ---\n")
cat(sprintf("  %-32s  %s\n", "Variable", "% agreement (2009 cross-section)"))
spill_2009_ntile <- df_ntile %>% filter(treat_ultra == 0, in_balanced_panel == 1, year == 2009)
spill_2009_cut   <- df_cut   %>% filter(treat_ultra == 0, in_balanced_panel == 1, year == 2009)
for (v in bins_vars) {
  bn <- paste0(v, "4")
  agree <- mean(spill_2009_ntile[[bn]] == spill_2009_cut[[bn]], na.rm = TRUE)
  n_diff <- sum(spill_2009_ntile[[bn]] != spill_2009_cut[[bn]], na.rm = TRUE)
  cat(sprintf("  %-32s  %.1f%%  (%d firms differ)\n", bn, 100*agree, n_diff))
}

# Spillover samples
spill_ntile <- df_ntile %>% filter(treat_ultra == 0, in_balanced_panel == 1)
spill_cut   <- df_cut   %>% filter(treat_ultra == 0, in_balanced_panel == 1)
cat(sprintf("\nSpillover N: ntile=%d  cut=%d\n", nrow(spill_ntile), nrow(spill_cut)))

# ---- Specifications ---------------------------------------------------------
base_fe_ntile <- paste(
  "identificad + industry1^year + mode_base_month^year + microregion^year",
  "+ lr_remdezr_w_pre4^year + l_firm_emp_pre4^year"
)
base_fe_cut <- base_fe_ntile  # same variable names, different values

spec_list <- list(
  baseline   = "",
  tf_07_11   = "totalflows_pre_07_114^year",
  tf_09_11   = "totalflows_pre_09_114^year",
  tfpw_07_11 = "totalflows_pw_pre_07_114^year",
  tfpw_09_11 = "totalflows_pw_pre_09_114^year"
)

build_fe <- function(base_fe, extra) {
  if (nchar(trimws(extra)) == 0) base_fe
  else paste(base_fe, "+", extra)
}

# ---- Reference values (hardcoded from runs) ---------------------------------
# R-orig (no fixef.rm, ntile bins): tf_07_11 b=0.0054 N=33,359
ref_R_b <- c(baseline = NA_real_,
             tf_07_11 = 0.0054, tf_09_11 = 0.0056,
             tfpw_07_11 = 0.0050, tfpw_09_11 = 0.0049)
ref_R_N <- c(baseline = NA_real_,
             tf_07_11 = 33359, tf_09_11 = 33359,
             tfpw_07_11 = 33359, tfpw_09_11 = 33359)

# Stata reghdfe (cut/group bins, singletons removed):
# exact values from singleton_check_20_Feb_2026_012645.log
ref_stata_b <- c(baseline = NA_real_,
                 tf_07_11 = 0.005000, tf_09_11 = 0.005191,
                 tfpw_07_11 = 0.005070, tfpw_09_11 = 0.004904)
ref_stata_N <- 32495

extract_b <- function(m) {
  cn <- grep("totaltreat_pw_norm", names(coef(m)), value = TRUE)[1]
  if (is.na(cn)) return(NA_real_)
  coef(m)[[cn]]
}

# ---- Run regressions --------------------------------------------------------
cat("\n", strrep("-", 70), "\n", sep = "")
cat("Running regressions (ntile vs cut bins, fixef.rm=none vs singleton)...\n")
cat(strrep("-", 70), "\n\n")

formula_rhs <- "lr_remdezr_w ~ treat_year:totaltreat_pw_norm | "

rows <- vector("list", length(spec_list))
for (i in seq_along(spec_list)) {
  sname <- names(spec_list)[i]
  extra <- spec_list[[sname]]

  fe_ntile <- build_fe(base_fe_ntile, extra)
  fe_cut   <- build_fe(base_fe_cut,   extra)

  fmla_ntile <- as.formula(paste0(formula_rhs, fe_ntile))
  fmla_cut   <- as.formula(paste0(formula_rhs, fe_cut))

  cat(sprintf("  %-12s ", sname))

  # ntile bins, no fixef.rm (coauthor original)
  m_ntile_none <- feols(fmla_ntile, data = spill_ntile, cluster = ~identificad,
                        fixef.rm = "none", warn = FALSE)
  # ntile bins, singleton removal (matches Stata's N)
  m_ntile_fix  <- feols(fmla_ntile, data = spill_ntile, cluster = ~identificad,
                        fixef.rm = "singleton", warn = FALSE)
  # cut bins, no fixef.rm
  m_cut_none   <- feols(fmla_cut,   data = spill_cut,   cluster = ~identificad,
                        fixef.rm = "none", warn = FALSE)
  # cut bins, singleton removal (EXPECTED: closest to Stata)
  m_cut_fix    <- feols(fmla_cut,   data = spill_cut,   cluster = ~identificad,
                        fixef.rm = "singleton", warn = FALSE)

  cat(sprintf("ntile/none N=%6d  cut/fix N=%6d  done.\n",
              m_ntile_none$nobs, m_cut_fix$nobs))

  rows[[i]] <- data.frame(
    spec           = sname,
    b_ntile_none   = extract_b(m_ntile_none),
    N_ntile_none   = m_ntile_none$nobs,
    b_ntile_fix    = extract_b(m_ntile_fix),
    N_ntile_fix    = m_ntile_fix$nobs,
    b_cut_none     = extract_b(m_cut_none),
    N_cut_none     = m_cut_none$nobs,
    b_cut_fix      = extract_b(m_cut_fix),
    N_cut_fix      = m_cut_fix$nobs,
    b_R_ref        = ref_R_b[[sname]],
    N_R_ref        = ref_R_N[[sname]],
    b_stata        = ref_stata_b[[sname]],
    N_stata        = ref_stata_N,
    stringsAsFactors = FALSE
  )
}
res <- do.call(rbind, rows)

# ---- Print tables -----------------------------------------------------------
fmt_val <- function(b, N) {
  if (is.na(b) || is.na(N)) return(sprintf("%-22s", "n/a"))
  sprintf("b=%8.5f  N=%6d", b, as.integer(N))
}

cat("\n")
cat(strrep("=", 150), "\n")
cat("SECTION 1 — SINGLETON EFFECT (ntile bins only)\n")
cat("  R-ntile/none = coauthor original (N=33,359)\n")
cat("  R-ntile/fix  = singleton removal (N~32,498)\n")
cat("  Stata         = reghdfe (N=32,495)\n")
cat(strrep("=", 150), "\n")
cat(sprintf("%-12s | %-22s | %-22s | %-22s\n",
            "Spec", "R-ntile/none", "R-ntile/fix", "Stata"))
cat(strrep("-", 82), "\n")
for (i in seq_len(nrow(res))) {
  r <- res[i, ]
  cat(sprintf("%-12s | %-22s | %-22s | %-22s\n",
              r$spec,
              fmt_val(r$b_ntile_none, r$N_ntile_none),
              fmt_val(r$b_ntile_fix,  r$N_ntile_fix),
              fmt_val(r$b_stata,      r$N_stata)))
}
cat(strrep("=", 150), "\n")

cat("\n")
cat(strrep("=", 150), "\n")
cat("SECTION 2 — BINNING EFFECT (singleton-removed regressions)\n")
cat("  R-ntile/fix = ntile bins + singleton removal [coauthor formula]\n")
cat("  R-cut/fix   = cut bins + singleton removal   [Stata-style bins; EXPECTED ~0.0050]\n")
cat("  Stata        = reghdfe cut/group bins\n")
cat(strrep("=", 150), "\n")
cat(sprintf("%-12s | %-22s | %-22s | %-22s | %-14s\n",
            "Spec", "R-ntile/fix", "R-cut/fix", "Stata",
            "cut-Stata gap"))
cat(strrep("-", 95), "\n")
for (i in seq_len(nrow(res))) {
  r <- res[i, ]
  gap <- if (!is.na(r$b_cut_fix) && !is.na(r$b_stata))
           sprintf("%+.5f", r$b_cut_fix - r$b_stata)
         else "n/a"
  cat(sprintf("%-12s | %-22s | %-22s | %-22s | %s\n",
              r$spec,
              fmt_val(r$b_ntile_fix, r$N_ntile_fix),
              fmt_val(r$b_cut_fix,   r$N_cut_fix),
              fmt_val(r$b_stata,     r$N_stata),
              gap))
}
cat(strrep("=", 150), "\n")

cat("\n")
cat(strrep("=", 150), "\n")
cat("SECTION 3 — FULL COMPARISON: original R vs Stata vs R-cut/fix\n")
cat(strrep("=", 150), "\n")
cat(sprintf("%-12s | %-22s | %-22s | %-22s | %-22s\n",
            "Spec", "R-orig(coauthor)", "R-ntile/fix", "R-cut/fix", "Stata"))
cat(strrep("-", 96), "\n")
for (i in seq_len(nrow(res))) {
  r <- res[i, ]
  cat(sprintf("%-12s | %-22s | %-22s | %-22s | %-22s\n",
              r$spec,
              fmt_val(r$b_R_ref,    r$N_R_ref),
              fmt_val(r$b_ntile_fix, r$N_ntile_fix),
              fmt_val(r$b_cut_fix,  r$N_cut_fix),
              fmt_val(r$b_stata,    r$N_stata)))
}
cat(strrep("=", 150), "\n")

# ---- Decomposition for tf_07_11 ---------------------------------------------
cat("\n--- Decomposition of gaps (tf_07_11) ---\n")
row_tf <- res[res$spec == "tf_07_11", ]
delta_singleton <- row_tf$b_ntile_none - row_tf$b_ntile_fix
delta_binning   <- row_tf$b_ntile_fix  - row_tf$b_cut_fix
delta_residual  <- row_tf$b_cut_fix    - row_tf$b_stata
delta_total     <- row_tf$b_ntile_none - row_tf$b_stata

cat(sprintf("  R-orig/none    b: %.5f  N: %d\n", row_tf$b_ntile_none, row_tf$N_ntile_none))
cat(sprintf("  R-ntile/fix    b: %.5f  N: %d\n", row_tf$b_ntile_fix,  row_tf$N_ntile_fix))
cat(sprintf("  R-cut/fix      b: %.5f  N: %d\n", row_tf$b_cut_fix,    row_tf$N_cut_fix))
cat(sprintf("  Stata          b: %.5f  N: %d\n", row_tf$b_stata,      row_tf$N_stata))
cat(sprintf("\n  Singleton effect (ntile/none - ntile/fix):  %+.5f\n", delta_singleton))
cat(sprintf("  Binning effect  (ntile/fix  - cut/fix):    %+.5f\n", delta_binning))
cat(sprintf("  Residual gap    (cut/fix    - Stata):       %+.5f\n", delta_residual))
cat(sprintf("  Total R-Stata   (orig/none  - Stata):       %+.5f\n", delta_total))

cat("\n--- Collinearity note (from both R and Stata) ---\n")
cat("  R (fixest): 'treat_year has been removed because of collinearity'\n")
cat("  Stata (reghdfe): 'note: 1bn.treat_year is probably collinear with the\n")
cat("    fixed effects (all partialled-out values are close to zero)'\n")
cat("    1.treat_year | 0 (omitted) ;  totaltreat_pw_norm | 0 (omitted)\n")
cat("  => FORMULA HYPOTHESIS RULED OUT: ## vs : makes no difference because\n")
cat("     treat_year is absorbed by the group×year FEs in both R and Stata.\n")
cat("  => REMAINING GAP: binning (ntile vs cut) is the primary candidate.\n")

cat("\nDone.\n")
