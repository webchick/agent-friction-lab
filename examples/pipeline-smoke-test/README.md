# Worked Example: Executor → Reviewer → Mediator

Real, unedited output from `run-friction-lab-experiment.sh`, kept here to show what the pipeline actually produces and how the review/synthesis stages behave — not a fabricated illustration.

## What this run was

A deliberately trivial task (`experiment-brief.md`: determine the HTML `<title>` of https://example.com/) run through the pipeline to smoke-test the mechanics, not to evaluate a real target.

`findings.md` was hand-crafted rather than produced by a real executor run, to skip the executor's Preflight (which expects the actual disposable dev container) and, more importantly, to plant one deliberate defect: an **Observed** claim citing evidence ID `E002`, which does not exist anywhere in `evidence-index.md`. `environment.md` and `raw-log.md` were also hand-crafted, as stand-ins for what a real executor would produce.

`review.md` and `final-report.md` are real, unedited output from `./run-friction-lab-experiment.sh review` and `./run-friction-lab-experiment.sh synthesize`, run for real against this fixture — nothing in either file was written or adjusted by hand.

## What it shows

- The reviewer independently caught the planted E002 defect, and correctly reasoned about *why* it was unsupported: no `evidence-index.md` row, no file, no `raw-log.md` entry, and no browser-MCP preflight recorded in `environment.md` that would make the claim plausible in the first place. It also caught something that wasn't deliberately planted — `environment.md` giving prose summaries instead of the literal check output `agent-runbook.md`'s Preflight section requires.
- The mediator's `final-report.md` does not silently resolve the disagreement between `findings.md` and `review.md` on the E002 claim. It states the ground truth on the actual task (title correctly determined: success) separately from the evidentiary-integrity verdict (not clean, because of the uncorroborated claim), and leaves "was a Playwright snapshot taken and never logged, or never taken at all" as an open question for the human rather than guessing.
- The mediator independently re-checks claims about `raw-log.md`/`environment.md` itself rather than trusting the reviewer's description of them — `reviewProtocol.synthesisArtifacts` was fixed to include both files after an earlier pass through this same fixture showed the mediator couldn't verify reviewer claims about files it never received.

## A caveat worth knowing

`experiment-brief.md`'s Reason section describes this run's purpose as testing "citation discipline," among other things — a leak in the test design. Both the reviewer and mediator noticed the framing (see the mediator's closing question in `final-report.md`). This doesn't undermine the reasoning quality once each agent found the gap, but it means this example doesn't demonstrate a *blind* catch of a fabricated citation — a brief that doesn't tip its hand would be a stronger test of that specific claim.

## Reproducing this

```bash
cp .friction-lab/config.cross-review.example.json .friction-lab/config.local.json
# ...fill in your own experiment-brief.md and run the executor for real...
./run-friction-lab-experiment.sh review
./run-friction-lab-experiment.sh synthesize
```

See `agent-runbook.md` for what each stage is actually supposed to do, and the "Agent Roles And Review" / "Running The Experiment Pipeline" sections of the top-level `README.md` for the full setup.
