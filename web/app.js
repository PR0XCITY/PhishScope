// UI for the PhishScope checker. All output is built with createElement + textContent.

import { extractFeatures, findHighlights, HIGHLIGHT_GROUPS } from "./features.js";
import { posterior, likelihoodRatios, validateModel } from "./score.js";
import { EXAMPLES } from "./examples.js";

export const MAX_BODY = 20000;
export const MAX_SUBJECT = 500;

const FEATURE_LABELS = {
  has_credential: "Credential words (password, login, account...)",
  generic_greeting: "Generic greeting (Dear customer...)",
  has_money: "Money words (prize, refund, wire transfer...)",
  subject_caps: "3+ ALL-CAPS words in subject",
  has_urgency: "Urgency words (urgent, suspend, verify...)",
  at_in_url: "@ inside a link",
  has_url: "Contains a link",
  ip_url: "Link to a bare IP address",
  shortener_url: "Link shortener"
};
const GROUP_LABELS = {
  urgency: "urgency", credential: "credential", money: "money",
  generic_greeting: "generic greeting"
};

// Cut to max UTF-16 units without splitting a surrogate pair.
export function clampText(s, max) {
  const str = typeof s === "string" ? s : "";
  if (str.length <= max) return str;
  const code = str.charCodeAt(max - 1);
  return str.slice(0, code >= 0xd800 && code <= 0xdbff ? max - 1 : max);
}

export function formatPercent(p) {
  if (p < 0.001) return "<0.1%";
  if (p > 0.999) return ">99.9%";
  return (100 * p).toFixed(1) + "%";
}

function el(doc, tag, className, text) {
  const node = doc.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}

function scoreCard(doc, label, score, threshold) {
  const flagged = score >= threshold;
  const card = el(doc, "div", "score-card " + (flagged ? "flagged" : "clear"));
  card.appendChild(el(doc, "p", "score-label", label));
  card.appendChild(el(doc, "p", "score-value", formatPercent(score)));
  const meter = el(doc, "meter");
  meter.setAttribute("min", "0");
  meter.setAttribute("max", "1");
  meter.setAttribute("value", String(score));
  meter.setAttribute("aria-label", label + " " + formatPercent(score));
  card.appendChild(meter);
  card.appendChild(el(doc, "p", "verdict", flagged ? "Looks like phishing" : "No strong phishing signal"));
  return card;
}

function flagTable(doc, model, features) {
  const wrap = el(doc, "div", "table-wrap");
  const table = el(doc, "table");
  const head = el(doc, "tr");
  for (const h of ["Signal", "Present", "Likelihood ratio", "Effect"]) {
    const th = el(doc, "th", null, h);
    th.setAttribute("scope", "col");
    head.appendChild(th);
  }
  const thead = el(doc, "thead");
  thead.appendChild(head);
  table.appendChild(thead);
  const tbody = el(doc, "tbody");
  const rows = likelihoodRatios(model, features).sort((a, b) => b.ratio - a.ratio);
  for (const r of rows) {
    const tr = el(doc, "tr", r.fired ? "fired" : null);
    tr.appendChild(el(doc, "td", null, FEATURE_LABELS[r.feature] || r.feature));
    tr.appendChild(el(doc, "td", null, r.fired ? "Yes" : "No"));
    tr.appendChild(el(doc, "td", "num", (r.ratio >= 10 ? r.ratio.toFixed(0) : r.ratio.toFixed(2)) + "x"));
    tr.appendChild(el(doc, "td", null, r.ratio > 1.05 ? "raises" : r.ratio < 0.95 ? "lowers" : "neutral"));
    tbody.appendChild(tr);
  }
  table.appendChild(tbody);
  wrap.appendChild(table);
  return wrap;
}

// Text with lexicon matches wrapped in <mark>; every piece of input goes in as text.
export function highlighted(doc, text, lexicon) {
  const box = el(doc, "div", "preview");
  let pos = 0;
  for (const [start, end, group] of findHighlights(text, lexicon)) {
    if (start > pos) box.appendChild(doc.createTextNode(text.slice(pos, start)));
    const mark = el(doc, "mark", group, text.slice(start, end));
    mark.setAttribute("title", GROUP_LABELS[group]);
    box.appendChild(mark);
    pos = end;
  }
  if (pos < text.length) box.appendChild(doc.createTextNode(text.slice(pos)));
  return box;
}

function legend(doc) {
  const list = el(doc, "ul", "legend");
  for (const g of HIGHLIGHT_GROUPS) {
    const item = el(doc, "li");
    item.appendChild(el(doc, "mark", g, GROUP_LABELS[g]));
    list.appendChild(item);
  }
  return list;
}

export function buildResults(doc, model, rawSubject, rawBody) {
  const subject = clampText(rawSubject, MAX_SUBJECT);
  const body = clampText(rawBody, MAX_BODY);
  const features = extractFeatures(subject, body, model.lexicon);
  const root = el(doc, "div", "card");
  root.appendChild(el(doc, "h2", null, "PhishScore"));
  const scores = el(doc, "div", "scores");
  scores.appendChild(scoreCard(doc, "At dataset prior (" + formatPercent(model.prior) + " phishing)",
    posterior(model, features), model.threshold));
  scores.appendChild(scoreCard(doc, "At 1% prior (typical inbox)",
    posterior(model, features, 0.01), model.threshold));
  root.appendChild(scores);
  root.appendChild(el(doc, "p", "explain",
    "Same evidence, different starting point: the training data is " +
    formatPercent(model.prior) + " phishing, a real inbox is closer to 1%, " +
    "so the same red flags give a lower score on the right."));
  root.appendChild(el(doc, "h2", null, "Red flags"));
  root.appendChild(flagTable(doc, model, features));
  root.appendChild(el(doc, "h2", null, "Matched words"));
  root.appendChild(legend(doc));
  root.appendChild(el(doc, "p", "score-label", "Subject"));
  root.appendChild(highlighted(doc, subject, model.lexicon));
  root.appendChild(el(doc, "p", "score-label", "Body"));
  root.appendChild(highlighted(doc, body, model.lexicon));
  return root;
}

function setStatus(node, message, isError) {
  node.textContent = message;
  node.className = isError ? "status error" : "status";
}

export async function init(doc, fetchFn) {
  const form = doc.getElementById("email-form");
  const subject = doc.getElementById("subject");
  const body = doc.getElementById("body");
  const counter = doc.getElementById("counter");
  const status = doc.getElementById("status");
  const results = doc.getElementById("results");
  const buttons = Array.from(form.querySelectorAll("button"));
  const updateCounter = () => {
    counter.textContent = body.value.length.toLocaleString("en-US") + " / 20,000 characters";
  };
  body.addEventListener("input", updateCounter);

  let model;
  try {
    const response = await fetchFn("./model.json", { cache: "no-cache" });
    if (!response.ok) throw new Error("HTTP " + response.status);
    model = await response.json();
  } catch (err) {
    setStatus(status, "Could not load the model (" + err.message + "). Please reload the page.", true);
    return;
  }
  const problem = validateModel(model);
  if (problem !== null) {
    setStatus(status, "The model file is invalid: " + problem + ".", true);
    return;
  }

  const analyze = () => {
    results.replaceChildren(buildResults(doc, model, subject.value, body.value));
    results.hidden = false;
  };
  form.addEventListener("submit", (event) => {
    event.preventDefault();
    analyze();
  });
  for (const b of buttons.filter((x) => x.dataset.example)) {
    b.addEventListener("click", () => {
      const ex = EXAMPLES[b.dataset.example];
      subject.value = ex.subject;
      body.value = ex.body;
      updateCounter();
      analyze();
    });
  }
  buttons.forEach((b) => { b.disabled = false; });
  setStatus(status, "Model v" + model.version + " loaded. Everything runs in this page.", false);
}

if (typeof document !== "undefined" && typeof window !== "undefined") {
  init(document, window.fetch.bind(window));
}
