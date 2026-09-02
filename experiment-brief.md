# Airlock Experiment Brief

Fill this file in for a specific airlock agent experiment.

## Reason

Why are we running this experiment? What assumption, workflow, product experience, or agent-readiness question are we trying to understand?

## Outcome

What should the agent try to accomplish?

Define concrete success criteria. Include observable verification requirements, such as:

- final URL, file, artifact, or system state,
- exact text or behavior that must be visible,
- independent verification method,
- expected evidence to capture.

## Targets

List the product, system, platform, repository, workflow, or environment under test.

If there are multiple targets, state whether they should be tested sequentially or in parallel.

## Starting Conditions

State what should and should not exist at the beginning of the run.

Examples:

- no pre-authenticated target accounts,
- no target-specific CLIs,
- no target-specific credentials,
- no prior run artifacts in the active workspace,
- generic developer tooling available,
- browser automation available from the beginning.

## Allowed Resources

State what the agent may use.

Examples:

- public documentation,
- public repositories,
- search engines,
- account creation,
- provided credentials,
- paid services,
- target-specific CLI installation if discovered during the run.

## Off-Limits

State what the agent must not do.

Examples:

- spend money,
- use host credentials,
- bypass verification or anti-abuse controls,
- import prior findings,
- install target-specific MCPs/skills unless explicitly authorized.

## Preflight Additions

Set experiment-specific airlock checks here. Prefer local overrides in `.airlock/env` for private or scenario-specific values; that file is ignored by Git. Use `.airlock/config.json` for reusable defaults that should be committed.

Suggested config fields:

```json
{
  "requiredCommands": ["node", "npm", "git", "curl", "jq", "claude"],
  "forbiddenCommands": [],
  "forbiddenEnvPattern": "",
  "priorTracePattern": "(^|/)(environment|evidence-index|raw-log|findings)\\.md$|(^|/)(evidence|artifacts)(/|$)",
  "allowedMcpServers": ["playwright"],
  "npmGlobalPackages": [],
  "playwrightBrowsers": [],
  "playwrightMcpBrowsers": [],
  "mcpServers": []
}
```

Optional local `.airlock/env` overrides:

```sh
export AIRLOCK_FORBIDDEN_COMMANDS=""
export AIRLOCK_FORBIDDEN_ENV_PATTERN=""
export AIRLOCK_PRIOR_TRACE_PATTERN=""
export AIRLOCK_ALLOWED_MCP_SERVERS="playwright"
./verify-airlock.sh
```

## Tests

Define what counts as success and what counts as failure.

For unsuccessful attempts, state what blocker information should be captured.

## Timing

State which phases require timestamps or elapsed time measurements.

## Final Deliverable

Describe the desired final report shape, or use the default from `agent-runbook.md`.
