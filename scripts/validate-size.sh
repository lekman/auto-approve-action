#!/bin/bash

# validate-size.sh - Validates PR size against configured thresholds

set -euo pipefail

# Source the common logging library
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SOURCE_DIR/lib/logging.sh"

# Function to get PR statistics
get_pr_stats() {
    local pr_number="$1"
    
    log_info "Fetching PR statistics for PR #$pr_number..."
    
    local pr_stats
    log_debug "Running: gh pr view $pr_number --json additions,deletions,changedFiles --repo $GITHUB_REPOSITORY"
    if ! pr_stats=$(gh pr view "$pr_number" --json additions,deletions,changedFiles --repo "$GITHUB_REPOSITORY"); then
        log_error "Failed to fetch PR statistics"
        return 1
    fi
    log_debug "Got PR stats: $pr_stats"
    
    echo "$pr_stats"
}

# Function to validate PR size
validate_pr_size() {
    local pr_number="$1"
    local max_files="${2:-0}"
    local max_added="${3:-0}"
    local max_removed="${4:-0}"
    local max_total="${5:-0}"
    local size_message="${6:-PR exceeds configured size limits}"
    
    # Get PR statistics
    local pr_stats
    if ! pr_stats=$(get_pr_stats "$pr_number"); then
        log_error "Failed to get PR statistics"
        export VALIDATED_SIZE_REASON="Failed to retrieve PR statistics"
        return 1
    fi
    
    # Extract values from JSON
    local files_changed=$(echo "$pr_stats" | jq -r '.changedFiles // 0')
    local lines_added=$(echo "$pr_stats" | jq -r '.additions // 0')
    local lines_removed=$(echo "$pr_stats" | jq -r '.deletions // 0')
    local total_lines=$((lines_added + lines_removed))
    
    log_info "PR size metrics:"
    log_info "  - Files changed: $files_changed"
    log_info "  - Lines added: $lines_added"
    log_info "  - Lines removed: $lines_removed"
    log_info "  - Total lines changed: $total_lines"
    
    # Validate against thresholds
    local validation_failed=false
    local failure_reasons=()
    
    # Check files changed limit
    if [[ $max_files -gt 0 && $files_changed -gt $max_files ]]; then
        validation_failed=true
        failure_reasons+=("Files changed ($files_changed) exceeds limit ($max_files)")
        log_error "PR exceeds maximum files changed: $files_changed > $max_files"
    fi
    
    # Check lines added limit
    if [[ $max_added -gt 0 && $lines_added -gt $max_added ]]; then
        validation_failed=true
        failure_reasons+=("Lines added ($lines_added) exceeds limit ($max_added)")
        log_error "PR exceeds maximum lines added: $lines_added > $max_added"
    fi
    
    # Check lines removed limit
    if [[ $max_removed -gt 0 && $lines_removed -gt $max_removed ]]; then
        validation_failed=true
        failure_reasons+=("Lines removed ($lines_removed) exceeds limit ($max_removed)")
        log_error "PR exceeds maximum lines removed: $lines_removed > $max_removed"
    fi
    
    # Check total lines limit
    if [[ $max_total -gt 0 && $total_lines -gt $max_total ]]; then
        validation_failed=true
        failure_reasons+=("Total lines changed ($total_lines) exceeds limit ($max_total)")
        log_error "PR exceeds maximum total lines changed: $total_lines > $max_total"
    fi
    
    # Export results for use by other scripts
    export VALIDATED_SIZE_FILES="$files_changed"
    export VALIDATED_SIZE_ADDED="$lines_added"
    export VALIDATED_SIZE_REMOVED="$lines_removed"
    export VALIDATED_SIZE_TOTAL="$total_lines"
    
    if [[ "$validation_failed" == "true" ]]; then
        export VALIDATED_SIZE_STATUS="rejected"
        export VALIDATED_SIZE_REASON="${failure_reasons[*]}"
        return 1
    else
        export VALIDATED_SIZE_STATUS="approved"
        export VALIDATED_SIZE_REASON=""
        return 0
    fi
}

