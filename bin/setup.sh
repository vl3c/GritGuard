#!/bin/bash
# Claude Code Isolated Environment Setup Script
# This script sets up the complete isolated environment for Claude Code

set -e

AGENT_DIR="/home/erebus/agent"

echo "=== Claude Code Isolated Environment Setup ==="
echo ""

# Create directory structure
echo "[1/5] Creating directory structure..."
mkdir -p "$AGENT_DIR"/{.claude-config/workspace,.claude-state,.npm,.node,.nvm,bin,logs,sandbox}

# Install nvm if not present
if [ ! -d "$AGENT_DIR/.nvm" ] || [ ! -f "$AGENT_DIR/.nvm/nvm.sh" ]; then
    echo "[2/5] Installing nvm..."
    export NVM_DIR="$AGENT_DIR/.nvm"
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
else
    echo "[2/5] nvm already installed, skipping..."
fi

# Load nvm
export NVM_DIR="$AGENT_DIR/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"

# Install Node.js 22 if not present
if ! command -v node &> /dev/null || [[ "$(node -v)" != v22* ]]; then
    echo "[3/5] Installing Node.js 22..."
    nvm install 22
    nvm use 22
else
    echo "[3/5] Node.js 22 already installed, skipping..."
fi

# Install Claude Code and sandbox-runtime
echo "[4/5] Installing Claude Code and sandbox-runtime..."
export NPM_CONFIG_PREFIX="$AGENT_DIR/.npm"
export PATH="$AGENT_DIR/.npm/bin:$PATH"

npm install -g @anthropic-ai/claude-code@latest 2>/dev/null || true
npm install -g @anthropic-ai/sandbox-runtime@latest 2>/dev/null || true

# Verify installation
echo "[5/5] Verifying installation..."
echo ""
echo "Node.js version: $(node -v)"
echo "npm version: $(npm -v)"
echo "Claude Code location: $(command -v claude || echo 'Not found')"
echo "srt location: $(command -v srt || echo 'Not found')"
echo ""

# Check dependencies
echo "=== Checking dependencies ==="
if command -v bwrap &> /dev/null; then
    echo "bubblewrap: $(bwrap --version)"
else
    echo "WARNING: bubblewrap not found. Install with: sudo apt install bubblewrap"
fi

if command -v socat &> /dev/null; then
    echo "socat: installed"
else
    echo "NOTE: socat not found. Network proxying may be limited."
    echo "      Install with: sudo apt install socat"
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "To run Claude Code in sandboxed mode:"
echo "  $AGENT_DIR/bin/claude-sandboxed"
echo ""
echo "To run Claude Code without sandbox:"
echo "  source $AGENT_DIR/.nvm/nvm.sh && claude"
echo ""
echo "Environment variables for manual use:"
echo "  export NVM_DIR=\"$AGENT_DIR/.nvm\""
echo "  export CLAUDE_CONFIG_DIR=\"$AGENT_DIR/.claude-config\""
echo "  export CLAUDE_LOCAL_STATE_DIR=\"$AGENT_DIR/.claude-state\""
echo "  export PATH=\"$AGENT_DIR/.npm/bin:\$PATH\""
