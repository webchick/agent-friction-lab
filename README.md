# Agent Friction Lab

Reusable Dev Container harness for friction lab agent-readiness experiments.

Use this when you want to observe what happens when a relatively barebones coding agent tries to accomplish a task from a cold workspace and a generic developer environment.

## Quickstart

You need Docker. This walks through the terminal path; see [Prefer VS Code?](#prefer-vs-code) below for the GUI equivalent.

```bash
git clone https://github.com/webchick/agent-friction-lab.git
cd agent-friction-lab
cp .friction-lab/config.json .friction-lab/config.local.json
npm install -g @devcontainers/cli
```

Edit `experiment-brief.md` and `.friction-lab/config.local.json` for your test.

Clone into a fresh directory like this, rather than opening an existing checkout of this repo. If your existing checkout's `origin` remote uses the SSH form (`git@github.com:...`), any git operation that touches it inside the container — a fetch, a shell prompt's git-ahead/behind check, an editor's background fetch — will write to `~/.ssh/known_hosts` and fail `verify-friction-lab.sh`'s clean-SSH-state checks, even though no SSH keys are present to actually authenticate. A plain HTTPS clone like the one above has no SSH remote to trigger that.

Then start the disposable test environment:

```bash
devcontainer up --workspace-folder . --remove-existing-container
```

Open a shell in the container:

```bash
devcontainer exec --workspace-folder . bash
```

From inside that shell, run:

```bash
./verify-friction-lab.sh
```

Start the agent experiment only after verification passes. That same `devcontainer exec` shell is also where you drive the executor interactively and run `run-friction-lab-experiment.sh` — reopen it any time with the command above.

### Prefer VS Code?

If you'd rather drive the container from an editor than the terminal, install VS Code with the Dev Containers extension instead of the Dev Containers CLI, then:

1. Run **Git: Clone** from the command palette and clone `https://github.com/webchick/agent-friction-lab.git`.
2. Open the cloned folder in VS Code.
3. Open a VS Code terminal in that folder and run:

```bash
cp .friction-lab/config.json .friction-lab/config.local.json
```

4. Edit `experiment-brief.md` and `.friction-lab/config.local.json` for your test.
5. Run **Dev Containers: Rebuild and Reopen in Container** from the command palette.
6. In the container's integrated terminal, run `./verify-friction-lab.sh`.

Everything past this point — the scripts, the pipeline, the evidence files — is identical either way; VS Code only changes how you launch and browse the container.

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
- `run-friction-lab-experiment.sh` - runs the executor/reviewer/mediator pipeline
- `reset-friction-lab-workspace.sh` - archive/remove run artifacts from the active workspace
- `agent-runbook.md` - reusable meta-prompt for agents running experiments
- `experiment-brief.md` - task-specific brief template to fill in for each experiment
- `examples/pipeline-smoke-test/` - real, worked example of executor/reviewer/mediator output

## Basic Workflow

1. Copy or clone this harness into a new experiment workspace.
2. Edit `experiment-brief.md` with the concrete task/outcome.
3. Copy `.friction-lab/config.json` to `.friction-lab/config.local.json` and edit the local file for the experiment.
4. Restart the disposable Dev Container so the local config is applied.
5. Run `./verify-friction-lab.sh`.
6. Start the agent experiment only after the verifier passes: run `./run-friction-lab-experiment.sh` for the executor/reviewer/mediator pipeline, or drive the executor interactively yourself and run `./run-friction-lab-experiment.sh review` (or `synthesize`) once `findings.md` exists.
7. Preserve `environment.md`, `raw-log.md`, `evidence-index.md`, `findings.md`, `review.md`, `final-report.md`, `evidence/`, and `artifacts/` after each run.
8. Run `./reset-friction-lab-workspace.sh --yes` before the next friction lab attempt.

`.friction-lab/config.local.json` is ignored by Git and automatically preferred by setup and verification when it exists. Use it for all scenario-specific tool, MCP, package, forbidden-command, and forbidden-environment settings, even if they do not seem private yet.

Use `.friction-lab/env` only for advanced overrides that are easier as shell values, such as `FRICTION_LAB_ARCHIVE_ROOT` or temporarily pointing `FRICTION_LAB_CONFIG` at a differently named file.

## Restarting The Test Environment

The Dev Container is the disposable Linux workspace where the agent runs. Restarting it means throwing away the old container and creating a fresh one from this repository's `.devcontainer/` settings.

From the terminal, use the Dev Containers CLI commands below. In VS Code, use **Dev Containers: Rebuild and Reopen in Container** from the command palette instead.

## Dev Container CLI

Quickstart above covers installing the Dev Containers CLI and the everyday `devcontainer up --remove-existing-container` restart. For a no-cache image rebuild:

```bash
devcontainer build --workspace-folder . --no-cache
devcontainer up --workspace-folder . --remove-existing-container
```

Then open a shell (`devcontainer exec --workspace-folder . bash`, as in Quickstart above) and run `./verify-friction-lab.sh`.

## Config Format

Configuration is JSON because the setup and verifier scripts can read it with `jq`, which is already part of the generic baseline. YAML would be friendlier for some people, but it would add another parser/tool dependency to the clean environment. The expected workflow is that a human or agent copies an example config, edits the few fields needed for the experiment, and lets `./verify-friction-lab.sh` catch mistakes before the run begins.

## Optional Verification Settings

The verifier is intentionally generic. For each experiment, edit `.friction-lab/config.local.json`:

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
  "forbiddenCommands": ["example-cli"],
  "forbiddenEnvPattern": "EXAMPLE_VENDOR|ANOTHER_VENDOR",
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

The expected-MCP-server list the verifier checks against is derived from `mcpServers[].name` in the resolved config, so it can't drift out of sync with what's actually declared; `FRICTION_LAB_ALLOWED_MCP_SERVERS` only needs setting to override that derived list for an unusual case (for example, an MCP server that's expected to already be configured outside this repo's `mcpServers[]`).

`.friction-lab/env` and `.friction-lab/config.local.json` are ignored by Git so local experiment details do not accidentally get committed to the public harness repo.

The default config enables Claude Code plus Playwright MCP because browser automation is a common experiment need. Remove or replace the agents, package, browser, and MCP entries for a different agent or a shell-only friction lab.

Examples are available at `.friction-lab/config.claude-playwright.example.json`, `.friction-lab/config.cross-review.example.json`, and `.friction-lab/config.shell-only.example.json`.

## Agent Roles And Review

Use `agents` to declare the roles participating in the experiment. Common roles are:

- `executor`: the agent that attempts the task.
- `reviewer`: an agent that independently examines the executor's evidence and produces its own findings.
- `mediator`: an agent that reconciles the executor's and reviewer's findings into a cited final report, surfacing disagreements rather than resolving them.
- `observer`: a non-executing role that records or summarizes behavior.

Use `reviewProtocol` to describe the expected handoff pattern. A cross-review run uses Claude Code as the executor inside the container, then hands `environment.md`, `raw-log.md`, `evidence-index.md`, `findings.md`, `evidence/`, and `artifacts/` to a second, isolated Claude Code invocation as reviewer, and finally to a third as mediator. `command` is a free string, so a different external CLI agent can be substituted for `reviewer` or `mediator` instead. See `.friction-lab/config.cross-review.example.json` for the full three-role profile, and `run-friction-lab-experiment.sh` for the script that runs it end to end.

Reviewer and mediator agents do not have to run inside the same container as the executor, and even inside the same container they run in their own working directory containing only copies of the handoff artifacts — never the executor's live session or working tree. Keeping them isolated reduces cross-contamination: the executor's container/working tree remains the measured environment, while the reviewer and mediator inspect only the recorded evidence. Both run with shell/code execution, web search/fetch, and MCP tools disabled (`claude --restricted --strict-mcp-config` for the Claude Code profile), so they can only reason from what was recorded, not go re-verify or re-research the task themselves. If an experiment intentionally needs two agents sharing a container, declare both as required installed agents and document that shared environment as part of the baseline.

This is related to multi-agent debate, adversarial collaboration, and cross-examination patterns. The goal is not to make agents argue theatrically; it is to make claims easier to verify before a human has to make a decision.

## Running The Experiment Pipeline

`run-friction-lab-experiment.sh` runs the executor/reviewer/mediator pipeline declared in the resolved config. It takes one subcommand:

```bash
./run-friction-lab-experiment.sh execute      # run the executor, if findings.md does not already exist
./run-friction-lab-experiment.sh review       # run the reviewer against the handoff artifacts
./run-friction-lab-experiment.sh synthesize   # run the mediator against findings.md + review.md
./run-friction-lab-experiment.sh all          # execute, review, synthesize in sequence (default)
```

`execute` only launches Claude Code headlessly with full tool access if you pass `--unattended`; otherwise, if `findings.md` is missing, it stops and tells you to either drive the executor interactively yourself (as documented above) or re-run with `--unattended`. This keeps unattended full-tool-access runs an explicit choice rather than a script default. `review` and `synthesize` always run headless and isolated, since they only need read access to already-captured evidence.

Each stage's working artifacts live under `review/<timestamp>/`; `reset-friction-lab-workspace.sh` sweeps that directory along with the other run artifacts.

See `examples/pipeline-smoke-test/` for real, unedited output from all three stages — including a deliberately planted evidence defect and how the reviewer and mediator handle it.

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
