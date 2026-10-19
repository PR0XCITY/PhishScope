# Phase 6A: export each module as JSON for the website (web/public/data). Data only.
# Reruns analysis/00-07 to capture their console output, then reads outputs/results/*.rds.

ew <- new.env()
sys.source("R/export_web.R", envir = ew)

set.seed(2026)
out_dir <- "web/public/data"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
if (!file.exists("web/public/model.json") && file.exists("web/model.json")) {
  file.copy("web/model.json", "web/public/model.json")
}
classes <- c("legitimate", "phishing", "spam")

# ---- Console output of each analysis script ----
rscript_name <- if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript"
rscript <- file.path(R.home("bin"), rscript_name)
run_console <- function(script) {
  message("running ", script)
  out <- suppressWarnings(system2(rscript, script, stdout = TRUE, stderr = TRUE))
  status <- attr(out, "status")
  if (!is.null(status) && status != 0) stop(script, " failed with status ", status)
  ew$clean_console(out)
}
scripts <- sort(list.files("analysis", pattern = "^0[0-7]_.*[.]R$", full.names = TRUE))
consoles <- stats::setNames(lapply(scripts, run_console), basename(scripts))

res <- lapply(stats::setNames(nm = c(paste0("m", 0:7), "headline")), function(n) {
  readRDS(file.path("outputs/results", paste0(n, ".rds")))
})
emails <- as.data.frame(arrow::read_parquet("data/processed/emails.parquet"))
train <- emails[emails$set == "train", ]

# Code blocks from (file, labels) pairs; NULL labels keeps every block in the file.
code_blocks <- function(spec) {
  unlist(lapply(spec, function(s) {
    blocks <- ew$extract_web_blocks(s$file)
    if (!is.null(s$labels)) blocks <- Filter(function(b) b$label %in% s$labels, blocks)
    blocks
  }), recursive = FALSE)
}

# Share of class rows per histogram bin, one series per class.
class_histogram <- function(df, value, breaks, transform = identity) {
  lapply(classes, function(cl) {
    x <- transform(df[[value]][df$class == cl])
    counts <- graphics::hist(pmin(pmax(x, min(breaks)), max(breaks)), breaks = breaks,
                             plot = FALSE)$counts
    ew$web_series(cl, (utils::head(breaks, -1) + breaks[-1]) / 2, counts / length(x), cl)
  })
}

# Sample quantiles at 200 probabilities against normal quantiles in data units.
qq_normal_series <- function(x, name, class = NA_character_) {
  p <- stats::ppoints(200)
  ew$web_series(name, mean(x) + stats::sd(x) * stats::qnorm(p),
                unname(stats::quantile(x, p, type = 7)), class)
}

heatmap_series <- function(mat, name) {
  long <- as.data.frame(as.table(mat))
  ew$web_series(name, as.character(long$Var1), as.character(long$Var2), value = long$Freq)
}

module <- function(id, title, syllabus, question, code, console, tests, tables, charts,
                   takeaway) {
  m <- list(id = id, title = title, syllabus_module = syllabus, question = question,
            code = code, console = console, tests = tests, tables = tables, charts = charts,
            takeaway = takeaway)
  ew$check_module_json(m)
  m
}

# ---- Module builders ----
binary_features <- c("has_url", "ip_url", "shortener_url", "at_in_url", "has_urgency",
                     "has_credential", "has_money", "generic_greeting", "has_html",
                     "subject_caps")
num <- function(x, d = 3) formatC(x, digits = d, format = "f", big.mark = ",")

