#!/bin/bash
# GritGuard Setup Script
# Installs sandbox runtime and dependencies

set -e

echo "=== GritGuard Setup ==="
echo ""

# Determine install location
INSTALL_DIR="${GRITGUARD_INSTALL_DIR:-$HOME/.gritguard}"

echo "Install directory: $INSTALL_DIR"
echo ""

# Create directory structure
echo "[1/4] Creating directory structure..."
mkdir -p "$INSTALL_DIR"/{bin,templates}

# Check for Node.js
echo "[2/4] Checking Node.js..."
if ! command -v node &> /dev/null; then
    echo "ERROR: Node.js not found"
    echo "Please install Node.js 18+ first:"
    echo "  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -"
    echo "  sudo apt-get install -y nodejs"
    exit 1
fi

NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    echo "ERROR: Node.js 18+ required (found v$NODE_VERSION)"
    exit 1
fi
echo "Node.js version: $(node -v)"

# Install sandbox-runtime
echo "[3/4] Installing sandbox-runtime..."
if command -v srt &> /dev/null; then
    echo "srt already installed: $(command -v srt)"
else
    npm install -g @anthropic-ai/sandbox-runtime@latest
fi

# Check system dependencies
echo "[4/4] Checking system dependencies..."
echo ""

MISSING_DEPS=0

if command -v bwrap &> /dev/null; then
    echo "  bubblewrap: $(bwrap --version 2>&1 | head -1)"
else
    echo "  bubblewrap: NOT FOUND"
    echo "    Install with: sudo apt install bubblewrap"
    MISSING_DEPS=1
fi

if command -v socat &> /dev/null; then
    echo "  socat: installed"
else
    echo "  socat: NOT FOUND (optional, for network proxying)"
    echo "    Install with: sudo apt install socat"
fi

echo ""

# Copy template if not exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -f "$SCRIPT_DIR/templates/base.json" ]; then
    cp "$SCRIPT_DIR/templates/base.json" "$INSTALL_DIR/templates/"
    echo "Template settings copied to: $INSTALL_DIR/templates/base.json"
fi

# Copy sandboxed wrapper
if [ -f "$SCRIPT_DIR/bin/sandboxed" ]; then
    cp "$SCRIPT_DIR/bin/sandboxed" "$INSTALL_DIR/bin/"
    chmod +x "$INSTALL_DIR/bin/sandboxed"
    echo "Wrapper script copied to: $INSTALL_DIR/bin/sandboxed"
fi

echo ""
echo "=== Setup Complete ==="
echo ""

if [ $MISSING_DEPS -eq 1 ]; then
    echo "WARNING: Some dependencies are missing. Install them for full functionality."
    echo ""
fi

echo "Usage:"
echo "  1. Copy and customize settings:"
echo "     cp $INSTALL_DIR/templates/base.json .srt-settings.json"
echo ""
echo "  2. Run any command in sandbox:"
echo "     $INSTALL_DIR/bin/sandboxed your-command [args...]"
echo ""
echo "  Or add to PATH:"
echo "     export PATH=\"$INSTALL_DIR/bin:\$PATH\""
echo "     sandboxed your-command [args...]"
echo ""
