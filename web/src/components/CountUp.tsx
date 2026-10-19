import { animate, useReducedMotion } from "framer-motion";
import { useEffect, useState } from "react";

interface Props {
  value: number;
  format: (v: number) => string;
  duration?: number;
}

// Counts from 0 to value once; shows the final value at once under reduced motion.
export function CountUp({ value, format, duration = 0.25 }: Props) {
  const reduce = useReducedMotion();
  const [shown, setShown] = useState(reduce ? value : 0);
  useEffect(() => {
    if (reduce) {
      setShown(value);
      return;
    }
    const controls = animate(0, value, { duration, ease: "easeOut", onUpdate: setShown });
    return () => controls.stop();
  }, [value, duration, reduce]);
  return (
    <>
      <span aria-hidden="true">{format(shown)}</span>
      <span className="sr-only">{format(value)}</span>
    </>
  );
}
