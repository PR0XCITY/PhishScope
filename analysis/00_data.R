# Phase 1: raw CSVs -> data/processed/emails.parquet (features, no text) + text.parquet.

source("R/load.R")
source("R/features.R")
source("R/split.R")

set.seed(2026)
# @web-start Load, harmonize and deduplicate the six corpora
emails <- load_emails("data/raw")
# @web-end
# @web-start Extract 18 features from subject and body
feats <- extract_features(emails$subject, emails$body, load_lexicon("config/features.yml"))
# @web-end
# @web-start Stratified 70/30 split by class x source
meta <- data.frame(id = emails$id, class = emails$class, source = emails$source,
                   date = emails$date)
processed <- split_train_test(cbind(meta, feats), prop = 0.7, seed = 2026)
# @web-end

dir.create("data/processed", showWarnings = FALSE, recursive = TRUE)
arrow::write_parquet(processed, "data/processed/emails.parquet")
arrow::write_parquet(emails[, c("id", "subject", "body")], "data/processed/text.parquet")

# Counts only (no text) for the report.
dir.create("outputs/results", showWarnings = FALSE, recursive = TRUE)
saveRDS(c(attr(emails, "log"), list(
  rows_kept = nrow(processed), class_source = table(processed$source, processed$class),
  set_class = table(processed$class, processed$set)
)), "outputs/results/m0.rds")

cat("\nRows by class x source:\n")
print(table(processed$source, processed$class))
cat("\nRows by set:\n")
print(table(processed$set))
cat("\nRows by class x set:\n")
print(table(processed$class, processed$set))
