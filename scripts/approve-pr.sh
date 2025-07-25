#!/bin/bash

# approve-pr.sh - Executes PR approval after all criteria are met

set -euo pipefail

# Source the common logging library
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SOURCE_DIR/lib/logging.sh"

# Function to verify GitHub token permissions
verify_token_permissions() {
    local pr_number="$1"
    
    # Check if we can access the PR with the token
    if ! gh pr view "$pr_number" --json number --repo "$GITHUB_REPOSITORY" >/dev/null 2>&1; then
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
        # Check if it's a GitHub App by trying the app endpoint
        local app_slug
        if app_slug=$(gh api /app --jq '.slug' 2>&1) && [[ -n "$app_slug" ]]; then
            current_user="${app_slug}[bot]"
            log_info "Detected GitHub App: $current_user"
        elif [[ -n "${GITHUB_ACTIONS:-}" ]]; then
            # For GITHUB_TOKEN in Actions, use the actor
            current_user="${GITHUB_ACTOR:-github-actions[bot]}"
            log_info "Using GITHUB_ACTOR as current user: $current_user (token type: $token_type)"
        else
            log_error "Unable to determine current user: $current_user"
            return 1
        fi
    else
        log_info "Current user: $current_user"
    fi
    
    # Skip permission check for tokens in Actions - they have implicit permissions from workflow
    if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
        log_info "Running in GitHub Actions - assuming PR write permissions are granted by workflow"
        can_approve=true
    else
        # For tokens outside Actions, check if we can access the reviews endpoint
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
        # Check if it's a GitHub App by trying the app endpoint
        local app_slug
        if app_slug=$(gh api /app --jq '.slug' 2>&1) && [[ -n "$app_slug" ]]; then
            current_user="${app_slug}[bot]"
            log_info "Using GitHub App for approval check: $current_user"
        elif [[ -n "${GITHUB_ACTIONS:-}" ]]; then
            # For GITHUB_TOKEN in Actions, use the actor
            current_user="${GITHUB_ACTOR:-github-actions[bot]}"
            log_info "Using GITHUB_ACTOR for approval check: $current_user"
        else
            log_error "Unable to determine current user: $current_user"
            return 1
        fi
    fi
    
    # Check existing reviews
    local existing_approvals
    if ! existing_approvals=$(gh pr view "$pr_number" --json reviews --repo "$GITHUB_REPOSITORY" --jq ".reviews[] | select(.author.login == \"$current_user\" and .state == \"APPROVED\") | .id" 2>&1); then
        log_error "Failed to check existing reviews: $existing_approvals"
        return 1
    fi
    
    if [[ -n "$existing_approvals" ]]; then
        log_info "PR already approved by $current_user"
        return 0
    fi
    
    return 1
}

# Function to check if approval is stale or missing
check_approval_status() {
    local pr_number="$1"
    
    # Get current user info
    local current_user
    if ! current_user=$(gh api user --jq '.login' 2>&1); then
        # Check if it's a GitHub App by trying the app endpoint
        local app_slug
        if app_slug=$(gh api /app --jq '.slug' 2>&1) && [[ -n "$app_slug" ]]; then
            current_user="${app_slug}[bot]"
        elif [[ -n "${GITHUB_ACTIONS:-}" ]]; then
            # For GITHUB_TOKEN in Actions, use the actor
            current_user="${GITHUB_ACTOR:-github-actions[bot]}"
        else
            log_error "Unable to determine current user for approval check"
            return 2
        fi
    fi
    
    log_info "Checking approval status for $current_user..."
    
    # Get the latest commit SHA for the PR
    local latest_commit
    if ! latest_commit=$(gh pr view "$pr_number" --json headRefOid --repo "$GITHUB_REPOSITORY" --jq '.headRefOid' 2>&1); then
        log_error "Failed to get latest commit SHA: $latest_commit"
        return 2
    fi
    
    # Check if we have an approval at the latest commit
    local approval_at_head
    if ! approval_at_head=$(gh api "/repos/${GITHUB_REPOSITORY}/pulls/${pr_number}/reviews" --jq ".[] | select(.user.login == \"$current_user\" and .state == \"APPROVED\" and .commit_id == \"$latest_commit\") | .id" 2>&1); then
        log_error "Failed to check reviews: $approval_at_head"
        return 2
    fi
    
    if [[ -n "$approval_at_head" ]]; then
        log_info "Found valid approval at latest commit"
        return 0  # Approval exists and is current
    fi
    
    # Check if we have any approval (potentially stale)
    local any_approval
    if ! any_approval=$(gh api "/repos/${GITHUB_REPOSITORY}/pulls/${pr_number}/reviews" --jq ".[] | select(.user.login == \"$current_user\" and .state == \"APPROVED\") | .id" 2>&1); then
        log_error "Failed to check for any approvals: $any_approval"
        return 2
    fi
    
    if [[ -n "$any_approval" ]]; then
        log_info "Found stale approval (not at latest commit)"
        return 1  # Stale approval exists
    fi
    
    log_info "No existing approval found"
    return 2  # No approval exists
}

