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

## Phase 4: Modules 5-6 (done)
- Files: R/tests_print.R (test_result, print_test, tests_to_df, z_one_prop, z_two_prop, z_one_mean, z_two_mean, cohens_h), analysis/05_large_sample_tests.R, analysis/06_small_sample_anova.R, tests/testthat/test-ztests.R (textbook values + prop.test). Outputs m5.rds, m6.rds, m6_anova_residual_qq.png.
- M5: phishing URL share 0.27, H1 p > 0.5 not supported (z -26.7). Two-prop h: credential 1.49, greeting 1.14, urgency 1.00, has_url -0.23. caps_ratio d 0.43, log body d 0.38, exclam d -0.05. Manual z^2 = prop.test X^2 exactly. Urgency power 1.0; 17 per group for 80%.
- M6 small n = 20, 500 draws: rejection rate one-sample 0.56, Welch 0.29, F 0.28 (low power). GOF legit n_urls vs Poisson: chi2 78410, df 7, w 1.69, rejected.
- Holm p < 0.05 and V >= 0.1: has_credential 0.50, generic_greeting 0.46, has_money 0.45, subject_caps 0.39, has_urgency 0.35, at_in_url 0.18 (at_in_url OR phish vs legit 0.84, CI spans 1: its V comes from spam). has_html min expected 0.12, unreliable.
- ANOVA log body: one-way F 3727, eta^2 0.115; Tukey all pairs differ (phish +0.43 vs legit, spam -0.79). Two-way (CEAS, Enron, Ling, SpamAssasin; legit + spam only) class:source F 1695. Three-way has_html F 0.35 p 0.55, interactions rank-deficient. Levene rejects (SD ratio 1.42).
- DOE (observational): RBD caps_ratio class F 1.93 p 0.26 (4 blocks, Enron/Ling zero caps). LSD: first of 12 Latin squares with all cells n >= 30 (cyclic one had an empty cell); class F 37.8 p 0.026, error df 2.

## Phase 5: PhishScore + Module 7 (done)
- Files: R/phishscore.R (fit_phishscore, phishscore_posterior, model_from_json, wilson_ci, classification_metrics, auc_rank, roc_points), R/reliability.R (parallel_prob, series_prob, user_reliability, mttf_emails, availability), analysis/07_phishscore_reliability.R, tests/parity/make_expected.R -> expected.json, test-phishscore.R. Outputs headline.rds, m7.rds, m7_roc, m7_user_reliability; web/model.json v1.0.0.
- Model: Bernoulli NB on 6 features (has_credential, generic_greeting, has_money, subject_caps, has_urgency, at_in_url), Laplace, train prior 0.1098, threshold 0.5. Posterior on log-odds scale (JS must match).
- Test (13228, 1452 phish): sens 0.746 [0.723, 0.768], spec 0.969 [0.966, 0.972], precision 0.748 [0.725, 0.770], F1 0.747 [0.731, 0.762] (Wilson; F1 as 2TP / (2TP + FP + FN)). AUC 0.920.
- Precision at 1% prevalence: deployed 0.196; re-scored with 1% prior 0.492. Cross-corpus Nigerian Fraud sensitivity 0.887 -> 0.473 (drop 0.413), AUC 0.968 -> 0.914.
- M7 rules: parallel detect 0.968 predicted vs 0.904 empirical, false alarm 0.217 vs 0.196; series ~0 (at_in_url d 0.006). 16 of 30 rule pairs dependent (Holm), positive phi, so independence overstates "any fires".
- User: pi 1%, miss 0.254, h 0.00254, R(100) 0.775, R(1000) 0.079, MTTF 394 emails = 7.9 days at 50/day. Availability 90 / (90 + 2) = 0.978 (assumption-based).
- Note: at_in_url passes the M6 rule only via spam (OR 0.84 phish vs legit); kept per rule, weight near 0. M6 feature selection used all train classes.

