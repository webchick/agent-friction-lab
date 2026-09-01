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

# Claude Code, Playwright, and the Playwright MCP server are installed in the
# image so they are present immediately after container creation.
RUN npm install -g @anthropic-ai/claude-code playwright @playwright/mcp

# Install Chromium + the Linux libraries Playwright needs into a shared cache.
RUN npx --no-install playwright install --with-deps chromium \
    && playwright-mcp install-browser chrome-for-testing \
    && chmod -R a+rX /ms-playwright

USER node

# Configure only a container-local Claude MCP entry, available from any project.
RUN claude mcp add --scope user playwright -- playwright-mcp --isolated --headless --browser chromium --no-sandbox --output-dir /tmp/playwright-mcp
