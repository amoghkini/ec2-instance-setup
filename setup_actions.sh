#!/bin/bash

# GitHub Actions Runner Setup Script
# This script sets up multiple GitHub runners for different repositories
# It checks for existing runners, generates setup links, and guides configuration

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BASE_DIR="${1:-$(eval echo ~ubuntu)}"
RUNNERS_DIR="${BASE_DIR}/actions-runners"

# Default repositories (can be overridden)
declare -a REPOS=(
    "https://github.com/amoghkini/MotoGarage"
    "https://github.com/amoghkini/todoist"
)

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

# Function to extract owner/repo from GitHub URL
extract_repo_info() {
    local url="$1"
    # Remove .git suffix if present
    url="${url%.git}"
    # Extract owner/repo from URL
    echo "$url" | sed 's|https://github.com/||'
}

# Function to get runner folder name from repo
get_runner_name() {
    local repo="$1"
    # Extract repo name (last part after /)
    echo "$repo" | awk -F'/' '{print $NF}'
}

# Function to check if a runner is currently running
check_runner_running() {
    local runner_dir="$1"
    
    if pgrep -f "${runner_dir}/run.sh" > /dev/null 2>&1; then
        return 0  # Running
    else
        return 1  # Not running
    fi
}

# Function to check if runner is configured
check_runner_configured() {
    local runner_dir="$1"
    
    if [ -f "${runner_dir}/.runner" ] && [ -f "${runner_dir}/run.sh" ]; then
        return 0  # Configured
    else
        return 1  # Not configured
    fi
}

# Function to display runner status
show_runner_status() {
    local runner_dir="$1"
    local runner_name=$(basename "$runner_dir")
    
    if [ ! -d "$runner_dir" ]; then
        print_warning "$runner_name: Not set up"
        return
    fi
    
    if check_runner_configured "$runner_dir"; then
        if check_runner_running "$runner_dir"; then
            print_status "$runner_name: Configured and RUNNING"
        else
            print_warning "$runner_name: Configured but STOPPED"
        fi
    else
        print_warning "$runner_name: Directory exists but NOT configured"
    fi
}

# Function to prompt user for action
prompt_continue() {
    local prompt="$1"
    local response
    
    while true; do
        read -p "$(echo -e ${BLUE}$prompt${NC}) (yes/no/cancel): " response
        case "$response" in
            [Yy][Ee][Ss]|[Yy])
                return 0
                ;;
            [Nn][Oo]|[Nn])
                return 1
                ;;
            [Cc][Aa][Nn][Cc][Ee][Ll])
                print_warning "Setup cancelled by user"
                exit 0
                ;;
            *)
                print_error "Please answer 'yes', 'no', or 'cancel'"
                ;;
        esac
    done
}

