#!/bin/bash

# test-monitor-checks.sh - Local test script for status check monitoring

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITOR_SCRIPT="$SCRIPT_DIR/monitor-checks.sh"

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

# Function to mock GitHub GraphQL API responses
setup_mock_gh() {
    local mock_response="$1"
    
    # Create a temporary directory for our mock
    export MOCK_DIR=$(mktemp -d)
    
    # Create mock gh script
    cat > "$MOCK_DIR/gh" << EOF
#!/bin/bash
if [[ "\$1" == "api" ]] && [[ "\$2" == "graphql" ]]; then
    echo '$mock_response'
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

# Function to create mock response
create_mock_response() {
    local state="$1"
    local checks="$2"
    
    cat << EOF
{
  "data": {
    "repository": {
      "pullRequest": {
        "commits": {
          "nodes": [{
            "commit": {
              "statusCheckRollup": {
                "state": "$state",
                "contexts": {
                  "nodes": $checks
                }
              }
            }
          }]
        }
      }
    }
  }
}
EOF
}

# Function to run a test
run_test() {
    local test_name="$1"
    local expected_result="$2"  # "pass" or "fail"
    local wait_for_checks="$3"
    local max_wait_time="$4"
    local required_checks="$5"
    local mock_response="$6"
    
    if [[ -n "${CI:-}" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]]; then
        echo "Running test: $test_name"
    else
        echo -e "${YELLOW}Running test: $test_name${NC}"
    fi
    
    # Setup mock
    setup_mock_gh "$mock_response"
    export GITHUB_TOKEN="mock-token"
    export GITHUB_REPOSITORY="owner/repo"
    
    # Set environment variables
    export WAIT_FOR_CHECKS="$wait_for_checks"
    export MAX_WAIT_TIME="$max_wait_time"
    export REQUIRED_CHECKS="$required_checks"
    export PR_NUMBER="123"
    
    # Run the monitor script
    # Note: timeout command may not be available on all systems
    local timeout_cmd=""
    if command -v timeout >/dev/null 2>&1; then
        timeout_cmd="timeout"
    elif command -v gtimeout >/dev/null 2>&1; then
        timeout_cmd="gtimeout"  # macOS with coreutils
    fi
    
    if [[ -n "$timeout_cmd" ]]; then
        if $timeout_cmd 5s bash "$MONITOR_SCRIPT" > /dev/null 2>&1; then
            actual_result="pass"
        else
            actual_result="fail"
        fi
    else
        # Fallback without timeout
        if bash "$MONITOR_SCRIPT" > /dev/null 2>&1; then
            actual_result="pass"
        else
            actual_result="fail"
        fi
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
    unset WAIT_FOR_CHECKS MAX_WAIT_TIME REQUIRED_CHECKS PR_NUMBER GITHUB_TOKEN GITHUB_REPOSITORY || true
    echo
}

echo "Starting status check monitoring tests..."
echo

# Test with wait-for-checks disabled
run_test "Check monitoring disabled" "pass" \
    "false" \
    "30" \
    "" \
    ""

# Test all checks passed
all_passed_response=$(create_mock_response "SUCCESS" '[
  {"__typename": "CheckRun", "name": "CI Build", "status": "COMPLETED", "conclusion": "SUCCESS"},
  {"__typename": "CheckRun", "name": "Unit Tests", "status": "COMPLETED", "conclusion": "SUCCESS"},
  {"__typename": "StatusContext", "context": "Security Scan", "state": "SUCCESS"}
]')

run_test "All checks passed" "pass" \
    "true" \
    "1" \
    "" \
    "$all_passed_response"

# Test with required checks filter
run_test "Required checks passed" "pass" \
    "true" \
    "1" \
    "CI Build,Unit Tests" \
    "$all_passed_response"

# Test with failed check
failed_check_response=$(create_mock_response "FAILURE" '[
  {"__typename": "CheckRun", "name": "CI Build", "status": "COMPLETED", "conclusion": "FAILURE"},
  {"__typename": "CheckRun", "name": "Unit Tests", "status": "COMPLETED", "conclusion": "SUCCESS"}
]')

run_test "Check failed" "fail" \
    "true" \
    "1" \
    "" \
    "$failed_check_response"

# Test with pending checks (will timeout)
pending_response=$(create_mock_response "PENDING" '[
  {"__typename": "CheckRun", "name": "CI Build", "status": "IN_PROGRESS", "conclusion": null},
  {"__typename": "CheckRun", "name": "Unit Tests", "status": "QUEUED", "conclusion": null}
]')

run_test "Timeout waiting for checks" "fail" \
    "true" \
    "0.05" \
    "" \
    "$pending_response"

# Test with no checks
no_checks_response=$(create_mock_response "SUCCESS" '[]')

run_test "No checks found" "pass" \
    "true" \
    "1" \
    "" \
    "$no_checks_response"

# Test with no checks but required checks specified
run_test "No checks but required specified" "fail" \
    "true" \
    "1" \
    "CI Build" \
    "$no_checks_response"

# Test with mixed check types
mixed_response=$(create_mock_response "SUCCESS" '[
  {"__typename": "CheckRun", "name": "Build", "status": "COMPLETED", "conclusion": "SUCCESS"},
  {"__typename": "StatusContext", "context": "coverage/coveralls", "state": "SUCCESS"},
  {"__typename": "CheckRun", "name": "Lint", "status": "COMPLETED", "conclusion": "SUCCESS"}
]')

run_test "Mixed check types" "pass" \
    "true" \
    "1" \
    "" \
    "$mixed_response"

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