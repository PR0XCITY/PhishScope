# Security Policy

## Reporting a vulnerability

Please report security issues privately through GitHub's "Report a vulnerability" button on
the repository's Security tab (private vulnerability reporting). Include steps to reproduce
and the affected file or page. Do not open a public issue for security problems. You can
expect an acknowledgement within 7 days.

## What this repository contains

- **No dataset text.** The raw Kaggle CSVs and all processed data live in `data/`, which is
  gitignored. Only aggregate results, code, hand-written test fixtures and
  `web/public/model.json` (feature likelihoods and the lexicon) are committed.
- **No secrets.** A gitleaks pre-commit hook and a CI job scan every commit.

## Website

The site in `web/` (Vite + React + TypeScript + Tailwind) runs entirely in the browser. Its
only requests are `./model.json` and `./data/*.json` on its own origin (enforced in
`src/lib/data.ts`), and every JSON file is validated before use. The built page carries a
Content Security Policy: `default-src 'self'; script-src 'self'; style-src 'self'
'unsafe-inline'; font-src 'self'; img-src 'self' data:; connect-src 'self'; base-uri 'none';
form-action 'none'; object-src 'none'`. Inline styles are allowed for chart and syntax
colors; scripts are not. Fonts are self-hosted.

Pasted email content and R code are rendered only as React text (Shiki tokens become
spans), so nothing is interpreted as HTML and links in pasted text are never clickable.
`dangerouslySetInnerHTML`, `innerHTML`, `outerHTML`, `insertAdjacentHTML`, `eval` and
`new Function` are banned by ESLint rules, a source-scanning test and a CI grep.
