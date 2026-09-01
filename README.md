# Agent Airlock

Reusable Dev Container harness for airlock agent-readiness experiments.

Use this when you want to observe what happens when a relatively barebones coding agent tries to accomplish a task from a cold workspace and a generic developer environment.

## What It Provides

- Debian Linux + Node.js
- Claude Code
- Playwright MCP configured at container creation
- Headless Chromium verified both directly and through Playwright MCP
- Generic developer tools: `git`, `curl`, `jq`, `npm`
- No host home mount, host SSH keys, host Claude config, platform credentials, or platform-specific MCPs/skills
- A verifier script that fails loudly when the airlock assumptions are violated
- A reset script that moves run artifacts out of the active workspace
- A reusable experiment runbook for evidence, logs, findings, and RETURN behavior

## Files

- `.devcontainer/` - disposable airlock container definition
- `verify-airlock.sh` - automated preflight verification
- `reset-airlock-workspace.sh` - archive/remove run artifacts from the active workspace
- `agent-runbook.md` - reusable meta-prompt for agents running experiments
- `experiment-brief.md` - task-specific brief template to fill in for each experiment

## Basic Workflow

1. Copy or clone this harness into a new experiment workspace.
2. Edit `experiment-brief.md` with the concrete task/outcome.
3. Rebuild/reopen the Dev Container.
4. Run `./verify-airlock.sh`.
5. Start the agent experiment only after the verifier passes.
6. Preserve `environment.md`, `raw-log.md`, `evidence-index.md`, `findings.md`, `evidence/`, and `artifacts/` after each run.
7. Run `./reset-airlock-workspace.sh --yes` before the next airlock attempt.

## Optional Verification Settings

The verifier is intentionally generic. For a particular experiment, you can add stricter checks through environment variables:

```bash
AIRLOCK_FORBIDDEN_COMMANDS="example-cli another-cli" ./verify-airlock.sh
AIRLOCK_FORBIDDEN_ENV_PATTERN="EXAMPLE_VENDOR|ANOTHER_VENDOR" ./verify-airlock.sh
AIRLOCK_ALLOWED_MCP_SERVERS="playwright" ./verify-airlock.sh
```

By default, the only allowed Claude MCP server is `playwright`.

## Resetting Between Runs

Dry run:

```bash
./reset-airlock-workspace.sh
```

Perform reset:

```bash
./reset-airlock-workspace.sh --yes
```

By default, artifacts are moved to `/private/tmp/agent-airlock-archives/<timestamp>/`. Set `AIRLOCK_ARCHIVE_ROOT` to use a durable host path or a separate Git checkout.
