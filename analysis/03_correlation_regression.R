# Module 3: rank correlation, partial correlation, linear probability model (train set).

library(ggplot2)

set.seed(2026)
fig_dir <- "outputs/figures"
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)
dir.create("outputs/results", showWarnings = FALSE, recursive = TRUE)

emails <- arrow::read_parquet("data/processed/emails.parquet")
train <- as.data.frame(emails[emails$set == "train", ])
binary_features <- c("has_url", "ip_url", "shortener_url", "at_in_url", "has_urgency",
                     "has_credential", "has_money", "generic_greeting", "has_html",
                     "subject_caps")
numeric_features <- c("n_urls", "urgency_count", "credential_count", "money_count",
                      "exclam_count", "caps_ratio", "body_chars", "n_words")

# Spearman matrix, and one pair by the rank-difference formula.
spearman_mat <- stats::cor(train[numeric_features], method = "spearman")

# @web-start Spearman by the rank-difference formula
rank_difference_rho <- function(x, y) {
  d <- rank(x) - rank(y)
  n <- length(x)
  1 - 6 * sum(d^2) / (n * (n^2 - 1))
}
pair <- c("body_chars", "n_words")
rho_formula <- rank_difference_rho(train[[pair[1]]], train[[pair[2]]])
rho_cor <- spearman_mat[pair[1], pair[2]]
# @web-end

# @web-start Spearman of each feature with is_phish
# Spearman of each feature with is_phish, phishing vs legitimate only.
pl <- train[train$class %in% c("phishing", "legitimate"), ]
pl$is_phish <- as.integer(pl$class == "phishing")
all_features <- c(numeric_features, binary_features)
rho_phish <- sapply(all_features, function(f) {
  if (stats::sd(pl[[f]]) == 0) NA_real_ else stats::cor(pl[[f]], pl$is_phish, method = "spearman")
})
rho_phish <- sort(rho_phish, decreasing = TRUE)
# @web-end

# @web-start Partial correlation with ppcor
# Partial correlation: urgency_count vs is_phish given body_chars and n_urls.
controls <- pl[, c("body_chars", "n_urls")]
partial <- rbind(
  pearson = ppcor::pcor.test(pl$urgency_count, pl$is_phish, controls, method = "pearson"),
  spearman = ppcor::pcor.test(pl$urgency_count, pl$is_phish, controls, method = "spearman")
)
zero_order <- c(pearson = stats::cor(pl$urgency_count, pl$is_phish),
                spearman = stats::cor(pl$urgency_count, pl$is_phish, method = "spearman"))
# @web-end

# @web-start Linear probability model and logistic fit
# Linear probability model and logistic comparison.
pl$log_body_chars <- log(pl$body_chars)
lpm_formula <- stats::reformulate(c(binary_features, "log_body_chars"), response = "is_phish")
lpm <- stats::lm(lpm_formula, data = pl)
lpm_sum <- summary(lpm)
lpm_fit <- stats::fitted(lpm)
out_of_range <- mean(lpm_fit < 0 | lpm_fit > 1)
logit <- stats::glm(lpm_formula, data = pl, family = stats::binomial())
# @web-end
coef_table <- data.frame(
  term = names(stats::coef(lpm)),
  lpm_estimate = unname(stats::coef(lpm)),
  lpm_p = unname(lpm_sum$coefficients[, 4]),
  logit_estimate = unname(stats::coef(logit)[names(stats::coef(lpm))]),
  logit_odds_ratio = unname(exp(stats::coef(logit)[names(stats::coef(lpm))]))
)
lpm_limitation <- sprintf(
  paste("LPM limitation: %.1f%% of fitted probabilities fall outside [0, 1]",
        "and errors are heteroscedastic by construction."),
  100 * out_of_range
)

heat <- ggplot(as.data.frame(as.table(spearman_mat)),
               aes(x = .data$Var1, y = .data$Var2, fill = .data$Freq)) +
  geom_tile() +
  geom_text(aes(label = sprintf("%.2f", .data$Freq)), size = 3) +
  scale_fill_gradient2(limits = c(-1, 1), low = "#3b6fb6", high = "#c0392b") +
  labs(x = NULL, y = NULL, fill = "rho", title = "Spearman correlation, numeric features") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
ggsave(file.path(fig_dir, "m3_spearman_heatmap.png"), heat, width = 7, height = 6, dpi = 120)

rho_df <- data.frame(feature = factor(names(rho_phish), rev(names(rho_phish))), rho = rho_phish)
rho_plot <- ggplot(rho_df[!is.na(rho_df$rho), ], aes(x = .data$rho, y = .data$feature)) +
  geom_col(fill = "#3b6fb6") +
  labs(x = "Spearman rho with is_phish", y = NULL,
       title = "Feature association with phishing (vs legitimate)") +
  theme_minimal()
ggsave(file.path(fig_dir, "m3_rho_is_phish.png"), rho_plot, width = 7, height = 5, dpi = 120)

saveRDS(list(
  spearman = spearman_mat, rank_formula = c(pair = paste(pair, collapse = " x "),
                                            formula = rho_formula, cor = rho_cor),
  rho_is_phish = rho_phish, partial = partial, zero_order = zero_order,
  lpm_coef = coef_table, r_squared = lpm_sum$r.squared, multiple_r = sqrt(lpm_sum$r.squared),
  adj_r_squared = lpm_sum$adj.r.squared, out_of_range = out_of_range,
  lpm_limitation = lpm_limitation, logit_aic = stats::AIC(logit), n_pl = nrow(pl),
  figures = file.path(fig_dir, c("m3_spearman_heatmap.png", "m3_rho_is_phish.png"))
), "outputs/results/m3.rds")

cat(sprintf("Rank-difference rho (%s): formula %.5f vs cor() %.5f (gap from ties %.1e)\n",
            paste(pair, collapse = " x "), rho_formula, rho_cor, rho_formula - rho_cor))
cat("\nSpearman with is_phish (phishing vs legitimate, n =", nrow(pl), "):\n")
print(round(rho_phish, 3))
cat("\nurgency_count vs is_phish: zero-order",
    sprintf("%s %.3f", names(zero_order), zero_order), "\n")
print(partial[, c("estimate", "p.value", "statistic", "n")], digits = 3)
cat(sprintf("\nLPM: R^2 %.4f, multiple R %.4f, adj R^2 %.4f\n",
            lpm_sum$r.squared, sqrt(lpm_sum$r.squared), lpm_sum$adj.r.squared))
print(coef_table, digits = 3, row.names = FALSE)
cat("\n", lpm_limitation, "\n", sep = "")
