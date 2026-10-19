import { ErrorState, LoadingBlock } from "../components/ui";
import { usePalette } from "../lib/colors";
import { useMeta, usePipeline, type Meta, type Pipeline as PipelineData } from "../lib/data";

interface FlowNode {
  title: string;
  detail: string;
  href: string;
}

function nodesFor(pipeline: PipelineData, meta: Meta | null): FlowNode[] {
  const raw = pipeline.steps[0]?.rows ?? 0;
  const kept = pipeline.steps[pipeline.steps.length - 1]?.rows ?? 0;
  const n = (v: number) => v.toLocaleString("en-US");
  const rules = meta ? meta.headline.features.length : 6;
  return [
    { title: "Raw CSVs", detail: n(raw) + " rows", href: "#/analysis/0" },
    { title: "Clean & dedup", detail: n(kept) + " emails", href: "#/analysis/0" },
    { title: "Features", detail: "18 per email", href: "#/analysis/0" },
    { title: "Modules 1 to 7", detail: n(pipeline.split.train) + " train", href: "#/analysis/1" },
    { title: "PhishScore", detail: n(pipeline.split.test) + " test", href: "#/analysis/8" },
    { title: "model.json", detail: rules + " rules", href: "#/analysis/8" },
    { title: "Your browser", detail: "nothing sent", href: "#/check" }
  ];
}

const W = 150;
const H = 74;
const GAP = 34;

function Flow({ nodes, vertical }: { nodes: FlowNode[]; vertical: boolean }) {
  const p = usePalette();
  const step = (vertical ? H : W) + GAP;
  const width = vertical ? 240 : nodes.length * W + (nodes.length - 1) * GAP;
  const height = vertical ? nodes.length * H + (nodes.length - 1) * GAP : H;
  const nodeX = (i: number) => (vertical ? (240 - W - 30) / 2 : i * step);
  const nodeY = (i: number) => (vertical ? i * step : 0);
  return (
    <svg
      viewBox={`-2 -2 ${width + 4} ${height + 4}`}
      className={vertical ? "mx-auto w-full max-w-xs" : "w-full"}
      role="group"
      aria-label="Data pipeline from raw CSVs to your browser"
    >
      <defs>
        <marker
          id={"arrow-" + vertical}
          viewBox="0 0 8 8"
          refX="7"
          refY="4"
          markerWidth="8"
          markerHeight="8"
          orient="auto"
        >
          <path d="M0,0 L8,4 L0,8 z" fill={p.muted} />
        </marker>
      </defs>
      {nodes.slice(0, -1).map((_, i) => {
        const x1 = vertical ? nodeX(i) + W / 2 : nodeX(i) + W;
        const y1 = vertical ? nodeY(i) + H : H / 2;
        const x2 = vertical ? x1 : nodeX(i + 1) - 2;
        const y2 = vertical ? nodeY(i + 1) - 2 : H / 2;
        return (
          <line
            key={i}
            x1={x1}
            y1={y1}
            x2={x2}
            y2={y2}
            stroke={p.muted}
            strokeWidth="1.5"
            markerEnd={`url(#arrow-${vertical})`}
          />
        );
      })}
      {nodes.map((node, i) => (
        <a key={node.title} href={node.href} aria-label={node.title + ", " + node.detail}>
          <g className="group">
            <rect
              x={nodeX(i)}
              y={nodeY(i)}
              width={W}
              height={H}
              rx="12"
              fill={i === nodes.length - 1 ? p.surface2 : p.surface}
              stroke={i === nodes.length - 1 ? p.legit : p.border}
              className="transition-[stroke] duration-150 group-hover:stroke-[var(--c-focus)] group-focus:stroke-[var(--c-focus)]"
            />
            <text
              x={nodeX(i) + W / 2}
              y={nodeY(i) + 31}
              textAnchor="middle"
              fill={p.text}
              fontSize="14"
              fontWeight="600"
            >
              {node.title}
            </text>
            <text
              x={nodeX(i) + W / 2}
              y={nodeY(i) + 52}
              textAnchor="middle"
              fill={p.muted}
              fontSize="12"
              fontFamily="IBM Plex Mono, monospace"
            >
              {node.detail}
            </text>
          </g>
        </a>
      ))}
    </svg>
  );
}

export default function Pipeline() {
  const pipeline = usePipeline();
  const meta = useMeta();
  return (
    <div className="space-y-8">
      <header className="max-w-2xl">
        <h1 className="text-3xl font-semibold tracking-tight">Pipeline</h1>
        <p className="mt-2 text-muted">
          From six public corpora to a score in your browser. R does the statistics; the site only reads the
          JSON it exported. Select a step to open the matching module.
        </p>
      </header>
      {pipeline.status === "loading" ? (
        <LoadingBlock label="Loading pipeline counts" />
      ) : pipeline.status === "error" ? (
        <ErrorState title="Pipeline counts could not be loaded" detail={pipeline.error} />
      ) : (
        <>
          <div className="card p-6">
            <div className="hidden xl:block">
              <Flow
                nodes={nodesFor(pipeline.data, meta.status === "ready" ? meta.data : null)}
                vertical={false}
              />
            </div>
            <div className="xl:hidden">
              <Flow nodes={nodesFor(pipeline.data, meta.status === "ready" ? meta.data : null)} vertical />
            </div>
          </div>
          <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
            <div className="card p-5">
              <h2 className="text-sm font-medium">Cleaning steps</h2>
              <ol className="mt-3 divide-y divide-border">
                {pipeline.data.steps.map((s) => (
                  <li key={s.step} className="flex justify-between gap-4 py-2 text-sm">
                    <span className="text-muted">{s.step}</span>
                    <span className="num">{s.rows.toLocaleString("en-US")}</span>
                  </li>
                ))}
              </ol>
            </div>
            <div className="card p-5">
              <h2 className="text-sm font-medium">Emails by class</h2>
              <ol className="mt-3 divide-y divide-border">
                {Object.entries(pipeline.data.by_class).map(([cls, rows]) => (
                  <li key={cls} className="flex justify-between gap-4 py-2 text-sm">
                    <span className="text-muted">{cls}</span>
                    <span className="num">{rows.toLocaleString("en-US")}</span>
                  </li>
                ))}
                <li className="flex justify-between gap-4 py-2 text-sm">
                  <span className="text-muted">train / test split</span>
                  <span className="num">
                    {pipeline.data.split.train.toLocaleString("en-US")} /{" "}
                    {pipeline.data.split.test.toLocaleString("en-US")}
                  </span>
                </li>
              </ol>
            </div>
          </div>
        </>
      )}
    </div>
  );
}
