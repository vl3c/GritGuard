#!/bin/bash
# Test suite for GritGuard dynamic sandbox configuration
# Run with: ./tests/test_gritguard.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GRITGUARD_DIR="$(dirname "$SCRIPT_DIR")"
AGENT_DIR="${AGENT_DIR:-$(dirname "$(dirname "$(cd "$(dirname "$0")" && pwd)")")}"
TEST_REPO="/tmp/gritguard-test-$$"
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

log_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

cleanup() {
    rm -rf "$TEST_REPO" 2>/dev/null || true
}
trap cleanup EXIT

# Setup test repo
setup_test_repo() {
    cleanup
    mkdir -p "$TEST_REPO"
    cd "$TEST_REPO"
    git init -q
    git config user.email "test@test.local"
    git config user.name "Test"
    echo "# Test" > README.md
    git add . && git commit -q -m "init"
    cd "$AGENT_DIR"
}

echo "========================================"
echo "GritGuard Dynamic Config Test Suite"
echo "========================================"
echo ""

# Setup
log_info "Setting up test repository at $TEST_REPO"
setup_test_repo

# Test 1: generate-config produces valid JSON
log_info "Test 1: generate-config produces valid JSON"
if output=$("$GRITGUARD_DIR/bin/generate-config" "$TEST_REPO" 2>&1); then
    if echo "$output" | python3 -m json.tool > /dev/null 2>&1; then
        log_pass "generate-config produces valid JSON"
    else
        log_fail "generate-config output is not valid JSON"
    fi
else
    log_fail "generate-config failed: $output"
fi

# Test 2: generate-config includes target directory in allowWrite
log_info "Test 2: Config includes target directory in allowWrite"
if output=$("$GRITGUARD_DIR/bin/generate-config" "$TEST_REPO" 2>&1); then
    if echo "$output" | grep -q "$TEST_REPO"; then
        log_pass "Config includes target directory"
    else
        log_fail "Config missing target directory"
    fi
else
    log_fail "generate-config failed"
fi

# Test 3: generate-config includes logs/plans/worktrees paths
log_info "Test 3: Config includes logs/plans/worktrees paths"
if output=$("$GRITGUARD_DIR/bin/generate-config" "$TEST_REPO" 2>&1); then
    if echo "$output" | grep -q "$TEST_REPO/logs" && \
       echo "$output" | grep -q "$TEST_REPO/plans" && \
       echo "$output" | grep -q "$TEST_REPO/.worktrees"; then
        log_pass "Config includes logs/plans/worktrees paths"
    else
        log_fail "Config missing some dynamic paths"
    fi
else
    log_fail "generate-config failed"
fi

# Test 4: generate-config includes parent .worktrees
log_info "Test 4: Config includes parent .worktrees path"
if output=$("$GRITGUARD_DIR/bin/generate-config" "$TEST_REPO" 2>&1); then
    if echo "$output" | grep -q "/tmp/.worktrees"; then
        log_pass "Config includes parent .worktrees"
    else
        log_fail "Config missing parent .worktrees"
    fi
else
    log_fail "generate-config failed"
fi

# Test 5: gritguard --repo flag parsing
log_info "Test 5: gritguard --repo flag is parsed correctly"
if output=$(GRITGUARD_DEBUG=1 "$GRITGUARD_DIR/bin/gritguard" --repo "$TEST_REPO" echo test 2>&1); then
    if echo "$output" | grep -q "Target directory: $TEST_REPO" && \
       echo "$output" | grep -q "Command args: echo test"; then
        log_pass "--repo flag parsed correctly"
    else
        log_fail "--repo parsing incorrect: $output"
    fi
else
    log_fail "gritguard failed"
fi

# Test 6: gritguard --repo at end of command
log_info "Test 6: gritguard --repo at end of args"
if output=$(GRITGUARD_DEBUG=1 "$GRITGUARD_DIR/bin/gritguard" echo hello --repo "$TEST_REPO" 2>&1); then
    if echo "$output" | grep -q "Target directory: $TEST_REPO" && \
       echo "$output" | grep -q "Command args: echo hello"; then
        log_pass "--repo at end of args works"
    else
        log_fail "--repo at end parsing incorrect: $output"
    fi
else
    log_fail "gritguard failed"
fi

# Test 7: gritguard basic execution
log_info "Test 7: gritguard basic execution"
if output=$("$GRITGUARD_DIR/bin/gritguard" --repo "$TEST_REPO" echo "sandbox works" 2>&1); then
    if echo "$output" | grep -q "sandbox works"; then
        log_pass "Basic execution works"
    else
        log_fail "Basic execution unexpected output: $output"
    fi
else
    log_fail "gritguard basic execution failed"
fi

