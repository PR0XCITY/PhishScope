// Small shared building blocks: skeletons, error state, tags, section headings.
import { AlertTriangle } from "lucide-react";
import type { ReactNode } from "react";

export function Skeleton({ className = "" }: { className?: string }) {
  return (
    <div aria-hidden="true" className={"motion-safe:animate-pulse rounded-md bg-surface-2 " + className} />
  );
}

export function LoadingBlock({ label, lines = 3 }: { label: string; lines?: number }) {
  return (
    <div role="status" aria-label={label} className="card space-y-3 p-6">
      <Skeleton className="h-6 w-1/3" />
      {Array.from({ length: lines }, (_, i) => (
        <Skeleton key={i} className="h-4 w-full" />
      ))}
      <span className="sr-only">{label}</span>
    </div>
  );
}

export function ErrorState({ title, detail }: { title: string; detail: string }) {
  return (
    <div role="alert" className="card flex items-start gap-3 border-phish/50 p-5">
      <AlertTriangle aria-hidden="true" className="mt-0.5 size-5 shrink-0 text-phish" />
      <div>
        <p className="font-semibold">{title}</p>
        <p className="mt-1 text-sm text-muted">{detail}</p>
        <p className="mt-2 text-sm text-muted">Reload the page to try again.</p>
      </div>
    </div>
  );
}

export function Tag({ children, tone = "muted" }: { children: ReactNode; tone?: "muted" | "focus" }) {
  const cls = tone === "focus" ? "border-focus/40 text-focus" : "border-border text-muted";
  return (
    <span className={"num inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs " + cls}>
      {children}
    </span>
  );
}

export function SectionTitle({ children, id }: { children: ReactNode; id?: string }) {
  return (
    <h2 id={id} className="mb-3 text-xl font-semibold tracking-tight">
      {children}
    </h2>
  );
}
