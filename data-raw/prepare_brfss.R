# Rebuild data/brfss2024_extract_slim.csv.gz from the official 2024 BRFSS file.
#
# Source: CDC, 2024 BRFSS Survey Data and Documentation (public domain).
#   https://www.cdc.gov/brfss/annual_data/annual_2024.html
#
# Status: this script was written to document provenance but has NOT been run.
# The environment used to build this repository could not reach cdc.gov, so the
# committed extract comes from the course-provided CSV instead (see data/README.md).
#
# Note on rows: the course CSV covers state FIPS 1-24 and stops partway through
# Maryland. Rebuilding from the national file with keep_states = 1:24 gives the
# same jurisdictions but a complete Maryland sample, so row counts will differ
# slightly from the committed file. Set keep_states <- NULL for all states.
#
# Usage (from the repository root): Rscript data-raw/prepare_brfss.R

url <- "https://www.cdc.gov/brfss/annual_data/2024/files/LLCP2024XPT.zip"
keep_states <- 1:24
out_file <- "data/brfss2024_extract_slim.csv.gz"

keep_vars <- c(
  "_STATE", "_STSTR", "_PSU", "_LLCPWT",                 # survey design
  "DIABETE4", "PREDIAB2",                                 # outcome and related item
  "GENHLTH", "PHYSHLTH", "MENTHLTH", "CHECKUP1", "EXERANY2",
  "CVDINFR4", "CVDCRHD4", "CVDSTRK3", "CHCKDNY2", "_MICHD",
  "_AGE80", "_AGEG5YR", "_SEX", "_BMI5", "_EDUCAG", "_INCOMG1",
  "_SMOKER3", "_TOTINDA", "_RFHLTH", "_RACEGR3", "MEDCOST1"
)

tmp <- tempfile(fileext = ".zip")
utils::download.file(url, tmp, mode = "wb")
unzip_dir <- file.path(tempdir(), "brfss2024")
utils::unzip(tmp, exdir = unzip_dir)
# The XPT inside CDC zips has sometimes carried a trailing space in its name.
xpt <- list.files(unzip_dir, pattern = "XPT", full.names = TRUE, ignore.case = TRUE)[1]
stopifnot(!is.na(xpt))

if (requireNamespace("haven", quietly = TRUE)) {
  brfss <- as.data.frame(haven::read_xpt(xpt))
} else {
  brfss <- foreign::read.xport(xpt)
  # foreign prefixes names that start with an underscore with "X".
  names(brfss) <- sub("^X_", "_", names(brfss))
}

missing_vars <- setdiff(keep_vars, names(brfss))
if (length(missing_vars)) stop("Variables not found: ", paste(missing_vars, collapse = ", "))

slim <- brfss[, keep_vars]
if (!is.null(keep_states)) slim <- slim[slim[["_STATE"]] %in% keep_states, ]

con <- gzfile(out_file, "w")
utils::write.csv(slim, con, row.names = FALSE, na = "")
close(con)
message("Wrote ", nrow(slim), " rows x ", ncol(slim), " columns to ", out_file)