# Function to add PR comment explaining the approval
add_approval_comment() {
    local pr_number="$1"
    local pr_author="$2"
    local matched_labels="$3"
    local label_mode="$4"
    local checks_total="$5"
    local checks_passed="$6"
    local is_reapproval="${7:-false}"
    
    log_info "Adding approval explanation comment to PR #$pr_number..."
    
    # Build the comment message
    local comment="## 🤖 Auto-Approval"
    if [[ "$is_reapproval" == "true" ]]; then
        comment+=" (Re-approval after new commits)"
    fi
    comment+="\n\n"
    comment+="This pull request meets all criteria for automatic approval:\n\n"
    
    # Author verification
    comment+="### ✅ Author Verification\n"
    comment+="- **PR Author**: @$pr_author\n"
    comment+="- **Status**: Authorized for auto-approval\n\n"
    
    # Label validation
    comment+="### ✅ Label Requirements\n"
    comment+="- **Match Mode**: $label_mode\n"
    if [[ "$label_mode" == "none" ]]; then
        if [[ -n "$matched_labels" ]]; then
            comment+="- **Status**: No excluded labels found\n"
        else
            comment+="- **Status**: No labels on PR (meets requirements)\n"
        fi
    else
        if [[ -n "$matched_labels" ]]; then
            comment+="- **Matched Labels**: $matched_labels\n"
        fi
        comment+="- **Status**: Label requirements satisfied\n"
    fi
    comment+="\n"
    
    # Status checks
    comment+="### ✅ Status Checks\n"
    if [[ "$checks_total" -gt 0 ]]; then
        comment+="- **Total Checks**: $checks_total\n"
        comment+="- **Passed Checks**: $checks_passed\n"
        comment+="- **Status**: All required checks passed\n"
    else
        comment+="- **Status**: No checks required or all checks passed\n"
    fi
    comment+="\n"
    
    # Footer
    comment+="---\n"
    comment+="*Automatically approved by the Auto-Approve GitHub Action at $(date -u +"%Y-%m-%d %H:%M:%S UTC")*"
    
    # Submit the comment
    if ! result=$(gh pr comment "$pr_number" --body "$comment" --repo "$GITHUB_REPOSITORY" 2>&1); then
        log_error "Failed to add approval comment: $result"
        return 1
    fi
    
    log_success "Successfully added approval comment to PR #$pr_number"
    return 0
}

# Function to approve the PR
approve_pr() {
    local pr_number="$1"
    
    log_info "Submitting approval for PR #$pr_number..."
    
    # Submit approval review without comment
    if ! result=$(gh pr review "$pr_number" --approve --repo "$GITHUB_REPOSITORY" 2>&1); then
        log_error "Failed to approve PR: $result"
        return 1
    fi
    
    log_success "Successfully approved PR #$pr_number"
    return 0
}

# Function to check if auto-merge is enabled
check_auto_merge_status() {
    local pr_number="$1"
    
    # Check if auto-merge is enabled
    local auto_merge_enabled
    if ! auto_merge_enabled=$(gh pr view "$pr_number" --json autoMergeRequest --repo "$GITHUB_REPOSITORY" --jq '.autoMergeRequest != null' 2>&1); then
        log_error "Failed to check auto-merge status: $auto_merge_enabled"
        return 2
    fi
    
    if [[ "$auto_merge_enabled" == "true" ]]; then
        log_info "Auto-merge is already enabled for PR #$pr_number"
        return 0
    else
        log_info "Auto-merge is not enabled for PR #$pr_number"
        return 1
    fi
}

