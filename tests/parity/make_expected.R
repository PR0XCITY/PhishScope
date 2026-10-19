# Writes tests/parity/expected.json: R features and PhishScore on the fixture emails,
# using web/model.json, so web/features.js can be checked against it.
# Run from the project root: Rscript tests/parity/make_expected.R

source("R/features.R")
source("R/phishscore.R")

model <- model_from_json("web/model.json")
fixture <- utils::read.csv("tests/testthat/fixtures/emails.csv", colClasses = "character",
                           na.strings = "")
feats <- extract_features(fixture$subject, fixture$body, model$lexicon)
score_prior <- phishscore_posterior(model, feats)
score_1pct <- phishscore_posterior(model, feats, prior = 0.01)

cases <- lapply(seq_len(nrow(fixture)), function(i) {
  list(id = fixture$id[i],
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
