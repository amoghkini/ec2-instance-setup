#!/bin/bash

# Stop all GitHub runners
# Run as: bash stop_runners.sh

# Configuration - use current directory as base
RUNNERS_BASE_DIR="$(pwd)/actions-runners"
LOGS_DIR="${RUNNERS_BASE_DIR}/logs"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

print_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

print_info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
}

# Validate runners base directory exists
if [ ! -d "$RUNNERS_BASE_DIR" ]; then
    print_error "Runners directory not found: $RUNNERS_BASE_DIR"
    exit 1
fi

print_status "Stopping GitHub runners from: $RUNNERS_BASE_DIR"

# Counter for stopped runners
RUNNERS_STOPPED=0
RUNNERS_NOT_RUNNING=0

# Find all runner directories (those containing run.sh)
find "$RUNNERS_BASE_DIR" -maxdepth 1 -type d ! -name 'logs' ! -name "$(basename "$RUNNERS_BASE_DIR")" | while read -r runner_dir; do
    runner_name=$(basename "$runner_dir")
    
    # Check if run.sh exists
    if [ ! -f "${runner_dir}/run.sh" ]; then
        print_warning "Skipping $runner_name: run.sh not found"
        continue
    fi
    
    print_status "Stopping runner: $runner_name"
    
    # Kill all processes related to this runner
    pkill -f "${runner_dir}/run.sh" || true
    pkill -f "${runner_dir}/run-helper.sh" || true
    pkill -f "${runner_dir}/bin/Runner" || true
    
    # Also try by runner name
    pkill -f "actions-runners/${runner_name}" || true
    
    # Remove PID file if it exists
    pid_file="${LOGS_DIR}/${runner_name}.pid"
    if [ -f "$pid_file" ]; then
        rm "$pid_file"
    fi
    
    print_status "Runner $runner_name stopped"
    ((RUNNERS_STOPPED++))
    
done

echo ""
print_status "========== Summary =========="
print_status "Runners stopped: $RUNNERS_STOPPED"
print_status "=============================="

# Final check - kill any remaining runner processes
print_info "Checking for any remaining runner processes..."
if pgrep -f "Runner.Listener" > /dev/null; then
    print_warning "Found remaining Runner.Listener processes, killing them..."
    pkill -9 -f "Runner.Listener" || true
fi

if pgrep -f "run-helper.sh" > /dev/null; then
    print_warning "Found remaining run-helper.sh processes, killing them..."
    pkill -9 -f "run-helper.sh" > /dev/null || true
fi

print_status "All runner processes stopped"

exit 0
