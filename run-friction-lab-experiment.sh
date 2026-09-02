#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'EOF'
Usage: ./run-friction-lab-experiment.sh [execute|review|synthesize|all] [--unattended]

Runs the executor/reviewer/mediator pipeline declared in the resolved
friction lab config (.friction-lab/config.local.json if present, else
.friction-lab/config.json, or $FRICTION_LAB_CONFIG) against the resolved
brief (experiment-brief.local.md if present, else experiment-brief.md).

  execute      Run the executor agent, producing findings.md and the rest of
               the evidence chain. Skipped if findings.md already exists.
               Requires --unattended to run headlessly with full tool access;
               otherwise drive the executor interactively yourself.
  review       Run the reviewer agent against the handoff artifacts in an
               isolated, read-only working directory. Requires findings.md.
  synthesize   Run the mediator agent against findings.md + review.md in
               an isolated, read-only working directory. Requires review.md.
  all          execute, review, synthesize in sequence (default).

Set FRICTION_LAB_MAX_BUDGET_USD to cap API spend per stage.
EOF
}

if [ -f ".friction-lab/env" ]; then
  set -a
  # shellcheck disable=SC1091
  . ".friction-lab/env"
  set +a
fi

if [ -n "${FRICTION_LAB_CONFIG:-}" ]; then
  config_path="$FRICTION_LAB_CONFIG"
elif [ -f ".friction-lab/config.local.json" ]; then
  config_path=".friction-lab/config.local.json"
else
  config_path=".friction-lab/config.json"
fi

if [ ! -f "$config_path" ]; then
  printf 'Agent Friction Lab config not found: %s\n' "$config_path" >&2
  exit 1
fi

if [ -f "experiment-brief.local.md" ]; then
  brief_path="experiment-brief.local.md"
else
  brief_path="experiment-brief.md"
fi

if [ ! -f "$brief_path" ]; then
  printf 'Agent Friction Lab brief not found: %s\n' "$brief_path" >&2
  exit 1
fi

subcommand="all"
unattended=0
for arg in "$@"; do
  case "$arg" in
    --unattended) unattended=1 ;;
    execute|review|synthesize|all) subcommand="$arg" ;;
    -h|--help) usage; exit 0 ;;
    *)
      printf 'Unknown argument: %s\n' "$arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

agent_command() {
  local role="$1"
  jq -r --arg role "$role" '.agents[]? | select(.role == $role) | .command // ""' "$config_path" | head -n1
}

budget_args=()
if [ -n "${FRICTION_LAB_MAX_BUDGET_USD:-}" ]; then
  budget_args=(--max-budget-usd "$FRICTION_LAB_MAX_BUDGET_USD")
fi

copy_artifacts() {
  local dest="$1"
  shift
  mkdir -p "$dest"
  local item stripped
  for item in "$@"; do
    stripped="${item%/}"
    # Strip any trailing slash before cp -R: BSD cp (macOS) flattens a
    # trailing-slash directory's contents into dest instead of nesting it,
    # unlike GNU cp -- stripping it first makes the nesting consistent
    # across both.
    if [ -e "$stripped" ]; then
      cp -R "$stripped" "$dest/"
    fi
  done
}

run_executor() {
  local executor_command
  executor_command="$(agent_command executor)"
  if [ -z "$executor_command" ]; then
    printf 'No executor agent configured in %s (agents[].role == "executor").\n' "$config_path" >&2
    exit 1
  fi

  if [ -f findings.md ]; then
    printf 'findings.md already exists; skipping executor.\n'
    printf 'Remove prior run artifacts (./reset-friction-lab-workspace.sh --yes) to re-run.\n'
    return 0
  fi

  if [ "$unattended" -ne 1 ]; then
    printf 'findings.md not found, and the --unattended flag was not passed.\n' >&2
    printf 'Either drive the executor interactively yourself (start %s and follow\n' "$executor_command" >&2
    printf 'agent-runbook.md + %s), or re-run this command and pass\n' "$brief_path" >&2
    printf 'the --unattended flag for a headless, full-tool-access executor run.\n' >&2
    exit 1
  fi

  printf 'Running executor (%s) headlessly with full tool access...\n' "$executor_command"
  "$executor_command" -p --dangerously-skip-permissions "${budget_args[@]}" \
    "You are the executor agent for this Agent Friction Lab run. Read ./agent-runbook.md and ./$brief_path in this directory and follow them exactly, starting with Preflight. Do not skip Preflight. Produce every required artifact (environment.md, raw-log.md, evidence-index.md, findings.md, evidence/, artifacts/) before finishing."

  if [ ! -f findings.md ]; then
    printf 'Executor run finished but findings.md was not produced.\n' >&2
    exit 1
  fi
  printf 'Executor complete: findings.md\n'
}

