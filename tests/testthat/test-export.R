source(file.path(testthat::test_path("..", ".."), "R", "export_web.R"))

test_that("marker extraction returns labelled blocks with line numbers", {
  path <- tempfile(fileext = ".R")
  writeLines(c(
    "x <- 1",
    "# @web-start First block",
    "y <- x + 1",
    "z <- y * 2",
    "# @web-end",
    "print(z)",
    "  # @web-start Second",
    "w <- 3",
    "  # @web-end"
  ), path)
  blocks <- extract_web_blocks(path, display = "fixture.R")
  expect_length(blocks, 2)
  expect_identical(blocks[[1]]$label, "First block")
  expect_identical(blocks[[1]]$file, "fixture.R")
  expect_identical(blocks[[1]]$start_line, 3)
  expect_identical(blocks[[1]]$code, "y <- x + 1\nz <- y * 2")
  expect_identical(blocks[[2]]$code, "w <- 3")
  writeLines(c("# @web-start Open", "a <- 1"), path)
  expect_error(extract_web_blocks(path), "Unbalanced")
})

test_that("console cleaning strips ANSI codes and absolute paths", {
  root <- "D:/Projects/PhisScope"
  out <- clean_console(c("\033[32mINF\033[0m done", "read D:/Projects/PhisScope/data/x.csv",
                         "saved C:\\Users\\me\\out.rds", "file /home/me/a.R ok"), root)
  expect_identical(out[1], "INF done")
  expect_identical(out[2], "read ./data/x.csv")
  expect_identical(out[3], "saved <path>")
  expect_identical(out[4], "file <path> ok")
  long <- clean_console(rep("ok", 450), root)
  expect_length(long, 401)
  expect_match(long[401], "50 more lines")
  expect_error(clean_console(strrep("a", 301), root), "exceeds 300")
})

test_that("p-values switch to scientific notation below 0.001", {
  expect_identical(format_p(c(0.5, 0.0123, 0.00042)), c("0.5000", "0.0123", "4.20e-04"))
})

test_that("module JSON requires every key", {
  m <- list(id = 1, title = "t", syllabus_module = "M1", question = "q", code = list(),
            console = character(), tests = list(), tables = list(), charts = list(),
            takeaway = "x")
  expect_true(check_module_json(m))
  expect_error(check_module_json(m[setdiff(names(m), "takeaway")]), "takeaway")
  m$charts <- list(list(id = "c", series = list(a = list(points = data.frame(x = 1, y = 1)))))
  expect_error(check_module_json(m), "unnamed list")
})

test_that("charts are capped at 500 points per series", {
  s <- web_series("big", seq_len(2000), rnorm(2000), ordered = FALSE)
  expect_identical(nrow(s$points), 500L)
  s2 <- web_series("line", seq_len(1001), seq_len(1001))
  expect_identical(nrow(s2$points), 500L)
  expect_identical(s2$points$x[c(1, 500)], c(1L, 1001L))
  expect_error(web_chart("x", "pie", "t", "x", "y", list(s)))
  bad <- list(name = "raw", class = NA, points = data.frame(x = 1:600, y = 1:600))
  expect_error(web_chart("x", "line", "t", "x", "y", list(bad)), "more than 500")
})

test_that("em dashes are removed from nested text", {
  x <- strip_em_dash(list(a = "one \u2014 two", b = list(c = "x\u2014y", n = 3)))
  expect_identical(x$a, "one - two")
  expect_identical(x$b$c, "x-y")
  expect_identical(x$b$n, 3)
})

test_that("chart points serialize as an array of {x, y} objects", {
  s <- web_series("s", c(1, 2), c("a—b", "c"))
  json <- jsonlite::toJSON(strip_em_dash(list(points = s$points)), auto_unbox = TRUE)
  expect_identical(as.character(json), '{"points":[{"x":1,"y":"a-b"},{"x":2,"y":"c"}]}')
})
