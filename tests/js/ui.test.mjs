// UI safety: input length limit, and rendering never turns input into HTML.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import { buildResults, clampText, MAX_BODY, MAX_SUBJECT } from "../../web/app.js";

const root = new URL("../../", import.meta.url);
const model = JSON.parse(readFileSync(new URL("web/model.json", root), "utf8"));
const ALLOWED_TAGS = new Set(["div", "h2", "p", "meter", "table", "thead", "tbody", "tr", "th",
  "td", "ul", "li", "mark"]);

// Minimal DOM: records every element and refuses any HTML-parsing entry point.
function fakeDocument() {
  const created = [];
  const forbid = (name) => () => { throw new Error(name + " used"); };
  class Node {
    constructor(tag, text) {
      this.tagName = tag;
      this.children = [];
      this.attributes = {};
      this.className = "";
      this.ownText = text || "";
    }
    appendChild(child) { this.children.push(child); return child; }
    setAttribute(k, v) { this.attributes[k] = String(v); }
    set textContent(v) { this.ownText = String(v); this.children = []; }
    get textContent() { return this.ownText + this.children.map((c) => c.textContent).join(""); }
  }
  for (const prop of ["innerHTML", "outerHTML"]) {
    Object.defineProperty(Node.prototype, prop, { get: forbid(prop), set: forbid(prop) });
  }
  Node.prototype.insertAdjacentHTML = forbid("insertAdjacentHTML");
  return {
    created,
    createElement(tag) { const n = new Node(tag); created.push(n); return n; },
    createTextNode(text) { return new Node("#text", text); },
    write: forbid("document.write")
  };
}

test("input is clamped to the length limits", () => {
  assert.equal(clampText("x".repeat(25000), MAX_BODY).length, 20000);
  assert.equal(clampText("short", MAX_BODY), "short");
  assert.equal(clampText(undefined, MAX_BODY), "");
  const emoji = "a".repeat(MAX_BODY - 1) + "\u{1F600}";
  assert.equal(clampText(emoji, MAX_BODY).length, MAX_BODY - 1);
  const html = readFileSync(new URL("web/index.html", root), "utf8");
  assert.match(html, /<textarea[^>]*maxlength="20000"/);
  assert.match(html, new RegExp(`id="subject"[^>]*maxlength="${MAX_SUBJECT}"`));
});

test("malicious input is rendered as text only", () => {
  const doc = fakeDocument();
  const subject = "<img src=x onerror=alert(1)> URGENT ACCOUNT NOTICE";
  const body = "<script>alert('x')</script> verify your password at " +
    "<a href=\"javascript:alert(1)\">http://evil.example/login</a> dear customer";
  const out = buildResults(doc, model, subject, body);
  for (const n of doc.created) assert.ok(ALLOWED_TAGS.has(n.tagName), "unexpected <" + n.tagName + ">");
  assert.ok(!doc.created.some((n) => n.tagName === "a"), "links must not be clickable");
  for (const n of doc.created) {
    for (const k of Object.keys(n.attributes)) assert.ok(!/^on|href|src/i.test(k), "attribute " + k);
  }
  const text = out.textContent;
  assert.ok(text.includes("<img src=x onerror=alert(1)>"));
  assert.ok(text.includes("<script>alert('x')</script>"));
  assert.ok(text.includes("http://evil.example/login"));
  assert.ok(doc.created.some((n) => n.tagName === "mark" && n.textContent === "password"));
});

test("web sources avoid HTML injection sinks and inline code", () => {
  const dir = new URL("web/", root);
  const banned = /innerHTML|outerHTML|insertAdjacentHTML|document\.write|\beval\s*\(|new Function/;
  for (const name of readdirSync(dir).filter((f) => f.endsWith(".js"))) {
    assert.doesNotMatch(readFileSync(new URL(name, dir), "utf8"), banned, name);
  }
  const html = readFileSync(new URL("index.html", dir), "utf8");
  assert.doesNotMatch(html, /\son[a-z]+\s*=/i, "inline handler");
  assert.doesNotMatch(html, /<script(?![^>]*\bsrc=)[^>]*>/i, "inline script");
  assert.doesNotMatch(html, /\sstyle\s*=|<style/i, "inline style");
  assert.doesNotMatch(html, /https?:\/\//i, "external resource");
  assert.match(html, /default-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self'; img-src 'self'; base-uri 'none'; form-action 'none'/);
});
