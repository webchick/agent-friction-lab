#!/usr/bin/env bash
set -Eeuo pipefail

if [ -f ".friction-lab/env" ]; then
  set -a
  # shellcheck disable=SC1091
  . ".friction-lab/env"
  set +a
fi

failures=0

if [ -n "${FRICTION_LAB_CONFIG:-}" ]; then
  config_path="$FRICTION_LAB_CONFIG"
elif [ -f ".friction-lab/config.local.json" ]; then
  config_path=".friction-lab/config.local.json"
else
  config_path=".friction-lab/config.json"
fi

if [ ! -f "$config_path" ]; then
  printf 'FAIL: friction lab config not found: %s\n' "$config_path" >&2
  exit 1
fi

read_json_array_words() {
  local query="$1"
  jq -r "$query | join(\" \")" "$config_path"
}

required_commands="${FRICTION_LAB_REQUIRED_COMMANDS:-$(read_json_array_words '.requiredCommands // []')}"
configured_mcp_required_commands="$(jq -r '.mcpServers[]?.requiredCommands[]?' "$config_path" | sort -u | tr '\n' ' ')"
allowed_mcp_servers="${FRICTION_LAB_ALLOWED_MCP_SERVERS:-$(read_json_array_words '.allowedMcpServers // []')}"
forbidden_commands="${FRICTION_LAB_FORBIDDEN_COMMANDS:-$(read_json_array_words '.forbiddenCommands // []')}"
forbidden_env_pattern="${FRICTION_LAB_FORBIDDEN_ENV_PATTERN:-$(jq -r '.forbiddenEnvPattern // ""' "$config_path")}"
prior_trace_pattern="${FRICTION_LAB_PRIOR_TRACE_PATTERN:-$(jq -r '.priorTracePattern // ""' "$config_path")}"
agent_summary="$(jq -r '
  if (.agents // []) | length > 0 then
    [.agents[] | "\(.id // .role // "agent")=\(.name // "unspecified")/\(.role // "unspecified")"] | join(", ")
  elif .agent then
    "agent=\(.agent.name // "unspecified")"
  else
    "none"
  end
' "$config_path")"
agent_commands="$(jq -r '
  if (.agents // []) | length > 0 then
    .agents[]? | select((.command // "") != "" and (if has("required") then .required else true end) != false) | .command
  elif .agent and ((.agent.command // "") != "") then
    .agent.command
  else
    empty
  end
' "$config_path")"
mcp_provider="$(jq -r '
  if (.agents // []) | length > 0 then
    ([.agents[]?.mcpProvider // "none" | select(. != "none")] | first) // "none"
  else
    .agent.mcpProvider // "none"
  end
' "$config_path")"

pass() {
  printf 'PASS: %s\n' "$1"
}

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  failures=$((failures + 1))
}

require_command() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    pass "required command is present: $name ($(command -v "$name"))"
  else
    fail "required command is missing: $name"
  fi
}

forbid_command() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    fail "forbidden command is present: $name ($(command -v "$name"))"
  else
    pass "forbidden command is absent: $name"
  fi
}

check_no_env_matches() {
  local label="$1"
  local pattern="$2"
  if env | grep -Eiq "$pattern"; then
    fail "forbidden environment variable pattern found: $label"
    env | grep -Ei "$pattern" >&2 || true
  else
    pass "no forbidden environment variable pattern found: $label"
  fi
}

check_no_sensitive_env() {
  local matches
  matches="$(env | grep -Ei '(TOKEN|SECRET|PASSWORD|API_KEY|PRIVATE_KEY|CLIENT_SECRET)=' | grep -Eiv '^(CLAUDE_CODE_MESSAGING_TOKEN|GIT_ASKPASS)=' || true)"
  if [ -n "$matches" ]; then
    fail "forbidden sensitive environment variable names found"
    printf '%s\n' "$matches" >&2
  else
    pass "no forbidden sensitive environment variable names found"
  fi
}

printf '== Agent Friction Lab verification ==\n'
printf 'Date: %s\n' "$(date -Is)"
printf 'OS: %s\n' "$(uname -a)"
printf 'CWD: %s\n' "$PWD"
printf 'HOME: %s\n' "$HOME"
printf 'Config: %s\n' "$config_path"
printf 'Agents: %s\n' "$agent_summary"
printf '\n'

if [ -r /etc/debian_version ]; then
  pass "Debian base detected (/etc/debian_version: $(tr -d '\n' </etc/debian_version))"
else
  fail "Debian base not detected"
fi

case "$(uname -s)" in
  Linux) pass "Linux kernel detected" ;;
  *) fail "expected Linux kernel, found $(uname -s)" ;;
esac

for tool in $required_commands $configured_mcp_required_commands; do
  require_command "$tool"
done

if node --version | grep -Eq '^v[0-9]+'; then
  pass "Node runs: $(node --version)"
else
  fail "Node does not report a valid version"
fi

if npm --version >/dev/null 2>&1; then
  pass "npm runs: $(npm --version)"
else
  fail "npm does not run"
fi

if [ -n "$agent_commands" ]; then
  for agent_command in $agent_commands; do
    if command -v "$agent_command" >/dev/null 2>&1; then
      version_output="$("$agent_command" --version 2>/dev/null | head -n 1 || true)"
      pass "configured agent command runs: $agent_command${version_output:+ ($version_output)}"
    else
      fail "configured agent command is missing: $agent_command"
    fi
  done
else
  pass "no configured agent command"
fi

if [ -n "$forbidden_commands" ]; then
  for tool in $forbidden_commands; do
    forbid_command "$tool"
  done
else
  pass "no experiment-specific forbidden commands configured"
fi

if [ -n "$forbidden_env_pattern" ]; then
  check_no_env_matches "experiment-specific credentials" "$forbidden_env_pattern"
else
  pass "no experiment-specific forbidden environment pattern configured"
fi
check_no_sensitive_env

if [ -d "$HOME/.ssh" ]; then
  if [ ! -r "$HOME/.ssh" ] || [ ! -w "$HOME/.ssh" ]; then
    fail "\$HOME/.ssh exists but is not readable and writable by $(id -un)"
  else
    ssh_listing="$(find "$HOME/.ssh" -mindepth 1 -maxdepth 1 -print 2>/dev/null | sort || true)"
    if [ -n "$ssh_listing" ]; then
      fail "\$HOME/.ssh exists and is not empty"
      printf '%s\n' "$ssh_listing" >&2
    else
      pass "\$HOME/.ssh exists but is empty"
    fi
  fi
else
  pass "\$HOME/.ssh is absent"
fi

if [ -f "$HOME/.ssh/known_hosts" ]; then
  fail "\$HOME/.ssh/known_hosts exists; friction lab SSH host history must be empty"
fi

if [ "${HOME#"/Users/"}" != "$HOME" ] || [ "${HOME#"/home/"}" = "$HOME" ]; then
  fail "\$HOME does not look like an isolated Linux container home: $HOME"
else
  pass "\$HOME looks container-local"
fi

if [ "${PWD#"/workspaces/"}" = "$PWD" ]; then
  fail "workspace is not mounted under /workspaces: $PWD"
else
  pass "workspace is mounted under /workspaces"
fi

if findmnt -R "$PWD" >/dev/null 2>&1; then
  printf '\n== Workspace mount ==\n'
  findmnt -R "$PWD" -o TARGET,SOURCE,FSTYPE,OPTIONS || true
  printf '\n'
fi

host_mounts="$(findmnt -rn -o TARGET,SOURCE,FSTYPE | awk -v workspace="$PWD" '
  $3 ~ /^(virtiofs|osxfs|fuse\.osxfs|9p)$/ && $1 != workspace { print }
')"
if [ -n "$host_mounts" ]; then
  fail "host-backed mounts other than the project workspace are visible"
  printf '%s\n' "$host_mounts" >&2
else
  pass "no host-backed mounts other than the project workspace are visible"
fi

if [ -e /hosthome ] || [ -e /Users/webchick ] || [ -e /Users ]; then
  fail "host home path appears mounted or visible"
else
  pass "host home path is not visible"
fi

workspace_files="$(find "$PWD" -maxdepth 2 -mindepth 1 -not -path '*/.git/*' -print | sed "s#^$PWD/##" | sort)"
printf 'Workspace files visible:\n%s\n\n' "${workspace_files:-"(none)"}"

if [ -n "$prior_trace_pattern" ] && printf '%s\n' "$workspace_files" | grep -Eiq "$prior_trace_pattern"; then
  fail "workspace appears to contain configured prior-run traces"
else
  pass "workspace contains no configured prior-run traces"
fi

if [ -d "$HOME/.codex/skills" ] || [ -d "$HOME/.claude/skills" ]; then
  fail "agent skills directory exists in container home"
else
  pass "no container-home agent skills directory exists"
fi

if [ "$mcp_provider" = "claude" ]; then
  if ! command -v claude >/dev/null 2>&1; then
    fail "Claude MCP provider configured, but claude command is missing"
  elif [ -f "$HOME/.claude.json" ] || [ -d "$HOME/.claude" ]; then
    claude_mcp_list="$(claude mcp list 2>&1 || true)"
    printf 'Claude MCP list:\n%s\n\n' "$claude_mcp_list"
    for expected_name in $allowed_mcp_servers; do
      if printf '%s\n' "$claude_mcp_list" | grep -Eq "^${expected_name}:"; then
        pass "Claude Code has expected MCP server configured: $expected_name"
      else
        fail "Claude Code does not list expected MCP server: $expected_name"
      fi
    done
    mcp_names="$(printf '%s\n' "$claude_mcp_list" | sed -nE 's/^([[:alnum:]_.@/-]+):.*/\1/p' | sort -u)"
    unexpected_mcp=""
    for name in $mcp_names; do
      case " $allowed_mcp_servers " in
        *" $name "*) ;;
        *) unexpected_mcp="${unexpected_mcp}${name}"$'\n' ;;
      esac
    done
    if [ -n "$unexpected_mcp" ]; then
      fail "Claude Code lists MCP/connectors outside FRICTION_LAB_ALLOWED_MCP_SERVERS"
      printf '%s' "$unexpected_mcp" >&2
    else
      pass "Claude Code lists only allowed MCP/connectors: $allowed_mcp_servers"
    fi
  else
    if [ -n "$allowed_mcp_servers" ]; then
      fail "Claude Code configuration is absent; expected container-local MCP config"
    else
      pass "Claude Code configuration is absent and no MCP servers are expected"
    fi
  fi
else
  if [ -n "$allowed_mcp_servers" ]; then
    fail "allowedMcpServers is set, but no compatible agent MCP provider is configured (provider=$mcp_provider)"
  else
    pass "no MCP provider configured"
  fi
fi

if jq -e '.mcpServers[]? | select(.smokeTest == "example.com-accessibility-snapshot")' "$config_path" >/dev/null; then
  if NODE_PATH="${NODE_PATH:-/usr/local/share/npm-global/lib/node_modules}" node <<'NODE'
const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
  const page = await browser.newPage();
  await page.goto('https://example.com/', { waitUntil: 'domcontentloaded', timeout: 60000 });
  const title = await page.title();
  const body = await page.locator('body').innerText({ timeout: 10000 });
  const aria = await page.locator('body').ariaSnapshot({ timeout: 10000 });
  await browser.close();
  if (!/Example Domain/i.test(title) || !/Example Domain/i.test(body) || !/Example Domain/i.test(aria)) {
    throw new Error(`unexpected page state: title=${title} body=${body.slice(0, 80)} aria=${aria.slice(0, 80)}`);
  }
  console.log(aria);
})().catch(error => {
  console.error(error);
  process.exit(1);
});
NODE
  then
    pass "headless Chromium opened example.com and returned an accessibility snapshot"
  else
    fail "headless Chromium example.com accessibility smoke test failed"
  fi

  if node <<'NODE'
