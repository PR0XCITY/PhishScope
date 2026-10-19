# Module 6: small-sample t / F, chi-square GOF and independence, ANOVA, DOE layouts (train set).

library(ggplot2)
tp <- new.env()
sys.source("R/tests_print.R", envir = tp)

set.seed(2026)
dir.create("outputs/results", showWarnings = FALSE, recursive = TRUE)
dir.create("outputs/figures", showWarnings = FALSE, recursive = TRUE)

emails <- arrow::read_parquet("data/processed/emails.parquet")
train <- as.data.frame(emails[emails$set == "train", ])
train$log_body <- log(train$body_chars)
binary_features <- c("has_url", "ip_url", "shortener_url", "at_in_url", "has_urgency",
                     "has_credential", "has_money", "generic_greeting", "has_html",
                     "subject_caps")
mu_legit <- mean(train$log_body[train$class == "legitimate"])
pooled_d <- function(x, y) {
  sp <- sqrt(((length(x) - 1) * stats::var(x) + (length(y) - 1) * stats::var(y)) /
               (length(x) + length(y) - 2))
  (mean(x) - mean(y)) / sp
}

# @web-start Small samples: t and F tests, 500 repeated draws
# ---- Small samples: n = 20 per class, log(body_chars) ----
small_tests <- function(n = 20) {
  x <- sample(train$log_body[train$class == "phishing"], n)
  y <- sample(train$log_body[train$class == "legitimate"], n)
  one <- stats::t.test(x, mu = mu_legit)
  welch <- stats::t.test(x, y)
  ft <- stats::var.test(x, y)
  one_res <- tp$test_result("One-sample t, phishing log(body_chars), n = 20",
                            sprintf("mu = %.3f", mu_legit), sprintf("mu != %.3f", mu_legit),
                            "t", unname(one$statistic), stats::qt(0.975, n - 1), one$p.value,
                            "Cohen's d", (mean(x) - mu_legit) / stats::sd(x))
  welch_res <- tp$test_result("Welch t, phishing vs legitimate log(body_chars), n = 20 each",
                              "mu_phish = mu_legit", "mu_phish != mu_legit", "t",
                              unname(welch$statistic), stats::qt(0.975, unname(welch$parameter)),
                              welch$p.value, "Cohen's d", pooled_d(x, y))
  f_res <- tp$test_result("F test of variances, phishing vs legitimate, n = 20 each",
                          "var_phish = var_legit", "var_phish != var_legit", "F",
                          unname(ft$statistic), stats::qf(c(0.025, 0.975), n - 1, n - 1),
                          ft$p.value, "variance ratio", unname(ft$estimate))
  list(one_sample = one_res, welch = welch_res, f_test = f_res)
}
first_draw <- small_tests()
reps <- replicate(500, vapply(small_tests(), function(r) r$p_value < 0.05, logical(1)))
rejection_rate <- rowMeans(reps)
# @web-end

# ---- Chi-square GOF: n_urls in legitimate vs Poisson, pooling expected < 5 ----
pool_tail <- function(obs, expd) {
  while (length(expd) > 2 && expd[length(expd)] < 5) {
    k <- length(expd)
    obs[k - 1] <- obs[k - 1] + obs[k]
    expd[k - 1] <- expd[k - 1] + expd[k]
    obs <- obs[-k]
    expd <- expd[-k]
  }
  list(obs = obs, expd = expd)
}
gof_poisson <- function(x) {
  lambda <- mean(x)
  k_max <- max(x)
  obs <- tabulate(x + 1, nbins = k_max + 1)
  expd <- length(x) * c(stats::dpois(0:(k_max - 1), lambda),
                        stats::ppois(k_max - 1, lambda, lower.tail = FALSE))
  pooled <- pool_tail(obs, expd)
  chi2 <- sum((pooled$obs - pooled$expd)^2 / pooled$expd)
  df <- length(pooled$obs) - 1 - 1
  res <- tp$test_result("Chi-square GOF, legitimate n_urls vs Poisson",
                        sprintf("n_urls ~ Poisson(%.3f)", lambda), "n_urls is not Poisson",
                        "chi2", chi2, stats::qchisq(0.95, df),
                        stats::pchisq(chi2, df, lower.tail = FALSE), "Cohen's w",
                        sqrt(chi2 / length(x)))
  list(res = res, bins = length(pooled$obs), df = df, lambda = lambda)
}
gof <- gof_poisson(train$n_urls[train$class == "legitimate"])

