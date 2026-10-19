# Module 5: large-sample Z tests with manual formulas, cross-checked against prop.test / t.test.

tp <- new.env()
sys.source("R/tests_print.R", envir = tp)

set.seed(2026)
dir.create("outputs/results", showWarnings = FALSE, recursive = TRUE)

emails <- arrow::read_parquet("data/processed/emails.parquet")
train <- as.data.frame(emails[emails$set == "train", ])
phish <- train[train$class == "phishing", ]
legit <- train[train$class == "legitimate", ]
results <- list()
checks <- list()

# @web-start One-proportion Z test
# Single proportion: share of phishing with at least one URL.
x_url <- sum(phish$n_urls >= 1)
results$url_share <- tp$z_one_prop(
  x_url, nrow(phish), 0.5, alternative = "greater",
  name = "Phishing share with 1+ URL", h0 = "p = 0.5", h1 = "p > 0.5"
)
pt <- stats::prop.test(x_url, nrow(phish), 0.5, alternative = "greater", correct = FALSE)
checks$url_share <- c(manual = results$url_share$statistic^2,
                      builtin = unname(pt$statistic), builtin_p = pt$p.value)
# @web-end

# @web-start Two-proportion Z, cross-checked with prop.test
# Difference of proportions, phishing vs legitimate.
for (f in c("has_url", "has_urgency", "has_credential", "generic_greeting")) {
  x1 <- sum(phish[[f]])
  x2 <- sum(legit[[f]])
  results[[f]] <- tp$z_two_prop(
    x1, nrow(phish), x2, nrow(legit),
    name = paste0("P(", f, ") phishing vs legitimate"),
    h0 = "p_phish = p_legit", h1 = "p_phish != p_legit"
  )
  pt <- stats::prop.test(c(x1, x2), c(nrow(phish), nrow(legit)), correct = FALSE)
  checks[[f]] <- c(manual = results[[f]]$statistic^2,
                   builtin = unname(pt$statistic), builtin_p = pt$p.value)
}
# @web-end

# Single mean: phishing caps_ratio against the legitimate mean as the reference value.
mu_ref <- mean(legit$caps_ratio)
results$caps_ratio <- tp$z_one_mean(
  mean(phish$caps_ratio), stats::sd(phish$caps_ratio), nrow(phish), mu_ref,
  name = "Mean caps_ratio of phishing vs legitimate reference",
  h0 = sprintf("mu_phish = %.4f", mu_ref), h1 = sprintf("mu_phish != %.4f", mu_ref)
)

# @web-start Difference of means, cross-checked with t.test
# Difference of means, phishing vs legitimate.
two_mean <- function(x, y, label) {
  res <- tp$z_two_mean(mean(x), stats::sd(x), length(x), mean(y), stats::sd(y), length(y),
                       name = paste("Mean", label, "phishing vs legitimate"),
                       h0 = "mu_phish = mu_legit", h1 = "mu_phish != mu_legit")
  tt <- stats::t.test(x, y)
  list(res = res, check = c(manual = res$statistic, builtin = unname(tt$statistic),
                            builtin_p = tt$p.value))
}
tm <- list(log_body_chars = two_mean(log(phish$body_chars), log(legit$body_chars),
                                     "log(body_chars)"),
           exclam_count = two_mean(phish$exclam_count, legit$exclam_count, "exclam_count"))
for (k in names(tm)) {
  results[[k]] <- tm[[k]]$res
  checks[[k]] <- tm[[k]]$check
}
# @web-end

# @web-start Power with power.prop.test
# Power for the has_urgency difference.
p_ph <- mean(phish$has_urgency)
p_lg <- mean(legit$has_urgency)
power_at_n <- stats::power.prop.test(n = nrow(phish), p1 = p_ph, p2 = p_lg)$power
n_for_80 <- stats::power.prop.test(p1 = p_ph, p2 = p_lg, power = 0.8)$n
small_effect_n <- stats::power.prop.test(p1 = p_lg + 0.01, p2 = p_lg, power = 0.8)$n
# @web-end
error_note <- paste(
  "A Type I error is a false alarm: declaring that a feature separates phishing from",
  "legitimate mail when it does not, held at alpha = 0.05.",
  "A Type II error is a missed phish: failing to detect a real difference, and power",
  "(1 - beta) is the chance of catching it."
)

# Effect sizes of the phishing vs legitimate tests (Cohen's h or d).
effects <- tp$tests_to_df(results[names(results) != "url_share"])
effects$label <- factor(names(results)[names(results) != "url_share"],
                        rev(names(results)[names(results) != "url_share"]))
effect_plot <- ggplot2::ggplot(effects, ggplot2::aes(x = .data$effect, y = .data$label,
                                                     fill = .data$effect_name)) +
  ggplot2::geom_col() +
  ggplot2::geom_vline(xintercept = c(-0.2, 0.2, 0.5, 0.8), linetype = "dotted", colour = "grey50") +
  ggplot2::labs(x = "effect size (dotted: 0.2 small, 0.5 medium, 0.8 large)", y = NULL,
                fill = NULL, title = "Phishing vs legitimate: effect sizes of Z tests") +
  ggplot2::theme_minimal()
dir.create("outputs/figures", showWarnings = FALSE, recursive = TRUE)
fig_effects <- "outputs/figures/m5_effect_sizes.png"
ggplot2::ggsave(fig_effects, effect_plot, width = 7, height = 4, dpi = 120)

saveRDS(list(tests = tp$tests_to_df(results), results = results, checks = checks,
             power = c(p_phish = p_ph, p_legit = p_lg, power_at_n = power_at_n,
                       n_per_group_80 = n_for_80, n_per_group_80_1pt = small_effect_n),
             error_note = error_note, figures = fig_effects),
        "outputs/results/m5.rds")

invisible(lapply(results, tp$print_test))
cat("\nCross-checks (manual z^2 vs prop.test X^2; manual z vs Welch t):\n")
print(round(do.call(rbind, lapply(checks, function(x) x[1:2])), 4))
cat(sprintf(paste("\nPower (has_urgency, p %.3f vs %.3f): %.4f at n = %d per group;",
                  "n for 80%% power %.1f; n to detect +1 point %.0f\n"),
            p_ph, p_lg, power_at_n, nrow(phish), n_for_80, small_effect_n))
cat(error_note, "\n")
