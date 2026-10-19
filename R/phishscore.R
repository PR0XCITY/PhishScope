# PhishScore: Bernoulli naive Bayes, phishing vs legitimate, with a caller-supplied prior.

# Laplace-smoothed P(f = 1 | class) = (count + 1) / (n + 2).
fit_phishscore <- function(df, features, class_col = "class") {
  ph <- df[[class_col]] == "phishing"
  lg <- df[[class_col]] == "legitimate"
  smooth <- function(rows) {
    vapply(features, function(f) (sum(df[[f]][rows] == 1) + 1) / (sum(rows) + 2), numeric(1))
  }
  list(features = features, p_phish = smooth(ph), p_legit = smooth(lg),
       prior = sum(ph) / (sum(ph) + sum(lg)), n_phish = sum(ph), n_legit = sum(lg))
}

# Posterior P(phishing | x), computed on the log-odds scale.
phishscore_posterior <- function(model, x, prior = model$prior) {
  x <- as.matrix(x[, model$features, drop = FALSE])
  w1 <- log(model$p_phish / model$p_legit)
  w0 <- log((1 - model$p_phish) / (1 - model$p_legit))
  log_odds <- log(prior / (1 - prior)) + as.vector(x %*% w1 + (1 - x) %*% w0)
  1 / (1 + exp(-log_odds))
}

model_from_json <- function(path) {
  m <- jsonlite::read_json(path, simplifyVector = TRUE)
  feats <- unlist(m$features)
  list(features = feats,
       p_phish = vapply(feats, function(f) m$likelihoods[[f]]$phishing, numeric(1)),
       p_legit = vapply(feats, function(f) m$likelihoods[[f]]$legitimate, numeric(1)),
       prior = m$prior, threshold = m$threshold, lexicon = m$lexicon)
}

# Wilson score interval for x successes in n trials.
wilson_ci <- function(x, n, conf = 0.95) {
  z <- stats::qnorm(1 - (1 - conf) / 2)
  p <- x / n
  denom <- 1 + z^2 / n
  center <- (p + z^2 / (2 * n)) / denom
  half <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / denom
  c(lower = center - half, upper = center + half)
}

# Confusion matrix and rates with Wilson CIs; truth and pred are logical (TRUE = phishing).
classification_metrics <- function(truth, pred) {
  tp <- sum(truth & pred)
  fp <- sum(!truth & pred)
  fn <- sum(truth & !pred)
  tn <- sum(!truth & !pred)
  rate <- function(x, n) c(estimate = x / n, wilson_ci(x, n))
  list(
    confusion = matrix(c(tp, fn, fp, tn), 2, dimnames = list(
      predicted = c("phishing", "legitimate"), actual = c("phishing", "legitimate")
    )),
    metrics = rbind(sensitivity = rate(tp, tp + fn), specificity = rate(tn, tn + fp),
                    precision = rate(tp, tp + fp), f1 = rate(2 * tp, 2 * tp + fp + fn))
  )
}

# AUC by the Mann-Whitney rank formula (ties count one half).
auc_rank <- function(score, truth) {
  r <- rank(score)
  n1 <- sum(truth)
  n0 <- sum(!truth)
  (sum(r[truth]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}

roc_points <- function(score, truth) {
  thr <- c(Inf, sort(unique(score), decreasing = TRUE))
  data.frame(threshold = thr,
             tpr = vapply(thr, function(t) mean(score[truth] >= t), numeric(1)),
             fpr = vapply(thr, function(t) mean(score[!truth] >= t), numeric(1)))
}
