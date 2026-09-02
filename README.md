# Agent Airlock

Reusable Dev Container harness for airlock agent-readiness experiments.

Use this when you want to observe what happens when a relatively barebones coding agent tries to accomplish a task from a cold workspace and a generic developer environment.

## What It Provides

- Debian Linux + Node.js
- Config-selected agent/tooling installed at container creation
- Config-selected MCP servers applied at container creation
- Optional Playwright MCP and headless Chromium smoke test for browser-based experiments
- Generic developer tools: `git`, `curl`, `jq`, `npm`
- No host home mount, host SSH keys, host Claude config, platform credentials, or platform-specific MCPs/skills
- Experiment-specific MCP servers and checks declared in ignored local config
- A verifier script that fails loudly when the airlock assumptions are violated
- A reset script that moves run artifacts out of the active workspace
- A reusable experiment runbook for evidence, logs, findings, and RETURN behavior

## Files

- `.airlock/config.json` - tracked default profile and reusable example settings
- `.airlock/config.local.json` - optional ignored experiment profile; automatically used when present
- `.airlock/env.example` - template for advanced local environment overrides
- `.airlock/setup-airlock.sh` - installs configured packages/browsers and applies MCP configuration inside the container
- `.devcontainer/` - disposable airlock container definition
- `verify-airlock.sh` - automated preflight verification
- `reset-airlock-workspace.sh` - archive/remove run artifacts from the active workspace
- `agent-runbook.md` - reusable meta-prompt for agents running experiments
- `experiment-brief.md` - task-specific brief template to fill in for each experiment

## Basic Workflow

1. Copy or clone this harness into a new experiment workspace.
2. Edit `experiment-brief.md` with the concrete task/outcome.
3. Copy `.airlock/config.json` to `.airlock/config.local.json` and edit the local file for the experiment.
4. Rebuild/reopen the Dev Container.
5. Run `./verify-airlock.sh`.
6. Start the agent experiment only after the verifier passes.
7. Preserve `environment.md`, `raw-log.md`, `evidence-index.md`, `findings.md`, `evidence/`, and `artifacts/` after each run.
8. Run `./reset-airlock-workspace.sh --yes` before the next airlock attempt.

`.airlock/config.local.json` is ignored by Git and automatically preferred by setup and verification when it exists. Use it for all scenario-specific tool, MCP, package, forbidden-command, and forbidden-environment settings, even if they do not seem private yet.

Use `.airlock/env` only for advanced overrides that are easier as shell values, such as `AIRLOCK_ARCHIVE_ROOT` or temporarily pointing `AIRLOCK_CONFIG` at a differently named file.

## Optional Verification Settings

The verifier is intentionally generic. For each experiment, edit `.airlock/config.local.json`:

```json
{
  "requiredCommands": ["node", "npm", "git", "curl", "jq", "claude"],
  "agent": {
    "name": "Claude Code",
    "command": "claude",
    "mcpProvider": "claude"
  },
  "forbiddenCommands": ["example-cli"],
  "forbiddenEnvPattern": "EXAMPLE_VENDOR|ANOTHER_VENDOR",
  "allowedMcpServers": ["playwright"],
  "npmGlobalPackages": ["@anthropic-ai/claude-code", "playwright", "@playwright/mcp"],
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

Optional environment overrides are available for local shell-only tweaks. Copy `.airlock/env.example` to `.airlock/env`, then set values such as:

```sh
AIRLOCK_ARCHIVE_ROOT=/path/to/durable/archive
AIRLOCK_FORBIDDEN_COMMANDS="example-cli another-cli"
AIRLOCK_FORBIDDEN_ENV_PATTERN="EXAMPLE_VENDOR|ANOTHER_VENDOR"
AIRLOCK_ALLOWED_MCP_SERVERS="playwright"
```

`.airlock/env` and `.airlock/config.local.json` are ignored by Git so local experiment details do not accidentally get committed to the public harness repo.

The default config enables Claude Code plus Playwright MCP because browser automation is a common experiment need. Remove or replace the agent, package, browser, MCP, and allowed-server entries for a different agent or a shell-only airlock.

Examples are available at `.airlock/config.claude-playwright.example.json` and `.airlock/config.shell-only.example.json`.

## Baseline Bias

The default Dev Container includes Node.js because the sample agent and MCP tooling are installed through npm. Treat that as harness plumbing, not as a claim that JavaScript is part of every fair target baseline.

This distinction can still matter. Node/npm availability may advantage JavaScript-native targets, just as adding PHP, Python, Composer, or other ecosystem tools may advantage their native stacks. For comparative experiments, document which tools are required for the harness, which tools are deliberately provided for the target task, and which tools are merely incidental to the base image.

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
