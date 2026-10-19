# Load raw Kaggle CSVs and harmonize to: id, source, subject, body, sender, date_raw, label.

phishing_sources <- c("Nazario", "Nigerian_Fraud")
combined_name_pattern <- "phishing_email|combined"

# Flag files that duplicate the per-source files (by name or by row count).
find_source_files <- function(dir = "data/raw") {
  files <- list.files(dir, pattern = "[.]csv$", full.names = TRUE)
  n_rows <- vapply(files, function(f) nrow(data.table::fread(f, select = "label")), numeric(1))
  keep <- rep(TRUE, length(files))
  for (i in seq_along(files)) {
    by_name <- grepl(combined_name_pattern, basename(files[i]), ignore.case = TRUE)
    by_count <- length(files) > 2 && n_rows[i] == sum(n_rows[-i])
    if (by_name || by_count) {
      keep[i] <- FALSE
      why <- c(if (by_name) "name looks combined", if (by_count) "rows = sum of others")
      message("skip ", basename(files[i]), ": ", paste(why, collapse = "; "))
    }
  }
  files[keep]
}

clean_text <- function(x) {
  x <- stringi::stri_enc_toutf8(x, validate = TRUE)
  x[is.na(x)] <- ""
  x
}

read_source <- function(path) {
  raw <- data.table::fread(path, colClasses = "character", encoding = "UTF-8",
                           showProgress = FALSE)
  message(basename(path), " columns: ", paste(names(raw), collapse = ", "))
  source <- tools::file_path_sans_ext(basename(path))
  col <- function(name) if (name %in% names(raw)) raw[[name]] else rep(NA_character_, nrow(raw))
  data.frame(
    id = sprintf("%s_%06d", source, seq_len(nrow(raw))),
    source = source,
    subject = clean_text(col("subject")),
    body = clean_text(col("body")),
    sender = col("sender"),
    date_raw = col("date"),
    label = as.integer(col("label"))
  )
}

parse_dates <- function(x) {
  x <- stringi::stri_replace_all_regex(x, "\\([^)]*\\)", "")
  x <- stringi::stri_trim_both(stringi::stri_replace_first_regex(x, "^[A-Za-z]{3},", ""))
  orders <- c("dbYHMSz", "dbYHMS", "dbYHMz", "dbYHM", "YmdHMS", "mdYHMS", "Ymd")
  suppressWarnings(lubridate::parse_date_time(x, orders = orders, tz = "UTC", quiet = TRUE))
}

# @web-start Class mapping
assign_class <- function(label, source) {
  ifelse(label == 0, "legitimate",
         ifelse(source %in% phishing_sources, "phishing", "spam"))
}
# @web-end

normalize_text <- function(x) {
  x <- stringi::stri_trans_tolower(x)
  stringi::stri_trim_both(stringi::stri_replace_all_regex(x, "\\s+", " "))
}

# @web-start Drop empty bodies and normalized duplicates
# Drop empty bodies, then exact duplicates on normalized subject + body.
clean_emails <- function(df) {
  empty <- stringi::stri_trim_both(df$body) == ""
  message("dropped empty bodies: ", sum(empty))
  df <- df[!empty, , drop = FALSE]
  key <- paste(normalize_text(df$subject), normalize_text(df$body), sep = "\r")
  dup <- duplicated(key)
  message("dropped duplicates: ", sum(dup))
  out <- df[!dup, , drop = FALSE]
  attr(out, "dropped") <- c(empty_body = sum(empty), duplicate = sum(dup))
  out
}
# @web-end

log_date_rates <- function(df) {
  rate <- tapply(!is.na(df$date), df$source, mean)
  for (s in names(rate)) message(sprintf("date parse rate %s: %.1f%%", s, 100 * rate[[s]]))
  rate
}

# Returns the cleaned emails with attr "log": files used, row counts, date parse rates.
load_emails <- function(dir = "data/raw") {
  files <- find_source_files(dir)
  df <- do.call(rbind, lapply(files, read_source))
  n_loaded <- nrow(df)
  message("rows loaded: ", n_loaded)
  message("dropped missing labels: ", sum(is.na(df$label)))
  n_missing <- sum(is.na(df$label))
  df <- df[!is.na(df$label), , drop = FALSE]
  df$class <- assign_class(df$label, df$source)
  df$date <- parse_dates(df$date_raw)
  rates <- log_date_rates(df)
  out <- clean_emails(df)
  attr(out, "log") <- list(files = basename(files), rows_loaded = n_loaded,
                           missing_label = n_missing, dropped = attr(out, "dropped"),
                           date_parse_rate = rates)
  out
}
