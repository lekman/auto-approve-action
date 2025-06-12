#!/usr/bin/env bash

# test-validate-paths.sh - Unit tests for validate-paths.sh

set -euo pipefail

# Unset any gh alias that might interfere with our tests
unalias gh 2>/dev/null || true

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE_PATHS_SCRIPT="$SCRIPT_DIR/validate-paths.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

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
    export PR_NUMBER="123"
    export PATH_FILTERS="$1"
    export GITHUB_STEP_SUMMARY="/tmp/test_summary_$$"
    > "$GITHUB_STEP_SUMMARY"
    
    # Create a temporary directory for mock commands
    export MOCK_BIN_DIR="/tmp/mock_bin_$$"
    mkdir -p "$MOCK_BIN_DIR"
    
    # Create mock gh command
    cat > "$MOCK_BIN_DIR/gh" << 'EOF'
#!/bin/bash
if [[ "$1" == "pr" && "$2" == "view" && "$4" == "--json" && "$5" == "files" ]]; then
    # Return mock file data based on PR number
    case "$3" in
        "123")
            # Test PR with docs and src files
            echo '{
                "files": [
                    {"path": "docs/README.md"},
                    {"path": "docs/api/guide.md"},
                    {"path": "src/main.js"},
                    {"path": "src/lib/utils.js"},
                    {"path": "tests/unit/test.js"}
                ]
            }'
            ;;
        "124")
            # Test PR with only docs files
            echo '{
                "files": [
                    {"path": "docs/README.md"},
                    {"path": "docs/contributing.md"}
                ]
            }'
            ;;
        "125")
            # Test PR with config files
            echo '{
                "files": [
                    {"path": ".github/workflows/ci.yml"},
                    {"path": "config/settings.json"},
                    {"path": "package.json"}
                ]
            }'
            ;;
        "126")
            # Empty PR
            echo '{"files": []}'
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
    unset GITHUB_TOKEN PR_NUMBER PATH_FILTERS
    rm -f "$GITHUB_STEP_SUMMARY"
    
    # Clean up mock directory
    if [[ -n "$MOCK_BIN_DIR" ]] && [[ -d "$MOCK_BIN_DIR" ]]; then
        rm -rf "$MOCK_BIN_DIR"
    fi
    unset MOCK_BIN_DIR
    
    # Restore PATH
    export PATH="${PATH#*:}"
}


# Test 1: Basic inclusion pattern matching
test_start "Basic inclusion pattern - docs files"
setup_test_env "docs/**/*.md"
export PR_NUMBER="123"
if "$VALIDATE_PATHS_SCRIPT" > /dev/null 2>&1; then
    test_pass "Correctly matched docs files"
else
    test_fail "Failed to match docs files" "exit 0" "exit 1"
fi
cleanup_test_env

# Test 2: Multiple inclusion patterns
test_start "Multiple inclusion patterns"
setup_test_env "docs/**/*.md,src/**/*.js"
export PR_NUMBER="123"
if "$VALIDATE_PATHS_SCRIPT" > /dev/null 2>&1; then
    test_pass "Correctly matched multiple patterns"
else
    test_fail "Failed to match multiple patterns" "exit 0" "exit 1"
fi
cleanup_test_env

# Test 3: Exclusion pattern
test_start "Exclusion pattern - reject test files"
setup_test_env "**/*.js,!tests/**/*.js"
export PR_NUMBER="123"
if "$VALIDATE_PATHS_SCRIPT" > /dev/null 2>&1; then
    test_pass "Correctly excluded test files"
else
    test_fail "Failed to exclude test files" "exit 0" "exit 1"
fi
cleanup_test_env

# Test 4: No matching files
test_start "No matching files"
setup_test_env "*.py"
export PR_NUMBER="123"
if "$VALIDATE_PATHS_SCRIPT" > /dev/null 2>&1; then
    test_fail "Should have failed with no matching files" "exit 1" "exit 0"
