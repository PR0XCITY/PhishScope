# Phase 1: raw CSVs -> data/processed/emails.parquet (features, no text) + text.parquet.

source("R/load.R")
source("R/features.R")
source("R/split.R")

set.seed(2026)
emails <- load_emails("data/raw")
feats <- extract_features(emails$subject, emails$body, load_lexicon("config/features.yml"))
meta <- data.frame(id = emails$id, class = emails$class, source = emails$source,
                   date = emails$date)
processed <- split_train_test(cbind(meta, feats), prop = 0.7, seed = 2026)

dir.create("data/processed", showWarnings = FALSE, recursive = TRUE)
arrow::write_parquet(processed, "data/processed/emails.parquet")
arrow::write_parquet(emails[, c("id", "subject", "body")], "data/processed/text.parquet")

cat("\nRows by class x source:\n")
print(table(processed$source, processed$class))
cat("\nRows by set:\n")
print(table(processed$set))
cat("\nRows by class x set:\n")
print(table(processed$class, processed$set))
