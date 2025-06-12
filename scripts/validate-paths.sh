#!/bin/bash

# validate-paths.sh - Validates file paths changed in PR against configured patterns

set -euo pipefail

# Source the common logging library
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SOURCE_DIR/lib/logging.sh"

# Function to get changed files in PR
get_changed_files() {
    local pr_number="$1"
    
    log_info "Fetching list of changed files for PR #$pr_number..."
    
    local files_json
    log_debug "Running: gh pr view $pr_number --json files --repo $GITHUB_REPOSITORY"
    if ! files_json=$(gh pr view "$pr_number" --json files --repo "$GITHUB_REPOSITORY"); then
        log_error "Failed to fetch PR file information"
        return 1
    fi
    log_debug "Got files JSON: $files_json"
    
    # Extract file paths from JSON
    local file_paths
    if ! file_paths=$(echo "$files_json" | jq -r '.files[].path' 2>&1); then
        log_error "Failed to parse PR files JSON: $file_paths"
        return 1
    fi
    
    echo "$file_paths"
}

# Function to check if a file matches a pattern
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

# Function to validate paths against filters
validate_paths() {
    local pr_number="$1"
    local filters="$2"
    
    # Get changed files
    local changed_files
    if ! changed_files=$(get_changed_files "$pr_number"); then
        log_error "Failed to get changed files"
        export VALIDATED_PATH_REASON="Failed to retrieve changed files from PR"
        return 1
    fi
    
    # Count changed files
    local file_count=0
    if [[ -n "$changed_files" ]]; then
        file_count=$(echo "$changed_files" | grep -c . || echo 0)
    fi
    log_info "Found $file_count changed file(s) in PR #$pr_number"
    
    if [[ $file_count -eq 0 ]]; then
        log_warning "No files changed in PR"
        export VALIDATED_PATH_STATUS="approved"
        export VALIDATED_PATH_REASON="No files changed - auto-approved"
        export VALIDATED_MATCHED_FILES="0"
        export VALIDATED_EXCLUDED_FILES="0"
        return 0
    fi
    
    # Parse filters into arrays
    local include_patterns=()
    local exclude_patterns=()
    
    IFS=',' read -ra filter_array <<< "$filters"
    for filter in "${filter_array[@]}"; do
        # Trim whitespace
        filter=$(echo "$filter" | xargs)
        
        if [[ -z "$filter" ]]; then
            continue
        fi
        
        if [[ "$filter" == "!"* ]]; then
            # Exclusion pattern
            exclude_patterns+=("${filter:1}")
        else
            # Inclusion pattern
            # Check for invalid pattern characters and warn
            if [[ "$filter" == *"["* ]] || [[ "$filter" == *"]"* ]] || \
               [[ "$filter" == *"("* ]] || [[ "$filter" == *")"* ]] || \
               [[ "$filter" == *"{"* ]] || [[ "$filter" == *"}"* ]]; then
                log_warning "Pattern contains special characters that may not work as expected: $filter"
            fi
            include_patterns+=("$filter")
        fi
    done
    
    log_info "Inclusion patterns: ${#include_patterns[@]} patterns"
    log_info "Exclusion patterns: ${#exclude_patterns[@]} patterns"
    
    # Check each file against patterns
    local matched_files=()
    local excluded_files=()
    local unmatched_files=()
    
    while IFS= read -r file; do
        if [[ -z "$file" ]]; then
            continue
        fi
        
        local matched=false
        local excluded=false
        
        # Check exclusion patterns first
        if [[ ${#exclude_patterns[@]} -gt 0 ]]; then
            for pattern in "${exclude_patterns[@]}"; do
                if matches_pattern "$file" "$pattern"; then
                    excluded=true
                    excluded_files+=("$file")
                    log_info "File '$file' matches exclusion pattern '$pattern'"
                    break
                fi
            done
        fi
        
        # If excluded, skip this file entirely (don't check inclusion)
        if [[ "$excluded" == "true" ]]; then
            continue
        fi
        
        # Check inclusion patterns
        if [[ ${#include_patterns[@]} -gt 0 ]]; then
            for pattern in "${include_patterns[@]}"; do
                if matches_pattern "$file" "$pattern"; then
                    matched=true
                    matched_files+=("$file")
                    log_info "File '$file' matches inclusion pattern '$pattern'"
                    break
                fi
            done
            
            if [[ "$matched" == "false" ]]; then
                unmatched_files+=("$file")
            fi
        else
            # If no inclusion patterns, all non-excluded files are matched
            matched_files+=("$file")
        fi
    done <<< "$changed_files"
    
    # Determine approval status
    local approval_status="approved"
    local status_reason=""
    
    # Calculate effective file count (total minus excluded)
    local effective_files=$((file_count - ${#excluded_files[@]}))
    
    # If we have only exclude patterns (no include patterns)
    if [[ ${#include_patterns[@]} -eq 0 && ${#exclude_patterns[@]} -gt 0 ]]; then
        # Check if all files were excluded
        if [[ $effective_files -eq 0 ]]; then
            approval_status="rejected"
            status_reason="All files in PR match exclusion patterns"
            log_error "All files in PR match exclusion patterns"
        else
            # Some files remain after exclusion
            status_reason="Files remain after applying exclusion patterns"
        fi
    # If we have include patterns
    elif [[ ${#include_patterns[@]} -gt 0 ]]; then
        # Check if any files matched the include patterns (after exclusions)
        if [[ ${#matched_files[@]} -eq 0 ]]; then
            approval_status="rejected"
            status_reason="No files match the required inclusion patterns"
            log_error "No files in PR match the required patterns"
        else
            status_reason="Files match required patterns"
        fi
    fi
    
    # Log excluded files if any (for information only)
    if [[ ${#excluded_files[@]} -gt 0 ]]; then
        log_info "Excluded ${#excluded_files[@]} file(s) based on exclusion patterns:"
        for file in "${excluded_files[@]}"; do
            log_info "  - $file"
        done
    fi
    
    # Log summary
    log_info "Path validation summary:"
    log_info "  - Total files: $file_count"
    log_info "  - Matched files: ${#matched_files[@]}"
    log_info "  - Excluded files: ${#excluded_files[@]}"
    log_info "  - Unmatched files: ${#unmatched_files[@]}"
    
    # Export results for use by other scripts
    export VALIDATED_PATH_STATUS="$approval_status"
    export VALIDATED_PATH_REASON="$status_reason"
    export VALIDATED_MATCHED_FILES="${#matched_files[@]}"
    export VALIDATED_EXCLUDED_FILES="${#excluded_files[@]}"
    
    # Return based on approval status
    if [[ "$approval_status" == "approved" ]]; then
        return 0
    else
        return 1
    fi
}

# Main execution
main() {
    log_step_start "File Path Validation"
    
    # Check required environment variables
    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
        log_error "GITHUB_TOKEN environment variable is not set"
        exit 1
    fi
    
    if [[ -z "${PR_NUMBER:-}" ]]; then
        log_error "PR_NUMBER environment variable is not set"
        exit 1
    fi
    
    if [[ -z "${PATH_FILTERS:-}" ]]; then
        log_error "PATH_FILTERS environment variable is not set"
        exit 1
    fi
    
    log_info "Validating file paths for PR #$PR_NUMBER"
    log_info "Path filters: $PATH_FILTERS"
    
    # Validate paths
    if validate_paths "$PR_NUMBER" "$PATH_FILTERS"; then
        log_success "File path validation passed! All file changes meet the configured criteria."
        
        # Add to GitHub Step Summary
        add_to_summary "### ✅ File Path Validation"
        add_to_summary ""
        add_to_summary "All file changes in PR #$PR_NUMBER meet the configured path filters."
        add_to_summary ""
        add_to_summary "| Metric | Count |"
        add_to_summary "|--------|-------|"
        add_to_summary "| Matched Files | ${VALIDATED_MATCHED_FILES:-0} |"
        add_to_summary "| Excluded Files | ${VALIDATED_EXCLUDED_FILES:-0} |"
        
        log_step_end "File Path Validation" "success"
        exit 0
    else
        log_error "File path validation failed: ${VALIDATED_PATH_REASON:-Unknown reason}"
        
        # Add failure to GitHub Step Summary
        add_to_summary "### ❌ File Path Validation Failed"
        add_to_summary ""
        add_to_summary "**Reason**: ${VALIDATED_PATH_REASON:-Unknown reason}"
        add_to_summary ""
        add_to_summary "| Metric | Count |"
        add_to_summary "|--------|-------|"
        add_to_summary "| Matched Files | ${VALIDATED_MATCHED_FILES:-0} |"
        add_to_summary "| Excluded Files | ${VALIDATED_EXCLUDED_FILES:-0} |"
        
        log_step_end "File Path Validation" "failure"
        exit 1
    fi
}

# Run main function
main "$@"