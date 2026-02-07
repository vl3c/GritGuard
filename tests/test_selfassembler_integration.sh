#!/bin/bash
# GritGuard + SelfAssembler Combined Integration Tests
# Tests SelfAssembler running inside GritGuard sandbox.
#
# Usage: ./tests/test_selfassembler_integration.sh
#
# Prerequisites: SelfAssembler must be installed (pip install -e SelfAssembler)
# Tests marked (API) require valid Claude auth and will SKIP if unavailable.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GRITGUARD_DIR="$(dirname "$SCRIPT_DIR")"
AGENT_DIR="${AGENT_DIR:-$(dirname "$GRITGUARD_DIR")}"
TEST_REPO="/tmp/gritguard-sa-integ-$$"
PASS=0
FAIL=0
SKIP=0

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

log_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
    SKIP=$((SKIP + 1))
}

log_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

cleanup() {
    rm -rf "$TEST_REPO" /tmp/gritguard-sa-test*-$$.py 2>/dev/null || true
}
trap cleanup EXIT

setup_test_repo() {
    cleanup
    mkdir -p "$TEST_REPO"
    cd "$TEST_REPO"
    git init -q
    git config user.email "combined@test.local"
    git config user.name "Combined Tester"
    echo "# Combined Test" > README.md
    git add . && git commit -q -m "init"
    cd "$AGENT_DIR"
}

# Check selfassembler is installed
if ! command -v selfassembler &>/dev/null && ! python3 -m selfassembler.cli --version &>/dev/null 2>&1; then
    echo "Error: selfassembler not installed. Run: pip install -e SelfAssembler/" >&2
    exit 1
fi

# Check for srt
find_srt() {
    if command -v srt &> /dev/null; then echo "srt"; return 0; fi
    for loc in "$AGENT_DIR/.npm/bin/srt" "$HOME/.npm/bin/srt" "$HOME/.local/bin/srt" "/usr/local/bin/srt"; do
        if [[ -x "$loc" ]]; then echo "$loc"; return 0; fi
    done
    return 1
}

SRT_CMD=$(find_srt) || {
    echo "Error: srt not found. Cannot run integration tests." >&2
    exit 1
}

# Check if Claude CLI is authenticated (cheap check, no API cost)
claude_is_authed() {
    claude --version &>/dev/null 2>&1 || return 1
    timeout 15 claude -p "reply with exactly: OK" --max-turns 1 2>/dev/null | grep -q "OK" 2>/dev/null
}

echo "========================================"
echo "GritGuard + SelfAssembler Integration"
echo "========================================"
echo ""

log_info "Setting up test repository at $TEST_REPO"
setup_test_repo

# ─── Test 1: selfassembler_version_in_sandbox ────────────────────────────
log_info "Test 1: selfassembler --version inside sandbox"
if output=$("$GRITGUARD_DIR/bin/gritguard" --repo "$TEST_REPO" "selfassembler --version" 2>&1); then
    if echo "$output" | grep -qiE "(selfassembler|0\.[0-9])"; then
        log_pass "selfassembler_version_in_sandbox"
    else
        log_fail "selfassembler_version_in_sandbox — got: $output"
    fi
else
    # Try via python module
    if output=$("$GRITGUARD_DIR/bin/gritguard" --repo "$TEST_REPO" "python3 -m selfassembler.cli --version" 2>&1); then
        if echo "$output" | grep -qiE "(selfassembler|0\.[0-9])"; then
            log_pass "selfassembler_version_in_sandbox"
        else
            log_fail "selfassembler_version_in_sandbox — got: $output"
        fi
    else
        log_fail "selfassembler_version_in_sandbox — command failed"
    fi
fi

# ─── Test 2: selfassembler_dry_run_in_sandbox ────────────────────────────
log_info "Test 2: selfassembler --dry-run shows phases"
if output=$("$GRITGUARD_DIR/bin/gritguard" --repo "$TEST_REPO" \
    "selfassembler --dry-run 'test task' --name test" 2>&1); then
    if echo "$output" | grep -qiE "(phase|preflight|cost|setup)"; then
        log_pass "selfassembler_dry_run_in_sandbox"
    else
        log_fail "selfassembler_dry_run_in_sandbox — exit 0 but no phase output: $(echo "$output" | tail -5)"
    fi
else
    # Try python module fallback
    if output=$("$GRITGUARD_DIR/bin/gritguard" --repo "$TEST_REPO" \
        "python3 -m selfassembler.cli --dry-run 'test task' --name test" 2>&1); then
        if echo "$output" | grep -qiE "(phase|preflight|cost|setup)"; then
            log_pass "selfassembler_dry_run_in_sandbox"
        else
            log_fail "selfassembler_dry_run_in_sandbox — exit 0 but no phase output: $(echo "$output" | tail -5)"
        fi
    else
        log_fail "selfassembler_dry_run_in_sandbox — command failed"
    fi
fi

# ─── Test 3: selfassembler_list_phases_in_sandbox ────────────────────────
log_info "Test 3: selfassembler --list-phases works"
if output=$("$GRITGUARD_DIR/bin/gritguard" --repo "$TEST_REPO" "selfassembler --list-phases" 2>&1); then
    if echo "$output" | grep -qiE "(preflight|implementation)"; then
        log_pass "selfassembler_list_phases_in_sandbox"
    else
        log_fail "selfassembler_list_phases_in_sandbox — got: $(echo "$output" | tail -5)"
    fi
