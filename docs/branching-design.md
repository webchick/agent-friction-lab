# Branching: barebones by default, escalate on RETURN, preserve every attempt

**Status: design only, not yet implemented.** Part (A) below (the barebones-default
config change) is implemented and live. `branch-experiment.sh` and the RETURN/raw-log
runbook changes ((B) and (C)) are deferred pending a real RETURN to design against —
see Sequencing. Nothing described here beyond (A) exists in the harness yet; treat
the rest as a plan, not documentation of current behavior.

## Context

The historical pattern that led to Playwright being baked into this harness's default
config was: run barebones against four PLG targets (Vercel, Acquia, Pantheon,
WordPress VIP); three of four block at "Go" with no CLI path forward; add Playwright
MCP as a permanent baseline fix; rerun — everyone succeeds except WordPress VIP
(blocked on disallowing throwaway emails, a much more interesting finding). That
process worked, but baking the fix into the shared default means every future
experiment inherits it whether it needs it or not, and the "did this target need
more than barebones" signal — itself real data — gets permanently baked out.

The better model, per this conversation: barebones is always the true default, per
experiment. A RETURN-worthy blocker is a decision point, not a dead end — the human
(who's already watching, since the executor runs interactively via
`run-experiment.sh`) decides in the moment: stop, or branch. Branching means sealing
the current attempt's evidence as its own standalone, comparable record, then
continuing with whatever capability was authorized — never silently overwriting the
blocked attempt.

Confirmed design intent from this conversation: keep Playwright's packages/browser
binaries baked into `.devcontainer/Dockerfile` (pure latency win, and a good bet per
the "most 2026-era PLG flows are visual-first" hypothesis) — but don't *register*
the Playwright MCP server with `claude` by default. Registration becomes the actual
branch action: fast (nothing to download, already cached), and now something the
agent has to earn through a real blocker rather than start with.

## Design

**Run tree = a sequence of sealed attempts plus one live attempt.** The live
workspace's top-level evidence files (`environment.md`, `raw-log.md`,
`evidence-index.md`, `findings.md`, `evidence/`) work exactly as they do today — the
executor just keeps appending to them, uninterrupted, across a branch. What's new is
a **seal point**: right before a branch, the current live state gets copied (not
moved) into `runs/<NNN>-<slug>/`, freezing it as a standalone, self-contained record
of "the barebones attempt, through the point it got blocked." The live files keep
growing past that point for the new branch. A second branch later seals again,
capturing everything up to that point (root + branch 1's continuation). No tree
nesting needed — sequential numbering plus an explicit `parent:` field in each seal's
metadata is enough for the linear case this is built for, while leaving room for a
non-linear fork later without having to build that now.

**New script: `branch-experiment.sh <slug> "<what blocked the parent>" "<what's
being authorized>"`** (repo root, alongside the other top-level scripts).
Mechanical only — it doesn't decide *whether* to branch, the executor/human already
did that in the interactive session. The blocker/authorization text are required
arguments, not fields to remember to fill in later — this is exactly the kind of
deterministic step that should be captured atomically rather than left to memory,
same reasoning as `run-experiment.sh`:
1. `mkdir -p runs`; auto-detects the next sequence number from what's already
   there (start at `001` if empty).
2. Copies the live evidence files (`environment.md`, `raw-log.md`,
   `evidence-index.md`, `findings.md`, `evidence/`, `artifacts/`) plus
   `agent-runbook.md` and the resolved brief into `runs/<NNN>-<slug>/`, so each
   sealed attempt is independently readable without the live workspace.
3. Writes `runs/<NNN>-<slug>/branch.md` with parent (auto: most recent prior seal,
   or "root" if none), timestamp, and the blocker/authorization text passed in —
   fully populated at seal time, not a stub. The executor can still add richer
   narrative to `raw-log.md` afterward, but the core facts are never left blank.

Doesn't touch config or MCP registration itself — that stays a separate, explicit
step (see below) so the script has one job and the config change is visible in
`raw-log.md`/`findings.md` like any other action.

**`raw-log.md` needs an inline branch marker, not just a final summary.** Since the
live log stays one continuous document across branches, a human (or the mediator)
reading it mid-document has no signal where a fork happened without cross-referencing
`runs/`. `agent-runbook.md`'s Raw Log section should require a marker line (e.g.
`=== BRANCH: <slug> (runs/<NNN>-<slug>/) ===`) written immediately after each
`branch-experiment.sh` invocation, before continuing.