else
    test_pass "Correctly failed with no matching files"
fi
cleanup_test_env

# Test 5: All files excluded
test_start "All files excluded"
setup_test_env "!**/*"
export PR_NUMBER="123"
if "$VALIDATE_PATHS_SCRIPT" > /dev/null 2>&1; then
    test_fail "Should have failed with all files excluded" "exit 1" "exit 0"
else
    test_pass "Correctly failed with all files excluded"
fi
cleanup_test_env

# Test 6: Only docs files allowed
test_start "Only docs files allowed"
setup_test_env "docs/**/*"
export PR_NUMBER="124"
if "$VALIDATE_PATHS_SCRIPT" > /dev/null 2>&1; then
    test_pass "Correctly approved PR with only docs files"
else
    test_fail "Failed to approve PR with only docs files" "exit 0" "exit 1"
fi
cleanup_test_env

# Test 7: Complex pattern with specific extensions
test_start "Complex pattern with specific extensions"
setup_test_env "**/*.yml,**/*.json"
export PR_NUMBER="125"
if "$VALIDATE_PATHS_SCRIPT" > /dev/null 2>&1; then
    test_pass "Correctly matched config files"
else
    test_fail "Failed to match config files" "exit 0" "exit 1"
fi
cleanup_test_env

# Test 8: Empty PR (no files changed)
test_start "Empty PR with no files"
setup_test_env "**/*.md"
export PR_NUMBER="126"
if "$VALIDATE_PATHS_SCRIPT" > /dev/null 2>&1; then
    test_pass "Correctly handled empty PR"
else
    test_fail "Failed to handle empty PR" "exit 0" "exit 1"
fi
cleanup_test_env

# Test 9: Whitespace in patterns
test_start "Patterns with whitespace"
setup_test_env " docs/**/*.md , src/**/*.js "
export PR_NUMBER="123"
if "$VALIDATE_PATHS_SCRIPT" > /dev/null 2>&1; then
    test_pass "Correctly handled patterns with whitespace"
else
    test_fail "Failed to handle patterns with whitespace" "exit 0" "exit 1"
fi
cleanup_test_env

# Test 10: Mixed inclusion and exclusion
test_start "Mixed inclusion and exclusion patterns"
setup_test_env "**/*,!**/*.md"
export PR_NUMBER="123"
if "$VALIDATE_PATHS_SCRIPT" > /dev/null 2>&1; then
    test_pass "Correctly handled mixed patterns"
else
    test_fail "Failed to handle mixed patterns" "exit 0" "exit 1"
fi
cleanup_test_env

# Test 11: Single file pattern
test_start "Single file pattern"
setup_test_env "package.json"
export PR_NUMBER="125"
if "$VALIDATE_PATHS_SCRIPT" > /dev/null 2>&1; then
    test_pass "Correctly matched single file"
else
    test_fail "Failed to match single file" "exit 0" "exit 1"
fi
cleanup_test_env

# Test 12: Pattern with single asterisk
test_start "Pattern with single asterisk"
setup_test_env "src/*.js"
export PR_NUMBER="123"
if "$VALIDATE_PATHS_SCRIPT" > /dev/null 2>&1; then
    test_pass "Correctly matched src/*.js pattern"
else
    test_fail "Failed to match src/*.js pattern" "exit 0" "exit 1"
fi
cleanup_test_env

# Test 13: Invalid pattern characters warning
test_start "Invalid pattern characters warning"
setup_test_env "[docs]/**/*.md"
export PR_NUMBER="123"
OUTPUT=$("$VALIDATE_PATHS_SCRIPT" 2>&1 || true)
if echo "$OUTPUT" | grep -q "may not work as expected"; then
    test_pass "Correctly warned about invalid pattern characters"
else
    test_fail "Failed to warn about invalid pattern characters" "warning message" "no warning"
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