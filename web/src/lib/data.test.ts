// @vitest-environment node
import { readFileSync } from "node:fs";
import { describe, expect, test } from "vitest";
import { validateMeta, validateModelJson, validateModuleData, validatePipeline } from "./data";

const read = (rel: string) =>
  JSON.parse(readFileSync(new URL("../../public/" + rel, import.meta.url), "utf8")) as Record<
    string,
    unknown
  >;

describe("exported JSON passes validation", () => {
  test.each([0, 1, 2, 3, 4, 5, 6, 7, 8])("m%i.json", (i) => {
    const r = validateModuleData(read("data/m" + i + ".json"));
    expect(r.ok, r.ok ? "" : r.error).toBe(true);
    if (r.ok) {
      expect(r.value.id).toBe(i);
      expect(r.value.code.length).toBeGreaterThan(0);
    }
  });

  test("meta, pipeline and model", () => {
    expect(validateMeta(read("data/meta.json")).ok).toBe(true);
    expect(validatePipeline(read("data/pipeline.json")).ok).toBe(true);
    expect(validateModelJson(read("model.json")).ok).toBe(true);
  });
});

describe("validators reject malformed JSON", () => {
  const good = read("data/m4.json");

  test.each([
    ["not an object", null],
    ["array", []],
    ["missing title", { ...good, title: undefined }],
    ["unknown chart type", { ...good, charts: [{ id: "c", title: "t", type: "pie", series: [] }] }],
    [
      "too many points",
      {
        ...good,
        charts: [
          {
            id: "c",
            title: "t",
            type: "line",
            series: [{ name: "s", points: Array.from({ length: 501 }, (_, i) => ({ x: i, y: i })) }]
          }
        ]
      }
    ],
    [
      "bad point",
      {
        ...good,
        charts: [{ id: "c", title: "t", type: "bar", series: [{ name: "s", points: [{ x: {} }] }] }]
      }
    ],
    ["ragged table", { ...good, tables: [{ title: "t", columns: ["a", "b"], rows: [[1]] }] }],
    ["code without start_line", { ...good, code: [{ label: "l", file: "f", code: "x" }] }]
  ])("module: %s", (_label, value) => {
    expect(validateModuleData(value).ok).toBe(false);
  });

  test("meta and pipeline", () => {
    const meta = read("data/meta.json");
    expect(validateMeta({ ...meta, headline: { ...(meta.headline as object), auc: "high" } }).ok).toBe(false);
    expect(validateMeta({ ...meta, r_version: 4 }).ok).toBe(false);
    const pipe = read("data/pipeline.json");
    expect(validatePipeline({ ...pipe, steps: [] }).ok).toBe(false);
    expect(validatePipeline({ ...pipe, split: { train: "many" } }).ok).toBe(false);
    expect(validateModelJson({ version: "1", prior: 0.1 }).ok).toBe(false);
  });
});
