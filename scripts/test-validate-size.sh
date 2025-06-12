#!/usr/bin/env bash

# test-validate-size.sh - Unit tests for validate-size.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE_SIZE_SCRIPT="$SCRIPT_DIR/validate-size.sh"

# Test helper functions
test_start() {
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -e "${YELLOW}Running test: $1${NC}"
}

test_pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✓ Test passed: $1${NC}"
}

test_fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}✗ Test failed: $1${NC}"
    echo "  Expected: $2"
    echo "  Actual: $3"
}

# Mock environment setup
setup_test_env() {
    export GITHUB_TOKEN="test-token"
    export PR_NUMBER="$1"
    export MAX_FILES_CHANGED="${2:-0}"
    export MAX_LINES_ADDED="${3:-0}"
    export MAX_LINES_REMOVED="${4:-0}"
    export MAX_TOTAL_LINES="${5:-0}"
    export SIZE_LIMIT_MESSAGE="${6:-PR exceeds configured size limits}"
    export GITHUB_STEP_SUMMARY="/tmp/test_summary_$$"
    > "$GITHUB_STEP_SUMMARY"
    
    # Create a temporary directory for mock commands
    export MOCK_BIN_DIR="/tmp/mock_bin_$$"
    mkdir -p "$MOCK_BIN_DIR"
    
    # Create mock gh command
    cat > "$MOCK_BIN_DIR/gh" << 'EOF'
#!/bin/bash
if [[ "$1" == "pr" && "$2" == "view" && "$4" == "--json" && "$5" == "additions,deletions,changedFiles" ]]; then
    # Return mock PR data based on PR number
    case "$3" in
        "100")
            # Small PR
            echo '{
                "additions": 10,
                "deletions": 5,
                "changedFiles": 2
            }'
            ;;
        "101")
            # Medium PR
            echo '{
                "additions": 150,
                "deletions": 75,
                "changedFiles": 8
            }'
            ;;
        "102")
            # Large PR
            echo '{
                "additions": 500,
                "deletions": 300,
                "changedFiles": 25
            }'
            ;;
        "103")
            # Huge PR
            echo '{
                "additions": 2000,
                "deletions": 1500,
                "changedFiles": 100
            }'
            ;;
        "104")
            # Mostly additions
            echo '{
                "additions": 1000,
                "deletions": 10,
                "changedFiles": 15
            }'
            ;;
        "105")
            # Mostly deletions
            echo '{
                "additions": 10,
                "deletions": 1000,
                "changedFiles": 15
            }'
            ;;
        "106")
            # Empty PR
            echo '{
                "additions": 0,
                "deletions": 0,
                "changedFiles": 0
            }'
            ;;
        *)
            echo "Error: Unknown PR" >&2
            exit 1
            ;;
    esac
else
    # For any other gh commands, fail
    echo "Error: Unexpected gh command: $@" >&2
    exit 1
fi
EOF
    chmod +x "$MOCK_BIN_DIR/gh"
    
    # Add mock directory to PATH (must be first)
    export PATH="$MOCK_BIN_DIR:$PATH"
}

cleanup_test_env() {
    unset GITHUB_TOKEN PR_NUMBER MAX_FILES_CHANGED MAX_LINES_ADDED MAX_LINES_REMOVED MAX_TOTAL_LINES SIZE_LIMIT_MESSAGE
    rm -f "$GITHUB_STEP_SUMMARY"
    
    # Clean up mock directory
    if [[ -n "$MOCK_BIN_DIR" ]] && [[ -d "$MOCK_BIN_DIR" ]]; then
        rm -rf "$MOCK_BIN_DIR"
    fi
    unset MOCK_BIN_DIR
    
    # Restore PATH
    export PATH="${PATH#*:}"
}

# Test 1: No size limits configured
test_start "No size limits configured"
setup_test_env "100" "0" "0" "0" "0"
if "$VALIDATE_SIZE_SCRIPT" > /dev/null 2>&1; then
    test_pass "Correctly skipped validation when no limits configured"
else
    test_fail "Should skip validation when no limits configured" "exit 0" "exit 1"
fi
cleanup_test_env

# Test 2: Small PR within all limits
test_start "Small PR within all limits"
setup_test_env "100" "5" "20" "10" "30"
if "$VALIDATE_SIZE_SCRIPT" > /dev/null 2>&1; then
    test_pass "Correctly approved small PR"
else
    test_fail "Should approve small PR within limits" "exit 0" "exit 1"
fi
cleanup_test_env

# Test 3: PR exceeds file count limit
test_start "PR exceeds file count limit"
setup_test_env "102" "20" "0" "0" "0"
if "$VALIDATE_SIZE_SCRIPT" > /dev/null 2>&1; then
    test_fail "Should reject PR exceeding file count" "exit 1" "exit 0"
else
    test_pass "Correctly rejected PR exceeding file count"
fi
cleanup_test_env

