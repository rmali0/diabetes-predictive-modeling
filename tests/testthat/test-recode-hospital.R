test_that("age bands map to midpoints", {
  expect_equal(age_band_midpoint(c("[0-10)", "[70-80)", "[90-100)")), c(5, 75, 95))
  expect_true(is.na(age_band_midpoint("70-80")))
})

test_that("only the first encounter per patient is kept", {
  df <- data.frame(encounter_id = c(30, 10, 20), patient_nbr = c(1, 1, 2))
  out <- first_encounter_per_patient(df)
  expect_equal(out$encounter_id, c(10, 20))
})

test_that("lab fields map None and blanks to Not_measured", {
  expect_equal(lab_status(c("None", NA, ">8", "")), c("Not_measured", "Not_measured", ">8", "Not_measured"))
})

test_that("prepare_los gives one row per patient with clean codes", {
  raw <- read.csv(fixture("hospital_tiny.csv"), na.strings = c("", "NA"), check.names = FALSE)
  out <- prepare_los(raw)
  expect_equal(nrow(out), 3)  # patient 11 kept once, Unknown/Invalid gender dropped
  expect_equal(out$time_in_hospital, c(3, 2, 14))  # encounter 100 is patient 11's first
  expect_equal(out$age_mid, c(75, 55, 5))
  expect_equal(as.character(out$race), c("Caucasian", "Missing", "Hispanic"))
  expect_equal(as.character(out$A1Cresult), c("Not_measured", "Norm", ">7"))
  expect_equal(as.character(out$max_glu_serum), c("Not_measured", ">300", "Norm"))
  expect_true(is.factor(out$discharge_disposition_id))
})

test_that("rare levels are pooled using training counts only", {
  train <- data.frame(x = factor(c(rep("a", 5), rep("b", 5), "c")))
  test <- data.frame(x = factor(c("a", "c", "d")))
  out <- lump_rare_levels(train, test, "x", min_n = 2)
  expect_equal(levels(out$train$x), c("a", "b", "Other"))
  expect_equal(as.character(out$test$x), c("a", "Other", "Other"))
})

test_that("unseen test levels fall back to the modal level when nothing is pooled", {
  train <- data.frame(x = factor(c(rep("a", 5), rep("b", 3))))
  test <- data.frame(x = factor(c("b", "z")))
  out <- lump_rare_levels(train, test, "x", min_n = 2)
  expect_equal(levels(out$test$x), c("a", "b"))
  expect_equal(as.character(out$test$x), c("b", "a"))
})
