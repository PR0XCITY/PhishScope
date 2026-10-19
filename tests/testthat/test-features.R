root <- testthat::test_path("..", "..")
source(file.path(root, "R", "features.R"))
source(file.path(root, "R", "load.R"))

fixture <- utils::read.csv(testthat::test_path("fixtures", "emails.csv"),
                           colClasses = "character", na.strings = "")
fixture$label <- as.integer(fixture$label)
lexicon <- load_lexicon(file.path(root, "config", "features.yml"))
feats <- extract_features(fixture$subject, fixture$body, lexicon)

expected <- data.frame(
  n_urls = c(1L, 2L, 0L, 0L),
  has_url = c(1L, 1L, 0L, 0L),
  ip_url = c(1L, 0L, 0L, 0L),
  shortener_url = c(0L, 1L, 0L, 0L),
  at_in_url = c(0L, 1L, 0L, 0L),
  urgency_count = c(0L, 0L, 6L, 0L),
  credential_count = c(0L, 0L, 4L, 0L),
  money_count = c(0L, 0L, 0L, 0L),
  has_urgency = c(0L, 0L, 1L, 0L),
  has_credential = c(0L, 0L, 1L, 0L),
  has_money = c(0L, 0L, 0L, 0L),
  generic_greeting = c(0L, 0L, 1L, 0L),
  exclam_count = c(1L, 0L, 1L, 0L),
  caps_ratio = c(2 / 49, 2 / 56, 22 / 113, 4 / 50),
  body_chars = c(65L, 64L, 110L, 50L),
  n_words = c(6L, 5L, 17L, 11L),
  has_html = c(1L, 0L, 0L, 0L),
  subject_caps = c(0L, 0L, 1L, 0L)
)

test_that("every feature matches hand-computed values", {
  expect_identical(names(feats), names(expected))
  for (col in setdiff(names(expected), "caps_ratio")) {
    expect_identical(feats[[col]], expected[[col]], info = col)
  }
  expect_equal(feats$caps_ratio, expected$caps_ratio, tolerance = 1e-12)
})

test_that("whole-word matching ignores substrings", {
  f <- extract_features("", "accounts pinned login2 suspend suspended", lexicon)
  expect_identical(f$credential_count, 0L)
  expect_identical(f$urgency_count, 2L)
})

test_that("emails without 2+ letter words keep one row each", {
  f <- extract_features(c("", "a"), c("1 2 !", ""), lexicon)
  expect_identical(nrow(f), 2L)
  expect_identical(f$caps_ratio, c(0, 0))
})

test_that("class mapping follows label and source", {
  expect_identical(
    assign_class(fixture$label, fixture$source),
    c("spam", "phishing", "phishing", "legitimate")
  )
  expect_identical(assign_class(c(0L, 0L), c("Nazario", "SpamAssasin")),
                   c("legitimate", "legitimate"))
})

test_that("dates parse best effort", {
  d <- parse_dates(fixture$date_raw)
  expect_identical(format(d[1], "%Y-%m-%d %H:%M", tz = "UTC"), "2008-08-05 23:31")
  expect_false(is.na(d[2]))
  expect_true(all(is.na(d[3:4])))
})

test_that("dedup uses normalized subject + body and drops empty bodies", {
  dup <- fixture[4, ]
  dup$id <- "fx_dup"
  dup$subject <- "LUNCH   tomorrow"
  dup$body <- "hi sam,\n are we still on for LUNCH at noon?  thanks. "
  empty <- fixture[1, ]
  empty$id <- "fx_empty"
  empty$body <- "   "
  out <- suppressMessages(clean_emails(rbind(fixture, dup, empty)))
  expect_identical(out$id, fixture$id)
})
