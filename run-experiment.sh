#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'EOF'
Usage: ./run-experiment.sh ["<scenario description>"] [--budget <usd>] [--force]

Runs a full Agent Friction Lab experiment with minimal ceremony: cleans up any
leftover run artifacts, sets up the brief, builds a fresh disposable container
(barebones cross-review by default -- no browser automation unless a branch
adds it, see docs/branching-design.md), verifies it, then hands you an
interactive executor session to watch and drive. The executor is the one
stage of this pipeline that hasn't been validated running unattended, so it
stays supervised on purpose -- everything else (setup, review, synthesis,
printing the result) is automatic.

Two ways to use it:
  - Quick/exploratory: pass a scenario description and a minimal brief gets
    generated from it (Outcome only, everything else defaults).
  - Rigorous/benchmark: write a full experiment-brief.local.md by hand first
    (Targets, Starting Conditions, Allowed Resources, Off-Limits, Tests, Timing
    -- the complete template in experiment-brief.md), then run this with no
    scenario argument at all. The existing brief is used as-is.

  --budget <usd>   Cap API spend per pipeline stage (default: 15). Ignored if
                   .friction-lab/env already sets FRICTION_LAB_MAX_BUDGET_USD.
  --force          Overwrite an existing experiment-brief.local.md with a new
                   scenario (requires passing one)

Run this from inside an existing clone of the harness (same one you'd run
verify-friction-lab.sh from), not a fresh clone each time -- reset happens
automatically as part of this script.

Examples:
  ./run-experiment.sh "Sign up for a free trial of Contentful and publish a first content entry."
  ./run-experiment.sh   # uses the experiment-brief.local.md you already wrote
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

if [ ! -f "run-friction-lab-experiment.sh" ] || [ ! -f "agent-runbook.md" ]; then
  printf 'Run this from the root of an Agent Friction Lab checkout.\n' >&2
  exit 1
fi

brief_exists=0
[ -f "experiment-brief.local.md" ] && brief_exists=1

if [ -z "$scenario" ] && { [ "$brief_exists" -eq 0 ] || [ "$force" -eq 1 ]; }; then
  printf 'A scenario description is required unless experiment-brief.local.md already exists (and --force is not set).\n' >&2
  usage >&2
  exit 2
fi

if [ "$brief_exists" -eq 1 ] && [ "$force" -ne 1 ] && [ -n "$scenario" ]; then
  printf 'experiment-brief.local.md already exists; using it as-is and ignoring the scenario argument.\n' >&2
  printf 'Pass --force to overwrite it with the new scenario instead.\n' >&2
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

if [ "$brief_exists" -eq 0 ] || [ "$force" -eq 1 ]; then
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
else
  printf 'Using existing experiment-brief.local.md.\n'
fi

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
printf 'Watch what it does. When it finishes or RETURNs, type /exit (or Ctrl-D) to\n'
printf 'close this session -- review and synthesis run automatically right after.\n\n'
devcontainer exec --workspace-folder . "${remote_env_args[@]}" claude \
  "You are the executor agent for this Agent Friction Lab run. Read ./agent-runbook.md and ./experiment-brief.local.md in this directory and follow them exactly, starting with Preflight. Do not skip Preflight. When you have finished (task complete, or you've recorded a STOP per the RETURN protocol), end your final message by telling the human to type /exit (or Ctrl-D) to close this session -- reviewer and mediator run automatically the moment it closes, so don't suggest they run run-friction-lab-experiment.sh manually."

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
