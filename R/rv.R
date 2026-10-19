# Helpers for Modules 1-2: descriptive statistics and random variables.

# Most frequent value; ties go to the smallest.
stat_mode <- function(x) {
  x <- x[!is.na(x)]
  counts <- table(x)
  as.numeric(names(counts)[which.max(counts)])
}

describe <- function(x) {
  x <- x[!is.na(x)]
  q <- stats::quantile(x, c(0.25, 0.5, 0.75), names = FALSE)
  m <- mean(x)
  s <- stats::sd(x)
  c(
    n = length(x), mean = m, median = q[2], mode = stat_mode(x),
    q1 = q[1], q3 = q[3], iqr = q[3] - q[1], variance = s^2, sd = s,
    cv = if (m != 0) s / m else NA_real_,
    skewness = moments::skewness(x), kurtosis = moments::kurtosis(x)
  )
}

# describe() for every feature x class, long format.
describe_by_class <- function(df, features, class_col = "class") {
  rows <- list()
  for (f in features) {
    for (cl in sort(unique(df[[class_col]]))) {
      d <- describe(df[[f]][df[[class_col]] == cl])
      rows[[length(rows) + 1]] <- data.frame(feature = f, class = cl, t(d))
    }
  }
  do.call(rbind, rows)
}

# PMF and CDF of a count variable, values >= cap pooled into "cap+".
pmf_capped <- function(x, cap = 10) {
  k <- pmin(x, cap)
  p <- tabulate(k + 1, nbins = cap + 1) / length(k)
  data.frame(
    value = c(as.character(0:(cap - 1)), paste0(cap, "+")),
    k = 0:cap, pmf = p, cdf = cumsum(p)
  )
}

rv_moments <- function(x) {
  m <- mean(x)
  c(mean = m, var = mean((x - m)^2))
}

# Joint PMF of two binary variables with marginals.
joint_pmf <- function(a, b, a_name = "a", b_name = "b") {
  tab <- table(factor(a, 0:1), factor(b, 0:1), dnn = c(a_name, b_name)) / length(a)
  stats::addmargins(tab)
}

# P(C | F) = P(F | C) P(C) / [P(F | C) P(C) + P(F | not C) (1 - P(C))]
bayes_posterior <- function(p_f_given_c, p_f_given_not_c, prior) {
  num <- p_f_given_c * prior
  num / (num + p_f_given_not_c * (1 - prior))
}

bayes_worked <- function(p_f_given_c, p_f_given_not_c, prior, feature = "F", cls = "C") {
  post <- bayes_posterior(p_f_given_c, p_f_given_not_c, prior)
  sprintf(
    "P(%s | %s) = (%.4f x %.4f) / (%.4f x %.4f + %.4f x %.4f) = %.4f / %.4f = %.4f",
    cls, feature, p_f_given_c, prior, p_f_given_c, prior, p_f_given_not_c, 1 - prior,
    p_f_given_c * prior, p_f_given_c * prior + p_f_given_not_c * (1 - prior), post
  )
}

# log M(t) via log-sum-exp so heavy tails do not overflow.
log_empirical_mgf <- function(x, t) {
  vapply(t, function(ti) {
    z <- ti * x
    zmax <- max(z)
    zmax + log(mean(exp(z - zmax)))
  }, numeric(1))
}

log_poisson_mgf <- function(lambda, t) {
  lambda * (exp(t) - 1)
}

# Mean and variance from central differences of M(t) at t = 0.
mgf_moments <- function(log_mgf, h = 1e-4) {
  m <- exp(log_mgf(c(-h, 0, h)))
  d1 <- (m[3] - m[1]) / (2 * h)
  d2 <- (m[3] - 2 * m[2] + m[1]) / h^2
  c(mean = d1, var = d2 - d1^2)
}
