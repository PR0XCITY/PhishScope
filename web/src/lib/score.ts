// PhishScore: Bernoulli naive Bayes posterior from model.json. Pure functions.

import type { Features, Lexicon } from "./features";

export interface Model {
  version: string;
  training_date?: string;
  prior: number;
  threshold: number;
  features: (keyof Features)[];
  likelihoods: Record<string, { phishing: number; legitimate: number }>;
  lexicon: Lexicon;
}

export interface Ratio {
  feature: keyof Features;
  fired: boolean;
  ratio: number;
}

const LEXICON_GROUPS: (keyof Lexicon)[] = [
  "urgency",
  "credential",
  "money",
  "generic_greeting",
  "shorteners"
];

const isProb = (x: unknown): x is number => typeof x === "number" && Number.isFinite(x) && x > 0 && x < 1;
const isStringArray = (a: unknown): a is string[] =>
  Array.isArray(a) && a.every((s) => typeof s === "string");
const isObject = (x: unknown): x is Record<string, unknown> => x !== null && typeof x === "object";

// Returns null when the model is usable, otherwise a short reason.
export function validateModel(m: unknown): string | null {
  if (!isObject(m)) return "model is not an object";
  if (typeof m.version !== "string") return "missing version";
  if (!isProb(m.prior)) return "prior must be between 0 and 1";
  if (!isProb(m.threshold)) return "threshold must be between 0 and 1";
  if (!isStringArray(m.features) || m.features.length === 0) return "missing features";
  if (!isObject(m.lexicon)) return "missing lexicon";
  for (const g of LEXICON_GROUPS) {
    if (!isStringArray(m.lexicon[g])) return "lexicon group " + g + " is invalid";
  }
  if (!isObject(m.likelihoods)) return "missing likelihoods";
  for (const f of m.features) {
    const l = m.likelihoods[f];
    if (!isObject(l) || !isProb(l.phishing) || !isProb(l.legitimate)) {
      return "likelihoods for " + f + " are invalid";
    }
  }
  return null;
}

// Likelihood ratio P(x | phishing) / P(x | legitimate) for each feature's observed state.
export function likelihoodRatios(model: Model, features: Features): Ratio[] {
  return model.features.map((f) => {
    const { phishing: p1, legitimate: p0 } = model.likelihoods[f];
    const fired = features[f] === 1;
    return { feature: f, fired, ratio: fired ? p1 / p0 : (1 - p1) / (1 - p0) };
  });
}

// Posterior P(phishing | x) on the log-odds scale, as in R/phishscore.R.
export function posterior(model: Model, features: Features, prior: number = model.prior): number {
  let w1 = 0;
  let w0 = 0;
  for (const f of model.features) {
    const { phishing: p1, legitimate: p0 } = model.likelihoods[f];
    const x = features[f];
    w1 += x * Math.log(p1 / p0);
    w0 += (1 - x) * Math.log((1 - p1) / (1 - p0));
  }
  const logOdds = Math.log(prior / (1 - prior)) + (w1 + w0);
  return 1 / (1 + Math.exp(-logOdds));
}

// Products of per-feature likelihoods: L1 = P(x | phishing), L0 = P(x | legitimate).
export function likelihoodTerms(model: Model, features: Features): { l1: number; l0: number } {
  let l1 = 1;
  let l0 = 1;
  for (const f of model.features) {
    const { phishing: p1, legitimate: p0 } = model.likelihoods[f];
    const x = features[f];
    l1 *= x === 1 ? p1 : 1 - p1;
    l0 *= x === 1 ? p0 : 1 - p0;
  }
  return { l1, l0 };
}

// Bayes rule with an arbitrary prevalence: pi L1 / (pi L1 + (1 - pi) L0).
export function posteriorFromTerms(l1: number, l0: number, prior: number): number {
  const num = prior * l1;
  return num / (num + (1 - prior) * l0);
}

// Prevalence slider: 0..1000 mapped on a log scale from 0.1% to 50%.
export const SLIDER_STEPS = 1000;
export const PRIOR_MIN = 0.001;
export const PRIOR_MAX = 0.5;
const LOG_MIN = Math.log10(PRIOR_MIN);
const LOG_SPAN = Math.log10(PRIOR_MAX) - LOG_MIN;

export function sliderToPrior(v: number): number {
  const t = Math.min(Math.max(v, 0), SLIDER_STEPS) / SLIDER_STEPS;
  return 10 ** (LOG_MIN + t * LOG_SPAN);
}

export function priorToSlider(p: number): number {
  const clamped = Math.min(Math.max(p, PRIOR_MIN), PRIOR_MAX);
  return Math.round(((Math.log10(clamped) - LOG_MIN) / LOG_SPAN) * SLIDER_STEPS);
}

export type Verdict = "legitimate" | "suspicious" | "phishing";

// Suspicious from 5%: at a 1% base rate that is already a fivefold lift.
export const SUSPICIOUS_FROM = 0.05;

export function verdictFor(p: number, threshold: number): Verdict {
  if (p >= threshold) return "phishing";
  if (p >= SUSPICIOUS_FROM) return "suspicious";
  return "legitimate";
}
