# Feature extraction over subject + body.
# Every regex is plain ASCII with no lookbehind, so web/features.js can reproduce it exactly.

ws_chars <- "[ \\t\\n\\r\\f\\x0B]"
# URL characters are ASCII only (RFC 3986 set), so no line terminators can enter a URL and
# "." / "$" never need to agree between ICU and JS.
url_pattern <- "https?://[A-Za-z0-9._~:/?#@!$&()*+,;=%\\[\\]-]+"
ip_host_pattern <- "^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$"
subject_caps_pattern <- paste0(
  "(^|[^A-Za-z0-9])[A-Z]{2,}([^A-Za-z0-9]+[A-Z]{2,}){2}(?![A-Za-z0-9])"
)

load_lexicon <- function(path = "config/features.yml") {
  yaml::read_yaml(path)
}

# Lowercase A-Z only, so non-ASCII letters behave the same in R and JS.
ascii_lower <- function(x) {
  chartr("ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz", x)
}

escape_regex <- function(x) {
  stringi::stri_replace_all_regex(x, "[.*+?^${}()|\\[\\]\\\\]", "\\\\$0")
}

# Whole word or phrase: no [a-z0-9_] on either side; spaces match any whitespace run.
term_pattern <- function(term) {
  body <- stringi::stri_replace_all_fixed(escape_regex(term), " ", paste0(ws_chars, "+"))
  paste0("(^|[^a-z0-9_])", body, "(?![a-z0-9_])")
}

count_terms <- function(lower, terms) {
  counts <- vapply(terms, function(t) stringi::stri_count_regex(lower, term_pattern(t)),
                   numeric(length(lower)))
  as.integer(rowSums(matrix(counts, nrow = length(lower))))
}

trim_url <- function(urls) {
  stringi::stri_replace_first_regex(urls, "[.,;:!?)\\]]+$", "")
}

# Host = text before the first / ? #, after the last @, before the first :.
url_host <- function(urls) {
  first_match <- function(x, pattern) {
    out <- stringi::stri_extract_first_regex(x, pattern)
    out[is.na(out)] <- ""
    out
  }
  rest <- stringi::stri_replace_first_regex(urls, "^https?://", "")
  host <- first_match(rest, "^[^/?#]*")
  host <- stringi::stri_replace_first_regex(host, "^(?:[^@]*@)+", "")
  first_match(host, "^[^:]*")
}

url_features <- function(lower, shorteners) {
  urls <- stringi::stri_extract_all_regex(lower, url_pattern, omit_no_match = TRUE)
  n_urls <- lengths(urls)
  flat <- trim_url(unlist(urls))
  idx <- rep(seq_along(lower), n_urls)
  host <- url_host(flat)
  is_short <- host %in% shorteners |
    Reduce(`|`, lapply(shorteners, function(s) endsWith(host, paste0(".", s))), FALSE)
  any_by_email <- function(flag) as.integer(tabulate(idx[flag], nbins = length(lower)) > 0)
  data.frame(
    n_urls = as.integer(n_urls),
    has_url = as.integer(n_urls > 0),
    ip_url = any_by_email(grepl(ip_host_pattern, host)),
    shortener_url = any_by_email(is_short),
    at_in_url = any_by_email(grepl("@", flat, fixed = TRUE))
  )
}

# Uppercase share of letters inside words of 2+ ASCII letters; 0 if there are none.
caps_ratio <- function(text) {
  words <- stringi::stri_extract_all_regex(text, "[A-Za-z]{2,}", omit_no_match = TRUE)
  letters_only <- vapply(words, paste, character(1), collapse = "")
  total <- stringi::stri_length(letters_only)
  upper <- stringi::stri_count_regex(letters_only, "[A-Z]")
  ifelse(total > 0, upper / pmax(total, 1), 0)
}

extract_features <- function(subject, body, lexicon = load_lexicon()) {
  subject[is.na(subject)] <- ""
  body[is.na(body)] <- ""
  text <- paste(subject, body, sep = "\n")
  lower <- ascii_lower(text)
  urgency <- count_terms(lower, lexicon$urgency)
  credential <- count_terms(lower, lexicon$credential)
  money <- count_terms(lower, lexicon$money)
  cbind(
    url_features(lower, lexicon$shorteners),
    data.frame(
      urgency_count = urgency,
      credential_count = credential,
      money_count = money,
      has_urgency = as.integer(urgency > 0),
      has_credential = as.integer(credential > 0),
      has_money = as.integer(money > 0),
      generic_greeting = as.integer(count_terms(lower, lexicon$generic_greeting) > 0),
      exclam_count = as.integer(stringi::stri_count_fixed(text, "!")),
      caps_ratio = caps_ratio(text),
      body_chars = as.integer(stringi::stri_length(body)),
      n_words = as.integer(stringi::stri_count_regex(body, "[^ \\t\\n\\r\\f\\x0B]+")),
      has_html = as.integer(stringi::stri_detect_regex(lower, "<html|<a[ \\t\\n\\r\\f\\x0B]+href")),
      subject_caps = as.integer(stringi::stri_detect_regex(subject, subject_caps_pattern))
    )
  )
}
