// Port of R/features.R. Every pattern here is the same ASCII regex string used in R
// (no lookbehind, no Unicode classes, no "." or "$" outside ASCII-only input).

const WS = "[ \\t\\n\\r\\f\\x0B]";
const URL_PATTERN = "https?://[A-Za-z0-9._~:/?#@!$&()*+,;=%\\[\\]-]+";
const IP_HOST = /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/;
const SUBJECT_CAPS = /(^|[^A-Za-z0-9])[A-Z]{2,}([^A-Za-z0-9]+[A-Z]{2,}){2}(?![A-Za-z0-9])/;
const HTML_TAG = /<html|<a[ \t\n\r\f\x0B]+href/;

export const HIGHLIGHT_GROUPS = ["urgency", "credential", "money", "generic_greeting"];

// Lowercase A-Z only, matching chartr() in R.
export function asciiLower(s) {
  return s.replace(/[A-Z]/g, (c) => String.fromCharCode(c.charCodeAt(0) + 32));
}

function escapeRegex(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

// Whole word or phrase: no [a-z0-9_] on either side; spaces match any whitespace run.
export function termPattern(term) {
  return "(^|[^a-z0-9_])" + escapeRegex(term).split(" ").join(WS + "+") + "(?![a-z0-9_])";
}

function eachMatch(str, pattern, fn) {
  const re = new RegExp(pattern, "g");
  let m = re.exec(str);
  while (m !== null) {
    fn(m);
    if (m[0] === "") re.lastIndex += 1;
    m = re.exec(str);
  }
}

function countMatches(str, pattern) {
  let n = 0;
  eachMatch(str, pattern, () => { n += 1; });
  return n;
}

function countTerms(lower, terms) {
  return terms.reduce((sum, t) => sum + countMatches(lower, termPattern(t)), 0);
}

function trimUrl(url) {
  return url.replace(/[.,;:!?)\]]+$/, "");
}

function firstMatch(s, re) {
  const m = s.match(re);
  return m === null ? "" : m[0];
}

// Host = text before the first / ? #, after the last @, before the first :.
export function urlHost(url) {
  const rest = url.replace(/^https?:\/\//, "");
  const host = firstMatch(rest, /^[^/?#]*/).replace(/^(?:[^@]*@)+/, "");
  return firstMatch(host, /^[^:]*/);
}

function urlFeatures(lower, shorteners) {
  const urls = [];
  eachMatch(lower, URL_PATTERN, (m) => urls.push(trimUrl(m[0])));
  const hosts = urls.map(urlHost);
  const isShort = (h) => shorteners.some((s) => h === s || h.endsWith("." + s));
  return {
    n_urls: urls.length,
    has_url: urls.length > 0 ? 1 : 0,
    ip_url: hosts.some((h) => IP_HOST.test(h)) ? 1 : 0,
    shortener_url: hosts.some(isShort) ? 1 : 0,
    at_in_url: urls.some((u) => u.includes("@")) ? 1 : 0
  };
}

// Uppercase share of letters inside words of 2+ ASCII letters; 0 if there are none.
function capsRatio(text) {
  const letters = (text.match(/[A-Za-z]{2,}/g) || []).join("");
  if (letters.length === 0) return 0;
  return (letters.match(/[A-Z]/g) || []).length / letters.length;
}

// Code points, matching stringi::stri_length().
function codePointLength(s) {
  let n = 0;
  for (const ch of s) {
    if (ch !== undefined) n += 1;
  }
  return n;
}

export function extractFeatures(subject, body, lexicon) {
  const subj = subject || "";
  const bod = body || "";
  const text = subj + "\n" + bod;
  const lower = asciiLower(text);
  const urgency = countTerms(lower, lexicon.urgency);
  const credential = countTerms(lower, lexicon.credential);
  const money = countTerms(lower, lexicon.money);
  return {
    ...urlFeatures(lower, lexicon.shorteners),
    urgency_count: urgency,
    credential_count: credential,
    money_count: money,
    has_urgency: urgency > 0 ? 1 : 0,
    has_credential: credential > 0 ? 1 : 0,
    has_money: money > 0 ? 1 : 0,
    generic_greeting: countTerms(lower, lexicon.generic_greeting) > 0 ? 1 : 0,
    exclam_count: text.split("!").length - 1,
    caps_ratio: capsRatio(text),
    body_chars: codePointLength(bod),
    n_words: countMatches(bod, "[^ \\t\\n\\r\\f\\x0B]+"),
    has_html: HTML_TAG.test(lower) ? 1 : 0,
    subject_caps: SUBJECT_CAPS.test(subj) ? 1 : 0
  };
}

// Lexicon matches in one string as [start, end, group] ranges (UTF-16 offsets), merged.
export function findHighlights(text, lexicon) {
  const lower = asciiLower(text);
  const ranges = [];
  for (const group of HIGHLIGHT_GROUPS) {
    for (const term of lexicon[group]) {
      eachMatch(lower, termPattern(term), (m) => {
        const start = m.index + m[1].length;
        ranges.push([start, m.index + m[0].length, group]);
      });
    }
  }
  ranges.sort((a, b) => a[0] - b[0] || b[1] - a[1]);
  const merged = [];
  for (const r of ranges) {
    const last = merged[merged.length - 1];
    if (last && r[0] < last[1]) {
      last[1] = Math.max(last[1], r[1]);
    } else {
      merged.push(r.slice());
    }
  }
  return merged;
}
