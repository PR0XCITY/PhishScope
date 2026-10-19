# Module 4: Binomial, Poisson, Normal, Exponential, and Gamma/Weibull/lognormal fits (train set).

library(ggplot2)

set.seed(2026)
fig_dir <- "outputs/figures"
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)
dir.create("outputs/results", showWarnings = FALSE, recursive = TRUE)

emails <- arrow::read_parquet("data/processed/emails.parquet")
train <- as.data.frame(emails[emails$set == "train", ])
classes <- sort(unique(train$class))
save_fig <- function(name, plot, width = 7, height = 4) {
  path <- file.path(fig_dir, name)
  ggsave(path, plot, width = width, height = height, dpi = 120)
  path
}

# Binomial: batches of 50 drawn from phishing + legitimate, reweighted to prevalence p.
simulate_batches <- function(p, n_batch = 50, n_sim = 2000) {
  pool <- train$class[train$class %in% c("phishing", "legitimate")]
  is_phish <- pool == "phishing"
  w <- ifelse(is_phish, p / sum(is_phish), (1 - p) / sum(!is_phish))
  k_sim <- replicate(n_sim, sum(is_phish[sample.int(length(pool), n_batch, TRUE, prob = w)]))
  k <- 0:max(k_sim, stats::qbinom(0.9999, n_batch, p))
  data.frame(p = p, k = k, theoretical = stats::dbinom(k, n_batch, p),
             simulated = tabulate(k_sim + 1, nbins = length(k)) / n_sim,
             sim_mean = mean(k_sim), sim_var = stats::var(k_sim))
}
binom <- rbind(simulate_batches(0.01), simulate_batches(0.10))
binom_summary <- do.call(rbind, lapply(split(binom, binom$p), function(b) {
  data.frame(p = b$p[1], theory_mean = 50 * b$p[1], sim_mean = b$sim_mean[1],
             theory_var = 50 * b$p[1] * (1 - b$p[1]), sim_var = b$sim_var[1],
             total_variation = 0.5 * sum(abs(b$theoretical - b$simulated)))
}))
binom_long <- rbind(
  data.frame(binom[, c("p", "k")], source = "theoretical", prob = binom$theoretical),
  data.frame(binom[, c("p", "k")], source = "simulated", prob = binom$simulated)
)
binom_plot <- ggplot(binom_long, aes(x = .data$k, y = .data$prob, fill = .data$source)) +
  geom_col(position = "dodge") +
  facet_wrap(~ paste0("p = ", p), scales = "free") +
  labs(x = "phishing emails in a batch of 50", y = "P(K = k)", fill = NULL,
       title = "Binomial(50, p) vs 2000 simulated batches") +
  theme_minimal()
fig_binom <- save_fig("m4_binomial_batches.png", binom_plot, width = 8)

# Poisson: n_urls by class, lambda = mean, observed vs expected counts 0..9 and 10+.
poisson_fit <- function(x, cap = 10) {
  lambda <- mean(x)
  k <- 0:cap
  obs <- tabulate(pmin(x, cap) + 1, nbins = cap + 1) / length(x)
  expd <- c(stats::dpois(0:(cap - 1), lambda), stats::ppois(cap - 1, lambda, lower.tail = FALSE))
  list(table = data.frame(k = k, observed = obs, expected = expd),
       lambda = lambda, dispersion = stats::var(x) / lambda)
}
pois <- lapply(stats::setNames(classes, classes), function(cl) {
  poisson_fit(train$n_urls[train$class == cl])
})
pois_long <- do.call(rbind, lapply(classes, function(cl) {
  t <- pois[[cl]]$table
  rbind(data.frame(class = cl, k = t$k, kind = "observed", prob = t$observed),
        data.frame(class = cl, k = t$k, kind = "Poisson", prob = t$expected))
}))
pois_plot <- ggplot(pois_long, aes(x = .data$k, y = .data$prob, fill = .data$kind)) +
  geom_col(position = "dodge") +
  scale_x_continuous(breaks = 0:10, labels = c(0:9, "10+")) +
  facet_wrap(~class) +
  labs(x = "n_urls", y = "probability", fill = NULL,
       title = "n_urls: observed vs Poisson(lambda = mean)") +
  theme_minimal()
fig_pois <- save_fig("m4_poisson_n_urls.png", pois_plot, width = 9)
pois_summary <- data.frame(class = classes,
                           lambda = sapply(pois, `[[`, "lambda"),
                           dispersion_index = sapply(pois, `[[`, "dispersion"),
                           p0_observed = sapply(pois, function(p) p$table$observed[1]),
                           p0_poisson = sapply(pois, function(p) p$table$expected[1]))

