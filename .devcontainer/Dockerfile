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

# Claude Code is part of the baseline. Experiment-specific packages and MCP
# exposure are controlled by .airlock/config.json during post-create setup.
RUN npm install -g @anthropic-ai/claude-code

USER node
