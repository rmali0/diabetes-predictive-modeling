# Plot theme and figure helpers. Colors follow a fixed, colorblind-checked
# categorical order; each model keeps the same color in every figure.

palette_models <- c("#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4")
ink <- list(primary = "#0b0b0b", secondary = "#52514e", grid = "#e6e5e1", surface = "#fcfcfb")

theme_project <- function(base_size = 11) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(fill = ink$surface, colour = NA),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(colour = ink$grid, linewidth = 0.3),
      axis.text = ggplot2::element_text(colour = ink$secondary),
      axis.title = ggplot2::element_text(colour = ink$secondary),
      plot.title = ggplot2::element_text(colour = ink$primary, face = "bold"),
      plot.subtitle = ggplot2::element_text(colour = ink$secondary),
      plot.caption = ggplot2::element_text(colour = ink$secondary, hjust = 0),
      legend.text = ggplot2::element_text(colour = ink$primary),
      legend.title = ggplot2::element_blank(),
      legend.position = "bottom",
      strip.text = ggplot2::element_text(colour = ink$primary, face = "bold")
    )
}

model_colors <- function(labels) stats::setNames(palette_models[seq_along(labels)], labels)

save_figure <- function(plot, name, width = 7, height = 5) {
  path <- file.path(outputs_dir("figures"), paste0(name, ".png"))
  ggplot2::ggsave(path, plot, width = width, height = height, dpi = 150, bg = ink$surface)
  invisible(path)
}

# Relative path from analysis/ to a saved figure, for knitr::include_graphics().
figure_link <- function(name) {
  if (quick_run()) return(file.path(outputs_dir("figures"), paste0(name, ".png")))
  file.path("..", "outputs", "figures", paste0(name, ".png"))
}

plot_roc <- function(roc_df, colors, title, subtitle = NULL) {
  ggplot2::ggplot(roc_df, ggplot2::aes(1 - specificity, sensitivity, colour = model)) +
    ggplot2::geom_abline(linetype = "dashed", colour = ink$secondary, linewidth = 0.3) +
    ggplot2::geom_path(linewidth = 0.7) +
    ggplot2::scale_colour_manual(values = colors) +
    ggplot2::coord_equal() +
    ggplot2::labs(x = "False positive rate (1 - specificity)", y = "Sensitivity",
                  title = title, subtitle = subtitle) +
    theme_project() +
    ggplot2::guides(colour = ggplot2::guide_legend(ncol = 2))
}

plot_pr <- function(pr_df, colors, prevalence, title) {
  ggplot2::ggplot(pr_df, ggplot2::aes(recall, precision, colour = model)) +
    ggplot2::geom_hline(yintercept = prevalence, linetype = "dashed", colour = ink$secondary,
                        linewidth = 0.3) +
    ggplot2::geom_path(linewidth = 0.7) +
    ggplot2::scale_colour_manual(values = colors) +
    ggplot2::scale_y_continuous(limits = c(0, 1)) +
    ggplot2::labs(x = "Recall (sensitivity)", y = "Precision (PPV)", title = title,
                  subtitle = sprintf("Dashed line: test-set prevalence (%.1f%%)", 100 * prevalence)) +
    theme_project() +
    ggplot2::guides(colour = ggplot2::guide_legend(ncol = 2))
}

plot_calibration <- function(cal_df, colors, title) {
  lim <- c(0, max(cal_df$high, cal_df$predicted) * 1.05)
  ggplot2::ggplot(cal_df, ggplot2::aes(predicted, observed, colour = model)) +
    ggplot2::geom_abline(linetype = "dashed", colour = ink$secondary, linewidth = 0.3) +
    ggplot2::geom_errorbar(ggplot2::aes(ymin = low, ymax = high), width = 0, linewidth = 0.4) +
    ggplot2::geom_line(linewidth = 0.5) +
    ggplot2::geom_point(size = 1.8) +
    ggplot2::facet_wrap(~model, nrow = 1) +
    ggplot2::scale_colour_manual(values = colors, guide = "none") +
    ggplot2::scale_x_continuous(limits = lim, labels = scales::percent) +
    ggplot2::scale_y_continuous(limits = lim, labels = scales::percent) +
    ggplot2::coord_equal() +
    ggplot2::labs(x = "Mean predicted risk (decile)", y = "Observed diabetes rate", title = title,
                  subtitle = "Test set, deciles of predicted risk, 95% binomial intervals") +
    theme_project(base_size = 10)
}

