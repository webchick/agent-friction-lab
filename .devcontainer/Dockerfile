FROM mcr.microsoft.com/devcontainers/javascript-node:1-22-bookworm

USER root

ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright \
    NODE_PATH=/usr/local/share/npm-global/lib/node_modules \
    DISABLE_AUTOUPDATER=1

# Generic utilities useful for the experiment.
RUN apt-get update && apt-get install -y \
    curl \
    jq \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Pre-bake the harness's default agent/tooling/browser stack as image layers
# instead of installing it in postCreateCommand (.friction-lab/setup-friction-lab.sh),
# so `devcontainer up --remove-existing-container` is fast on every run instead of
# re-downloading the same static packages/browsers each time. setup-friction-lab.sh
# still runs at container creation and stays a fast no-op for anything already
# baked in here (npm install / playwright install are already idempotent), while
# still handling any experiment-specific delta from .friction-lab/config.local.json.
#
# Keep this in sync by hand with the npmGlobalPackages/playwrightBrowsers/
# playwrightMcpBrowsers defaults in .friction-lab/config.json -- it's a static
# bake of that default, not read from it, so a changed default here needs a
# matching Dockerfile edit to keep the fast path.
RUN npm install -g @anthropic-ai/claude-code playwright @playwright/mcp

RUN npm_global_bin="$(npm prefix -g)/bin" \
    && PATH="$npm_global_bin:$PATH" playwright install --with-deps chromium \
    && PATH="$npm_global_bin:$PATH" playwright-mcp install-browser chrome-for-testing \
    && chmod -R a+rX "$PLAYWRIGHT_BROWSERS_PATH"

USER node
