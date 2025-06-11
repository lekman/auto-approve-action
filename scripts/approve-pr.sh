#!/bin/bash

# approve-pr.sh - Executes PR approval after all criteria are met

set -euo pipefail

# Function to log errors using GitHub Actions error format
log_error() {
    echo "::error::$1"
}

# Function to log info
log_info() {
    echo "ℹ️  $1"
}

# Function to log success
log_success() {
    echo "✅ $1"
}

# Function to verify GitHub token permissions
verify_token_permissions() {
    local pr_number="$1"
    
    # Check if we can access the PR with the token
    if ! gh pr view "$pr_number" --json number >/dev/null 2>&1; then
        log_error "Unable to access PR #$pr_number - check GITHUB_TOKEN permissions"
        return 1
    fi
    
    # Debug: Check what type of token we're using
    local token_type="unknown"
    if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
        # Check if it's a GitHub App token or regular token
        local rate_limit
        if rate_limit=$(gh api rate_limit --jq '.rate.limit' 2>/dev/null); then
            if [[ $rate_limit -gt 1000 ]]; then
                token_type="app-or-pat"
            else
                token_type="github-token"
            fi
        fi
    fi
    log_info "Token type detected: $token_type"
    
    # For GitHub Actions default token, we need to check permissions differently
    # The default GITHUB_TOKEN has limited scope even with pull-requests: write
    local can_approve=false
    
    # Try to get current user to verify token is valid
    local current_user
    if ! current_user=$(gh api user --jq '.login' 2>&1); then
        # For GITHUB_TOKEN, use the actor instead
        if [[ "$token_type" == "github-token" ]]; then
            current_user="${GITHUB_ACTOR:-github-actions[bot]}"
            log_info "Using GITHUB_ACTOR as current user: $current_user"
        else
            log_error "Unable to determine current user: $current_user"
            return 1
        fi
    else
        log_info "Current user: $current_user"
    fi
    
    # Skip permission check for GITHUB_TOKEN in Actions - it has implicit permissions
    if [[ -n "${GITHUB_ACTIONS:-}" ]] && [[ "$token_type" == "github-token" ]]; then
        log_info "Running in GitHub Actions with GITHUB_TOKEN - assuming PR write permissions are granted by workflow"
        can_approve=true
    else
        # For other tokens, check if we can access the reviews endpoint
        local reviews_check
        if reviews_check=$(gh api "/repos/${GITHUB_REPOSITORY}/pulls/${pr_number}/reviews" 2>&1); then
            can_approve=true
        else
            log_error "Token does not have write permissions required for PR approval: $reviews_check"
            return 1
        fi
    fi
    
    if [[ "$can_approve" != "true" ]]; then
        log_error "Token does not have write permissions required for PR approval"
        log_info "Make sure the workflow has 'pull-requests: write' permission"
        return 1
    fi
    
    return 0
}

# Function to check if PR is already approved by this token
check_existing_approval() {
    local pr_number="$1"
    
    # Get current user info
    local current_user
    if ! current_user=$(gh api user --jq '.login' 2>&1); then
        # For GITHUB_TOKEN, gh api user doesn't work, use the actor
        if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
            current_user="${GITHUB_ACTOR:-github-actions[bot]}"
            log_info "Using GITHUB_ACTOR for approval check: $current_user"
        else
            log_error "Unable to determine current user: $current_user"
            return 1
        fi
    fi
    
    # Check existing reviews
    local existing_approvals
    if ! existing_approvals=$(gh pr view "$pr_number" --json reviews --jq ".reviews[] | select(.author.login == \"$current_user\" and .state == \"APPROVED\") | .id" 2>&1); then
        log_error "Failed to check existing reviews: $existing_approvals"
        return 1
    fi
    
    if [[ -n "$existing_approvals" ]]; then
        log_info "PR already approved by $current_user"
        return 0
    fi
    
    return 1
}

# Function to build approval message
build_approval_message() {
    local pr_author="$1"
    local matched_labels="$2"
    local label_mode="$3"
    local checks_total="$4"
    local checks_passed="$5"
    
    local message="## 🤖 Auto-Approval Summary\n\n"
    message+="This pull request has been automatically approved based on the following criteria:\n\n"
    
    # Author verification
    message+="### ✅ Author Verification\n"
    message+="- **PR Author**: @$pr_author\n"
    message+="- **Status**: Authorized for auto-approval\n\n"
    
    # Label validation
    message+="### ✅ Label Validation\n"
    message+="- **Match Mode**: $label_mode\n"
    if [[ "$label_mode" == "none" ]]; then
        if [[ -n "$matched_labels" ]]; then
            message+="- **Status**: No excluded labels found\n"
        else
            message+="- **Status**: No labels on PR (allowed)\n"
        fi
    else
        message+="- **Matched Labels**: $matched_labels\n"
        message+="- **Status**: Label requirements satisfied\n"
    fi
    message+="\n"
    
    # Status checks
    message+="### ✅ Status Checks\n"
    message+="- **Total Checks**: $checks_total\n"
    message+="- **Passed Checks**: $checks_passed\n"
    message+="- **Status**: All required checks passed\n\n"
    
    # Footer
    message+="---\n"
    message+="*This approval was performed automatically by the Auto-Approve GitHub Action.*\n"
    message+="*Timestamp: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*"
    
    echo "$message"
}

# Function to approve the PR
approve_pr() {
    local pr_number="$1"
    local approval_message="$2"
    
    log_info "Submitting approval for PR #$pr_number..."
    
    # Submit approval review
    if ! result=$(gh pr review "$pr_number" --approve --body "$approval_message" 2>&1); then
        log_error "Failed to approve PR: $result"
        return 1
    fi
    
    log_success "Successfully approved PR #$pr_number"
    return 0
}

# Main execution
main() {
    # Check required environment variables
    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
        log_error "GITHUB_TOKEN environment variable is not set"
        exit 1
    fi
    
    if [[ -z "${GITHUB_REPOSITORY:-}" ]]; then
        log_error "GITHUB_REPOSITORY environment variable is not set"
        exit 1
    fi
    
    # Get PR number
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
    
    # Get validation results from previous steps
    local pr_author="${VALIDATED_PR_AUTHOR:-unknown}"
    local matched_labels="${VALIDATED_LABELS:-}"
    local label_mode="${LABEL_MATCH_MODE:-none}"
    local checks_total="${VALIDATED_CHECKS_TOTAL:-0}"
    local checks_passed="${VALIDATED_CHECKS_PASSED:-0}"
    
    log_info "Processing approval for PR #$pr_number by @$pr_author"
    
    # Verify token permissions
    if ! verify_token_permissions "$pr_number"; then
        exit 1
    fi
    
    # Check if already approved
    if check_existing_approval "$pr_number"; then
        log_info "Skipping duplicate approval"
        exit 0
    fi
    
    # Build approval message
    local approval_message
    approval_message=$(build_approval_message "$pr_author" "$matched_labels" "$label_mode" "$checks_total" "$checks_passed")
    
    # Approve the PR
    if ! approve_pr "$pr_number" "$approval_message"; then
        exit 1
    fi
    
    # Add action summary
    if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
        {
            echo "## Auto-Approval Completed"
            echo ""
            echo "- **PR**: #$pr_number"
            echo "- **Author**: @$pr_author"
            echo "- **Timestamp**: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
            echo ""
            echo "### Approval Criteria Met"
            echo "- ✅ Author is in allowed list"
            echo "- ✅ Label requirements satisfied"
            echo "- ✅ All status checks passed"
        } >> "$GITHUB_STEP_SUMMARY"
    fi
    
    exit 0
}

# Run main function
main "$@"