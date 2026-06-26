#!/bin/bash

# Multi-runner startup script
# This script starts all GitHub runners in the actions-runners folder
# Each runner runs in the background with separate logging

# Configuration
RUNNERS_BASE_DIR="${1:-$(eval echo ~ubuntu)/actions-runners}"
LOGS_DIR="${RUNNERS_BASE_DIR}/logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Validate runners base directory exists
if [ ! -d "$RUNNERS_BASE_DIR" ]; then
    print_error "Runners directory not found: $RUNNERS_BASE_DIR"
    exit 1
fi

# Create logs directory if it doesn't exist
mkdir -p "$LOGS_DIR"

print_status "Starting GitHub runners from: $RUNNERS_BASE_DIR"
print_status "Logs will be stored in: $LOGS_DIR"

# Counter for started runners
RUNNERS_STARTED=0
RUNNERS_FAILED=0

# Find all runner directories (those containing run.sh)
find "$RUNNERS_BASE_DIR" -maxdepth 1 -type d ! -name 'logs' ! -name "$(basename "$RUNNERS_BASE_DIR")" | while read -r runner_dir; do
    runner_name=$(basename "$runner_dir")
    log_file="${LOGS_DIR}/${runner_name}_${TIMESTAMP}.log"
    
    # Check if run.sh exists
    if [ ! -f "${runner_dir}/run.sh" ]; then
        print_warning "Skipping $runner_name: run.sh not found"
        continue
    fi
    
    # Check if runner is already running
    if pgrep -f "${runner_dir}/run.sh" > /dev/null 2>&1; then
        print_warning "Runner $runner_name is already running"
        continue
    fi
    
    # Start the runner in background
    print_status "Starting runner: $runner_name"
    
    # Create log file first
    touch "$log_file"
    
    # Start runner using full path to run.sh
    nohup "${runner_dir}/run.sh" >> "$log_file" 2>&1 &
    PID=$!
    
    print_status "Runner $runner_name started successfully (PID: $PID)"
    echo "$PID" > "${LOGS_DIR}/${runner_name}.pid"
    ((RUNNERS_STARTED++))
    
done

echo ""
print_status "========== Summary =========="
print_status "Runners started: $RUNNERS_STARTED"
print_status "Log directory: $LOGS_DIR"
print_status "=============================="

exit 0