# Function to enable auto-merge for the PR
enable_auto_merge() {
    local pr_number="$1"
    local merge_method="${2:-merge}"
    local force="${3:-false}"
    
    # Check if auto-merge is already enabled (unless forcing)
    if [[ "$force" != "true" ]]; then
        if check_auto_merge_status "$pr_number"; then
            log_info "Auto-merge already enabled, skipping"
            return 0
        fi
    fi
    
    log_info "Enabling auto-merge for PR #$pr_number using $merge_method method..."
    
    # Validate merge method
    case "$merge_method" in
        merge|squash|rebase)
            ;;
        *)
            log_error "Invalid merge method: $merge_method. Must be 'merge', 'squash', or 'rebase'"
            return 1
            ;;
    esac
    
    # Enable auto-merge using the specified method
    if ! result=$(gh pr merge "$pr_number" --auto --$merge_method --repo "$GITHUB_REPOSITORY" 2>&1); then
        # Check if the error is because auto-merge is already enabled
        if [[ "$result" =~ "already enabled" ]] || [[ "$result" =~ "is already queued to merge" ]]; then
            log_info "Auto-merge was already enabled or queued"
            return 0
        fi
        log_error "Failed to enable auto-merge: $result"
        return 1
    fi
    
    log_success "Successfully enabled auto-merge for PR #$pr_number using $merge_method method"
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
    local path_status="${VALIDATED_PATH_STATUS:-}"
    local path_reason="${VALIDATED_PATH_REASON:-}"
    
    log_info "Processing approval for PR #$pr_number by @$pr_author"
    
    # Verify token permissions
    if ! verify_token_permissions "$pr_number"; then
        exit 1
    fi
    
    # Check approval status
    check_approval_status "$pr_number"
    local approval_status=$?
    local is_reapproval="false"
    
    case $approval_status in
        0)
            # Approval exists and is current
            log_info "Approval is already current at latest commit, skipping duplicate approval"
            exit 0
            ;;
        1)
            # Stale approval exists
            log_info "Stale approval detected, will re-approve at latest commit"
            is_reapproval="true"
            ;;
        2)
            # No approval exists
            log_info "No existing approval found, will approve"
            ;;
    esac
    
    # Check if running in dry-run mode
    local auto_merge_enabled="false"
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "DRY RUN MODE: Would enable auto-merge and approve PR #$pr_number but skipping actual actions"
    else
        # For re-approvals, we need to ensure auto-merge is re-enabled
        # because it gets disabled when new commits are pushed
        local merge_method="${MERGE_METHOD:-merge}"
        
        # Always try to enable auto-merge (it will check if already enabled)
        if enable_auto_merge "$pr_number" "$merge_method"; then
            auto_merge_enabled="true"
        else
            log_error "Failed to enable auto-merge, continuing with approval only"
            # Don't exit - we can still approve even if auto-merge fails
        fi
        
        # Approve the PR
        if ! approve_pr "$pr_number"; then
            exit 1
        fi
        
        # If this was a re-approval and auto-merge failed earlier, try once more
        # This handles the case where auto-merge needs the approval to exist first
        if [[ "$is_reapproval" == "true" ]] && [[ "$auto_merge_enabled" != "true" ]]; then
            log_info "Retrying auto-merge after re-approval..."
            if enable_auto_merge "$pr_number" "$merge_method" "true"; then
                auto_merge_enabled="true"
                log_success "Successfully re-enabled auto-merge after re-approval"
            else
                log_warning "Auto-merge could not be re-enabled after re-approval"
            fi
        fi
    fi
    
    # Add action summary (unless silent mode is enabled)
    if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]] && [[ "${SILENT:-false}" != "true" ]]; then
        {
            if [[ "${DRY_RUN:-false}" == "true" ]]; then
                echo "## 🤖 Auto-Approval Dry Run Completed"
            else
                if [[ "$is_reapproval" == "true" ]]; then
                    echo "## 🤖 Auto-Approval Completed (Re-approval after new commits)"
                else
                    echo "## 🤖 Auto-Approval Completed"
                fi
            fi
            echo ""
            echo "### Pull Request Details"
            echo "- **PR**: #$pr_number"
            echo "- **Author**: @$pr_author"
            echo "- **Timestamp**: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
            if [[ "$is_reapproval" == "true" ]]; then
                echo "- **Type**: Re-approval (previous approval was stale due to new commits)"
            fi
            echo ""
            echo "### ✅ Author Verification"
            echo "- **PR Author**: @$pr_author"
            echo "- **Status**: Authorized for auto-approval"
            echo ""
            echo "### ✅ Label Validation"
            echo "- **Match Mode**: $label_mode"
            if [[ "$label_mode" == "none" ]]; then
                if [[ -n "$matched_labels" ]]; then
                    echo "- **Status**: No excluded labels found"
                else
                    echo "- **Status**: No labels on PR (allowed)"
                fi
            else
                echo "- **Matched Labels**: $matched_labels"
                echo "- **Status**: Label requirements satisfied"
            fi
            echo ""
            echo "### ✅ Status Checks"
            echo "- **Total Checks**: $checks_total"
            echo "- **Passed Checks**: $checks_passed"
            echo "- **Status**: All required checks passed"
            echo ""
            if [[ -n "$path_status" ]]; then
                echo "### ✅ File Path Validation"
                if [[ "$path_status" == "approved" ]]; then
                    echo "- **Status**: All file changes meet path filter requirements"
                else
                    echo "- **Status**: Path validation was not performed or failed"
                    if [[ -n "$path_reason" ]]; then
                        echo "- **Reason**: $path_reason"
                    fi
                fi
                echo ""
            fi
            if [[ "${DRY_RUN:-false}" != "true" ]]; then
                echo "### 🔀 Auto-Merge Status"
                if [[ "$auto_merge_enabled" == "true" ]]; then
                    echo "- **Status**: ✅ Auto-merge enabled (PR will merge when all checks pass)"
                    echo "- **Method**: ${merge_method:-merge}"
                else
                    echo "- **Status**: ⚠️ Auto-merge not enabled (manual merge required)"
                fi
                echo ""
            fi
            echo "---"
            if [[ "${DRY_RUN:-false}" == "true" ]]; then
                echo "*This was a dry run. No actual approval or merge was performed.*"
            fi
        } >> "$GITHUB_STEP_SUMMARY"
    fi
    
    exit 0
}

# Run main function
main "$@"