#!/usr/bin/env bash
set -Eeuo pipefail

if [ -f ".airlock/env" ]; then
  set -a
  # shellcheck disable=SC1091
  . ".airlock/env"
  set +a
fi

archive_root="${AIRLOCK_ARCHIVE_ROOT:-/private/tmp/agent-airlock-archives}"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
archive_dir="$archive_root/$timestamp"

baseline_paths=(
  ".devcontainer"
  ".airlock"
  "README.md"
  "agent-runbook.md"
  "experiment-brief.md"
  "verify-airlock.sh"
  "reset-airlock-workspace.sh"
)

cruft_paths=(
  "environment.md"
  "raw-log.md"
  "evidence-index.md"
  "findings.md"
  "final-report.md"
  "evidence"
  "artifacts"
  "runs"
  ".playwright-mcp"
)

usage() {
  cat <<'EOF'
Usage: ./reset-airlock-workspace.sh [--yes]

Moves known experiment/preflight artifacts out of this workspace and into:
  /private/tmp/agent-airlock-archives/<timestamp>/

The baseline harness files are left in place:
  .devcontainer/
  .airlock/
  README.md
  agent-runbook.md
  experiment-brief.md
  verify-airlock.sh
  reset-airlock-workspace.sh

Set AIRLOCK_ARCHIVE_ROOT to choose a different archive location.
EOF
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  ""|--yes)
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

present=()
for path in "${cruft_paths[@]}"; do
  if [ -e "$path" ]; then
    present+=("$path")
  fi
done

if [ "${#present[@]}" -eq 0 ]; then
  printf 'No known airlock run artifacts found. Workspace already looks baseline-ready.\n'
  exit 0
fi

printf 'The following paths will be moved out of the workspace:\n'
printf '  %s\n' "${present[@]}"
printf '\nArchive destination: %s\n' "$archive_dir"

if [ "${1:-}" != "--yes" ]; then
  printf '\nRe-run with --yes to perform the reset.\n'
  exit 0
fi

mkdir -p "$archive_dir"

for path in "${present[@]}"; do
  mkdir -p "$archive_dir/$(dirname "$path")"
  mv "$path" "$archive_dir/$path"
done

printf '\nRemaining baseline paths:\n'
for path in "${baseline_paths[@]}"; do
  if [ -e "$path" ]; then
    printf '  PASS %s\n' "$path"
  else
    printf '  MISSING %s\n' "$path"
  fi
done

printf '\nMoved artifacts to: %s\n' "$archive_dir"
printf 'Now rebuild/reopen the devcontainer and run ./verify-airlock.sh.\n'
