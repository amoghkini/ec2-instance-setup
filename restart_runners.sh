#!/bin/bash

# Restart all GitHub runners
# This script stops all runners and then starts them again

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    echo -e "${RED}[✗]${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

# Function to check if script exists and is executable
check_script_exists() {
    local script="$1"
    if [ ! -f "$script" ]; then
        print_error "Script not found: $script"
        return 1
    fi
    if [ ! -x "$script" ]; then
        print_warning "Script is not executable: $script"
        print_info "Making it executable..."
        chmod +x "$script"
    fi
    return 0
}

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Use home directory for runners
RUNNERS_HOME="${1:-$(eval echo ~ubuntu)/actions-runners}"

print_header "Restarting GitHub Actions Runners"

# Stop runners
print_header "Step 1: Stopping Runners"

if check_script_exists "${SCRIPT_DIR}/stop_runners.sh"; then
    if bash "${SCRIPT_DIR}/stop_runners.sh" "$RUNNERS_HOME"; then
        print_status "Runners stopped successfully"
    else
        print_error "Failed to stop runners"
        exit 1
    fi
else
    print_error "Cannot find stop_runners.sh"
    exit 1
fi

# Wait a moment for processes to fully terminate
print_info "Waiting for processes to terminate..."
sleep 2

# Start runners
print_header "Step 2: Starting Runners"

if check_script_exists "${SCRIPT_DIR}/start_runners.sh"; then
    if bash "${SCRIPT_DIR}/start_runners.sh" "$RUNNERS_HOME"; then
        print_status "Runners started successfully"
    else
        print_error "Failed to start runners"
        exit 1
    fi
else
    print_error "Cannot find start_runners.sh"
    exit 1
fi

# Final summary
print_header "Restart Complete"
print_status "All runners have been restarted!"
print_info "Check runner status: bash ${SCRIPT_DIR}/runner_status.sh $RUNNERS_HOME"

exit 0
