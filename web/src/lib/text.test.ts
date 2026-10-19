// @vitest-environment node
import { expect, test } from "vitest";
import { clampText, formatPercent, MAX_BODY, MAX_SUBJECT } from "./text";

test("input is clamped to the length limits", () => {
  expect(MAX_BODY).toBe(20000);
  expect(clampText("x".repeat(25000), MAX_BODY)).toHaveLength(20000);
  expect(clampText("y".repeat(900), MAX_SUBJECT)).toHaveLength(500);
  expect(clampText("short", MAX_BODY)).toBe("short");
  expect(clampText(undefined, MAX_BODY)).toBe("");
  // A surrogate pair at the cut is dropped whole, never split.
  expect(clampText("a".repeat(MAX_BODY - 1) + "\u{1F600}", MAX_BODY)).toHaveLength(MAX_BODY - 1);
});

test("percent formatting", () => {
  expect(formatPercent(0.1078)).toBe("10.8%");
  expect(formatPercent(0.0004)).toBe("<0.1%");
  expect(formatPercent(0.9999)).toBe(">99.9%");
});