build_m0 <- function() {
  m0 <- res$m0
  cs <- as.data.frame.matrix(m0$class_source)
  cs_df <- data.frame(source = rownames(cs), cs, check.names = FALSE)
  rates <- data.frame(source = names(m0$date_parse_rate),
                      parse_rate = as.numeric(m0$date_parse_rate))
  prevalence <- lapply(classes, function(cl) {
    ew$web_series(cl, binary_features, vapply(binary_features, function(f) {
      mean(train[[f]][train$class == cl])
    }, numeric(1)), cl)
  })
  by_source <- lapply(classes, function(cl) ew$web_series(cl, rownames(cs), cs[[cl]], cl))
  module(
    0, "Data and Features", "Data preparation",
    "What is in the dataset, and how does each email become a row of numbers?",
    code_blocks(list(list(file = "analysis/00_data.R"), list(file = "R/load.R"),
                     list(file = "R/features.R"))),
    consoles[["00_data.R"]], list(),
    list(ew$web_table("Emails by source and class after cleaning", cs_df),
         ew$web_table("Date parse rate by source", rates)),
    list(ew$web_chart("class_by_source", "bar", "Emails by source and class", "source",
                      "emails", by_source),
         ew$web_chart("binary_prevalence", "bar", "How often each binary feature fires (train)",
                      "feature", "share of class", prevalence)),
    sprintf(paste("%s emails remain after removing %s empty bodies and %s duplicates.",
                  "Phishing comes from only two corpora, so class and source overlap."),
            num(m0$rows_kept, 0), num(m0$dropped[["empty_body"]], 0),
            num(m0$dropped[["duplicate"]], 0))
  )
}

build_m1 <- function() {
  m1 <- res$m1
  feats <- c("body_chars", "n_urls", "caps_ratio", "exclam_count")
  charts <- lapply(feats, function(f) {
    log_x <- isTRUE(m1$log_scale[[f]])
    tr <- if (log_x) function(x) log10(1 + x) else identity
    hi <- if (log_x) ceiling(max(tr(train[[f]])) * 10) / 10 else max(1, max(train[[f]]))
    ew$web_chart(paste0("hist_", f), "histogram", paste("Distribution of", f, "by class"),
                 if (log_x) paste0("log10(1 + ", f, ")") else f, "share of class",
                 class_histogram(train, f, seq(0, hi, length.out = 41), tr),
                 if (log_x) "Log scale because the feature is strongly right-skewed." else "")
  })
  stats <- m1$stats[, c("feature", "class", "mean", "median", "mode", "iqr", "sd", "cv",
                        "skewness", "kurtosis")]
  module(
    1, "Descriptive Statistics", "Module 1",
    "How do length, links, capitals and exclamation marks differ by class?",
    code_blocks(list(list(file = "analysis/01_descriptive.R"),
                     list(file = "R/rv.R", labels = "Descriptive summary of one variable"))),
    consoles[["01_descriptive.R"]], list(),
    list(ew$web_table("Summary statistics by class (training set)", stats)),
    charts,
    paste("All four features are strongly right-skewed, so medians describe them better",
          "than means. Phishing emails are longer and use more capitals; spam is shortest.")
  )
}

m2_rv_labels <- c("PMF and CDF of a count variable", "Bayes rule",
                  "Moment generating function and its derivatives")

build_m2 <- function() {
  m2 <- res$m2
  pmf <- m2$pmf
  pmf_series <- lapply(classes, function(cl) {
    d <- pmf[pmf$class == cl, ]
    ew$web_series(cl, d$value, d$pmf, cl)
  })
  cdf_series <- lapply(classes, function(cl) {
    d <- pmf[pmf$class == cl, ]
    ew$web_series(cl, d$k, d$cdf, cl)
  })
  mgf <- m2$mgf_curves
  mgf_series <- lapply(split(mgf, paste(mgf$class, mgf$model)), function(d) {
    ew$web_series(paste(d$class[1], d$model[1]), d$t, d$log_m, d$class[1])
  })
  joint <- m2$joint$phishing
  joint_df <- data.frame(has_url = rownames(joint), as.data.frame.matrix(joint),
                         check.names = FALSE)
  bayes <- m2$bayes[, c("feature", "p_f_phish", "p_f_not_phish", "post_sample", "post_1pct")]
  module(
    2, "Random Variables and Bayes", "Module 2",
    "If a red flag fires, how likely is the email to be phishing?",
    code_blocks(list(list(file = "analysis/02_random_variables.R"),
                     list(file = "R/rv.R", labels = m2_rv_labels))),
    consoles[["02_random_variables.R"]], list(),
    list(ew$web_table("Bayes: P(phishing | feature) at sample prior and at 1%", bayes),
         ew$web_table("Joint PMF of has_url (rows) x has_urgency (columns), phishing", joint_df),
         ew$web_table("Moments of n_urls: MGF derivatives vs direct", m2$mgf_moments)),
    list(ew$web_chart("pmf_n_urls", "bar", "PMF of n_urls (10+ pooled)", "n_urls", "P(X = x)",
                      pmf_series),
         ew$web_chart("cdf_n_urls", "line", "CDF of n_urls", "n_urls", "P(X <= x)", cdf_series),
         ew$web_chart("mgf_n_urls", "line", "log MGF of n_urls: empirical vs Poisson", "t",
                      "log M(t)", mgf_series, "The empirical curve rises far faster: heavy tail."),
         ew$web_chart("cor_heatmap", "heatmap", "Pearson correlation of numeric features", "",
                      "", list(heatmap_series(m2$cor, "Pearson r")))),
    paste("Worked example at a 1% prior:", m2$worked[["one_pct"]],
          "The same evidence is far weaker when phishing is rare.")
  )
}

