#!/bin/bash

# validate-inputs.sh - Validates all input parameters for the Auto Approve GitHub Action

set -euo pipefail

# Source the common logging library
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SOURCE_DIR/lib/logging.sh"

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
log_step_start "Input Validation"
add_to_summary "### Validation Results"
add_to_summary ""

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


# Additional validation: if label-match-mode is not 'none', required-labels should be provided
if [[ "$LABEL_MATCH_MODE" != "none" && -z "${REQUIRED_LABELS:-}" ]]; then
    log_error "When 'label-match-mode' is '$LABEL_MATCH_MODE', 'required-labels' must be provided"
    exit 1
fi

# Note: When label-match-mode is 'none', required-labels can be provided to specify
# which labels should NOT be present on the PR (excluded labels)

# Validate merge-method (optional)
MERGE_METHOD="${MERGE_METHOD:-merge}"
case "$MERGE_METHOD" in
    merge|squash|rebase)
        log_info "✓ merge-method: Valid ($MERGE_METHOD)"
        ;;
    *)
        log_error "Input 'merge-method' must be one of: merge, squash, rebase (got: $MERGE_METHOD)"
        exit 1
        ;;
esac

# Validate path-filters (optional)
if [[ -n "${PATH_FILTERS:-}" ]]; then
    if ! is_valid_csv_list "$PATH_FILTERS"; then
        log_error "Input 'path-filters' must be a valid comma-separated list when provided"
        exit 1
    fi
    # Validate pattern syntax
    IFS=',' read -ra patterns <<< "$PATH_FILTERS"
    for pattern in "${patterns[@]}"; do
        pattern=$(echo "$pattern" | xargs)
        # Check for invalid characters in patterns
        if [[ "$pattern" =~ [\[\]{}] ]]; then
            log_warning "Pattern '$pattern' contains characters that may not work as expected. Use * and ** for wildcards."
        fi
    done
    log_info "✓ path-filters: Valid ($PATH_FILTERS)"
else
    log_info "✓ path-filters: Not provided (optional)"
fi

# Validate size limits (optional)
# max-files-changed
if [[ -n "${MAX_FILES_CHANGED:-}" ]]; then
    if ! [[ "$MAX_FILES_CHANGED" =~ ^[0-9]+$ ]] || [[ "$MAX_FILES_CHANGED" -lt 0 ]]; then
        log_error "Input 'max-files-changed' must be a non-negative integer (got: $MAX_FILES_CHANGED)"
        exit 1
    fi
    log_info "✓ max-files-changed: Valid ($MAX_FILES_CHANGED)"
else
    log_info "✓ max-files-changed: Not provided (optional, default: 0)"
fi

# max-lines-added
if [[ -n "${MAX_LINES_ADDED:-}" ]]; then
    if ! [[ "$MAX_LINES_ADDED" =~ ^[0-9]+$ ]] || [[ "$MAX_LINES_ADDED" -lt 0 ]]; then
        log_error "Input 'max-lines-added' must be a non-negative integer (got: $MAX_LINES_ADDED)"
        exit 1
    fi
    log_info "✓ max-lines-added: Valid ($MAX_LINES_ADDED)"
else
    log_info "✓ max-lines-added: Not provided (optional, default: 0)"
fi

# max-lines-removed
if [[ -n "${MAX_LINES_REMOVED:-}" ]]; then
    if ! [[ "$MAX_LINES_REMOVED" =~ ^[0-9]+$ ]] || [[ "$MAX_LINES_REMOVED" -lt 0 ]]; then
        log_error "Input 'max-lines-removed' must be a non-negative integer (got: $MAX_LINES_REMOVED)"
        exit 1
    fi
    log_info "✓ max-lines-removed: Valid ($MAX_LINES_REMOVED)"
else
    log_info "✓ max-lines-removed: Not provided (optional, default: 0)"
fi

# max-total-lines
if [[ -n "${MAX_TOTAL_LINES:-}" ]]; then
    if ! [[ "$MAX_TOTAL_LINES" =~ ^[0-9]+$ ]] || [[ "$MAX_TOTAL_LINES" -lt 0 ]]; then
        log_error "Input 'max-total-lines' must be a non-negative integer (got: $MAX_TOTAL_LINES)"
        exit 1
    fi
    log_info "✓ max-total-lines: Valid ($MAX_TOTAL_LINES)"
else
    log_info "✓ max-total-lines: Not provided (optional, default: 0)"
fi

log_info "✅ All input validations passed successfully!"

# Add validation summary
add_to_summary "| Parameter | Value | Status |"
add_to_summary "|-----------|-------|--------|"
add_to_summary "| allowed-authors | $ALLOWED_AUTHORS | ✅ Valid |"
add_to_summary "| required-labels | ${REQUIRED_LABELS:-_(not provided)_} | ✅ Valid |"
add_to_summary "| label-match-mode | $LABEL_MATCH_MODE | ✅ Valid |"
add_to_summary "| merge-method | ${MERGE_METHOD:-merge} | ✅ Valid |"
add_to_summary "| path-filters | ${PATH_FILTERS:-_(not provided)_} | ✅ Valid |"
add_to_summary "| max-files-changed | ${MAX_FILES_CHANGED:-0} | ✅ Valid |"
add_to_summary "| max-lines-added | ${MAX_LINES_ADDED:-0} | ✅ Valid |"
add_to_summary "| max-lines-removed | ${MAX_LINES_REMOVED:-0} | ✅ Valid |"
add_to_summary "| max-total-lines | ${MAX_TOTAL_LINES:-0} | ✅ Valid |"

log_step_end "Input Validation" "success"

# Export validated inputs for use by other scripts
export VALIDATED_ALLOWED_AUTHORS="$ALLOWED_AUTHORS"
export VALIDATED_REQUIRED_LABELS="${REQUIRED_LABELS:-}"
export VALIDATED_LABEL_MATCH_MODE="$LABEL_MATCH_MODE"
export VALIDATED_PATH_FILTERS="${PATH_FILTERS:-}"