# Helpers for exporting the R analysis as JSON for the website (data only, no images or HTML).

max_points <- 500
max_table_rows <- 15
max_console_lines <- 400
max_line_chars <- 300
chart_types <- c("histogram", "bar", "line", "scatter", "qq", "roc", "heatmap", "survival")
module_keys <- c("id", "title", "syllabus_module", "question", "code", "console", "tests",
                 "tables", "charts", "takeaway")

# Code between "# @web-start <label>" and "# @web-end" lines; start_line is the first code line.
extract_web_blocks <- function(path, display = path) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  starts <- grep("^\\s*# @web-start ", lines)
  ends <- grep("^\\s*# @web-end\\s*$", lines)
  if (length(starts) != length(ends) || any(ends <= starts) ||
        any(utils::head(ends, -1) >= utils::tail(starts, -1))) {
    stop("Unbalanced @web markers in ", display)
  }
  lapply(seq_along(starts), function(i) {
    list(label = trimws(sub("^\\s*# @web-start ", "", lines[starts[i]])), file = display,
         start_line = starts[i] + 1,
         code = paste(lines[(starts[i] + 1):(ends[i] - 1)], collapse = "\n"))
  })
}

# Strip ANSI escapes and absolute paths, cap length, and refuse long lines (email text guard).
clean_console <- function(lines, root = getwd()) {
  lines <- gsub("\033\\[[0-9;?]*[A-Za-z]", "", lines)
  roots <- unique(c(root, normalizePath(root, winslash = "/", mustWork = FALSE),
                    normalizePath(root, winslash = "\\", mustWork = FALSE)))
  for (r in roots[nzchar(roots)]) lines <- gsub(r, ".", lines, fixed = TRUE)
  lines <- gsub("[A-Za-z]:[\\\\/][^ \"'<>|]*", "<path>", lines)
  lines <- gsub("(^|[ \"'(])/(home|Users|tmp|var|private|root|opt)/[^ \"'<>|]*", "\\1<path>",
                lines)
  too_long <- which(nchar(lines, type = "chars") > max_line_chars)
  if (length(too_long) > 0) {
    stop("Console line ", too_long[1], " exceeds ", max_line_chars, " characters")
  }
  if (length(lines) > max_console_lines) {
    n_cut <- length(lines) - max_console_lines
    lines <- c(lines[seq_len(max_console_lines)], sprintf("... (%d more lines)", n_cut))
  }
  lines
}

format_p <- function(p) {
  ifelse(is.na(p), NA_character_,
         ifelse(p < 0.001, formatC(p, format = "e", digits = 2), sprintf("%.4f", p)))
}

# Replace em dashes in every string of a nested list.
strip_em_dash <- function(x) {
  if (is.character(x)) return(gsub("—", "-", x, fixed = TRUE))
  if (is.data.frame(x)) {
    chr <- vapply(x, is.character, logical(1))
    x[chr] <- lapply(x[chr], strip_em_dash)
    return(x)
  }
  if (is.list(x)) return(lapply(x, strip_em_dash))
  x
}

# Keep at most n rows: evenly spaced for ordered data, a seeded sample otherwise.
cap_points <- function(df, n = max_points, ordered = TRUE, seed = 2026) {
  if (nrow(df) <= n) return(df)
  if (ordered) return(df[unique(round(seq(1, nrow(df), length.out = n))), , drop = FALSE])
  set.seed(seed)
  df[sort(sample.int(nrow(df), n)), , drop = FALSE]
}

web_series <- function(name, x, y, class = NA_character_, value = NULL, ordered = TRUE) {
  pts <- data.frame(x = x, y = y)
  if (!is.null(value)) pts$value <- value
  pts <- cap_points(pts, ordered = ordered)
  list(name = name, class = class, points = pts)
}

web_chart <- function(id, type, title, x_label, y_label, series, note = "") {
  stopifnot(type %in% chart_types)
  for (s in series) {
    if (nrow(s$points) > max_points) stop("Chart ", id, " has more than ", max_points, " points")
  }
  list(id = id, type = type, title = title, x_label = x_label, y_label = y_label,
       series = series, note = note)
}

web_table <- function(title, df, digits = 4) {
  df <- utils::head(as.data.frame(df), max_table_rows)
  num <- vapply(df, is.numeric, logical(1))
  df[num] <- lapply(df[num], signif, digits)
  rows <- lapply(seq_len(nrow(df)), function(i) unname(lapply(df[i, , drop = FALSE], `[[`, 1)))
  list(title = title, columns = names(df), rows = rows)
}

web_test <- function(name, h0, h1, statistic, critical, p_value, decision, effect_label,
                     effect_value) {
  if (is.numeric(critical)) critical <- paste(signif(critical, 4), collapse = ", ")
  list(name = name, h0 = h0, h1 = h1, statistic = signif(statistic, 5),
       critical = critical, p_value = format_p(p_value), decision = decision,
       effect_label = effect_label, effect_value = signif(effect_value, 4))
}

# Rows of tests_to_df() (Modules 5 and 6) as web tests.
web_tests_from_df <- function(df) {
  lapply(seq_len(nrow(df)), function(i) {
    r <- df[i, ]
    web_test(r$name, r$h0, r$h1, r$statistic, r$critical, r$p_value, r$decision,
             r$effect_name, r$effect)
  })
}

check_module_json <- function(m) {
  missing <- setdiff(module_keys, names(m))
  if (length(missing) > 0) stop("Module JSON missing keys: ", paste(missing, collapse = ", "))
  for (ch in m$charts) {
    for (s in ch$series) if (nrow(s$points) > max_points) stop("Too many points in ", ch$id)
  }
  invisible(TRUE)
}

write_web_json <- function(x, path) {
  jsonlite::write_json(strip_em_dash(x), path, auto_unbox = TRUE, digits = 6, na = "null",
                       pretty = FALSE, dataframe = "rows")
}