build_m3 <- function() {
  m3 <- res$m3
  partial_tests <- lapply(rownames(m3$partial), function(method) {
    p <- m3$partial[method, ]
    ew$web_test(paste0("Partial correlation (", method, "): urgency_count vs is_phish"),
                "partial rho = 0 given body_chars and n_urls", "partial rho != 0",
                p$statistic, "1.96 (normal approximation)", p$p.value,
                if (p$p.value < 0.05) "reject H0" else "fail to reject H0", "partial r",
                p$estimate)
  })
  rho <- m3$rho_is_phish[!is.na(m3$rho_is_phish)]
  pl <- train[train$class != "spam", ]
  scatter <- lapply(c("legitimate", "phishing"), function(cl) {
    d <- pl[pl$class == cl, ]
    ew$web_series(cl, log10(d$body_chars), log10(1 + d$n_words), cl, ordered = FALSE)
  })
  rank_tbl <- data.frame(pair = m3$rank_formula[["pair"]],
                         rank_difference = as.numeric(m3$rank_formula[["formula"]]),
                         cor_spearman = as.numeric(m3$rank_formula[["cor"]]))
  module(
    3, "Correlation and Regression", "Module 3",
    "Which features move with phishing, and can a straight line predict it?",
    code_blocks(list(list(file = "analysis/03_correlation_regression.R"))),
    consoles[["03_correlation_regression.R"]], partial_tests,
    list(ew$web_table("Linear probability model with logistic comparison", m3$lpm_coef),
         ew$web_table("Spearman with is_phish (phishing vs legitimate)",
                      data.frame(feature = names(rho), rho = unname(rho))),
         ew$web_table("Rank-difference formula vs cor()", rank_tbl)),
    list(ew$web_chart("rho_is_phish", "bar", "Spearman correlation with phishing", "feature",
                      "rho", list(ew$web_series("rho", names(rho), unname(rho)))),
         ew$web_chart("spearman_heatmap", "heatmap", "Spearman correlation of numeric features",
                      "", "", list(heatmap_series(m3$spearman, "Spearman rho"))),
         ew$web_chart("length_vs_words", "scatter", "Body length vs word count (500 per class)",
                      "log10(body_chars)", "log10(1 + n_words)", scatter)),
    sprintf(paste("The linear probability model explains R squared = %.3f, but %.1f%% of its",
                  "fitted probabilities fall outside [0, 1]."),
            m3$r_squared, 100 * m3$out_of_range)
  )
}

