// Typed loading and manual validation of every JSON file the site reads.
// The only network requests are ./model.json and ./data/*.json.

import { useEffect, useState } from "react";
import { validateModel, type Model } from "./score";

export type Cell = string | number | boolean | null;
export interface Point {
  x: number | string;
  y: number | string;
  value?: number;
}
export interface Series {
  name: string;
  class: string | null;
  points: Point[];
}
export const CHART_TYPES = [
  "histogram",
  "bar",
  "line",
  "scatter",
  "qq",
  "roc",
  "heatmap",
  "survival"
] as const;
export type ChartType = (typeof CHART_TYPES)[number];
export interface Chart {
  id: string;
  type: ChartType;
  title: string;
  x_label: string;
  y_label: string;
  series: Series[];
  note: string;
}
export interface TestResult {
  name: string;
  h0: string;
  h1: string;
  statistic: number | null;
  critical: string;
  p_value: string | null;
  decision: string;
  effect_label: string;
  effect_value: number | null;
}
export interface Table {
  title: string;
  columns: string[];
  rows: Cell[][];
}
export interface CodeBlock {
  label: string;
  file: string;
  start_line: number;
  code: string;
}
export interface ModuleData {
  id: number;
  title: string;
  syllabus_module: string;
  question: string;
  code: CodeBlock[];
  console: string[];
  tests: TestResult[];
  tables: Table[];
  charts: Chart[];
  takeaway: string;
}
export interface Interval {
  estimate: number;
  lower: number;
  upper: number;
}
export interface ModuleSummary {
  id: number;
  title: string;
  syllabus_module: string;
  question: string;
  takeaway: string;
}
export interface Meta {
  r_version: string;
  r_version_short: string;
  packages: Record<string, string>;
  citation: string;
  dataset: string;
  snapshot_date: string;
  modules: ModuleSummary[];
  headline: {
    features: string[];
    prior: number;
    threshold: number;
    auc: number;
    sensitivity: Interval;
    specificity: Interval;
    precision: Interval;
    f1: Interval;
    precision_1pct_deployed: number;
    precision_1pct_prior: number;
    sensitivity_drop_cross_corpus: number;
  };
}
export interface Pipeline {
  files: string[];
  steps: { step: string; rows: number }[];
  by_class: Record<string, number>;
  by_source_class: { source: string; class: string; rows: number }[];
  split: { train: number; test: number; by_class: { class: string; set: string; rows: number }[] };
}

export type Validated<T> = { ok: true; value: T } | { ok: false; error: string };

// ---- small checking helpers ----
type Obj = Record<string, unknown>;
const isObj = (x: unknown): x is Obj => x !== null && typeof x === "object" && !Array.isArray(x);
const isNum = (x: unknown): x is number => typeof x === "number" && Number.isFinite(x);
const isStr = (x: unknown): x is string => typeof x === "string";
// R's jsonlite unboxes length-1 vectors, so a lone string may stand for a one-item array.
const asArray = (x: unknown): unknown[] | null =>
  Array.isArray(x) ? x : x === undefined || x === null ? null : [x];

class Invalid extends Error {}
function need(cond: unknown, msg: string): asserts cond {
  if (!cond) throw new Invalid(msg);
}
function strings(x: unknown, what: string): string[] {
  const a = asArray(x);
  need(a !== null && a.every(isStr), what + " must be a list of strings");
  return a as string[];
}
function list(x: unknown, what: string): unknown[] {
  if (isObj(x) && Object.keys(x).length === 0) return [];
  const a = asArray(x);
  need(a !== null, what + " must be a list");
  return a;
}
const numOrNull = (x: unknown) => (isNum(x) ? x : null);
const strOrNull = (x: unknown) => (isStr(x) ? x : null);
function wrap<T>(fn: () => T): Validated<T> {
  try {
    return { ok: true, value: fn() };
  } catch (err) {
    if (err instanceof Invalid) return { ok: false, error: err.message };
    throw err;
  }
}

function checkPoint(p: unknown, where: string): Point {
  need(isObj(p), where + ": point must be an object");
  need(isNum(p.x) || isStr(p.x), where + ": point.x must be a number or string");
  need(isNum(p.y) || isStr(p.y), where + ": point.y must be a number or string");
  const point: Point = { x: p.x, y: p.y };
  if (isNum(p.value)) point.value = p.value;
  return point;
}

