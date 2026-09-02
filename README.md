# Agent Airlock

Reusable Dev Container harness for airlock agent-readiness experiments.

Use this when you want to observe what happens when a relatively barebones coding agent tries to accomplish a task from a cold workspace and a generic developer environment.

## What It Provides

- Debian Linux + Node.js
- Claude Code
- Config-selected MCP servers applied at container creation
- Optional Playwright MCP and headless Chromium smoke test for browser-based experiments
- Generic developer tools: `git`, `curl`, `jq`, `npm`
- No host home mount, host SSH keys, host Claude config, platform credentials, or platform-specific MCPs/skills
- Experiment-specific MCP servers and checks declared in `.airlock/config.json`
- A verifier script that fails loudly when the airlock assumptions are violated
- A reset script that moves run artifacts out of the active workspace
- A reusable experiment runbook for evidence, logs, findings, and RETURN behavior

## Files

- `.airlock/config.json` - tracked baseline tools, MCPs, and verifier settings
- `.airlock/env.example` - template for local, untracked experiment-specific overrides
- `.airlock/setup-airlock.sh` - installs configured packages/browsers and applies MCP configuration inside the container
- `.devcontainer/` - disposable airlock container definition
- `verify-airlock.sh` - automated preflight verification
- `reset-airlock-workspace.sh` - archive/remove run artifacts from the active workspace
- `agent-runbook.md` - reusable meta-prompt for agents running experiments
- `experiment-brief.md` - task-specific brief template to fill in for each experiment

## Basic Workflow

1. Copy or clone this harness into a new experiment workspace.
2. Edit `experiment-brief.md` with the concrete task/outcome.
3. For private or scenario-specific settings, copy `.airlock/env.example` to `.airlock/env` and edit `.airlock/env`. This file is ignored by Git.
4. Rebuild/reopen the Dev Container.
5. Run `./verify-airlock.sh`.
6. Start the agent experiment only after the verifier passes.
7. Preserve `environment.md`, `raw-log.md`, `evidence-index.md`, `findings.md`, `evidence/`, and `artifacts/` after each run.
8. Run `./reset-airlock-workspace.sh --yes` before the next airlock attempt.

## Optional Verification Settings

The verifier is intentionally generic. For reusable defaults, edit `.airlock/config.json`:

```json
{
  "requiredCommands": ["node", "npm", "git", "curl", "jq", "claude"],
  "forbiddenCommands": ["example-cli"],
  "forbiddenEnvPattern": "EXAMPLE_VENDOR|ANOTHER_VENDOR",
  "allowedMcpServers": ["playwright"],
  "npmGlobalPackages": ["playwright", "@playwright/mcp"],
  "playwrightBrowsers": ["chromium"],
  "playwrightMcpBrowsers": ["chrome-for-testing"],
  "mcpServers": [
    {
      "name": "playwright",
      "command": "playwright-mcp",
      "args": ["--isolated", "--headless", "--browser", "chromium", "--no-sandbox"],
      "requiredCommands": ["playwright", "playwright-mcp"],
      "smokeTest": "example.com-accessibility-snapshot"
    }
  ]
}
```

Local environment overrides are safer for private or scenario-specific runs. Copy `.airlock/env.example` to `.airlock/env`, then set values such as:

```sh
AIRLOCK_FORBIDDEN_COMMANDS="example-cli another-cli"
AIRLOCK_FORBIDDEN_ENV_PATTERN="EXAMPLE_VENDOR|ANOTHER_VENDOR"
AIRLOCK_ALLOWED_MCP_SERVERS="playwright"
```

`.airlock/env` is ignored by Git so local experiment details do not accidentally get committed to the public harness repo.

The sample config enables Playwright MCP because browser automation is a common experiment need. Remove it from `npmGlobalPackages`, `playwrightBrowsers`, `playwrightMcpBrowsers`, `mcpServers`, and `allowedMcpServers` for a shell-only airlock.

A shell-only example is available at `.airlock/config.shell-only.example.json`.

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
