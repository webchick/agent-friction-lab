# Agent Friction Lab Experiment Brief

## Reason

Smoke test of the executor/reviewer/mediator pipeline mechanics (isolation, evidence handoff, citation discipline) using a deliberately trivial task, ahead of running the harness against a real PLG onboarding target.

## Outcome

Determine the HTML `<title>` of https://example.com/ and report it.

Success criteria: `findings.md` states the literal title text, cited to a piece of evidence that actually contains it.

## Targets

https://example.com/ (single target, no comparison).

## Starting Conditions

No pre-authenticated accounts, no target-specific tooling, no prior run artifacts. Generic developer tooling and web access available.

## Allowed Resources

Public web access to https://example.com/ only.

## Off-Limits

No spending, no accounts, no destructive actions. This is a read-only fetch of a single public page.

## Preflight Additions

None beyond the harness defaults.

## Tests

Success: findings.md correctly states the page title and cites the evidence it came from.
Failure: title is wrong, missing, or uncited.

## Timing

Not material for this smoke test.

## Final Deliverable

Standard findings.md / review.md / final-report.md per agent-runbook.md.
