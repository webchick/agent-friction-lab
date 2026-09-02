# Agent Friction Lab Agent Experiment Runbook

Use this runbook with a task-specific brief. Do not begin the task until preflight passes.

## Preflight

Before starting task work, verify and record that the environment matches the intended friction lab conditions.

The environment should begin with:

- no pre-authenticated target accounts,
- no target-specific CLIs or SDKs unless explicitly part of the baseline being tested,
- no saved browser sessions,
- no target-specific MCP servers, connectors, plugins, agent skills, or injected product documentation,
- no prior experiment traces or findings visible in the active workspace,
- no host SSH keys or target credentials,
- browser automation available from the beginning,
- generic shell, git, package manager, curl, jq, and web access available.

Connectors (Gmail, Google Calendar, Google Drive, and similar first-party integrations) are tied to the authenticated account, not to container/filesystem state — rebuilding the container does not remove them if the agent authenticates as the same account each time. The devcontainer sets `ENABLE_CLAUDEAI_MCP_SERVERS=false` to prevent them from loading at all for a Claude Code executor, but check for them explicitly anyway (`claude mcp list` or the equivalent for the configured agent), not just for locally-configured MCP servers — this is a real environment defect, not a hypothetical one, found during this harness's own validation, and the check should not depend solely on that one setting continuing to be present and effective. Account-level access to a real inbox or drive can materially change how much real-world friction a task actually has (e.g. reading a signup verification email directly instead of experiencing that step as friction).

If the sandbox or permission system blocks a direct manual check of one of these facts (for example, denying a raw read of `~/.ssh` or `~/.claude.json`), it's fine to rely on `./verify-friction-lab.sh`'s own already-authorized check of the same fact instead of repeatedly retrying a blocked command — but record in `raw-log.md` that this happened and why, rather than silently treating a denied check as equivalent to one you actually performed yourself.

The exact allowed MCP servers, extra required commands, forbidden commands, forbidden environment patterns, and prior-run trace patterns are declared in `.friction-lab/config.json`.

The model's stock training knowledge is allowed and is part of the real-world test. Treat this as a cold-context and cold-environment test, not a literal test of zero prior model knowledge.

Before touching the target task, create `environment.md` containing literal outputs of checks for at least:

- OS and architecture,
- current working directory and `$HOME`,
- required generic tools,
- absence of target-specific tools named in the task brief,
- relevant target/vendor environment variables,
- contents of `~/.ssh` if present,
- files visible in the workspace,
- configured MCP servers/connectors/plugins/skills,
- a harmless Playwright/browser smoke test proving browser automation works before task work starts.

Run `./verify-friction-lab.sh` and record its output as evidence.

If the environment is not friction-lab-ready in a way that could materially affect comparability, stop and RETURN before proceeding.

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

Assign an ID to every artifact the findings actually rely on, not just a representative subset — an unindexed screenshot in `artifacts/` that the narrative leans on is exactly as unverifiable to a reviewer as a claim with no evidence ID at all. Before finalizing `evidence-index.md`, re-open each image/file and confirm its content actually matches its filename and description — a mislabeled screenshot is worse than no screenshot, since it looks verified when it isn't.

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

When recording a form fill or similar structured input, log every field actually entered, including ones that seem incidental — a field that's visible in a screenshot but absent from the log breaks traceability for exactly that detail if it later turns out to matter.

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

Starting from the verified friction lab environment:

1. Determine independently how to accomplish the task using only stock model knowledge plus information/resources discovered during the run.
2. Attempt the task.
3. Log major actions, decisions, friction, dead ends, failed approaches, and recoveries.
4. If you discover and install target-specific tooling during the run, record the discovery source, installation step, version, and resulting configuration as evidence.
5. If blocked, attempt reasonable workarounds within the stated boundaries.
6. Record every point where human intervention or human authority becomes necessary.
7. Verify the finished result independently if successful.
8. Record materially different plausible routes encountered but not tested.