# Normal: log(body_chars) by class, QQ plot, Shapiro-Wilk on up to 5000 per class.
train$log_body_chars <- log(train$body_chars)
normal_summary <- do.call(rbind, lapply(classes, function(cl) {
  x <- train$log_body_chars[train$class == cl]
  s <- if (length(x) > 5000) sample(x, 5000) else x
  sw <- stats::shapiro.test(s)
  data.frame(class = cl, mean = mean(x), sd = stats::sd(x),
             skewness = moments::skewness(x), n_shapiro = length(s),
             W = unname(sw$statistic), p_value = sw$p.value)
}))
qq_normal <- ggplot(train, aes(sample = .data$log_body_chars)) +
  stat_qq(size = 0.4, alpha = 0.3) +
  stat_qq_line(colour = "#c0392b") +
  facet_wrap(~class, scales = "free") +
  labs(x = "theoretical normal quantile", y = "log(body_chars)",
       title = "Normal QQ plot of log(body_chars)") +
  theme_minimal()
fig_qq_normal <- save_fig("m4_qq_normal_log_body.png", qq_normal, width = 9)

# Exponential: inter-arrival days of dated Nazario emails in the densest 365-day window.
densest_window <- function(times, days = 365) {
  t <- sort(as.numeric(times)) / 86400
  ends <- findInterval(t + days, t)
  start <- which.max(ends - seq_along(t))
  t[start:ends[start]]
}
naz_dates <- train$date[train$source == "Nazario" & !is.na(train$date)]
naz_dates <- naz_dates[as.integer(format(naz_dates, "%Y")) >= 1995]
window_days <- densest_window(naz_dates)
gaps <- diff(window_days)
expo <- NULL
fig_qq_exp <- NULL
if (length(gaps) >= 30 && max(gaps) < 30) {
  rate <- 1 / mean(gaps)
  probs <- stats::ppoints(length(gaps))
  qq_df <- data.frame(theoretical = stats::qexp(probs, rate), observed = sort(gaps))
  expo <- list(n_emails = length(window_days), n_gaps = length(gaps), rate_per_day = rate,
               mean_gap_days = mean(gaps), cv = stats::sd(gaps) / mean(gaps),
               zero_gaps = mean(gaps < 1 / 1440),
               window = format(as.POSIXct(range(window_days) * 86400, tz = "UTC"), "%Y-%m-%d"),
               ks = suppressWarnings(stats::ks.test(gaps, "pexp", rate)))
  qq_exp <- ggplot(qq_df, aes(x = .data$theoretical, y = .data$observed)) +
    geom_point(size = 0.8, alpha = 0.5) +
    geom_abline(colour = "#c0392b") +
    labs(x = "Exponential quantile (days)", y = "observed gap (days)",
         title = "Exponential QQ plot, Nazario inter-arrival times") +
    theme_minimal()
  fig_qq_exp <- save_fig("m4_qq_exponential_nazario.png", qq_exp, width = 6)
}

# Gamma vs Weibull vs lognormal on body_chars (in thousands; scaling keeps AIC ranking).
fit_candidates <- function(x) {
  fits <- lapply(c(gamma = "gamma", weibull = "weibull", lnorm = "lnorm"), function(d) {
    args <- list(x, d, method = "mle")
    if (d != "lnorm") args$lower <- c(0, 0)
    tryCatch(do.call(fitdistrplus::fitdist, args), error = function(e) {
      message("fit failed for ", d, ": ", conditionMessage(e))
      NULL
    })
  })
  ok <- !vapply(fits, is.null, logical(1))
  data.frame(distribution = names(fits)[ok],
             aic = vapply(fits[ok], `[[`, numeric(1), "aic"),
             bic = vapply(fits[ok], `[[`, numeric(1), "bic"))
}
fit_table <- do.call(rbind, lapply(classes, function(cl) {
  tab <- fit_candidates(train$body_chars[train$class == cl] / 1000)
  tab$class <- cl
  tab$winner <- tab$aic == min(tab$aic)
  tab
}))

saveRDS(list(
  binomial = binom, binomial_summary = binom_summary, poisson = pois_summary,
  poisson_tables = lapply(pois, `[[`, "table"), normal = normal_summary,
  exponential = expo, fits = fit_table,
  figures = c(fig_binom, fig_pois, fig_qq_normal, fig_qq_exp)
), "outputs/results/m4.rds")

cat("Binomial batches (n = 50, 2000 sims):\n")
print(binom_summary, digits = 3, row.names = FALSE)
cat("\nPoisson fit of n_urls:\n")
print(pois_summary, digits = 3, row.names = FALSE)
cat("\nNormality of log(body_chars):\n")
print(normal_summary, digits = 3, row.names = FALSE)
if (is.null(expo)) {
  cat("\nExponential: Nazario dates too sparse in the densest window; skipped.\n")
} else {
  cat(sprintf(paste("\nExponential: %d gaps in %s to %s, rate %.3f/day, mean %.3f days,",
                    "CV %.2f, KS D %.3f p %.3g\n"),
              expo$n_gaps, expo$window[1], expo$window[2], expo$rate_per_day,
              expo$mean_gap_days, expo$cv, expo$ks$statistic, expo$ks$p.value))
}
cat("\nGamma / Weibull / lognormal on body_chars (thousands):\n")
print(fit_table[, c("class", "distribution", "aic", "bic", "winner")], digits = 6,
      row.names = FALSE)
