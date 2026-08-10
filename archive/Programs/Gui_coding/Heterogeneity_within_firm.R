rm(list = ls())
library(dplyr)
library(tidyverse)
library(haven)
library(fixest)
library(arrow)

# ============================================================================
# UNION SPILLOVERS — WORKER CHARACTERISTIC OUTCOMES
#
# Firm-year outcomes from the worker panel:
#   Gender:    share_female, lw_male, lw_female, gender_gap
#   Race:      share_white, lw_white, lw_nonwhite, race_gap
#   Age:       mean_age, age_slope
#   Tenure:    mean_tenure, tenure_slope
#   Education: share_nohs, share_hs, share_collegeplus, share_hsplus,
#              lw_nohs, lw_hs, lw_collegeplus, lw_hsplus,
#              edprem_hs, edprem_collegeplus, edprem_hsplus
# ============================================================================

rais_firm <- "/Users/gui.neri/Library/CloudStorage/OneDrive-NorthwesternUniversity/Research Projects/Org_Econ BR/UnionSpillovers/Gui_coding/Luis_og_files"

# =============================================================================
# 1. CONSTRUCT FIRM-YEAR OUTCOMES FROM WORKER PANEL
# =============================================================================

worker <- read_parquet(file.path(rais_firm, "worker_panel_lagos.parquet")) %>%
  select(identificad, year, lr_remdezr, tempempr, age, genero, raca_cor, grinstrucao)

# --- Education categories ---
worker <- worker %>%
  mutate(
    white = as.integer(raca_cor == 2),
    female = as.integer(genero == 0),
    educ_nohs      = as.integer(grinstrucao %in% 1:6),
    educ_hs        = as.integer(grinstrucao %in% 7:8),
    educ_collegeplus = as.integer(grinstrucao %in% 9:11),
    educ_hsplus    = as.integer(grinstrucao %in% 7:11)
  )

# --- Main firm-year aggregation ---
cat("Computing firm-year outcomes from worker panel...\n")

firm_yr <- worker %>%
  filter(!is.na(lr_remdezr)) %>%
  group_by(identificad, year) %>%
  summarise(
    n_workers = n(),
    
    # --- Gender ---
    share_female = mean(female, na.rm = TRUE),
    lw_male      = mean(lr_remdezr[female == 0], na.rm = TRUE),
    lw_female    = mean(lr_remdezr[female == 1], na.rm = TRUE),
    
    # --- Race ---
    share_white  = mean(white, na.rm = TRUE),
    lw_white     = mean(lr_remdezr[white == 1], na.rm = TRUE),
    lw_nonwhite  = mean(lr_remdezr[white == 0], na.rm = TRUE),
    
    # --- Age ---
    mean_age = mean(age, na.rm = TRUE),
    
    # --- Tenure ---
    mean_tenure = mean(tempempr, na.rm = TRUE),
    
    # --- Education shares ---
    share_nohs        = mean(educ_nohs, na.rm = TRUE),
    share_hs          = mean(educ_hs, na.rm = TRUE),
    share_collegeplus = mean(educ_collegeplus, na.rm = TRUE),
    share_hsplus      = mean(educ_hsplus, na.rm = TRUE),
    
    # --- Education group wages ---
    lw_nohs        = mean(lr_remdezr[educ_nohs == 1], na.rm = TRUE),
    lw_hs          = mean(lr_remdezr[educ_hs == 1], na.rm = TRUE),
    lw_collegeplus = mean(lr_remdezr[educ_collegeplus == 1], na.rm = TRUE),
    lw_hsplus      = mean(lr_remdezr[educ_hsplus == 1], na.rm = TRUE),
    
    .groups = "drop"
  ) %>%
  mutate(
    # --- Gaps ---
    gender_gap       = lw_male - lw_female,
    race_gap         = lw_white - lw_nonwhite,
    edprem_hs        = lw_hs - lw_nohs,
    edprem_collegeplus = lw_collegeplus - lw_nohs,
    edprem_hsplus    = lw_hsplus - lw_nohs
  )

# --- Slopes (need >= 2 workers) ---
cat("Computing age and tenure slopes...\n")