fit_histogram_chart <- function(cl) {
  x <- train$body_chars[train$class == cl] / 1000
  upper <- stats::quantile(x, 0.99, names = FALSE)
  breaks <- seq(0, upper, length.out = 51)
  inside <- x[x <= upper]
  counts <- graphics::hist(inside, breaks = breaks, plot = FALSE)$counts
  mids <- (utils::head(breaks, -1) + breaks[-1]) / 2
  grid <- seq(upper / 200, upper, length.out = 200)
  fits <- res$m4$fits[res$m4$fits$class == cl, ]
  pdf <- function(d) {
    f <- fits[fits$distribution == d, ]
    switch(d, gamma = stats::dgamma(grid, shape = f$param1, rate = f$param2),
           weibull = stats::dweibull(grid, shape = f$param1, scale = f$param2),
           lnorm = stats::dlnorm(grid, meanlog = f$param1, sdlog = f$param2))
  }
  series <- c(list(ew$web_series("observed", mids, counts / (length(x) * diff(breaks)[1]), cl)),
              lapply(fits$distribution, function(d) ew$web_series(d, grid, pdf(d), cl)))
  ew$web_chart(paste0("fit_body_", cl), "histogram",
               paste("Body length with fitted curves:", cl), "body_chars (thousands)",
               "density", series, "Histogram up to the 99th percentile; curves use MLE fits.")
}

build_m4 <- function() {
  m4 <- res$m4
  nrm <- m4$normal
  tests <- lapply(seq_len(nrow(nrm)), function(i) {
    ew$web_test(paste("Shapiro-Wilk, log(body_chars),", nrm$class[i]), "log(body_chars) is normal",
                "not normal", nrm$W[i], "n/a (tabulated)", nrm$p_value[i],
                if (nrm$p_value[i] < 0.05) "reject H0" else "fail to reject H0", "skewness",
                nrm$skewness[i])
  })
  ex <- m4$exponential
  tests <- c(tests, list(ew$web_test(
    "Kolmogorov-Smirnov, Nazario inter-arrival days vs exponential", "gaps ~ Exponential",
    "not exponential", unname(ex$ks$statistic), 1.358 / sqrt(ex$n_gaps), ex$ks$p.value,
    if (ex$ks$p.value < 0.05) "reject H0" else "fail to reject H0", "CV", ex$cv
  )))
  binom <- m4$binomial
  binom_charts <- lapply(sort(unique(binom$p)), function(p) {
    b <- binom[binom$p == p, ]
    ew$web_chart(paste0("binomial_", p * 100), "bar",
                 sprintf("Phishing per batch of 50 at %g%% prevalence", 100 * p), "k", "P(K = k)",
                 list(ew$web_series("theoretical", b$k, b$theoretical),
                      ew$web_series("simulated (2000 batches)", b$k, b$simulated)))
  })
  pois_series <- unlist(lapply(classes, function(cl) {
    t <- m4$poisson_tables[[cl]]
    list(ew$web_series(paste(cl, "observed"), t$k, t$observed, cl),
         ew$web_series(paste(cl, "Poisson"), t$k, t$expected, cl))
  }), recursive = FALSE)
  qq <- lapply(classes, function(cl) {
    qq_normal_series(log(train$body_chars[train$class == cl]), cl, cl)
  })
  p <- stats::ppoints(length(ex$gaps))
  qq_exp <- ew$web_series("Nazario gaps", stats::qexp(p, ex$rate_per_day), sort(ex$gaps))
  module(
    4, "Probability Distributions", "Module 4",
    "Which textbook distributions describe the data, and which fail?",
    code_blocks(list(list(file = "analysis/04_distributions.R"))),
    consoles[["04_distributions.R"]], tests,
    list(ew$web_table("Gamma, Weibull and lognormal fits (body_chars in thousands)", m4$fits),
         ew$web_table("Poisson fit of n_urls", m4$poisson),
         ew$web_table("Binomial batches: theory vs simulation", m4$binomial_summary)),
    c(binom_charts,
      list(ew$web_chart("poisson_n_urls", "bar", "n_urls: observed vs Poisson", "n_urls (10 = 10+)",
                        "probability", pois_series),
           ew$web_chart("qq_log_body", "qq", "Normal QQ, log(body_chars)", "normal quantile",
                        "sample quantile", qq, "Points on y = x would mean normal."),
           ew$web_chart("qq_exponential", "qq", "Exponential QQ, Nazario inter-arrival days",
                        "exponential quantile (days)", "observed gap (days)", list(qq_exp))),
      lapply(classes, fit_histogram_chart)),
    paste("The lognormal fits body length best in every class; link counts are far too",
          "dispersed for a Poisson; Nazario arrival gaps look exponential.")
  )
}

