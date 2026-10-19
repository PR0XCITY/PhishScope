/// <reference types="vitest/config" />
import { defineConfig, type Plugin } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";

export const CSP =
  "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; font-src 'self'; " +
  "img-src 'self' data:; connect-src 'self'; base-uri 'none'; form-action 'none'; " +
  "object-src 'none'";

// index.html carries the CSP meta for the built site. The dev server needs inline
// React Refresh code, so the tag is removed while serving locally.
function stripCspInDev(): Plugin {
  return {
    name: "phishscope-strip-csp-in-dev",
    apply: "serve",
    transformIndexHtml(html) {
      return html.replace(/<meta http-equiv="Content-Security-Policy"[^>]*>\s*/, "");
    }
  };
}

export default defineConfig({
  base: "./",
  plugins: [react(), tailwindcss(), stripCspInDev()],
  build: {
    modulePreload: { polyfill: false },
    // Never inline fonts as data: URIs (font-src is 'self' only).
    assetsInlineLimit: (file) => !/\.(woff2?|ttf|otf)$/.test(file),
    chunkSizeWarningLimit: 900
  },
  test: {
    environment: "jsdom",
    css: false
  }
});
