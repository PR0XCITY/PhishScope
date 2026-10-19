import type { Chart } from "../lib/data";
import { usePalette } from "../lib/colors";

// Correlation matrix as an accessible table of colored cells with the value printed in each.
export function Heatmap({ chart }: { chart: Chart }) {
  const p = usePalette();
  const points = chart.series[0]?.points ?? [];
  const cols = [...new Set(points.map((pt) => String(pt.x)))];
  const rows = [...new Set(points.map((pt) => String(pt.y)))];
  const value = new Map(points.map((pt) => [String(pt.x) + "|" + String(pt.y), pt.value ?? NaN]));
  return (
    <div className="overflow-x-auto" tabIndex={0} aria-label={chart.title}>
      <table className="num border-separate border-spacing-0.5 text-xs">
        <thead>
          <tr>
            <th scope="col" className="sr-only">
              Feature
            </th>
            {cols.map((c) => (
              <th key={c} scope="col" className="h-24 min-w-11 align-bottom font-normal text-muted">
                <span className="inline-block origin-bottom-left translate-x-5 -rotate-45 whitespace-nowrap">
                  {c}
                </span>
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r}>
              <th scope="row" className="whitespace-nowrap pr-2 text-right font-normal text-muted">
                {r}
              </th>
              {cols.map((c) => {
                const v = value.get(c + "|" + r) ?? NaN;
                const color = v >= 0 ? p.phish : p.focus;
                const strength = Number.isFinite(v) ? Math.round(Math.min(Math.abs(v), 1) * 75) : 0;
                return (
                  <td
                    key={c}
                    className="h-11 min-w-11 rounded text-center"
                    style={{ background: `color-mix(in srgb, ${color} ${strength}%, transparent)` }}
                  >
                    {Number.isFinite(v) ? v.toFixed(2) : ""}
                  </td>
                );
              })}
            </tr>
          ))}
        </tbody>
      </table>
      <p className="mt-2 text-xs text-muted">
        Red cells are positive, blue cells negative; the number is the coefficient.
      </p>
    </div>
  );
}
