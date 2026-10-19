// PhishScore: Bernoulli naive Bayes posterior from model.json. Pure functions.

const LEXICON_GROUPS = ["urgency", "credential", "money", "generic_greeting", "shorteners"];

const isProb = (x) => typeof x === "number" && Number.isFinite(x) && x > 0 && x < 1;
const isStringArray = (a) => Array.isArray(a) && a.every((s) => typeof s === "string");

// Returns null when the model is usable, otherwise a short reason.
export function validateModel(m) {
  if (m === null || typeof m !== "object") return "model is not an object";
  if (typeof m.version !== "string") return "missing version";
  if (!isProb(m.prior)) return "prior must be between 0 and 1";
  if (!isProb(m.threshold)) return "threshold must be between 0 and 1";
  if (!isStringArray(m.features) || m.features.length === 0) return "missing features";
  if (m.lexicon === null || typeof m.lexicon !== "object") return "missing lexicon";
  for (const g of LEXICON_GROUPS) {
    if (!isStringArray(m.lexicon[g])) return "lexicon group " + g + " is invalid";
  }
  if (m.likelihoods === null || typeof m.likelihoods !== "object") return "missing likelihoods";
  for (const f of m.features) {
    const l = m.likelihoods[f];
    if (!l || !isProb(l.phishing) || !isProb(l.legitimate)) {
      return "likelihoods for " + f + " are invalid";
    }
  }
  return null;
}

// Likelihood ratio P(x | phishing) / P(x | legitimate) for each feature's observed state.
export function likelihoodRatios(model, features) {
  return model.features.map((f) => {
    const p1 = model.likelihoods[f].phishing;
    const p0 = model.likelihoods[f].legitimate;
    const fired = features[f] === 1;
    return { feature: f, fired, ratio: fired ? p1 / p0 : (1 - p1) / (1 - p0) };
  });
}

// Posterior P(phishing | x) on the log-odds scale, as in R/phishscore.R.
export function posterior(model, features, prior = model.prior) {
  let w1 = 0;
  let w0 = 0;
  for (const f of model.features) {
    const p1 = model.likelihoods[f].phishing;
    const p0 = model.likelihoods[f].legitimate;
    const x = features[f];
    w1 += x * Math.log(p1 / p0);
    w0 += (1 - x) * Math.log((1 - p1) / (1 - p0));
  }
  const logOdds = Math.log(prior / (1 - prior)) + (w1 + w0);
  return 1 / (1 + Math.exp(-logOdds));
}
