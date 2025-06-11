#!/bin/bash

# validate-labels.sh - Validates PR labels according to configured requirements

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

# Function to retrieve PR labels
get_pr_labels() {
    local pr_number="$1"
    
    log_info "Retrieving PR labels..." >&2
    
    # Use GitHub CLI to get PR labels
    local pr_data
    if ! pr_data=$(gh pr view "$pr_number" --json labels 2>&1); then
        log_error "Failed to retrieve PR labels: $pr_data"
        return 1
    fi
    
    # Extract label names from JSON response
    local labels
    if ! labels=$(echo "$pr_data" | jq -r '.labels[].name' 2>&1); then
        log_error "Failed to parse PR labels from response: $labels"
        return 1
    fi
    
    echo "$labels"
}

# Function to check labels against requirements
check_labels() {
    local mode="$1"
    local required_labels="$2"
    local pr_labels="$3"
    
    # Convert required labels to array
    IFS=',' read -ra required_array <<< "$required_labels"
    
    # Trim whitespace from required labels
    local trimmed_required=()
    for label in "${required_array[@]}"; do
        trimmed_required+=("$(echo "$label" | xargs)")
    done
    
    # Convert PR labels to array (one per line)
    local pr_labels_array=()
    while IFS= read -r label; do
        [[ -n "$label" ]] && pr_labels_array+=("$label")
    done <<< "$pr_labels"
    
    case "$mode" in
        "all")
            # All required labels must be present
            for required in "${trimmed_required[@]}"; do
                local found=false
                for pr_label in "${pr_labels_array[@]}"; do
                    if [[ "$pr_label" == "$required" ]]; then
                        found=true
                        break
                    fi
                done
                if [[ "$found" == false ]]; then
                    log_error "Required label '$required' is not present on the PR"
                    return 1
                fi
            done
            log_success "All required labels are present: ${trimmed_required[*]}"
            return 0
            ;;
            
        "any")
            # At least one required label must be present
            for required in "${trimmed_required[@]}"; do
                for pr_label in "${pr_labels_array[@]}"; do
                    if [[ "$pr_label" == "$required" ]]; then
                        log_success "Found required label: '$required'"
                        return 0
                    fi
                done
            done
            log_error "None of the required labels are present: ${trimmed_required[*]}"
            return 1
            ;;
            
        "none")
            # None of the specified labels should be present
            if [[ ${#pr_labels_array[@]} -gt 0 ]]; then
                for required in "${trimmed_required[@]}"; do
                    for pr_label in "${pr_labels_array[@]}"; do
                        if [[ "$pr_label" == "$required" ]]; then
                            log_error "Label '$required' should not be present on the PR"
                            return 1
                        fi
                    done
                done
            fi
            log_success "None of the excluded labels are present"
            return 0
            ;;
            
        *)
            log_error "Invalid label match mode: $mode"
            return 1
            ;;
    esac
}

# Main execution
main() {
    # Check if required environment variables are set
    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
        log_error "GITHUB_TOKEN environment variable is not set"
        exit 1
    fi
    
    if [[ -z "${LABEL_MATCH_MODE:-}" ]]; then
        log_error "LABEL_MATCH_MODE environment variable is not set"
        exit 1
    fi
    
    # Get PR number from environment
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
    
    log_info "Validating labels for PR #$pr_number"
    log_info "Label match mode: $LABEL_MATCH_MODE"
    
    # Check if we need to validate labels
    if [[ "$LABEL_MATCH_MODE" == "none" ]] && [[ -z "${REQUIRED_LABELS:-}" ]]; then
        log_info "No label validation needed (mode=none, no labels specified)"
        exit 0
    fi
    
    if [[ "$LABEL_MATCH_MODE" != "none" ]] && [[ -z "${REQUIRED_LABELS:-}" ]]; then
        log_error "Required labels must be specified when label-match-mode is '$LABEL_MATCH_MODE'"
        exit 1
    fi
    
    # Get PR labels
    local pr_labels
    if ! pr_labels=$(get_pr_labels "$pr_number"); then
        exit 1
    fi
    
    # Log current labels
    if [[ -z "$pr_labels" ]]; then
        log_info "PR has no labels"
    else
        log_info "PR labels: $(echo "$pr_labels" | tr '\n' ', ' | sed 's/, $//')"
    fi
    
    # If required labels are specified, validate them
    if [[ -n "${REQUIRED_LABELS:-}" ]]; then
        log_info "Required labels: $REQUIRED_LABELS"
        
        if ! check_labels "$LABEL_MATCH_MODE" "$REQUIRED_LABELS" "$pr_labels"; then
            exit 1
        fi
    fi
    
    # Export validated label information for downstream scripts
    export VALIDATED_PR_LABELS="$pr_labels"
    export VALIDATED_LABEL_MATCH_MODE="$LABEL_MATCH_MODE"
    
    # Make available for subsequent steps via GITHUB_ENV
    if [[ -n "${GITHUB_ENV:-}" ]]; then
        echo "VALIDATED_LABELS=$matched_labels" >> "$GITHUB_ENV"
        echo "LABEL_MATCH_MODE=$LABEL_MATCH_MODE" >> "$GITHUB_ENV"
    fi
    
    exit 0
}

# Run main function
main "$@"