# Test 4: PR exceeds lines added limit
test_start "PR exceeds lines added limit"
setup_test_env "102" "0" "400" "0" "0"
if "$VALIDATE_SIZE_SCRIPT" > /dev/null 2>&1; then
    test_fail "Should reject PR exceeding lines added" "exit 1" "exit 0"
else
    test_pass "Correctly rejected PR exceeding lines added"
fi
cleanup_test_env

# Test 5: PR exceeds lines removed limit
test_start "PR exceeds lines removed limit"
setup_test_env "102" "0" "0" "200" "0"
if "$VALIDATE_SIZE_SCRIPT" > /dev/null 2>&1; then
    test_fail "Should reject PR exceeding lines removed" "exit 1" "exit 0"
else
    test_pass "Correctly rejected PR exceeding lines removed"
fi
cleanup_test_env

# Test 6: PR exceeds total lines limit
test_start "PR exceeds total lines limit"
setup_test_env "101" "0" "0" "0" "200"
if "$VALIDATE_SIZE_SCRIPT" > /dev/null 2>&1; then
    test_fail "Should reject PR exceeding total lines" "exit 1" "exit 0"
else
    test_pass "Correctly rejected PR exceeding total lines"
fi
cleanup_test_env

# Test 7: Multiple limits exceeded
test_start "Multiple limits exceeded"
setup_test_env "103" "50" "1000" "1000" "2000"
if "$VALIDATE_SIZE_SCRIPT" > /dev/null 2>&1; then
    test_fail "Should reject PR exceeding multiple limits" "exit 1" "exit 0"
else
    test_pass "Correctly rejected PR exceeding multiple limits"
fi
cleanup_test_env

# Test 8: Large PR with high limits
test_start "Large PR within high limits"
setup_test_env "103" "200" "3000" "2000" "5000"
if "$VALIDATE_SIZE_SCRIPT" > /dev/null 2>&1; then
    test_pass "Correctly approved large PR within high limits"
else
    test_fail "Should approve large PR within high limits" "exit 0" "exit 1"
fi
cleanup_test_env

# Test 9: PR with mostly additions
test_start "PR with mostly additions"
setup_test_env "104" "20" "800" "50" "0"
if "$VALIDATE_SIZE_SCRIPT" > /dev/null 2>&1; then
    test_fail "Should reject PR with too many additions" "exit 1" "exit 0"
else
    test_pass "Correctly rejected PR with too many additions"
fi
cleanup_test_env

# Test 10: PR with mostly deletions
test_start "PR with mostly deletions"
setup_test_env "105" "20" "50" "800" "0"
if "$VALIDATE_SIZE_SCRIPT" > /dev/null 2>&1; then
    test_fail "Should reject PR with too many deletions" "exit 1" "exit 0"
else
    test_pass "Correctly rejected PR with too many deletions"
fi
cleanup_test_env

# Test 11: Empty PR
test_start "Empty PR with limits"
setup_test_env "106" "10" "100" "100" "200"
if "$VALIDATE_SIZE_SCRIPT" > /dev/null 2>&1; then
    test_pass "Correctly approved empty PR"
else
    test_fail "Should approve empty PR" "exit 0" "exit 1"
fi
cleanup_test_env

# Test 12: Custom error message
test_start "Custom error message"
setup_test_env "102" "10" "0" "0" "0" "Custom: PR is too large for auto-approval"
OUTPUT=$("$VALIDATE_SIZE_SCRIPT" 2>&1 || true)
if echo "$OUTPUT" | grep -q "Custom: PR is too large for auto-approval"; then
    test_pass "Custom error message displayed correctly"
else
    test_fail "Custom error message not displayed" "Custom message in output" "No custom message"
fi
cleanup_test_env

# Test 13: Exact limit boundary (at limit)
test_start "PR at exact file limit"
setup_test_env "101" "8" "0" "0" "0"
if "$VALIDATE_SIZE_SCRIPT" > /dev/null 2>&1; then
    test_pass "Correctly approved PR at exact limit"
else
    test_fail "Should approve PR at exact limit" "exit 0" "exit 1"
fi
cleanup_test_env

# Test 14: Exact limit boundary (just over)
test_start "PR just over file limit"
setup_test_env "101" "7" "0" "0" "0"
if "$VALIDATE_SIZE_SCRIPT" > /dev/null 2>&1; then
    test_fail "Should reject PR just over limit" "exit 1" "exit 0"
else
    test_pass "Correctly rejected PR just over limit"
fi
cleanup_test_env

# Test 15: Total lines check with separate limits
test_start "Total lines validation"
setup_test_env "101" "0" "200" "200" "200"
# This PR has 150 additions + 75 deletions = 225 total
if "$VALIDATE_SIZE_SCRIPT" > /dev/null 2>&1; then
    test_fail "Should reject PR exceeding total lines" "exit 1" "exit 0"
else
    test_pass "Correctly rejected PR exceeding total lines"
fi
cleanup_test_env

# Summary
echo ""
echo "================================"
echo "Test Summary:"
echo "Tests run: $TESTS_RUN"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
echo "================================"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi