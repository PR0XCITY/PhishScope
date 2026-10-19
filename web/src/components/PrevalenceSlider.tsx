import { useId } from "react";
import { priorToSlider, sliderToPrior, SLIDER_STEPS } from "../lib/score";
import { formatPercent } from "../lib/text";

interface Props {
  prior: number;
  onChange: (p: number) => void;
}

const MARKS = [0.001, 0.01, 0.1, 0.5];

export function PrevalenceSlider({ prior, onChange }: Props) {
  const id = useId();
  return (
    <div>
      <div className="flex items-baseline justify-between gap-3">
        <label htmlFor={id} className="text-sm font-medium">
          Assumed phishing prevalence
        </label>
        <output htmlFor={id} className="num text-sm text-focus">
          {formatPercent(prior, prior < 0.01 ? 2 : 1)}
        </output>
      </div>
      <input
        id={id}
        type="range"
        min={0}
        max={SLIDER_STEPS}
        step={1}
        value={priorToSlider(prior)}
        onChange={(e) => onChange(sliderToPrior(Number(e.target.value)))}
        aria-valuetext={formatPercent(prior, 2) + " of emails are phishing"}
        className="mt-3 w-full accent-[var(--c-focus)]"
      />
      <div aria-hidden="true" className="num relative mt-1 h-4 text-xs text-muted">
        {MARKS.map((m) => (
          <span
            key={m}
            className="absolute -translate-x-1/2 first:translate-x-0 last:-translate-x-full"
            style={{ left: (priorToSlider(m) / SLIDER_STEPS) * 100 + "%" }}
          >
            {formatPercent(m, m < 0.01 ? 1 : 0)}
          </span>
        ))}
      </div>
      <p className="mt-2 text-xs text-muted">
        Log scale. A typical inbox is closer to 1% than to the training mix.
      </p>
    </div>
  );
}
