// Parity: web/features.js + web/score.js must reproduce tests/parity/expected.json (from R).
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { extractFeatures } from "../../web/features.js";
import { posterior, validateModel } from "../../web/score.js";

const root = new URL("../../", import.meta.url);
const model = JSON.parse(readFileSync(new URL("web/model.json", root), "utf8"));
const expected = JSON.parse(readFileSync(new URL("tests/parity/expected.json", root), "utf8"));
const TOL = 1e-6;

test("model.json passes validation", () => {
  assert.equal(validateModel(model), null);
  assert.equal(expected.model_version, model.version);
});

for (const c of expected.cases) {
  test(`features match R for ${c.id}`, () => {
    const got = extractFeatures(c.subject, c.body, model.lexicon);
    assert.deepEqual(Object.keys(got), Object.keys(c.features));
    for (const [name, want] of Object.entries(c.features)) {
      if (name === "caps_ratio") {
        assert.ok(Math.abs(got[name] - want) <= TOL, `${name}: ${got[name]} vs ${want}`);
      } else {
        assert.equal(got[name], want, name);
      }
    }
  });

  test(`scores match R for ${c.id}`, () => {
    const f = extractFeatures(c.subject, c.body, model.lexicon);
    const atPrior = posterior(model, f);
    const at1 = posterior(model, f, 0.01);
    assert.ok(Math.abs(atPrior - c.score_dataset_prior) <= TOL, `${atPrior} vs ${c.score_dataset_prior}`);
    assert.ok(Math.abs(at1 - c.score_1pct_prior) <= TOL, `${at1} vs ${c.score_1pct_prior}`);
  });
}

test("validateModel rejects malformed models", () => {
  assert.notEqual(validateModel(null), null);
  assert.notEqual(validateModel({ ...model, prior: 2 }), null);
  const broken = structuredClone(model);
  broken.likelihoods[model.features[0]].phishing = "0.5";
  assert.notEqual(validateModel(broken), null);
  const noLex = structuredClone(model);
  delete noLex.lexicon.urgency;
  assert.notEqual(validateModel(noLex), null);
});