# Main execution
main() {
    log_step_start "PR Size Validation"
    
    # Check required environment variables
    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
        log_error "GITHUB_TOKEN environment variable is not set"
        exit 1
    fi
    
    if [[ -z "${GITHUB_REPOSITORY:-}" ]]; then
        log_error "GITHUB_REPOSITORY environment variable is not set"
        exit 1
    fi
    
    if [[ -z "${PR_NUMBER:-}" ]]; then
        log_error "PR_NUMBER environment variable is not set"
        exit 1
    fi
    
    # Get configuration
    local max_files="${MAX_FILES_CHANGED:-0}"
    local max_added="${MAX_LINES_ADDED:-0}"
    local max_removed="${MAX_LINES_REMOVED:-0}"
    local max_total="${MAX_TOTAL_LINES:-0}"
    local size_message="${SIZE_LIMIT_MESSAGE:-PR exceeds configured size limits}"
    
    # Check if any limits are configured
    if [[ $max_files -eq 0 && $max_added -eq 0 && $max_removed -eq 0 && $max_total -eq 0 ]]; then
        log_info "No size limits configured, skipping size validation"
        
        # Add to GitHub Step Summary
        add_to_summary "### ℹ️ PR Size Validation"
        add_to_summary ""
        add_to_summary "No size limits configured - size validation skipped."
        
        log_step_end "PR Size Validation" "skipped"
        exit 0
    fi
    
    log_info "Validating PR size for PR #$PR_NUMBER"
    log_info "Size limits:"
    [[ $max_files -gt 0 ]] && log_info "  - Max files changed: $max_files"
    [[ $max_added -gt 0 ]] && log_info "  - Max lines added: $max_added"
    [[ $max_removed -gt 0 ]] && log_info "  - Max lines removed: $max_removed"
    [[ $max_total -gt 0 ]] && log_info "  - Max total lines: $max_total"
    
    # Validate PR size
    if validate_pr_size "$PR_NUMBER" "$max_files" "$max_added" "$max_removed" "$max_total" "$size_message"; then
        log_success "PR size validation passed! PR size is within configured limits."
        
        # Add to GitHub Step Summary
        add_to_summary "### ✅ PR Size Validation"
        add_to_summary ""
        add_to_summary "PR size is within configured limits."
        add_to_summary ""
        add_to_summary "| Metric | Value | Limit |"
        add_to_summary "|--------|-------|-------|"
        [[ $max_files -gt 0 ]] && add_to_summary "| Files Changed | ${VALIDATED_SIZE_FILES} | ${max_files} |"
        [[ $max_added -gt 0 ]] && add_to_summary "| Lines Added | ${VALIDATED_SIZE_ADDED} | ${max_added} |"
        [[ $max_removed -gt 0 ]] && add_to_summary "| Lines Removed | ${VALIDATED_SIZE_REMOVED} | ${max_removed} |"
        [[ $max_total -gt 0 ]] && add_to_summary "| Total Lines | ${VALIDATED_SIZE_TOTAL} | ${max_total} |"
        
        log_step_end "PR Size Validation" "success"
        exit 0
    else
        log_error "PR size validation failed: $size_message"
        
        # Add failure to GitHub Step Summary
        add_to_summary "### ❌ PR Size Validation Failed"
        add_to_summary ""
        add_to_summary "**Reason**: $size_message"
        add_to_summary ""
        add_to_summary "**Details**:"
        for reason in "${VALIDATED_SIZE_REASON[@]}"; do
            add_to_summary "- $reason"
        done
        add_to_summary ""
        add_to_summary "| Metric | Value | Limit | Status |"
        add_to_summary "|--------|-------|-------|--------|"
        
        if [[ $max_files -gt 0 ]]; then
            local files_status="✅"
            [[ ${VALIDATED_SIZE_FILES} -gt $max_files ]] && files_status="❌"
            add_to_summary "| Files Changed | ${VALIDATED_SIZE_FILES} | ${max_files} | $files_status |"
        fi
        
        if [[ $max_added -gt 0 ]]; then
            local added_status="✅"
            [[ ${VALIDATED_SIZE_ADDED} -gt $max_added ]] && added_status="❌"
            add_to_summary "| Lines Added | ${VALIDATED_SIZE_ADDED} | ${max_added} | $added_status |"
        fi
        
        if [[ $max_removed -gt 0 ]]; then
            local removed_status="✅"
            [[ ${VALIDATED_SIZE_REMOVED} -gt $max_removed ]] && removed_status="❌"
            add_to_summary "| Lines Removed | ${VALIDATED_SIZE_REMOVED} | ${max_removed} | $removed_status |"
        fi
        
        if [[ $max_total -gt 0 ]]; then
            local total_status="✅"
            [[ ${VALIDATED_SIZE_TOTAL} -gt $max_total ]] && total_status="❌"
            add_to_summary "| Total Lines | ${VALIDATED_SIZE_TOTAL} | ${max_total} | $total_status |"
        fi
        
        log_step_end "PR Size Validation" "failure"
        exit 1
    fi
}

# Run main function
main "$@"