function checkChart(c: unknown, i: number): Chart {
  const where = "chart " + i;
  need(isObj(c), where + " must be an object");
  need(isStr(c.id) && isStr(c.title), where + " needs id and title");
  need(CHART_TYPES.includes(c.type as ChartType), where + " has unknown type");
  const series = list(c.series, where + " series").map((s, j) => {
    need(isObj(s) && isStr(s.name), where + ": series " + j + " needs a name");
    const points = list(s.points, where + " points").map((p) => checkPoint(p, where));
    need(points.length <= 500, where + ": more than 500 points");
    return { name: s.name, class: strOrNull(s.class), points };
  });
  return {
    id: c.id,
    type: c.type as ChartType,
    title: c.title,
    x_label: isStr(c.x_label) ? c.x_label : "",
    y_label: isStr(c.y_label) ? c.y_label : "",
    series,
    note: isStr(c.note) ? c.note : ""
  };
}

function checkTest(t: unknown, i: number): TestResult {
  need(isObj(t) && isStr(t.name) && isStr(t.decision), "test " + i + " needs name and decision");
  return {
    name: t.name,
    h0: isStr(t.h0) ? t.h0 : "",
    h1: isStr(t.h1) ? t.h1 : "",
    statistic: numOrNull(t.statistic),
    critical: isStr(t.critical) ? t.critical : isNum(t.critical) ? String(t.critical) : "n/a",
    p_value: strOrNull(t.p_value),
    decision: t.decision,
    effect_label: isStr(t.effect_label) ? t.effect_label : "",
    effect_value: numOrNull(t.effect_value)
  };
}

function checkTable(t: unknown, i: number): Table {
  need(isObj(t) && isStr(t.title), "table " + i + " needs a title");
  const columns = strings(t.columns, "table " + i + " columns");
  const rows = list(t.rows, "table " + i + " rows").map((r) => {
    const cells = asArray(r) ?? [];
    need(cells.length === columns.length, "table " + i + ": row length does not match columns");
    return cells.map((v) =>
      v === null || ["string", "number", "boolean"].includes(typeof v) ? v : null
    ) as Cell[];
  });
  return { title: t.title, columns, rows };
}

export function validateModuleData(x: unknown): Validated<ModuleData> {
  return wrap(() => {
    need(isObj(x), "module file must be an object");
    need(isNum(x.id) && isStr(x.title) && isStr(x.question), "module needs id, title, question");
    const code = list(x.code, "code").map((b, i) => {
      need(isObj(b) && isStr(b.label) && isStr(b.file) && isStr(b.code), "code block " + i + " is invalid");
      need(isNum(b.start_line), "code block " + i + " needs start_line");
      return { label: b.label, file: b.file, start_line: b.start_line, code: b.code };
    });
    return {
      id: x.id,
      title: x.title,
      syllabus_module: isStr(x.syllabus_module) ? x.syllabus_module : "",
      question: x.question,
      code,
      console: x.console === undefined ? [] : strings(x.console, "console"),
      tests: list(x.tests, "tests").map(checkTest),
      tables: list(x.tables, "tables").map(checkTable),
      charts: list(x.charts, "charts").map(checkChart),
      takeaway: isStr(x.takeaway) ? x.takeaway : ""
    };
  });
}

function checkInterval(x: unknown, what: string): Interval {
  need(
    isObj(x) && isNum(x.estimate) && isNum(x.lower) && isNum(x.upper),
    what + " must have estimate, lower, upper"
  );
  return { estimate: x.estimate, lower: x.lower, upper: x.upper };
}

export function validateMeta(x: unknown): Validated<Meta> {
  return wrap(() => {
    need(isObj(x), "meta must be an object");
    need(isStr(x.r_version) && isStr(x.citation), "meta needs r_version and citation");
    const h = x.headline;
    need(isObj(h), "meta needs headline metrics");
    need(isNum(h.prior) && isNum(h.auc) && isNum(h.precision_1pct_deployed), "headline numbers missing");
    const modules = list(x.modules, "modules").map((m, i) => {
      need(isObj(m) && isNum(m.id) && isStr(m.title), "module summary " + i + " is invalid");
      return {
        id: m.id,
        title: m.title,
        syllabus_module: isStr(m.syllabus_module) ? m.syllabus_module : "",
        question: isStr(m.question) ? m.question : "",
        takeaway: isStr(m.takeaway) ? m.takeaway : ""
      };
    });
    const packages: Record<string, string> = {};
    if (isObj(x.packages)) for (const [k, v] of Object.entries(x.packages)) if (isStr(v)) packages[k] = v;
    return {
      r_version: x.r_version,
      r_version_short: isStr(x.r_version_short) ? x.r_version_short : x.r_version,
      packages,
      citation: x.citation,
      dataset: isStr(x.dataset) ? x.dataset : "",
      snapshot_date: isStr(x.snapshot_date) ? x.snapshot_date : "",
      modules,
      headline: {
        features: strings(h.features, "headline features"),
        prior: h.prior,
        threshold: isNum(h.threshold) ? h.threshold : 0.5,
        auc: h.auc,
        sensitivity: checkInterval(h.sensitivity, "sensitivity"),
        specificity: checkInterval(h.specificity, "specificity"),
        precision: checkInterval(h.precision, "precision"),
        f1: checkInterval(h.f1, "f1"),
        precision_1pct_deployed: h.precision_1pct_deployed,
        precision_1pct_prior: isNum(h.precision_1pct_prior) ? h.precision_1pct_prior : NaN,
        sensitivity_drop_cross_corpus: isNum(h.sensitivity_drop_cross_corpus)
          ? h.sensitivity_drop_cross_corpus
          : NaN
      }
    };
  });
}