const { spawn } = require('node:child_process');
const child = spawn('playwright-mcp', ['--isolated', '--headless', '--browser', 'chromium', '--no-sandbox', '--output-dir', '/tmp/playwright-mcp'], {
  stdio: ['pipe', 'pipe', 'pipe'],
  env: { ...process.env, PLAYWRIGHT_BROWSERS_PATH: process.env.PLAYWRIGHT_BROWSERS_PATH || '/ms-playwright' },
});

let buffer = '';
let nextId = 1;
const pending = new Map();
const timeout = setTimeout(() => {
  console.error('Timed out waiting for Playwright MCP');
  child.kill('SIGTERM');
  process.exit(1);
}, 90000);

function send(method, params = {}) {
  const id = nextId++;
  const marker = method === 'tools/call' && params.name
    ? `tools/call:${params.name}`
    : method;
  const payload = { jsonrpc: '2.0', id, method, params };
  pending.set(id, { method: marker });
  child.stdin.write(JSON.stringify(payload) + '\n');
  return id;
}

function finish(ok, message) {
  clearTimeout(timeout);
  if (message) console.log(message);
  child.kill('SIGTERM');
  process.exit(ok ? 0 : 1);
}

child.stderr.on('data', chunk => process.stderr.write(chunk));
child.on('error', error => finish(false, error.message));

