#!/bin/bash

# test-validate-inputs.sh - Local test script for input validation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE_SCRIPT="$SCRIPT_DIR/validate-inputs.sh"

# Detect if running in CI
if [[ -n "${CI:-}" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    # No colors in CI
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
else
    # Colors for output
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m' # No Color
fi

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local expected_result="$2"  # "pass" or "fail"
    shift 2
    
    if [[ -n "${CI:-}" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]]; then
        echo "Running test: $test_name"
    else
        echo -e "${YELLOW}Running test: $test_name${NC}"
    fi
    
    # Set environment variables from remaining arguments
    while [[ $# -gt 0 ]]; do
        export "$1"
        shift
    done
    
    # Run the validation script
    if bash "$VALIDATE_SCRIPT" > /dev/null 2>&1; then
        actual_result="pass"
    else
        actual_result="fail"
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
    unset ALLOWED_AUTHORS REQUIRED_LABELS LABEL_MATCH_MODE MERGE_METHOD PATH_FILTERS MAX_FILES_CHANGED MAX_LINES_ADDED MAX_LINES_REMOVED MAX_TOTAL_LINES 2>/dev/null || true
    echo
}

echo "Starting validation tests..."
echo

# Valid input tests
run_test "Valid minimal inputs" "pass" \
    "ALLOWED_AUTHORS=user1,user2" \
    "LABEL_MATCH_MODE=none"

run_test "Valid with all inputs" "pass" \
    "ALLOWED_AUTHORS=user1,user2,dependabot[bot]" \
    "REQUIRED_LABELS=approved,ready" \
    "LABEL_MATCH_MODE=all" \
    "MERGE_METHOD=squash" \
    "PATH_FILTERS=src/**/*.js,tests/**/*.js" \
    "MAX_FILES_CHANGED=50" \
    "MAX_LINES_ADDED=1000"

run_test "Valid with spaces in CSV" "pass" \
    "ALLOWED_AUTHORS=user1, user2, user3" \
    "REQUIRED_LABELS=bug, enhancement" \
    "LABEL_MATCH_MODE=any"

# Invalid allowed-authors tests
run_test "Missing allowed-authors" "fail" \
    "LABEL_MATCH_MODE=all"

run_test "Empty allowed-authors" "fail" \
    "ALLOWED_AUTHORS=" \
    "LABEL_MATCH_MODE=all"

run_test "Invalid CSV format - trailing comma" "fail" \
    "ALLOWED_AUTHORS=user1,user2," \
    "LABEL_MATCH_MODE=all"

# Invalid label-match-mode tests
run_test "Invalid label-match-mode" "fail" \
    "ALLOWED_AUTHORS=user1" \
    "LABEL_MATCH_MODE=invalid"

# Invalid merge-method tests
run_test "Invalid merge-method" "fail" \
    "ALLOWED_AUTHORS=user1" \
    "LABEL_MATCH_MODE=all" \
    "MERGE_METHOD=invalid"

# Invalid size limit tests
run_test "Negative max-files-changed" "fail" \
    "ALLOWED_AUTHORS=user1" \
    "LABEL_MATCH_MODE=all" \
    "MAX_FILES_CHANGED=-5"

run_test "Non-numeric max-lines-added" "fail" \
    "ALLOWED_AUTHORS=user1" \
    "LABEL_MATCH_MODE=all" \
    "MAX_LINES_ADDED=abc"

# Label mode validation rules
run_test "label-match-mode 'all' without labels" "fail" \
    "ALLOWED_AUTHORS=user1" \
    "LABEL_MATCH_MODE=all"

run_test "label-match-mode 'any' without labels" "fail" \
    "ALLOWED_AUTHORS=user1" \
    "LABEL_MATCH_MODE=any"

run_test "label-match-mode 'none' with labels (valid)" "pass" \
    "ALLOWED_AUTHORS=user1" \
    "REQUIRED_LABELS=do-not-merge" \
    "LABEL_MATCH_MODE=none"

run_test "label-match-mode 'none' without labels" "pass" \
    "ALLOWED_AUTHORS=user1" \
    "LABEL_MATCH_MODE=none"

# Summary
echo "======================================="
if [[ -n "${CI:-}" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    echo "Tests passed: $TESTS_PASSED"
    echo "Tests failed: $TESTS_FAILED"
else
    echo -e "${GREEN}Tests passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Tests failed: $TESTS_FAILED${NC}"
fi
echo "======================================="

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi