# ------------------------------------------------------------------------------
# run_all.R -- reproduce Tables A6, A7 (core specification) and A8.
#
#   cd within_firm_final && Rscript run_all.R
#
# Writes to output/:
#   a6_group{,_hw}.csv  a6_partition{,_hw}.csv  a7{,_hw}.csv  a8{,_hw}.csv
#
# Then build the LaTeX and the PDF:
#   python3 scripts/05b_make_tables_within_firm.py
#   python3 scripts/build_pdf.py
# ------------------------------------------------------------------------------

source("R/00_config.R")
source("R/01_functions.R")
source("R/02_build.R")
source("R/03_estimate.R")
source("R/04_engine.R")

setFixest_notes(FALSE)
t0 <- Sys.time()

msg("")
msg("=== monthly wages  -> a6/a7/a8.csv     (Tables A6, A7, A8) ===")
run_within_firm("lr_remdezr_w",   "lr_remdezr_layer",   "")

msg("")
msg("=== hourly wages   -> a6/a7/a8_hw.csv  (hourly counterparts) ===")
run_within_firm("lr_remdezr_h_w", "lr_remdezr_h_layer", "_hw")

msg("")
msg("elapsed: %.1f min", as.numeric(difftime(Sys.time(), t0, units = "mins")))
msg("next: python3 scripts/05b_make_tables_within_firm.py && python3 scripts/build_pdf.py")
