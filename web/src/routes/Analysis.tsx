import { AnimatePresence, motion, useReducedMotion } from "framer-motion";
import { ArrowLeft, ArrowRight, Lightbulb } from "lucide-react";
import { Link, Navigate, useNavigate, useParams } from "react-router";
import { ChartRenderer } from "../components/ChartRenderer";
import { CodePanel } from "../components/CodePanel";
import { ConsolePanel } from "../components/ConsolePanel";
import { DataTable } from "../components/DataTable";
import { TestCard } from "../components/TestCard";
import { ErrorState, LoadingBlock, Skeleton, Tag } from "../components/ui";
import { useMeta, useModule, type ModuleData, type ModuleSummary } from "../lib/data";

const MODULE_IDS = [0, 1, 2, 3, 4, 5, 6, 7, 8];

function Sidebar({ modules, current }: { modules: ModuleSummary[]; current: number }) {
  const navigate = useNavigate();
  return (
    <>
      <div className="lg:hidden">
        <label htmlFor="module-select" className="mb-1.5 block text-sm text-muted">
          Module
        </label>
        <select
          id="module-select"
          value={current}
          onChange={(e) => navigate("/analysis/" + e.target.value)}
          className="w-full rounded-lg border border-border bg-surface px-3 py-2"
        >
          {modules.map((m) => (
            <option key={m.id} value={m.id}>
              {m.syllabus_module}: {m.title}
            </option>
          ))}
        </select>
      </div>
      <nav aria-label="Modules" className="hidden lg:block">
        <ol className="space-y-1">
          {modules.map((m) => {
            const active = m.id === current;
            return (
              <li key={m.id}>
                <Link
                  to={"/analysis/" + m.id}
                  aria-current={active ? "page" : undefined}
                  className={
                    "block rounded-lg border px-3 py-2 transition-colors duration-150 " +
                    (active
                      ? "border-border bg-surface text-fg"
                      : "border-transparent text-muted hover:text-fg")
                  }
                >
                  <span className="num block text-xs text-muted">{m.syllabus_module}</span>
                  <span className="block text-sm">{m.title}</span>
                </Link>
              </li>
            );
          })}
        </ol>
      </nav>
    </>
  );
}

function ModuleView({ data, modules }: { data: ModuleData; modules: ModuleSummary[] }) {
  const idx = modules.findIndex((m) => m.id === data.id);
  const prev = idx > 0 ? modules[idx - 1] : null;
  const next = idx >= 0 && idx < modules.length - 1 ? modules[idx + 1] : null;
  return (
    <article className="min-w-0 space-y-8">
      <header>
        <Tag tone="focus">{data.syllabus_module}</Tag>
        <h1 className="mt-3 text-3xl font-semibold tracking-tight">{data.title}</h1>
        <p className="mt-2 text-xl text-muted">{data.question}</p>
      </header>

      <CodePanel blocks={data.code} />
      <ConsolePanel lines={data.console} />

      {data.charts.length > 0 ? (
        <section aria-label="Charts" className="grid grid-cols-1 gap-4 xl:grid-cols-2">
          {data.charts.map((c) => (
            <ChartRenderer key={c.id} chart={c} />
          ))}
        </section>
      ) : null}

      {data.tests.length > 0 ? (
        <section aria-labelledby="tests-title">
          <h2 id="tests-title" className="mb-3 text-xl font-semibold tracking-tight">
            Hypothesis tests
          </h2>
          <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3">
            {data.tests.map((t, i) => (
              <TestCard key={t.name + i} test={t} />
            ))}
          </div>
        </section>
      ) : null}

      {data.tables.length > 0 ? (
        <section aria-label="Tables" className="grid grid-cols-1 gap-4 xl:grid-cols-2">
          {data.tables.map((t) => (
            <DataTable key={t.title} table={t} />
          ))}
        </section>
      ) : null}

      <aside className="card flex gap-3 border-focus/40 p-5">
        <Lightbulb aria-hidden="true" className="mt-0.5 size-5 shrink-0 text-focus" />
        <div>
          <p className="text-sm font-medium">Takeaway</p>
          <p className="mt-1 text-muted">{data.takeaway}</p>
        </div>
      </aside>

      <nav aria-label="Module pagination" className="flex flex-wrap justify-between gap-3">
        {prev ? (
          <Link
            to={"/analysis/" + prev.id}
            className="card inline-flex items-center gap-2 px-4 py-2.5 text-sm hover:border-focus/50"
          >
            <ArrowLeft aria-hidden="true" className="size-4" />
            {prev.title}
          </Link>
        ) : (
          <span />
        )}
        {next ? (
          <Link
            to={"/analysis/" + next.id}
            className="card inline-flex items-center gap-2 px-4 py-2.5 text-sm hover:border-focus/50"
          >
            {next.title}
            <ArrowRight aria-hidden="true" className="size-4" />
          </Link>
        ) : null}
      </nav>
    </article>
  );
}

function ModuleLoader({ id, modules }: { id: number; modules: ModuleSummary[] }) {
  const mod = useModule(id);
  const reduce = useReducedMotion();
  if (mod.status === "loading") return <LoadingBlock label="Loading module" lines={8} />;
  if (mod.status === "error")
    return <ErrorState title="This module could not be loaded" detail={mod.error} />;
  return (
    <AnimatePresence mode="wait">
      <motion.div
        key={id}
        initial={reduce ? false : { opacity: 0, y: 4 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.2, ease: "easeOut" }}
      >
        <ModuleView data={mod.data} modules={modules} />
      </motion.div>
    </AnimatePresence>
  );
}

export default function Analysis() {
  const { id } = useParams();
  const meta = useMeta();
  const n = Number(id);
  if (!MODULE_IDS.includes(n)) return <Navigate to="/analysis/0" replace />;
  return (
    <div className="grid grid-cols-1 gap-8 lg:grid-cols-[15rem_minmax(0,1fr)]">
      <aside className="lg:sticky lg:top-24 lg:self-start">
        {meta.status === "ready" ? (
          <Sidebar modules={meta.data.modules} current={n} />
        ) : meta.status === "loading" ? (
          <div className="space-y-2">
            {MODULE_IDS.map((i) => (
              <Skeleton key={i} className="h-12" />
            ))}
          </div>
        ) : (
          <ErrorState title="Module list unavailable" detail={meta.error} />
        )}
      </aside>
      <ModuleLoader id={n} modules={meta.status === "ready" ? meta.data.modules : []} />
    </div>
  );
}
