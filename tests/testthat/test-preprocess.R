test_that("imputation medians and cluster centers come from training data only", {
  train <- data.frame(a = c(1, 2, 3, NA, 100, 101, 102), b = c(1, 1, 2, 2, 50, 51, 52))
  test <- data.frame(a = c(NA, 1000), b = c(1, 1000))
  prep <- fit_preprocessor(train, impute_vars = "a", cluster_vars = c("a", "b"),
                           cluster_name = "cl", k = 2, nstart = 5)
  expect_equal(unname(prep$medians["a"]), 51.5)
  out <- apply_preprocessor(prep, test)
  expect_equal(out$a[1], 51.5)
  expect_equal(levels(out$cl), c("1", "2"))
  # A far-away test row does not move the training centers.
  expect_equal(prep$center, colMeans(impute_medians(train, prep$medians)))
})

test_that("clusters are labelled by size, largest first", {
  set.seed(1)
  train <- data.frame(a = c(rnorm(20, 0), rnorm(5, 10)))
  prep <- fit_preprocessor(train, "a", "a", "cl", k = 2)
  out <- apply_preprocessor(prep, train)
  expect_equal(as.integer(table(out$cl)), c(20L, 5L))
})

test_that("nearest-center assignment picks the closest center", {
  centers <- rbind(c(0, 0), c(10, 10))
  z <- rbind(c(1, 1), c(9, 8), c(4, 4))
  expect_equal(assign_nearest_center(z, centers), c(1, 2, 1))
})
