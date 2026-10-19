// @vitest-environment node
// Parity: src/lib/features.ts + score.ts must reproduce tests/parity/expected.json (from R).
import { readFileSync } from "node:fs";
import { describe, expect, test } from "vitest";
import { extractFeatures, type Features } from "./features";
import { posterior, validateModel, type Model } from "./score";

interface Case {
  id: string;
  subject: string;
  body: string;
  features: Features;
  score_dataset_prior: number;
  score_1pct_prior: number;
}

const read = (rel: string) => JSON.parse(readFileSync(new URL(rel, import.meta.url), "utf8"));
const model = read("../../public/model.json") as Model;
const expected = read("../../../tests/parity/expected.json") as {
  model_version: string;
  cases: Case[];
};
const TOL = 1e-6;

test("model.json is valid and matches the parity file version", () => {
  expect(validateModel(model)).toBeNull();
  expect(expected.model_version).toBe(model.version);
  expect(expected.cases.length).toBeGreaterThanOrEqual(12);
});

describe.each(expected.cases)("case $id", (c) => {
  const got = extractFeatures(c.subject, c.body, model.lexicon);

  test("features match R", () => {
    expect(Object.keys(got)).toEqual(Object.keys(c.features));
    for (const [name, want] of Object.entries(c.features)) {
      const value = got[name as keyof Features];
      if (name === "caps_ratio") {
        expect(Math.abs(value - want)).toBeLessThanOrEqual(TOL);
      } else {
        expect(value, name).toBe(want);
      }
    }
  });

  test("scores match R", () => {
    expect(Math.abs(posterior(model, got) - c.score_dataset_prior)).toBeLessThanOrEqual(TOL);
    expect(Math.abs(posterior(model, got, 0.01) - c.score_1pct_prior)).toBeLessThanOrEqual(TOL);
  });
});

test("validateModel rejects malformed models", () => {
  expect(validateModel(null)).not.toBeNull();
  expect(validateModel({ ...model, prior: 2 })).not.toBeNull();
  const broken = structuredClone(model) as unknown as {
    likelihoods: Record<string, Record<string, unknown>>;
  };
  broken.likelihoods[model.features[0]].phishing = "0.5";
  expect(validateModel(broken)).not.toBeNull();
  const noLex = structuredClone(model) as unknown as { lexicon: Partial<Record<string, unknown>> };
  delete noLex.lexicon.urgency;
  expect(validateModel(noLex)).not.toBeNull();
});