plot_importance <- function(imp_df, colors, title, x_label) {
  imp_df$variable <- stats::reorder(imp_df$variable, imp_df$importance, FUN = max)
  ggplot2::ggplot(imp_df, ggplot2::aes(importance, variable, fill = model)) +
    ggplot2::geom_col(width = 0.7) +
    ggplot2::geom_vline(xintercept = 0, colour = ink$secondary, linewidth = 0.3) +
    ggplot2::facet_wrap(~model, nrow = 1, scales = "free_x") +
    ggplot2::scale_fill_manual(values = colors, guide = "none") +
    ggplot2::labs(x = x_label, y = NULL, title = title,
                  subtitle = "Permutation importance on the held-out test set") +
    theme_project(base_size = 10)
}

# Mean prediction (with IQR) at each observed length of stay. A perfect model
# would sit on the diagonal; a flat line means the model cannot separate stays.
plot_observed_vs_predicted <- function(df, colors, title) {
  agg <- do.call(rbind, lapply(split(df, list(df$model, df$observed), drop = TRUE), function(d) {
    data.frame(model = d$model[1], observed = d$observed[1], mean_pred = mean(d$predicted),
               q25 = stats::quantile(d$predicted, 0.25), q75 = stats::quantile(d$predicted, 0.75))
  }))
  ggplot2::ggplot(agg, ggplot2::aes(observed, mean_pred, colour = model, fill = model)) +
    ggplot2::geom_abline(linetype = "dashed", colour = ink$secondary, linewidth = 0.3) +
    ggplot2::geom_ribbon(ggplot2::aes(ymin = q25, ymax = q75), alpha = 0.15, colour = NA) +
    ggplot2::geom_line(linewidth = 0.7) +
    ggplot2::geom_point(size = 1.6) +
    ggplot2::scale_colour_manual(values = colors) +
    ggplot2::scale_fill_manual(values = colors) +
    ggplot2::scale_x_continuous(breaks = 1:14) +
    ggplot2::scale_y_continuous(breaks = seq(0, 14, 2)) +
    ggplot2::coord_equal(xlim = c(1, 14), ylim = c(0, 14)) +
    ggplot2::labs(x = "Observed length of stay (days)", y = "Predicted length of stay (days)",
                  title = title,
                  subtitle = "Test set: mean prediction (line) and interquartile range (band) per observed day") +
    theme_project()
}

plot_residuals <- function(df, colors, title) {
  ggplot2::ggplot(df, ggplot2::aes(predicted, residual)) +
    ggplot2::geom_bin2d(bins = 50) +
    ggplot2::geom_hline(yintercept = 0, colour = ink$secondary, linewidth = 0.3) +
    ggplot2::geom_smooth(ggplot2::aes(colour = model), method = "loess", se = FALSE,
                         linewidth = 0.8, formula = y ~ x, span = 0.5) +
    ggplot2::facet_wrap(~model) +
    ggplot2::scale_fill_gradient(low = "#cde2fb", high = "#0d366b", name = "Patients",
                                 trans = "log10") +
    ggplot2::scale_colour_manual(values = colors, guide = "none") +
    ggplot2::labs(x = "Predicted length of stay (days)", y = "Residual (observed - predicted)",
                  title = title, subtitle = "Test set; line is a loess smooth of the residuals") +
    theme_project(base_size = 10) +
    ggplot2::theme(legend.position = "right", legend.title = ggplot2::element_text())
}

plot_qq <- function(residuals, title) {
  ggplot2::ggplot(data.frame(r = residuals), ggplot2::aes(sample = r)) +
    ggplot2::stat_qq(size = 0.6, colour = palette_models[1], alpha = 0.4) +
    ggplot2::stat_qq_line(colour = ink$secondary, linewidth = 0.4) +
    ggplot2::labs(x = "Normal quantile", y = "Residual quantile (days)", title = title) +
    theme_project()
}
