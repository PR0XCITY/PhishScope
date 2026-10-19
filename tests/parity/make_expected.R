# Writes tests/parity/expected.json: R features and PhishScore on the fixture emails plus
# hand-written edge cases, using web/model.json, so web/features.js can be checked against it.
# Run from the project root: Rscript tests/parity/make_expected.R

source("R/features.R")
source("R/phishscore.R")

model <- model_from_json("web/model.json")
fixture <- utils::read.csv("tests/testthat/fixtures/emails.csv", colClasses = "character",
                           na.strings = "")
edge <- data.frame(
  id = paste0("edge_", 1:8),
  subject = c("FINAL NOTICE: ACT NOW", "ÜRGENT ACCOUNT ALERT", "Re: lunch", "",
              "Hi", "WIN BIG MONEY 100 NOW", "ok", "Dear Customer"),
  body = c(
    "Act\n\t now or your PASSWORD expires!! Visit HTTP://Bit.ly/Ab and http://x@10.0.0.1:80/.",
    "Café login verify your account at https://bank.example.com/épath now",
    "accounts pinned login2 dearcustomer winner_s prize-winner",
    "",
    "\U0001F600 emoji \U0001F600 counts as one char each; dear   friend",
    "Wire   transfer via western\nunion to the beneficiary within 24 hours!",
    "<A HREF=\"https://tinyurl.com/x\">click</a> <html>",
    "  "
  )
)
cases_df <- rbind(fixture[, c("id", "subject", "body")], edge)
cases_df$subject[is.na(cases_df$subject)] <- ""
cases_df$body[is.na(cases_df$body)] <- ""
feats <- extract_features(cases_df$subject, cases_df$body, model$lexicon)
score_prior <- phishscore_posterior(model, feats)
score_1pct <- phishscore_posterior(model, feats, prior = 0.01)

cases <- lapply(seq_len(nrow(cases_df)), function(i) {
  list(id = cases_df$id[i], subject = cases_df$subject[i], body = cases_df$body[i],
       features = lapply(as.list(feats[i, ]), function(v) round(v, 6)),
       score_dataset_prior = round(score_prior[i], 6),
       score_1pct_prior = round(score_1pct[i], 6))
})
jsonlite::write_json(
  list(model_version = jsonlite::read_json("web/model.json")$version,
       fixture = "tests/testthat/fixtures/emails.csv", decimals = 6, cases = cases),
  "tests/parity/expected.json", auto_unbox = TRUE, digits = NA, pretty = TRUE
)
cat("Wrote", length(cases), "cases; scores at dataset prior:",
    paste(round(score_prior, 4), collapse = ", "), "\n")
