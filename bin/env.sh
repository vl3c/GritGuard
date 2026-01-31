# Source this file to set up the Claude Code environment
# Usage: source /home/erebus/agent/bin/env.sh

export NVM_DIR="/home/erebus/agent/.nvm"
export CLAUDE_CONFIG_DIR="/home/erebus/agent/.claude-config"
export CLAUDE_LOCAL_STATE_DIR="/home/erebus/agent/.claude-state"

# Load nvm first
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"

# Add our npm bin to PATH (where claude is installed)
export PATH="/home/erebus/agent/.npm/bin:$PATH"

echo "Claude Code environment loaded."
echo "  Node: $(node -v)"
echo "  Claude: $(claude --version)"
echo ""
echo "Commands:"
echo "  claude            - Run Claude Code directly"
echo "  claude-sandboxed  - Run Claude Code in sandbox"