# @web-start Chi-square independence, Cramer's V, odds ratio, Holm
# ---- Chi-square independence: binary feature x class ----
odds_ratio_ci <- function(a, b, c, d) {
  if (min(a, b, c, d) == 0) {
    a <- a + 0.5
    b <- b + 0.5
    c <- c + 0.5
    d <- d + 0.5
  }
  log_or <- log(a * d / (b * c))
  se <- sqrt(1 / a + 1 / b + 1 / c + 1 / d)
  exp(c(log_or, log_or - 1.96 * se, log_or + 1.96 * se))
}
independence_row <- function(f) {
  tab <- table(train[[f]], train$class)
  ct <- suppressWarnings(stats::chisq.test(tab, correct = FALSE))
  ph <- train$class == "phishing"
  lg <- train$class == "legitimate"
  or <- odds_ratio_ci(sum(ph & train[[f]] == 1), sum(ph & train[[f]] == 0),
                      sum(lg & train[[f]] == 1), sum(lg & train[[f]] == 0))
  data.frame(feature = f, chi2 = unname(ct$statistic), df = unname(ct$parameter),
             critical = stats::qchisq(0.95, ct$parameter), p_value = ct$p.value,
             cramers_v = sqrt(unname(ct$statistic) / (sum(tab) * (min(dim(tab)) - 1))),
             odds_ratio = or[1], or_low = or[2], or_high = or[3],
             min_expected = min(ct$expected))
}
indep <- do.call(rbind, lapply(binary_features, independence_row))
indep$p_holm <- stats::p.adjust(indep$p_value, method = "holm")
indep$decision <- ifelse(indep$p_holm < 0.05, "reject H0", "fail to reject H0")
indep$passes <- indep$p_holm < 0.05 & indep$cramers_v >= 0.1
indep <- indep[order(-indep$cramers_v), ]
# @web-end
effect_note <- paste("With about 57k emails almost any difference is significant;",
                     "Cramer's V and the odds ratio show which ones matter.")

# ---- ANOVA on log(body_chars) ----
anova_terms <- function(fit, label, response = "log(body_chars)") {
  tab <- summary(fit)[[1]]
  rownames(tab) <- trimws(rownames(tab))
  ss_res <- tab["Residuals", "Sum Sq"]
  df_res <- tab["Residuals", "Df"]
  terms <- setdiff(rownames(tab), "Residuals")
  lapply(stats::setNames(terms, terms), function(term) {
    tp$test_result(paste0(label, ": ", term), paste("no", term, "effect on mean", response),
                   paste("some", term, "level means differ"), "F", tab[term, "F value"],
                   stats::qf(0.95, tab[term, "Df"], df_res), tab[term, "Pr(>F)"],
                   "partial eta^2", tab[term, "Sum Sq"] / (tab[term, "Sum Sq"] + ss_res))
  })
}
# @web-start One-, two- and three-way ANOVA, Levene
one_way <- stats::aov(log_body ~ class, data = train)
multi_sources <- names(which(tapply(train$class, train$source, function(x) {
  length(unique(x))
}) >= 2))
multi <- train[train$source %in% multi_sources, ]
two_way <- stats::aov(log_body ~ class * source, data = multi)
three_way <- stats::aov(log_body ~ class * source * has_html, data = multi)
anova_results <- c(anova_terms(one_way, "One-way"), anova_terms(two_way, "Two-way"),
                   anova_terms(three_way, "Three-way"))
levene <- car::leveneTest(log_body ~ factor(class), data = train)
# @web-end
sd_by_class <- tapply(train$log_body, train$class, stats::sd)
levene_res <- tp$test_result("Levene, log(body_chars) by class", "equal variances",
                             "some variances differ", "F", levene[1, "F value"],
                             stats::qf(0.95, levene[1, "Df"], levene[2, "Df"]),
                             levene[1, "Pr(>F)"], "SD ratio max/min",
                             max(sd_by_class) / min(sd_by_class))
resid <- stats::residuals(one_way)
resid_check <- c(skewness = moments::skewness(resid), kurtosis = moments::kurtosis(resid),
                 shapiro_p_5000 = stats::shapiro.test(sample(resid, 5000))$p.value)
qq <- ggplot(data.frame(r = resid), aes(sample = .data$r)) +
  stat_qq(size = 0.4, alpha = 0.3) +
  stat_qq_line(colour = "#c0392b") +
  labs(x = "normal quantile", y = "residual", title = "One-way ANOVA residuals, QQ plot") +
  theme_minimal()
