# Data

Both files are committed gzipped so the analyses run from a fresh clone.

## `brfss2024_extract_slim.csv.gz`

- **Source:** Centers for Disease Control and Prevention, Behavioral Risk Factor
  Surveillance System (BRFSS), 2024 combined landline and cell phone data,
  <https://www.cdc.gov/brfss/annual_data/annual_2024.html>.
- **License:** BRFSS data are produced by a US federal agency and are in the
  public domain.
- **Size:** 167,655 rows x 27 columns, 3.9 MB gzipped.
- **Coverage:** this is a column subset of the CSV provided for the course, not
  the national file. It covers 21 jurisdictions only, state FIPS codes 1 to 24:
  Alabama, Alaska, Arizona, Arkansas, California, Colorado, Connecticut,
  Delaware, District of Columbia, Florida, Georgia, Hawaii, Idaho, Illinois,
  Indiana, Iowa, Kansas, Kentucky, Louisiana, Maine and Maryland. The course
  file appears to be the first part of the national file cut off partway
  through Maryland (Maryland's final weights sum to 2.8 million, far below its
  adult population), so the Maryland sample is incomplete. The analysis keeps
  Maryland for modeling and leaves it out of survey-weighted estimates.
- **Columns:** survey design variables (`_STATE`, `_STSTR`, `_PSU`, `_LLCPWT`),
  the outcome `DIABETE4`, and the predictors listed in `R/recode_brfss.R`.
  `PREDIAB2`, `_AGEG5YR`, `_RACEGR3` and `MEDCOST1` are included in the extract
  but not used by the models.
- **Rebuilding:** `data-raw/prepare_brfss.R` downloads the national
  `LLCP2024XPT.zip` from CDC and writes the same columns. It has not been run,
  because the machine used to build this repository could not reach cdc.gov.
  Rebuilding from the national file gives a complete Maryland sample, so row
  counts will differ slightly.
- **Codebook:** the 2024 LLCP codebook, linked from the CDC page above, gives
  the value codes used in `R/recode_brfss.R`.

## `diabetic_data.csv.gz`

- **Source:** Clore J, Cios K, DeShazo J, Strack B. *Diabetes 130-US Hospitals for
  Years 1999-2008* [dataset]. UCI Machine Learning Repository, 2014.
  <https://doi.org/10.24432/C5230J>, <https://archive.ics.uci.edu/dataset/296>.
- **Original study:** Strack B, DeShazo JP, Gennings C, et al. Impact of HbA1c
  measurement on hospital readmission rates: analysis of 70,000 clinical
  database patient records. *BioMed Research International*. 2014;2014:781670.
- **License:** Creative Commons Attribution 4.0 International (CC BY 4.0).
- **Size:** 101,766 encounters x 50 columns, 3.2 MB gzipped. This is
  `diabetic_data.csv` as distributed by UCI, gzipped (row and column counts
  match the UCI description). Missing values are coded `?`.
- **Rebuilding:** download the dataset zip from the UCI page above, extract
  `diabetic_data.csv`, and run `gzip -9 diabetic_data.csv`.
