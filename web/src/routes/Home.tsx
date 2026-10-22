import { FlaskConical, ScanSearch } from "lucide-react";
import { Link } from "react-router";
import { CountUp } from "../components/CountUp";
import { ErrorState, Skeleton } from "../components/ui";
import { useMeta, usePipeline, type Meta, type Pipeline } from "../lib/data";
import { formatPercent } from "../lib/text";

function StatCard({
  label,
  value,
  format,
  detail
}: {
  label: string;
  value: number;
  format: (v: number) => string;
  detail: string;
}) {
  return (
    <div className="card p-5">
      <p className="text-sm text-muted">{label}</p>
      <p className="num mt-2 text-3xl font-medium tracking-tight">
        <CountUp value={value} format={format} />
      </p>
      <p className="num mt-1 text-xs text-muted">{detail}</p>
    </div>
  );
}

function Stats({ meta, pipeline }: { meta: Meta; pipeline: Pipeline }) {
  const h = meta.headline;
  const pct = (v: number) => (100 * v).toFixed(1) + "%";
  const ci = (i: { lower: number; upper: number }) =>
    "95% CI " + formatPercent(i.lower) + " to " + formatPercent(i.upper);
  const emails = pipeline.steps[pipeline.steps.length - 1].rows;
  return (
    <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
      <StatCard
        label="Emails analyzed"
        value={emails}
        format={(v) => Math.round(v).toLocaleString("en-US")}
        detail={"from " + pipeline.files.length + " public corpora"}
      />
      <StatCard label="Sensitivity" value={h.sensitivity.estimate} format={pct} detail={ci(h.sensitivity)} />
      <StatCard label="Specificity" value={h.specificity.estimate} format={pct} detail={ci(h.specificity)} />
      <StatCard
        label="Precision at 1% prevalence"
        value={h.precision_1pct_deployed}
        format={pct}
        detail="most alerts are false alarms"
      />
    </div>
  );
}

export default function Home() {
  const meta = useMeta();
  const pipeline = usePipeline();
  return (
    <div className="space-y-14">
      <section className="relative -mx-4 -mt-8 px-4 pb-4 pt-16 sm:-mx-6 sm:px-6">
        <div aria-hidden="true" className="hero-glow pointer-events-none absolute inset-0" />
        <div className="relative max-w-3xl">
          <p className="num text-sm text-focus">Probability and Statistics, Modules 1 to 7</p>
          <h1 className="mt-3 text-3xl font-semibold tracking-tight sm:text-5xl">
            Can Statistics Catch a Phish?
          </h1>
          <p className="mt-4 text-base text-muted sm:text-xl">
            Classical statistics in R, applied to 80,000 real emails, then turned into a transparent phishing
            score that runs entirely in your browser.
          </p>
          <div className="mt-8 flex flex-wrap gap-3">
            <Link
              to="/check"
              className="inline-flex items-center gap-2 rounded-lg bg-focus px-4 py-2.5 font-medium text-bg transition-opacity duration-150 hover:opacity-90"
            >
              <ScanSearch aria-hidden="true" className="size-4" />
              Check an email
            </Link>
            <Link
              to="/analysis/0"
              className="inline-flex items-center gap-2 rounded-lg border border-border bg-surface px-4 py-2.5 font-medium transition-colors duration-150 hover:border-focus/50"
            >
              <FlaskConical aria-hidden="true" className="size-4" />
              Explore the analysis
            </Link>
          </div>
        </div>
      </section>

      <section aria-label="Headline results">
        {meta.status === "error" || pipeline.status === "error" ? (
          <ErrorState
            title="Results could not be loaded"
            detail={meta.status === "error" ? meta.error : pipeline.status === "error" ? pipeline.error : ""}
          />
        ) : meta.status === "ready" && pipeline.status === "ready" ? (
          <Stats meta={meta.data} pipeline={pipeline.data} />
        ) : (
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {[0, 1, 2, 3].map((i) => (
              <Skeleton key={i} className="h-32" />
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
