#!/bin/bash

# verify-author.sh - Validates PR authors against the configured allowlist

set -euo pipefail

# Source the common logging library
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SOURCE_DIR/lib/logging.sh"

# Function to retrieve PR author
get_pr_author() {
    local pr_number="$1"
    
    log_info "Retrieving PR author information..." >&2
    
    # Use GitHub CLI to get PR author
    # The --json flag returns structured data we can parse
    local pr_data
    if ! pr_data=$(gh pr view "$pr_number" --repo "$GITHUB_REPOSITORY" --json author 2>&1); then
        log_error "Failed to retrieve PR information: $pr_data"
        return 1
    fi
    
    # Extract author login from JSON response
    local author
    if ! author=$(echo "$pr_data" | jq -r '.author.login' 2>&1); then
        log_error "Failed to parse PR author from response: $author"
        return 1
    fi
    
    # Check if author is null or empty
    if [[ "$author" == "null" ]] || [[ -z "$author" ]]; then
        log_error "Unable to determine PR author"
        return 1
    fi
    
    echo "$author"
}

# Function to check if author is in allowlist
is_author_allowed() {
    local author="$1"
    local allowed_authors="$2"
    
    # Convert comma-separated list to array
    IFS=',' read -ra authors_array <<< "$allowed_authors"
    
    # Check each allowed author (with trimmed whitespace)
    for allowed in "${authors_array[@]}"; do
        # Trim whitespace
        allowed=$(echo "$allowed" | xargs)
        
        # Perform exact case-sensitive match
        if [[ "$author" == "$allowed" ]]; then
            return 0
        fi
    done
    
    return 1
}

# Main execution
main() {
    # Check if required environment variables are set
    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
        log_error "GITHUB_TOKEN environment variable is not set"
        exit 1
    fi
    
    if [[ -z "${GITHUB_REPOSITORY:-}" ]]; then
        log_error "GITHUB_REPOSITORY environment variable is not set"
        exit 1
    fi
    
    if [[ -z "${ALLOWED_AUTHORS:-}" ]]; then
        log_error "ALLOWED_AUTHORS environment variable is not set"
        exit 1
    fi
    
    # Get PR number from GitHub Actions context
    local pr_number="${PR_NUMBER:-}"
    
    # If PR_NUMBER not set, try to extract from GITHUB_REF
    if [[ -z "$pr_number" ]] && [[ "${GITHUB_REF:-}" =~ ^refs/pull/([0-9]+)/ ]]; then
        pr_number="${BASH_REMATCH[1]}"
    fi
    
    # If still no PR number, try GITHUB_EVENT_PATH
    if [[ -z "$pr_number" ]] && [[ -f "${GITHUB_EVENT_PATH:-}" ]]; then
        pr_number=$(jq -r '.pull_request.number // .number // empty' "$GITHUB_EVENT_PATH" 2>/dev/null || echo "")
    fi
    
    if [[ -z "$pr_number" ]]; then
        log_error "Unable to determine PR number from context"
        exit 1
    fi
    
    log_step_start "Author Verification"
    log_info "Verifying author for PR #$pr_number"
    log_info "Allowed authors: $ALLOWED_AUTHORS"
    
    add_to_summary "### Verification Details"
    add_to_summary ""
    add_to_summary "- **PR Number**: #$pr_number"
    add_to_summary "- **Allowed Authors**: $ALLOWED_AUTHORS"
    
    # Get PR author
    local pr_author
    if ! pr_author=$(get_pr_author "$pr_number"); then
        exit 1
    fi
    
    log_info "PR author: $pr_author"
    add_to_summary "- **PR Author**: @$pr_author"
    
    # Check if author is allowed
    if is_author_allowed "$pr_author" "$ALLOWED_AUTHORS"; then
        log_success "Author '$pr_author' is authorized to trigger auto-approval"
        add_to_summary "- **Verification Result**: ✅ Authorized"
        log_step_end "Author Verification" "success"
        
        # Export for use by other scripts
        export VALIDATED_PR_AUTHOR="$pr_author"
        export VALIDATED_PR_NUMBER="$pr_number"
        
        # Make available for subsequent steps via GITHUB_ENV
        if [[ -n "${GITHUB_ENV:-}" ]]; then
            echo "VALIDATED_PR_AUTHOR=$pr_author" >> "$GITHUB_ENV"
            echo "VALIDATED_PR_NUMBER=$pr_number" >> "$GITHUB_ENV"
        fi
        
        exit 0
    else
        log_error "Author '$pr_author' is not in the allowed authors list"
        log_info "Auto-approval is only available for: $ALLOWED_AUTHORS"
        add_to_summary "- **Verification Result**: ❌ Not Authorized"
        log_step_end "Author Verification" "failure"
        exit 1
    fi
}

# Run main function
main "$@"