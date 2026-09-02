# Agent Friction Lab

Reusable Dev Container harness for friction lab agent-readiness experiments.

Use this when you want to observe what happens when a relatively barebones coding agent tries to accomplish a task from a cold workspace and a generic developer environment.

## What It Provides

- Debian Linux + Node.js
- Config-selected agent/tooling installed at container creation
- Config-selected MCP servers applied at container creation
- Optional Playwright MCP and headless Chromium smoke test for browser-based experiments
- Generic developer tools: `git`, `curl`, `jq`, `npm`
- No host home mount, host SSH keys, host Claude config, platform credentials, or platform-specific MCPs/skills
- Experiment-specific MCP servers and checks declared in ignored local config
- A verifier script that fails loudly when the friction lab assumptions are violated
- A reset script that moves run artifacts out of the active workspace
- A reusable experiment runbook for evidence, logs, findings, and RETURN behavior

## Files

- `.friction-lab/config.json` - tracked default profile and reusable example settings
- `.friction-lab/config.local.json` - optional ignored experiment profile; automatically used when present
- `.friction-lab/env.example` - template for advanced local environment overrides
- `.friction-lab/setup-friction-lab.sh` - installs configured packages/browsers and applies MCP configuration inside the container
- `.devcontainer/` - disposable friction lab container definition
- `verify-friction-lab.sh` - automated preflight verification
- `reset-friction-lab-workspace.sh` - archive/remove run artifacts from the active workspace
- `agent-runbook.md` - reusable meta-prompt for agents running experiments
- `experiment-brief.md` - task-specific brief template to fill in for each experiment

## Basic Workflow

1. Copy or clone this harness into a new experiment workspace.
2. Edit `experiment-brief.md` with the concrete task/outcome.
3. Copy `.friction-lab/config.json` to `.friction-lab/config.local.json` and edit the local file for the experiment.
4. Restart the disposable Dev Container so the local config is applied.
5. Run `./verify-friction-lab.sh`.
6. Start the agent experiment only after the verifier passes.
7. Preserve `environment.md`, `raw-log.md`, `evidence-index.md`, `findings.md`, `evidence/`, and `artifacts/` after each run.
8. Run `./reset-friction-lab-workspace.sh --yes` before the next friction lab attempt.

`.friction-lab/config.local.json` is ignored by Git and automatically preferred by setup and verification when it exists. Use it for all scenario-specific tool, MCP, package, forbidden-command, and forbidden-environment settings, even if they do not seem private yet.

Use `.friction-lab/env` only for advanced overrides that are easier as shell values, such as `FRICTION_LAB_ARCHIVE_ROOT` or temporarily pointing `FRICTION_LAB_CONFIG` at a differently named file.

## Restarting The Test Environment

The Dev Container is the disposable Linux workspace where the agent runs. Restarting it means throwing away the old container and creating a fresh one from this repository's `.devcontainer/` settings.

In VS Code, use **Dev Containers: Rebuild and Reopen in Container** from the command palette.

From the terminal, use the Dev Containers CLI commands below.

## Dev Container CLI

If you prefer the terminal to VS Code's command palette, install the Dev Containers CLI:

```bash
npm install -g @devcontainers/cli
```

Start or rebuild the container from the repository root:

```bash
devcontainer up --workspace-folder . --remove-existing-container
```

For a no-cache image rebuild:

```bash
devcontainer build --workspace-folder . --no-cache
devcontainer up --workspace-folder . --remove-existing-container
```

Then open a shell in the container and run:

```bash
./verify-friction-lab.sh
```

## Config Format

Configuration is JSON because the setup and verifier scripts can read it with `jq`, which is already part of the generic baseline. YAML would be friendlier for some people, but it would add another parser/tool dependency to the clean environment. The expected workflow is that a human or agent copies an example config, edits the few fields needed for the experiment, and lets `./verify-friction-lab.sh` catch mistakes before the run begins.

## Optional Verification Settings

The verifier is intentionally generic. For each experiment, edit `.friction-lab/config.local.json`:

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

Optional environment overrides are available for local shell-only tweaks. Copy `.friction-lab/env.example` to `.friction-lab/env`, then set values such as:

```sh
FRICTION_LAB_ARCHIVE_ROOT=/path/to/durable/archive
FRICTION_LAB_FORBIDDEN_COMMANDS="example-cli another-cli"
FRICTION_LAB_FORBIDDEN_ENV_PATTERN="EXAMPLE_VENDOR|ANOTHER_VENDOR"
FRICTION_LAB_ALLOWED_MCP_SERVERS="playwright"
```

`.friction-lab/env` and `.friction-lab/config.local.json` are ignored by Git so local experiment details do not accidentally get committed to the public harness repo.

The default config enables Claude Code plus Playwright MCP because browser automation is a common experiment need. Remove or replace the agent, package, browser, MCP, and allowed-server entries for a different agent or a shell-only friction lab.

Examples are available at `.friction-lab/config.claude-playwright.example.json` and `.friction-lab/config.shell-only.example.json`.

## Baseline Bias

The default Dev Container includes Node.js because the sample agent and MCP tooling are installed through npm. Treat that as harness plumbing, not as a claim that JavaScript is part of every fair target baseline.

This distinction can still matter. Node/npm availability may advantage JavaScript-native targets, just as adding PHP, Python, Composer, or other ecosystem tools may advantage their native stacks. For comparative experiments, document which tools are required for the harness, which tools are deliberately provided for the target task, and which tools are merely incidental to the base image.

## Resetting Between Runs

Dry run:

```bash
./reset-friction-lab-workspace.sh
```

Perform reset:

```bash
./reset-friction-lab-workspace.sh --yes
```

By default, artifacts are moved to `/private/tmp/agent-friction-lab-archives/<timestamp>/`. Set `FRICTION_LAB_ARCHIVE_ROOT` to use a durable host path or a separate Git checkout.
