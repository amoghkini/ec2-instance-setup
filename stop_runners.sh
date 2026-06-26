#!/bin/bash

# Stop all GitHub runners
# This script stops all running GitHub runners gracefully

# Configuration
RUNNERS_BASE_DIR="${1:-.}/actions-runners"
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
    
    # Check if runner is running
    if pgrep -f "${runner_dir}/run.sh" > /dev/null 2>&1; then
        print_status "Stopping runner: $runner_name"
        
        # Get PID from pid file if available
        pid_file="${LOGS_DIR}/${runner_name}.pid"
        if [ -f "$pid_file" ]; then
            PID=$(cat "$pid_file")
            if kill -0 "$PID" 2>/dev/null; then
                kill "$PID" 2>/dev/null || true
                print_status "Runner $runner_name stopped (PID: $PID)"
                rm "$pid_file"
                ((RUNNERS_STOPPED++))
            else
                print_warning "PID file exists but process not found: $PID"
                rm "$pid_file"
            fi
        else
            # Kill by process name if pid file doesn't exist
            pkill -f "${runner_dir}/run.sh" || true
            print_status "Runner $runner_name stopped"
            ((RUNNERS_STOPPED++))
        fi
    else
        print_warning "Runner $runner_name is not running"
        ((RUNNERS_NOT_RUNNING++))
    fi
    
done

echo ""
print_status "========== Summary =========="
print_status "Runners stopped: $RUNNERS_STOPPED"
if [ $RUNNERS_NOT_RUNNING -gt 0 ]; then
    print_warning "Runners not running: $RUNNERS_NOT_RUNNING"
fi
print_status "=============================="

exit 0
