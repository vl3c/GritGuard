#!/bin/bash
# GritGuard Integration Tests
# Tests git identity propagation, write paths, and sandbox behavior end-to-end.
#
# Usage: ./tests/test_integration.sh
#
# Tests marked (API) require a valid Claude/Codex auth and will SKIP if unavailable.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GRITGUARD_DIR="$(dirname "$SCRIPT_DIR")"
AGENT_DIR="${AGENT_DIR:-$(dirname "$GRITGUARD_DIR")}"
TEST_REPO="/tmp/gritguard-integ-$$"
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
    rm -rf "$TEST_REPO" /tmp/gritguard-bare-$$ 2>/dev/null || true
}
trap cleanup EXIT

# Setup a test repo with local git config
setup_test_repo() {
    cleanup
    mkdir -p "$TEST_REPO"
    cd "$TEST_REPO"
    git init -q
    git config user.email "integration@gritguard.test"
    git config user.name "Integration Tester"
    echo "# Integration Test" > README.md
    git add . && git commit -q -m "init"
    cd "$AGENT_DIR"
}

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
    # Try a trivial command to see if auth works
    timeout 15 claude -p "reply with exactly: OK" --max-turns 1 2>/dev/null | grep -q "OK" 2>/dev/null
}

echo "========================================"
echo "GritGuard Integration Test Suite"
echo "========================================"
echo ""

log_info "Setting up test repository at $TEST_REPO"
setup_test_repo

# ─── Test 1: git_identity_from_local_config ─────────────────────────────
log_info "Test 1: Git identity reads from local repo config"
# Clear any env vars that would take priority
unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL 2>/dev/null || true
if output=$("$GRITGUARD_DIR/bin/gritguard" --repo "$TEST_REPO" 'echo "$GIT_AUTHOR_NAME|$GIT_AUTHOR_EMAIL"' 2>&1); then
    if echo "$output" | grep -q "Integration Tester|integration@gritguard.test"; then
        log_pass "git_identity_from_local_config"
    else
        log_fail "git_identity_from_local_config — got: $output"
    fi
else
    log_fail "git_identity_from_local_config — gritguard exited $?"
fi

# ─── Test 2: git_identity_from_env_override ──────────────────────────────
log_info "Test 2: Explicit GIT_AUTHOR_* env vars are preserved"
export GIT_AUTHOR_NAME="Custom Author"
export GIT_AUTHOR_EMAIL="custom@override.test"
if output=$("$GRITGUARD_DIR/bin/gritguard" --repo "$TEST_REPO" 'echo "$GIT_AUTHOR_NAME|$GIT_AUTHOR_EMAIL"' 2>&1); then
    if echo "$output" | grep -q "Custom Author|custom@override.test"; then
        log_pass "git_identity_from_env_override"
    else
        log_fail "git_identity_from_env_override — got: $output"
    fi
else
    log_fail "git_identity_from_env_override — gritguard exited $?"
fi
unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL 2>/dev/null || true

# ─── Test 3: git_identity_fallback ───────────────────────────────────────
log_info "Test 3: Fallback identity when repo has no config"
unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL 2>/dev/null || true
BARE_REPO="/tmp/gritguard-bare-$$"
mkdir -p "$BARE_REPO"
cd "$BARE_REPO" && git init -q && cd "$AGENT_DIR"
# Remove any local config
git -C "$BARE_REPO" config --unset user.name 2>/dev/null || true
git -C "$BARE_REPO" config --unset user.email 2>/dev/null || true
if output=$("$GRITGUARD_DIR/bin/gritguard" --repo "$BARE_REPO" 'echo "GGID:$GIT_AUTHOR_NAME|$GIT_AUTHOR_EMAIL"' 2>&1); then
    # Extract the identity line using a unique marker to avoid matching stray output
    id_line=$(echo "$output" | grep "^GGID:" | head -1)
    if [[ -n "$id_line" ]]; then
        id_name=$(echo "$id_line" | sed 's/^GGID:\(.*\)|.*/\1/')
        if [[ -n "$id_name" && "$id_name" != "GGID:" ]]; then
            log_pass "git_identity_fallback"
        else
            log_fail "git_identity_fallback — name was empty in: $id_line"
        fi
    else
        log_fail "git_identity_fallback — no GGID marker in output: $output"
    fi
else
    log_fail "git_identity_fallback — gritguard exited $?"
fi
rm -rf "$BARE_REPO"

# ─── Test 4: git_commit_inside_sandbox ───────────────────────────────────
log_info "Test 4: Git commit works inside srt sandbox"
unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL 2>/dev/null || true
if output=$("$GRITGUARD_DIR/bin/gritguard" --repo "$TEST_REPO" \
    'echo "sandbox file" > sandbox-test.txt && git add sandbox-test.txt && git commit -m "sandbox commit" && git log --oneline -1' 2>&1); then
    if echo "$output" | grep -q "sandbox commit"; then
        log_pass "git_commit_inside_sandbox"
    else
        log_fail "git_commit_inside_sandbox — got: $output"
    fi
else
    log_fail "git_commit_inside_sandbox — gritguard exited $?"
fi

