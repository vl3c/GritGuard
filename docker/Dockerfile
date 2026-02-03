# GritGuard Sandbox Container
# Base image for running AI agents in isolation
#
# Build: docker build -t gritguard-sandbox:latest docker/
# Usage: Used by gritguard-docker wrapper script

FROM ubuntu:22.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install base system utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    jq \
    bash \
    less \
    vim-tiny \
    wget \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 22.x (current LTS)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Python 3.11+
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/python3 /usr/bin/python

# Install commonly used npm packages globally
RUN npm install -g \
    typescript \
    ts-node \
    && npm cache clean --force

# Install AI coding agent CLIs
RUN npm install -g \
    @openai/codex \
    @anthropic-ai/claude-code \
    && npm cache clean --force

# Create a non-root user for running commands
# Note: UID/GID will be overridden at runtime via --user flag
RUN groupadd -g 1000 sandbox \
    && useradd -u 1000 -g sandbox -m -s /bin/bash sandbox

# Set default working directory (will be overridden at runtime)
WORKDIR /workspace

# Default to bash shell
CMD ["/bin/bash"]

# Labels for identification
LABEL org.opencontainers.image.title="GritGuard Sandbox"
LABEL org.opencontainers.image.description="Isolated container for running AI agents safely"
LABEL org.opencontainers.image.vendor="GritGuard"
