rm(list = ls())
library(dplyr)
library(tidyverse)
library(haven)
library(ggplot2)
library(fixest)

# ============================================================================
# UNION SPILLOVERS — WAGE RESULTS WITH COMPOSITION-ADJUSTED OUTCOMES
#
# Produces: Direct effects (Panels A & B), Spillover effects, Event studies
# for four wage outcomes:
#   1. Log December wage        (lr_remdezr_w)
#   2. Log hourly wage          (lr_remdezr_h_w)
#   3. Residualized log wage    (lr_remdezr_resid)
#   4. Residualized log hourly  (lr_hourly_resid)
#
# Structure:
#   1. Load main data + Mincer residuals, merge
#   2. Variable creation (treatment timing, connectivity, bins)
#   3. Sample definitions
#   4. Specifications
#   5. Helpers & estimation functions
#   6. Results
# ============================================================================

rais_firm <- "/Users/gui.neri/Library/CloudStorage/OneDrive-NorthwesternUniversity/Research Projects/Org_Econ BR/UnionSpillovers/Gui_coding/Luis_og_files"

# =============================================================================
# 1. LOAD DATA
# =============================================================================

# --- Main analysis data ---
df <- readRDS(file.path(rais_firm,
                        "lagos_sample_sep24_pct_unionexp_ext_df2.rds"))

# --- Auxiliary datasets (same as main code) ---
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
  mutate(
    totalflows_pre_07_11 = rowMeans(cbind(totalflows_07_08, totalflows_08_09, totalflows_09_10, totalflows_10_11), na.rm = TRUE),
    totalflows_pre_09_11 = rowMeans(cbind(totalflows_09_10, totalflows_10_11), na.rm = TRUE),
    totalflows_pw_pre_07_11 = rowMeans(cbind(totalflows_pw_07_08, totalflows_pw_08_09, totalflows_pw_09_10, totalflows_pw_10_11), na.rm = TRUE),
    totalflows_pw_pre_09_11 = rowMeans(cbind(totalflows_pw_09_10, totalflows_pw_10_11), na.rm = TRUE)
  )

# Merge auxiliary datasets
df <- df %>%
  left_join(totalflows_pw_n_data %>% select(identificad, totalflows_pw_n),
            by = "identificad") %>%
  left_join(network_size %>% select(identificad, n_connected_4yr),
            by = "identificad") %>%
  left_join(turnover_data %>% select(-firm_emp, -l_firm_emp),
            by = c("identificad", "year")) %>%
  left_join(yearly_flows_data %>% select(identificad, totalflows_pre_07_11,
                                         totalflows_pre_09_11,
                                         totalflows_pw_pre_07_11,
                                         totalflows_pw_pre_09_11),
            by = "identificad")

rm(network_size, totalflows_pw_n_data, turnover_data, pre_avgs, yearly_flows_data)

# --- Mincer residuals (firm x year) ---
mincer <- read.csv(file.path(rais_firm, "mincer_residuals_firm_year.csv"))
# Ensure identificad format matches
mincer$identificad <- sprintf("%014.0f", as.numeric(mincer$identificad))
# year in mincer is numeric; coerce to integer to match df
mincer$year <- as.integer(mincer$year)

cat("Mincer residuals loaded:", nrow(mincer), "firm-year cells\n")

# Merge residualized outcomes onto the main panel
df <- df %>%
  left_join(
    mincer %>% select(identificad, year,
                      lr_remdezr_resid, lr_hourly_resid),
    by = c("identificad", "year")
  )

cat("Merge coverage (non-missing residualized wage):",
    sum(!is.na(df$lr_remdezr_resid)), "of", nrow(df), "rows\n")

rm(mincer)
gc()

# Keep only post-2009, Lagos sample
df <- df %>% filter(year >= 2009, lagos_sample_avg == 1)
cat("Full sample size:", nrow(df), "\n")

# =============================================================================
# 2. VARIABLE CREATION
# =============================================================================

