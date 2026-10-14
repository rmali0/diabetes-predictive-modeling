# Recoding helpers for the 2024 BRFSS extract.
# Code conventions follow the 2024 BRFSS codebook (LLCP 2024): 77/99 or 7/9 are
# "don't know / refused", 88 means "none" for day counts, _BMI5 carries two
# implied decimals, and calculated variables use 9 for "don't know / missing".

# Diagnosed diabetes: 1 = yes. 3 = no and 4 = no (prediabetes/borderline) form
# the comparison group. 2 (gestational only), 7 and 9 are excluded as NA.
brfss_diabetes_outcome <- function(x) {
  x <- as.numeric(x)
  out <- ifelse(x == 1, "Yes", ifelse(x %in% c(3, 4), "No", NA_character_))
  factor(out, levels = c("Yes", "No"))
}

# PHYSHLTH / MENTHLTH: 1-30 days, 88 = none, 77/99 = don't know / refused.
brfss_days <- function(x) {
  x <- as.numeric(x)
  x[x %in% 88] <- 0
  x[x %in% c(77, 99)] <- NA
  x[!is.na(x) & (x < 0 | x > 30)] <- NA
  x
}

# _BMI5 is BMI x 100 (two implied decimals). Blank means missing in 2024; the
# 7777/9999 guard is kept for older-style extracts.
brfss_bmi <- function(x) {
  x <- as.numeric(x)
  x[x %in% c(7777, 9999)] <- NA
  x / 100
}

# Map valid codes to labels and keep everything else (don't know, refused,
# blank) as an explicit "Missing" level so nonresponse stays visible to models.
brfss_factor <- function(x, codes, labels, missing_label = "Missing") {
  stopifnot(length(codes) == length(labels))
  x <- as.numeric(x)
  out <- factor(ifelse(x %in% codes, x, NA), levels = codes, labels = labels)
  if (anyNA(out)) {
    out <- addNA(out)
    levels(out)[is.na(levels(out))] <- missing_label
  }
  out
}

yes_no <- list(codes = c(1, 2), labels = c("Yes", "No"))

# One row per predictor: readable name, BRFSS source variable, codes, labels.
# _TOTINDA, _RFHLTH and _MICHD were dropped because they are deterministic
# recodes of EXERANY2, GENHLTH and CVDINFR4/CVDCRHD4 already in the model.
brfss_factor_spec <- list(
  general_health = list(var = "GENHLTH", codes = 1:5,
                        labels = c("Excellent", "Very_good", "Good", "Fair", "Poor")),
  routine_checkup = list(var = "CHECKUP1", codes = c(1, 2, 3, 4, 8),
                         labels = c("Past_year", "Past_2_years", "Past_5_years",
                                    "Five_plus_years", "Never")),
  exercise_30days = c(var = "EXERANY2", yes_no),
  heart_attack = c(var = "CVDINFR4", yes_no),
  coronary_heart_disease = c(var = "CVDCRHD4", yes_no),
  stroke = c(var = "CVDSTRK3", yes_no),
  kidney_disease = c(var = "CHCKDNY2", yes_no),
  sex = list(var = "_SEX", codes = c(1, 2), labels = c("Male", "Female")),
  education_group = list(var = "_EDUCAG", codes = 1:4,
                         labels = c("No_HS", "HS_grad", "Some_college", "College_grad")),
  income_group = list(var = "_INCOMG1", codes = 1:7,
                      labels = c("Under_15k", "15k_25k", "25k_35k", "35k_50k",
                                 "50k_100k", "100k_200k", "200k_plus")),
  smoking_status = list(var = "_SMOKER3", codes = 1:4,
                        labels = c("Current_daily", "Current_some_days", "Former", "Never"))
)

brfss_numeric_vars <- c("age_years", "bmi", "physical_unhealthy_days", "mental_unhealthy_days")

# Build the analytic frame: outcome plus recoded predictors. No statistics are
# estimated here (no imputation, no scaling), so it is safe to run before the
# train/test split.
prepare_brfss <- function(raw) {
  raw <- as.data.frame(raw, check.names = FALSE)
  out <- data.frame(
    diabetes = brfss_diabetes_outcome(raw[["DIABETE4"]]),
    age_years = as.numeric(raw[["_AGE80"]]),
    bmi = brfss_bmi(raw[["_BMI5"]]),
    physical_unhealthy_days = brfss_days(raw[["PHYSHLTH"]]),
    mental_unhealthy_days = brfss_days(raw[["MENTHLTH"]])
  )
  for (name in names(brfss_factor_spec)) {
    spec <- brfss_factor_spec[[name]]
    out[[name]] <- brfss_factor(raw[[spec$var]], spec$codes, spec$labels)
  }
  out$state_fips <- as.integer(raw[["_STATE"]])
  out[!is.na(out$diabetes), , drop = FALSE]
}
