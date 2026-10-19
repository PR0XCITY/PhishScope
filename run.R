# Entry point: Rscript run.R <data | analysis | report | all>

usage <- function() {
  cat("Usage: Rscript run.R <stage>\n")
  cat("  data      build data/processed from data/raw\n")
  cat("  analysis  run analysis/ module scripts -> outputs/results\n")
  cat("  report    render report/report.qmd\n")
  cat("  all       data, analysis, report in order\n")
}

run_script <- function(path) {
  message("== ", path)
  source(path, local = new.env())
}

run_data <- function() {
  run_script("analysis/00_data.R")
}

# Modules 1-7 in order (07 writes web/model.json), then the JS parity fixtures.
run_analysis <- function() {
  scripts <- sort(list.files("analysis", pattern = "^0[1-7]_.*[.]R$", full.names = TRUE))
  for (s in scripts) run_script(s)
  run_script("tests/parity/make_expected.R")
}

quarto_bin <- function() {
  candidates <- c(Sys.getenv("QUARTO_PATH"), Sys.which("quarto"),
                  file.path(Sys.getenv("LOCALAPPDATA"), "Programs", "Quarto", "bin", "quarto.exe"))
  found <- candidates[nzchar(candidates) & file.exists(candidates)]
  if (length(found) == 0) stop("Quarto not found; install it or set QUARTO_PATH.")
  found[[1]]
}

# Renders HTML and PDF (typst) as set in the report's YAML header.
run_report <- function() {
  status <- system2(quarto_bin(), c("render", "report/report.qmd"))
  if (status != 0) stop("quarto render failed with status ", status)
}

main <- function(args) {
  set.seed(2026)
  stage <- if (length(args) > 0) args[[1]] else ""
  switch(stage,
    data = run_data(),
    analysis = run_analysis(),
    report = run_report(),
    all = {
      run_data()
      run_analysis()
      run_report()
    },
    usage()
  )
  invisible(NULL)
}

main(commandArgs(trailingOnly = TRUE))
