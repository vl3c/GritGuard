#!/bin/bash
# Quick test suite for Claude Code sandboxed environment (no network tests)
# Run with: ./tests/test_sandbox_quick.sh

AGENT_DIR="${AGENT_DIR:-$(dirname "$(dirname "$(cd "$(dirname "$0")" && pwd)")")}"
SRT_SETTINGS="$AGENT_DIR/.srt-settings.json"
PASS=0
FAIL=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Load environment
export NVM_DIR="$AGENT_DIR/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
export PATH="$AGENT_DIR/.npm/bin:$PATH"

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    PASS=$((PASS + 1))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    FAIL=$((FAIL + 1))
}

run_sandboxed() {
    srt --settings "$SRT_SETTINGS" "$@" 2>&1
}

echo "========================================"
echo "Claude Code Sandbox Quick Tests"
echo "========================================"
echo ""

# Test 1: Sandbox executes commands
echo -n "Testing sandbox execution... "
if run_sandboxed "echo test" | grep -q "test"; then
    log_pass "sandbox executes commands"
else
    log_fail "sandbox execution"
fi

# Test 2: Claude Code runs
echo -n "Testing Claude Code in sandbox... "
if run_sandboxed "claude --version" | grep -q "Claude Code"; then
    log_pass "Claude Code runs"
else
    log_fail "Claude Code"
fi

# Test 3: ~/.ssh blocked
echo -n "Testing ~/.ssh blocking... "
if ! run_sandboxed "cat $HOME/.ssh/authorized_keys" 2>&1 | grep -q "ssh-"; then
    log_pass "~/.ssh blocked"
else
    log_fail "~/.ssh accessible"
fi

# Test 4: Write in agent dir
echo -n "Testing write in agent dir... "
if run_sandboxed "touch $AGENT_DIR/sandbox/.write_test && rm $AGENT_DIR/sandbox/.write_test"; then
    log_pass "write allowed in agent dir"
else
    log_fail "write in agent dir"
fi

# Test 5: Write blocked outside
echo -n "Testing write blocking outside agent dir... "
if run_sandboxed "touch $HOME/.write_test" 2>&1 | grep -q "Read-only"; then
    log_pass "write blocked outside"
else
    log_fail "write not blocked"
fi

# Test 6: Node.js works
echo -n "Testing Node.js in sandbox... "
if run_sandboxed "node -e 'console.log(2+2)'" | grep -q "4"; then
    log_pass "Node.js works"
else
    log_fail "Node.js"
fi

# Test 7: /root blocked
echo -n "Testing /root blocking... "
root_output=$(run_sandboxed "ls /root" 2>&1)
if [[ -z "$root_output" ]] || echo "$root_output" | grep -qE "(Permission denied|No such file)"; then
    log_pass "/root blocked"
else
    log_fail "/root accessible: $root_output"
fi

# Test 8: gritguard wrapper
echo -n "Testing gritguard wrapper... "
GRITGUARD_DIR="$(dirname "$0")/.."
if "$GRITGUARD_DIR/bin/gritguard" --repo /tmp echo "test" 2>&1 | grep -q "test"; then
    log_pass "gritguard wrapper works"
else
    log_fail "gritguard wrapper"
fi

echo ""
echo "========================================"
echo -e "Results: ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}"
echo "========================================"

[ $FAIL -eq 0 ]
