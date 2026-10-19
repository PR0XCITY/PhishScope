root <- testthat::test_path("..", "..")
source(file.path(root, "R", "phishscore.R"))
source(file.path(root, "R", "reliability.R"))

hand_model <- list(features = c("a", "b"), p_phish = c(a = 0.8, b = 0.6),
                   p_legit = c(a = 0.2, b = 0.3), prior = 0.5)

test_that("posterior matches hand-computed values", {
  one <- list(features = "a", p_phish = c(a = 0.8), p_legit = c(a = 0.2), prior = 0.5)
  expect_equal(phishscore_posterior(one, data.frame(a = c(1, 0))), c(0.8, 0.2))
  # x = (1, 0), prior 0.1: L1 = 0.8 * 0.4 = 0.32, L0 = 0.2 * 0.7 = 0.14,
  # so the posterior is 0.032 over (0.032 + 0.126), about 0.202532
  post <- phishscore_posterior(hand_model, data.frame(a = 1, b = 0), prior = 0.1)
  expect_equal(post, 0.032 / 0.158, tolerance = 1e-12)
})

test_that("fit uses Laplace smoothing", {
  df <- data.frame(class = c("phishing", "phishing", "legitimate", "spam"), a = c(1, 1, 0, 1))
  m <- fit_phishscore(df, "a")
  expect_equal(unname(m$p_phish), 3 / 4)
  expect_equal(unname(m$p_legit), 1 / 3)
  expect_equal(m$prior, 2 / 3)
})

test_that("series and parallel match hand values", {
  expect_equal(parallel_prob(c(0.5, 0.2)), 0.6)
  expect_equal(series_prob(c(0.5, 0.2)), 0.1)
  expect_equal(user_reliability(100, 0.01), 0.99^100)
  expect_equal(user_reliability(100, 0.01), 0.366032, tolerance = 1e-6)
  expect_equal(mttf_emails(0.01), 100)
  expect_equal(availability(90, 2), 90 / 92)
})

test_that("Wilson interval and AUC match hand values", {
  ci <- wilson_ci(50, 100)
  expect_equal(unname(ci), c(0.40383, 0.59617), tolerance = 1e-4)
  # Pairs: 0.9 beats both negatives, 0.6 ties 0.6 (one half) and beats 0.1: 3.5 / 4
  expect_equal(auc_rank(c(0.9, 0.6, 0.6, 0.1), c(TRUE, TRUE, FALSE, FALSE)), 0.875)
})

test_that("classification metrics count the confusion matrix", {
  truth <- c(TRUE, TRUE, TRUE, FALSE, FALSE)
  pred <- c(TRUE, TRUE, FALSE, TRUE, FALSE)
  m <- classification_metrics(truth, pred)
  expect_equal(unname(m$metrics[, "estimate"]), c(2 / 3, 1 / 2, 2 / 3, 4 / 6))
  expect_equal(m$confusion["phishing", "phishing"], 2)
  expect_equal(m$confusion["phishing", "legitimate"], 1)
  expect_equal(m$confusion["legitimate", "phishing"], 1)
})
