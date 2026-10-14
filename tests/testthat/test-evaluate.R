test_that("average precision equals prevalence for a constant score and 1 for a perfect one", {
  y <- c(1, 0, 0, 0, 1, 0, 0, 0, 0, 0)
  expect_equal(average_precision(rep(0.5, 10), y), 0.2)
  expect_equal(average_precision(y + 0.1, y), 1)
})

test_that("average precision matches a hand calculation", {
  # ranks: 1 (pos), 2 (neg), 3 (pos) -> AP = 0.5 * 1 + 0.5 * 2/3
  expect_equal(average_precision(c(0.9, 0.8, 0.7), c(1, 0, 1)), 0.5 + 1 / 3)
})

test_that("Brier score is the mean squared error of probabilities", {
  expect_equal(brier_score(c(1, 0, 0.5), c(1, 0, 1)), 0.25 / 3)
})

test_that("threshold for sensitivity reaches the target", {
  set.seed(2)
  y <- rbinom(500, 1, 0.2)
  p <- runif(500) * 0.5 + 0.3 * y
  t <- threshold_for_sensitivity(p, y, 0.8)
  sens <- mean(p[y == 1] >= t)
  expect_gte(sens, 0.8)
  # The next-higher positive score would fall below the target.
  higher <- min(p[y == 1 & p > t])
  expect_lt(mean(p[y == 1] >= higher), 0.8)
})

test_that("confusion metrics count correctly", {
  m <- confusion_metrics(c(0.9, 0.6, 0.4, 0.1), c(1, 0, 1, 0), threshold = 0.5)
  expect_equal(c(m$sensitivity, m$specificity, m$ppv, m$npv, m$flagged),
               c(0.5, 0.5, 0.5, 0.5, 0.5))
})

test_that("regression metrics match definitions", {
  m <- regression_metrics(c(1, 2, 3), c(1, 2, 5))
  expect_equal(m$rmse, sqrt(4 / 3))
  expect_equal(m$mae, 2 / 3)
  expect_equal(m$r2, 1 - 4 / 2)
})

test_that("calibration bins have equal size and preserve the overall rate", {
  set.seed(3)
  p <- runif(100)
  y <- rbinom(100, 1, p)
  cal <- calibration_bins(p, y, bins = 10)
  expect_equal(cal$n, rep(10L, 10))
  expect_equal(sum(cal$observed * cal$n) / 100, mean(y))
})
