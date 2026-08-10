rm(list = ls())
library(dplyr)
library(tidyverse)
library(haven)
library(ggplot2)
library(fixest)

# ============================================================================
# UNION SPILLOVERS — MAIN RESULTS
#
# Produces: Table 2, Figure 1, Table 3, Figure 2, Table 4
#
# Structure:
#   1. Load data
#   2. Create variables (treatment timing, connectivity, bins, etc.)
#   3. Define samples (direct effects, spillover)
#   4. Define specifications — ALL controls live here for easy tweaking
#   5. Helpers (table display)
#   6. Estimation functions
#   7-11. Results
#
# PRE-TREND TESTS: Each estimation function reports two pre-trend diagnostics:
#   (a) Pooled placebo: a single pre-treatment coefficient from a separate
#       regression on pre-reform data (treat x placebo_year), with SE and p-val.
#       This pools 2009-2010 into a single dummy and tests the average deviation
#       from the 2011 reference year.
#   (b) Joint Wald test: F-test of all pre-treatment event-study coefficients
#       being jointly zero, from the full-sample event-study model. This allows
#       each pre-treatment year to have its own coefficient.
# ============================================================================

rais_firm <- "/Users/gui.neri/Library/CloudStorage/OneDrive-NorthwesternUniversity/Research Projects/Org_Econ BR/UnionSpillovers/Gui_coding/Luis_og_files"

# =============================================================================
# 1. LOAD DATA
# =============================================================================

# ##--- Run once: import .dta and save as .rds ---
# df <- read_dta(file.path(rais_firm,
#                          "lagos_sample_sep24_pct_unionexp_ext_df2.dta"))
# saveRDS(df, file.path(rais_firm,
#                       "lagos_sample_sep24_pct_unionexp_ext_df2.rds"))

# --- Standard load ---
df <- readRDS(file.path(rais_firm,
                        "lagos_sample_sep24_pct_unionexp_ext_df2.rds"))

## read data with the network size to attach to main data
network_size <- read.csv(file.path(rais_firm,
                                        "network_degree_full_rais.csv"))
network_size$identificad <- sprintf("%014.0f", network_size$identificad)

## read data with the total flows per worker (totalflows_pw_n)
totalflows_pw_n_data <- read.csv(file.path(rais_firm,
                                        "sample_estabs_pw_flows.csv"))
totalflows_pw_n_data$identificad <- sprintf("%014.0f", totalflows_pw_n_data$identificad)

# Read new turnover data
turnover_data <- read.csv(file.path(rais_firm,
                                        "corrected_turnover_sample.csv"))
turnover_data$identificad <- sprintf("%014.0f", turnover_data$identificad)

### Adjusting and creating some variables in the turnover data
# Total churn: hiring + separations
turnover_data$churn_u <- turnover_data$hired_u + turnover_data$separations_u
# turnover_data$churn_u <- turnover_data$hired_u + turnover_data$separations_u - turnover_data$other_sep_u

# Churn rate: churn / avg employment
turnover_data$churn_rate_u <- turnover_data$churn_u / turnover_data$avg_emp
# Renaming turnover to separation rate
turnover_data <- turnover_data %>% rename(separation_rate_u = turnover_u)
# Pre-treatment averages (2009-2011) for churn, churn rate, and separation rate
pre_avgs <- turnover_data %>%
  filter(year >= 2009, year <= 2011) %>%
  group_by(identificad) %>%
  summarise(
    churn_u_pre          = mean(churn_u, na.rm = TRUE),
    churn_rate_u_pre     = mean(churn_rate_u, na.rm = TRUE),
    separation_rate_u_pre = mean(separation_rate_u, na.rm = TRUE)
  )
turnover_data <- turnover_data %>%
  left_join(pre_avgs, by = "identificad")

# Reading new yearly flows data
yearly_flows_data <- read.csv(file.path(rais_firm,
                                        "totalflows_wide_2007_2011.csv"))
yearly_flows_data$identificad <- sprintf("%014.0f", yearly_flows_data$identificad)

# # testing where the missing in balanced panel comes from
# x<- select(df,identificad, in_balanced_panel,year,treat_ultra,totaltreat_pw_n)
# x<-filter(x, x$year == 2012)
# 
# y<-left_join(yearly_flows_data, x, by = c("identificad"))
# k<-filter(y, y$in_balanced_panel == 1)

#Constructing pre-treatment average flow variables for 2007-2011 and 2009-2011
yearly_flows_data <- yearly_flows_data %>%
  mutate(
    totalflows_pre_07_11 = rowMeans(cbind(totalflows_07_08, totalflows_08_09, totalflows_09_10, totalflows_10_11), na.rm = TRUE),
    totalflows_pre_09_11 = rowMeans(cbind(totalflows_09_10, totalflows_10_11), na.rm = TRUE),
    totalflows_pw_pre_07_11 = rowMeans(cbind(totalflows_pw_07_08, totalflows_pw_08_09, totalflows_pw_09_10, totalflows_pw_10_11), na.rm = TRUE),
    totalflows_pw_pre_09_11 = rowMeans(cbind(totalflows_pw_09_10, totalflows_pw_10_11), na.rm = TRUE)
)




# Merge aux datasets to main data
# PS: these auxiliary datasets are only for the balanced panel
df <- df %>% left_join(totalflows_pw_n_data %>% select(identificad, totalflows_pw_n),
                       by = c("identificad"))

df <- df %>% left_join(network_size %>% select(identificad, n_connected_4yr),
                         by = c("identificad"))