build_m5 <- function() {
  m5 <- res$m5
  eff <- m5$tests[m5$tests$name != "Phishing share with 1+ URL", ]
  checks <- do.call(rbind, lapply(names(m5$checks), function(k) {
    data.frame(test = k, manual = m5$checks[[k]][["manual"]],
               builtin = m5$checks[[k]][["builtin"]])
  }))
  power <- data.frame(quantity = names(m5$power), value = unname(m5$power))
  module(
    5, "Large-Sample Tests", "Module 5",
    "Are the differences between phishing and legitimate mail real, and how large are they?",
    code_blocks(list(list(file = "analysis/05_large_sample_tests.R"),
                     list(file = "R/tests_print.R"))),
    consoles[["05_large_sample_tests.R"]], ew$web_tests_from_df(m5$tests),
    list(ew$web_table("Manual z (or z squared) vs prop.test / t.test", checks),
         ew$web_table("Power for the has_urgency difference", power)),
    list(ew$web_chart("effect_sizes", "bar", "Effect sizes, phishing vs legitimate", "test",
                      "Cohen's h or d", list(ew$web_series("effect", eff$name, eff$effect)),
                      "0.2 small, 0.5 medium, 0.8 large.")),
    paste("With thousands of emails nearly every test rejects; effect sizes show which",
          "differences matter.", m5$error_note)
  )
}

build_m6 <- function() {
  m6 <- res$m6
  tests <- unlist(lapply(list(m6$small_first_draw, m6$gof, m6$anova, m6$levene, m6$rbd, m6$lsd),
                         ew$web_tests_from_df), recursive = FALSE)
  ind <- m6$independence[, c("feature", "chi2", "cramers_v", "odds_ratio", "or_low", "or_high",
                             "p_holm", "passes")]
  ind$p_holm <- ew$format_p(ind$p_holm)
  tukey <- data.frame(comparison = rownames(m6$tukey), m6$tukey, check.names = FALSE)
  rej <- m6$small_rejection_rate
  resid <- log(train$body_chars) - stats::ave(log(train$body_chars), train$class)
  module(
    6, "Small Samples, Chi-square and ANOVA", "Module 6",
    "What survives small samples, which features depend on class, and how do groups compare?",
    code_blocks(list(list(file = "analysis/06_small_sample_anova.R"))),
    consoles[["06_small_sample_anova.R"]], tests,
    list(ew$web_table("Binary feature x class, ranked by Cramer's V", ind),
         ew$web_table("Tukey HSD, log(body_chars)", tukey),
         ew$web_table("Latin square cells (mean exclam_count)", m6$lsd_data)),
    list(ew$web_chart("cramers_v", "bar", "Cramer's V by feature", "feature", "V",
                      list(ew$web_series("V", m6$independence$feature, m6$independence$cramers_v)),
                      "Features with Holm p < 0.05 and V >= 0.1 feed PhishScore."),
         ew$web_chart("rejection_rate", "bar", "Rejection rate over 500 draws of n = 20", "test",
                      "share rejecting H0", list(ew$web_series("rate", names(rej), unname(rej)))),
         ew$web_chart("anova_residuals", "qq", "One-way ANOVA residuals, normal QQ",
                      "normal quantile", "residual quantile",
                      list(qq_normal_series(resid, "residuals")))),
    paste(m6$effect_note, m6$doe_note)
  )
}

