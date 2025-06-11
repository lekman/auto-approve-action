#!/bin/bash

# monitor-checks.sh - Monitors and validates PR status checks

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

# Function to log warning
log_warning() {
    echo "⚠️  $1"
}

# Function to get current timestamp in seconds
get_timestamp() {
    date +%s
}

# Function to retrieve PR check runs
get_pr_checks() {
    local pr_number="$1"
    
    # Use GitHub CLI to get check runs
    # We use the GraphQL API for more detailed information
    local query='
    query($owner: String!, $repo: String!, $pr: Int!) {
      repository(owner: $owner, name: $repo) {
        pullRequest(number: $pr) {
          commits(last: 1) {
            nodes {
              commit {
                statusCheckRollup {
                  state
                  contexts(first: 100) {
                    nodes {
                      __typename
                      ... on CheckRun {
                        name
                        status
                        conclusion
                      }
                      ... on StatusContext {
                        context
                        state
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }'
    
    local owner_repo="${GITHUB_REPOSITORY:-}"
    local owner="${owner_repo%%/*}"
    local repo="${owner_repo##*/}"
    
    if ! result=$(gh api graphql -f query="$query" -f owner="$owner" -f repo="$repo" -F pr="$pr_number" 2>&1); then
        log_error "Failed to retrieve PR checks: $result"
        return 1
    fi
    
    echo "$result"
}

# Function to parse check status from GraphQL response
parse_check_status() {
    local response="$1"
    local required_checks="$2"
    
    # Extract overall state
    local overall_state
    overall_state=$(echo "$response" | jq -r '.data.repository.pullRequest.commits.nodes[0].commit.statusCheckRollup.state // "UNKNOWN"')
    
    # Parse individual checks
    local checks_json
    checks_json=$(echo "$response" | jq -r '.data.repository.pullRequest.commits.nodes[0].commit.statusCheckRollup.contexts.nodes // []')
    
    # Create arrays for tracking
    local all_checks=()
    local pending_checks=()
    local failed_checks=()
    local passed_checks=()
    
    # Process each check
    while IFS= read -r check; do
        local check_type
        check_type=$(echo "$check" | jq -r '.__typename')
        
        local name status
        if [[ "$check_type" == "CheckRun" ]]; then
            name=$(echo "$check" | jq -r '.name')
            status=$(echo "$check" | jq -r '.status')
            conclusion=$(echo "$check" | jq -r '.conclusion // "null"')
            
            # Determine effective status
            if [[ "$status" == "COMPLETED" ]]; then
                if [[ "$conclusion" == "SUCCESS" ]]; then
                    status="SUCCESS"
                elif [[ "$conclusion" == "null" ]]; then
                    status="PENDING"
                else
                    status="FAILURE"
                fi
            else
                status="PENDING"
            fi
        else
            # StatusContext
            name=$(echo "$check" | jq -r '.context')
            state=$(echo "$check" | jq -r '.state')
            
            # Map state to our status
            case "$state" in
                "SUCCESS") status="SUCCESS" ;;
                "PENDING") status="PENDING" ;;
                *) status="FAILURE" ;;
            esac
        fi
        
        # Skip if we have required checks and this isn't one of them
        if [[ -n "$required_checks" ]]; then
            local found=false
            IFS=',' read -ra required_array <<< "$required_checks"
            for required in "${required_array[@]}"; do
                required=$(echo "$required" | xargs)  # Trim whitespace
                if [[ "$name" == "$required" ]]; then
                    found=true
                    break
                fi
            done
            [[ "$found" == false ]] && continue
        fi
        
        # Categorize check
        all_checks+=("$name")
        case "$status" in
            "SUCCESS")
                passed_checks+=("$name")
                ;;
            "PENDING")
                pending_checks+=("$name")
                ;;
            *)
                failed_checks+=("$name")
                ;;
        esac
    done < <(echo "$checks_json" | jq -c '.[]')
    
    # Output results
    echo "OVERALL_STATE=$overall_state"
    echo "ALL_CHECKS=${#all_checks[@]}"
    echo "PASSED_CHECKS=${#passed_checks[@]}"
    echo "PENDING_CHECKS=${#pending_checks[@]}"
    echo "FAILED_CHECKS=${#failed_checks[@]}"
    
    # Output detailed lists
    if [[ ${#pending_checks[@]} -gt 0 ]]; then
        echo "PENDING_LIST=${pending_checks[*]}"
    fi
    if [[ ${#failed_checks[@]} -gt 0 ]]; then
        echo "FAILED_LIST=${failed_checks[*]}"
    fi
    if [[ ${#passed_checks[@]} -gt 0 ]]; then
        echo "PASSED_LIST=${passed_checks[*]}"
    fi
}

# Main execution
main() {
    # Check if required environment variables are set
    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
        log_error "GITHUB_TOKEN environment variable is not set"
        exit 1
    fi
    
    if [[ -z "${WAIT_FOR_CHECKS:-}" ]]; then
        log_error "WAIT_FOR_CHECKS environment variable is not set"
        exit 1
    fi
    
    # Skip if not waiting for checks
    if [[ "$WAIT_FOR_CHECKS" != "true" ]]; then
        log_info "Check monitoring is disabled (wait-for-checks=false)"
        exit 0
    fi
    
    # Get configuration
    local max_wait_minutes="${MAX_WAIT_TIME:-30}"
    local required_checks="${REQUIRED_CHECKS:-}"
    local poll_interval=30  # seconds
    
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
    
    log_info "Monitoring checks for PR #$pr_number"
    log_info "Maximum wait time: $max_wait_minutes minutes"
    log_info "Poll interval: $poll_interval seconds"
    
    if [[ -n "$required_checks" ]]; then
        log_info "Required checks: $required_checks"
    else
        log_info "Monitoring all checks"
    fi
    
    # Calculate timeout
    local start_time=$(get_timestamp)
    local max_wait_seconds=$((max_wait_minutes * 60))
    local timeout_time=$((start_time + max_wait_seconds))
    
    # Polling loop
    while true; do
        local current_time=$(get_timestamp)
        
        # Check timeout
        if [[ $current_time -ge $timeout_time ]]; then
            log_error "Timeout waiting for checks to complete (waited $max_wait_minutes minutes)"
            exit 1
        fi
        
        # Get check status
        log_info "Retrieving check status..." >&2
        local checks_response
        if ! checks_response=$(get_pr_checks "$pr_number"); then
            exit 1
        fi
        
        # Parse status
        local status_output
        status_output=$(parse_check_status "$checks_response" "$required_checks")
        
        # Extract values using a safer method
        local OVERALL_STATE ALL_CHECKS PASSED_CHECKS PENDING_CHECKS FAILED_CHECKS
        local PENDING_LIST FAILED_LIST PASSED_LIST
        
        while IFS='=' read -r key value; do
            case "$key" in
                "OVERALL_STATE") OVERALL_STATE="$value" ;;
                "ALL_CHECKS") ALL_CHECKS="$value" ;;
                "PASSED_CHECKS") PASSED_CHECKS="$value" ;;
                "PENDING_CHECKS") PENDING_CHECKS="$value" ;;
                "FAILED_CHECKS") FAILED_CHECKS="$value" ;;
                "PENDING_LIST") PENDING_LIST="$value" ;;
                "FAILED_LIST") FAILED_LIST="$value" ;;
                "PASSED_LIST") PASSED_LIST="$value" ;;
            esac
        done <<< "$status_output"
        
        # Log current status
        local elapsed=$(( (current_time - start_time) / 60 ))
        log_info "Status after ${elapsed}m: Total=$ALL_CHECKS, Passed=$PASSED_CHECKS, Pending=$PENDING_CHECKS, Failed=$FAILED_CHECKS"
        
        # Check for failures
        if [[ $FAILED_CHECKS -gt 0 ]]; then
            log_error "The following checks have failed: $FAILED_LIST"
            exit 1
        fi
        
        # Check if all complete
        if [[ $PENDING_CHECKS -eq 0 ]]; then
            if [[ $ALL_CHECKS -eq 0 ]]; then
                log_warning "No checks found on the PR"
                if [[ -n "$required_checks" ]]; then
                    log_error "Required checks were specified but no checks were found"
                    exit 1
                fi
            else
                log_success "All $ALL_CHECKS checks have passed!"
                if [[ -n "${PASSED_LIST:-}" ]]; then
                    log_info "Passed checks: $PASSED_LIST"
                fi
            fi
            break
        fi
        
        # Still waiting
        log_info "Waiting for $PENDING_CHECKS checks to complete: ${PENDING_LIST:-}"
        log_info "Next check in $poll_interval seconds..."
        sleep $poll_interval
    done
    
    # Export check information for downstream scripts
    export VALIDATED_CHECKS_TOTAL="$ALL_CHECKS"
    export VALIDATED_CHECKS_PASSED="$PASSED_CHECKS"
    
    exit 0
}

# Run main function
main "$@"