df <- df %>%
  left_join(
    turnover_data %>% select(-firm_emp, -l_firm_emp),
    by = c("identificad", "year")
  )

df <- df %>%
  left_join(
    yearly_flows_data %>% select(identificad,totalflows_pre_07_11,totalflows_pre_09_11,totalflows_pw_pre_07_11,totalflows_pw_pre_09_11),
    by = c("identificad")
  )

rm(network_size,totalflows_pw_n_data,turnover_data,pre_avgs)
gc()


# Keep only post-2009 observations in the Lagos analysis sample
df <- df %>% filter(year >= 2009, lagos_sample_avg == 1)
cat("Full sample size:", nrow(df), "\n")

# #Excluding public sector firms (would have to re-compute some things after)
# df <- df %>% filter(pub_firm == 0)




# =============================================================================
# 2. VARIABLE CREATION
# =============================================================================

# --- 2a. Treatment timing indicators ----------------------------------------
# placebo_year = 1 for 2009-2010 (pooled pre-trend test; 2011 is omitted ref)
# treat_year   = 1 for years 2012-2016 (post-reform)
df <- df %>%
  mutate(placebo_year = as.integer(year < 2011),
         treat_year   = as.integer(year >= 2012))

# --- 2b. Scale connectivity to 90th percentile among untreated firms --------
# This normalization means a coefficient on connectivity represents the
# effect of moving from 0 to the 90th percentile of exposure.
# We compute the 90th percentile from the 2009 cross-section of untreated,
# balanced-panel firms (the spillover sample).
p90_conn <- df %>%
  filter(treat_ultra == 0, in_balanced_panel == 1, year == 2009) %>%
  summarise(p90 = quantile(totaltreat_pw_n, 0.90, na.rm = TRUE)) %>%
  pull(p90)

df <- df %>% mutate(totaltreat_pw_norm = totaltreat_pw_n / p90_conn)

# --- 2c. Pre-treatment averages (2009-2011) ----------------------------------
# Used as control variables (via bins) to absorb level differences in
# outcomes across establishments before the reform.
for (v in c("lr_remdezr_w", "lr_remdezr_h_w", "l_firm_emp", "turnover")) {
  pre_name <- paste0(v, "_pre")
  df <- df %>%
    group_by(identificad) %>%
    mutate(!!pre_name := mean(.data[[v]][year %in% 2009:2011], na.rm = TRUE)) %>%
    ungroup()
}

# Pre-treatment average firm size (used to construct flows-per-employee)
df <- df %>%
  group_by(identificad) %>%
  mutate(firm_emp_pre = mean(firm_emp[year %in% 2009:2011], na.rm = TRUE)) %>%
  ungroup() %>%
  # Total worker flows scaled by firm size — captures overall mobility rate
  mutate(tf_per_emp_pre = if_else(firm_emp_pre > 0,
                                  totalflows_n / (4*firm_emp_pre), NA_real_))

# # Only firms within an interval of firm size (based on pre-treatment avg)
# df <- filter(df, df$firm_emp_pre >= 5 & df$firm_emp_pre <= 1000)

# --- 2d. CBA period variables ------------------------------------------------
# For the clause count outcome, we use CBA filing periods rather than
# calendar years, because CBAs are filed at irregular intervals.
# Periods 1-2 are pre-treatment; periods 3-6 are post-treatment (2013-2016).
df <- df %>%
  mutate(
    cba_period = case_when(
      # Period 1: earliest CBA filed on or after 2009
      avg_file_date == earliest2009_avg - 1 & !is.na(avg_file_date) ~ 1L,
      # Period 2: second CBA (still pre-reform)
      avg_file_date == second_cba_avg & !is.na(avg_file_date) ~ 2L,
      # Periods 3-6: post-reform, one per calendar year
      avg_file_date >= as.Date("2013-01-01") &
        avg_file_date <= as.Date("2013-12-31") & !is.na(avg_file_date) ~ 3L,
      avg_file_date >= as.Date("2014-01-01") &
        avg_file_date <= as.Date("2014-12-31") & !is.na(avg_file_date) ~ 4L,
      avg_file_date >= as.Date("2015-01-01") &
        avg_file_date <= as.Date("2015-12-31") & !is.na(avg_file_date) ~ 5L,
      avg_file_date >= as.Date("2016-01-01") &
        avg_file_date <= as.Date("2016-12-31") & !is.na(avg_file_date) ~ 6L,
      TRUE ~ NA_integer_
    ),
    # Binary indicators for pooled pre/post CBA regressions
    pre_treat_cba  = if_else(cba_period < 2, 1L, 0L),
    post_treat_cba = if_else(!is.na(cba_period) & cba_period >= 3, 1L, 0L)
  )

# Pre-treatment average clause count (across CBA periods 1-2)
if ("numb_clauses" %in% names(df)) {
  df <- df %>%
    group_by(identificad) %>%
    mutate(numb_clauses_pre = mean(numb_clauses[cba_period %in% 1:2],
                                   na.rm = TRUE)) %>%
    ungroup()
}

## Excluding firms with very share of flows
#  df<- filter(df,df$churn_rate_u_pre <=2)