# Test 8: Write to target directory allowed
log_info "Test 8: Write to target directory allowed"
if "$GRITGUARD_DIR/bin/gritguard" --repo "$TEST_REPO" touch "$TEST_REPO/test-write.txt" 2>&1; then
    if [ -f "$TEST_REPO/test-write.txt" ]; then
        log_pass "Write to target directory allowed"
        rm -f "$TEST_REPO/test-write.txt"
    else
        log_fail "File was not created"
    fi
else
    log_fail "Write to target directory failed"
fi

# Test 9: Write to /tmp allowed (in allowWrite)
log_info "Test 9: Write to /tmp allowed"
TMP_TEST="/tmp/gritguard-write-test-$$"
if "$GRITGUARD_DIR/bin/gritguard" --repo "$TEST_REPO" touch "$TMP_TEST" 2>&1; then
    if [ -f "$TMP_TEST" ]; then
        log_pass "Write to /tmp allowed"
        rm -f "$TMP_TEST"
    else
        log_fail "/tmp file was not created"
    fi
else
    log_fail "Write to /tmp failed"
fi

# Test 10: Write outside allowed paths blocked
log_info "Test 10: Write outside allowed paths blocked"
# Use /var/tmp which is outside allowWrite paths regardless of user
if output=$("$GRITGUARD_DIR/bin/gritguard" --repo "$TEST_REPO" touch /var/tmp/gritguard_evil.txt 2>&1); then
    log_fail "Write outside allowed paths should have failed"
    rm -f /var/tmp/gritguard_evil.txt 2>/dev/null
else
    if echo "$output" | grep -q "Read-only"; then
        log_pass "Write outside allowed paths blocked"
    else
        log_pass "Write blocked (different error)"
    fi
fi

# Test 11: Sensitive directory protection (.ssh)
log_info "Test 11: Sensitive directory protection (.ssh)"
if output=$("$GRITGUARD_DIR/bin/gritguard" --repo "$TEST_REPO" cat $HOME/.ssh/known_hosts 2>&1); then
    if echo "$output" | grep -q "ssh-"; then
        log_fail ".ssh is accessible in sandbox"
    else
        log_pass ".ssh content hidden"
    fi
else
    log_pass ".ssh protected (access denied)"
fi

# Test 12: Sensitive directory protection (.gnupg)
log_info "Test 12: Sensitive directory protection (.gnupg)"
if output=$("$GRITGUARD_DIR/bin/gritguard" --repo "$TEST_REPO" ls $HOME/.gnupg 2>&1); then
    if [ -z "$output" ] || echo "$output" | grep -qE "(No such file|Permission denied)"; then
        log_pass ".gnupg protected"
    else
        log_fail ".gnupg is accessible: $output"
    fi
else
    log_pass ".gnupg protected (access denied)"
fi

# Test 13: /root blocked
log_info "Test 13: /root blocked"
if output=$("$GRITGUARD_DIR/bin/gritguard" --repo "$TEST_REPO" ls /root 2>&1); then
    if [ -z "$output" ] || echo "$output" | grep -qE "(No such file|Permission denied)"; then
        log_pass "/root blocked"
    else
        log_fail "/root accessible: $output"
    fi
else
    log_pass "/root blocked (access denied)"
fi

# Test 14: Can read allowed system files
log_info "Test 14: Can read allowed system files"
if output=$("$GRITGUARD_DIR/bin/gritguard" --repo "$TEST_REPO" cat /etc/hostname 2>&1); then
    if [ -n "$output" ]; then
        log_pass "Can read /etc/hostname"
    else
        log_fail "Cannot read /etc/hostname"
    fi
else
    log_fail "Reading /etc/hostname failed"
fi

# Test 15: Node.js works in sandbox
log_info "Test 15: Node.js works in sandbox"
if output=$("$GRITGUARD_DIR/bin/gritguard" --repo "$TEST_REPO" 'node -e "console.log(2+2)"' 2>&1); then
    if echo "$output" | grep -q "4"; then
        log_pass "Node.js works in sandbox"
    else
        log_fail "Node.js unexpected output: $output"
    fi
else
    log_fail "Node.js failed in sandbox"
fi

# Test 16: Uses current directory when --repo not specified
log_info "Test 16: Uses current directory when --repo not specified"
cd "$TEST_REPO"
if output=$(GRITGUARD_DEBUG=1 "$GRITGUARD_DIR/bin/gritguard" echo test 2>&1); then
    if echo "$output" | grep -q "Target directory: $TEST_REPO"; then
        log_pass "Uses current directory by default"
    else
        log_fail "Wrong default directory: $output"
    fi
else
    log_fail "gritguard failed without --repo"
fi
cd "$AGENT_DIR"

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
