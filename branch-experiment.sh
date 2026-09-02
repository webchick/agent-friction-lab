#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'EOF'
Usage: ./branch-experiment.sh <slug> "<what blocked the parent>" "<what's being authorized>"

Seals the current live evidence state into runs/<NNN>-<slug>/ as a standalone,
independently-readable record of the attempt up to this point, then leaves the
live workspace files in place so the same task attempt can continue under a
newly-authorized capability. Mechanical only -- this script does not decide
whether to branch (that's the human's call at a RETURN point, per
agent-runbook.md), and it does not itself apply the authorized change (see
docs/branching-design.md for the deterministic recipe-copying step).

  <slug>          Short label for this branch, e.g. "playwright". Used in the
                   runs/ directory name.
  <blocker>        What blocked the parent attempt. Required, not optional --
                   captured atomically here rather than left to fill in later.
  <authorization>  What the human authorized. Required for the same reason.

Example:
  ./branch-experiment.sh playwright \
    "No CLI path forward for signup; blind scripted Playwright too slow to iterate" \
    "Human authorized registering Playwright MCP for live browser observation"
EOF
}

if [ "$#" -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  usage
  [ "$#" -eq 0 ] && exit 2
  exit 0
fi

if [ "$#" -ne 3 ]; then
  printf 'Expected exactly 3 arguments: <slug> "<blocker>" "<authorization>"\n' >&2
  usage >&2
  exit 2
fi

slug="$1"
blocker="$2"
authorization="$3"

if ! printf '%s' "$slug" | grep -Eq '^[a-z0-9][a-z0-9-]*$'; then
  printf 'slug must be lowercase alphanumeric with hyphens (e.g. "playwright", "real-github-account"): got %s\n' "$slug" >&2
  exit 2
fi

if [ ! -f "findings.md" ] && [ ! -f "raw-log.md" ]; then
  printf 'No live evidence found (no findings.md or raw-log.md) -- nothing to seal.\n' >&2
  printf 'Run this from the same workspace the executor is working in, after some\n' >&2
  printf 'Preflight/task-attempt evidence already exists.\n' >&2
  exit 1
fi

mkdir -p runs

# Auto-detect the next sequence number and the most recent prior seal (the
# parent), from what's already in runs/. Directory names are NNN-<slug>.
last_dir=""
next_n=1
for d in runs/*/; do
  [ -d "$d" ] || continue
  name="$(basename "$d")"
  case "$name" in
    [0-9][0-9][0-9]-*)
      n="${name%%-*}"
      n="$((10#$n))"
      if [ "$n" -ge "$next_n" ]; then
        next_n=$((n + 1))
        last_dir="$name"
      fi
      ;;
  esac
done

parent="root"
if [ -n "$last_dir" ]; then
  parent="$last_dir"
fi

seq="$(printf '%03d' "$next_n")"
dest="runs/${seq}-${slug}"

if [ -e "$dest" ]; then
  printf 'runs/%s already exists; refusing to overwrite.\n' "${seq}-${slug}" >&2
  exit 1
fi

mkdir -p "$dest"

copy_if_present() {
  local item="$1" stripped
  stripped="${item%/}"
  if [ -e "$stripped" ]; then
    cp -R "$stripped" "$dest/"
  fi
}

for item in environment.md raw-log.md evidence-index.md findings.md evidence/ artifacts/ agent-runbook.md; do
  copy_if_present "$item"
done

if [ -f "experiment-brief.local.md" ]; then
  cp "experiment-brief.local.md" "$dest/experiment-brief.md"
elif [ -f "experiment-brief.md" ]; then
  cp "experiment-brief.md" "$dest/experiment-brief.md"
fi

timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

cat > "$dest/branch.md" <<BRANCH
# Branch: ${slug}

- **Sealed at**: ${timestamp}
- **Parent**: ${parent}
- **Blocker**: ${blocker}
- **Authorized**: ${authorization}

This directory is a frozen, standalone copy of the live evidence at the moment
of this branch -- independently readable without the live workspace. The live
workspace's evidence files continue past this point under the newly authorized
capability; they are not reset.
BRANCH

printf 'Sealed attempt: runs/%s-%s/ (parent: %s)\n' "$seq" "$slug" "$parent"
printf '\n'
printf 'Next: apply the authorized change deterministically (copy the matching\n'
printf 'mcpServers entry from the relevant .friction-lab/config.*.example.json into\n'
printf 'config.local.json, then register it the same way setup-friction-lab.sh\n'
printf 'would have), and write a branch marker into raw-log.md:\n'
printf '\n'
printf '  === BRANCH: %s (runs/%s-%s/) ===\n' "$slug" "$seq" "$slug"
