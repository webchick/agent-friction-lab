# Agent Friction Lab Experiment Brief

Fill this file in for a specific friction lab agent experiment.

For a real run, copy this to `experiment-brief.local.md` and edit that instead —
it's gitignored and automatically preferred over this file when present, so a real
target's name and strategy can't end up committed to this public repo. Use this
tracked file only for a reusable, non-sensitive default brief.

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

Also classify baseline tooling:

- harness-required tools,
- deliberately provided target-task tools,
- incidental tools present in the base image.

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

Set experiment-specific friction lab checks here. Put scenario-specific values in `.friction-lab/config.local.json`; that file is ignored by Git and is automatically preferred by setup and verification when it exists. Use `.friction-lab/config.json` only for reusable defaults that should be committed.

Suggested config fields:

```json
{
  "requiredCommands": ["node", "npm", "git", "curl", "jq", "claude"],
  "agents": [
    {
      "id": "executor",
      "role": "executor",
      "name": "Claude Code",
      "command": "claude",
      "mcpProvider": "claude"
    }
  ],
  "reviewProtocol": {
    "description": "One configured agent executes the experiment and records evidence."
  },
  "forbiddenCommands": [],
  "forbiddenEnvPattern": "",
  "priorTracePattern": "(^|/)(environment|evidence-index|raw-log|findings)\\.md$|(^|/)(evidence|artifacts)(/|$)",
  "npmGlobalPackages": [],
  "playwrightBrowsers": [],
  "playwrightMcpBrowsers": [],
  "mcpServers": []
}
```

Optional local `.friction-lab/env` overrides for temporary shell values:

```sh
FRICTION_LAB_ARCHIVE_ROOT=/path/to/durable/archive
FRICTION_LAB_CONFIG=.friction-lab/some-other-local-profile.json
```

## Tests

Define what counts as success and what counts as failure.

For unsuccessful attempts, state what blocker information should be captured.

## Timing

State which phases require timestamps or elapsed time measurements.

## Final Deliverable

Describe the desired final report shape, or use the default from `agent-runbook.md`.