**`agent-runbook.md` changes**:
- **RETURN section**: replace the vague "after receiving help, continue
  autonomously" ending with two named outcomes the human chooses between:
  - **STOP**: the blocked state is the final result. Proceed straight to the Final
    Deliverable as normal — the block itself is the finding.
  - **BRANCH**: the human authorizes a specific capability/config change. Run
    `./branch-experiment.sh <slug> "<blocker>" "<authorization>"` to seal the
    current attempt, then apply the change deterministically rather than from
    recall: copy the relevant `mcpServers` entry verbatim from the matching
    `.friction-lab/config.*.example.json` (e.g. `config.claude-playwright.example.json`
    for a Playwright branch) into `.friction-lab/config.local.json`, then run the
    same registration command that entry specifies (matching what
    `setup-friction-lab.sh` would have run had it been in the config from the
    start), so `config.local.json` and the live `claude mcp list` output never
    drift apart. Write the branch marker into `raw-log.md` (see below) and
    continue the same task attempt.
  - Explicit boundary: branching only ever *adds an authorized capability*. It is
    never a route around a hard Boundary (payment, CAPTCHA, identity, credentials)
    — those stay absolute regardless of how many times you've branched.
- **Final Deliverable**: if any branches occurred, `findings.md` must summarize the
  branch lineage (what blocked each attempt, what was authorized, pointer to
  `runs/` for the full frozen record of each prior attempt) — this is what makes
  "did it need Playwright to get past Go" legible to a human reader without digging
  through `runs/` themselves.

**Config changes — barebones becomes the real default** (this part is (A), already
implemented):
- `.friction-lab/config.json`: keep the executor+reviewer+mediator roles (already
  validated this session), but `mcpServers: []` — no Playwright registered by
  default. `runs/` added to `reviewProtocol.handoffArtifacts` and
  `synthesisArtifacts` so the reviewer/mediator can see prior sealed attempts once
  branching exists, not just the final live state.
  `npmGlobalPackages`/`playwrightBrowsers`/`playwrightMcpBrowsers` stay as-is,
  matching what's already baked into the Dockerfile — installed-but-unregistered is
  the whole point, not a contradiction.
- `.friction-lab/config.claude-playwright.example.json`: restated as the literal
  branch recipe — same roles as the new default, plus the Playwright `mcpServers`
  entry, documented as "what `config.local.json` should look like after branching
  to add Playwright."
- `.friction-lab/config.cross-review.example.json` retired — it became an exact
  duplicate of the new default `config.json` once both are barebones cross-review.
- `run-experiment.sh`: the "copy `config.cross-review.example.json` if
  `config.local.json` is missing" step is gone — `config.json` alone is now a
  sufficient, correct default, and `run-friction-lab-experiment.sh` already falls
  back to it.

**No changes needed** to `verify-friction-lab.sh` (the Playwright smoke-test gate
is already conditional on `mcpServers[].smokeTest` being present, so it correctly
no-ops with an empty `mcpServers: []` and correctly re-activates once a branch adds
the entry) or to `reset-friction-lab-workspace.sh` (`runs` is already in
`cruft_paths`, already gets swept between experiments — it was anticipated, just
never built out until now).

## Sequencing

This design bundles three separable pieces:

- **(A) Barebones-default config change** — shipped. `config.json`'s
  `mcpServers: []`, `config.claude-playwright.example.json` restated as the branch
  recipe, `config.cross-review.example.json` retired, `run-experiment.sh`
  simplified. Low-risk, immediately valuable on its own even with no branching
  mechanism yet — every run from here on measures the true barebones default.
- **(B) + (C) `branch-experiment.sh` and the RETURN/raw-log runbook changes** —
  deferred. This is the least-validated design in the whole harness so far: built
  from one historical anecdote plus one design conversation, no prototype exercised
  yet. This doc preserves the design without committing to the mechanics being
  exactly right. Build it once a real RETURN happens against the new barebones
  default and there's an actual blocker to design against, rather than trusting
  paper design here.

## Verification (for (B) + (C), once built)

- `bash -n branch-experiment.sh`; `jq empty` on any config files it touches.
- Scratch dry-run of `branch-experiment.sh` against synthetic evidence files:
  confirm sequential numbering increments correctly across two invocations, confirm
  `runs/001-<slug>/` and `runs/002-<slug>/` each contain complete, independently
  readable copies, confirm `branch.md`'s auto-detected `parent:` field is correct
  for both.
- Confirm `run-friction-lab-experiment.sh review`/`synthesize` still resolve
  correctly with `runs/` in `handoffArtifacts`/`synthesisArtifacts` when `runs/`
  doesn't exist yet (a run with zero branches) as well as when it does.
- Real validation needs a live devcontainer run: a real RETURN, a real human
  decision to branch, confirming the executor reads the new RETURN instructions
  correctly, invokes `branch-experiment.sh` itself when authorized, and
  `findings.md` ends up with a real branch-lineage summary.
