# Module 2: random variables, joint distributions, Bayes, covariance, MGF (train set).

library(ggplot2)
source("R/rv.R")

set.seed(2026)
fig_dir <- "outputs/figures"
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)
dir.create("outputs/results", showWarnings = FALSE, recursive = TRUE)

emails <- arrow::read_parquet("data/processed/emails.parquet")
train <- as.data.frame(emails[emails$set == "train", ])
classes <- sort(unique(train$class))
binary_features <- c("has_url", "ip_url", "shortener_url", "at_in_url", "has_urgency",
                     "has_credential", "has_money", "generic_greeting", "has_html",
                     "subject_caps")
numeric_features <- c("n_urls", "urgency_count", "credential_count", "money_count",
                      "exclam_count", "caps_ratio", "body_chars", "n_words")

# X = n_urls: PMF, CDF (display capped at 10+), E[X], Var[X] on raw values.
pmf_by_class <- do.call(rbind, lapply(classes, function(cl) {
  data.frame(class = cl, pmf_capped(train$n_urls[train$class == cl], cap = 10))
}))
moments_x <- t(sapply(classes, function(cl) rv_moments(train$n_urls[train$class == cl])))

x_breaks <- scale_x_continuous(breaks = 0:10, labels = c(0:9, "10+"))
pmf_plot <- ggplot(pmf_by_class, aes(x = .data$k, y = .data$pmf, fill = .data$class)) +
  geom_col(position = "dodge") +
  x_breaks +
  labs(x = "X = n_urls", y = "P(X = x)", fill = NULL, title = "PMF of n_urls by class") +
  theme_minimal()
cdf_plot <- ggplot(pmf_by_class, aes(x = .data$k, y = .data$cdf, colour = .data$class)) +
  geom_step(linewidth = 0.8) +
  x_breaks +
  coord_cartesian(ylim = c(0.5, 1)) +
  labs(x = "X = n_urls", y = "P(X <= x)", colour = NULL, title = "CDF of n_urls by class") +
  theme_minimal()
ggsave(file.path(fig_dir, "m2_pmf_n_urls.png"), pmf_plot, width = 7, height = 4, dpi = 120)
ggsave(file.path(fig_dir, "m2_cdf_n_urls.png"), cdf_plot, width = 7, height = 4, dpi = 120)

# Joint PMF of has_url x has_urgency within phishing and within legitimate.
joint <- lapply(c(phishing = "phishing", legitimate = "legitimate"), function(cl) {
  d <- train[train$class == cl, ]
  joint_pmf(d$has_url, d$has_urgency, "has_url", "has_urgency")
})

# P(feature | class) and Bayes P(phishing | feature) at sample and 1% prevalence.
is_phish <- train$class == "phishing"
prior_sample <- mean(is_phish)
cond <- t(sapply(binary_features, function(f) tapply(train[[f]] == 1, train$class, mean)))
bayes <- data.frame(
  feature = binary_features,
  p_f_phish = sapply(binary_features, function(f) mean(train[[f]][is_phish] == 1)),
  p_f_not_phish = sapply(binary_features, function(f) mean(train[[f]][!is_phish] == 1))
)
bayes$post_sample <- bayes_posterior(bayes$p_f_phish, bayes$p_f_not_phish, prior_sample)
bayes$post_1pct <- bayes_posterior(bayes$p_f_phish, bayes$p_f_not_phish, 0.01)
bayes$lift_1pct <- bayes$post_1pct / 0.01
cred <- bayes[bayes$feature == "has_credential", ]
worked <- c(
  sample = bayes_worked(cred$p_f_phish, cred$p_f_not_phish, prior_sample,
                        "has_credential", "phishing"),
  one_pct = bayes_worked(cred$p_f_phish, cred$p_f_not_phish, 0.01, "has_credential", "phishing")
)
# Sanity: Bayes at sample prevalence equals the direct conditional share.
direct_cred <- mean(is_phish[train$has_credential == 1])

