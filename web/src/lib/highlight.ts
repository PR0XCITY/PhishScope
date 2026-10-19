// Lazy Shiki setup: R grammar and two themes only, JavaScript regex engine (no WASM, no eval).
// Tokens are rendered by React as spans; no HTML strings are produced.
import type { HighlighterCore, ThemedToken } from "shiki/core";

export type CodeTheme = "github-dark" | "github-light";
let highlighter: Promise<HighlighterCore> | null = null;

function getHighlighter(): Promise<HighlighterCore> {
  highlighter ??= (async () => {
    const [{ createHighlighterCore }, { createJavaScriptRegexEngine }, r, dark, light] = await Promise.all([
      import("shiki/core"),
      import("shiki/engine/javascript"),
      import("shiki/langs/r.mjs"),
      import("shiki/themes/github-dark.mjs"),
      import("shiki/themes/github-light.mjs")
    ]);
    return createHighlighterCore({
      themes: [dark.default, light.default],
      langs: [r.default],
      engine: createJavaScriptRegexEngine()
    });
  })();
  return highlighter;
}

export async function tokenizeR(code: string, theme: CodeTheme): Promise<ThemedToken[][]> {
  const h = await getHighlighter();
  return h.codeToTokens(code, { lang: "r", theme }).tokens;
}
