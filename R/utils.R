# Small project utilities shared by both analyses.

# Walk up from the working directory until run_all.R is found, so the same code
# works when knitting from analysis/ and when testing from the repository root.
repo_root <- function(start = getwd()) {
  path <- normalizePath(start, mustWork = TRUE)
  while (!file.exists(file.path(path, "run_all.R"))) {
    parent <- dirname(path)
    if (identical(parent, path)) stop("Could not find the repository root (run_all.R).")
    path <- parent
  }
  path
}

repo_path <- function(...) file.path(repo_root(), ...)

# Cap threads at 4 (or the number of cores, if fewer). Override with N_THREADS.
n_threads <- function() {
  env <- Sys.getenv("N_THREADS", "")
  if (nzchar(env)) return(as.integer(env))
  as.integer(min(4L, parallel::detectCores(logical = TRUE), na.rm = TRUE))
}

write_table <- function(df, name, digits = 4) {
  num <- vapply(df, is.numeric, logical(1))
  df[num] <- lapply(df[num], round, digits = digits)
  utils::write.csv(df, file.path(outputs_dir("tables"), paste0(name, ".csv")), row.names = FALSE)
  invisible(df)
}

fmt_num <- function(x, digits = 3) {
  x <- round(x, digits)
  x[x == 0] <- 0  # drop the sign from negative zero
  formatC(x, format = "f", digits = digits, big.mark = ",")
}
fmt_int <- function(x) formatC(x, format = "d", big.mark = ",")
fmt_pct <- function(x, digits = 1) paste0(formatC(100 * x, format = "f", digits = digits), "%")

# QUICK=1 runs a small subsample with fewer trees, for checking that the
# pipeline works end to end. Results from a quick run are not the reported ones.
quick_run <- function() identical(Sys.getenv("QUICK"), "1")

# Quick runs write to a temporary folder so they never overwrite reported outputs.
outputs_dir <- function(kind) {
  base <- if (quick_run()) file.path(tempdir(), "quick-outputs") else repo_path("outputs")
  path <- file.path(base, kind)
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  path
}