# --- 2e. Control bins ---------------------------------------------------------
# Create quartile bins (0,1,2,3) based on the 2009 balanced-panel cross-section.
# These are interacted with year (or cba_period) FEs in the specification to
# allow flexible differential trends by pre-treatment characteristics.
# Establishments not in the 2009 cross-section get bin = 0 (the reference
# category), matching Stata's ib0. behavior.
make_bins <- function(data, var, g = 4) {
  bin_name <- paste0(var, g)
  # Compute bins from the 2009 cross-section only
  ref <- data %>%
    filter(year == 2009, in_balanced_panel == 1) %>%
    transmute(identificad, !!bin_name := ntile(.data[[var]], g) - 1L)
  # Merge back to full panel; handle potential duplicate column from re-runs
  data %>%
    left_join(ref, by = "identificad", suffix = c("", ".new")) %>%
    { if (paste0(bin_name, ".new") %in% names(.)) {
      mutate(., !!bin_name := coalesce(.data[[paste0(bin_name, ".new")]],
                                       .data[[bin_name]])) %>%
        select(-all_of(paste0(bin_name, ".new")))
    } else . } %>%
    # Assign missing bins to 0 (reference category)
    mutate(!!bin_name := replace_na(.data[[bin_name]], 0L))
}

df <- make_bins(df, "totalflows_n")
df <- make_bins(df, "tf_per_emp_pre")
for (v in c("lr_remdezr_w_pre", "lr_remdezr_h_w_pre",
            "l_firm_emp_pre", "numb_clauses_pre", "turnover_pre","totalflows_pw_n","n_connected_4yr",
            "churn_u_pre", "churn_rate_u_pre", "separation_rate_u_pre",
            "totalflows_pre_07_11", "totalflows_pre_09_11","totalflows_pw_pre_07_11", "totalflows_pw_pre_09_11")) {
  if (v %in% names(df)) df <- make_bins(df, v)
}

# --- 2f. Union exposure variables ---------------------------------------------
# Binary indicator for whether the establishment's union covers any treated firm
df <- df %>% mutate(treat_union = as.integer(treat_union_exp_all > 0))

# =============================================================================
# 3. SAMPLE DEFINITIONS
# =============================================================================

# Spillover sample: all untreated firms in the balanced panel
spill <- df %>% filter(treat_ultra == 0, in_balanced_panel == 1)

# Direct effects Panel A: treated firms + untreated with ZERO connectivity
# (excludes indirectly exposed firms from the control group)
direct_a <- df %>%
  filter(in_balanced_panel == 1,
         treat_ultra == 1 | (treat_ultra == 0 & totaltreat_pw_n == 0))



# # Direct effects Panel A one <1% connectivity
# # (excludes indirectly exposed firms from the control group)
# direct_a <- df %>%
#   filter(in_balanced_panel == 1,
#          treat_ultra == 1 | (treat_ultra == 0 & totaltreat_pw_n <0.01))


# Direct effects Panel B: treated firms + ALL untreated firms
direct_b <- df %>% filter(in_balanced_panel == 1)

# # Excluding smaller firms
# direct_a <- direct_a %>% filter(firm_emp_pre<=200)
# direct_b <- direct_b %>% filter(firm_emp_pre<=200)
# spill<- spill %>% filter(firm_emp_pre<=200)


cat("Direct A:", n_distinct(direct_a$identificad), "estabs\n")
cat("Direct B:", n_distinct(direct_b$identificad), "estabs\n")
cat("Spillover:", n_distinct(spill$identificad), "estabs\n")

# Name of the normalized connectivity variable (used in spillover regressions)
conn <- "totaltreat_pw_norm"

# =============================================================================
# 4. SPECIFICATIONS — ALL CONTROLS DEFINED HERE
# =============================================================================

# --- Base components (shared across outcomes) --------------------------------
# These appear in every specification. To remove a control, comment it out here.

base_controls_year <- "identificad + industry1^year + mode_base_month^year +
                       microregion^year"

base_controls_cba  <- "identificad + industry1^cba_period + mode_base_month^cba_period +
                       microregion^cba_period"




# --- Full FE strings by outcome ----------------------------------------------
# Each entry is the complete fixed-effects portion of the formula.
# To change how pre-treatment outcomes are controlled for (e.g., linear instead
# of bins, or drop entirely), just edit the relevant line.

## Current draft version
# fe_specs <- list(
#   lr_remdezr_w   = paste(base_controls_year,
#                          "+ lr_remdezr_w_pre4^year + tf_per_emp_pre4^year"),
#   lr_remdezr_h_w = paste(base_controls_year,
#                          "+ lr_remdezr_h_w_pre4^year + tf_per_emp_pre4^year"),
#   l_firm_emp     = paste(base_controls_year,
#                          "+ l_firm_emp_pre4^year + tf_per_emp_pre4^year"),
#   numb_clauses   = paste(base_controls_cba,
#                          "+ numb_clauses_pre4^cba_period+tf_per_emp_pre4^cba_period")
# )

## Most ex ante reasonable version (???)
# fe_specs <- list(
#   lr_remdezr_w   = paste(base_controls_year,
#                          "+ lr_remdezr_w_pre4^year + l_firm_emp_pre4^year + totalflows_n4^year"),
#   lr_remdezr_h_w = paste(base_controls_year,
#                          "+ lr_remdezr_h_w_pre4^year + l_firm_emp_pre4^year + totalflows_n4^year"),
#   l_firm_emp     = paste(base_controls_year,
#                          "+ l_firm_emp_pre4^year + l_firm_emp_pre4^year + totalflows_n4^year"),
#   numb_clauses   = paste(base_controls_cba,
#                          "+ numb_clauses_pre4^cba_period+l_firm_emp_pre4^cba_period + totalflows_n4^cba_period")
# )

## Best-looking out of reasonable ones
# fe_specs <- list(
#   lr_remdezr_w   = paste(base_controls_year,
#                          "+ lr_remdezr_w_pre4^year + l_firm_emp_pre4^year"),
#   lr_remdezr_h_w = paste(base_controls_year,
#                          "+ lr_remdezr_h_w_pre4^year + l_firm_emp_pre4^year"),
#   l_firm_emp     = paste(base_controls_year,
#                          "+ l_firm_emp_pre4^year + l_firm_emp_pre4^year"),
#   numb_clauses   = paste(base_controls_cba,
#                          "+ numb_clauses_pre4^cba_period+l_firm_emp_pre4^cba_period")
# )






fe_specs <- list(
  lr_remdezr_w   = paste(base_controls_year,
                         "+ lr_remdezr_w_pre4^year + l_firm_emp_pre4^year + turnover_pre4^year"),
  lr_remdezr_h_w = paste(base_controls_year,
                         "+ lr_remdezr_h_w_pre4^year + l_firm_emp_pre4^year + turnover_pre4^year"),
  l_firm_emp     = paste(base_controls_year,
                         "+ l_firm_emp_pre4^year + l_firm_emp_pre4^year + turnover_pre4^year"),
  numb_clauses   = paste(base_controls_cba,
                         "+ numb_clauses_pre4^cba_period+l_firm_emp_pre4^cba_period + turnover_pre4^cba_period")
)

fe_specs <- list(
  lr_remdezr_w   = paste(base_controls_year,
                         "+ lr_remdezr_w_pre4^year + l_firm_emp_pre4^year + churn_u_pre4^year"),
  lr_remdezr_h_w = paste(base_controls_year,
                         "+ lr_remdezr_h_w_pre4^year + l_firm_emp_pre4^year + churn_u_pre4^year"),
  l_firm_emp     = paste(base_controls_year,
                         "+ l_firm_emp_pre4^year + l_firm_emp_pre4^year + churn_u_pre4^year"),
  numb_clauses   = paste(base_controls_cba,
                         "+ numb_clauses_pre4^cba_period+l_firm_emp_pre4^cba_period + churn_u_pre4^cba_period")
)

fe_specs <- list(
  lr_remdezr_w   = paste(base_controls_year,
                         "+ lr_remdezr_w_pre4^year + l_firm_emp_pre4^year"),
  lr_remdezr_h_w = paste(base_controls_year,
                         "+ lr_remdezr_h_w_pre4^year + l_firm_emp_pre4^year"),
  l_firm_emp     = paste(base_controls_year,
                         "+ l_firm_emp_pre4^year + l_firm_emp_pre4^year"),
  numb_clauses   = paste(base_controls_cba,
                         "+ numb_clauses_pre4^cba_period+l_firm_emp_pre4^cba_period")
)

fe_specs <- list(
  lr_remdezr_w   = paste(base_controls_year,
                         "+ lr_remdezr_w_pre4^year + l_firm_emp_pre4^year+ totalflows_pw_pre_07_114^year"),
  lr_remdezr_h_w = paste(base_controls_year,
                         "+ lr_remdezr_h_w_pre4^year + l_firm_emp_pre4^year+ totalflows_pw_pre_07_114^year"),
  l_firm_emp     = paste(base_controls_year,
                         "+ l_firm_emp_pre4^year + l_firm_emp_pre4^year+ totalflows_pw_pre_07_114^year"),
  numb_clauses   = paste(base_controls_cba,
                         "+ numb_clauses_pre4^cba_period+l_firm_emp_pre4^cba_period+ totalflows_pw_pre_07_114^cba_period")
)




# =============================================================================
# 5. TABLE DISPLAY (plain text — zero dependencies)
# =============================================================================

stars_fn <- function(p) {
  case_when(p < 0.01 ~ "***", p < 0.05 ~ "**", p < 0.10 ~ "*", TRUE ~ "")
}

print_table <- function(tab, title = "") {
  cat("\n", strrep("=", 95), "\n")
  cat(" ", title, "\n")
  cat(strrep("-", 95), "\n")
  cat(sprintf("  %-12s %-18s %13s %13s %13s %8s\n",
              "Panel", "Outcome", "Post x Treat",
              "Pooled Pre", "Joint F pval", "N"))
  cat(strrep("-", 95), "\n")
  for (i in seq_len(nrow(tab))) {
    r <- tab[i, ]
    cat(sprintf("  %-12s %-18s  %7.4f%s    %7.4f%s      [%5.3f]    %s\n",
                r$label, r$outcome,
                r$b_post, stars_fn(r$p_post),
                r$b_pre_pooled, stars_fn(r$p_pre_pooled),
                r$p_pre_joint,
                format(r$n_obs, big.mark = ",")))
    cat(sprintf("  %32s (%6.4f)     (%6.4f)\n", "", r$se_post, r$se_pre_pooled))
  }
  cat(strrep("=", 95), "\n\n")
}

# =============================================================================
# 6. ESTIMATION FUNCTIONS
# =============================================================================
# All functions look up the FE string from fe_specs (defined in Section 4).
# They return a one-row tibble with:
#   label, outcome,
#   b_post, se_post, p_post,                    (post-reform treatment effect)
#   b_pre_pooled, se_pre_pooled, p_pre_pooled,  (pooled placebo regression)
#   p_pre_joint,                                 (joint Wald test from event study)
#   n_obs.

# --- 6a. Direct effects (pooled DiD) -----------------------------------------
est_direct <- function(outcome, data, label = "") {
  fe_str <- fe_specs[[outcome]]
  
  # Post-reform pooled DiD
  m_post <- feols(
    as.formula(paste0(outcome, " ~ treat_ultra:treat_year | ", fe_str)),
    data = data, cluster = ~identificad)
  
  # --- Pooled placebo pre-trend test ---
  # Separate regression on pre-reform data only. Tests a single pooled
  # coefficient: the average deviation of 2009-2010 from 2011.
  m_pre <- feols(
    as.formula(paste0(outcome, " ~ treat_ultra:placebo_year | ", fe_str)),
    data = data %>% filter(year <= 2011), cluster = ~identificad)
  
  # --- Joint Wald test from event study ---
  # Allows each pre-treatment year its own coefficient, then tests them jointly.
  m_es <- feols(
    as.formula(paste0(outcome, " ~ i(year, treat_ultra, ref = 2011) | ", fe_str)),
    data = data, cluster = ~identificad)
  
  w <- wald(m_es, "year::20(09|10):treat_ultra")
  
  tibble(label = label, outcome = outcome,
         b_post  = coef(m_post)[["treat_ultra:treat_year"]],
         se_post = se(m_post)[["treat_ultra:treat_year"]],
         p_post  = pvalue(m_post)[["treat_ultra:treat_year"]],
         b_pre_pooled  = coef(m_pre)[["treat_ultra:placebo_year"]],
         se_pre_pooled = se(m_pre)[["treat_ultra:placebo_year"]],
         p_pre_pooled  = pvalue(m_pre)[["treat_ultra:placebo_year"]],
         p_pre_joint   = w$p,
         n_obs = m_post$nobs)
}

# --- 6b. Direct effects for clause count (uses CBA periods, not years) --------
est_direct_clauses <- function(data, label = "") {
  fe_str <- fe_specs[["numb_clauses"]]
  
  # Post-reform
  m_post <- feols(
    as.formula(paste0("numb_clauses ~ treat_ultra:post_treat_cba | ", fe_str)),
    data = data %>% filter(!is.na(cba_period)), cluster = ~identificad)
  
  # --- Pooled placebo pre-trend test ---
  m_pre <- feols(
    as.formula(paste0("numb_clauses ~ treat_ultra:pre_treat_cba | ", fe_str)),
    data = data %>% filter(!is.na(cba_period), cba_period <= 2),
    cluster = ~identificad)
  
  # --- Joint Wald test from event study ---
  # Note: only 1 pre-treatment CBA period, so both tests collapse to the
  # same single restriction. Results should be numerically very close.
  m_es <- feols(
    as.formula(paste0("numb_clauses ~ i(cba_period, treat_ultra, ref = 2) | ", fe_str)),
    data = data %>% filter(!is.na(cba_period)), cluster = ~identificad)
  
  w <- wald(m_es, "cba_period::1")
  
  tibble(label = label, outcome = "numb_clauses",
         b_post  = coef(m_post)[["treat_ultra:post_treat_cba"]],
         se_post = se(m_post)[["treat_ultra:post_treat_cba"]],
         p_post  = pvalue(m_post)[["treat_ultra:post_treat_cba"]],
         b_pre_pooled  = coef(m_pre)[["treat_ultra:pre_treat_cba"]],
         se_pre_pooled = se(m_pre)[["treat_ultra:pre_treat_cba"]],
         p_pre_pooled  = pvalue(m_pre)[["treat_ultra:pre_treat_cba"]],
         p_pre_joint   = w$p,
         n_obs = m_post$nobs)
}

# --- 6c. Spillover effects (continuous connectivity treatment) ----------------
est_spill <- function(outcome, data, extra_rhs = "", extra_fe = "", label = "") {
  fe_str <- fe_specs[[outcome]]
  if (nchar(extra_fe) > 0) fe_str <- paste(fe_str, "+", extra_fe)
  
  # Build RHS components
  rhs_post <- paste0("treat_year:", conn)
  rhs_pre  <- paste0("placebo_year:", conn)
  if (nchar(extra_rhs) > 0) {
    rhs_post <- paste(rhs_post, "+", extra_rhs)
    rhs_pre  <- paste(rhs_pre,  "+", extra_rhs)
  }
  
  # Post-reform spillover estimate
  m_post <- feols(
    as.formula(paste0(outcome, " ~ ", rhs_post, " | ", fe_str)),
    data = data, cluster = ~identificad)
  
  # --- Pooled placebo pre-trend test ---
  m_pre <- feols(
    as.formula(paste0(outcome, " ~ ", rhs_pre, " | ", fe_str)),
    data = data %>% filter(year <= 2011), cluster = ~identificad)
  
  # --- Joint Wald test from event study ---
  rhs_es <- paste0("i(year, ", conn, ", ref = 2011)")
  if (nchar(extra_rhs) > 0) {
    rhs_es <- paste(rhs_es, "+", extra_rhs)
  }
  
  m_es <- feols(
    as.formula(paste0(outcome, " ~ ", rhs_es, " | ", fe_str)),
    data = data, cluster = ~identificad)
  
  # FIX: match only connectivity's pre-treatment coefficients, not those
  # from extra_rhs variables (which also get year::200X interactions)
  w <- wald(m_es, paste0("year::20(09|10):", conn))
  
  # Extract connectivity coefficient names
  cn_post <- grep(conn, names(coef(m_post)), value = TRUE)[1]
  cn_pre  <- grep(conn, names(coef(m_pre)),  value = TRUE)[1]
  
  tibble(label = label, outcome = outcome,
         b_post  = coef(m_post)[[cn_post]],
         se_post = se(m_post)[[cn_post]],
         p_post  = pvalue(m_post)[[cn_post]],
         b_pre_pooled  = coef(m_pre)[[cn_pre]],
         se_pre_pooled = se(m_pre)[[cn_pre]],
         p_pre_pooled  = pvalue(m_pre)[[cn_pre]],
         p_pre_joint   = w$p,
         n_obs = m_post$nobs)
}

# --- 6d. Spillover for clause count (CBA-period timing) -----------------------
est_spill_clauses <- function(data, label = "") {
  fe_str <- fe_specs[["numb_clauses"]]
  
  # Post-reform
  m_post <- feols(
    as.formula(paste0("numb_clauses ~ post_treat_cba:", conn, " | ", fe_str)),
    data = data %>% filter(!is.na(cba_period)), cluster = ~identificad)
  
  # --- Pooled placebo pre-trend test ---
  m_pre <- feols(
    as.formula(paste0("numb_clauses ~ pre_treat_cba:", conn, " | ", fe_str)),
    data = data %>% filter(!is.na(cba_period), cba_period <= 2),
    cluster = ~identificad)
  
  # --- Joint Wald test from event study ---
  m_es <- feols(
    as.formula(paste0("numb_clauses ~ i(cba_period, ", conn, ", ref = 2) | ", fe_str)),
    data = data %>% filter(!is.na(cba_period)), cluster = ~identificad)
  
  w <- wald(m_es, paste0("cba_period::1:", conn))
  
  cn_post <- grep(conn, names(coef(m_post)), value = TRUE)[1]
  cn_pre  <- grep(conn, names(coef(m_pre)),  value = TRUE)[1]
  
  tibble(label = label, outcome = "numb_clauses",
         b_post  = coef(m_post)[[cn_post]],
         se_post = se(m_post)[[cn_post]],
         p_post  = pvalue(m_post)[[cn_post]],
         b_pre_pooled  = coef(m_pre)[[cn_pre]],
         se_pre_pooled = se(m_pre)[[cn_pre]],
         p_pre_pooled  = pvalue(m_pre)[[cn_pre]],
         p_pre_joint   = w$p,
         n_obs = m_post$nobs)
}

# =============================================================================
# 7. TABLE 2 — DIRECT EFFECTS (Panels A & B)
# =============================================================================

tab2a <- bind_rows(
  est_direct("lr_remdezr_w",   direct_a, "Panel A"),
  est_direct("lr_remdezr_h_w", direct_a, "Panel A"),
  est_direct("l_firm_emp",     direct_a, "Panel A"),
  est_direct_clauses(direct_a, "Panel A")
)

tab2b <- bind_rows(
  est_direct("lr_remdezr_w",   direct_b, "Panel B"),
  est_direct("lr_remdezr_h_w", direct_b, "Panel B"),
  est_direct("l_firm_emp",     direct_b, "Panel B"),
  est_direct_clauses(direct_b, "Panel B")
)

tab2 <- bind_rows(tab2a, tab2b)

# =============================================================================
# 8. FIGURE 1 — DIRECT EFFECTS EVENT STUDY (Log Wages)
# =============================================================================

es_direct <- feols(
  as.formula(paste0(
    "lr_remdezr_w ~ i(year, treat_ultra, ref = 2011) | ",
    fe_specs[["lr_remdezr_w"]])),
  data = direct_a, cluster = ~identificad)

# Joint pre-trend test for the figure annotation
w_direct <- wald(es_direct, "year::20(09|10):treat_ultra")

es_df <- as.data.frame(coeftable(es_direct)) %>%
  tibble::rownames_to_column("term") %>%
  filter(grepl("year::", term)) %>%
  mutate(year  = as.integer(gsub("year::([0-9]+):treat_ultra", "\\1", term)),
         ci_lo = Estimate - 1.96 * `Std. Error`,
         ci_hi = Estimate + 1.96 * `Std. Error`)

es_df <- bind_rows(
  es_df,
  tibble(term = NA_character_, Estimate = 0, `Std. Error` = 0,
         `t value` = NA_real_, `Pr(>|t|)` = NA_real_,
         year = 2011L, ci_lo = 0, ci_hi = 0)
) %>% arrange(year)

pooled_direct <- tab2a %>% filter(outcome == "lr_remdezr_w")

fig1 <- ggplot(es_df, aes(x = year, y = Estimate)) +
  geom_hline(yintercept = 0, color = "gray50") +
  geom_vline(xintercept = 2011.75, linetype = "dashed", color = "red") +
  geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi), width = 0.15, color = "blue") +
  geom_point(color = "blue", size = 2.5) +
  annotate("text", x = 2015, y = max(es_df$ci_hi) * 0.95,
           label = sprintf("%.4f (%.4f)",
                           pooled_direct$b_post, pooled_direct$se_post),
           color = "blue", size = 3.5) +
  labs(x = NULL, y = "Dynamic DiD coefficients",
       title = "Figure 1: Direct Effects on Log Wages",
       caption = sprintf("P-value for pre-trend test = %.3f", w_direct$p)) +
  scale_x_continuous(breaks = 2009:2016) +
  theme_minimal() +
  theme(panel.grid.minor = element_blank())

print(fig1)

# =============================================================================
# 9. TABLE 3 — SPILLOVER EFFECTS
# =============================================================================

