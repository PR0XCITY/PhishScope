import { Check, Copy, FileCode } from "lucide-react";
import { useEffect, useId, useRef, useState, type KeyboardEvent } from "react";
import type { ThemedToken } from "shiki/core";
import type { CodeBlock } from "../lib/data";
import { useTheme } from "../lib/theme";

function useTokens(code: string): ThemedToken[][] | null {
  const { resolved } = useTheme();
  const theme = resolved === "dark" ? "github-dark" : "github-light";
  const [state, setState] = useState<{ key: string; tokens: ThemedToken[][] } | null>(null);
  const key = theme + "\u0000" + code;
  useEffect(() => {
    let active = true;
    import("../lib/highlight")
      .then((m) => m.tokenizeR(code, theme))
      .then((tokens) => {
        if (active) setState({ key, tokens });
      })
      .catch(() => undefined); // Plain text stays on screen if highlighting fails.
    return () => {
      active = false;
    };
  }, [code, theme, key]);
  return state?.key === key ? state.tokens : null;
}

function CodeLines({ block }: { block: CodeBlock }) {
  const tokens = useTokens(block.code);
  const plain = block.code.split("\n");
  return (
    <pre
      className="num overflow-x-auto py-3 text-[13px] leading-6"
      tabIndex={0}
      aria-label={"Code from " + block.file}
    >
      <code>
        {plain.map((line, i) => (
          <div key={i} className="flex px-4">
            <span aria-hidden="true" className="w-10 shrink-0 select-none pr-4 text-right text-muted/70">
              {block.start_line + i}
            </span>
            <span className="whitespace-pre">
              {tokens?.[i]
                ? tokens[i].map((t, j) => (
                    <span
                      key={j}
                      style={{
                        color: t.color,
                        fontStyle: t.fontStyle !== undefined && (t.fontStyle & 1) === 1 ? "italic" : undefined
                      }}
                    >
                      {t.content}
                    </span>
                  ))
                : line || " "}
            </span>
          </div>
        ))}
      </code>
    </pre>
  );
}

function CopyButton({ text }: { text: string }) {
  const [copied, setCopied] = useState(false);
  const copy = async () => {
    try {
      await navigator.clipboard.writeText(text);
      setCopied(true);
      window.setTimeout(() => setCopied(false), 1500);
    } catch {
      setCopied(false);
    }
  };
  return (
    <button
      type="button"
      onClick={copy}
      className="inline-flex items-center gap-1.5 rounded-md border border-border px-2 py-1 text-xs text-muted transition-colors duration-150 hover:text-fg"
    >
      {copied ? (
        <Check aria-hidden="true" className="size-3.5" />
      ) : (
        <Copy aria-hidden="true" className="size-3.5" />
      )}
      {copied ? "Copied" : "Copy"}
    </button>
  );
}

export function CodePanel({ blocks }: { blocks: CodeBlock[] }) {
  const [active, setActive] = useState(0);
  const base = useId();
  const tabs = useRef<(HTMLButtonElement | null)[]>([]);
  if (blocks.length === 0) return null;
  const current = blocks[Math.min(active, blocks.length - 1)];
  const lastLine = current.start_line + current.code.split("\n").length - 1;

  const onKey = (e: KeyboardEvent<HTMLDivElement>) => {
    const targets: Record<string, number> = {
      ArrowRight: (active + 1) % blocks.length,
      ArrowLeft: (active - 1 + blocks.length) % blocks.length,
      Home: 0,
      End: blocks.length - 1
    };
    const next = targets[e.key];
    if (next === undefined) return;
    e.preventDefault();
    setActive(next);
    tabs.current[next]?.focus();
  };

  return (
    <section className="card overflow-hidden" aria-label="R code">
      <div
        role="tablist"
        aria-label="R code blocks"
        onKeyDown={onKey}
        className="flex overflow-x-auto border-b border-border"
      >
        {blocks.map((b, i) => (
          <button
            key={b.file + b.start_line}
            ref={(el) => {
              tabs.current[i] = el;
            }}
            id={base + "-tab-" + i}
            role="tab"
            type="button"
            aria-selected={i === active}
            aria-controls={base + "-panel"}
            tabIndex={i === active ? 0 : -1}
            onClick={() => setActive(i)}
            className={
              "shrink-0 border-b-2 px-4 py-2.5 text-sm whitespace-nowrap transition-colors duration-150 " +
              (i === active ? "border-focus text-fg" : "border-transparent text-muted hover:text-fg")
            }
          >
            {b.label}
          </button>
        ))}
      </div>
      <div id={base + "-panel"} role="tabpanel" aria-labelledby={base + "-tab-" + active}>
        <div className="flex flex-wrap items-center justify-between gap-2 border-b border-border bg-surface-2 px-4 py-2">
          <p className="num flex min-w-0 items-center gap-2 text-xs text-muted">
            <FileCode aria-hidden="true" className="size-3.5 shrink-0" />
            <span className="truncate">{current.file}</span>
            <span>
              lines {current.start_line} to {lastLine}
            </span>
          </p>
          <CopyButton text={current.code} />
        </div>
        <CodeLines key={current.file + current.start_line} block={current} />
      </div>
    </section>
  );
}