# ─── Test 5: write_path_claude_dir ───────────────────────────────────────
log_info "Test 5: generate-config includes ~/.claude in allowWrite"
if config_output=$("$GRITGUARD_DIR/bin/generate-config" "$TEST_REPO" 2>&1); then
    if echo "$config_output" | grep -q "$HOME/.claude"; then
        log_pass "write_path_claude_dir"
    else
        log_fail "write_path_claude_dir — ~/.claude not in allowWrite"
    fi
else
    log_fail "write_path_claude_dir — generate-config failed"
fi

# ─── Test 6: write_path_codex_dir ────────────────────────────────────────
log_info "Test 6: generate-config includes ~/.codex in allowWrite"
if echo "$config_output" | grep -q "$HOME/.codex"; then
    log_pass "write_path_codex_dir"
else
    log_fail "write_path_codex_dir — ~/.codex not in allowWrite"
fi

# ─── Test 7: write_path_local_dir ────────────────────────────────────────
log_info "Test 7: generate-config includes ~/.local in allowWrite"
if echo "$config_output" | grep -q "$HOME/.local"; then
    log_pass "write_path_local_dir"
else
    log_fail "write_path_local_dir — ~/.local not in allowWrite"
fi

# ─── Test 8: claude_dir_writable_in_sandbox ──────────────────────────────
log_info "Test 8: Can mkdir/touch inside ~/.claude in srt"
if output=$("$GRITGUARD_DIR/bin/gritguard" --repo "$TEST_REPO" \
    "mkdir -p $HOME/.claude/test-integ-$$ && touch $HOME/.claude/test-integ-$$/marker && echo OK" 2>&1); then
    if echo "$output" | grep -q "OK"; then
        log_pass "claude_dir_writable_in_sandbox"
    else
        log_fail "claude_dir_writable_in_sandbox — got: $output"
    fi
else
    log_fail "claude_dir_writable_in_sandbox — gritguard exited $?"
fi
# Clean up
rm -rf "$HOME/.claude/test-integ-$$" 2>/dev/null || true

# ─── Test 9: chatgpt_domain_in_config ────────────────────────────────────
log_info "Test 9: chatgpt.com in allowedDomains"
if echo "$config_output" | grep -q "chatgpt.com"; then
    log_pass "chatgpt_domain_in_config"
else
    log_fail "chatgpt_domain_in_config — chatgpt.com not in allowedDomains"
fi

# ─── Test 10: claude_cli_in_sandbox ──────────────────────────────────────
log_info "Test 10: claude --version works inside sandbox"
if output=$("$GRITGUARD_DIR/bin/gritguard" --repo "$TEST_REPO" "claude --version" 2>&1); then
    if echo "$output" | grep -qiE "(claude|[0-9]+\.[0-9]+)"; then
        log_pass "claude_cli_in_sandbox"
    else
        log_fail "claude_cli_in_sandbox — got: $output"
    fi
else
    log_fail "claude_cli_in_sandbox — gritguard exited $?"
fi

# ─── Test 11: codex_cli_in_sandbox ───────────────────────────────────────
log_info "Test 11: codex --version works inside sandbox"
if command -v codex &>/dev/null; then
    if output=$("$GRITGUARD_DIR/bin/gritguard" --repo "$TEST_REPO" "codex --version" 2>&1); then
        if echo "$output" | grep -qiE "(codex|[0-9]+\.[0-9]+)"; then
            log_pass "codex_cli_in_sandbox"
        else
            log_fail "codex_cli_in_sandbox — got: $output"
        fi
    else
        log_fail "codex_cli_in_sandbox — gritguard exited $?"
    fi
else
    log_skip "codex_cli_in_sandbox — codex not installed"
fi

# ─── Test 12: claude_cli_commit_in_sandbox (API) ─────────────────────────
log_info "Test 12: Claude creates+commits a file inside sandbox (API)"
if claude_is_authed; then
    # Re-setup repo fresh for this test
    setup_test_repo
    output=$("$GRITGUARD_DIR/bin/gritguard" --repo "$TEST_REPO" \
        "claude -p 'Run: echo INTEGRATION > hello.txt && git add hello.txt && git commit -m api-test-commit' --max-turns 2 --allowedTools Bash" 2>&1) || true
    # Check the commit landed (regardless of claude exit code)
    commit_count=$(git -C "$TEST_REPO" log --oneline 2>/dev/null | wc -l)
    if git -C "$TEST_REPO" log --oneline 2>/dev/null | grep -qi "api-test-commit"; then
        log_pass "claude_cli_commit_in_sandbox"
    elif [[ "$commit_count" -gt 1 ]]; then
        # A new commit was made, even if message differs
        log_pass "claude_cli_commit_in_sandbox"
    else
        log_fail "claude_cli_commit_in_sandbox — no new commit. Output: $(echo "$output" | tail -5)"
    fi
else
    log_skip "claude_cli_commit_in_sandbox — Claude CLI not authenticated"
fi

echo ""
echo "========================================"
echo "Integration Test Results"
echo "========================================"
echo -e "${GREEN}Passed: $PASS${NC}"
echo -e "${RED}Failed: $FAIL${NC}"
echo -e "${YELLOW}Skipped: $SKIP${NC}"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}All integration tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some integration tests failed.${NC}"
    exit 1
fi