build_m7 <- function() {
  m7 <- res$m7
  dep <- m7$dependence[order(-m7$dependence$chi2), ][1:5, ]
  tests <- lapply(seq_len(nrow(dep)), function(i) {
    d <- dep[i, ]
    ew$web_test(sprintf("%s x %s within %s", d$rule_a, d$rule_b, d$class),
                "rules fire independently", "rules are dependent", d$chi2,
                stats::qchisq(0.95, 1), d$p_holm,
                if (d$p_holm < 0.05) "reject H0" else "fail to reject H0", "phi", d$phi)
  })
  sr <- m7$system_rates
  curve <- m7$user_curve
  ul <- m7$user_level
  module(
    7, "Reliability", "Module 7",
    "If each red-flag rule is a component, how reliable is the system for one user?",
    code_blocks(list(list(file = "analysis/07_phishscore_reliability.R",
                          labels = c("Rules as series and parallel components",
                                     "Pairwise rule dependence (chi-square)",
                                     "User-level reliability and MTTF")),
                     list(file = "R/reliability.R"))),
    consoles[["07_phishscore_reliability.R"]], tests,
    list(ew$web_table("Rule detection (d) and false alarm (f) rates, test set", m7$rule_rates),
         ew$web_table("Series and parallel: independence vs observed", sr),
         ew$web_table("User-level reliability", data.frame(quantity = names(ul),
                                                           value = unname(ul))),
         ew$web_table("Availability (assumption-based)",
                      data.frame(quantity = names(m7$availability),
                                 value = unname(m7$availability)))),
    list(ew$web_chart("rule_rates", "bar", "Rule firing rates by class", "rule", "rate",
                      list(ew$web_series("d = P(fires | phishing)", m7$rule_rates$rule,
                                         m7$rule_rates$d, "phishing"),
                           ew$web_series("f = P(fires | legitimate)", m7$rule_rates$rule,
                                         m7$rule_rates$f, "legitimate"))),
         ew$web_chart("parallel_series", "bar", "Detection: independence prediction vs observed",
                      "system", "P(detect)",
                      list(ew$web_series("predicted", sr$system, sr$detect_predicted),
                           ew$web_series("observed", sr$system, sr$detect_empirical))),
         ew$web_chart("user_reliability", "survival", "P(no missed phish) after n emails",
                      "emails received", "R(n)",
                      list(ew$web_series("R(n)", curve$n, curve$reliability)),
                      m7$availability_note)),
    sprintf(paste("At 1%% phishing, a missed phish arrives about every %s emails (%.1f days at",
                  "50 emails a day). Rules fire together, so independence overstates detection."),
            num(ul[["mttf_emails"]], 0), ul[["mttf_days"]])
  )
}

build_m8 <- function() {
  hl <- res$headline
  mt <- data.frame(metric = rownames(hl$metrics), hl$metrics, check.names = FALSE)
  conf <- data.frame(predicted = rownames(hl$confusion),
                     as.data.frame.matrix(hl$confusion), check.names = FALSE)
  prec <- data.frame(setting = c("deployed model at 1% prevalence", "re-scored with 1% prior"),
                     precision = c(hl$precision_1pct_deployed, hl$precision_1pct_prior))
  roc <- res$m7$roc
  roc <- roc[is.finite(roc$threshold) | roc$tpr == 0, ]
  module(
    8, "PhishScore Validation", "Model validation",
    "How well does a transparent naive Bayes score do on unseen emails?",
    code_blocks(list(list(file = "analysis/07_phishscore_reliability.R",
                          labels = c("Naive Bayes fit and test-set evaluation",
                                     "ROC curve and AUC",
                                     "Cross-corpus refit without Nigerian Fraud")),
                     list(file = "R/phishscore.R"))),
    consoles[["07_phishscore_reliability.R"]], list(),
    list(ew$web_table("Test set at threshold 0.5, Wilson 95% intervals", mt),
         ew$web_table("Confusion matrix (rows predicted, columns actual)", conf),
         ew$web_table("Cross-corpus: Nigerian Fraud vs test legitimate", hl$cross_corpus),
         ew$web_table("Precision when phishing is 1% of mail", prec)),
    list(ew$web_chart("roc", "roc", sprintf("ROC curve (AUC %.3f)", hl$auc),
                      "false positive rate", "true positive rate",
                      list(ew$web_series("PhishScore", roc$fpr, roc$tpr),
                           ew$web_series("chance", c(0, 1), c(0, 1)))),
         ew$web_chart("metrics", "bar", "Test-set metrics", "metric", "estimate",
                      list(ew$web_series("estimate", mt$metric, mt$estimate)))),
    sprintf(paste("Sensitivity %.3f and specificity %.3f, AUC %.3f. At 1%% prevalence",
                  "precision is only %.3f, and sensitivity drops by %.3f on an unseen corpus."),
            hl$metrics["sensitivity", "estimate"], hl$metrics["specificity", "estimate"],
            hl$auc, hl$precision_1pct_deployed, hl$sensitivity_drop)
  )
}