# --- 2a. Treatment timing indicators ----------------------------------------
df <- df %>%
  mutate(placebo_year = as.integer(year < 2011),
         treat_year   = as.integer(year >= 2012))

# --- 2b. Scale connectivity to 90th percentile ------------------------------
p90_conn <- df %>%
  filter(treat_ultra == 0, in_balanced_panel == 1, year == 2009) %>%
  summarise(p90 = quantile(totaltreat_pw_n, 0.90, na.rm = TRUE)) %>%
  pull(p90)

df <- df %>% mutate(totaltreat_pw_norm = totaltreat_pw_n / p90_conn)

# --- 2c. Pre-treatment averages (2009-2011) ----------------------------------
# Raw wage outcomes (already in main code)
for (v in c("lr_remdezr_w", "lr_remdezr_h_w", "l_firm_emp", "turnover")) {
  pre_name <- paste0(v, "_pre")
  df <- df %>%
    group_by(identificad) %>%
    mutate(!!pre_name := mean(.data[[v]][year %in% 2009:2011], na.rm = TRUE)) %>%
    ungroup()
}

# Residualized wage outcomes — pre-treatment averages
for (v in c("lr_remdezr_resid", "lr_hourly_resid")) {
  pre_name <- paste0(v, "_pre")
  df <- df %>%
    group_by(identificad) %>%
    mutate(!!pre_name := mean(.data[[v]][year %in% 2009:2011], na.rm = TRUE)) %>%
    ungroup()
}

# Pre-treatment average firm size
df <- df %>%
  group_by(identificad) %>%
  mutate(firm_emp_pre = mean(firm_emp[year %in% 2009:2011], na.rm = TRUE)) %>%
  ungroup() %>%
  mutate(tf_per_emp_pre = if_else(firm_emp_pre > 0,
                                  totalflows_n / (4 * firm_emp_pre), NA_real_))

# --- 2d. Control bins ---------------------------------------------------------
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

# Bins for raw outcomes and controls
for (v in c("lr_remdezr_w_pre", "lr_remdezr_h_w_pre", "l_firm_emp_pre",
            "turnover_pre", "totalflows_pw_n", "n_connected_4yr",
            "churn_u_pre", "churn_rate_u_pre", "separation_rate_u_pre",
            "totalflows_pre_07_11", "totalflows_pre_09_11",
            "totalflows_pw_pre_07_11", "totalflows_pw_pre_09_11",
            "totalflows_n", "tf_per_emp_pre")) {
  if (v %in% names(df)) df <- make_bins(df, v)
}

# Bins for residualized outcomes
for (v in c("lr_remdezr_resid_pre", "lr_hourly_resid_pre")) {
  if (v %in% names(df)) df <- make_bins(df, v)
}

# =============================================================================
# 3. SAMPLE DEFINITIONS
# =============================================================================

# Spillover: all untreated, balanced panel
spill <- df %>% filter(treat_ultra == 0, in_balanced_panel == 1)

# Direct A: treated + untreated with zero connectivity
direct_a <- df %>%
  filter(in_balanced_panel == 1,
         treat_ultra == 1 | (treat_ultra == 0 & totaltreat_pw_n == 0))

# Direct B: treated + all untreated
direct_b <- df %>% filter(in_balanced_panel == 1)

cat("Direct A:", n_distinct(direct_a$identificad), "estabs\n")
cat("Direct B:", n_distinct(direct_b$identificad), "estabs\n")
cat("Spillover:", n_distinct(spill$identificad), "estabs\n")

conn <- "totaltreat_pw_norm"

# =============================================================================
# 4. SPECIFICATIONS
# =============================================================================

base_controls_year <- "identificad + industry1^year + mode_base_month^year +
                       microregion^year"

# Raw wage outcomes use their own pre-treatment average bins;
# residualized outcomes use the residualized pre-treatment average bins.
# All share the same firm size and flow controls.
fe_specs <- list(
  lr_remdezr_w   = paste(base_controls_year,
                         "+ lr_remdezr_w_pre4^year + l_firm_emp_pre4^year + totalflows_pw_pre_07_114^year"),
  lr_remdezr_h_w = paste(base_controls_year,
                         "+ lr_remdezr_h_w_pre4^year + l_firm_emp_pre4^year + totalflows_pw_pre_07_114^year"),
  lr_remdezr_resid = paste(base_controls_year,
                           "+ lr_remdezr_resid_pre4^year + l_firm_emp_pre4^year + totalflows_pw_pre_07_114^year"),
  lr_hourly_resid  = paste(base_controls_year,
                           "+ lr_hourly_resid_pre4^year + l_firm_emp_pre4^year + totalflows_pw_pre_07_114^year")
)

# =============================================================================
# 5. HELPERS & ESTIMATION FUNCTIONS
# =============================================================================

stars_fn <- function(p) {
  case_when(p < 0.01 ~ "***", p < 0.05 ~ "**", p < 0.10 ~ "*", TRUE ~ "")
}

print_table <- function(tab, title = "") {
  cat("\n", strrep("=", 100), "\n")
  cat(" ", title, "\n")
  cat(strrep("-", 100), "\n")
  cat(sprintf("  %-12s %-22s %13s %13s %13s %8s\n",
              "Panel", "Outcome", "Post x Treat",
              "Pooled Pre", "Joint F pval", "N"))
  cat(strrep("-", 100), "\n")
  for (i in seq_len(nrow(tab))) {
    r <- tab[i, ]
    cat(sprintf("  %-12s %-22s  %7.4f%s    %7.4f%s      [%5.3f]    %s\n",
                r$label, r$outcome,
                r$b_post, stars_fn(r$p_post),
                r$b_pre_pooled, stars_fn(r$p_pre_pooled),
                r$p_pre_joint,
                format(r$n_obs, big.mark = ",")))
    cat(sprintf("  %36s (%6.4f)     (%6.4f)\n", "", r$se_post, r$se_pre_pooled))
  }
  cat(strrep("=", 100), "\n\n")
}

