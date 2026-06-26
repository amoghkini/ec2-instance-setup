#!/bin/bash

# GitHub Actions Runner Status Script
# Run as: bash runner_status.sh

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration - use current directory as base
RUNNERS_BASE_DIR="$(pwd)/actions-runners"
LOGS_DIR="${RUNNERS_BASE_DIR}/logs"

# Functions for colored output
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

# Function to check if a runner is currently running
check_runner_running() {
    local runner_dir="$1"
    
    if pgrep -f "${runner_dir}/run.sh" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to check if runner is configured
check_runner_configured() {
    local runner_dir="$1"
    
    if [ -f "${runner_dir}/.runner" ] && [ -f "${runner_dir}/run.sh" ]; then
        return 0
    else
        return 1
    fi
}

# Function to get runner PID
get_runner_pid() {
    local runner_dir="$1"
    pgrep -f "${runner_dir}/run.sh" 2>/dev/null || echo "N/A"
}

# Function to get latest log file
get_latest_log() {
    local runner_name="$1"
    ls -t "${LOGS_DIR}/${runner_name}"_*.log 2>/dev/null | head -1
}

# Function to display detailed runner status
show_runner_details() {
    local runner_dir="$1"
    local runner_name=$(basename "$runner_dir")
    
    if [ ! -d "$runner_dir" ]; then
        print_warning "$runner_name: Not set up"
        return
    fi
    
    echo -e "${BLUE}Runner: $runner_name${NC}"
    echo "  Directory: $runner_dir"
    
    if check_runner_configured "$runner_dir"; then
        echo "  Configuration: $(print_status 'Configured')"
        
        if check_runner_running "$runner_dir"; then
            local pid=$(get_runner_pid "$runner_dir")
            echo "  Status: $(print_status 'RUNNING')"
            echo "  PID: $pid"
            
            if command -v ps &> /dev/null; then
                local ps_info=$(ps -p "$pid" -o %cpu=,%mem= 2>/dev/null)
                if [ -n "$ps_info" ]; then
                    echo "  CPU/Memory: $ps_info"
                fi
            fi
        else
            echo "  Status: $(print_warning 'STOPPED')"
        fi
        
        local latest_log=$(get_latest_log "$runner_name")
        if [ -n "$latest_log" ]; then
            echo "  Latest Log: $latest_log"
            echo "  Last 5 lines:"
            tail -5 "$latest_log" | sed 's/^/    /'
        fi
    else
        echo "  Configuration: $(print_error 'NOT CONFIGURED')"
    fi
    
    echo ""
}

# Main script
main() {
    print_header "GitHub Actions Runner Status"
    
    print_info "Runners directory: $RUNNERS_BASE_DIR"
    echo ""
    
    # Check if runners directory exists
    if [ ! -d "$RUNNERS_BASE_DIR" ]; then
        print_error "Runners directory not found: $RUNNERS_BASE_DIR"
        exit 1
    fi
    
    # Find all runner directories
    local runner_count=0
    local running_count=0
    local stopped_count=0
    local unconfigured_count=0
    
    while IFS= read -r runner_dir; do
        runner_name=$(basename "$runner_dir")
        
        if [ -d "$runner_dir" ]; then
            ((runner_count++))
            
            if check_runner_configured "$runner_dir"; then
                if check_runner_running "$runner_dir"; then
                    ((running_count++))
                else
                    ((stopped_count++))
                fi
            else
                ((unconfigured_count++))
            fi
            
            show_runner_details "$runner_dir"
        fi
    done < <(find "$RUNNERS_BASE_DIR" -maxdepth 1 -type d ! -name 'logs' ! -name "$(basename "$RUNNERS_BASE_DIR")")
    
    # Summary
    print_header "Summary"
    print_info "Total runners: $runner_count"
    
    if [ $running_count -gt 0 ]; then
        print_status "Running: $running_count"
    else
        print_warning "Running: $running_count"
    fi
    
    if [ $stopped_count -gt 0 ]; then
        print_warning "Stopped: $stopped_count"
    else
        print_status "Stopped: $stopped_count"
    fi
    
    if [ $unconfigured_count -gt 0 ]; then
        print_error "Not configured: $unconfigured_count"
    else
        print_status "Not configured: $unconfigured_count"
    fi
    
    print_info "Logs directory: $LOGS_DIR"
    
    if [ $running_count -eq 0 ] && [ $runner_count -gt 0 ]; then
        echo ""
        print_warning "No runners are currently running"
        print_info "To start all runners, run: bash start_runners.sh"
    fi
}

# Run main function
main "$@"
