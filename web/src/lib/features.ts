// Port of R/features.R. Every pattern is the same ASCII regex string used in R
// (no lookbehind, no Unicode classes, no "." or "$" applied to non-ASCII input).

export interface Lexicon {
  urgency: string[];
  credential: string[];
  money: string[];
  generic_greeting: string[];
  shorteners: string[];
}

export interface Features {
  n_urls: number;
  has_url: number;
  ip_url: number;
  shortener_url: number;
  at_in_url: number;
  urgency_count: number;
  credential_count: number;
  money_count: number;
  has_urgency: number;
  has_credential: number;
  has_money: number;
  generic_greeting: number;
  exclam_count: number;
  caps_ratio: number;
  body_chars: number;
  n_words: number;
  has_html: number;
  subject_caps: number;
}

export type HighlightGroup = "urgency" | "credential" | "money" | "generic_greeting";
export type Highlight = [start: number, end: number, group: HighlightGroup];

const WS = "[ \\t\\n\\r\\f\\x0B]";
const URL_PATTERN = "https?://[A-Za-z0-9._~:/?#@!$&()*+,;=%\\[\\]-]+";
const IP_HOST = /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/;
const SUBJECT_CAPS = /(^|[^A-Za-z0-9])[A-Z]{2,}([^A-Za-z0-9]+[A-Z]{2,}){2}(?![A-Za-z0-9])/;
// Same ASCII whitespace class as R, built from WS (vertical tab \x0B included).
const HTML_TAG = new RegExp("<html|<a" + WS + "+href");

export const HIGHLIGHT_GROUPS: HighlightGroup[] = ["urgency", "credential", "money", "generic_greeting"];

// Lowercase A-Z only, matching chartr() in R.
export function asciiLower(s: string): string {
  return s.replace(/[A-Z]/g, (c) => String.fromCharCode(c.charCodeAt(0) + 32));
}

function escapeRegex(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

// Whole word or phrase: no [a-z0-9_] on either side; spaces match any whitespace run.
export function termPattern(term: string): string {
  return (
    "(^|[^a-z0-9_])" +
    escapeRegex(term)
      .split(" ")
      .join(WS + "+") +
    "(?![a-z0-9_])"
  );
}

function eachMatch(str: string, pattern: string, fn: (m: RegExpExecArray) => void): void {
  const re = new RegExp(pattern, "g");
  let m = re.exec(str);
  while (m !== null) {
    fn(m);
    if (m[0] === "") re.lastIndex += 1;
    m = re.exec(str);
  }
}

function countMatches(str: string, pattern: string): number {
  let n = 0;
  eachMatch(str, pattern, () => {
    n += 1;
  });
  return n;
}

function countTerms(lower: string, terms: string[]): number {
  return terms.reduce((sum, t) => sum + countMatches(lower, termPattern(t)), 0);
}

function trimUrl(url: string): string {
  return url.replace(/[.,;:!?)\]]+$/, "");
}

function firstMatch(s: string, re: RegExp): string {
  const m = s.match(re);
  return m === null ? "" : m[0];
}

// Host = text before the first / ? #, after the last @, before the first :.
export function urlHost(url: string): string {
  const rest = url.replace(/^https?:\/\//, "");
  const host = firstMatch(rest, /^[^/?#]*/).replace(/^(?:[^@]*@)+/, "");
  return firstMatch(host, /^[^:]*/);
}

function urlFeatures(lower: string, shorteners: string[]) {
  const urls: string[] = [];
  eachMatch(lower, URL_PATTERN, (m) => urls.push(trimUrl(m[0])));
  const hosts = urls.map(urlHost);
  const isShort = (h: string) => shorteners.some((s) => h === s || h.endsWith("." + s));
  return {
    n_urls: urls.length,
    has_url: urls.length > 0 ? 1 : 0,
    ip_url: hosts.some((h) => IP_HOST.test(h)) ? 1 : 0,
    shortener_url: hosts.some(isShort) ? 1 : 0,
    at_in_url: urls.some((u) => u.includes("@")) ? 1 : 0
  };
}

// Uppercase share of letters inside words of 2+ ASCII letters; 0 if there are none.
function capsRatio(text: string): number {
  const letters = (text.match(/[A-Za-z]{2,}/g) ?? []).join("");
  if (letters.length === 0) return 0;
  return (letters.match(/[A-Z]/g) ?? []).length / letters.length;
}

// Code points, matching stringi::stri_length().
function codePointLength(s: string): number {
  return Array.from(s).length;
}

export function extractFeatures(subject: string, body: string, lexicon: Lexicon): Features {
  const text = subject + "\n" + body;
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
    body_chars: codePointLength(body),
    n_words: countMatches(body, "[^ \\t\\n\\r\\f\\x0B]+"),
    has_html: HTML_TAG.test(lower) ? 1 : 0,
    subject_caps: SUBJECT_CAPS.test(subject) ? 1 : 0
  };
}

// Lexicon matches in one string as merged [start, end, group] ranges (UTF-16 offsets).
export function findHighlights(text: string, lexicon: Lexicon): Highlight[] {
  const lower = asciiLower(text);
  const ranges: Highlight[] = [];
  for (const group of HIGHLIGHT_GROUPS) {
    for (const term of lexicon[group]) {
      eachMatch(lower, termPattern(term), (m) => {
        ranges.push([m.index + m[1].length, m.index + m[0].length, group]);
      });
    }
  }
  ranges.sort((a, b) => a[0] - b[0] || b[1] - a[1]);
  const merged: Highlight[] = [];
  for (const r of ranges) {
    const last = merged[merged.length - 1];
    if (last && r[0] < last[1]) {
      last[1] = Math.max(last[1], r[1]);
    } else {
      merged.push([r[0], r[1], r[2]]);
    }
  }
  return merged;
}