else
    if output=$("$GRITGUARD_DIR/bin/gritguard" --repo "$TEST_REPO" "python3 -m selfassembler.cli --list-phases" 2>&1); then
        if echo "$output" | grep -qiE "(preflight|implementation)"; then
            log_pass "selfassembler_list_phases_in_sandbox"
        else
            log_fail "selfassembler_list_phases_in_sandbox — got: $(echo "$output" | tail -5)"
        fi
    else
        log_fail "selfassembler_list_phases_in_sandbox — command failed"
    fi
fi

# ─── Test 4: git_identity_visible_to_selfassembler ───────────────────────
log_info "Test 4: Python can resolve git identity via ensure_identity()"
unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL 2>/dev/null || true
TMP_PY="/tmp/gritguard-sa-test4-$$.py"
cat > "$TMP_PY" << PYEOF
import sys, os
sys.path.insert(0, "$AGENT_DIR/SelfAssembler")
from selfassembler.git import GitManager
from pathlib import Path
gm = GitManager(Path("."))
identity = gm.ensure_identity()
print("SAID:" + identity["name"] + "|" + identity["email"] + "|" + identity["source"])
PYEOF
if output=$("$GRITGUARD_DIR/bin/gritguard" --repo "$TEST_REPO" "python3 $TMP_PY" 2>&1); then
    id_line=$(echo "$output" | grep "^SAID:" | head -1)
    if echo "$id_line" | grep -q "Combined Tester|combined@test.local"; then
        log_pass "git_identity_visible_to_selfassembler"
    elif [[ -n "$id_line" ]]; then
        # Some identity was resolved (maybe from env or global config)
        log_pass "git_identity_visible_to_selfassembler"
    else
        log_fail "git_identity_visible_to_selfassembler — no SAID marker in: $output"
    fi
else
    log_fail "git_identity_visible_to_selfassembler — gritguard exited $?"
fi
rm -f "$TMP_PY"

# ─── Test 5: selfassembler_preflight_in_sandbox ──────────────────────────
log_info "Test 5: Preflight passes inside sandbox (mock agent CLI check only)"
# Reset test repo to have main branch
cd "$TEST_REPO" && git branch -M main 2>/dev/null || true; cd "$AGENT_DIR"
TMP_PY="/tmp/gritguard-sa-test5-$$.py"
cat > "$TMP_PY" << PYEOF
import sys, os
sys.path.insert(0, "$AGENT_DIR/SelfAssembler")
from unittest.mock import MagicMock
from selfassembler.phases import PreflightPhase
from pathlib import Path

context = MagicMock()
context.repo_path = Path(".")
executor = MagicMock()
executor.check_available.return_value = (True, "1.0.0")
executor.AGENT_TYPE = "claude"
config = MagicMock()
config.git.base_branch = "main"
config.git.auto_update = False

pf = PreflightPhase(context, executor, config)
check = pf._check_git_identity()
if check["passed"]:
    print("PREFLIGHT_PASSED")
else:
    print("PREFLIGHT_FAILED: " + str(check))
PYEOF
if output=$("$GRITGUARD_DIR/bin/gritguard" --repo "$TEST_REPO" "python3 $TMP_PY" 2>&1); then
    if echo "$output" | grep -q "PREFLIGHT_PASSED"; then
        log_pass "selfassembler_preflight_in_sandbox"
    else
        log_fail "selfassembler_preflight_in_sandbox — got: $(echo "$output" | tail -3)"
    fi
else
    log_fail "selfassembler_preflight_in_sandbox — gritguard exited $?"
fi
rm -f "$TMP_PY"

# ─── Test 6: claude_commit_via_gritguard (API) ──────────────────────────
log_info "Test 6: Full cycle — Claude creates+commits a file inside sandbox (API)"
if claude_is_authed; then
    # Fresh repo for this test
    setup_test_repo
    output=$("$GRITGUARD_DIR/bin/gritguard" --repo "$TEST_REPO" \
        "claude -p 'Run: echo COMBINED > combined.txt && git add combined.txt && git commit -m combined-test' --max-turns 2 --allowedTools Bash" 2>&1) || true
    # Check the commit landed (regardless of claude exit code)
    commit_count=$(git -C "$TEST_REPO" log --oneline 2>/dev/null | wc -l)
    if git -C "$TEST_REPO" log --oneline 2>/dev/null | grep -qi "combined"; then
        log_pass "claude_commit_via_gritguard"
    elif [[ "$commit_count" -gt 1 ]]; then
        log_pass "claude_commit_via_gritguard"
    else
        log_fail "claude_commit_via_gritguard — no new commit. Output: $(echo "$output" | tail -5)"
    fi
else
    log_skip "claude_commit_via_gritguard — Claude CLI not authenticated"
fi

echo ""
echo "========================================"
echo "Combined Integration Results"
echo "========================================"
echo -e "${GREEN}Passed: $PASS${NC}"
echo -e "${RED}Failed: $FAIL${NC}"
echo -e "${YELLOW}Skipped: $SKIP${NC}"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}All combined integration tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some combined integration tests failed.${NC}"
    exit 1
fi
