#!/bin/bash

# logging.sh - Common logging functions for Auto-Approve Action

# Get current timestamp in UTC
get_timestamp() {
    date -u +"%Y-%m-%d %H:%M:%S UTC"
}

# Function to log errors using GitHub Actions error format with timestamp
log_error() {
    local timestamp=$(get_timestamp)
    echo "::error::[$timestamp] $1"
}

# Function to log warnings with timestamp
log_warning() {
    local timestamp=$(get_timestamp)
    echo "⚠️  [$timestamp] $1" >&2
}

# Function to log info with timestamp
log_info() {
    local timestamp=$(get_timestamp)
    echo "ℹ️  [$timestamp] $1" >&2
}

# Function to log success with timestamp
log_success() {
    local timestamp=$(get_timestamp)
    echo "✅ [$timestamp] $1" >&2
}

# Function to log debug messages (only if DEBUG is set)
log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        local timestamp=$(get_timestamp)
        echo "🔍 [$timestamp] [DEBUG] $1" >&2
    fi
}

# Function to start a step summary section
start_summary_section() {
    local title="$1"
    if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
        {
            echo "## $title"
            echo ""
            echo "**Started at**: $(get_timestamp)"
            echo ""
        } >> "$GITHUB_STEP_SUMMARY"
    fi
}

# Function to add to step summary
add_to_summary() {
    local content="$1"
    if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
        echo "$content" >> "$GITHUB_STEP_SUMMARY"
    fi
}

# Function to end a step summary section
end_summary_section() {
    if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
        {
            echo ""
            echo "**Completed at**: $(get_timestamp)"
            echo ""
            echo "---"
            echo ""
        } >> "$GITHUB_STEP_SUMMARY"
    fi
}

# Function to log step entry
log_step_start() {
    local step_name="$1"
    log_info "Starting: $step_name"
    start_summary_section "$step_name"
}

# Function to log step completion
log_step_end() {
    local step_name="$1"
    local status="${2:-success}"
    
    case "$status" in
        success)
            log_success "Completed: $step_name"
            add_to_summary "✅ **Status**: Success"
            ;;
        failure)
            log_error "Failed: $step_name"
            add_to_summary "❌ **Status**: Failed"
            ;;
        skipped)
            log_info "Skipped: $step_name"
            add_to_summary "⏭️ **Status**: Skipped"
            ;;
    esac
    
    end_summary_section
}

# Function to measure and log execution time
measure_time() {
    local start_time=$1
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [[ $duration -ge 60 ]]; then
        local minutes=$((duration / 60))
        local seconds=$((duration % 60))
        echo "${minutes}m ${seconds}s"
    else
        echo "${duration}s"
    fi
}

# Export all functions
export -f get_timestamp log_error log_warning log_info log_success log_debug
export -f start_summary_section add_to_summary end_summary_section
export -f log_step_start log_step_end measure_time