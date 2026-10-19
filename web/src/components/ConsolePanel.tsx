import { ChevronRight, Terminal } from "lucide-react";

export function ConsolePanel({ lines }: { lines: string[] }) {
  if (lines.length === 0) return null;
  return (
    <details className="card group overflow-hidden">
      <summary className="flex cursor-pointer list-none items-center gap-2 px-4 py-3 text-sm font-medium [&::-webkit-details-marker]:hidden">
        <ChevronRight
          aria-hidden="true"
          className="size-4 text-muted transition-transform duration-150 group-open:rotate-90"
        />
        <Terminal aria-hidden="true" className="size-4 text-muted" />R console output
        <span className="num ml-auto text-xs text-muted">{lines.length} lines</span>
      </summary>
      <pre
        tabIndex={0}
        aria-label="R console output"
        className="num max-h-96 overflow-auto border-t border-border bg-bg px-4 py-3 text-[13px] leading-6 text-muted"
      >
        {lines.join("\n")}
      </pre>
    </details>
  );
}
