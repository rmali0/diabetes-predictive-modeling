# Train-only preprocessing: median imputation and a k-means cluster feature.
# Every statistic (medians, means, SDs, cluster centers) is estimated on the
# training rows and then applied unchanged to the test rows.

impute_medians <- function(data, medians) {
  for (v in names(medians)) {
    x <- data[[v]]
    x[is.na(x)] <- medians[[v]]
    data[[v]] <- x
  }
  data
}

# Index of the nearest center (squared Euclidean distance) for each row.
assign_nearest_center <- function(z, centers) {
  z <- as.matrix(z)
  dist <- vapply(seq_len(nrow(centers)),
                 function(j) rowSums(sweep(z, 2, centers[j, ])^2),
                 numeric(nrow(z)))
  dist <- matrix(dist, nrow = nrow(z))
  max.col(-dist, ties.method = "first")
}

fit_preprocessor <- function(train, impute_vars, cluster_vars, cluster_name,
                             k = 3, nstart = 20, seed = 5330) {
  medians <- vapply(train[impute_vars], stats::median, numeric(1), na.rm = TRUE)
  imputed <- impute_medians(train, medians)
  x <- as.matrix(imputed[cluster_vars])
  center <- colMeans(x)
  scale <- apply(x, 2, stats::sd)
  scale[scale == 0] <- 1
  set.seed(seed)
  # Lloyd's algorithm avoids Hartigan-Wong's step limit on 100k+ rows.
  km <- stats::kmeans(scale(x, center, scale), centers = k, nstart = nstart, iter.max = 100,
                      algorithm = "Lloyd")
  # Relabel clusters by size (1 = largest) so labels do not depend on the
  # random start that happened to win.
  centers <- km$centers[order(-km$size), , drop = FALSE]
  rownames(centers) <- seq_len(k)
  structure(list(medians = medians, cluster_vars = cluster_vars, center = center,
                 scale = scale, centers = centers, cluster_name = cluster_name),
            class = "train_preprocessor")
}

apply_preprocessor <- function(prep, data) {
  data <- impute_medians(data, prep$medians)
  z <- scale(as.matrix(data[prep$cluster_vars]), prep$center, prep$scale)
  k <- nrow(prep$centers)
  data[[prep$cluster_name]] <- factor(assign_nearest_center(z, prep$centers), levels = seq_len(k))
  data
}

# Cluster centers in original units, for describing what each cluster means.
cluster_profile <- function(prep, data) {
  centers <- sweep(sweep(prep$centers, 2, prep$scale, "*"), 2, prep$center, "+")
  out <- data.frame(cluster = rownames(centers), round(centers, 2), check.names = FALSE)
  counts <- table(data[[prep$cluster_name]])
  out$n_train <- as.integer(counts[out$cluster])
  out
}
