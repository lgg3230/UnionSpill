# ------------------------------------------------------------------------------
# 00_config.R -- paths and data access for the self-contained core replication.
#
# Inputs are the Stata files in ./data, copied verbatim from the replication
# package. Nothing else is required: no cache, no prior run, no other folder.
#
# Inputs live in ./data, copied verbatim from the replication package. Override
# with the WF_DATA environment variable if you keep them elsewhere.
# ------------------------------------------------------------------------------

suppressMessages({
  library(data.table)
  library(fixest)
  library(haven)
  library(igraph)
})

ROOT <- normalizePath(getwd())
if (!dir.exists(file.path(ROOT, "R")))
  stop("Run from the within_firm_final/ directory: Rscript run_all.R")

DATA_DIR <- Sys.getenv("WF_DATA", unset = normalizePath(
  file.path(ROOT, "data"), mustWork = FALSE))
OUT   <- file.path(ROOT, "output")
CHECK <- file.path(ROOT, "check")
dir.create(OUT, showWarnings = FALSE); dir.create(CHECK, showWarnings = FALSE)

if (!dir.exists(DATA_DIR))
  stop(sprintf("DATA_DIR not found: %s\nSet WF_DATA to the directory holding the .dta inputs.",
               DATA_DIR))

msg <- function(...) cat(sprintf(...), "\n", sep = "")

# --- data access --------------------------------------------------------------
# Read a Stata file once and memoise it for the session. haven returns labelled
# vectors for some columns; strip the labels so comparisons behave like Stata's.
.DATA_CACHE <- new.env(parent = emptyenv())

read_data <- function(stem, cols = NULL) {
  key <- paste0(stem, "|", paste(cols, collapse = ","))
  if (!is.null(.DATA_CACHE[[key]])) return(copy(.DATA_CACHE[[key]]))
  f <- file.path(DATA_DIR, paste0(stem, ".dta"))
  if (!file.exists(f)) stop("missing input: ", f)
  x <- if (is.null(cols)) read_dta(f) else read_dta(f, col_select = all_of(cols))
  setDT(x)
  for (v in names(x))
    if (inherits(x[[v]], "haven_labelled")) set(x, j = v, value = as.vector(x[[v]]))
  .DATA_CACHE[[key]] <- x
  copy(x)
}

read_csv_input <- function(stem, ...) {
  f <- file.path(DATA_DIR, paste0(stem, ".csv"))
  if (!file.exists(f)) stop("missing input: ", f)
  fread(f, ...)
}

msg("data directory : %s", DATA_DIR)
msg("output         : %s", OUT)
