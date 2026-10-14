# Model specifications. All models share the same CV folds so that tuning and
# out-of-fold predictions are comparable across model families.

cv_folds <- function(y, k = 5, seed = 5330) {
  set.seed(seed)
  caret::createFolds(y, k = k, returnTrain = TRUE)
}

class_control <- function(index) {
  caret::trainControl(method = "cv", index = index, classProbs = TRUE,
                      summaryFunction = caret::twoClassSummary,
                      savePredictions = "final", allowParallel = FALSE)
}

reg_control <- function(index) {
  caret::trainControl(method = "cv", index = index, savePredictions = "final",
                      allowParallel = FALSE)
}

# Linear models get a formula (dummy coding); tree models get the raw data
# frame so rpart and ranger can split on factors directly and report
# importance per variable rather than per dummy column.
fit_caret <- function(train, outcome, predictors, method, ctrl, metric,
                      interface = c("formula", "xy"), seed = 5330, ...) {
  interface <- match.arg(interface)
  set.seed(seed)
  if (interface == "formula") {
    caret::train(stats::reformulate(predictors, response = outcome),
                 data = train[c(outcome, predictors)], method = method,
                 trControl = ctrl, metric = metric, ...)
  } else {
    caret::train(x = train[predictors], y = train[[outcome]], method = method,
                 trControl = ctrl, metric = metric, ...)
  }
}

# Fit a ranger forest at fixed hyperparameters on all training rows (used for
# the no-cluster ablation, which reuses the tuned settings of the main forest).
fit_ranger_fixed <- function(train, outcome, predictors, tune, threads, trees,
                             classification = TRUE, seed = 5330) {
  set.seed(seed)
  caret::train(x = train[predictors], y = train[[outcome]], method = "ranger",
               trControl = caret::trainControl(method = "none", classProbs = classification),
               tuneGrid = tune, num.trees = trees, num.threads = threads,
               respect.unordered.factors = "order")
}

classification_models <- function(train, outcome, predictors, index, threads,
                                  rf_trees = 200, rf_mtry = c(3, 6), rf_min_node = 25) {
  ctrl <- class_control(index)
  list(
    logistic = fit_caret(train, outcome, predictors, "glm", ctrl, "ROC",
                         family = stats::binomial, preProcess = c("center", "scale")),
    penalized = fit_caret(train, outcome, predictors, "glmnet", ctrl, "ROC",
                          preProcess = c("center", "scale"),
                          tuneGrid = expand.grid(alpha = c(0, 0.5, 1),
                                                 lambda = 10^seq(-5, -1, length.out = 15))),
    # With ~15% prevalence, the default cp search stops at a handful of leaves,
    # so the grid reaches down to much smaller complexity values.
    tree = fit_caret(train, outcome, predictors, "rpart", ctrl, "ROC", interface = "xy",
                     tuneGrid = data.frame(cp = c(5e-5, 1e-4, 2e-4, 3e-4, 5e-4, 1e-3))),
    forest = fit_caret(train, outcome, predictors, "ranger", ctrl, "ROC", interface = "xy",
                       tuneGrid = expand.grid(mtry = rf_mtry, splitrule = "gini",
                                              min.node.size = rf_min_node),
                       num.trees = rf_trees, num.threads = threads,
                       respect.unordered.factors = "order")
  )
}

regression_models <- function(train, outcome, predictors, index, threads,
                              rf_trees = 200, rf_mtry = c(3, 6, 9), rf_min_node = 20) {
  ctrl <- reg_control(index)
  lambda <- 10^seq(-4, 0, length.out = 20)
  list(
    linear = fit_caret(train, outcome, predictors, "lm", ctrl, "RMSE",
                       preProcess = c("center", "scale")),
    ridge = fit_caret(train, outcome, predictors, "glmnet", ctrl, "RMSE",
                      preProcess = c("center", "scale"),
                      tuneGrid = expand.grid(alpha = 0, lambda = lambda)),
    lasso = fit_caret(train, outcome, predictors, "glmnet", ctrl, "RMSE",
                      preProcess = c("center", "scale"),
                      tuneGrid = expand.grid(alpha = 1, lambda = lambda)),
    tree = fit_caret(train, outcome, predictors, "rpart", ctrl, "RMSE", interface = "xy",
                     tuneGrid = data.frame(cp = c(1e-4, 3e-4, 1e-3, 3e-3, 1e-2))),
    forest = fit_caret(train, outcome, predictors, "ranger", ctrl, "RMSE", interface = "xy",
                       tuneGrid = expand.grid(mtry = rf_mtry, splitrule = "variance",
                                              min.node.size = rf_min_node),
                       num.trees = rf_trees, num.threads = threads,
                       respect.unordered.factors = "order")
  )
}

predict_prob <- function(model, newdata, event = "Yes") {
  stats::predict(model, newdata = newdata, type = "prob")[[event]]
}

# Out-of-fold probabilities at the selected tuning values, in training-row order.
oof_prob <- function(model, event = "Yes") {
  p <- model$pred
  p <- p[order(p$rowIndex), ]
  stopifnot(!anyDuplicated(p$rowIndex))
  p[[event]]
}

cv_summary <- function(model, metric) {
  best <- merge(model$results, model$bestTune)
  best[[metric]]
}

tune_label <- function(model) {
  bt <- model$bestTune
  if (names(bt)[1] %in% c("parameter", "intercept")) return("none")
  paste(names(bt), vapply(bt, function(v) if (is.numeric(v)) format(signif(v, 3)) else as.character(v),
                          character(1)), sep = "=", collapse = ", ")
}
