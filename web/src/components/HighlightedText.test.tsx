import { cleanup, render } from "@testing-library/react";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { afterEach, expect, test } from "vitest";
import type { Model } from "../lib/score";
import { HighlightedText } from "./HighlightedText";

// Vitest runs from web/, so paths resolve from the project folder.
const model = JSON.parse(readFileSync(join(process.cwd(), "public", "model.json"), "utf8")) as Model;

afterEach(cleanup);

test("highlighted email renders no HTML from input", () => {
  const body =
    "<img src=x onerror=alert(1)> <script>alert('x')</script> verify your password at " +
    '<a href="javascript:alert(1)">http://evil.example/login</a> <iframe src="//x"></iframe> dear customer';
  const { container } = render(<HighlightedText label="Body" text={body} lexicon={model.lexicon} />);

  expect(container.querySelectorAll("img, script, a, iframe, object, embed, style")).toHaveLength(0);
  for (const el of Array.from(container.querySelectorAll("*"))) {
    for (const attr of Array.from(el.attributes)) expect(attr.name).not.toMatch(/^on|^href$|^src$/i);
  }
  expect(container.textContent).toContain("<img src=x onerror=alert(1)>");
  expect(container.textContent).toContain("<script>alert('x')</script>");
  expect(container.textContent).toContain("http://evil.example/login");

  const marks = Array.from(container.querySelectorAll("mark")).map((m) => m.textContent);
  expect(marks).toEqual(expect.arrayContaining(["verify your", "password", "dear customer"]));
});
