# Security Policy

## Reporting a vulnerability

Please report security issues privately through GitHub's "Report a vulnerability" button on
the repository's Security tab (private vulnerability reporting). Include steps to reproduce
and the affected file or page. Do not open a public issue for security problems. You can
expect an acknowledgement within 7 days.

## What this repository contains

- **No dataset text.** The raw Kaggle CSVs and all processed data live in `data/`, which is
  gitignored. Only aggregate results, code, hand-written test fixtures and `web/model.json`
  (feature likelihoods and the lexicon) are committed.
- **No secrets.** A gitleaks pre-commit hook and a CI job scan every commit.

## Web demo

The checker in `web/` runs entirely in the browser. It loads only `./model.json` from its own
origin, sends nothing anywhere, and is locked down with a Content Security Policy
(`default-src 'self'`, no inline scripts or styles). All output is built with
`createElement` and `textContent`, so pasted email content is never interpreted as HTML and
links in it are never clickable. CI fails if `web/` uses `innerHTML`, `outerHTML`,
`insertAdjacentHTML` or `eval(`.
