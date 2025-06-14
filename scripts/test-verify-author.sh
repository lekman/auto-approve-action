#!/bin/bash

# test-verify-author.sh - Local test script for author verification

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFY_SCRIPT="$SCRIPT_DIR/verify-author.sh"

# Detect if running in CI
if [[ -n "${CI:-}" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    # No colors in CI
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
else
    # Colors for output
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
fi

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Function to mock GitHub CLI responses
setup_mock_gh() {
    local mock_author="$1"
    
    # Create a temporary directory for our mock
    export MOCK_DIR=$(mktemp -d)
    
    # Create mock gh script
    cat > "$MOCK_DIR/gh" << EOF
#!/bin/bash
if [[ "\$1" == "pr" ]] && [[ "\$2" == "view" ]]; then
    echo '{"author": {"login": "$mock_author"}}'
    exit 0
fi
exit 1
EOF
    
    chmod +x "$MOCK_DIR/gh"
    
    # Add mock to PATH
    export PATH="$MOCK_DIR:$PATH"
}

# Function to cleanup mock
cleanup_mock() {
    if [[ -n "${MOCK_DIR:-}" ]] && [[ -d "$MOCK_DIR" ]]; then
        rm -rf "$MOCK_DIR"
    fi
    unset MOCK_DIR || true
}

# Function to run a test
run_test() {
    local test_name="$1"
    local expected_result="$2"  # "pass" or "fail"
    local mock_author="$3"
    local allowed_authors="$4"
    local pr_number="${5:-123}"
    
    if [[ -n "${CI:-}" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]]; then
        echo "Running test: $test_name"
    else
        echo -e "${YELLOW}Running test: $test_name${NC}"
    fi
    
    # Skip if no GitHub token (for CI environments)
    if [[ -z "${GITHUB_TOKEN:-}" ]] && [[ "$mock_author" != "MOCK:"* ]]; then
        if [[ -n "${CI:-}" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]]; then
            echo "⚠ Test skipped (no GITHUB_TOKEN)"
        else
            echo -e "${BLUE}⚠ Test skipped (no GITHUB_TOKEN)${NC}"
        fi
        TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
        echo
        return
    fi
    
    # Setup mock if author starts with "MOCK:"
    if [[ "$mock_author" == "MOCK:"* ]]; then
        mock_author="${mock_author#MOCK:}"
        setup_mock_gh "$mock_author"
        export GITHUB_TOKEN="mock-token"
    fi
    
    # Set environment variables
    export ALLOWED_AUTHORS="$allowed_authors"
    export PR_NUMBER="$pr_number"
    
    # Run the verification script
    if bash "$VERIFY_SCRIPT" > /dev/null 2>&1; then
        actual_result="pass"
    else
        actual_result="fail"
    fi
    
    # Cleanup mock if used
    if [[ -n "${MOCK_DIR:-}" ]]; then
        cleanup_mock
    fi
    
    # Check if result matches expectation
    if [[ "$actual_result" == "$expected_result" ]]; then
        if [[ -n "${CI:-}" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]]; then
            echo "✓ Test passed"
        else
            echo -e "${GREEN}✓ Test passed${NC}"
        fi
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        if [[ -n "${CI:-}" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]]; then
            echo "✗ Test failed (expected: $expected_result, got: $actual_result)"
        else
            echo -e "${RED}✗ Test failed (expected: $expected_result, got: $actual_result)${NC}"
        fi
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    # Clean up environment
    unset ALLOWED_AUTHORS PR_NUMBER GITHUB_TOKEN || true
    echo
}

echo "Starting author verification tests..."
echo
echo "Note: Tests using real GitHub API require GITHUB_TOKEN to be set"
echo "      Mock tests will run regardless of token availability"
echo

# Mock tests (always run)
run_test "Valid author - single allowed" "pass" \
    "MOCK:user1" \
    "user1" \
    "123"

run_test "Valid author - multiple allowed" "pass" \
    "MOCK:user2" \
    "user1,user2,user3" \
    "123"

run_test "Valid bot author" "pass" \
    "MOCK:dependabot[bot]" \
    "user1,dependabot[bot],renovate[bot]" \
    "123"

run_test "Invalid author - not in list" "fail" \
    "MOCK:unauthorized-user" \
    "user1,user2,user3" \
    "123"

run_test "Case sensitivity test - should fail" "fail" \
    "MOCK:User1" \
    "user1" \
    "123"

run_test "Author with spaces in allowlist" "pass" \
    "MOCK:user1" \
    "user1, user2, user3" \
    "123"

run_test "Complex bot name" "pass" \
    "MOCK:github-actions[bot]" \
    "dependabot[bot],github-actions[bot],renovate[bot]" \
    "123"

# Edge cases
run_test "Empty author (should fail)" "fail" \
    "MOCK:" \
    "user1,user2" \
    "123"

# API failure simulation (using invalid PR number with real API)
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    if [[ -n "${CI:-}" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]]; then
        echo "Running real API tests..."
    else
        echo -e "${YELLOW}Running real API tests...${NC}"
    fi
    
    # This should fail because PR 999999999 likely doesn't exist
    run_test "API failure - invalid PR" "fail" \
        "" \
        "user1,user2" \
        "999999999"
fi

# Summary
echo "======================================="
if [[ -n "${CI:-}" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    echo "Tests passed: $TESTS_PASSED"
    echo "Tests failed: $TESTS_FAILED"
    echo "Tests skipped: $TESTS_SKIPPED"
else
    echo -e "${GREEN}Tests passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Tests failed: $TESTS_FAILED${NC}"
    echo -e "${BLUE}Tests skipped: $TESTS_SKIPPED${NC}"
fi
echo "======================================="

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi

# Explicit success exit
exit 0