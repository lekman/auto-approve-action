#!/bin/bash

# test-validate-labels.sh - Local test script for label validation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE_SCRIPT="$SCRIPT_DIR/validate-labels.sh"

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
    local mock_labels="$1"
    
    # Create a temporary directory for our mock
    export MOCK_DIR=$(mktemp -d)
    
    # Create mock gh script
    cat > "$MOCK_DIR/gh" << EOF
#!/bin/bash
if [[ "\$1" == "pr" ]] && [[ "\$2" == "view" ]]; then
    echo '$mock_labels'
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
    local mode="$3"
    local required_labels="$4"
    local mock_labels="$5"
    local pr_number="${6:-123}"
    
    if [[ -n "${CI:-}" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]]; then
        echo "Running test: $test_name"
    else
        echo -e "${YELLOW}Running test: $test_name${NC}"
    fi
    
    # Setup mock
    setup_mock_gh "$mock_labels"
    export GITHUB_TOKEN="mock-token"
    
    # Set environment variables
    export LABEL_MATCH_MODE="$mode"
    export REQUIRED_LABELS="$required_labels"
    export PR_NUMBER="$pr_number"
    
    # Run the validation script
    if bash "$VALIDATE_SCRIPT" > /dev/null 2>&1; then
        actual_result="pass"
    else
        actual_result="fail"
    fi
    
    # Cleanup mock
    cleanup_mock
    
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
    unset LABEL_MATCH_MODE REQUIRED_LABELS PR_NUMBER GITHUB_TOKEN || true
    echo
}

echo "Starting label validation tests..."
echo

# Test mode: all
run_test "Mode 'all' - all labels present" "pass" \
    "all" \
    "bug,enhancement,ready" \
    '{"labels": [{"name": "bug"}, {"name": "enhancement"}, {"name": "ready"}, {"name": "extra"}]}'

run_test "Mode 'all' - missing one label" "fail" \
    "all" \
    "bug,enhancement,ready" \
    '{"labels": [{"name": "bug"}, {"name": "enhancement"}]}'

run_test "Mode 'all' - no labels on PR" "fail" \
    "all" \
    "bug,enhancement" \
    '{"labels": []}'

run_test "Mode 'all' - empty required labels (should fail)" "fail" \
    "all" \
    "" \
    '{"labels": [{"name": "bug"}]}'

# Test mode: any
run_test "Mode 'any' - one label present" "pass" \
    "any" \
    "bug,enhancement,feature" \
    '{"labels": [{"name": "bug"}]}'

run_test "Mode 'any' - multiple labels present" "pass" \
    "any" \
    "bug,enhancement" \
    '{"labels": [{"name": "bug"}, {"name": "enhancement"}]}'

run_test "Mode 'any' - no matching labels" "fail" \
    "any" \
    "bug,enhancement" \
    '{"labels": [{"name": "documentation"}, {"name": "test"}]}'

run_test "Mode 'any' - no labels on PR" "fail" \
    "any" \
    "bug,enhancement" \
    '{"labels": []}'

# Test mode: none
run_test "Mode 'none' - no excluded labels present" "pass" \
    "none" \
    "do-not-merge,wip,blocked" \
    '{"labels": [{"name": "bug"}, {"name": "ready"}]}'

run_test "Mode 'none' - one excluded label present" "fail" \
    "none" \
    "do-not-merge,wip" \
    '{"labels": [{"name": "bug"}, {"name": "do-not-merge"}]}'

run_test "Mode 'none' - no labels on PR" "pass" \
    "none" \
    "do-not-merge,wip" \
    '{"labels": []}'

run_test "Mode 'none' - empty required labels" "pass" \
    "none" \
    "" \
    '{"labels": [{"name": "bug"}]}'

# Test with spaces in labels
run_test "Labels with spaces in CSV" "pass" \
    "all" \
    "bug, enhancement, ready" \
    '{"labels": [{"name": "bug"}, {"name": "enhancement"}, {"name": "ready"}]}'

# Test case sensitivity
run_test "Case sensitive matching" "fail" \
    "all" \
    "Bug" \
    '{"labels": [{"name": "bug"}]}'

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