slopes <- worker %>%
  filter(!is.na(lr_remdezr), !is.na(tempempr), !is.na(age)) %>%
  group_by(identificad, year) %>%
  filter(n() >= 2) %>%
  summarise(
    tenure_slope = {
      x <- tempempr - mean(tempempr)
      denom <- sum(x^2)
      if (denom > 0) sum(x * lr_remdezr) / denom else NA_real_
    },
    age_slope = {
      x <- age - mean(age)
      denom <- sum(x^2)
      if (denom > 0) sum(x * lr_remdezr) / denom else NA_real_
    },
    .groups = "drop"
  )

# Merge slopes into firm_yr
firm_yr <- firm_yr %>%
  left_join(slopes, by = c("identificad", "year"))

cat("Firm-year outcomes computed:", nrow(firm_yr), "cells\n")

rm(worker, slopes); gc()

# =============================================================================
# 2. LOAD MAIN ANALYSIS DATA AND MERGE
# =============================================================================

df <- readRDS(file.path(rais_firm, "lagos_sample_sep24_pct_unionexp_ext_df2.rds"))

# --- Auxiliary datasets ---
network_size <- read.csv(file.path(rais_firm, "network_degree_full_rais.csv"))
network_size$identificad <- sprintf("%014.0f", network_size$identificad)

totalflows_pw_n_data <- read.csv(file.path(rais_firm, "sample_estabs_pw_flows.csv"))
totalflows_pw_n_data$identificad <- sprintf("%014.0f", totalflows_pw_n_data$identificad)

turnover_data <- read.csv(file.path(rais_firm, "corrected_turnover_sample.csv"))
turnover_data$identificad <- sprintf("%014.0f", turnover_data$identificad)
turnover_data$churn_u <- turnover_data$hired_u + turnover_data$separations_u
turnover_data$churn_rate_u <- turnover_data$churn_u / turnover_data$avg_emp
turnover_data <- turnover_data %>% rename(separation_rate_u = turnover_u)

pre_avgs <- turnover_data %>%
  filter(year >= 2009, year <= 2011) %>%
  group_by(identificad) %>%
  summarise(
    churn_u_pre          = mean(churn_u, na.rm = TRUE),
    churn_rate_u_pre     = mean(churn_rate_u, na.rm = TRUE),
    separation_rate_u_pre = mean(separation_rate_u, na.rm = TRUE)
  )
turnover_data <- turnover_data %>% left_join(pre_avgs, by = "identificad")

yearly_flows_data <- read.csv(file.path(rais_firm, "totalflows_wide_2007_2011.csv"))
yearly_flows_data$identificad <- sprintf("%014.0f", yearly_flows_data$identificad)
yearly_flows_data <- yearly_flows_data %>%
  mutate(totalflows_pw_pre_07_11 = rowMeans(
    cbind(totalflows_pw_07_08, totalflows_pw_08_09,
          totalflows_pw_09_10, totalflows_pw_10_11), na.rm = TRUE))

df <- df %>%
  left_join(totalflows_pw_n_data %>% select(identificad, totalflows_pw_n),
            by = "identificad") %>%
  left_join(network_size %>% select(identificad, n_connected_4yr),
            by = "identificad") %>%
  left_join(turnover_data %>% select(-firm_emp, -l_firm_emp),
            by = c("identificad", "year")) %>%
  left_join(yearly_flows_data %>% select(identificad, totalflows_pw_pre_07_11),
            by = "identificad")

rm(network_size, totalflows_pw_n_data, turnover_data, pre_avgs, yearly_flows_data); gc()

# --- Merge worker-characteristic outcomes ---
firm_yr$identificad <- sprintf("%014.0f", as.numeric(firm_yr$identificad))
firm_yr$year <- as.integer(firm_yr$year)

df <- df %>%
  left_join(firm_yr, by = c("identificad", "year"))

cat("Merge coverage (non-missing share_female):",
    sum(!is.na(df$share_female)), "of", nrow(df), "rows\n")

rm(firm_yr); gc()

df <- df %>% filter(year >= 2009, lagos_sample_avg == 1)
cat("Full sample size:", nrow(df), "\n")

# =============================================================================
# 3. VARIABLE CREATION
# =============================================================================

df <- df %>%
  mutate(placebo_year = as.integer(year < 2011),
         treat_year   = as.integer(year >= 2012))

# Scale connectivity to 90th percentile
p90_conn <- df %>%
  filter(treat_ultra == 0, in_balanced_panel == 1, year == 2009) %>%
  summarise(p90 = quantile(totaltreat_pw_n, 0.90, na.rm = TRUE)) %>%
  pull(p90)
df <- df %>% mutate(totaltreat_pw_norm = totaltreat_pw_n / p90_conn)

# --- All outcome variables that need pre-treatment averages ---
outcome_vars <- c(
  "lr_remdezr_w",
  # Gender
  "share_female", "lw_male", "lw_female", "gender_gap",
  # Race
  "share_white", "lw_white", "lw_nonwhite", "race_gap",
  # Age
  "mean_age", "age_slope",
  # Tenure
  "mean_tenure", "tenure_slope",
  # Education shares
  "share_nohs", "share_hs", "share_collegeplus", "share_hsplus",
  # Education wages
  "lw_nohs", "lw_hs", "lw_collegeplus", "lw_hsplus",
  # Education premia
  "edprem_hs", "edprem_collegeplus", "edprem_hsplus"
)

# Pre-treatment averages (2009-2011) for all outcomes
for (v in outcome_vars) {
  pre_name <- paste0(v, "_pre")
  if (!pre_name %in% names(df) & v %in% names(df)) {
    df <- df %>%
      group_by(identificad) %>%
      mutate(!!pre_name := mean(.data[[v]][year %in% 2009:2011], na.rm = TRUE)) %>%
      ungroup()
  }
}

# Pre-treatment averages for size controls
for (v in c("l_firm_emp")) {
  pre_name <- paste0(v, "_pre")
  if (!pre_name %in% names(df)) {
    df <- df %>%
      group_by(identificad) %>%
      mutate(!!pre_name := mean(.data[[v]][year %in% 2009:2011], na.rm = TRUE)) %>%
      ungroup()
  }
}

df <- df %>%
  group_by(identificad) %>%
  mutate(firm_emp_pre = mean(firm_emp[year %in% 2009:2011], na.rm = TRUE)) %>%
  ungroup() %>%
  mutate(tf_per_emp_pre = if_else(firm_emp_pre > 0,
                                  totalflows_n / (4 * firm_emp_pre), NA_real_))

# --- Quartile bins ---
make_bins <- function(data, var, g = 4) {
  bin_name <- paste0(var, g)
  ref <- data %>%
    filter(year == 2009, in_balanced_panel == 1) %>%
    transmute(identificad, !!bin_name := ntile(.data[[var]], g) - 1L)
  data %>%
    left_join(ref, by = "identificad", suffix = c("", ".new")) %>%
    { if (paste0(bin_name, ".new") %in% names(.)) {
      mutate(., !!bin_name := coalesce(.data[[paste0(bin_name, ".new")]],
                                       .data[[bin_name]])) %>%
        select(-all_of(paste0(bin_name, ".new")))
    } else . } %>%
    mutate(!!bin_name := replace_na(.data[[bin_name]], 0L))
}

# Bins for size and flows (shared across all specs)
for (v in c("l_firm_emp_pre", "totalflows_pw_pre_07_11")) {
  if (v %in% names(df)) df <- make_bins(df, v)
}

# Bins for each outcome's own pre-treatment average
for (v in outcome_vars) {
  pre_name <- paste0(v, "_pre")
  if (pre_name %in% names(df)) {
    df <- make_bins(df, pre_name)
  }
}

# =============================================================================
# 4. SAMPLES
# =============================================================================

spill    <- df %>% filter(treat_ultra == 0, in_balanced_panel == 1)
direct_a <- df %>% filter(in_balanced_panel == 1,
                          treat_ultra == 1 | (treat_ultra == 0 & totaltreat_pw_n == 0))

cat("Direct A:", n_distinct(direct_a$identificad), "estabs\n")
cat("Spillover:", n_distinct(spill$identificad), "estabs\n")

