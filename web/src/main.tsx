import "@fontsource/ibm-plex-sans/400.css";
import "@fontsource/ibm-plex-sans/500.css";
import "@fontsource/ibm-plex-sans/600.css";
import "@fontsource/ibm-plex-mono/400.css";
import "@fontsource/ibm-plex-mono/500.css";
import "./index.css";

import { StrictMode, Suspense, lazy } from "react";
import { createRoot } from "react-dom/client";
import { HashRouter, Link, Navigate, Route, Routes } from "react-router";
import { Layout } from "./components/Layout";
import { LoadingBlock } from "./components/ui";
import { applyTheme, readThemeChoice, resolveTheme, ThemeProvider } from "./lib/theme";
import Check from "./routes/Check";
import Home from "./routes/Home";
import Pipeline from "./routes/Pipeline";

const Analysis = lazy(() => import("./routes/Analysis"));

function NotFound() {
  return (
    <div className="card p-8">
      <h1 className="text-xl font-semibold">Page not found</h1>
      <Link to="/" className="mt-3 inline-block text-focus underline-offset-4 hover:underline">
        Back to the start
      </Link>
    </div>
  );
}

// Apply the stored theme before the first paint.
applyTheme(resolveTheme(readThemeChoice()));

const root = document.getElementById("root");
if (root !== null) {
  createRoot(root).render(
    <StrictMode>
      <ThemeProvider>
        <HashRouter>
          <Routes>
            <Route element={<Layout />}>
              <Route index element={<Home />} />
              <Route path="check" element={<Check />} />
              <Route path="analysis" element={<Navigate to="/analysis/0" replace />} />
              <Route
                path="analysis/:id"
                element={
                  <Suspense fallback={<LoadingBlock label="Loading the analysis explorer" lines={8} />}>
                    <Analysis />
                  </Suspense>
                }
              />
              <Route path="pipeline" element={<Pipeline />} />
              <Route path="*" element={<NotFound />} />
            </Route>
          </Routes>
        </HashRouter>
      </ThemeProvider>
    </StrictMode>
  );
}