tab3 <- bind_rows(
  est_spill("lr_remdezr_w",   spill, label = "Spillover"),
  est_spill("lr_remdezr_h_w", spill, label = "Spillover"),
  est_spill("l_firm_emp",     spill, label = "Spillover"),
  est_spill_clauses(spill, label = "Spillover")
)

# =============================================================================
# 10. FIGURE 2 — SPILLOVER EVENT STUDY (Log Wages)
# =============================================================================

es_spill <- feols(
  as.formula(paste0(
    "lr_remdezr_w ~ i(year, totaltreat_pw_norm, ref = 2011) | ",
    fe_specs[["lr_remdezr_w"]])),
  data = spill, cluster = ~identificad)

w_spill <- wald(es_spill, paste0("year::20(09|10):", conn))

es_sp_df <- as.data.frame(coeftable(es_spill)) %>%
  tibble::rownames_to_column("term") %>%
  filter(grepl("year::", term)) %>%
  mutate(year  = as.integer(gsub("year::([0-9]+):.*", "\\1", term)),
         ci_lo = Estimate - 1.96 * `Std. Error`,
         ci_hi = Estimate + 1.96 * `Std. Error`)

es_sp_df <- bind_rows(
  es_sp_df,
  tibble(term = NA_character_, Estimate = 0, `Std. Error` = 0,
         `t value` = NA_real_, `Pr(>|t|)` = NA_real_,
         year = 2011L, ci_lo = 0, ci_hi = 0)
) %>% arrange(year)

pooled_spill <- tab3 %>% filter(outcome == "lr_remdezr_w")

fig2 <- ggplot(es_sp_df, aes(x = year, y = Estimate)) +
  geom_hline(yintercept = 0, color = "gray50") +
  geom_vline(xintercept = 2011.75, linetype = "dashed", color = "red") +
  geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi), width = 0.15, color = "blue") +
  geom_point(color = "blue", shape = 18, size = 3) +
  annotate("text", x = 2015, y = max(es_sp_df$ci_hi) * 0.85,
           label = sprintf("%.4f (%.4f)",
                           pooled_spill$b_post, pooled_spill$se_post),
           color = "blue", size = 3.5) +
  labs(x = NULL, y = "Dynamic DiD coefficients",
       title = "Figure 2: Spillover Effects on Log Wages",
       caption = sprintf("P-value for pre-trend test = %.3f", w_spill$p)) +
  scale_x_continuous(breaks = 2009:2016) +
  theme_minimal() +
  theme(panel.grid.minor = element_blank())

print(fig2)

# =============================================================================
# 11. TABLE 4 — SPILLOVER ROBUSTNESS TO UNION CONTROLS
# =============================================================================

tab4 <- bind_rows(
  est_spill("lr_remdezr_w", spill, label = "Baseline"),
  est_spill("lr_remdezr_w", spill,
            extra_fe = "mode_union^year",
            label = "Union FE x Year"),
  est_spill("lr_remdezr_w", spill,
            extra_rhs = "i(year, treat_union_exp_all)",
            label = "Union Exp (firm)"),
  est_spill("lr_remdezr_w", spill,
            extra_rhs = "i(year, union_emp_exp)",
            label = "Union Exp (wkrs)")
)


# =============================================================================
# Extra Table: Spillovers on hourly wages with union controls
# =============================================================================

tab5 <- bind_rows(
  est_spill("lr_remdezr_h_w", spill, label = "Baseline"),
  est_spill("lr_remdezr_h_w", spill,
            extra_fe = "mode_union^year",
            label = "Union FE x Year"),
  est_spill("lr_remdezr_h_w", spill,
            extra_rhs = "i(year, treat_union_exp_all)",
            label = "Union Exp (firm)"),
  est_spill("lr_remdezr_h_w", spill,
            extra_rhs = "i(year, union_emp_exp)",
            label = "Union Exp (wkrs)")
)

# =============================================================================
# PRINT ALL TABLES
# =============================================================================

print_table(tab2, "Table 2: Direct Effects")
print_table(tab3, "Table 3: Spillover Effects")
print_table(tab4, "Table 4: Spillover Robustness to Union Controls")
cat("\nDone.\n")



##### teste
# --- Diagnose pre-trend F-test for log employment (Panel A) -------------------
es_emp <- feols(
  as.formula(paste0(
    "l_firm_emp ~ i(year, treat_ultra, ref = 2011) | ",
    fe_specs[["l_firm_emp"]])),
  data = direct_a, cluster = ~identificad)

cat("\n--- Pre-treatment coefficients for log employment (Panel A) ---\n")
coefs <- coeftable(es_emp)
pre_rows <- grepl("year::(2009|2010)", rownames(coefs))
print(coefs[pre_rows, ])


