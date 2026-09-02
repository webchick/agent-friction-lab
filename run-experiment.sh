#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'EOF'
Usage: ./run-experiment.sh "<scenario description>" [--budget <usd>] [--force]

Runs a full Agent Friction Lab experiment with minimal ceremony: cleans up any
leftover run artifacts, sets up the cross-review config and brief, builds a
fresh disposable container, verifies it, then hands you an interactive
executor session to watch and drive. The executor is the one stage of this
pipeline that hasn't been validated running unattended, so it stays
supervised on purpose -- everything else (setup, review, synthesis, printing
the result) is automatic.

  --budget <usd>   Cap API spend per pipeline stage (default: 15). Ignored if
                   .friction-lab/env already sets FRICTION_LAB_MAX_BUDGET_USD.
  --force          Overwrite an existing experiment-brief.local.md

Run this from inside an existing clone of the harness (same one you'd run
verify-friction-lab.sh from), not a fresh clone each time -- reset happens
automatically as part of this script.

Example:
  ./run-experiment.sh "Sign up for a free trial of Contentful and publish a first content entry."
EOF
}

scenario=""
budget="15"
force=0

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --force) force=1; shift ;;
    --budget)
      budget="${2:-}"
      if [ -z "$budget" ]; then
        printf -- '--budget requires a value\n' >&2
        exit 2
      fi
      shift 2
      ;;
    -*)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
    *)
      if [ -n "$scenario" ]; then
        printf 'Only one scenario argument is supported.\n' >&2
        usage >&2
        exit 2
      fi
      scenario="$1"
      shift
      ;;
  esac
done

if [ -z "$scenario" ]; then
  usage >&2
  exit 2
fi

if [ ! -f "run-friction-lab-experiment.sh" ] || [ ! -f "agent-runbook.md" ]; then
  printf 'Run this from the root of an Agent Friction Lab checkout.\n' >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  printf 'Docker is required. Install it from https://docs.docker.com/get-docker/ and try again.\n' >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  printf "Docker doesn't seem to be running. Start Docker Desktop (or your Docker daemon) and try again.\n" >&2
  exit 1
fi

if ! command -v devcontainer >/dev/null 2>&1; then
  printf 'Installing the Dev Containers CLI (one-time)...\n'
  npm install -g @devcontainers/cli
fi

printf '\n===== Cleaning up any leftover run artifacts =====\n'
./reset-friction-lab-workspace.sh --yes

if [ ! -f ".friction-lab/config.local.json" ]; then
  printf '\nNo .friction-lab/config.local.json found; using the cross-review (executor+reviewer+mediator) profile.\n'
  cp .friction-lab/config.cross-review.example.json .friction-lab/config.local.json
fi

if [ -f "experiment-brief.local.md" ] && [ "$force" -ne 1 ]; then
  printf '\nexperiment-brief.local.md already exists.\n' >&2
  printf 'Re-run with --force to overwrite it with the new scenario, or remove it yourself first.\n' >&2
  exit 1
fi

cat > experiment-brief.local.md <<BRIEF
# Agent Friction Lab Experiment Brief

## Reason

Generated from a one-line scenario via run-experiment.sh; no additional reason
given beyond the Outcome below.

## Outcome

$scenario

## Targets

(infer from Outcome)

## Notes / Exceptions

None. All standing defaults from agent-runbook.md apply in full (Preflight,
Boundaries, Evidence Chain, RETURN protocol) with no scenario-specific
exceptions.
BRIEF

remote_env_args=()
if [ ! -f ".friction-lab/env" ] || ! grep -q '^FRICTION_LAB_MAX_BUDGET_USD=' ".friction-lab/env" 2>/dev/null; then
  remote_env_args=(--remote-env "FRICTION_LAB_MAX_BUDGET_USD=$budget")
fi

printf '\n===== Building/starting the disposable container =====\n'
printf '(First run of a given image can take a while; fast once cached.)\n'
devcontainer up --workspace-folder . --remove-existing-container

printf '\n===== Verifying the environment =====\n'
devcontainer exec --workspace-folder . bash -c "./verify-friction-lab.sh"

printf '\n===== Executor: interactive session =====\n'
printf 'Watch what it does. Exit (Ctrl-D or /exit) once it finishes or RETURNs.\n\n'
devcontainer exec --workspace-folder . "${remote_env_args[@]}" claude \
  "You are the executor agent for this Agent Friction Lab run. Read ./agent-runbook.md and ./experiment-brief.local.md in this directory and follow them exactly, starting with Preflight. Do not skip Preflight."

printf '\n===== Running reviewer + mediator =====\n'
if ! devcontainer exec --workspace-folder . "${remote_env_args[@]}" bash -c "./run-friction-lab-experiment.sh all"; then
  printf '\nReview/synthesis did not complete -- see the output above for why (most likely\n' >&2
  printf 'findings.md was never produced, meaning the executor session ended before\n' >&2
  printf 'finishing or RETURNing). Re-run "devcontainer exec --workspace-folder . claude"\n' >&2
  printf 'to continue that session, then re-run this script with --force to pick up\n' >&2
  printf 'from review onward once findings.md exists.\n' >&2
  exit 1
fi

if [ -f "final-report.md" ]; then
  printf '\n===== RESULTS =====\n\n'
  cat final-report.md
  printf '\nFull evidence trail: findings.md, review.md, evidence/, artifacts/ in this directory.\n'
else
  printf '\nNo final-report.md produced -- check the output above for what happened.\n' >&2
  exit 1
fi
