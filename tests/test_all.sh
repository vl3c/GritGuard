#!/bin/bash
# Unified test runner for GritGuard
# Runs all test suites for both srt/bubblewrap and Docker backends
#
# Usage: ./tests/test_all.sh [options]
#   --quick     Run quick tests only (no network tests)
#   --srt       Run only srt/bubblewrap tests
#   --docker    Run only Docker tests
#   --help      Show this help

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GRITGUARD_DIR="$(dirname "$SCRIPT_DIR")"
AGENT_DIR="$(dirname "$GRITGUARD_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Counters
TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_SKIP=0
SUITES_RUN=0
SUITES_FAILED=0

# Options
RUN_SRT=true
RUN_DOCKER=true
QUICK_ONLY=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --quick)
            QUICK_ONLY=true
            shift
            ;;
        --srt)
            RUN_DOCKER=false
            shift
            ;;
        --docker)
            RUN_SRT=false
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --quick     Run quick tests only (no network tests)"
            echo "  --srt       Run only srt/bubblewrap tests"
            echo "  --docker    Run only Docker tests"
            echo "  --help      Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

cd "$GRITGUARD_DIR"

echo -e "${BOLD}========================================"
echo "GritGuard Unified Test Suite"
echo "========================================${NC}"
echo ""

# Function to run a test suite and capture results
run_suite() {
    local name="$1"
    local script="$2"
    local description="$3"

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Running: $name${NC}"
    echo -e "${YELLOW}$description${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    SUITES_RUN=$((SUITES_RUN + 1))

    # Run the test and capture output
    set +e
    output=$("$script" 2>&1)
    exit_code=$?
    set -e

    echo "$output"
    echo ""

    # Parse results from output
    if echo "$output" | grep -q "Passed:"; then
        passed=$(echo "$output" | grep -oP "Passed: \K\d+" | tail -1)
        failed=$(echo "$output" | grep -oP "Failed: \K\d+" | tail -1)
        skipped=$(echo "$output" | grep -oP "Skipped: \K\d+" || echo "0")

        TOTAL_PASS=$((TOTAL_PASS + ${passed:-0}))
        TOTAL_FAIL=$((TOTAL_FAIL + ${failed:-0}))
        TOTAL_SKIP=$((TOTAL_SKIP + ${skipped:-0}))
    fi

    if [[ $exit_code -ne 0 ]]; then
        SUITES_FAILED=$((SUITES_FAILED + 1))
        echo -e "${RED}Suite failed with exit code $exit_code${NC}"
    else
        echo -e "${GREEN}Suite completed successfully${NC}"
    fi

    echo ""
    return $exit_code
}

# Check what's available
SRT_AVAILABLE=false
DOCKER_AVAILABLE=false

# Check for srt in common locations
# Note: Use AGENT_DIR-relative path as fallback for sudo environments
if command -v srt &> /dev/null || \
   [[ -x "$AGENT_DIR/.npm/bin/srt" ]] || \
   [[ -x "$HOME/agent/.npm/bin/srt" ]] || \
   [[ -x "$HOME/.npm/bin/srt" ]]; then
    SRT_AVAILABLE=true
fi

if command -v docker &> /dev/null && docker info &> /dev/null 2>&1; then
    DOCKER_AVAILABLE=true
fi

echo -e "${YELLOW}Backend availability:${NC}"
echo -e "  srt/bubblewrap: $([ "$SRT_AVAILABLE" = true ] && echo -e "${GREEN}available${NC}" || echo -e "${RED}not available${NC}")"
echo -e "  Docker:         $([ "$DOCKER_AVAILABLE" = true ] && echo -e "${GREEN}available${NC}" || echo -e "${RED}not available${NC}")"
echo ""

# Track if any suites were skipped due to missing backends
SKIPPED_SUITES=""

# Run srt/bubblewrap tests
if [[ "$RUN_SRT" = true ]]; then
    if [[ "$SRT_AVAILABLE" = true ]]; then
        # Note: srt tests need to run from parent directory to avoid submodule .git issues
        # The test scripts reference AGENT_DIR and SRT_SETTINGS with absolute paths
        PARENT_DIR="$(dirname "$GRITGUARD_DIR")"

        if [[ "$QUICK_ONLY" = true ]]; then
            run_suite "srt Quick Tests" "$GRITGUARD_DIR/tests/test_sandbox_quick.sh" "Quick sandbox tests (no network)" || true
        else
            # Run from parent to avoid .claude file conflicts in submodule
            echo -e "${YELLOW}Note: Running srt tests from parent directory to avoid submodule issues${NC}"
            pushd "$PARENT_DIR" > /dev/null
            run_suite "srt Full Tests" "$GRITGUARD_DIR/tests/test_sandbox.sh" "Full sandbox tests including network" || true
            popd > /dev/null
        fi

        run_suite "gritguard Wrapper Tests" "$GRITGUARD_DIR/tests/test_gritguard.sh" "Dynamic config and --repo flag tests" || true
    else
        SKIPPED_SUITES="$SKIPPED_SUITES srt"
        echo -e "${YELLOW}Skipping srt tests - srt not available${NC}"
        echo ""
    fi
fi

# Run integration tests (srt-based, always with srt)
if [[ "$RUN_SRT" = true ]]; then
    if [[ "$SRT_AVAILABLE" = true ]]; then
        run_suite "Integration Tests" "$GRITGUARD_DIR/tests/test_integration.sh" "Git identity, write paths, and sandbox integration" || true

        # Run SelfAssembler combined tests if selfassembler is installed
        if command -v selfassembler &>/dev/null || python3 -m selfassembler.cli --version &>/dev/null 2>&1; then
            run_suite "SelfAssembler Integration" "$GRITGUARD_DIR/tests/test_selfassembler_integration.sh" "SelfAssembler inside GritGuard sandbox" || true
        else
            echo -e "${YELLOW}Skipping SelfAssembler integration tests - selfassembler not installed${NC}"
            echo ""
        fi
    fi
fi

# Run Docker tests
if [[ "$RUN_DOCKER" = true ]]; then
    if [[ "$DOCKER_AVAILABLE" = true ]]; then
        # Check if image exists
        if ! docker image inspect gritguard-sandbox:latest &> /dev/null; then
            echo -e "${YELLOW}Docker image not found, building...${NC}"
            docker build -t gritguard-sandbox:latest "$GRITGUARD_DIR/docker/" || {
                echo -e "${RED}Failed to build Docker image${NC}"
                SKIPPED_SUITES="$SKIPPED_SUITES docker"
            }
        fi

        if docker image inspect gritguard-sandbox:latest &> /dev/null; then
            run_suite "Docker Tests" "./tests/test_docker.sh" "Docker isolation tests" || true
        fi
    else
        SKIPPED_SUITES="$SKIPPED_SUITES docker"
        echo -e "${YELLOW}Skipping Docker tests - Docker not available${NC}"
        echo ""
    fi
fi

# Final summary
echo -e "${BOLD}========================================"
echo "Final Results"
echo "========================================${NC}"
echo ""
echo -e "Test Suites Run:    ${BOLD}$SUITES_RUN${NC}"
echo -e "Test Suites Failed: $([ $SUITES_FAILED -gt 0 ] && echo -e "${RED}$SUITES_FAILED${NC}" || echo -e "${GREEN}0${NC}")"
echo ""
echo -e "${GREEN}Total Passed:  $TOTAL_PASS${NC}"
echo -e "${RED}Total Failed:  $TOTAL_FAIL${NC}"
echo -e "${YELLOW}Total Skipped: $TOTAL_SKIP${NC}"
echo ""

if [[ -n "$SKIPPED_SUITES" ]]; then
    echo -e "${YELLOW}Skipped backends:$SKIPPED_SUITES${NC}"
    echo ""
fi

if [[ $TOTAL_FAIL -eq 0 && $SUITES_FAILED -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}${BOLD}Some tests failed.${NC}"
    exit 1
fi