run_reviewer() {
  local reviewer_command
  reviewer_command="$(agent_command reviewer)"
  if [ -z "$reviewer_command" ]; then
    printf 'No reviewer agent configured in %s (agents[].role == "reviewer"); nothing to do.\n' "$config_path" >&2
    exit 1
  fi

  if [ ! -f findings.md ]; then
    printf 'findings.md not found. Run the executor first (./run-friction-lab-experiment.sh execute).\n' >&2
    exit 1
  fi

  mapfile -t handoff_artifacts < <(jq -r '.reviewProtocol.handoffArtifacts[]?' "$config_path")
  if [ "${#handoff_artifacts[@]}" -eq 0 ]; then
    printf 'reviewProtocol.handoffArtifacts is empty in %s; nothing to hand to the reviewer.\n' "$config_path" >&2
    exit 1
  fi

  local timestamp run_dir
  timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
  run_dir="review/$timestamp/inbox"
  copy_artifacts "$run_dir" "${handoff_artifacts[@]}" agent-runbook.md
  cp "$brief_path" "$run_dir/experiment-brief.md"

  printf 'Running reviewer (%s) in isolated directory %s...\n' "$reviewer_command" "$run_dir"
  (
    cd "$run_dir"
    "$reviewer_command" -p --restricted --strict-mcp-config --permission-mode acceptEdits "${budget_args[@]}" \
      "You are the reviewer agent in a cross-review protocol. Read ./agent-runbook.md's Cross-Review section for your responsibilities and ./experiment-brief.md for task context. Examine only the evidence files already in this directory. Produce ./review.md per the Cross-Review section: verify that findings.md claims are backed by evidence-index.md citations, distinguish Observed/Inferred/Recommendation, challenge weak or missing evidence, note places where a different reasonable path might have changed the outcome, and list specific follow-up or escalation questions. Do not rewrite findings.md, and do not attempt to re-run or re-research the task."
  )

  if [ ! -f "$run_dir/review.md" ]; then
    printf 'Reviewer did not produce review.md in %s\n' "$run_dir" >&2
    exit 1
  fi
  cp "$run_dir/review.md" review.md
  printf 'Reviewer complete: review.md\n'
}

run_mediator() {
  local mediator_command
  mediator_command="$(agent_command mediator)"
  if [ -z "$mediator_command" ]; then
    printf 'No mediator agent configured in %s (agents[].role == "mediator"); nothing to do.\n' "$config_path" >&2
    exit 1
  fi

  if [ ! -f review.md ]; then
    printf 'review.md not found. Run the reviewer first (./run-friction-lab-experiment.sh review).\n' >&2
    exit 1
  fi

  mapfile -t synthesis_artifacts < <(jq -r '.reviewProtocol.synthesisArtifacts[]?' "$config_path")
  if [ "${#synthesis_artifacts[@]}" -eq 0 ]; then
    printf 'reviewProtocol.synthesisArtifacts is empty in %s; nothing to hand to the mediator.\n' "$config_path" >&2
    exit 1
  fi

  local timestamp run_dir
  timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
  run_dir="review/$timestamp/synthesis"
  copy_artifacts "$run_dir" "${synthesis_artifacts[@]}" agent-runbook.md
  cp "$brief_path" "$run_dir/experiment-brief.md"

  printf 'Running mediator (%s) in isolated directory %s...\n' "$mediator_command" "$run_dir"
  (
    cd "$run_dir"
    "$mediator_command" -p --restricted --strict-mcp-config --permission-mode acceptEdits "${budget_args[@]}" \
      "You are the mediator agent. Read ./agent-runbook.md's Synthesis section for your responsibilities. Reconcile ./findings.md (executor) and ./review.md (reviewer) using ./environment.md, ./raw-log.md, ./evidence-index.md, and the evidence/artifacts directories as ground truth -- check a reviewer claim about any of those files directly rather than taking it on trust. Produce ./final-report.md per the Synthesis section: executive summary; ground truth with confidence, noting whether executor and reviewer agree; points of agreement, cited; points of disagreement, cited from both sides and left unresolved rather than picked; reconciled recommendations, cited; and open follow-up or escalation questions for the human. Explicitly flag disagreements between executor and reviewer rather than silently resolving them in favor of one side."
  )

  if [ ! -f "$run_dir/final-report.md" ]; then
    printf 'Mediator did not produce final-report.md in %s\n' "$run_dir" >&2
    exit 1
  fi
  cp "$run_dir/final-report.md" final-report.md
  printf 'Mediator complete: final-report.md\n'
}

case "$subcommand" in
  execute) run_executor ;;
  review) run_reviewer ;;
  synthesize) run_mediator ;;
  all)
    run_executor
    run_reviewer
    run_mediator
    ;;
esac
