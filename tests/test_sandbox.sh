#!/bin/bash
# Test suite for Claude Code sandboxed environment
# Run with: ./tests/test_sandbox.sh

AGENT_DIR="/home/erebus/agent"
SRT_SETTINGS="$AGENT_DIR/.srt-settings.json"
PASS=0
FAIL=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

log_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

run_sandboxed() {
    srt --settings "$SRT_SETTINGS" "$@" 2>&1
}

echo "========================================"
echo "Claude Code Sandbox Test Suite"
echo "========================================"
echo ""

# Test 1: Basic sandbox execution
log_info "Test 1: Basic sandbox execution"
if output=$(run_sandboxed "echo 'sandbox works'"); then
    if [[ "$output" == *"sandbox works"* ]]; then
        log_pass "Basic command execution in sandbox"
    else
        log_fail "Basic command execution - unexpected output: $output"
    fi
else
    log_fail "Basic command execution failed"
fi

# Test 2: Claude Code runs in sandbox
log_info "Test 2: Claude Code runs in sandbox"
if output=$(run_sandboxed "claude --version"); then
    if [[ "$output" == *"Claude Code"* ]]; then
        log_pass "Claude Code runs in sandbox"
    else
        log_fail "Claude Code version check - unexpected output: $output"
    fi
else
    log_fail "Claude Code failed to run in sandbox"
fi

# Test 3: Credential directory blocking (~/.ssh)
log_info "Test 3: Credential directory blocking (~/.ssh)"
if output=$(run_sandboxed "ls /home/erebus/.ssh/" 2>&1); then
    if [[ "$output" == *"No such file"* ]] || [[ -z "$output" ]]; then
        log_pass "~/.ssh is hidden from sandbox"
    else
        log_fail "~/.ssh is accessible: $output"
    fi
else
    log_pass "~/.ssh is blocked from sandbox"
fi

# Test 4: Credential directory blocking (~/.gnupg)
log_info "Test 4: Credential directory blocking (~/.gnupg)"
if output=$(run_sandboxed "ls /home/erebus/.gnupg/" 2>&1); then
    if [[ "$output" == *"No such file"* ]] || [[ -z "$output" ]]; then
        log_pass "~/.gnupg is hidden from sandbox"
    else
        log_fail "~/.gnupg is accessible: $output"
    fi
else
    log_pass "~/.gnupg is blocked from sandbox"
fi

# Test 5: Write allowed in agent directory
log_info "Test 5: Write allowed in agent directory"
TEST_FILE="$AGENT_DIR/sandbox/test_write_$$"
if run_sandboxed "echo 'test' > $TEST_FILE && cat $TEST_FILE" | grep -q "test"; then
    log_pass "Write allowed in $AGENT_DIR"
    rm -f "$TEST_FILE"
else
    log_fail "Write failed in $AGENT_DIR"
fi

# Test 6: Write blocked outside agent directory
log_info "Test 6: Write blocked outside agent directory"
if output=$(run_sandboxed "echo 'test' > /home/erebus/outside_test.txt" 2>&1); then
    log_fail "Write outside agent dir should have failed"
    rm -f /home/erebus/outside_test.txt
else
    if [[ "$output" == *"Read-only"* ]]; then
        log_pass "Write blocked outside agent directory"
    else
        log_pass "Write blocked outside agent directory (different error)"
    fi
fi

# Test 7: Write blocked in /tmp
log_info "Test 7: Write blocked in /tmp"
if output=$(run_sandboxed "echo 'test' > /tmp/sandbox_test.txt" 2>&1); then
    log_fail "Write to /tmp should have failed"
else
    log_pass "Write blocked in /tmp"
fi

# Test 8: Non-allowlisted domain blocked
log_info "Test 8: Non-allowlisted domain blocked (example.com)"
output=$(run_sandboxed "curl -s --max-time 5 https://example.com" 2>&1) || true
if [[ -z "$output" ]] || [[ "$output" == *"timed out"* ]] || [[ "$output" == *"Connection"* ]]; then
    log_pass "Non-allowlisted domain blocked"
else
    log_fail "example.com should be blocked but got response: $output"
fi

# Test 9: Allowlisted domain works (api.anthropic.com)
log_info "Test 9: Allowlisted domain works (api.anthropic.com)"
if output=$(run_sandboxed "curl -s --max-time 10 -I https://api.anthropic.com" 2>&1); then
    if [[ "$output" == *"HTTP"* ]]; then
        log_pass "Allowlisted domain (api.anthropic.com) accessible"
    else
        log_fail "Allowlisted domain returned unexpected response: $output"
    fi
else
    log_fail "Allowlisted domain request failed"
fi

# Test 10: Allowlisted domain works (registry.npmjs.org)
log_info "Test 10: Allowlisted domain works (registry.npmjs.org)"
if output=$(run_sandboxed "curl -s --max-time 10 -I https://registry.npmjs.org" 2>&1); then
    if [[ "$output" == *"HTTP"* ]]; then
        log_pass "Allowlisted domain (registry.npmjs.org) accessible"
    else
        log_fail "Allowlisted domain returned unexpected response: $output"
    fi
else
    log_fail "Allowlisted domain request failed"
fi

# Test 11: Node.js works in sandbox
log_info "Test 11: Node.js works in sandbox"
if output=$(run_sandboxed "node -e 'console.log(1+1)'"); then
    if [[ "$output" == *"2"* ]]; then
        log_pass "Node.js works in sandbox"
    else
        log_fail "Node.js unexpected output: $output"
    fi
else
    log_fail "Node.js failed in sandbox"
fi

# Test 12: Environment variables set correctly
log_info "Test 12: Environment isolation (CLAUDE_CONFIG_DIR)"
export CLAUDE_CONFIG_DIR="$AGENT_DIR/.claude-config"
if output=$(run_sandboxed 'echo $CLAUDE_CONFIG_DIR'); then
    if [[ "$output" == *".claude-config"* ]] || [[ -z "$output" ]]; then
        log_pass "Environment variable handling works"
    else
        log_fail "Unexpected CLAUDE_CONFIG_DIR: $output"
    fi
else
    log_pass "Environment isolation works"
fi

# Test 13: Cannot access /root
log_info "Test 13: Cannot access /root"
output=$(run_sandboxed "ls /root" 2>&1)
if [[ -z "$output" ]] || [[ "$output" == *"Permission denied"* ]] || [[ "$output" == *"No such file"* ]]; then
    log_pass "/root is inaccessible"
else
    log_fail "/root is accessible: $output"
fi

# Test 14: Can read system files (not in denyRead)
log_info "Test 14: Can read system files (/etc/hostname)"
if output=$(run_sandboxed "cat /etc/hostname"); then
    if [[ -n "$output" ]]; then
        log_pass "Can read allowed system files"
    else
        log_fail "Could not read /etc/hostname"
    fi
else
    log_fail "Reading system files failed"
fi

# Test 15: gritguard wrapper works
log_info "Test 15: gritguard wrapper works"
GRITGUARD_DIR="$(dirname "$0")/.."
if output=$("$GRITGUARD_DIR/bin/gritguard" --repo /tmp echo "gritguard test" 2>&1); then
    if [[ "$output" == *"gritguard test"* ]]; then
        log_pass "gritguard wrapper works correctly"
    else
        log_fail "gritguard wrapper unexpected output: $output"
    fi
else
    log_fail "gritguard wrapper failed"
fi

echo ""
echo "========================================"
echo "Test Results"
echo "========================================"
echo -e "${GREEN}Passed: $PASS${NC}"
echo -e "${RED}Failed: $FAIL${NC}"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
