// One renderer for every chart type exported by R (analysis/08_export_web.R).
import {
  Area,
  Bar,
  BarChart,
  CartesianGrid,
  ComposedChart,
  Legend,
  Line,
  ReferenceLine,
  Scatter,
  ScatterChart,
  Tooltip,
  XAxis,
  YAxis
} from "recharts";
import { useLayoutEffect, useRef, useState } from "react";
import type { Chart, Series } from "../lib/data";
import { classColor, seriesPalette, usePalette, type Palette } from "../lib/colors";
import { formatNumber } from "../lib/text";
import { Heatmap } from "./Heatmap";

const DASHES = ["", "6 3", "2 3", "8 3 2 3", "1 2"];
const CLASS_NAMES = new Set(["legitimate", "phishing", "spam", "observed"]);

function seriesColors(p: Palette, series: Series[]): string[] {
  const classes = series.map((s) => s.class);
  const oneColorPerClass =
    classes.every((c) => classColor(p, c) !== null) && new Set(classes).size === classes.length;
  const palette = seriesPalette(p);
  return series.map((s, i) =>
    oneColorPerClass ? (classColor(p, s.class) as string) : palette[i % palette.length]
  );
}

const tick = (p: Palette) => ({ fill: p.muted, fontSize: 12, fontFamily: "IBM Plex Mono, monospace" });
const fmtTick = (v: unknown) => (typeof v === "number" ? formatNumber(v) : String(v));

function axes(p: Palette, chart: Chart, numericX: boolean, domainX?: [number, number], yKey?: string) {
  return [
    <CartesianGrid key="g" stroke={p.border} strokeDasharray="3 3" />,
    <XAxis
      key="x"
      dataKey="x"
      type={numericX ? "number" : "category"}
      domain={domainX ?? (numericX ? ["auto", "auto"] : undefined)}
      allowDuplicatedCategory={false}
      tick={tick(p)}
      tickFormatter={fmtTick}
      stroke={p.border}
      label={{ value: chart.x_label, position: "insideBottom", offset: -4, fill: p.muted, fontSize: 12 }}
      height={44}
    />,
    <YAxis
      key="y"
      dataKey={yKey}
      type="number"
      tick={tick(p)}
      tickFormatter={fmtTick}
      stroke={p.border}
      width={64}
      label={{
        value: chart.y_label,
        angle: -90,
        position: "insideLeft",
        fill: p.muted,
        fontSize: 12,
        dy: 40
      }}
    />,
    <Tooltip
      key="t"
      formatter={(v: unknown) => (typeof v === "number" ? formatNumber(v) : String(v))}
      labelFormatter={(l: unknown) => chart.x_label + ": " + fmtTick(l)}
      contentStyle={{
        background: p.surface2,
        border: "1px solid " + p.border,
        borderRadius: 8,
        color: p.text,
        fontFamily: "IBM Plex Mono, monospace",
        fontSize: 12
      }}
      cursor={{ stroke: p.muted, strokeDasharray: "3 3" }}
    />,
    <Legend key="l" wrapperStyle={{ fontSize: 12, color: p.muted, paddingTop: 8 }} />
  ];
}

// Merge series sharing categorical x values into one row per x for grouped bars.
function mergeRows(series: Series[]): Record<string, number | string>[] {
  const rows = new Map<string, Record<string, number | string>>();
  for (const s of series) {
    for (const pt of s.points) {
      const key = String(pt.x);
      const row = rows.get(key) ?? { x: pt.x };
      row[s.name] = Number(pt.y);
      rows.set(key, row);
    }
  }
  return [...rows.values()];
}

const numeric = (series: Series[]) => series.every((s) => s.points.every((pt) => typeof pt.x === "number"));
const pts = (s: Series) => s.points.map((pt) => ({ x: pt.x, y: Number(pt.y) }));

interface PlotProps {
  chart: Chart;
  p: Palette;
  width: number;
  height: number;
}

function Plot({ chart, p, width, height }: PlotProps) {
  const colors = seriesColors(p, chart.series);
  const isNum = numeric(chart.series);

  if (chart.type === "bar") {
    return (
      <BarChart
        width={width}
        height={height}
        data={mergeRows(chart.series)}
        margin={{ top: 8, right: 16, bottom: 8, left: 8 }}
      >
        {axes(p, chart, false)}
        {chart.series.map((s, i) => (
          <Bar
            key={s.name}
            dataKey={s.name}
            fill={colors[i]}
            radius={[3, 3, 0, 0]}
            isAnimationActive={false}
          />
        ))}
      </BarChart>
    );
  }

  if (chart.type === "scatter" || chart.type === "qq") {
    const all = chart.series.flatMap((s) => s.points.flatMap((pt) => [Number(pt.x), Number(pt.y)]));
    const lo = Math.min(...all);
    const hi = Math.max(...all);
    return (
      <ScatterChart width={width} height={height} margin={{ top: 8, right: 16, bottom: 8, left: 8 }}>
        {axes(p, chart, true, undefined, "y")}
        {chart.type === "qq" ? (
          <ReferenceLine
            segment={[
              { x: lo, y: lo },
              { x: hi, y: hi }
            ]}
            stroke={p.muted}
            strokeDasharray="4 4"
            ifOverflow="extendDomain"
          />
        ) : null}
        {chart.series.map((s, i) => (
          <Scatter
            key={s.name}
            name={s.name}
            data={pts(s)}
            fill={colors[i]}
            fillOpacity={0.7}
            shape="circle"
            isAnimationActive={false}
            legendType="circle"
          />
        ))}
      </ScatterChart>
    );
  }

  // histogram, line, roc, survival: numeric x with one data array per series.
  const domainX: [number, number] | undefined = chart.type === "roc" ? [0, 1] : undefined;
  return (
    <ComposedChart width={width} height={height} margin={{ top: 8, right: 16, bottom: 8, left: 8 }}>
      {axes(p, chart, isNum, domainX)}
      {chart.series.map((s, i) => {
        const data = pts(s);
        if (chart.type === "histogram" && CLASS_NAMES.has(s.name)) {
          return (
            <Area
              key={s.name}
              name={s.name}
              data={data}
              dataKey="y"
              type="step"
              stroke={colors[i]}
              fill={colors[i]}
              fillOpacity={0.18}
              strokeWidth={1.5}
              isAnimationActive={false}
            />
          );
        }
        const chance = chart.type === "roc" && s.name === "chance";
        return (
          <Line
            key={s.name}
            name={s.name}
            data={data}
            dataKey="y"
            type={chart.type === "survival" ? "stepAfter" : "linear"}
            stroke={chance ? p.muted : colors[i]}
            strokeWidth={chance ? 1 : 2}
            strokeDasharray={chance ? "4 4" : DASHES[i % DASHES.length]}
            dot={chart.type === "roc" && !chance ? { r: 2 } : false}
            isAnimationActive={false}
          />
        );
      })}
    </ComposedChart>
  );
}

// Width measured right after layout (and on resize), so charts never render wider than their card.
function useWidth<T extends HTMLElement>() {
  const ref = useRef<T>(null);
  const [width, setWidth] = useState(0);
  useLayoutEffect(() => {
    const el = ref.current;
    if (!el) return;
    const measure = () => setWidth(Math.floor(el.getBoundingClientRect().width));
    measure();
    if (typeof ResizeObserver === "undefined") return;
    const ro = new ResizeObserver(measure);
    ro.observe(el);
    return () => ro.disconnect();
  }, []);
  return [ref, width] as const;
}

const CHART_HEIGHT = 288;

export function ChartRenderer({ chart }: { chart: Chart }) {
  const p = usePalette();
  const [ref, width] = useWidth<HTMLDivElement>();
  return (
    <figure className="card min-w-0 p-4">
      <figcaption className="mb-3">
        <p className="text-sm font-medium">{chart.title}</p>
        {chart.note ? <p className="mt-0.5 text-xs text-muted">{chart.note}</p> : null}
      </figcaption>
      {chart.type === "heatmap" ? (
        <Heatmap chart={chart} />
      ) : (
        <div
          ref={ref}
          className="h-72 w-full min-w-0"
          role="img"
          aria-label={chart.title + ". " + chart.series.map((s) => s.name).join(", ")}
        >
          {width > 0 ? <Plot chart={chart} p={p} width={width} height={CHART_HEIGHT} /> : null}
        </div>
      )}
    </figure>
  );
}
