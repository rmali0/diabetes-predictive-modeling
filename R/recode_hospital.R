# Recoding helpers for the UCI Diabetes 130-US Hospitals data (1999-2008).

# "[70-80)" -> 75. Anything that is not a closed-open band returns NA.
age_band_midpoint <- function(x) {
  parts <- regmatches(x, regexec("^\\[(\\d+)-(\\d+)\\)$", x))
  vapply(parts, function(p) if (length(p) == 3) mean(as.numeric(p[2:3])) else NA_real_,
         numeric(1))
}

# Keep each patient's earliest encounter (lowest encounter_id). Repeat
# admissions of the same patient are correlated; keeping one row per patient
# means a random split can never put the same person in train and test.
first_encounter_per_patient <- function(df) {
  df <- df[order(df$encounter_id), , drop = FALSE]
  df[!duplicated(df$patient_nbr), , drop = FALSE]
}

# Lab result fields use "None" (or blank) when the test was not done.
lab_status <- function(x) {
  x <- as.character(x)
  x[is.na(x) | x %in% c("None", "")] <- "Not_measured"
  x
}

los_factor_vars <- c("race", "gender", "admission_type_id", "discharge_disposition_id",
                     "admission_source_id", "max_glu_serum", "A1Cresult", "change",
                     "diabetesMed", "insulin")

los_numeric_vars <- c("age_mid", "num_lab_procedures", "num_procedures", "num_medications",
                      "number_outpatient", "number_emergency", "number_inpatient",
                      "number_diagnoses")

# Build the analytic frame (one row per patient). Like prepare_brfss(), this
# estimates nothing from the data, so it can run before the split.
prepare_los <- function(raw) {
  raw <- as.data.frame(raw)
  raw[raw == "?"] <- NA
  df <- first_encounter_per_patient(raw)
  df <- df[!(df$gender %in% "Unknown/Invalid"), , drop = FALSE]

  out <- data.frame(time_in_hospital = as.numeric(df$time_in_hospital),
                    age_mid = age_band_midpoint(df$age))
  for (v in setdiff(los_numeric_vars, "age_mid")) out[[v]] <- as.numeric(df[[v]])

  race <- as.character(df$race)
  race[is.na(race)] <- "Missing"
  out$race <- race
  out$gender <- df$gender
  for (v in c("admission_type_id", "discharge_disposition_id", "admission_source_id")) {
    out[[v]] <- paste0("id_", df[[v]])
  }
  out$max_glu_serum <- lab_status(df$max_glu_serum)
  out$A1Cresult <- lab_status(df$A1Cresult)
  out$change <- df$change
  out$diabetesMed <- df$diabetesMed
  out$insulin <- df$insulin
  for (v in los_factor_vars) out[[v]] <- factor(out[[v]])
  out
}

# Collapse levels seen fewer than min_n times in training into "Other" (merged
# with an existing "Other" level if there is one). Test
# levels unseen in training also go to "Other", or to the most common training
# level when training has no "Other" rows (so no level is empty at fit time).
# Thresholds come from training data only.
lump_rare_levels <- function(train, test, vars, min_n = 30, other = "Other") {
  for (v in vars) {
    counts <- table(train[[v]])
    keep <- names(counts)[counts >= min_n]
    tr <- as.character(train[[v]])
    te <- as.character(test[[v]])
    tr[!(tr %in% keep)] <- other
    fallback <- if (other %in% tr) other else names(which.max(counts))
    te[!(te %in% c(keep, other))] <- fallback
    lv <- if (other %in% tr) unique(c(keep, other)) else keep
    train[[v]] <- factor(tr, levels = lv)
    test[[v]] <- factor(te, levels = lv)
  }
  list(train = train, test = test)
}
