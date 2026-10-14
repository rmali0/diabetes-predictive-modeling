test_that("diabetes outcome keeps 1 vs 3/4 and drops 2, 7, 9 and blanks", {
  out <- brfss_diabetes_outcome(c(1, 2, 3, 4, 7, 9, NA))
  expect_equal(as.character(out), c("Yes", NA, "No", "No", NA, NA, NA))
  expect_equal(levels(out), c("Yes", "No"))
})

test_that("day counts recode 88 to zero and 77/99 to missing", {
  expect_equal(brfss_days(c(88, 1, 30, 77, 99, NA)), c(0, 1, 30, NA, NA, NA))
  expect_true(is.na(brfss_days(45)))
})

test_that("BMI divides _BMI5 by 100 and treats blanks and 9999 as missing", {
  expect_equal(brfss_bmi(c(2249, 3125, NA, 9999)), c(22.49, 31.25, NA, NA))
})

test_that("factor recode labels valid codes and adds Missing only when needed", {
  x <- brfss_factor(c(1, 2, 7, 9, NA), c(1, 2), c("Yes", "No"))
  expect_equal(as.character(x), c("Yes", "No", "Missing", "Missing", "Missing"))
  expect_equal(levels(x), c("Yes", "No", "Missing"))
  y <- brfss_factor(c(1, 2, 2), c(1, 2), c("Male", "Female"))
  expect_equal(levels(y), c("Male", "Female"))
})

test_that("CHECKUP1 = 8 is 'Never', not missing", {
  spec <- brfss_factor_spec$routine_checkup
  x <- brfss_factor(c(1, 4, 8, 7, 9), spec$codes, spec$labels)
  expect_equal(as.character(x), c("Past_year", "Five_plus_years", "Never", "Missing", "Missing"))
})

test_that("prepare_brfss builds the analytic frame from a tiny extract", {
  raw <- read.csv(fixture("brfss_tiny.csv"), check.names = FALSE)
  out <- prepare_brfss(raw)
  expect_equal(nrow(out), 3)  # codes 2, 7 and 9 are dropped
  expect_equal(as.character(out$diabetes), c("Yes", "No", "No"))
  expect_equal(out$physical_unhealthy_days, c(0, 5, 30))
  expect_equal(out$mental_unhealthy_days, c(0, NA, NA))
  expect_equal(out$bmi, c(31.25, 22.49, NA))
  expect_equal(as.character(out$routine_checkup), c("Past_year", "Never", "Missing"))
  expect_equal(as.character(out$exercise_30days), c("Yes", "No", "Missing"))
  expect_equal(as.character(out$heart_attack), c("No", "Yes", "Missing"))
  expect_equal(as.character(out$income_group), c("50k_100k", "Missing", "Under_15k"))
  expect_false(any(c("_TOTINDA", "_RFHLTH", "_MICHD") %in% names(out)))
})
