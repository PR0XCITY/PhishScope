# Entry point: Rscript run.R <data | analysis | report | all>

usage <- function() {
  cat("Usage: Rscript run.R <stage>\n")
  cat("  data      build data/processed from data/raw\n")
  cat("  analysis  run analysis/ module scripts -> outputs/results\n")
  cat("  report    render report/report.qmd\n")
  cat("  all       data, analysis, report in order\n")
}

run_data <- function() {
  message("data: not implemented yet")
}

run_analysis <- function() {
  message("analysis: not implemented yet")
}

run_report <- function() {
  message("report: not implemented yet")
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