# Function to setup a single runner
setup_runner() {
    local repo_url="$1"
    local runner_name=$(get_runner_name "$repo_url")
    local runner_dir="${RUNNERS_DIR}/${runner_name}"
    local repo_info=$(extract_repo_info "$repo_url")
    
    print_info "Setting up runner for: $repo_url"
    
    # Check if runner already exists
    if [ -d "$runner_dir" ]; then
        print_warning "Runner directory already exists: $runner_dir"
        show_runner_status "$runner_dir"
        
        if ! prompt_continue "Do you want to reconfigure this runner?"; then
            print_info "Skipping $runner_name"
            return
        fi
    fi
    
    # Create runner directory
    mkdir -p "$runner_dir"
    print_status "Created directory: $runner_dir"
    
    # Generate GitHub Actions runner setup link
    local setup_link="https://github.com/${repo_info}/settings/actions/runners/new"
    
    print_header "Configure Runner: $runner_name"
    print_info "Repository: $repo_url"
    print_info "Runner Directory: $runner_dir"
    print_info "\nPlease follow these steps:"
    echo -e "${YELLOW}1. Open this link in your browser:${NC}"
    echo -e "${BLUE}   $setup_link${NC}"
    echo -e "${YELLOW}2. Follow GitHub's instructions to create a new runner${NC}"
    echo -e "${YELLOW}3. Copy the configuration token${NC}"
    echo -e "${YELLOW}4. Return here and paste the token when prompted${NC}\n"
    
    # Prompt user to open link
    if prompt_continue "Have you opened the link and are ready to configure?"; then
        # Prompt for configuration token
        local config_token
        read -p "$(echo -e ${BLUE}Enter the configuration token:${NC}) " config_token
        
        if [ -z "$config_token" ]; then
            print_error "No token provided. Skipping $runner_name"
            return
        fi
        
        # Download runner package
        print_status "Downloading GitHub Actions runner..."
        
        # Detect OS and architecture
        local os_type=$(uname -s)
        local arch=$(uname -m)
        local runner_package
        
        case "$os_type" in
            Linux)
                case "$arch" in
                    x86_64)
                        runner_package="actions-runner-linux-x64"
                        ;;
                    aarch64)
                        runner_package="actions-runner-linux-arm64"
                        ;;
                    *)
                        print_error "Unsupported architecture: $arch"
                        return
                        ;;
                esac
                ;;
            Darwin)
                case "$arch" in
                    x86_64)
                        runner_package="actions-runner-osx-x64"
                        ;;
                    arm64)
                        runner_package="actions-runner-osx-arm64"
                        ;;
                    *)
                        print_error "Unsupported architecture: $arch"
                        return
                        ;;
                esac
                ;;
            *)
                print_error "Unsupported OS: $os_type"
                return
                ;;
        esac
        
        # Get latest runner version
        print_info "Fetching latest runner version..."
        local latest_version=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | grep -oP '"tag_name": "v\K[^"]*' || echo "2.335.1")
        local runner_url="https://github.com/actions/runner/releases/download/v${latest_version}/${runner_package}-${latest_version}.tar.gz"
        
        print_info "Downloading: ${runner_package}-${latest_version}.tar.gz"
        
        if cd "$runner_dir" && curl -L -o "${runner_package}-${latest_version}.tar.gz" "$runner_url"; then
            print_status "Downloaded successfully"
            
            # Extract the runner
            print_status "Extracting runner files..."
            if tar xzf "${runner_package}-${latest_version}.tar.gz"; then
                print_status "Extracted successfully"
                
                # Clean up tar file
                rm "${runner_package}-${latest_version}.tar.gz"
                
                # Run configuration
                print_status "Running configuration..."
                if ./config.sh --url "$repo_url" --token "$config_token" --unattended --replace; then
                    print_status "Runner $runner_name configured successfully!"
                    print_info "Runner is ready at: $runner_dir"
                    print_info "To start the runner, run: bash start_runners.sh $RUNNERS_DIR"
                else
                    print_error "Configuration failed for $runner_name"
                fi
            else
                print_error "Failed to extract runner files"
            fi
        else
            print_error "Failed to download runner package"
        fi
    else
        print_info "Skipping $runner_name"
    fi
}

# Main script
main() {
    print_header "GitHub Actions Runner Setup"
    
    print_info "Using runners directory: $RUNNERS_DIR"
    
    # Check if runners directory exists
    if [ ! -d "$RUNNERS_DIR" ]; then
        print_status "Creating runners directory: $RUNNERS_DIR"
        mkdir -p "$RUNNERS_DIR"
    fi
    
    # Check existing runners
    print_header "Checking Existing Runners"
    
    local has_runners=false
    for repo in "${REPOS[@]}"; do
        local runner_name=$(get_runner_name "$repo")
        local runner_dir="${RUNNERS_DIR}/${runner_name}"
        
        if [ -d "$runner_dir" ]; then
            has_runners=true
            show_runner_status "$runner_dir"
        fi
    done
    
    if [ "$has_runners" = false ]; then
        print_info "No existing runners found"
    fi
    
    # Setup new runners
    print_header "Setting Up New Runners"
    print_info "Found ${#REPOS[@]} repository(ies) to configure"
    
    for repo in "${REPOS[@]}"; do
        setup_runner "$repo"
        echo ""
    done
    
    print_header "Setup Complete"
    print_status "All runners have been configured!"
    print_info "Next steps:"
    echo -e "  1. Review runner status: $RUNNERS_DIR"
    echo -e "  2. Start runners using: bash start_runners.sh $RUNNERS_DIR"
    echo -e "  3. Check logs in: $RUNNERS_DIR/logs"
}

# Run main function
main "$@"