conn <- "totaltreat_pw_norm"

# =============================================================================
# 5. SPECIFICATIONS
# =============================================================================

base_controls_year <- "identificad + industry1^year + mode_base_month^year +
                       microregion^year"

shared_controls <- "+ l_firm_emp_pre4^year + totalflows_pw_pre_07_114^year"

# Build FE spec for each outcome: base + own pre bin + size + flows
fe_specs <- list()
for (v in outcome_vars) {
  pre_bin <- paste0(v, "_pre4")
  if (pre_bin %in% names(df)) {
    fe_specs[[v]] <- paste(base_controls_year, "+", pre_bin, "^year", shared_controls)
  } else {
    # Fallback: use wage pre bin if outcome's own bin unavailable
    fe_specs[[v]] <- paste(base_controls_year, "+ lr_remdezr_w_pre4^year", shared_controls)
  }
}

# =============================================================================
# 6. ESTIMATION HELPERS
# =============================================================================

stars_fn <- function(p) {
  case_when(p < 0.01 ~ "***", p < 0.05 ~ "**", p < 0.10 ~ "*", TRUE ~ "")
}

print_table <- function(tab, title = "") {
  cat("\n", strrep("=", 120), "\n")
  cat(" ", title, "\n")
  cat(strrep("-", 120), "\n")
  cat(sprintf("  %-12s %-30s %13s %13s %13s %8s\n",
              "Panel", "Outcome", "Post x Treat",
              "Pooled Pre", "Joint F pval", "N"))
  cat(strrep("-", 120), "\n")
  for (i in seq_len(nrow(tab))) {
    r <- tab[i, ]
    cat(sprintf("  %-12s %-30s  %7.4f%s    %7.4f%s      [%5.3f]    %s\n",
                r$label, r$outcome,
                r$b_post, stars_fn(r$p_post),
                r$b_pre_pooled, stars_fn(r$p_pre_pooled),
                r$p_pre_joint,
                format(r$n_obs, big.mark = ",")))
    cat(sprintf("  %44s (%6.4f)     (%6.4f)\n", "", r$se_post, r$se_pre_pooled))
  }
  cat(strrep("=", 120), "\n\n")
}

# --- Direct effects (Panel A) ---
est_direct <- function(outcome, data, label = "") {
  fe_str <- fe_specs[[outcome]]
  if (is.null(fe_str)) {
    cat("  Skipping", outcome, "- no FE spec\n")
    return(NULL)
  }
  
  # Drop rows with missing outcome
  data <- data %>% filter(!is.na(.data[[outcome]]))
  if (nrow(data) < 100) {
    cat("  Skipping", outcome, "- too few obs (", nrow(data), ")\n")
    return(NULL)
  }
  
  data_pre <- data %>% filter(year <= 2011)
  
  m_post <- tryCatch(
    feols(as.formula(paste0(outcome, " ~ treat_ultra:treat_year | ", fe_str)),
          data = data, cluster = ~identificad),
    error = function(e) { cat("  Error in post for", outcome, ":", e$message, "\n"); NULL }
  )
  if (is.null(m_post)) return(NULL)
  
  m_pre <- tryCatch(
    feols(as.formula(paste0(outcome, " ~ treat_ultra:placebo_year | ", fe_str)),
          data = data_pre, cluster = ~identificad),
    error = function(e) NULL
  )
  
  m_es <- tryCatch(
    feols(as.formula(paste0(outcome, " ~ i(year, treat_ultra, ref = 2011) | ", fe_str)),
          data = data, cluster = ~identificad),
    error = function(e) NULL
  )
  
  w_p <- NA_real_
  if (!is.null(m_es)) {
    w <- tryCatch(wald(m_es, "year::20(09|10):treat_ultra"), error = function(e) NULL)
    if (!is.null(w)) w_p <- w$p
  }
  
  cn_pre <- if (!is.null(m_pre)) grep("placebo_year", names(coef(m_pre)), value = TRUE)[1] else NA
  
  tibble(
    label = label, outcome = outcome,
    b_post  = coef(m_post)[["treat_ultra:treat_year"]],
    se_post = se(m_post)[["treat_ultra:treat_year"]],
    p_post  = pvalue(m_post)[["treat_ultra:treat_year"]],
    b_pre_pooled  = if (!is.null(m_pre) & !is.na(cn_pre)) coef(m_pre)[[cn_pre]] else NA_real_,
    se_pre_pooled = if (!is.null(m_pre) & !is.na(cn_pre)) se(m_pre)[[cn_pre]] else NA_real_,
    p_pre_pooled  = if (!is.null(m_pre) & !is.na(cn_pre)) pvalue(m_pre)[[cn_pre]] else NA_real_,
    p_pre_joint   = w_p,
    n_obs = m_post$nobs
  )
}

