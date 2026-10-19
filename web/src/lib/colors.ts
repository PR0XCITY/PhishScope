// Resolved token colors for SVG/Recharts, which cannot use CSS variables in attributes.
import { useMemo } from "react";
import { useTheme } from "./theme";

export interface Palette {
  bg: string;
  surface: string;
  surface2: string;
  border: string;
  text: string;
  muted: string;
  legit: string;
  spam: string;
  phish: string;
  focus: string;
}

const DARK: Palette = {
  bg: "#0B0F14",
  surface: "#121821",
  surface2: "#18202B",
  border: "#1F2A37",
  text: "#E6EDF3",
  muted: "#8B98A5",
  legit: "#3DDC97",
  spam: "#FFB020",
  phish: "#FF5C5C",
  focus: "#7AA7FF"
};

const LIGHT: Palette = {
  bg: "#F7F8FA",
  surface: "#FFFFFF",
  surface2: "#F0F2F5",
  border: "#E3E7ED",
  text: "#0B0F14",
  muted: "#5B6673",
  legit: "#0E7A50",
  spam: "#9A5B00",
  phish: "#C62828",
  focus: "#2F5FD0"
};

export function usePalette(): Palette {
  const { resolved } = useTheme();
  return useMemo(() => (resolved === "dark" ? DARK : LIGHT), [resolved]);
}

export function classColor(p: Palette, cls: string | null | undefined): string | null {
  if (cls === "legitimate") return p.legit;
  if (cls === "phishing") return p.phish;
  if (cls === "spam") return p.spam;
  return null;
}

// Fallback order when series are not one-per-class.
export function seriesPalette(p: Palette): string[] {
  return [p.focus, p.spam, p.legit, p.phish, p.muted];
}
