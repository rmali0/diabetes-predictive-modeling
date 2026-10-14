# Evaluation helpers. Binary outcomes are passed as 0/1 (1 = event).

brier_score <- function(prob, y01) mean((prob - y01)^2)

# Precision-recall points at each distinct score, ties handled as one block.
pr_curve <- function(prob, y01) {
  o <- order(prob, decreasing = TRUE)
  p <- prob[o]
  y <- y01[o]
  last <- c(diff(p) != 0, TRUE)
  tp <- cumsum(y)[last]
  fp <- cumsum(1 - y)[last]
  data.frame(threshold = p[last], recall = tp / sum(y), precision = tp / (tp + fp))
}

# Average precision (step-wise area under the PR curve). A constant score gives
# the prevalence; a perfect ranking gives 1.
average_precision <- function(prob, y01) {
  pr <- pr_curve(prob, y01)
  sum(diff(c(0, pr$recall)) * pr$precision)
}

# Highest threshold whose sensitivity (prob >= threshold) is at least target.
threshold_for_sensitivity <- function(prob, y01, target = 0.80) {
  pos <- sort(prob[y01 == 1], decreasing = TRUE)
  pos[ceiling(target * length(pos))]
}

confusion_metrics <- function(prob, y01, threshold) {
  pred <- as.integer(prob >= threshold)
  tp <- sum(pred == 1 & y01 == 1)
  tn <- sum(pred == 0 & y01 == 0)
  fp <- sum(pred == 1 & y01 == 0)
  fn <- sum(pred == 0 & y01 == 1)
  data.frame(threshold = threshold,
             sensitivity = tp / (tp + fn), specificity = tn / (tn + fp),
             ppv = tp / (tp + fp), npv = tn / (tn + fn),
             flagged = mean(pred))
}

roc_object <- function(prob, y01) {
  pROC::roc(response = y01, predictor = prob, levels = c(0, 1), direction = "<", quiet = TRUE)
}

auc_with_ci <- function(prob, y01) {
  ci <- as.numeric(pROC::ci.auc(roc_object(prob, y01), method = "delong"))
  data.frame(auc = ci[2], auc_low = ci[1], auc_high = ci[3])
}

# Decile calibration table: mean predicted risk vs observed rate per bin.
calibration_bins <- function(prob, y01, bins = 10) {
  bin <- ceiling(rank(prob, ties.method = "first") * bins / length(prob))
  agg <- lapply(split(seq_along(prob), bin), function(i) {
    obs <- mean(y01[i])
    se <- sqrt(obs * (1 - obs) / length(i))
    data.frame(predicted = mean(prob[i]), observed = obs,
               low = max(0, obs - 1.96 * se), high = min(1, obs + 1.96 * se), n = length(i))
  })
  out <- do.call(rbind, agg)
  out$bin <- as.integer(names(agg))
  out
}

regression_metrics <- function(obs, pred) {
  data.frame(rmse = sqrt(mean((obs - pred)^2)),
             mae = mean(abs(obs - pred)),
             r2 = 1 - sum((obs - pred)^2) / sum((obs - mean(obs))^2))
}

# Paired bootstrap of the test-set RMSE difference (a minus b). Resampling the
# same rows for both models keeps the comparison paired.
paired_rmse_diff <- function(obs, pred_a, pred_b, reps = 2000, seed = 5330) {
  set.seed(seed)
  n <- length(obs)
  diffs <- replicate(reps, {
    i <- sample.int(n, n, replace = TRUE)
    sqrt(mean((obs[i] - pred_a[i])^2)) - sqrt(mean((obs[i] - pred_b[i])^2))
  })
  point <- sqrt(mean((obs - pred_a)^2)) - sqrt(mean((obs - pred_b)^2))
  data.frame(diff = point, low = unname(stats::quantile(diffs, 0.025)),
             high = unname(stats::quantile(diffs, 0.975)))
}

# Permutation importance on held-out data: how much the metric worsens when one
# predictor is shuffled. higher_is_better flips the sign for loss metrics.
permutation_importance <- function(predict_fun, data, y, vars, metric_fun,
                                   higher_is_better = TRUE, reps = 1, seed = 5330) {
  set.seed(seed)
  base <- metric_fun(y, predict_fun(data))
  drops <- vapply(vars, function(v) {
    mean(vapply(seq_len(reps), function(r) {
      shuffled <- data
      shuffled[[v]] <- shuffled[[v]][sample.int(nrow(data))]
      score <- metric_fun(y, predict_fun(shuffled))
      if (higher_is_better) base - score else score - base
    }, numeric(1)))
  }, numeric(1))
  out <- data.frame(variable = vars, importance = unname(drops))
  out[order(-out$importance), , drop = FALSE]
}