# Covariance and correlation of numeric features.
cov_mat <- stats::cov(train[numeric_features])
cor_mat <- stats::cor(train[numeric_features])
spearman_mat <- stats::cor(train[numeric_features], method = "spearman")
cor_long <- as.data.frame(as.table(cor_mat))
heat <- ggplot(cor_long, aes(x = .data$Var1, y = .data$Var2, fill = .data$Freq)) +
  geom_tile() +
  geom_text(aes(label = sprintf("%.2f", .data$Freq)), size = 3) +
  scale_fill_gradient2(limits = c(-1, 1), low = "#3b6fb6", high = "#c0392b") +
  labs(x = NULL, y = NULL, fill = "r", title = "Pearson correlation, numeric features") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
ggsave(file.path(fig_dir, "m2_correlation_heatmap.png"), heat, width = 7, height = 6, dpi = 120)

# MGF of X: empirical vs Poisson(lambda = mean), t in [0, 0.5]; moments from derivatives.
t_grid <- seq(0, 0.5, by = 0.01)
mgf_curves <- do.call(rbind, lapply(classes, function(cl) {
  x <- train$n_urls[train$class == cl]
  rbind(data.frame(class = cl, t = t_grid, model = "empirical",
                   log_m = log_empirical_mgf(x, t_grid)),
        data.frame(class = cl, t = t_grid, model = "Poisson",
                   log_m = log_poisson_mgf(mean(x), t_grid)))
}))
mgf_moment_tbl <- do.call(rbind, lapply(classes, function(cl) {
  x <- train$n_urls[train$class == cl]
  # Step scaled to max(x) so h * max(x) stays small despite the heavy tail.
  emp <- mgf_moments(function(t) log_empirical_mgf(x, t), h = 0.01 / max(x))
  poi <- mgf_moments(function(t) log_poisson_mgf(mean(x), t))
  data.frame(class = cl, mgf_mean = emp[["mean"]], mgf_var = emp[["var"]],
             direct_mean = mean(x), direct_var = rv_moments(x)[["var"]],
             poisson_var = poi[["var"]])
}))
mgf_plot <- ggplot(mgf_curves, aes(x = .data$t, y = .data$log_m, linetype = .data$model)) +
  geom_line() +
  facet_wrap(~class, scales = "free_y") +
  labs(x = "t", y = "log M(t)", linetype = NULL,
       title = "MGF of n_urls: empirical vs Poisson (log scale)") +
  theme_minimal()
ggsave(file.path(fig_dir, "m2_mgf_n_urls.png"), mgf_plot, width = 8, height = 3.5, dpi = 120)

saveRDS(list(
  pmf = pmf_by_class, moments = moments_x, joint = joint, cond = cond, bayes = bayes,
  prior_sample = prior_sample, worked = worked, direct_cred = direct_cred,
  cov = cov_mat, cor = cor_mat, spearman = spearman_mat,
  mgf_curves = mgf_curves, mgf_moments = mgf_moment_tbl,
  figures = file.path(fig_dir, c("m2_pmf_n_urls.png", "m2_cdf_n_urls.png",
                                 "m2_correlation_heatmap.png", "m2_mgf_n_urls.png"))
), "outputs/results/m2.rds")

cat("E[X], Var[X] of n_urls by class:\n")
print(round(moments_x, 3))
cat("\nP(has_url, has_urgency = 1, 1): phishing", round(joint$phishing["1", "1"], 3),
    "| legitimate", round(joint$legitimate["1", "1"], 3), "\n")
cat("\nBayes P(phishing | feature), sample prior", round(prior_sample, 4), "and 1%:\n")
print(bayes[, c("feature", "p_f_phish", "p_f_not_phish", "post_sample", "post_1pct")],
      digits = 3, row.names = FALSE)
cat("\n", worked[["sample"]], "\n", worked[["one_pct"]], "\n", sep = "")
cat("Direct check P(phishing | has_credential):", round(direct_cred, 4), "\n")
strongest <- function(m, k = 3) {
  idx <- which(upper.tri(m), arr.ind = TRUE)
  idx <- idx[order(-abs(m[idx]))[seq_len(k)], , drop = FALSE]
  paste(sprintf("%s x %s %.3f", rownames(m)[idx[, 1]], colnames(m)[idx[, 2]], m[idx]),
        collapse = "; ")
}
cat("\nTop Pearson:", strongest(cor_mat), "\nTop Spearman:", strongest(spearman_mat), "\n")
cat("\nMGF moments vs direct:\n")
print(mgf_moment_tbl, digits = 4, row.names = FALSE)
