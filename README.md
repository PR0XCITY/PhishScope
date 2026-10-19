# PhishScope: Can Statistics Catch a Phish?

Classical probability and statistics, applied to telling phishing emails apart from spam and legitimate mail.

## Data

Kaggle "Phishing Email Dataset" (Al-Subaiey et al. 2024, arXiv 2405.11619). Place the CSVs in `data/raw/`; they are not committed.

## Setup

```r
renv::restore()
```

```bash
Rscript run.R
```

## Secret scanning

Commits are checked by a gitleaks pre-commit hook. Install once:

```bash
pip install pre-commit
pre-commit install
```

gitleaks itself is also available standalone (for example `choco install gitleaks` or `brew install gitleaks`).