child.stdout.on('data', chunk => {
  buffer += chunk.toString();
  let index;
  while ((index = buffer.indexOf('\n')) >= 0) {
    const line = buffer.slice(0, index).trim();
    buffer = buffer.slice(index + 1);
    if (!line) continue;
    let msg;
    try {
      msg = JSON.parse(line);
    } catch {
      continue;
    }
    if (!msg.id) continue;
    const pendingCall = pending.get(msg.id);
    if (!pendingCall) continue;
    pending.delete(msg.id);
    if (msg.error) finish(false, `${pendingCall.method} failed: ${JSON.stringify(msg.error)}`);

    if (pendingCall.method === 'initialize') {
      child.stdin.write(JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized' }) + '\n');
      send('tools/list');
    } else if (pendingCall.method === 'tools/list') {
      const names = (msg.result.tools || []).map(tool => tool.name);
      if (!names.includes('browser_navigate') || !names.includes('browser_snapshot')) {
        finish(false, `missing expected tools: ${names.join(', ')}`);
      }
      send('tools/call', { name: 'browser_navigate', arguments: { url: 'https://example.com/' } });
    } else if (pendingCall.method === 'tools/call:browser_navigate') {
      send('tools/call', { name: 'browser_snapshot', arguments: {} });
    } else if (pendingCall.method === 'tools/call:browser_snapshot') {
      const text = JSON.stringify(msg.result);
      if (/Example Domain/i.test(text)) {
        finish(true, 'Playwright MCP browser_snapshot contains Example Domain');
      }
      finish(false, `snapshot did not contain Example Domain: ${text.slice(0, 500)}`);
    }
  }
});

send('initialize', {
  protocolVersion: '2024-11-05',
  capabilities: {},
  clientInfo: { name: 'verify-friction-lab', version: '1.0.0' },
});
NODE
  then
    pass "Playwright MCP launched, navigated to example.com, and produced a snapshot"
  else
    fail "Playwright MCP functional smoke test failed"
  fi
else
  pass "no browser MCP smoke test configured"
fi

if [ "$failures" -eq 0 ]; then
  printf '\nAll friction lab checks passed.\n'
else
  printf '\n%d friction lab check(s) failed.\n' "$failures" >&2
  exit 1
fi
