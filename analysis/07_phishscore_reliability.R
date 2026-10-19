# PhishScore model (train -> test) and Module 7 reliability; exports web/model.json.

library(ggplot2)
source("R/phishscore.R")
source("R/reliability.R")

set.seed(2026)
dir.create("outputs/results", showWarnings = FALSE, recursive = TRUE)
dir.create("outputs/figures", showWarnings = FALSE, recursive = TRUE)

emails <- as.data.frame(arrow::read_parquet("data/processed/emails.parquet"))
pl <- emails[emails$class %in% c("phishing", "legitimate"), ]
train <- pl[pl$set == "train", ]
test <- pl[pl$set == "test", ]

# Features chosen in Module 6: Holm p < 0.05 and Cramer's V >= 0.1.
m6 <- readRDS("outputs/results/m6.rds")
features <- m6$independence$feature[m6$independence$passes]

# ---- Fit on train, evaluate on test at threshold 0.5 ----
threshold <- 0.5
model <- fit_phishscore(train, features)
truth <- test$class == "phishing"
score <- phishscore_posterior(model, test)
eval_main <- classification_metrics(truth, score >= threshold)
auc <- auc_rank(score, truth)
roc <- roc_points(score, truth)
roc_plot <- ggplot(roc, aes(x = .data$fpr, y = .data$tpr)) +
  geom_step(direction = "vh", colour = "#3b6fb6", linewidth = 0.8) +
  geom_abline(linetype = "dashed", colour = "grey60") +
  coord_equal() +
  labs(x = "false positive rate", y = "true positive rate",
       title = sprintf("PhishScore ROC, test set (AUC %.3f)", auc)) +
  theme_minimal()
ggsave("outputs/figures/m7_roc.png", roc_plot, width = 5, height = 5, dpi = 120)

# Precision when phishing is 1% of mail: deployed model, and model re-scored at a 1% prior.
precision_at <- function(sens, spec, prevalence) {
  sens * prevalence / (sens * prevalence + (1 - spec) * (1 - prevalence))
}
m_main <- eval_main$metrics
precision_1pct_deployed <- precision_at(m_main["sensitivity", "estimate"],
                                        m_main["specificity", "estimate"], 0.01)
eval_prior1 <- classification_metrics(truth, phishscore_posterior(model, test, 0.01) >= threshold)
precision_1pct_prior <- precision_at(eval_prior1$metrics["sensitivity", "estimate"],
                                     eval_prior1$metrics["specificity", "estimate"], 0.01)

# ---- Cross-corpus: refit without Nigerian Fraud, test on Nigerian Fraud vs test legitimate ----
nf_test <- test[test$source == "Nigerian_Fraud" | test$class == "legitimate", ]
nf_truth <- nf_test$class == "phishing"
cross_model <- fit_phishscore(train[train$source != "Nigerian_Fraud", ], features)
eval_in <- classification_metrics(nf_truth, phishscore_posterior(model, nf_test) >= threshold)
eval_cross <- classification_metrics(
  nf_truth, phishscore_posterior(cross_model, nf_test) >= threshold
)
cross <- data.frame(
  model = c("in-corpus (all train)", "cross-corpus (no Nigerian Fraud)"),
  sensitivity = c(eval_in$metrics["sensitivity", "estimate"],
                  eval_cross$metrics["sensitivity", "estimate"]),
  specificity = c(eval_in$metrics["specificity", "estimate"],
                  eval_cross$metrics["specificity", "estimate"]),
  auc = c(auc_rank(phishscore_posterior(model, nf_test), nf_truth),
          auc_rank(phishscore_posterior(cross_model, nf_test), nf_truth))
)
sens_drop <- cross$sensitivity[1] - cross$sensitivity[2]

# ---- Module 7: each selected rule as a component ----
rule_rates <- data.frame(
  rule = features,
  d = vapply(features, function(f) mean(test[[f]][truth] == 1), numeric(1)),
  f = vapply(features, function(f) mean(test[[f]][!truth] == 1), numeric(1))
)
fires <- as.matrix(test[, features]) == 1
system_rates <- data.frame(
  system = c("parallel (any fires)", "series (all fire)"),
  detect_predicted = c(parallel_prob(rule_rates$d), series_prob(rule_rates$d)),
  detect_empirical = c(mean(apply(fires[truth, ], 1, any)), mean(apply(fires[truth, ], 1, all))),
  false_alarm_predicted = c(parallel_prob(rule_rates$f), series_prob(rule_rates$f)),
  false_alarm_empirical = c(mean(apply(fires[!truth, ], 1, any)),
                            mean(apply(fires[!truth, ], 1, all)))
)

# Pairwise rule dependence within each class (chi-square, phi).
rule_dependence <- function(rows, label) {
  pairs <- utils::combn(features, 2)
  do.call(rbind, lapply(seq_len(ncol(pairs)), function(k) {
    a <- test[[pairs[1, k]]][rows]
    b <- test[[pairs[2, k]]][rows]
    tab <- table(factor(a, 0:1), factor(b, 0:1))
    ct <- suppressWarnings(stats::chisq.test(tab, correct = FALSE))
    phi <- if (stats::sd(a) > 0 && stats::sd(b) > 0) stats::cor(a, b) else NA_real_
    data.frame(class = label, rule_a = pairs[1, k], rule_b = pairs[2, k],
               chi2 = unname(ct$statistic), p_value = ct$p.value, phi = phi)
  }))
}
dependence <- rbind(rule_dependence(truth, "phishing"), rule_dependence(!truth, "legitimate"))
dependence$p_holm <- stats::p.adjust(dependence$p_value, method = "holm")