# --- Spillover effects ---
est_spill <- function(outcome, data, label = "") {
  fe_str <- fe_specs[[outcome]]
  if (is.null(fe_str)) {
    cat("  Skipping", outcome, "- no FE spec\n")
    return(NULL)
  }
  
  data <- data %>% filter(!is.na(.data[[outcome]]))
  if (nrow(data) < 100) {
    cat("  Skipping", outcome, "- too few obs (", nrow(data), ")\n")
    return(NULL)
  }
  
  data_pre <- data %>% filter(year <= 2011)
  
  m_post <- tryCatch(
    feols(as.formula(paste0(outcome, " ~ treat_year:", conn, " | ", fe_str)),
          data = data, cluster = ~identificad),
    error = function(e) { cat("  Error in post for", outcome, ":", e$message, "\n"); NULL }
  )
  if (is.null(m_post)) return(NULL)
  
  m_pre <- tryCatch(
    feols(as.formula(paste0(outcome, " ~ placebo_year:", conn, " | ", fe_str)),
          data = data_pre, cluster = ~identificad),
    error = function(e) NULL
  )
  
  m_es <- tryCatch(
    feols(as.formula(paste0(outcome, " ~ i(year, ", conn, ", ref = 2011) | ", fe_str)),
          data = data, cluster = ~identificad),
    error = function(e) NULL
  )
  
  w_p <- NA_real_
  if (!is.null(m_es)) {
    w <- tryCatch(wald(m_es, paste0("year::20(09|10):", conn)), error = function(e) NULL)
    if (!is.null(w)) w_p <- w$p
  }
  
  cn_post <- grep(conn, names(coef(m_post)), value = TRUE)[1]
  cn_pre  <- if (!is.null(m_pre)) grep(conn, names(coef(m_pre)), value = TRUE)[1] else NA
  
  tibble(
    label = label, outcome = outcome,
    b_post  = coef(m_post)[[cn_post]],
    se_post = se(m_post)[[cn_post]],
    p_post  = pvalue(m_post)[[cn_post]],
    b_pre_pooled  = if (!is.null(m_pre) & !is.na(cn_pre)) coef(m_pre)[[cn_pre]] else NA_real_,
    se_pre_pooled = if (!is.null(m_pre) & !is.na(cn_pre)) se(m_pre)[[cn_pre]] else NA_real_,
    p_pre_pooled  = if (!is.null(m_pre) & !is.na(cn_pre)) pvalue(m_pre)[[cn_pre]] else NA_real_,
    p_pre_joint   = w_p,
    n_obs = m_post$nobs
  )
}

# =============================================================================
# 7. OUTCOME LIST (organized by category)
# =============================================================================

outcomes_gender <- c("share_female", "lw_male", "lw_female", "gender_gap")
outcomes_race   <- c("share_white", "lw_white", "lw_nonwhite", "race_gap")
outcomes_age    <- c("mean_age", "age_slope")
outcomes_tenure <- c("mean_tenure", "tenure_slope")
outcomes_educ_shares <- c("share_nohs", "share_hsplus", "share_hs", "share_collegeplus")
outcomes_educ_wages  <- c("lw_nohs", "lw_hsplus", "lw_hs", "lw_collegeplus")
outcomes_educ_premia <- c("edprem_hsplus", "edprem_hs", "edprem_collegeplus")

