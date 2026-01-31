# Source this file to set up the Claude Code environment
# Usage: source /home/<user>/agent/bin/env.sh

export NVM_DIR="/home/<user>/agent/.nvm"
export CLAUDE_CONFIG_DIR="/home/<user>/agent/.claude-config"
export CLAUDE_LOCAL_STATE_DIR="/home/<user>/agent/.claude-state"

# Load nvm first
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"

# Add our npm bin to PATH (where claude is installed)
export PATH="/home/<user>/agent/.npm/bin:$PATH"

echo "Claude Code environment loaded."
echo "  Node: $(node -v)"
echo "  Claude: $(claude --version)"
echo ""
echo "Commands:"
echo "  claude            - Run Claude Code directly"
echo "  claude-sandboxed  - Run Claude Code in sandbox"
