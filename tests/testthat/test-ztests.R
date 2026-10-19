source(file.path(testthat::test_path("..", ".."), "R", "tests_print.R"))

test_that("one-proportion Z matches the textbook value", {
  # 60 of 100, p0 = 0.5: z = 0.10 / 0.05 = 2.00, upper-tail p = 0.02275
  r <- z_one_prop(60, 100, 0.5, alternative = "greater")
  expect_equal(r$statistic, 2)
  expect_equal(r$p_value, 0.02275, tolerance = 1e-4)
  expect_equal(r$critical, 1.644854, tolerance = 1e-6)
  expect_identical(r$decision, "reject H0")
  pt <- stats::prop.test(60, 100, 0.5, alternative = "greater", correct = FALSE)
  expect_equal(unname(pt$statistic), r$statistic^2)
})

test_that("two-proportion Z matches the textbook value", {
  # 45/100 vs 30/100: pooled 0.375, SE 0.068465, z = 2.1909, two-sided p = 0.02846
  r <- z_two_prop(45, 100, 30, 100)
  expect_equal(r$statistic, 2.1909, tolerance = 1e-4)
  expect_equal(r$p_value, 0.02846, tolerance = 1e-3)
  expect_equal(r$critical, 1.959964, tolerance = 1e-6)
  pt <- stats::prop.test(c(45, 30), c(100, 100), correct = FALSE)
  expect_equal(unname(pt$statistic), r$statistic^2)
  expect_equal(pt$p.value, r$p_value)
})

test_that("one-mean Z matches the textbook value", {
  # x_bar 52, s 10, n 100, mu0 50: z = 2 / 1 = 2, two-sided p = 0.0455, d = 0.2
  r <- z_one_mean(52, 10, 100, 50)
  expect_equal(r$statistic, 2)
  expect_equal(r$p_value, 0.0455, tolerance = 1e-3)
  expect_equal(r$effect, 0.2)
})

test_that("two-mean Z matches the textbook value", {
  # 85 (s 10, n 50) vs 80 (s 12, n 60): SE sqrt(2 + 2.4) = 2.0976, z = 2.3837
  r <- z_two_mean(85, 10, 50, 80, 12, 60)
  expect_equal(r$statistic, 2.3837, tolerance = 1e-4)
  expect_equal(r$p_value, 0.01714, tolerance = 1e-3)
  expect_identical(r$decision, "reject H0")
})

test_that("fail to reject when p exceeds alpha", {
  r <- z_one_prop(52, 100, 0.5, alternative = "greater")
  expect_identical(r$decision, "fail to reject H0")
})
