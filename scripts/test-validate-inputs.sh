#!/bin/bash

# test-validate-inputs.sh - Local test script for input validation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE_SCRIPT="$SCRIPT_DIR/validate-inputs.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local expected_result="$2"  # "pass" or "fail"
    shift 2
    
    echo -e "${YELLOW}Running test: $test_name${NC}"
    
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
        echo -e "${GREEN}✓ Test passed${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ Test failed (expected: $expected_result, got: $actual_result)${NC}"
        ((TESTS_FAILED++))
    fi
    
    # Clean up environment
    unset ALLOWED_AUTHORS REQUIRED_LABELS LABEL_MATCH_MODE WAIT_FOR_CHECKS MAX_WAIT_TIME REQUIRED_CHECKS
    echo
}

echo "Starting validation tests..."
echo

# Valid input tests
run_test "Valid minimal inputs" "pass" \
    "ALLOWED_AUTHORS=user1,user2" \
    "LABEL_MATCH_MODE=none" \
    "WAIT_FOR_CHECKS=true" \
    "MAX_WAIT_TIME=30"

run_test "Valid with all inputs" "pass" \
    "ALLOWED_AUTHORS=user1,user2,dependabot[bot]" \
    "REQUIRED_LABELS=approved,ready" \
    "LABEL_MATCH_MODE=all" \
    "WAIT_FOR_CHECKS=true" \
    "MAX_WAIT_TIME=60" \
    "REQUIRED_CHECKS=CI Build,Unit Tests"

run_test "Valid with spaces in CSV" "pass" \
    "ALLOWED_AUTHORS=user1, user2, user3" \
    "REQUIRED_LABELS=bug, enhancement" \
    "LABEL_MATCH_MODE=any" \
    "WAIT_FOR_CHECKS=false" \
    "MAX_WAIT_TIME=15"

# Invalid allowed-authors tests
run_test "Missing allowed-authors" "fail" \
    "LABEL_MATCH_MODE=all" \
    "WAIT_FOR_CHECKS=true" \
    "MAX_WAIT_TIME=30"

run_test "Empty allowed-authors" "fail" \
    "ALLOWED_AUTHORS=" \
    "LABEL_MATCH_MODE=all" \
    "WAIT_FOR_CHECKS=true" \
    "MAX_WAIT_TIME=30"

run_test "Invalid CSV format - trailing comma" "fail" \
    "ALLOWED_AUTHORS=user1,user2," \
    "LABEL_MATCH_MODE=all" \
    "WAIT_FOR_CHECKS=true" \
    "MAX_WAIT_TIME=30"

# Invalid label-match-mode tests
run_test "Invalid label-match-mode" "fail" \
    "ALLOWED_AUTHORS=user1" \
    "LABEL_MATCH_MODE=invalid" \
    "WAIT_FOR_CHECKS=true" \
    "MAX_WAIT_TIME=30"

# Invalid wait-for-checks tests
run_test "Invalid wait-for-checks" "fail" \
    "ALLOWED_AUTHORS=user1" \
    "LABEL_MATCH_MODE=all" \
    "WAIT_FOR_CHECKS=yes" \
    "MAX_WAIT_TIME=30"

# Invalid max-wait-time tests
run_test "Negative max-wait-time" "fail" \
    "ALLOWED_AUTHORS=user1" \
    "LABEL_MATCH_MODE=all" \
    "WAIT_FOR_CHECKS=true" \
    "MAX_WAIT_TIME=-5"

run_test "Zero max-wait-time" "fail" \
    "ALLOWED_AUTHORS=user1" \
    "LABEL_MATCH_MODE=all" \
    "WAIT_FOR_CHECKS=true" \
    "MAX_WAIT_TIME=0"

run_test "Non-numeric max-wait-time" "fail" \
    "ALLOWED_AUTHORS=user1" \
    "LABEL_MATCH_MODE=all" \
    "WAIT_FOR_CHECKS=true" \
    "MAX_WAIT_TIME=abc"

run_test "Excessive max-wait-time" "fail" \
    "ALLOWED_AUTHORS=user1" \
    "LABEL_MATCH_MODE=all" \
    "WAIT_FOR_CHECKS=true" \
    "MAX_WAIT_TIME=500"

# Label mode validation rules
run_test "label-match-mode 'all' without labels" "fail" \
    "ALLOWED_AUTHORS=user1" \
    "LABEL_MATCH_MODE=all" \
    "WAIT_FOR_CHECKS=true" \
    "MAX_WAIT_TIME=30"

run_test "label-match-mode 'any' without labels" "fail" \
    "ALLOWED_AUTHORS=user1" \
    "LABEL_MATCH_MODE=any" \
    "WAIT_FOR_CHECKS=true" \
    "MAX_WAIT_TIME=30"

run_test "label-match-mode 'none' with labels" "fail" \
    "ALLOWED_AUTHORS=user1" \
    "REQUIRED_LABELS=do-not-merge" \
    "LABEL_MATCH_MODE=none" \
    "WAIT_FOR_CHECKS=true" \
    "MAX_WAIT_TIME=30"

run_test "label-match-mode 'none' without labels" "pass" \
    "ALLOWED_AUTHORS=user1" \
    "LABEL_MATCH_MODE=none" \
    "WAIT_FOR_CHECKS=true" \
    "MAX_WAIT_TIME=30"

# Summary
echo "======================================="
echo -e "${GREEN}Tests passed: $TESTS_PASSED${NC}"
echo -e "${RED}Tests failed: $TESTS_FAILED${NC}"
echo "======================================="

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi