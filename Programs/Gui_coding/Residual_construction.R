rm(list = ls())
library(dplyr)
library(tidyverse)
library(haven)
library(ggplot2)
library(fixest)
library(arrow)

### ============================================================
### Residualize log wages on worker characteristics (Mincer FE)
### then collapse to firm × year means.
###
### Two outcomes:
###   1. Log December wage  (lr_remdezr)
###   2. Log hourly wage    (lr_hourly = log(remdezr / (horascontr * 4.33)))
###
### Specification:
###   outcome ~ 1 | race_group^grinstrucao^genero^year[age1, age2, age3, age4]
###
### Each race × education × gender × year cell gets its own intercept
### AND its own 4th-degree age polynomial (~1,000 intercepts + ~4,000
### slope parameters). No occupation, no tenure.
###
### Notes on speed choices:
###   - vcov = "iid": we only need residuals, not inference.
###   - lean = TRUE: discard large internal fixest objects to reduce memory.
### ============================================================

# --- Paths ---
rais_firm <- "/Users/gui.neri/Library/CloudStorage/OneDrive-NorthwesternUniversity/Research Projects/Org_Econ BR/UnionSpillovers/Gui_coding/Luis_og_files"
out_csv   <- file.path(rais_firm, "mincer_residuals_firm_year.csv")

# --- Load worker-level panel ---
cat("Loading parquet...\n")
df <- read_parquet(file.path(rais_firm, "worker_panel_lagos.parquet"))

# Keeping only used variables
df <- df %>%
  select(identificad, PIS, remdezr, horascontr, genero, raca_cor,
         grinstrucao, dtnascimento, age, lr_remdezr, year,
         race_group)
gc()

# --- Categorical FE variables: convert to factor ---
fe_vars <- c("grinstrucao", "race_group", "genero")

df <- df %>%
  mutate(across(all_of(fe_vars), as.factor),
         year = as.factor(year))

# --- Ensure age is numeric, then pre-compute polynomials ---
df <- df %>%
  mutate(
    age_num = as.numeric(age),
    age1 = age_num,  age2 = age_num^2,  age3 = age_num^3,  age4 = age_num^4
  )

# --- Construct log hourly wage ---
# Monthly wage (remdezr) divided by approximate monthly hours (weekly hours × 4.33).
# Set to NA when either input is non-positive.
df <- df %>%
  mutate(lr_hourly = if_else(
    horascontr > 0 & remdezr > 0,
    log(remdezr / (horascontr * 4.33)),
    NA_real_
  ))

# --- FE formula ---
fe_formula <- "race_group^grinstrucao^genero^year[age1, age2, age3, age4]"

# Variables that must be non-missing for estimation
required_vars <- c(fe_vars, "age_num")


### ============================================================
### Helper function: run one Mincer regression, extract residuals,
### collapse to firm × year means.
### ============================================================

run_mincer <- function(data, outcome_var, label) {
  
  cat(sprintf("\n%s\nOutcome: %s\n%s\n", strrep("=", 60), label, strrep("=", 60)))
  
  # --- Drop rows with missing outcome or FE / polynomial inputs ---
  df_est <- data %>%
    filter(!is.na(.data[[outcome_var]])) %>%
    drop_na(all_of(required_vars))
  
  cat(sprintf("  Estimation sample: %s rows (dropped %s)\n",
              format(nrow(df_est), big.mark = ","),
              format(nrow(data) - nrow(df_est), big.mark = ",")))
  
  # --- Build and run the fixest regression ---
  fml <- as.formula(paste0(outcome_var, " ~ 1 | ", fe_formula))
  cat("  Formula:", deparse(fml), "\n")
  cat("  Running feols...\n")
  t1 <- Sys.time()
  
  model <- feols(fml, data = df_est, vcov = "iid", lean = TRUE)
  
  cat(sprintf("  feols done in %.1f min\n", as.numeric(difftime(Sys.time(), t1, units = "mins"))))
  cat(sprintf("  Observations used by fixest: %d\n", model$nobs))
  
  # --- Handle singleton removal ---
  kept_idx <- model$obs_selection$obsRemoved
  if (!is.null(kept_idx) && length(kept_idx) > 0) {
    df_est <- df_est[-kept_idx, ]
    cat(sprintf("  Dropped %d singleton/NA rows by fixest\n", length(kept_idx)))
  }
  
  # --- Extract residuals (now aligned with df_est) ---
  resid_col <- paste0(outcome_var, "_resid")
  df_est[[resid_col]] <- residuals(model)
  
  cat(sprintf("  Residual mean:  %.6f  (should be ~0)\n", mean(df_est[[resid_col]])))
  cat(sprintf("  Residual sd:    %.4f\n", sd(df_est[[resid_col]])))
  cat(sprintf("  Raw outcome sd: %.4f\n", sd(df_est[[outcome_var]])))
  
  # --- Collapse to firm × year ---
  mean_col <- paste0(outcome_var, "_mean")
  n_col    <- paste0("n_workers_", label)
  
  firm_year <- df_est %>%
    group_by(identificad, year) %>%
    summarise(
      !!resid_col := mean(.data[[resid_col]], na.rm = TRUE),
      !!mean_col  := mean(.data[[outcome_var]], na.rm = TRUE),
      !!n_col     := n(),
      .groups = "drop"
    )
  
  cat(sprintf("  Firm-year cells: %s\n", format(nrow(firm_year), big.mark = ",")))
  cat(sprintf("  Unique firms:    %s\n", format(n_distinct(firm_year$identificad), big.mark = ",")))
  cat(sprintf("  Years covered:   %s\n", paste(sort(unique(firm_year$year)), collapse = ", ")))
  cat("\n  Collapsed residual summary:\n")
  print(summary(firm_year[[resid_col]]))
  
  return(firm_year)
}


### ============================================================
### Run for both outcomes
### ============================================================

# 1. Log December wage
fyr_dezr   <- run_mincer(df, "lr_remdezr", "dezr")

# 2. Log hourly wage
fyr_hourly <- run_mincer(df, "lr_hourly", "hourly")

### ============================================================
### Merge the two firm-year panels and save
### ============================================================

out <- full_join(fyr_dezr, fyr_hourly, by = c("identificad", "year"))

cat(sprintf("\nFinal merged dataset: %s rows\n", format(nrow(out), big.mark = ",")))

# Export csv
write_csv(out, out_csv)
