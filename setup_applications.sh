#!/bin/bash

# Ubuntu Server Initial Setup Script
# This script performs initial setup including Docker, Nginx, and user configuration
# Run as: sudo ./setup_applications.sh

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Main setup
main() {
    print_header "Ubuntu Server Initial Setup"
    
    check_root
    
    # Update system packages
    print_header "Step 1: Updating System Packages"
    print_status "Running apt update..."
    apt update -y
    print_status "Running apt upgrade..."
    apt upgrade -y
    
    # Install Docker
    print_header "Step 2: Installing Docker"
    
    if command_exists docker; then
        print_warning "Docker is already installed"
        docker --version
    else
        print_status "Installing Docker..."
        
        # Install dependencies
        apt install -y \
            apt-transport-https \
            ca-certificates \
            curl \
            gnupg \
            lsb-release
        
        # Add Docker GPG key
        print_info "Adding Docker GPG key..."
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        
        # Add Docker repository
        print_info "Adding Docker repository..."
        echo \
            "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
            $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Update package index
        apt update -y
        
        # Install Docker
        apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        
        print_status "Docker installed successfully"
        docker --version
    fi
    
    # Add ubuntu user to docker group
    print_header "Step 3: Configuring Docker User Permissions"
    
    if id -nG "ubuntu" | grep -qw "docker"; then
        print_warning "User 'ubuntu' is already in docker group"
    else
        print_status "Adding user 'ubuntu' to docker group..."
        usermod -aG docker ubuntu
        print_info "User 'ubuntu' added to docker group"
        print_warning "Note: You may need to log out and log back in for group changes to take effect"
    fi
    
    # Start and enable Docker
    print_status "Starting Docker service..."
    systemctl start docker
    systemctl enable docker
    print_status "Docker service enabled and started"
    
    # Install Nginx
    print_header "Step 4: Installing Nginx"
    
    if command_exists nginx; then
        print_warning "Nginx is already installed"
        nginx -v
    else
        print_status "Installing Nginx..."
        apt install -y nginx
        
        print_status "Nginx installed successfully"
        nginx -v
    fi
    
    # Start and enable Nginx
    print_status "Starting Nginx service..."
    systemctl start nginx
    systemctl enable nginx
    print_status "Nginx service enabled and started"
    
    # # Install Certbot (optional, for SSL certificates)
    # print_header "Step 5: Installing Certbot (Optional)"
    
    # if command_exists certbot; then
    #     print_warning "Certbot is already installed"
    #     certbot --version
    # else
    #     print_status "Installing Certbot and Nginx plugin..."
    #     apt install -y certbot python3-certbot-nginx
        
    #     print_status "Certbot installed successfully"
    #     certbot --version
    # fi
    
    # Summary
    print_header "Setup Complete"
    
    print_status "All components installed successfully!"
    echo ""
    print_info "Installed components:"
    echo "  • Docker: $(docker --version)"
    echo "  • Nginx: $(nginx -v 2>&1)"
    echo "  • Certbot: $(certbot --version)"
    echo ""
    
    print_info "Next steps:"
    echo "  1. Log out and log back in for docker group changes to take effect"
    echo "  2. Verify Docker: docker ps"
    echo "  3. Check Nginx: sudo systemctl status nginx"
    echo "  4. Configure Nginx: /etc/nginx/sites-available/"
    echo "  5. Setup SSL with Certbot: sudo certbot --nginx -d yourdomain.com"
    echo ""
    
    print_warning "Important: Log out and log back in to use Docker without sudo"
}

# Run main function
main "$@"
