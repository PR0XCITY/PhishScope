import { formatPercent } from "../lib/text";

function fmt(v: number): string {
  if (v === 0) return "0";
  if (Math.abs(v) < 0.001) return v.toExponential(2);
  return v.toFixed(4);
}

interface Props {
  prior: number;
  l1: number;
  l0: number;
  posterior: number;
}

// Bayes rule with the current numbers plugged in.
export function BayesFormula({ prior, l1, l0, posterior }: Props) {
  const num = prior * l1;
  const den = num + (1 - prior) * l0;
  return (
    <figure className="rounded-lg border border-border bg-surface-2 p-4">
      <figcaption className="text-xs text-muted">Bayes rule with your numbers</figcaption>
      <div className="num mt-2 space-y-1.5 overflow-x-auto text-sm leading-relaxed">
        <p className="whitespace-nowrap">
          P(phish | x) = <span className="text-focus">π</span> L1 / (<span className="text-focus">π</span> L1
          + (1 - <span className="text-focus">π</span>) L0)
        </p>
        <p className="whitespace-nowrap">
          = (<span className="text-focus">{fmt(prior)}</span> x {fmt(l1)}) / (
          <span className="text-focus">{fmt(prior)}</span> x {fmt(l1)} + {fmt(1 - prior)} x {fmt(l0)})
        </p>
        <p className="whitespace-nowrap">
          = {fmt(num)} / {fmt(den)} = <span className="font-medium text-fg">{formatPercent(posterior)}</span>
        </p>
      </div>
      <p className="mt-3 text-xs text-muted">
        L1 and L0 multiply P(rule state | class) over the six rules, assuming the rules are independent given
        the class (naive Bayes).
      </p>
    </figure>
  );
}