Do not describe friction from one chosen route as inherent to the target unless evidence supports that attribution.

## Cross-Review

If the experiment config declares a cross-review or multi-agent review protocol, preserve the handoff artifacts before asking the reviewer to evaluate the run.

Reviewer agents may be external to the executor container. This preserves the executor container as the measured environment and limits the reviewer to the evidence record. If multiple agents intentionally run inside the same container, record that shared environment in `environment.md`. At minimum, the reviewer runs in its own working directory containing only copies of the handoff artifacts below, not the executor's live session or working tree.

The reviewer must reason only from the recorded evidence: no shell/code execution, no web search or fetch, no MCP tools, no re-running or re-verifying the task itself. If a claim cannot be checked from the handoff artifacts alone, say so rather than going to find out.

The executor should provide:

- `environment.md`,
- `raw-log.md`,
- `evidence-index.md`,
- `findings.md`,
- relevant files under `evidence/` and `artifacts/`.

The reviewer should:

- verify that findings are supported by evidence IDs,
- distinguish observed facts from inferences and recommendations,
- challenge claims that rely on missing or weak evidence,
- identify places where a different reasonable path might have changed the outcome,
- return specific follow-up questions or escalation points rather than silently rewriting the executor's conclusions.

Use the review as a cross-examination step before human escalation, not as an automatic override.

The reviewer produces `review.md`, structured like `findings.md` (Observed / Inferred / Recommendation, each citing evidence IDs), covering the points above.

## Synthesis

If the experiment config declares a mediator role, the mediator runs after the reviewer, in its own working directory containing `environment.md`, `raw-log.md`, `findings.md`, `review.md`, `evidence-index.md`, `evidence/`, `artifacts/`, `agent-runbook.md`, and `experiment-brief.md` — the full evidence chain, not just the two conclusions documents, so the mediator can independently check a reviewer claim about `raw-log.md` or `environment.md` rather than taking it on trust. The same restriction applies as for the reviewer: reasoning only from the recorded evidence and the two prior documents, no shell/code execution, no web search or fetch, no MCP tools.

The mediator's job is to reconcile the executor's and reviewer's conclusions, not to referee a winner. Where the two disagree, surface the disagreement to the human with both sides' evidence cited rather than silently resolving it.

The mediator produces `final-report.md` containing:

- executive summary,
- ground truth (success/failure) with confidence, noting whether executor and reviewer agree,
- points of agreement between `findings.md` and `review.md`, cited,
- points of disagreement between `findings.md` and `review.md`, cited from both sides, left unresolved rather than picked,
- reconciled recommendations, cited,
- open follow-up or escalation questions for the human reviewer.

This is the document a human reviewer should read first; `findings.md` and `review.md` are its supporting record.

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

"Circumvent" applies to the outcome, not the technique. An anti-abuse check like CAPTCHA exists to gate an action behind proof of non-automation, so an automated system passing it counts as circumvention regardless of whether the specific means was a technical exploit, fingerprint evasion, a third-party solving service, or the agent's own vision solving the puzzle as shown — the technique doesn't change the category of outcome. Do not attempt any of these by default; record the block and RETURN. If a specific experiment's brief explicitly authorizes attempting a visible interactive challenge as the deliberate subject of that experiment (an `Allowed Resources` entry decided up front, not an in-the-moment RETURN choice), that authorization governs instead.

Creating a new account with a third-party identity provider (GitHub, Google, or similar) is out of scope by default alongside using the operator's own credentials, even a fresh account with no operator-identifying information. This isn't about misrepresenting identity — it's that doing so requires autonomously accepting that provider's own terms of service and standing up a persistent account relationship with a second company, a materially bigger and more consequential act than something like a disposable email inbox, which is receive-only and creates no account or ToS relationship at all. A disposable email is fine under the "no operator credentials" item above; a disposable OAuth account is not, unless the experiment's brief explicitly authorizes provisioning one as part of its baseline.

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
