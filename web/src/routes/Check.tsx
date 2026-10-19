import { FileText, ScanSearch } from "lucide-react";
import { useMemo, useState, type FormEvent } from "react";
import { useSearchParams } from "react-router";
import { BayesFormula } from "../components/BayesFormula";
import { Gauge, VERDICT_LABEL } from "../components/Gauge";
import { HighlightedText, HighlightLegend } from "../components/HighlightedText";
import { PrevalenceSlider } from "../components/PrevalenceSlider";
import { RedFlags } from "../components/RedFlags";
import { ErrorState, LoadingBlock, SectionTitle } from "../components/ui";
import { EXAMPLES } from "../data/examples";
import { useModel } from "../lib/data";
import { extractFeatures } from "../lib/features";
import { likelihoodTerms, posteriorFromTerms, verdictFor, type Model } from "../lib/score";
import { clampText, MAX_BODY, MAX_SUBJECT } from "../lib/text";

const field = "w-full rounded-lg border border-border bg-surface-2 px-3 py-2 text-fg placeholder:text-muted";

function Result({ model, subject, body }: { model: Model; subject: string; body: string }) {
  const [prior, setPrior] = useState(0.01);
  const features = useMemo(() => extractFeatures(subject, body, model.lexicon), [subject, body, model]);
  const { l1, l0 } = likelihoodTerms(model, features);
  const posterior = posteriorFromTerms(l1, l0, prior);
  const verdict = verdictFor(posterior, model.threshold);
  const tone = verdict === "phishing" ? "text-phish" : verdict === "suspicious" ? "text-spam" : "text-legit";
  return (
    <div className="space-y-6">
      <div className="card p-5">
        <div className="grid grid-cols-1 items-center gap-6 sm:grid-cols-[220px_minmax(0,1fr)]">
          <Gauge value={posterior} verdict={verdict} />
          <div className="space-y-5">
            <div>
              <p className="text-sm text-muted">Verdict</p>
              <p className={"text-xl font-semibold " + tone} aria-live="polite">
                {VERDICT_LABEL[verdict]}
              </p>
            </div>
            <PrevalenceSlider prior={prior} onChange={setPrior} />
          </div>
        </div>
        <div className="mt-5">
          <BayesFormula prior={prior} l1={l1} l0={l0} posterior={posterior} />
        </div>
      </div>

      <div className="card p-5">
        <SectionTitle>Red flags</SectionTitle>
        <p className="mb-2 text-sm text-muted">
          Likelihood ratio = P(rule state | phishing) / P(rule state | legitimate). Above 1x pushes toward
          phishing.
        </p>
        <RedFlags model={model} features={features} />
      </div>

      <div className="card space-y-4 p-5">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <SectionTitle>Matched words</SectionTitle>
          <HighlightLegend />
        </div>
        <HighlightedText label="Subject" text={subject} lexicon={model.lexicon} />
        <HighlightedText label="Body" text={body} lexicon={model.lexicon} />
      </div>
    </div>
  );
}

function EmptyState() {
  return (
    <div className="card flex min-h-80 flex-col items-center justify-center gap-3 p-8 text-center">
      <FileText aria-hidden="true" className="size-8 text-muted" />
      <p className="font-medium">No email analyzed yet</p>
      <p className="max-w-sm text-sm text-muted">
        Paste a subject and body, or try one of the examples. The score, red flags and matched words appear
        here.
      </p>
    </div>
  );
}

// "#/check?example=phishy" preloads a built-in example (used for screenshots and links).
function initialExample(params: URLSearchParams) {
  const key = params.get("example");
  return key === "phishy" || key === "normal" ? EXAMPLES[key] : null;
}

export default function Check() {
  const model = useModel();
  const [params] = useSearchParams();
  const [preset] = useState(() => initialExample(params));
  const [subject, setSubject] = useState(preset?.subject ?? "");
  const [body, setBody] = useState(preset?.body ?? "");
  const [analyzed, setAnalyzed] = useState<{ subject: string; body: string } | null>(
    preset ? { subject: preset.subject, body: preset.body } : null
  );
  const ready = model.status === "ready";

  const submit = (e: FormEvent) => {
    e.preventDefault();
    setAnalyzed({ subject: clampText(subject, MAX_SUBJECT), body: clampText(body, MAX_BODY) });
  };
  const loadExample = (key: keyof typeof EXAMPLES) => {
    const ex = EXAMPLES[key];
    setSubject(ex.subject);
    setBody(ex.body);
    setAnalyzed({ subject: ex.subject, body: ex.body });
  };

  return (
    <div>
      <header className="mb-8 max-w-2xl">
        <h1 className="text-3xl font-semibold tracking-tight">Check an email</h1>
        <p className="mt-2 text-muted">
          PhishScore runs the same six statistical red flags as the R analysis, right here in your browser.
        </p>
      </header>
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-[minmax(0,5fr)_minmax(0,7fr)]">
        <form onSubmit={submit} noValidate className="card h-fit space-y-4 p-5" aria-label="Email to check">
          <div>
            <label htmlFor="subject" className="mb-1.5 block text-sm font-medium">
              Subject
            </label>
            <input
              id="subject"
              type="text"
              maxLength={MAX_SUBJECT}
              autoComplete="off"
              spellCheck={false}
              value={subject}
              onChange={(e) => setSubject(e.target.value)}
              className={field}
            />
          </div>
          <div>
            <label htmlFor="body" className="mb-1.5 block text-sm font-medium">
              Email body
            </label>
            <textarea
              id="body"
              rows={12}
              maxLength={MAX_BODY}
              spellCheck={false}
              aria-describedby="body-counter"
              value={body}
              onChange={(e) => setBody(clampText(e.target.value, MAX_BODY))}
              className={field + " num min-h-48 resize-y text-sm"}
            />
            <p id="body-counter" className="num mt-1 text-right text-xs text-muted" aria-live="polite">
              {body.length.toLocaleString("en-US")} / {MAX_BODY.toLocaleString("en-US")}
            </p>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <button
              type="submit"
              disabled={!ready}
              className="inline-flex items-center gap-2 rounded-lg bg-focus px-4 py-2 font-medium text-bg transition-opacity duration-150 hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-50"
            >
              <ScanSearch aria-hidden="true" className="size-4" />
              Analyze
            </button>
            {(Object.keys(EXAMPLES) as (keyof typeof EXAMPLES)[]).map((key) => (
              <button
                key={key}
                type="button"
                disabled={!ready}
                onClick={() => loadExample(key)}
                className="rounded-lg border border-border px-3 py-2 text-sm transition-colors duration-150 hover:border-focus/50 disabled:cursor-not-allowed disabled:opacity-50"
              >
                {EXAMPLES[key].label}
              </button>
            ))}
          </div>
          <p className="text-xs text-muted">Examples are hand-written, not taken from the dataset.</p>
        </form>

        <section aria-label="Result">
          {model.status === "loading" ? (
            <LoadingBlock label="Loading the PhishScore model" lines={6} />
          ) : model.status === "error" ? (
            <ErrorState title="The model could not be loaded" detail={model.error} />
          ) : analyzed === null ? (
            <EmptyState />
          ) : (
            <Result model={model.data} subject={analyzed.subject} body={analyzed.body} />
          )}
        </section>
      </div>
    </div>
  );
}
