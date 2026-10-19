# Progress

## Phase 0: scaffold (done)
- Created README.md, run.R (stage dispatcher stubs: data, analysis, report, all), .lintr, .gitignore, .pre-commit-config.yaml (gitleaks v8.21.2), config/features.yml (5 lexicon groups).
- renv on R 4.6.1; lockfile has the 14 requested packages plus deps and R recommended pkgs; renv::status() clean, lintr 0 lints.
- Folders per layout with .gitkeep; data/raw and data/processed kept via .gitkeep, contents ignored.
- Deviation: .gitignore uses data/* with negations instead of data/ so data/raw survives clone; *.zip ignored (archive.zip at root).

## Phase 1: data pipeline (done)
- Files: R/load.R (load_emails, find_source_files, read_source, parse_dates, assign_class, clean_emails), R/features.R (extract_features, load_lexicon, ascii_lower, term_pattern), R/split.R (split_train_test), analysis/00_data.R, tests/testthat/test-features.R + fixtures/emails.csv. `Rscript run.R data` wired.
- Skipped phishing_email.csv (combined: name match and rows = sum of others). Loaded 82486; dropped 5 empty bodies, 596 duplicates; 81885 kept.
- class x source: CEAS_08 17290 legit / 21674 spam; Enron 15474 / 13950; Ling 2401 / 458; SpamAssasin 4090 / 1708; Nazario 1550 phishing; Nigerian_Fraud 3290 phishing.
- Totals: legitimate 39255, phishing 4840, spam 37790. Split 70/30 by class x source: train 57321, test 24564.
- Date parse rate: CEAS 100%, Nazario 99.9%, SpamAssasin 99.6%, Nigerian_Fraud 85.5%, Enron/Ling 0% (no date column).
- Feature defs for JS parity: ASCII-only lowercase (A-Z), word boundary = not [a-z0-9_], phrase spaces match any whitespace run, URL trailing .,;:!?)] trimmed, body_chars counts code points, n_words and body_chars use body only.
- Finding: has_html = 1 in only 4 rows (dataset bodies are HTML-stripped); treat as near-constant.

## Phase 2: Modules 1-2 (done)
- Files: R/rv.R (describe, describe_by_class, stat_mode, pmf_capped, rv_moments, joint_pmf, bayes_posterior, bayes_worked, log_empirical_mgf, log_poisson_mgf, mgf_moments), analysis/01_descriptive.R, analysis/02_random_variables.R, tests/testthat/test-rv.R. Outputs m1.rds, m2.rds, 8 m1_* + 4 m2_* figures. Train: legit 27479, phishing 3388, spam 26454.
- M1: all 4 features right-skewed (skew 2.6 to 132). Median body_chars legit 1080 / phish 2090 / spam 393; caps_ratio median phish 0.064 vs ~0.027 others; log1p axes for body_chars, n_urls, exclam_count.
- M2 n_urls: E[X] legit 1.72 / phish 0.48 / spam 2.29; Var 416 / 7.7 / 45 (far above Poisson var = mean). MGF derivative moments match direct (h = 0.01 / max x).
- Bayes (sample prior 0.0591 / 1%): has_credential 0.389 / 0.093; generic_greeting 0.708 / 0.280; subject_caps 0.649 / 0.229; has_url 0.041 (URLs less common in phishing).
- Correlation: Pearson top pair credential_count x body_chars 0.95 is outlier-driven; Spearman top body_chars x n_words 0.97. Spearman matrix also saved in m2.rds.
- Finding: Enron and Ling are 100% lowercase, so caps_ratio = 0 and subject_caps = 0 there; caps features partly encode source. Control for source in later tests.

## Phase 3: Modules 3-4 (done)
- Files: analysis/03_correlation_regression.R (rank_difference_rho), analysis/04_distributions.R (simulate_batches, poisson_fit, densest_window, fit_candidates). Outputs m3.rds, m4.rds, figures m3_spearman_heatmap, m3_rho_is_phish, m4_binomial_batches, m4_poisson_n_urls, m4_qq_normal_log_body, m4_qq_exponential_nazario.
- M3 (phishing vs legit, n 30867): rank-difference rho body_chars x n_words 0.97155 = cor() (tie gap 3e-7). Top rho with is_phish: credential_count 0.60, has_credential 0.57, money 0.56, generic_greeting 0.54; n_urls -0.10.
- M3 partial: urgency_count vs is_phish 0.238 zero-order Pearson -> 0.371 partial (Spearman 0.402 -> 0.373) given body_chars, n_urls.
- M3 LPM: R^2 0.577, multiple R 0.759; 37.1% fitted values outside [0, 1]. glm has_html OR 4881 is quasi-separation (1 phishing row); ignore.
- M4: binomial sims match theory (TV 0.037 at 1%, 0.023 at 10%). Poisson fails: dispersion index legit 241, phish 16, spam 20. log(body_chars) not normal (Shapiro p < 1e-14; phishing skew -1.0).
- M4 exponential: Nazario densest window 2015-11-02 to 2016-11-01, 276 gaps, rate 0.757/day, CV 1.07, KS p 0.14 (fits). Excluded bogus year-16 date.
- M4 body_chars fits (kchars, MLE): lognormal wins by AIC and BIC in all 3 classes; Weibull second, gamma last.