export function validatePipeline(x: unknown): Validated<Pipeline> {
  return wrap(() => {
    need(isObj(x), "pipeline must be an object");
    const steps = list(x.steps, "steps").map((s, i) => {
      need(isObj(s) && isStr(s.step) && isNum(s.rows), "step " + i + " is invalid");
      return { step: s.step, rows: s.rows };
    });
    need(steps.length >= 1, "pipeline needs at least one step");
    need(isObj(x.by_class), "pipeline needs by_class counts");
    const byClass: Record<string, number> = {};
    for (const [k, v] of Object.entries(x.by_class)) {
      need(isNum(v), "by_class." + k + " must be a number");
      byClass[k] = v;
    }
    const split = x.split;
    need(isObj(split) && isNum(split.train) && isNum(split.test), "pipeline needs train/test sizes");
    const rows = (v: unknown, what: string) =>
      list(v, what).map((r) => {
        need(isObj(r) && isNum(r.rows), what + " row is invalid");
        return r;
      });
    return {
      files: x.files === undefined ? [] : strings(x.files, "files"),
      steps,
      by_class: byClass,
      by_source_class: rows(x.by_source_class, "by_source_class").map((r) => ({
        source: String(r.source),
        class: String(r.class),
        rows: r.rows as number
      })),
      split: {
        train: split.train,
        test: split.test,
        by_class: rows(split.by_class, "split.by_class").map((r) => ({
          class: String(r.class),
          set: String(r.set),
          rows: r.rows as number
        }))
      }
    };
  });
}

export function validateModelJson(x: unknown): Validated<Model> {
  const problem = validateModel(x);
  return problem === null ? { ok: true, value: x as Model } : { ok: false, error: problem };
}

// ---- fetching with a per-URL cache ----
const ALLOWED_URL = /^\.\/(model\.json|data\/[a-z0-9_]+\.json)$/;
const cache = new Map<string, Promise<Validated<unknown>>>();

export function loadJson<T>(url: string, validate: (x: unknown) => Validated<T>): Promise<Validated<T>> {
  if (!ALLOWED_URL.test(url)) return Promise.resolve({ ok: false, error: "blocked URL " + url });
  let p = cache.get(url);
  if (!p) {
    p = fetch(url, { cache: "no-cache", credentials: "omit" })
      .then(async (res) => {
        if (!res.ok) return { ok: false as const, error: "HTTP " + res.status + " for " + url };
        return validate(await res.json()) as Validated<unknown>;
      })
      .catch(() => ({ ok: false as const, error: "Could not reach " + url }));
    cache.set(url, p);
    // Retry next time if this load failed.
    p.then((r) => {
      if (!r.ok) cache.delete(url);
    });
  }
  return p as Promise<Validated<T>>;
}

export type Resource<T> =
  { status: "loading" } | { status: "ready"; data: T } | { status: "error"; error: string };

export function useJson<T>(url: string, validate: (x: unknown) => Validated<T>): Resource<T> {
  const [state, setState] = useState<{ url: string; res: Resource<T> }>({
    url,
    res: { status: "loading" }
  });
  useEffect(() => {
    let active = true;
    loadJson(url, validate).then((r) => {
      if (!active) return;
      setState({ url, res: r.ok ? { status: "ready", data: r.value } : { status: "error", error: r.error } });
    });
    return () => {
      active = false;
    };
  }, [url, validate]);
  return state.url === url ? state.res : { status: "loading" };
}

export const useMeta = () => useJson("./data/meta.json", validateMeta);
export const usePipeline = () => useJson("./data/pipeline.json", validatePipeline);
export const useModel = () => useJson("./model.json", validateModelJson);
export const useModule = (id: number) => useJson("./data/m" + id + ".json", validateModuleData);
