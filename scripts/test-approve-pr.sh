#!/bin/bash

# test-approve-pr.sh - Local test script for PR approval execution

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPROVE_SCRIPT="$SCRIPT_DIR/approve-pr.sh"

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

# Function to mock GitHub CLI
setup_mock_gh() {
    local scenario="$1"
    
    # Create a temporary directory for our mock
    export MOCK_DIR=$(mktemp -d)
    
    # Create mock gh script
    cat > "$MOCK_DIR/gh" << 'EOF'
#!/bin/bash

# Parse command
cmd="$1"
subcmd="$2"

case "$cmd" in
    "pr")
        case "$subcmd" in
            "view")
                pr_num="$3"
                if [[ "$4" == "--json" ]] && [[ "$5" == "reviews" ]]; then
                    # Check if using --jq flag
                    if [[ "$6" == "--jq" ]]; then
                        # The jq filter is looking for approved reviews by current user
                        case "$MOCK_SCENARIO" in
                            "already_approved")
                                # Return an ID to indicate existing approval
                                echo "123"
                                ;;
                            *)
                                # Return nothing (empty result from jq filter)
                                echo ""
                                ;;
                        esac
                    else
                        # Return full JSON
                        case "$MOCK_SCENARIO" in
                            "already_approved")
                                echo '{"reviews": [{"author": {"login": "test-bot"}, "state": "APPROVED", "id": "123"}]}'
                                ;;
                            *)
                                echo '{"reviews": []}'
                                ;;
                        esac
                    fi
                elif [[ "$4" == "--json" ]] && [[ "$5" == "number" ]]; then
                    echo '{"number": 123}'
                else
                    echo "PR #$pr_num: Test PR"
                fi
                exit 0
                ;;
            "review")
                pr_num="$3"
                if [[ "$4" == "--approve" ]]; then
                    case "$MOCK_SCENARIO" in
                        "no_permissions")
                            echo "::error::Insufficient permissions" >&2
                            exit 1
                            ;;
                        "api_failure")
                            echo "ERROR: API request failed" >&2
                            exit 1
                            ;;
                        *)
                            echo "Approved PR #$pr_num"
                            exit 0
                            ;;
                    esac
                fi
                ;;
            "comment")
                pr_num="$3"
                if [[ "$4" == "--body" ]]; then
                    case "$MOCK_SCENARIO" in
                        "api_failure")
                            echo "ERROR: API request failed" >&2
                            exit 1
                            ;;
                        *)
                            echo "Comment added to PR #$pr_num"
                            exit 0
                            ;;
                    esac
                fi
                ;;
        esac
        ;;
    "api")
        resource="$2"
        # Handle both with and without --jq flag
        if [[ "$resource" == "/repos/"* ]]; then
            # Check if --jq flag is present
            if [[ "$3" == "--jq" ]] && [[ "$4" == ".permissions" ]]; then
                # Return just the permissions object when using jq
                case "$MOCK_SCENARIO" in
                    "no_permissions")
                        echo '{"push": false}'
                        ;;
                    "api_failure")
                        # API failure test should pass permissions check
                        echo '{"push": true}'
                        ;;
                    *)
                        echo '{"push": true}'
                        ;;
                esac
            else
                # Return full response
                case "$MOCK_SCENARIO" in
                    "no_permissions")
                        echo '{"permissions": {"push": false}}'
                        ;;
                    *)
                        echo '{"permissions": {"push": true}}'
                        ;;
                esac
            fi
            exit 0
        elif [[ "$resource" == "user" ]]; then
            # Check if --jq flag is present  
            if [[ "$3" == "--jq" ]] && [[ "$4" == ".login" ]]; then
                echo 'test-bot'  # No quotes when using jq
            else
                echo '{"login": "test-bot"}'
            fi
            exit 0
        fi
        ;;
esac

exit 1
EOF
    
    chmod +x "$MOCK_DIR/gh"
    
    # Set the scenario
    export MOCK_SCENARIO="$scenario"
    
    # Add mock to PATH
    export PATH="$MOCK_DIR:$PATH"
}

# Function to cleanup mock
cleanup_mock() {
    if [[ -n "${MOCK_DIR:-}" ]] && [[ -d "$MOCK_DIR" ]]; then
        rm -rf "$MOCK_DIR"
    fi
    unset MOCK_DIR MOCK_SCENARIO || true
}

# Function to run a test
run_test() {
    local test_name="$1"
    local scenario="$2"
    local expected_result="$3"  # "pass" or "fail"
    local setup_env="$4"
    
    if [[ -n "${CI:-}" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]]; then
        echo "Running test: $test_name"
    else
        echo -e "${YELLOW}Running test: $test_name${NC}"
    fi
    
    # Setup mock
    setup_mock_gh "$scenario"
    
    # Setup environment
    export GITHUB_TOKEN="mock-token"
    export GITHUB_REPOSITORY="test/repo"
    export PR_NUMBER="123"
    
    # Apply additional environment setup
    eval "$setup_env"
    
    # Run the approval script
    if bash "$APPROVE_SCRIPT" > /dev/null 2>&1; then
        actual_result="pass"
    else
        actual_result="fail"
    fi
    
    # Cleanup mock
    cleanup_mock
    
    # Clean up environment
    unset GITHUB_TOKEN GITHUB_REPOSITORY PR_NUMBER || true
    unset VALIDATED_PR_AUTHOR VALIDATED_LABELS LABEL_MATCH_MODE || true
    unset VALIDATED_CHECKS_TOTAL VALIDATED_CHECKS_PASSED || true
    
    # Check result
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
    echo
}

echo "Starting approval execution tests..."
echo

# Test successful approval
run_test "Successful approval" "success" "pass" '
    export VALIDATED_PR_AUTHOR="testuser"
    export VALIDATED_LABELS="ready-to-merge"
    export LABEL_MATCH_MODE="any"
    export VALIDATED_CHECKS_TOTAL="5"
    export VALIDATED_CHECKS_PASSED="5"
'

# Test with no permissions
run_test "No permissions" "no_permissions" "fail" '
    export VALIDATED_PR_AUTHOR="testuser"
'

# Test already approved
run_test "Already approved" "already_approved" "pass" '
    export VALIDATED_PR_AUTHOR="testuser"
'

# Test API failure
run_test "API failure" "api_failure" "fail" '
    export VALIDATED_PR_AUTHOR="testuser"
    export VALIDATED_LABELS=""
    export LABEL_MATCH_MODE="none"
    export VALIDATED_CHECKS_TOTAL="1"
    export VALIDATED_CHECKS_PASSED="1"
'

# Test with no labels
run_test "No labels mode" "success" "pass" '
    export VALIDATED_PR_AUTHOR="testuser"
    export VALIDATED_LABELS=""
    export LABEL_MATCH_MODE="none"
    export VALIDATED_CHECKS_TOTAL="3"
    export VALIDATED_CHECKS_PASSED="3"
'

# Test missing PR number
run_test "Missing PR number" "success" "fail" '
    unset PR_NUMBER
    export GITHUB_REF="refs/heads/main"
    export VALIDATED_PR_AUTHOR="testuser"
    # Also unset GITHUB_EVENT_PATH to ensure no PR number can be found
    unset GITHUB_EVENT_PATH
'

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

exit 0