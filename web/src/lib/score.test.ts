// @vitest-environment node
import { readFileSync } from "node:fs";
import { describe, expect, test } from "vitest";
import { EXAMPLES } from "../data/examples";
import { extractFeatures } from "./features";
import {
  likelihoodTerms,
  posterior,
  posteriorFromTerms,
  PRIOR_MAX,
  PRIOR_MIN,
  priorToSlider,
  sliderToPrior,
  SLIDER_STEPS,
  verdictFor,
  type Model
} from "./score";

const model = JSON.parse(readFileSync(new URL("../../public/model.json", import.meta.url), "utf8")) as Model;
const ex = EXAMPLES.phishy;
const features = extractFeatures(ex.subject, ex.body, model.lexicon);
const { l1, l0 } = likelihoodTerms(model, features);

describe("prevalence slider", () => {
  test("maps its range onto 0.1% to 50% on a log scale", () => {
    expect(sliderToPrior(0)).toBeCloseTo(PRIOR_MIN, 12);
    expect(sliderToPrior(SLIDER_STEPS)).toBeCloseTo(PRIOR_MAX, 12);
    // Halfway on a log scale is the geometric mean.
    expect(sliderToPrior(SLIDER_STEPS / 2)).toBeCloseTo(Math.sqrt(PRIOR_MIN * PRIOR_MAX), 10);
    expect(sliderToPrior(priorToSlider(0.01))).toBeCloseTo(0.01, 4);
  });

  test("posterior at the slider value equals the log-odds posterior", () => {
    for (const v of [0, 200, priorToSlider(0.01), 700, SLIDER_STEPS]) {
      const prior = sliderToPrior(v);
      expect(posteriorFromTerms(l1, l0, prior)).toBeCloseTo(posterior(model, features, prior), 10);
    }
  });

  test("posterior rises with prevalence and the verdict follows", () => {
    const values = [0, 250, 500, 750, 1000].map((v) => posteriorFromTerms(l1, l0, sliderToPrior(v)));
    for (let i = 1; i < values.length; i++) expect(values[i]).toBeGreaterThan(values[i - 1]);
    expect(posteriorFromTerms(l1, l0, 0.01)).toBeCloseTo(0.1078, 3);
    expect(verdictFor(posteriorFromTerms(l1, l0, 0.001), 0.5)).toBe("legitimate");
    expect(verdictFor(posteriorFromTerms(l1, l0, 0.01), 0.5)).toBe("suspicious");
    expect(verdictFor(posteriorFromTerms(l1, l0, 0.5), 0.5)).toBe("phishing");
  });

  test("hand-computed Bayes example", () => {
    // pi 0.1, L1 0.32, L0 0.14: 0.032 / (0.032 + 0.126)
    expect(posteriorFromTerms(0.32, 0.14, 0.1)).toBeCloseTo(0.032 / 0.158, 12);
  });
});
