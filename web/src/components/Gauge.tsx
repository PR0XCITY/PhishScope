import { motion, useReducedMotion } from "framer-motion";
import { usePalette } from "../lib/colors";
import type { Verdict } from "../lib/score";
import { formatPercent } from "../lib/text";

export const VERDICT_LABEL: Record<Verdict, string> = {
  legitimate: "Likely legitimate",
  suspicious: "Suspicious",
  phishing: "Likely phishing"
};

const R = 80;
const CIRC = 2 * Math.PI * R;
const ARC = 0.75; // 270 degree gauge

export function Gauge({ value, verdict }: { value: number; verdict: Verdict }) {
  const p = usePalette();
  const reduce = useReducedMotion();
  const color = verdict === "phishing" ? p.phish : verdict === "suspicious" ? p.spam : p.legit;
  const track = CIRC * ARC;
  const offset = track * (1 - Math.min(Math.max(value, 0), 1));
  return (
    <div
      role="meter"
      aria-label="Probability that this email is phishing"
      aria-valuemin={0}
      aria-valuemax={100}
      aria-valuenow={Math.round(value * 1000) / 10}
      aria-valuetext={formatPercent(value) + ", " + VERDICT_LABEL[verdict]}
      className="relative mx-auto w-full max-w-[220px]"
    >
      <svg viewBox="0 0 200 200" className="w-full" aria-hidden="true">
        <g transform="rotate(135 100 100)">
          <circle
            cx="100"
            cy="100"
            r={R}
            fill="none"
            stroke={p.border}
            strokeWidth="12"
            strokeLinecap="round"
            strokeDasharray={`${track} ${CIRC}`}
          />
          <motion.circle
            cx="100"
            cy="100"
            r={R}
            fill="none"
            stroke={color}
            strokeWidth="12"
            strokeLinecap="round"
            strokeDasharray={`${track} ${CIRC}`}
            initial={reduce ? false : { strokeDashoffset: track }}
            animate={{ strokeDashoffset: offset }}
            transition={reduce ? { duration: 0 } : { duration: 0.25, ease: "easeOut" }}
          />
        </g>
      </svg>
      <div className="absolute inset-0 flex flex-col items-center justify-center">
        <span className="num text-3xl font-medium">{formatPercent(value)}</span>
        <span className="mt-1 text-xs text-muted">P(phishing | email)</span>
      </div>
    </div>
  );
}