# --- Direct effects (pooled DiD) ---------------------------------------------
est_direct <- function(outcome, data, label = "") {
  fe_str <- fe_specs[[outcome]]
  
  m_post <- feols(
    as.formula(paste0(outcome, " ~ treat_ultra:treat_year | ", fe_str)),
    data = data, cluster = ~identificad)
  
  m_pre <- feols(
    as.formula(paste0(outcome, " ~ treat_ultra:placebo_year | ", fe_str)),
    data = data %>% filter(year <= 2011), cluster = ~identificad)
  
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

# --- Spillover effects (continuous connectivity) ------------------------------
est_spill <- function(outcome, data, label = "") {
  fe_str <- fe_specs[[outcome]]
  
  rhs_post <- paste0("treat_year:", conn)
  rhs_pre  <- paste0("placebo_year:", conn)
  
  m_post <- feols(
    as.formula(paste0(outcome, " ~ ", rhs_post, " | ", fe_str)),
    data = data, cluster = ~identificad)
  
  m_pre <- feols(
    as.formula(paste0(outcome, " ~ ", rhs_pre, " | ", fe_str)),
    data = data %>% filter(year <= 2011), cluster = ~identificad)
  
  rhs_es <- paste0("i(year, ", conn, ", ref = 2011)")
  m_es <- feols(
    as.formula(paste0(outcome, " ~ ", rhs_es, " | ", fe_str)),
    data = data, cluster = ~identificad)
  
  w <- wald(m_es, paste0("year::20(09|10):", conn))
  
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

# =============================================================================
# 6. RESULTS
# =============================================================================

outcomes_wage <- c("lr_remdezr_w", "lr_remdezr_h_w",
                   "lr_remdezr_resid", "lr_hourly_resid")

# --- Direct Effects Panel A (zero-connectivity controls) ---------------------
tab_a <- bind_rows(lapply(outcomes_wage, est_direct,
                          data = direct_a, label = "Panel A"))

# --- Direct Effects Panel B (all controls) -----------------------------------
tab_b <- bind_rows(lapply(outcomes_wage, est_direct,
                          data = direct_b, label = "Panel B"))

# --- Spillover Effects -------------------------------------------------------
tab_spill <- bind_rows(lapply(outcomes_wage, est_spill,
                              data = spill, label = "Spillover"))

# =============================================================================
# 7. EVENT STUDIES (Log Wages — raw and residualized)
# =============================================================================

make_es_plot <- function(outcome, data, fe_str, treat_var, wald_pattern,
                         pooled_tab, title_str) {
  
  m_es <- feols(
    as.formula(paste0(outcome, " ~ i(year, ", treat_var, ", ref = 2011) | ", fe_str)),
    data = data, cluster = ~identificad)
  
  w <- wald(m_es, wald_pattern)
  
  es_df <- as.data.frame(coeftable(m_es)) %>%
    tibble::rownames_to_column("term") %>%
    filter(grepl("year::", term)) %>%
    mutate(year  = as.integer(gsub("year::([0-9]+):.*", "\\1", term)),
           ci_lo = Estimate - 1.96 * `Std. Error`,
           ci_hi = Estimate + 1.96 * `Std. Error`)
  
  es_df <- bind_rows(
    es_df,
    tibble(term = NA_character_, Estimate = 0, `Std. Error` = 0,
           `t value` = NA_real_, `Pr(>|t|)` = NA_real_,
           year = 2011L, ci_lo = 0, ci_hi = 0)
  ) %>% arrange(year)
  
  pooled_row <- pooled_tab %>% filter(outcome == !!outcome)
  
  ggplot(es_df, aes(x = year, y = Estimate)) +
    geom_hline(yintercept = 0, color = "gray50") +
    geom_vline(xintercept = 2011.75, linetype = "dashed", color = "red") +
    geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi), width = 0.15, color = "blue") +
    geom_point(color = "blue", size = 2.5) +
    annotate("text", x = 2015, y = max(es_df$ci_hi) * 0.95,
             label = sprintf("%.4f (%.4f)", pooled_row$b_post, pooled_row$se_post),
             color = "blue", size = 3.5) +
    labs(x = NULL, y = "Dynamic DiD coefficients",
         title = title_str,
         caption = sprintf("P-value for pre-trend test = %.3f", w$p)) +
    scale_x_continuous(breaks = 2009:2016) +
    theme_minimal() +
    theme(panel.grid.minor = element_blank())
}

# Direct effects event studies (Panel A)
fig_direct_raw <- make_es_plot(
  "lr_remdezr_w", direct_a, fe_specs[["lr_remdezr_w"]],
  "treat_ultra", "year::20(09|10):treat_ultra", tab_a,
  "Direct Effects: Log Wages (Raw)")

fig_direct_resid <- make_es_plot(
  "lr_remdezr_resid", direct_a, fe_specs[["lr_remdezr_resid"]],
  "treat_ultra", "year::20(09|10):treat_ultra", tab_a,
  "Direct Effects: Log Wages (Residualized)")

# Spillover event studies
fig_spill_raw <- make_es_plot(
  "lr_remdezr_w", spill, fe_specs[["lr_remdezr_w"]],
  conn, paste0("year::20(09|10):", conn), tab_spill,
  "Spillover Effects: Log Wages (Raw)")

fig_spill_resid <- make_es_plot(
  "lr_remdezr_resid", spill, fe_specs[["lr_remdezr_resid"]],
  conn, paste0("year::20(09|10):", conn), tab_spill,
  "Spillover Effects: Log Wages (Residualized)")

print(fig_direct_raw)
print(fig_direct_resid)
print(fig_spill_raw)
print(fig_spill_resid)

# =============================================================================
# 8. PRINT TABLES
# =============================================================================

print_table(bind_rows(tab_a, tab_b),
            "Direct Effects: Raw and Residualized Wages")

print_table(tab_spill,
            "Spillover Effects: Raw and Residualized Wages")

cat("\nDone.\n")