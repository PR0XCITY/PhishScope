# Hypothesis test results: a common record, a printer, and manual large-sample Z tests.

# One test as a list: H0, H1, statistic, critical value, p-value, decision, effect size.
test_result <- function(name, h0, h1, stat_name, statistic, critical, p_value,
                        effect_name, effect, alpha = 0.05) {
  list(name = name, h0 = h0, h1 = h1, stat_name = stat_name, statistic = statistic,
       critical = critical, p_value = p_value, alpha = alpha,
       decision = if (p_value < alpha) "reject H0" else "fail to reject H0",
       effect_name = effect_name, effect = effect)
}

print_test <- function(res) {
  crit <- paste(sprintf("%.4g", res$critical), collapse = ", ")
  cat(sprintf("== %s ==\n  H0: %s\n  H1: %s\n", res$name, res$h0, res$h1))
  cat(sprintf("  %s = %.4g | critical (alpha %.2f) = %s | p = %.4g | %s | %s = %.4g\n",
              res$stat_name, res$statistic, res$alpha, crit, res$p_value, res$decision,
              res$effect_name, res$effect))
  invisible(res)
}

tests_to_df <- function(results) {
  do.call(rbind, lapply(results, function(r) {
    data.frame(name = r$name, h0 = r$h0, h1 = r$h1, stat_name = r$stat_name,
               statistic = r$statistic, critical = paste(signif(r$critical, 4), collapse = ", "),
               p_value = r$p_value, decision = r$decision, effect_name = r$effect_name,
               effect = r$effect)
  }))
}

z_critical <- function(alternative, alpha = 0.05) {
  switch(alternative,
         two.sided = stats::qnorm(1 - alpha / 2),
         greater = stats::qnorm(1 - alpha),
         less = stats::qnorm(alpha))
}

z_p_value <- function(z, alternative) {
  switch(alternative,
         two.sided = 2 * stats::pnorm(-abs(z)),
         greater = stats::pnorm(z, lower.tail = FALSE),
         less = stats::pnorm(z))
}

cohens_h <- function(p1, p2) 2 * asin(sqrt(p1)) - 2 * asin(sqrt(p2))

# @web-start Manual one-proportion Z formula
# Z for one proportion: (p_hat minus p0) over the null standard error.
z_one_prop <- function(x, n, p0, alternative = "two.sided", name = "one-proportion Z",
                       h0 = sprintf("p = %g", p0), h1 = NULL) {
  p_hat <- x / n
  z <- (p_hat - p0) / sqrt(p0 * (1 - p0) / n)
  h1 <- if (is.null(h1)) sprintf("p %s %g", alt_symbol(alternative), p0) else h1
  test_result(name, h0, h1, "z", z, z_critical(alternative), z_p_value(z, alternative),
              "Cohen's h", cohens_h(p_hat, p0))
}
# @web-end

# @web-start Manual two-proportion Z formula
# Z for two proportions with the pooled proportion in the standard error.
z_two_prop <- function(x1, n1, x2, n2, alternative = "two.sided", name = "two-proportion Z",
                       h0 = "p1 = p2", h1 = NULL) {
  p1 <- x1 / n1
  p2 <- x2 / n2
  pooled <- (x1 + x2) / (n1 + n2)
  z <- (p1 - p2) / sqrt(pooled * (1 - pooled) * (1 / n1 + 1 / n2))
  h1 <- if (is.null(h1)) sprintf("p1 %s p2", alt_symbol(alternative)) else h1
  test_result(name, h0, h1, "z", z, z_critical(alternative), z_p_value(z, alternative),
              "Cohen's h", cohens_h(p1, p2))
}
# @web-end

# z = (x_bar - mu0) / (s / sqrt(n)); effect d = (x_bar - mu0) / s
z_one_mean <- function(x_bar, s, n, mu0, alternative = "two.sided", name = "one-mean Z",
                       h0 = sprintf("mu = %.4g", mu0), h1 = NULL) {
  z <- (x_bar - mu0) / (s / sqrt(n))
  h1 <- if (is.null(h1)) sprintf("mu %s %.4g", alt_symbol(alternative), mu0) else h1
  test_result(name, h0, h1, "z", z, z_critical(alternative), z_p_value(z, alternative),
              "Cohen's d", (x_bar - mu0) / s)
}

# z = (m1 - m2) / sqrt(s1^2 / n1 + s2^2 / n2); effect d uses the pooled SD
z_two_mean <- function(m1, s1, n1, m2, s2, n2, alternative = "two.sided",
                       name = "two-mean Z", h0 = "mu1 = mu2", h1 = NULL) {
  z <- (m1 - m2) / sqrt(s1^2 / n1 + s2^2 / n2)
  sp <- sqrt(((n1 - 1) * s1^2 + (n2 - 1) * s2^2) / (n1 + n2 - 2))
  h1 <- if (is.null(h1)) sprintf("mu1 %s mu2", alt_symbol(alternative)) else h1
  test_result(name, h0, h1, "z", z, z_critical(alternative), z_p_value(z, alternative),
              "Cohen's d", (m1 - m2) / sp)
}

alt_symbol <- function(alternative) {
  switch(alternative, two.sided = "!=", greater = ">", less = "<")
}
