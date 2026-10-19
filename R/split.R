# Stratified train/test split by class x source.

split_train_test <- function(df, prop = 0.7, seed = 2026) {
  set.seed(seed)
  df <- df[order(df$id), , drop = FALSE]
  strata <- paste(df$class, df$source, sep = "|")
  set <- rep("test", nrow(df))
  for (s in sort(unique(strata))) {
    idx <- which(strata == s)
    n_train <- round(prop * length(idx))
    set[idx[sample.int(length(idx), n_train)]] <- "train"
  }
  df$set <- set
  df
}
