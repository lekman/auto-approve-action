#!/bin/bash

# validate-inputs.sh - Validates all input parameters for the Auto Approve GitHub Action

set -euo pipefail

# Function to log errors using GitHub Actions error format
log_error() {
    echo "::error::$1"
}

# Function to log info
log_info() {
    echo "ℹ️  $1"
}

# Function to validate boolean values
is_boolean() {
    local value="$1"
    [[ "$value" == "true" || "$value" == "false" ]]
}

# Function to validate positive integer
is_positive_integer() {
    local value="$1"
    [[ "$value" =~ ^[1-9][0-9]*$ ]]
}

# Function to validate comma-separated list (non-empty items)
is_valid_csv_list() {
    local value="$1"
    # Check if empty
    if [[ -z "$value" ]]; then
        return 0  # Empty is valid for optional fields
    fi
    
    # Check for empty items between commas
    if [[ "$value" =~ ,, ]] || [[ "$value" =~ ^, ]] || [[ "$value" =~ ,$ ]]; then
        return 1
    fi
    
    # Check if each item is non-empty after trimming spaces
    IFS=',' read -ra items <<< "$value"
    for item in "${items[@]}"; do
        # Trim whitespace
        item=$(echo "$item" | xargs)
        if [[ -z "$item" ]]; then
            return 1
        fi
    done
    
    return 0
}

# Start validation
log_info "Starting input validation..."

# Validate allowed-authors (required)
if [[ -z "${ALLOWED_AUTHORS:-}" ]]; then
    log_error "Input 'allowed-authors' is required but not provided"
    exit 1
fi

if ! is_valid_csv_list "$ALLOWED_AUTHORS"; then
    log_error "Input 'allowed-authors' must be a valid comma-separated list of GitHub usernames"
    exit 1
fi

log_info "✓ allowed-authors: Valid ($ALLOWED_AUTHORS)"

# Validate required-labels (optional)
if [[ -n "${REQUIRED_LABELS:-}" ]]; then
    if ! is_valid_csv_list "$REQUIRED_LABELS"; then
        log_error "Input 'required-labels' must be a valid comma-separated list when provided"
        exit 1
    fi
    log_info "✓ required-labels: Valid ($REQUIRED_LABELS)"
else
    log_info "✓ required-labels: Not provided (optional)"
fi

# Validate label-match-mode
VALID_LABEL_MODES=("all" "any" "none")
if [[ ! " ${VALID_LABEL_MODES[@]} " =~ " ${LABEL_MATCH_MODE} " ]]; then
    log_error "Input 'label-match-mode' must be one of: all, any, none (got: $LABEL_MATCH_MODE)"
    exit 1
fi

log_info "✓ label-match-mode: Valid ($LABEL_MATCH_MODE)"

# Validate wait-for-checks
if ! is_boolean "${WAIT_FOR_CHECKS}"; then
    log_error "Input 'wait-for-checks' must be either 'true' or 'false' (got: $WAIT_FOR_CHECKS)"
    exit 1
fi

log_info "✓ wait-for-checks: Valid ($WAIT_FOR_CHECKS)"

# Validate max-wait-time
if ! is_positive_integer "${MAX_WAIT_TIME}"; then
    log_error "Input 'max-wait-time' must be a positive integer representing minutes (got: $MAX_WAIT_TIME)"
    exit 1
fi

# Additional check for reasonable max-wait-time (e.g., not more than 360 minutes / 6 hours)
if [[ $MAX_WAIT_TIME -gt 360 ]]; then
    log_error "Input 'max-wait-time' cannot exceed 360 minutes (6 hours) (got: $MAX_WAIT_TIME)"
    exit 1
fi

log_info "✓ max-wait-time: Valid ($MAX_WAIT_TIME minutes)"

# Validate required-checks (optional)
if [[ -n "${REQUIRED_CHECKS:-}" ]]; then
    if ! is_valid_csv_list "$REQUIRED_CHECKS"; then
        log_error "Input 'required-checks' must be a valid comma-separated list when provided"
        exit 1
    fi
    log_info "✓ required-checks: Valid ($REQUIRED_CHECKS)"
else
    log_info "✓ required-checks: Not provided (optional)"
fi

# Additional validation: if label-match-mode is not 'none', required-labels should be provided
if [[ "$LABEL_MATCH_MODE" != "none" && -z "${REQUIRED_LABELS:-}" ]]; then
    log_error "When 'label-match-mode' is '$LABEL_MATCH_MODE', 'required-labels' must be provided"
    exit 1
fi

# Note: When label-match-mode is 'none', required-labels can be provided to specify
# which labels should NOT be present on the PR (excluded labels)

log_info "✅ All input validations passed successfully!"

# Export validated inputs for use by other scripts
export VALIDATED_ALLOWED_AUTHORS="$ALLOWED_AUTHORS"
export VALIDATED_REQUIRED_LABELS="${REQUIRED_LABELS:-}"
export VALIDATED_LABEL_MATCH_MODE="$LABEL_MATCH_MODE"
export VALIDATED_WAIT_FOR_CHECKS="$WAIT_FOR_CHECKS"
export VALIDATED_MAX_WAIT_TIME="$MAX_WAIT_TIME"
export VALIDATED_REQUIRED_CHECKS="${REQUIRED_CHECKS:-}"