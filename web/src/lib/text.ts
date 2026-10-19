// Input limits and number formatting.

export const MAX_BODY = 20000;
export const MAX_SUBJECT = 500;

// Cut to max UTF-16 units without splitting a surrogate pair.
export function clampText(s: unknown, max: number): string {
  const str = typeof s === "string" ? s : "";
  if (str.length <= max) return str;
  const code = str.charCodeAt(max - 1);
  return str.slice(0, code >= 0xd800 && code <= 0xdbff ? max - 1 : max);
}

export function formatPercent(p: number, digits = 1): string {
  if (!Number.isFinite(p)) return "n/a";
  if (p > 0 && p < 0.001) return "<0.1%";
  if (p < 1 && p > 0.999) return ">99.9%";
  return (100 * p).toFixed(digits) + "%";
}

export function formatRatio(r: number): string {
  return (r >= 10 ? r.toFixed(0) : r.toFixed(2)) + "x";
}

// Compact numeric display: integers with separators, small values in scientific notation.
export function formatNumber(v: number): string {
  if (!Number.isFinite(v)) return "n/a";
  const a = Math.abs(v);
  if (a === 0) return "0";
  if (Number.isInteger(v) && a < 1e9) return v.toLocaleString("en-US");
  if (a >= 1000) return v.toLocaleString("en-US", { maximumFractionDigits: 1 });
  if (a < 0.001) return v.toExponential(2);
  return Number(v.toPrecision(4)).toString();
}

export function formatCell(v: unknown): string {
  if (v === null || v === undefined) return "n/a";
  if (typeof v === "number") return formatNumber(v);
  if (typeof v === "boolean") return v ? "yes" : "no";
  return String(v);
}