# User level: pi = 1%, miss rate m = 1 - sensitivity, hazard h = pi * m.
pi_phish <- 0.01
miss <- 1 - m_main["sensitivity", "estimate"]
hazard <- pi_phish * miss
n_seq <- 0:1000
user_curve <- data.frame(n = n_seq, reliability = user_reliability(n_seq, hazard))
user_plot <- ggplot(user_curve, aes(x = .data$n, y = .data$reliability)) +
  geom_line(colour = "#3b6fb6", linewidth = 0.8) +
  labs(x = "emails received", y = "R(n) = P(no missed phish)",
       title = sprintf("User reliability, pi = 1%%, miss rate %.3f", miss)) +
  theme_minimal()
ggsave("outputs/figures/m7_user_reliability.png", user_plot, width = 6, height = 4, dpi = 120)
user_level <- c(pi = pi_phish, miss_rate = miss, hazard = hazard,
                r_100 = user_reliability(100, hazard), r_1000 = user_reliability(1000, hazard),
                mttf_emails = mttf_emails(hazard), mttf_days = mttf_emails(hazard) / 50)

# Maintainability and availability (assumption-based scenario).
avail <- c(mtbf_days = 90, mttr_days = 2, availability = availability(90, 2))
avail_note <- paste("Assumption-based: lexicon and likelihoods refreshed every 90 days,",
                    "2 days degraded per refresh; drift size taken from the cross-corpus",
                    sprintf("sensitivity drop of %.3f.", sens_drop))

# ---- Export web/model.json (no email text) ----
dir.create("web", showWarnings = FALSE)
likelihoods <- lapply(stats::setNames(features, features), function(f) {
  list(phishing = unname(model$p_phish[f]), legitimate = unname(model$p_legit[f]))
})
jsonlite::write_json(
  list(version = "1.0.0", training_date = format(Sys.Date()),
       classes = c("phishing", "legitimate"), lexicon = yaml::read_yaml("config/features.yml"),
       features = features, likelihoods = likelihoods, prior = model$prior,
       threshold = threshold, smoothing = "Laplace (count + 1) / (n + 2)",
       n_train = list(phishing = model$n_phish, legitimate = model$n_legit),
       citation = "Al-Subaiey et al. 2024, arXiv 2405.11619"),
  "web/model.json", auto_unbox = TRUE, digits = NA, pretty = TRUE
)

headline <- list(
  features = features, prior = model$prior, threshold = threshold,
  confusion = eval_main$confusion, metrics = m_main, auc = auc,
  precision_1pct_deployed = precision_1pct_deployed,
  precision_1pct_prior = precision_1pct_prior, prior1_metrics = eval_prior1$metrics,
  cross_corpus = cross, sensitivity_drop = sens_drop
)
saveRDS(headline, "outputs/results/headline.rds")
saveRDS(list(
  headline = headline, roc = roc, rule_rates = rule_rates, system_rates = system_rates,
  dependence = dependence, user_level = user_level, user_curve = user_curve,
  availability = avail, availability_note = avail_note,
  figures = c("outputs/figures/m7_roc.png", "outputs/figures/m7_user_reliability.png")
), "outputs/results/m7.rds")

cat("Selected features:", paste(features, collapse = ", "), "\n")
cat(sprintf("Train prior %.4f; test n = %d (phishing %d)\n", model$prior, nrow(test), sum(truth)))
cat("\nConfusion matrix (test, threshold 0.5):\n")
print(eval_main$confusion)
cat("\nMetrics with Wilson 95% CI:\n")
print(round(m_main, 4))
cat(sprintf("AUC %.4f\n", auc))
cat(sprintf("Precision at 1%% prevalence: deployed model %.4f; re-scored with 1%% prior %.4f\n",
            precision_1pct_deployed, precision_1pct_prior))
cat("\nCross-corpus on Nigerian Fraud vs test legitimate:\n")
print(cross, digits = 4, row.names = FALSE)
cat(sprintf("Sensitivity drop: %.4f\n", sens_drop))
cat("\nRule components (test):\n")
print(rule_rates, digits = 3, row.names = FALSE)
print(system_rates, digits = 4, row.names = FALSE)
sig <- dependence$p_holm < 0.05
cat(sprintf("Rule pairs dependent (Holm p < 0.05): %d of %d; mean phi phishing %.3f, legit %.3f\n",
            sum(sig, na.rm = TRUE), nrow(dependence),
            mean(dependence$phi[dependence$class == "phishing"], na.rm = TRUE),
            mean(dependence$phi[dependence$class == "legitimate"], na.rm = TRUE)))
cat("\nUser level:", sprintf("%s %.4g", names(user_level), user_level), "\n")
cat("Availability:", sprintf("%s %.4g", names(avail), avail), "\n", avail_note, "\n")