ggsave("outputs/figures/m6_anova_residual_qq.png", qq, width = 6, height = 4, dpi = 120)
# @web-start Tukey HSD
tukey <- as.data.frame(stats::TukeyHSD(one_way)$class)
# @web-end

# @web-start Randomized block design
# ---- DOE layouts on observational data ----
rbd_data <- stats::aggregate(caps_ratio ~ class + source, data = multi, FUN = mean)
rbd_fit <- stats::aov(caps_ratio ~ class + source, data = rbd_data)
rbd_results <- anova_terms(rbd_fit, "RBD", "caps_ratio")
# @web-end

# @web-start Latin square design (3 x 3)
# All 12 Latin squares of order 3: class permutations over the two cyclic patterns.
latin_candidates <- function(classes) {
  perms <- list(c(1, 2, 3), c(1, 3, 2), c(2, 1, 3), c(2, 3, 1), c(3, 1, 2), c(3, 2, 1))
  out <- list()
  for (sign in c(1, -1)) {
    for (p in perms) {
      out[[length(out) + 1]] <- outer(1:3, 1:3, function(i, j) classes[p][(i + sign * j) %% 3 + 1])
    }
  }
  out
}
# Rows = body length tercile, columns = n_urls band; first arrangement with every cell n >= 30.
latin_square <- function(min_n = 30) {
  row <- cut(train$body_chars, stats::quantile(train$body_chars, c(0, 1 / 3, 2 / 3, 1)),
             labels = c("short", "medium", "long"), include.lowest = TRUE)
  col <- cut(train$n_urls, c(-Inf, 0, 2, Inf), labels = c("0", "1-2", "3+"))
  counts <- table(row, col, train$class)
  for (sq in latin_candidates(c("legitimate", "phishing", "spam"))) {
    cells <- expand.grid(row = levels(row), col = levels(col), stringsAsFactors = FALSE)
    cells$class <- sq[cbind(match(cells$row, levels(row)), match(cells$col, levels(col)))]
    cells$n <- counts[cbind(cells$row, cells$col, cells$class)]
    if (min(cells$n) >= min_n) break
  }
  cells$exclam <- vapply(seq_len(nrow(cells)), function(i) {
    mean(train$exclam_count[row == cells$row[i] & col == cells$col[i] &
                              train$class == cells$class[i]])
  }, numeric(1))
  cells
}
lsd_data <- latin_square()
lsd_fit <- stats::aov(exclam ~ row + col + class, data = lsd_data)
lsd_results <- anova_terms(lsd_fit, "LSD", "exclam_count")
# @web-end
doe_note <- paste("Observational data arranged in DOE layouts: classes were not randomly",
                  "assigned, so effects are associations, not causal treatment effects.",
                  "CRD = the one-way ANOVA above.")

saveRDS(list(
  small_first_draw = tp$tests_to_df(first_draw), small_rejection_rate = rejection_rate,
  gof = tp$tests_to_df(list(gof$res)), gof_bins = gof$bins, gof_df = gof$df,
  independence = indep, effect_note = effect_note,
  anova = tp$tests_to_df(anova_results), levene = tp$tests_to_df(list(levene_res)),
  residual_check = resid_check, tukey = tukey, multi_sources = multi_sources,
  rbd_data = rbd_data, rbd = tp$tests_to_df(rbd_results),
  lsd_data = lsd_data, lsd = tp$tests_to_df(lsd_results), doe_note = doe_note,
  figures = "outputs/figures/m6_anova_residual_qq.png"
), "outputs/results/m6.rds")

invisible(lapply(first_draw, tp$print_test))
cat("Rejection rate over 500 draws:", sprintf("%s %.3f", names(rejection_rate), rejection_rate),
    "\n\n")
tp$print_test(gof$res)
cat("  bins after pooling:", gof$bins, "df:", gof$df, "\n\nIndependence (ranked by V):\n")
print(indep[, c("feature", "chi2", "cramers_v", "odds_ratio", "or_low", "or_high", "p_holm",
                "min_expected", "passes")], digits = 3, row.names = FALSE)
cat(effect_note, "\n\n")
invisible(lapply(c(anova_results, list(levene_res)), tp$print_test))
cat("Residuals:", sprintf("%s %.3g", names(resid_check), resid_check), "\nTukey HSD:\n")
print(round(tukey, 4))
cat("\nRBD sources:", paste(multi_sources, collapse = ", "), "\n")
invisible(lapply(c(rbd_results, lsd_results), tp$print_test))
cat("LSD cell sizes:", paste(lsd_data$n, collapse = ", "), "\n", doe_note, "\n")