## Phase 6: static web demo (done)
- Files: web/index.html, style.css, features.js (extractFeatures, findHighlights, urlHost), score.js (posterior, likelihoodRatios, validateModel), app.js (buildResults, clampText, init), examples.js; tests/js/parity.test.mjs, ui.test.mjs; .github/workflows/pages.yml (node tests, then deploy web/).
- Pattern change (R and JS): URL class now ASCII-only RFC 3986 chars `https?://[A-Za-z0-9._~:/?#@!$&()*+,;=%\[\]-]+`; host via `^[^/?#]*`, `^(?:[^@]*@)+`, `^[^:]*` (no `.`/`$`, which differ for U+0085/U+2028 in ICU vs JS). R tests + make_expected.R rerun.
- Not rerun: data/processed, m1-m7 and web/model.json still use the old URL pattern; differs only for URLs with non-ASCII chars. Rerun run.R data + 07 to refresh.
- Parity: expected.json now has 4 fixture + 8 hand-written edge cases (Unicode, emoji, U+2028, ports, @, mixed whitespace, HTML); all features exact, scores within 1e-6. Node 25 needs `node --test "tests/js/*.test.mjs"` (dir arg fails). 29 JS tests pass.
- UI test: fake DOM throws on innerHTML/outerHTML/insertAdjacentHTML; script/img/a input renders as text only; source scan for sinks, inline script/style/handlers, external URLs, exact CSP.
- Browser check (python http.server): suspicious example 59.7% (dataset prior) vs 10.8% (1% prior); normal 0.4% vs <0.1%. No console/CSP errors, no overflow at 360px, dark mode OK.

## Phase 7: report, README, CI (done)
- Files: report/report.qmd (HTML + typst PDF, reads outputs/results/*.rds only, copies figures to report/_fig), .github/workflows/ci.yml (R lint + testthat via renv, node tests + sink grep, gitleaks), .github/dependabot.yml, SECURITY.md, README.md. run.R: report (Quarto via QUARTO_PATH, PATH or %LOCALAPPDATA%/Programs/Quarto) and all.
- run.R analysis runs 01-07 then tests/parity/make_expected.R. 00_data.R now saves m0.rds (load counts); 05 adds m5_effect_sizes.png. 05/06 load helpers via tp <- new.env() + sys.source (lintr object_usage).
- run.R all completed: same counts; model refit with new URL pattern changed only at_in_url legit likelihood (0.00775 -> 0.00717); AUC 0.9199 -> 0.9198, other headline metrics unchanged.
- Added rmarkdown + knitr to renv. Quarto 1.10.19 installed portable (winget had no user-scope installer).
- Checks: R tests, 29 node tests, lintr clean, renv consistent; gitleaks detect clean; 0 of 58616 dataset body snippets found in tracked files; web demo scores both examples.
- Open: README live demo URL and screenshot are placeholders (no git remote yet).

## Phase 6A: R exports JSON for the website (done)
- Files: R/export_web.R (extract_web_blocks, clean_console, format_p, strip_em_dash, cap_points, web_series, web_chart, web_table, web_test, check_module_json, write_web_json), analysis/08_export_web.R (build_m0..build_m8, build_pipeline, build_meta), tests/testthat/test-export.R. `Rscript run.R web` wired.
- Markers: 3 to 6 `# @web-start/end` blocks in analysis/00-07 plus R/load.R, features.R, rv.R, tests_print.R, phishscore.R, reliability.R. Logic unchanged; 04 now also saves fit params (param1/2) and exponential gaps.
- Output web/public/data: m0-m8.json, pipeline.json, meta.json (R 4.6.1, package versions, headline, module summaries). 0.24 MB; consoles capped at 400 lines, guard fails on lines > 300 chars; points <= 500 per series.
- Frontend rule change (user): web/ is Vite + React + TS + Tailwind; model.json moved to web/public/model.json (07 and make_expected.R updated).
- Fix found in export: strip_em_dash turned data frames into column lists; now keeps rows, with a test.
