source(file.path(testthat::test_path("..", ".."), "R", "rv.R"))

test_that("bayes_posterior matches a hand-computed example", {
  # Hand calc: numerator 0.009, denominator 0.009 + 0.099 = 0.108, posterior 1/12.
  expect_equal(bayes_posterior(0.9, 0.1, 0.01), 1 / 12, tolerance = 1e-12)
  # Hand calc: numerator 0.4, denominator 0.4 + 0.1 = 0.5, posterior 0.8.
  expect_equal(bayes_posterior(0.8, 0.2, 0.5), 0.8, tolerance = 1e-12)
  expect_match(bayes_worked(0.9, 0.1, 0.01), "= 0.0090 / 0.1080 = 0.0833$")
})

test_that("describe returns the expected summaries", {
  d <- describe(c(1, 2, 2, 3, 10))
  expect_equal(unname(d[c("n", "mean", "median", "mode", "q1", "q3", "iqr")]),
               c(5, 3.6, 2, 2, 2, 3, 1))
  # squared deviations 6.76 + 2.56 + 2.56 + 0.36 + 40.96 = 53.2; / 4
  expect_equal(unname(d["variance"]), 13.3)
  expect_equal(unname(d["cv"]), sqrt(13.3) / 3.6)
})

test_that("pmf_capped pools the tail and the CDF ends at 1", {
  p <- pmf_capped(c(0, 0, 1, 3, 12, 40), cap = 3)
  expect_identical(p$value, c("0", "1", "2", "3+"))
  expect_equal(p$pmf, c(2, 1, 0, 3) / 6)
  expect_equal(p$cdf[4], 1)
})

test_that("joint_pmf has margins that sum to 1", {
  j <- joint_pmf(c(1, 1, 0, 0), c(1, 0, 0, 0))
  expect_equal(j["Sum", "Sum"], 1)
  expect_equal(j["1", "1"], 0.25)
  expect_equal(unname(j["1", "Sum"]), 0.5)
})

test_that("MGF derivatives recover mean and variance", {
  x <- c(0, 1, 2, 3)
  emp <- mgf_moments(function(t) log_empirical_mgf(x, t))
  expect_equal(unname(emp), c(1.5, 1.25), tolerance = 1e-6)
  poi <- mgf_moments(function(t) log_poisson_mgf(2, t))
  expect_equal(unname(poi), c(2, 2), tolerance = 1e-6)
})
