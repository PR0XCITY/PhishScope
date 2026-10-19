# Module 1: descriptive statistics by class (train set).

library(ggplot2)
source("R/rv.R")

set.seed(2026)
fig_dir <- "outputs/figures"
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)
dir.create("outputs/results", showWarnings = FALSE, recursive = TRUE)

# @web-start Training set only
emails <- arrow::read_parquet("data/processed/emails.parquet")
train <- as.data.frame(emails[emails$set == "train", ])
features <- c("body_chars", "n_urls", "caps_ratio", "exclam_count")
# @web-end

# @web-start Summary statistics for every feature x class
stats_tbl <- describe_by_class(train, features)
# @web-end
# @web-start Choose log scale from skewness
# Log scale only for skewed features with a wide range (caps_ratio stays linear in [0, 1]).
is_skewed <- vapply(features, function(f) {
  min(stats_tbl$skewness[stats_tbl$feature == f]) > 1 && max(train[[f]]) > 10
}, logical(1))
# @web-end

interpret <- function(f) {
  s <- stats_tbl[stats_tbl$feature == f, ]
  shape <- if (min(s$skewness) > 1) "strongly right-skewed in every class" else "moderately skewed"
  nonzero <- tapply(train[[f]] > 0, train$class, mean)[s$class]
  sprintf("%s: median %s; nonzero %s; highest mean in %s (%.3g); %s (skewness %.1f to %.1f).",
          f, paste(sprintf("%s %.3g", s$class, s$median), collapse = ", "),
          paste(sprintf("%.0f%%", 100 * nonzero), collapse = "/"),
          s$class[which.max(s$mean)], max(s$mean), shape, min(s$skewness), max(s$skewness))
}
interpretation <- vapply(features, interpret, character(1))

plot_feature <- function(f, log_scale) {
  scale_tr <- if (log_scale) "log1p" else "identity"
  brks <- if (log_scale) c(0, 10^(0:7)) else waiver()
  box <- ggplot(train, aes(x = .data$class, y = .data[[f]], fill = .data$class)) +
    geom_boxplot(outlier.alpha = 0.15, show.legend = FALSE) +
    scale_y_continuous(transform = scale_tr, breaks = brks) +
    labs(x = NULL, y = if (log_scale) paste(f, "(log1p scale)") else f,
         title = paste("Boxplot of", f, "by class")) +
    theme_minimal()
  hist <- ggplot(train, aes(x = .data[[f]], fill = .data$class)) +
    geom_histogram(bins = 40, show.legend = FALSE) +
    scale_x_continuous(transform = scale_tr, breaks = brks) +
    facet_wrap(~class, ncol = 1, scales = "free_y") +
    labs(x = if (log_scale) paste(f, "(log1p scale)") else f, y = "count",
         title = paste("Histogram of", f, "by class")) +
    theme_minimal()
  paths <- file.path(fig_dir, paste0("m1_", c("box_", "hist_"), f, ".png"))
  ggsave(paths[1], box, width = 6, height = 4, dpi = 120)
  ggsave(paths[2], hist, width = 6, height = 6, dpi = 120)
  paths
}
figures <- unlist(lapply(features, function(f) plot_feature(f, is_skewed[[f]])))

saveRDS(list(stats = stats_tbl, log_scale = is_skewed, interpretation = interpretation,
             figures = figures, n_train = table(train$class)),
        "outputs/results/m1.rds")

cat("Train rows by class:\n")
print(table(train$class))
cat("\nMean / median / SD by class:\n")
print(stats_tbl[, c("feature", "class", "mean", "median", "sd")], digits = 3, row.names = FALSE)
cat("\n", paste(interpretation, collapse = "\n"), "\n", sep = "")
cat("Figures written:", length(figures), "\n")
