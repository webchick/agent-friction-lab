# Airlock Agent Experiment Runbook

Use this runbook with a task-specific brief. Do not begin the task until preflight passes.

## Preflight

Before starting task work, verify and record that the environment matches the intended airlock conditions.

The environment should begin with:

- no pre-authenticated target accounts,
- no target-specific CLIs or SDKs unless explicitly part of the baseline being tested,
- no saved browser sessions,
- no target-specific MCP servers, plugins, agent skills, or injected product documentation,
- no prior experiment traces or findings visible in the active workspace,
- no host SSH keys or target credentials,
- browser automation available from the beginning,
- generic shell, git, package manager, curl, jq, and web access available.

The exact allowed MCP servers, extra required commands, forbidden commands, forbidden environment patterns, and prior-run trace patterns are declared in `.airlock/config.json`.

The model's stock training knowledge is allowed and is part of the real-world test. Treat this as a cold-context and cold-environment test, not a literal test of zero prior model knowledge.

Before touching the target task, create `environment.md` containing literal outputs of checks for at least:

- OS and architecture,
- current working directory and `$HOME`,
- required generic tools,
- absence of target-specific tools named in the task brief,
- relevant target/vendor environment variables,
- contents of `~/.ssh` if present,
- files visible in the workspace,
- configured MCP servers/plugins/skills,
- a harmless Playwright/browser smoke test proving browser automation works before task work starts.

Run `./verify-airlock.sh` and record its output as evidence.

If the environment is not airlocked in a way that could materially affect comparability, stop and RETURN before proceeding.

For minor ambiguities that do not materially affect the experiment, make a reasonable decision yourself and record the assumption.

## Evidence Chain

Design the run so findings are cheaply verifiable after the fact.

### Evidence IDs

Assign each material evidence artifact a stable ID as it is captured:

`E001`, `E002`, `E003`, ...

Maintain a neutral `evidence-index.md` with, for each evidence item:

- Evidence ID
- Target/system
- Phase/action
- Timestamp where available
- Evidence type, such as CLI output, browser snapshot, screenshot, HTTP response, artifact, or document
- File/path or URL
- Neutral one-line description of what the evidence contains

Do not put conclusions, severity ratings, or recommendations into `evidence-index.md`.

### Claim-to-Evidence Traceability

Every material factual claim in `findings.md` must cite one or more evidence IDs.

Use this structure where practical:

- **Observed** - directly demonstrated by evidence
- **Inferred** - interpretation that goes beyond direct observation
- **Recommendation** - proposed change based on observed/inferred findings

Where evidence limits, contradicts, or weakens a claim, cite that too.

### Raw Log

Maintain `raw-log.md` as a chronological lab notebook containing:

- action taken,
- literal result,
- timestamp where available,
- referenced evidence IDs.

Keep rationale and interpretation separate from raw evidence when possible.

For mutating commands or state changes whose behavior is ambiguous, capture enough before/after state to determine whether a partial side effect occurred.

### Untested Alternatives

When you encounter a plausible route that could materially change difficulty, time-to-first-value, success, or outcome quality but choose another route, record it explicitly as an untested alternative.

For each alternative, record:

- what the alternative was,
- where it appeared,
- why it remained untested if known,
- evidence ID showing the alternative existed.

Do not invent a post-hoc rationale if the contemporaneous record does not contain one.

## Task Execution

Starting from the verified airlock environment:

1. Determine independently how to accomplish the task using only stock model knowledge plus information/resources discovered during the run.
2. Attempt the task.
3. Log major actions, decisions, friction, dead ends, failed approaches, and recoveries.
4. If you discover and install target-specific tooling during the run, record the discovery source, installation step, version, and resulting configuration as evidence.
5. If blocked, attempt reasonable workarounds within the stated boundaries.
6. Record every point where human intervention or human authority becomes necessary.
7. Verify the finished result independently if successful.
8. Record materially different plausible routes encountered but not tested.

Do not describe friction from one chosen route as inherent to the target unless evidence supports that attribution.

## Boundaries

Follow the task-specific brief. Unless explicitly allowed there, do not:

- spend money or begin a paid subscription,
- violate terms of service,
- circumvent CAPTCHA, identity verification, payment requirements, access controls, anti-abuse systems, or similar safeguards,
- make unrelated external changes,
- publish or send communications to humans except where strictly required for the task,
- misrepresent identity or make legally meaningful attestations on the operator's behalf,
- use credentials, accounts, or private information belonging to the operator unless explicitly provided for this experiment,
- import target credentials/configuration from the host,
- import or read prior experiment findings/traces during the run,
- add target-specific agent skills/MCPs/plugins merely to advantage one target over another unless the experiment explicitly authorizes that comparison.

## Timing

Record timestamps or monotonic elapsed times for:

- start/end of each task attempt,
- significant waits/provisioning periods,
- human RETURN periods,
- final verified success/failure.

If work is parallelized, preserve per-target timing so elapsed time remains reconstructable.

## RETURN

If you hit a blocker:

- Try up to three substantially different, reasonable approaches to overcome it before escalating.
- Do not count repeated variants of essentially the same approach as separate approaches.
- Escalate sooner if proceeding would require crossing a boundary or if the blocker clearly requires human authority/capability.

When escalating, report:

1. what you were trying to accomplish,
2. what is blocking you,
3. what approaches you already tried,
4. what you learned from those attempts,
5. how you classify the blocker: target, harness, environment, agent route choice, human authority, or unknown,
6. the smallest specific thing needed from the human to proceed.

After receiving help, continue autonomously unless another RETURN condition occurs.

## Final Deliverable

After completing the task attempt, produce `findings.md` with:

- executive summary,
- success/failure ground truth,
- final URL/path/artifact/result if successful,
- elapsed time where measurable,
- major steps/decisions,
- significant friction,
- failed approaches,
- recoveries/workarounds,
- human interventions,
- important documentation/resources discovered,
- untested alternative routes,
- evidence IDs for all material factual claims,
- confidence stated separately for success/failure ground truth, friction attribution, comparisons, and major recommendations.