# # =============================================================================
# # Extra: Union FE: Sample Re-comp vs Actual FE
# # =============================================================================
# PS: It seems like FE partially explains the effect attenuation for specs where that happens...
# ...Std errors also increase not only from reduction in sample but also from FE, as it removes part of the identifying variation. So it's not just about sample size, but also about what variation is left after controlling for union-year effects., the one that comes across Union cells
# 
# # Step 1: Check actual nobs from both models directly
# m_baseline <- feols(
#   as.formula(paste0("lr_remdezr_w ~ treat_year:", conn, " | ",
#                     fe_specs[["lr_remdezr_w"]])),
#   data = spill, cluster = ~identificad)
# 
# m_union_fe <- feols(
#   as.formula(paste0("lr_remdezr_w ~ treat_year:", conn, " | ",
#                     fe_specs[["lr_remdezr_w"]], " + mode_union^year")),
#   data = spill, cluster = ~identificad)
# 
# cat("\nBaseline nobs:", m_baseline$nobs, "\n")
# cat("Union FE nobs:", m_union_fe$nobs, "\n")
# cat("Difference:", m_baseline$nobs - m_union_fe$nobs, "\n")
# 
# # Step 2: Reconstruct the Union FE subsample by removing singleton union-year cells
# # fixest iteratively drops singletons, so we replicate that process
# spill_uf <- spill %>%
#   filter(!is.na(lr_remdezr_w), !is.na(.data[[conn]]), !is.na(mode_union))
# 
# # Iteratively remove singleton union-year cells (and any other FE singletons)
# # until stable — mirrors what fixest does internally
# changed <- TRUE
# while (changed) {
#   n_before <- nrow(spill_uf)
#   spill_uf <- spill_uf %>%
#     group_by(mode_union, year) %>%
#     filter(n() > 1) %>%
#     ungroup()
#   changed <- (nrow(spill_uf) < n_before)
# }
# 
# cat("Reconstructed Union FE sample:", nrow(spill_uf), "obs,",
#     n_distinct(spill_uf$identificad), "estabs\n")
# 
# # Step 3: Run baseline, then restricted sample without and with Union FE
# tab_union_decomp <- bind_rows(
#   est_spill("lr_remdezr_w", spill,
#             label = ""),
#   est_spill("lr_remdezr_w", spill_uf,
#             label = "FE sample, no FE"),
#   est_spill("lr_remdezr_w", spill_uf,
#             extra_fe = "mode_union^year",
#             label = "FE sample, with FE")
# )
# 
# print_table(tab_union_decomp,
#             "Decomposing Union FE effect: Sample vs. Control")



# # =============================================================================
# # Avg Connectivity by Pre-treatment Employment Bins
# # =============================================================================
# bar_df_full <- spill %>%
#   filter(year == 2009) %>%
#   filter(!is.na(firm_emp_pre), !is.na(totaltreat_pw_n)) %>%
#   mutate(emp_bin = floor(firm_emp_pre / 20) * 20) %>%
#   group_by(emp_bin) %>%
#   summarise(avg_conn = mean(totaltreat_pw_n, na.rm = TRUE),
#             n = n(), .groups = "drop")
# 
# fit <- lm(avg_conn ~ emp_bin, data = bar_df_full)
# slope <- coef(fit)[["emp_bin"]]
# se_slope <- summary(fit)$coefficients["emp_bin", "Std. Error"]
# 
# bar_df_plot <- bar_df_full %>% filter(emp_bin <= 1000)
# 
# fig_scatter <- ggplot(bar_df_plot, aes(x = emp_bin, y = avg_conn)) +
#   geom_point(aes(size = n), color = "steelblue", alpha = 0.7, show.legend = FALSE) +
#   geom_smooth(method = "lm", color = "red", linewidth = 0.8, se = TRUE, fill = "mistyrose") +
#   annotate("text", x = 600, y = 0.045,
#            label = sprintf("Slope: %.7f (%.7f)", slope, se_slope),
#            color = "red", size = 4, hjust = 0) +
#   coord_cartesian(ylim = c(0, 0.05)) +
#   scale_size_continuous(range = c(1, 8)) +
#   labs(x = "Pre-treatment Employment (level)",
#        y = "Avg. Connectivity to Treated (raw)",
#        title = "Average Connectivity by Establishment Size",
#        subtitle = "Spillover sample, binned means (bin width = 20)") +
#   theme_minimal() +
#   theme(panel.grid.minor = element_blank())
# 
# print(fig_scatter)
# 
# 
# # =============================================================================
# # Avg Employment by Pre-treatment Connectivity Bins
# # =============================================================================
# bar_df_full <- spill %>%
#   filter(year == 2009) %>%
#   filter(!is.na(firm_emp_pre), !is.na(totaltreat_pw_n)) %>%
#   mutate(conn_bin = floor(totaltreat_pw_n / 0.001) * 0.001) %>%
#   group_by(conn_bin) %>%
#   summarise(avg_emp = mean(firm_emp_pre, na.rm = TRUE),
#             n = n(), .groups = "drop")
# fit <- lm(avg_emp ~ conn_bin, data = bar_df_full)
# slope <- coef(fit)[["conn_bin"]]
# se_slope <- summary(fit)$coefficients["conn_bin", "Std. Error"]
# fig_scatter <- ggplot(bar_df_full, aes(x = conn_bin, y = avg_emp)) +
#   geom_point(aes(size = n), color = "steelblue", alpha = 0.7, show.legend = FALSE) +
#   geom_smooth(method = "lm", color = "red", linewidth = 0.8, se = TRUE, fill = "mistyrose") +
#   annotate("text", x = max(bar_df_full$conn_bin) * 0.5, y = max(bar_df_full$avg_emp) * 0.9,
#            label = sprintf("Slope: %.2f (%.2f)", slope, se_slope),
#            color = "red", size = 4, hjust = 0) +
#   scale_size_continuous(range = c(1, 8)) +
#   labs(x = "Connectivity to Treated (binned at 0.001)",
#        y = "Avg. Pre-treatment Employment",
#        title = "Average Employment by Connectivity to Treated",
#        subtitle = "Spillover sample, binned means (bin width = 0.001)") +
#   theme_minimal() +
#   theme(panel.grid.minor = element_blank())
# print(fig_scatter)


