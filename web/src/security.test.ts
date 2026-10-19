// @vitest-environment node
// Static guards: no HTML sinks or dynamic code, fetches limited to local JSON, CSP as specified.
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { expect, test } from "vitest";
import { CSP } from "../vite.config";

const webRoot = fileURLToPath(new URL("..", import.meta.url));

function sourceFiles(dir: string): string[] {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) return sourceFiles(path);
    return /\.(ts|tsx)$/.test(name) && !/\.test\./.test(name) ? [path] : [];
  });
}

const files = sourceFiles(join(webRoot, "src"));

test("no HTML sinks, eval or new Function in source", () => {
  const banned = new RegExp(
    [
      "dangerouslySetInnerHTML",
      "\\.innerHTML",
      "\\.outerHTML",
      "insertAdjacentHTML",
      "\\beval\\s*\\(",
      "new Function",
      "document\\.write"
    ].join("|")
  );
  for (const f of files) expect(readFileSync(f, "utf8"), f).not.toMatch(banned);
});

test("fetch is only used by the data loader, for local JSON", () => {
  const callers = files.filter((f) => /\bfetch\s*\(/.test(readFileSync(f, "utf8")));
  expect(callers.map((f) => f.replace(/\\/g, "/").split("/src/")[1])).toEqual(["lib/data.ts"]);
  const loader = readFileSync(join(webRoot, "src", "lib", "data.ts"), "utf8");
  expect(loader).toContain("const ALLOWED_URL = /^\\.\\/(model\\.json|data\\/[a-z0-9_]+\\.json)$/;");
});

test("index.html carries the specified CSP and no inline code", () => {
  const html = readFileSync(join(webRoot, "index.html"), "utf8");
  const expected =
    "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; font-src 'self'; " +
    "img-src 'self' data:; connect-src 'self'; base-uri 'none'; form-action 'none'; object-src 'none'";
  expect(CSP).toBe(expected);
  expect(html).toContain('content="' + expected + '"');
  expect(html).not.toMatch(/<script(?![^>]*\bsrc=)[^>]*>/i);
  expect(html).not.toMatch(/\son[a-z]+\s*=/i);
});
