import type { TestResult } from "../lib/data";
import { formatNumber } from "../lib/text";

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-baseline justify-between gap-3 py-1">
      <dt className="text-xs text-muted">{label}</dt>
      <dd className="num text-right text-sm">{value}</dd>
    </div>
  );
}

export function TestCard({ test }: { test: TestResult }) {
  const reject = test.decision.toLowerCase().startsWith("reject");
  return (
    <article className="card flex flex-col p-4">
      <div className="flex items-start justify-between gap-3">
        <h4 className="text-sm font-medium leading-snug">{test.name}</h4>
        <span
          className={
            "num shrink-0 rounded-full border px-2 py-0.5 text-xs " +
            (reject ? "border-phish/50 bg-phish/10 text-phish" : "border-border text-muted")
          }
        >
          {reject ? "Reject H0" : "Fail to reject"}
        </span>
      </div>
      <p className="mt-2 text-xs text-muted">
        <span className="font-medium text-fg">H0:</span> {test.h0}
      </p>
      <p className="mt-0.5 text-xs text-muted">
        <span className="font-medium text-fg">H1:</span> {test.h1}
      </p>
      <dl className="mt-3 divide-y divide-border border-t border-border">
        <Row label="Statistic" value={test.statistic === null ? "n/a" : formatNumber(test.statistic)} />
        <Row label="Critical value (alpha 0.05)" value={test.critical} />
        <Row label="p-value" value={test.p_value ?? "n/a"} />
        <Row
          label={"Effect size" + (test.effect_label ? " (" + test.effect_label + ")" : "")}
          value={test.effect_value === null ? "n/a" : formatNumber(test.effect_value)}
        />
      </dl>
    </article>
  );
}
