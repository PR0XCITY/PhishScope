import { AnimatePresence, motion, useReducedMotion } from "framer-motion";
import { ShieldCheck } from "lucide-react";
import { NavLink, Outlet, useLocation } from "react-router";
import { useMeta } from "../lib/data";
import { ThemeToggle } from "./ThemeToggle";
import { Skeleton } from "./ui";

const NAV = [
  { to: "/check", label: "Check" },
  { to: "/analysis/0", label: "Analysis", match: "/analysis" },
  { to: "/pipeline", label: "Pipeline" }
];

function RBadge() {
  const meta = useMeta();
  if (meta.status === "loading") return <Skeleton className="hidden h-6 w-32 sm:block" />;
  if (meta.status === "error") return null;
  return (
    <span className="num hidden items-center gap-1.5 rounded-full border border-border px-2.5 py-1 text-xs text-muted sm:inline-flex">
      <span aria-hidden="true" className="size-1.5 rounded-full bg-legit" />
      Analyzed in R {meta.data.r_version_short}
    </span>
  );
}

export function Layout() {
  const location = useLocation();
  const reduce = useReducedMotion();
  const meta = useMeta();
  return (
    <div className="flex min-h-screen flex-col">
      <a
        href="#main"
        onClick={(e) => {
          e.preventDefault();
          document.getElementById("main")?.focus();
        }}
        className="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-50 focus:rounded-md focus:bg-surface focus:px-3 focus:py-2"
      >
        Skip to content
      </a>
      <header className="sticky top-0 z-40 border-b border-border bg-bg/90 backdrop-blur-sm">
        <div className="mx-auto flex max-w-7xl flex-wrap items-center gap-x-6 gap-y-2 px-4 py-3 sm:px-6">
          <NavLink
            to="/"
            className="flex items-center gap-2 font-semibold tracking-tight"
            aria-label="PhishScope home"
          >
            <ShieldCheck aria-hidden="true" className="size-5 text-focus" />
            <span className="text-base">
              Phish<span className="text-focus">Scope</span>
            </span>
          </NavLink>
          <nav aria-label="Main" className="order-3 w-full sm:order-none sm:w-auto">
            <ul className="flex gap-1">
              {NAV.map((item) => {
                const active = location.pathname.startsWith(item.match ?? item.to);
                return (
                  <li key={item.to}>
                    <NavLink
                      to={item.to}
                      aria-current={active ? "page" : undefined}
                      className={
                        "rounded-md px-3 py-1.5 text-sm transition-colors duration-150 " +
                        (active ? "bg-surface-2 text-fg" : "text-muted hover:text-fg")
                      }
                    >
                      {item.label}
                    </NavLink>
                  </li>
                );
              })}
            </ul>
          </nav>
          <div className="ml-auto flex items-center gap-3">
            <RBadge />
            <ThemeToggle />
          </div>
        </div>
      </header>

      <main
        id="main"
        tabIndex={-1}
        className="mx-auto w-full max-w-7xl flex-1 px-4 py-8 outline-none sm:px-6"
      >
        <AnimatePresence mode="wait" initial={false}>
          <motion.div
            key={location.pathname.split("/")[1] ?? ""}
            initial={reduce ? false : { opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={reduce ? undefined : { opacity: 0 }}
            transition={{ duration: 0.18, ease: "easeOut" }}
          >
            <Outlet />
          </motion.div>
        </AnimatePresence>
      </main>

      <footer className="border-t border-border">
        <div className="mx-auto flex max-w-7xl flex-col gap-2 px-4 py-6 text-sm text-muted sm:px-6">
          <p className="text-fg">All checks run in your browser. Nothing is sent anywhere.</p>
          <p>
            Data:{" "}
            {meta.status === "ready" ? meta.data.citation : "Al-Subaiey, A. et al. (2024), arXiv:2405.11619."}
          </p>
          <p>
            An early-warning aid, not a spam filter.{" "}
            <a
              href="https://github.com/PR0XCITY/PhishScope"
              rel="noopener noreferrer"
              className="text-focus underline-offset-4 hover:underline"
            >
              Source on GitHub
            </a>
          </p>
        </div>
      </footer>
    </div>
  );
}
