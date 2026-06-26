#!/bin/bash

# Master Setup Script
# This script orchestrates the complete server setup including:
# 1. Application installation (Docker, Nginx, Certbot)
# 2. GitHub Actions runner configuration
# 3. Starting all runners

set -e

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

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
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

# Function to run a subscript
run_subscript() {
    local script="$1"
    local description="$2"
    
    print_header "$description"
    
    if ! check_script_exists "$script"; then
        print_error "Cannot run $description"
        return 1
    fi
    
    if bash "$script"; then
        print_status "$description completed successfully"
        return 0
    else
        print_error "$description failed"
        return 1
    fi
}

# Main setup
main() {
    print_header "Complete Server Setup"
    print_info "This script will set up your server with:"
    echo "  1. Docker, Nginx, and Certbot"
    echo "  2. GitHub Actions runners"
    echo "  3. Start all runners"
    echo ""
    
    check_root
    
    # Get the directory where this script is located
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    print_info "Script directory: $SCRIPT_DIR"
    echo ""
    
    # Step 1: Install applications
    if ! run_subscript "${SCRIPT_DIR}/setup_applications.sh" "Step 1: Installing Applications (Docker, Nginx, Certbot)"; then
        print_error "Application setup failed. Continuing anyway..."
    fi
    
    echo ""
    
    # Step 2: Setup GitHub Actions runners
    if ! run_subscript "${SCRIPT_DIR}/setup_actions.sh" "Step 2: Setting Up GitHub Actions Runners"; then
        print_error "Runner setup failed. Continuing anyway..."
    fi
    
    echo ""
    
    # Step 3: Start runners
    if ! run_subscript "${SCRIPT_DIR}/start_runners.sh" "Step 3: Starting GitHub Actions Runners"; then
        print_error "Starting runners failed"
    fi
    
    # Final summary
    print_header "Complete Setup Summary"
    
    print_status "All setup steps completed!"
    echo ""
    print_info "What was installed:"
    echo "  • Docker"
    echo "  • Nginx"
    echo "  • Certbot"
    echo "  • GitHub Actions Runners"
    echo ""
    
    print_info "Important next steps:"
    echo "  1. Log out and log back in for docker group changes to take effect"
    echo "  2. Verify runners are running: bash ${SCRIPT_DIR}/runner_status.sh"
    echo "  3. Check runner logs: tail -f ./actions-runners/logs/*.log"
    echo "  4. Configure Nginx: /etc/nginx/sites-available/"
    echo "  5. Setup SSL: sudo certbot --nginx -d yourdomain.com"
    echo ""
    
    print_info "Useful commands:"
    echo "  • Check runner status: bash ${SCRIPT_DIR}/runner_status.sh"
    echo "  • Start runners: bash ${SCRIPT_DIR}/start_runners.sh"
    echo "  • Stop runners: pkill -f 'run.sh'"
    echo ""
}

# Run main function
main "$@"
