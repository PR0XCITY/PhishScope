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