build_pipeline <- function() {
  m0 <- res$m0
  after_label <- m0$rows_loaded - m0$missing_label
  after_empty <- after_label - m0$dropped[["empty_body"]]
  cs <- as.data.frame(m0$class_source, stringsAsFactors = FALSE)
  sc <- as.data.frame(m0$set_class, stringsAsFactors = FALSE)
  list(
    files = m0$files,
    steps = list(
      list(step = "Raw rows from per-source CSVs", rows = m0$rows_loaded),
      list(step = "After dropping missing labels", rows = after_label),
      list(step = "After dropping empty bodies", rows = after_empty),
      list(step = "After deduplication", rows = m0$rows_kept)
    ),
    by_class = as.list(colSums(m0$class_source)),
    by_source_class = lapply(seq_len(nrow(cs)), function(i) {
      list(source = cs$Var1[i], class = cs$Var2[i], rows = cs$Freq[i])
    }),
    split = list(train = sum(sc$Freq[sc$Var2 == "train"]),
                 test = sum(sc$Freq[sc$Var2 == "test"]),
                 by_class = lapply(seq_len(nrow(sc)), function(i) {
                   list(class = sc$Var1[i], set = sc$Var2[i], rows = sc$Freq[i])
                 }))
  )
}

# Meta, plus a short summary of every module for the home page.
build_meta <- function(modules) {
  pkgs <- c("data.table", "arrow", "stringi", "lubridate", "yaml", "jsonlite", "ggplot2",
            "moments", "MASS", "ppcor", "fitdistrplus", "car", "testthat")
  invisible(lapply(pkgs, requireNamespace, quietly = TRUE))
  si <- utils::sessionInfo()
  loaded <- c(si$otherPkgs, si$loadedOnly)
  hl <- res$headline
  list(
    r_version = R.version.string,
    r_version_short = paste(R.version$major, R.version$minor, sep = "."),
    packages = lapply(stats::setNames(nm = pkgs), function(p) loaded[[p]]$Version),
    citation = paste("Al-Subaiey, A. et al. (2024). Novel interpretable and robust web-based",
                     "AI platform for phishing email detection. arXiv:2405.11619."),
    dataset = "Kaggle Phishing Email Dataset",
    snapshot_date = format(Sys.Date()),
    modules = lapply(modules, function(m) {
      m[c("id", "title", "syllabus_module", "question", "takeaway")]
    }),
    headline = list(
      features = hl$features, prior = hl$prior, threshold = hl$threshold, auc = hl$auc,
      sensitivity = as.list(hl$metrics["sensitivity", ]),
      specificity = as.list(hl$metrics["specificity", ]),
      precision = as.list(hl$metrics["precision", ]),
      f1 = as.list(hl$metrics["f1", ]),
      precision_1pct_deployed = hl$precision_1pct_deployed,
      precision_1pct_prior = hl$precision_1pct_prior,
      sensitivity_drop_cross_corpus = hl$sensitivity_drop
    )
  )
}

modules <- list(build_m0(), build_m1(), build_m2(), build_m3(), build_m4(), build_m5(),
                build_m6(), build_m7(), build_m8())
for (m in modules) ew$write_web_json(m, file.path(out_dir, sprintf("m%d.json", m$id)))
ew$write_web_json(build_pipeline(), file.path(out_dir, "pipeline.json"))
ew$write_web_json(build_meta(modules), file.path(out_dir, "meta.json"))

files <- list.files(out_dir, full.names = TRUE)
sizes <- file.size(files)
cat("Wrote", length(files), "files to", out_dir, "\n")
cat(sprintf("  %-14s %7.1f KB\n", basename(files), sizes / 1024), sep = "")
cat(sprintf("Total %.2f MB\n", sum(sizes) / 1024^2))
if (sum(sizes) > 5 * 1024^2) stop("web/public/data exceeds 5 MB")
