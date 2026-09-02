#!/usr/bin/env bash
set -Eeuo pipefail

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
npm_global_bin="$(npm prefix -g)/bin"
setup_path="$npm_global_bin:$PATH"

if [ ! -f "$config_path" ]; then
  printf 'Agent Friction Lab config not found: %s\n' "$config_path" >&2
  exit 1
fi

find /home/node/.ssh -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
chmod 700 /home/node/.ssh 2>/dev/null || true

mapfile -t npm_global_packages < <(jq -r '.npmGlobalPackages[]?' "$config_path")
if [ "${#npm_global_packages[@]}" -gt 0 ]; then
  sudo npm install -g "${npm_global_packages[@]}"
fi

mapfile -t playwright_browsers < <(jq -r '.playwrightBrowsers[]?' "$config_path")
if [ "${#playwright_browsers[@]}" -gt 0 ]; then
  sudo env PATH="$setup_path" PLAYWRIGHT_BROWSERS_PATH="${PLAYWRIGHT_BROWSERS_PATH:-/ms-playwright}" npx --no-install playwright install --with-deps "${playwright_browsers[@]}"
  sudo chmod -R a+rX "${PLAYWRIGHT_BROWSERS_PATH:-/ms-playwright}"
fi

mapfile -t playwright_mcp_browsers < <(jq -r '.playwrightMcpBrowsers[]?' "$config_path")
if [ "${#playwright_mcp_browsers[@]}" -gt 0 ]; then
  sudo env PATH="$setup_path" PLAYWRIGHT_BROWSERS_PATH="${PLAYWRIGHT_BROWSERS_PATH:-/ms-playwright}" playwright-mcp install-browser "${playwright_mcp_browsers[@]}"
  sudo chmod -R a+rX "${PLAYWRIGHT_BROWSERS_PATH:-/ms-playwright}"
fi

mcp_provider="$(jq -r '
  if (.agents // []) | length > 0 then
    ([.agents[]?.mcpProvider // "none" | select(. != "none")] | first) // "none"
  else
    .agent.mcpProvider // "none"
  end
' "$config_path")"

if [ "$mcp_provider" != "claude" ]; then
  printf 'No Claude MCP setup requested (configured MCP provider=%s).\n' "$mcp_provider"
  printf 'Agent Friction Lab setup complete from %s\n' "$config_path"
  exit 0
fi

if ! command -v claude >/dev/null 2>&1; then
  printf 'Claude MCP setup requested, but claude is not installed.\n' >&2
  exit 1
fi

mkdir -p /home/node/.claude

configured_names="$(jq -r '.mcpServers[]?.name' "$config_path")"
existing_names="$(claude mcp list 2>/dev/null | sed -nE 's/^([[:alnum:]_.@/-]+):.*/\1/p' || true)"

for name in $existing_names; do
  if ! printf '%s\n' "$configured_names" | grep -Fxq "$name"; then
    claude mcp remove --scope user "$name" >/dev/null 2>&1 || true
  fi
done

jq -c '.mcpServers[]?' "$config_path" | while IFS= read -r server; do
  name="$(printf '%s\n' "$server" | jq -r '.name')"
  command="$(printf '%s\n' "$server" | jq -r '.command')"
  mapfile -t args < <(printf '%s\n' "$server" | jq -r '.args[]?')

  claude mcp remove --scope user "$name" >/dev/null 2>&1 || true
  claude mcp add --scope user "$name" -- "$command" "${args[@]}"
done

printf 'Agent Friction Lab setup complete from %s\n' "$config_path"
