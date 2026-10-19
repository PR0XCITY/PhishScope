import { findHighlights, type HighlightGroup, type Lexicon } from "../lib/features";

export const GROUP_LABELS: Record<HighlightGroup, string> = {
  urgency: "urgency",
  credential: "credential",
  money: "money",
  generic_greeting: "generic greeting"
};

// Color plus a distinct underline style per group, so color is never the only signal.
export const MARK_CLASSES: Record<HighlightGroup, string> = {
  urgency: "bg-spam/20 decoration-spam decoration-solid",
  credential: "bg-phish/20 decoration-phish decoration-double",
  money: "bg-legit/20 decoration-legit decoration-dashed",
  generic_greeting: "bg-focus/20 decoration-focus decoration-dotted"
};

interface Props {
  label: string;
  text: string;
  lexicon: Lexicon;
}

// Input is rendered only as React text children: markup stays text and URLs are never links.
export function HighlightedText({ label, text, lexicon }: Props) {
  const parts: { key: string; text: string; group?: HighlightGroup }[] = [];
  let pos = 0;
  for (const [start, end, group] of findHighlights(text, lexicon)) {
    if (start > pos) parts.push({ key: "t" + pos, text: text.slice(pos, start) });
    parts.push({ key: "m" + start, text: text.slice(start, end), group });
    pos = end;
  }
  if (pos < text.length) parts.push({ key: "t" + pos, text: text.slice(pos) });

  return (
    <div>
      <p className="text-xs uppercase tracking-wide text-muted">{label}</p>
      <div className="num mt-1.5 max-h-80 overflow-auto whitespace-pre-wrap break-words rounded-lg border border-border bg-surface-2 p-3 text-sm leading-relaxed">
        {parts.length === 0 ? <span className="text-muted">(empty)</span> : null}
        {parts.map((p) =>
          p.group ? (
            <mark
              key={p.key}
              title={GROUP_LABELS[p.group]}
              className={"rounded-sm px-0.5 text-fg underline underline-offset-4 " + MARK_CLASSES[p.group]}
            >
              {p.text}
            </mark>
          ) : (
            <span key={p.key}>{p.text}</span>
          )
        )}
      </div>
    </div>
  );
}

export function HighlightLegend() {
  return (
    <ul className="flex flex-wrap gap-2 text-xs" aria-label="Highlight legend">
      {(Object.keys(GROUP_LABELS) as HighlightGroup[]).map((g) => (
        <li key={g}>
          <mark className={"rounded-sm px-1 text-fg underline underline-offset-4 " + MARK_CLASSES[g]}>
            {GROUP_LABELS[g]}
          </mark>
        </li>
      ))}
    </ul>
  );
}
