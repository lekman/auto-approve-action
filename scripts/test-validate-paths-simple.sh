#!/usr/bin/env bash

# test-validate-paths-simple.sh - Simple unit tests for validate-paths.sh pattern matching

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

# Source the validate-paths script to test the functions directly
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SOURCE_DIR/lib/logging.sh"

# Copy the matches_pattern function from validate-paths.sh for testing
matches_pattern() {
    local file="$1"
    local pattern="$2"
    
    # Handle simple patterns without wildcards
    if [[ "$pattern" == "$file" ]]; then
        return 0
    fi
    
    # Convert glob pattern to regex
    local regex_pattern="$pattern"
    
    # Escape regex special chars (except * which we'll handle)
    regex_pattern="${regex_pattern//./\\.}"
    regex_pattern="${regex_pattern//+/\\+}"
    regex_pattern="${regex_pattern//\?/\\?}"
    
    # Handle ** patterns
    # Special case: **/* should match everything
    if [[ "$pattern" == "**/*" ]]; then
        regex_pattern=".*"
    else
        # First, handle /**/ in the middle (matches zero or more path segments)
        # This needs to match both "dir/**/*.ext" -> "dir/*.ext" and "dir/sub/*.ext"
        regex_pattern="${regex_pattern//\/\*\*\//\/(STARSTAR\/)?}"
        
        # Handle /** at the end
        regex_pattern="${regex_pattern//\/\*\*/\/STARSTAR}"
        
        # Handle **/ at the beginning (matches any number of directories)
        regex_pattern="${regex_pattern//\*\*\//STARSTAR/}"
        
        # Handle standalone **
        regex_pattern="${regex_pattern//\*\*/STARSTAR}"
        
        # Replace single * with [^/]* (matches any character except /)
        regex_pattern="${regex_pattern//\*/[^/]*}"
        
        # Now replace STARSTAR with .* (matches anything including /)
        regex_pattern="${regex_pattern//STARSTAR/.*}"
    fi
    
    # Anchor the pattern
    regex_pattern="^${regex_pattern}$"
    
    # Test the match
    if [[ "$file" =~ $regex_pattern ]]; then
        return 0
    fi
    
    return 1
}

# Test helper functions
test_start() {
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -e "${YELLOW}Test $TESTS_RUN: $1${NC}"
}

test_pattern() {
    local file="$1"
    local pattern="$2"
    local expected="$3"
    local description="$4"
    
    if matches_pattern "$file" "$pattern"; then
        local result="match"
    else
        local result="no-match"
    fi
    
    if [[ "$result" == "$expected" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓ $description${NC}"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗ $description${NC}"
        echo "  File: $file"
        echo "  Pattern: $pattern"
        echo "  Expected: $expected, Got: $result"
        return 1
    fi
}

echo "Running pattern matching tests..."
echo ""

# Test 1: Basic ** pattern matching
test_start "Basic ** patterns"
test_pattern "docs/README.md" "docs/**/*.md" "match" "docs/**/*.md matches docs/README.md"
test_pattern "docs/api/guide.md" "docs/**/*.md" "match" "docs/**/*.md matches docs/api/guide.md"
test_pattern "docs/api/v2/spec.md" "docs/**/*.md" "match" "docs/**/*.md matches docs/api/v2/spec.md"
test_pattern "README.md" "docs/**/*.md" "no-match" "docs/**/*.md doesn't match README.md"

# Test 2: Single * patterns
test_start "Single * patterns"
test_pattern "src/main.js" "src/*.js" "match" "src/*.js matches src/main.js"
test_pattern "src/lib/utils.js" "src/*.js" "no-match" "src/*.js doesn't match src/lib/utils.js"
test_pattern "test.js" "*.js" "match" "*.js matches test.js"

# Test 3: Exact matches
test_start "Exact matches"
test_pattern "package.json" "package.json" "match" "Exact match for package.json"
test_pattern "package.json" "package.yaml" "no-match" "No match for different file"

# Test 4: Complex patterns
test_start "Complex patterns"
test_pattern ".github/workflows/ci.yml" "**/*.yml" "match" "**/*.yml matches .github/workflows/ci.yml"
test_pattern "config/settings.json" "**/*.json" "match" "**/*.json matches config/settings.json"
test_pattern "src/components/Button.tsx" "src/**/*.tsx" "match" "src/**/*.tsx matches src/components/Button.tsx"

# Test 5: Edge cases
test_start "Edge cases"
test_pattern "file.txt" "**/*" "match" "**/* matches any file"
test_pattern "deep/nested/path/file.txt" "**/*" "match" "**/* matches deeply nested file"
test_pattern ".gitignore" ".*" "match" ".* matches dotfiles"

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