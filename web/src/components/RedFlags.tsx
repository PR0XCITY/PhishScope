import type { Features } from "../lib/features";
import { likelihoodRatios, type Model } from "../lib/score";
import { formatRatio } from "../lib/text";

export const FEATURE_LABELS: Partial<Record<keyof Features, string>> = {
  has_credential: "Credential words",
  generic_greeting: "Generic greeting",
  has_money: "Money words",
  subject_caps: "ALL-CAPS subject",
  has_urgency: "Urgency words",
  at_in_url: "@ inside a link",
  has_url: "Contains a link",
  ip_url: "Link to an IP address",
  shortener_url: "Link shortener"
};

const MAX_LOG = Math.log10(300);

// One row per rule: whether it fired and its likelihood ratio as a centered bar.
export function RedFlags({ model, features }: { model: Model; features: Features }) {
  const rows = likelihoodRatios(model, features).sort((a, b) => b.ratio - a.ratio);
  return (
    <ul className="divide-y divide-border">
      {rows.map((r) => {
        const strength = Math.min(Math.abs(Math.log10(r.ratio)) / MAX_LOG, 1);
        // Within 5% of 1x the rule barely moves the score either way.
        const effect = r.ratio > 1.05 ? "raises" : r.ratio < 1 / 1.05 ? "lowers" : "neutral";
        const raises = effect === "raises";
        const width = effect === "neutral" ? "0%" : Math.max(strength * 50, 0.5) + "%";
        const tone = effect === "raises" ? "text-phish" : effect === "lowers" ? "text-legit" : "text-muted";
        return (
          <li
            key={r.feature}
            className="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-x-4 gap-y-1.5 py-2.5 sm:grid-cols-[minmax(0,12rem)_minmax(0,1fr)_7rem]"
          >
            <div className="min-w-0">
              <p className={"truncate text-sm " + (r.fired ? "font-medium" : "text-muted")}>
                {FEATURE_LABELS[r.feature] ?? r.feature}
              </p>
              <p className="num text-xs text-muted">{r.fired ? "present" : "absent"}</p>
            </div>
            <div
              aria-hidden="true"
              className="relative order-3 col-span-2 h-2 rounded-full bg-surface-2 sm:order-none sm:col-span-1"
            >
              <span className="absolute left-1/2 top-0 h-2 w-px bg-border" />
              <span
                className={"absolute top-0 h-2 rounded-full " + (raises ? "bg-phish" : "bg-legit")}
                style={raises ? { left: "50%", width } : { right: "50%", width }}
              />
            </div>
            <p className="num text-right text-sm">
              {formatRatio(r.ratio)}
              <span className="sr-only">
                {effect === "neutral" ? ", no effect" : ", " + effect + " the score"}
              </span>
              <span aria-hidden="true" className={"ml-1 inline-block w-9 text-left text-xs " + tone}>
                {effect === "raises" ? "up" : effect === "lowers" ? "down" : "none"}
              </span>
            </p>
          </li>
        );
      })}
    </ul>
  );
}