all_outcomes <- c(outcomes_gender, outcomes_race, outcomes_age, outcomes_tenure,
                  outcomes_educ_shares, outcomes_educ_wages, outcomes_educ_premia)

# =============================================================================
# 8. ESTIMATION
# =============================================================================

cat("\n========== DIRECT EFFECTS (Panel A) ==========\n")

cat("  Gender...\n")
tab_d_gender <- bind_rows(lapply(outcomes_gender, est_direct, data = direct_a, label = "Gender"))
cat("  Race...\n")
tab_d_race <- bind_rows(lapply(outcomes_race, est_direct, data = direct_a, label = "Race"))
cat("  Age...\n")
tab_d_age <- bind_rows(lapply(outcomes_age, est_direct, data = direct_a, label = "Age"))
cat("  Tenure...\n")
tab_d_tenure <- bind_rows(lapply(outcomes_tenure, est_direct, data = direct_a, label = "Tenure"))
cat("  Education shares...\n")
tab_d_edshare <- bind_rows(lapply(outcomes_educ_shares, est_direct, data = direct_a, label = "Educ Share"))
cat("  Education wages...\n")
tab_d_edwage <- bind_rows(lapply(outcomes_educ_wages, est_direct, data = direct_a, label = "Educ Wage"))
cat("  Education premia...\n")
tab_d_edprem <- bind_rows(lapply(outcomes_educ_premia, est_direct, data = direct_a, label = "Educ Prem"))

cat("\n========== SPILLOVER EFFECTS ==========\n")

cat("  Gender...\n")
tab_s_gender <- bind_rows(lapply(outcomes_gender, est_spill, data = spill, label = "Gender"))
cat("  Race...\n")
tab_s_race <- bind_rows(lapply(outcomes_race, est_spill, data = spill, label = "Race"))
cat("  Age...\n")
tab_s_age <- bind_rows(lapply(outcomes_age, est_spill, data = spill, label = "Age"))
cat("  Tenure...\n")
tab_s_tenure <- bind_rows(lapply(outcomes_tenure, est_spill, data = spill, label = "Tenure"))
cat("  Education shares...\n")
tab_s_edshare <- bind_rows(lapply(outcomes_educ_shares, est_spill, data = spill, label = "Educ Share"))
cat("  Education wages...\n")
tab_s_edwage <- bind_rows(lapply(outcomes_educ_wages, est_spill, data = spill, label = "Educ Wage"))
cat("  Education premia...\n")
tab_s_edprem <- bind_rows(lapply(outcomes_educ_premia, est_spill, data = spill, label = "Educ Prem"))

# =============================================================================
# 9. PRINT RESULTS
# =============================================================================

print_table(bind_rows(tab_d_gender, tab_d_race),
            "Direct Effects (Panel A): Gender & Race")

print_table(bind_rows(tab_d_age, tab_d_tenure),
            "Direct Effects (Panel A): Age & Tenure")

print_table(bind_rows(tab_d_edshare, tab_d_edwage, tab_d_edprem),
            "Direct Effects (Panel A): Education")

print_table(bind_rows(tab_s_gender, tab_s_race),
            "Spillover Effects: Gender & Race")

print_table(bind_rows(tab_s_age, tab_s_tenure),
            "Spillover Effects: Age & Tenure")

print_table(bind_rows(tab_s_edshare, tab_s_edwage, tab_s_edprem),
            "Spillover Effects: Education")

# =============================================================================
# 10. EXPORT COMBINED TABLE
# =============================================================================

full_results <- bind_rows(
  bind_rows(tab_d_gender, tab_d_race, tab_d_age, tab_d_tenure,
            tab_d_edshare, tab_d_edwage, tab_d_edprem) %>%
    mutate(design = "Direct A"),
  bind_rows(tab_s_gender, tab_s_race, tab_s_age, tab_s_tenure,
            tab_s_edshare, tab_s_edwage, tab_s_edprem) %>%
    mutate(design = "Spillover")
)

write.csv(full_results,
          file.path(rais_firm, "worker_characteristics_did_results.csv"),
          row.names = FALSE)

cat("\nResults saved to worker_characteristics_did_results.csv\n")
cat("Done.\n")