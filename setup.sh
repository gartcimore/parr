#!/bin/bash

# Docker Compose Media Server Setup Script
# This script helps configure the environment variables for your media server setup

set -e

echo "========================================="
echo "Docker Compose Media Server Setup"
echo "========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to prompt for input with default value
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    
    echo -e "${BLUE}$prompt${NC}"
    echo -e "${YELLOW}Current/Default: $default${NC}"
    read -p "Enter value (or press Enter for default): " input
    
    if [ -z "$input" ]; then
        eval "$var_name='$default'"
    else
        eval "$var_name='$input'"
    fi
}

# Function to safely load environment variables from file
load_env_file() {
    local file="$1"
    if [ -f "$file" ]; then
        # Read variables safely, ignoring comments and empty lines
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            [[ $key =~ ^[[:space:]]*# ]] && continue
            [[ -z $key ]] && continue
            
            # Remove leading/trailing whitespace and quotes
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs | sed 's/^["'\'']//' | sed 's/["'\'']*$//')
            
            # Export the variable
            if [ -n "$key" ] && [ -n "$value" ]; then
                export "$key"="$value"
            fi
        done < "$file"
    fi
}

# Read current values from .env if it exists
if [ -f ".env" ]; then
    echo -e "${GREEN}Found existing .env file. Loading current values...${NC}"
    load_env_file ".env"
else
    echo -e "${YELLOW}No existing .env file found. Using defaults from .env.sample...${NC}"
    if [ -f ".env.sample" ]; then
        load_env_file ".env.sample"
    fi
fi

echo ""
echo "========================================="
echo "Basic Configuration"
echo "========================================="

# Basic config
prompt_with_default "Timezone (e.g., America/New_York, Europe/Paris):" "${TZ:-Europe/Paris}" "NEW_TZ"
prompt_with_default "Docker config directory (where app configs will be stored):" "${DOCKER_CONFIG_DIR:-/docker/appdata}" "NEW_DOCKER_CONFIG_DIR"
prompt_with_default "Hostname for Traefik (your local domain):" "${HOSTNAME:-media.local}" "NEW_HOSTNAME"

echo ""
echo "========================================="
echo "Installation Type"
echo "========================================="

# Installation type selection
echo -e "${BLUE}Choose installation type:${NC}"
echo "1. Service (systemctl) - Recommended for always-on setup (linux only)"
echo "2. Regular Docker Stack - Manual docker-compose management"
echo ""
read -p "Enter choice (1 or 2) [default: 1]: " install_choice

if [ -z "$install_choice" ] || [ "$install_choice" = "1" ]; then
    NEW_INSTALL_TYPE="service"
    echo -e "${GREEN}Selected: Service installation${NC}"
elif [ "$install_choice" = "2" ]; then
    NEW_INSTALL_TYPE="docker"
    echo -e "${GREEN}Selected: Regular Docker Stack${NC}"
else
    echo -e "${YELLOW}Invalid choice. Defaulting to service installation.${NC}"
    NEW_INSTALL_TYPE="service"
fi

echo ""
echo "========================================="
echo "Security Configuration"
echo "========================================="

# Generate Homarr secret key
echo -e "${BLUE}Generating secure encryption key for Homarr...${NC}"
if command -v openssl >/dev/null 2>&1; then
    NEW_HOMARR_SECRET_KEY=$(openssl rand -hex 32)
    echo -e "${GREEN}Generated 64-character encryption key${NC}"
else
    echo -e "${YELLOW}OpenSSL not found. Using fallback method...${NC}"
    # Fallback: generate using /dev/urandom if available
    if [ -r /dev/urandom ]; then
        NEW_HOMARR_SECRET_KEY=$(head -c 32 /dev/urandom | xxd -p -c 32)
        echo -e "${GREEN}Generated 64-character encryption key${NC}"
    else
        echo -e "${RED}Cannot generate secure key automatically${NC}"
        prompt_with_default "Homarr encryption key (64 characters):" "${HOMARR_SECRET_KEY:-$(date +%s | sha256sum | head -c 64)}" "NEW_HOMARR_SECRET_KEY"
    fi
fi

echo ""
echo "========================================="
echo "Media Storage Paths"
echo "========================================="

prompt_with_default "Primary media directory (for movies, TV shows, etc.):" "${MEDIA_DIR:-/media}" "NEW_MEDIA_DIR"

# Ask about additional mount points
echo ""
echo -e "${BLUE}Do you have additional storage locations? (y/n)${NC}"
read -p "Answer: " additional_storage

if [[ $additional_storage =~ ^[Yy]$ ]]; then
    prompt_with_default "Secondary data directory (optional):" "/mnt/data" "SECONDARY_DATA_DIR"
    prompt_with_default "Downloads directory:" "/mnt/dataYmir/downloads" "DOWNLOADS_DIR"
else
    SECONDARY_DATA_DIR=""
    DOWNLOADS_DIR="${NEW_MEDIA_DIR}/downloads"
fi

echo ""
echo "========================================="
echo "VPN Configuration (for qBittorrent)"
echo "========================================="

prompt_with_default "VPN Type (wireguard or openvpn):" "${VPN_TYPE:-wireguard}" "NEW_VPN_TYPE"
prompt_with_default "VPN Server Countries (comma-separated):" "${SERVER_COUNTRIES:-United States,Canada,United Kingdom}" "NEW_SERVER_COUNTRIES"

if [[ $NEW_VPN_TYPE == "openvpn" ]]; then
    prompt_with_default "OpenVPN Username:" "${OPENVPN_USER:-your_username+pmp}" "NEW_OPENVPN_USER"
    prompt_with_default "OpenVPN Password:" "${OPENVPN_PASSWORD:-your_password}" "NEW_OPENVPN_PASSWORD"
    NEW_WIREGUARD_PRIVATE_KEY="${WIREGUARD_PRIVATE_KEY:-your_wireguard_private_key_here}"
else
    prompt_with_default "WireGuard Private Key:" "${WIREGUARD_PRIVATE_KEY:-your_wireguard_private_key_here}" "NEW_WIREGUARD_PRIVATE_KEY"
    NEW_OPENVPN_USER="${OPENVPN_USER:-your_username+pmp}"
    NEW_OPENVPN_PASSWORD="${OPENVPN_PASSWORD:-your_password}"
fi

echo ""
echo "========================================="
echo "Writing Configuration"
echo "========================================="

# Write the .env file first so create-volumes.sh can use it
cat > .env << EOF
# Docker Compose Media Server Configuration
# Generated by setup script on $(date)

# Base config
TZ=$NEW_TZ
MEDIA_DIR=$NEW_MEDIA_DIR
DOCKER_CONFIG_DIR=$NEW_DOCKER_CONFIG_DIR
INSTALL_TYPE=$NEW_INSTALL_TYPE

# Traefik config
HOSTNAME=$NEW_HOSTNAME

# Homarr config
HOMARR_SECRET_KEY=$NEW_HOMARR_SECRET_KEY

# Gluetun config
VPN_TYPE=$NEW_VPN_TYPE
SERVER_COUNTRIES=$NEW_SERVER_COUNTRIES

# OpenVPN config
OPENVPN_USER=$NEW_OPENVPN_USER
OPENVPN_PASSWORD=$NEW_OPENVPN_PASSWORD

# Wireguard config
WIREGUARD_PRIVATE_KEY=$NEW_WIREGUARD_PRIVATE_KEY
EOF

echo -e "${GREEN}Configuration written to .env file!${NC}"

echo ""
echo "========================================="
echo "Creating Directories"
echo "========================================="

# Run the create-volumes script to create all necessary directories
echo -e "${BLUE}Running create-volumes.sh to create all necessary directories...${NC}"
if [ -f "./create-volumes.sh" ]; then
    chmod +x ./create-volumes.sh
    ./create-volumes.sh
else
    echo -e "${YELLOW}Warning: create-volumes.sh not found. You may need to create directories manually.${NC}"
fi

echo ""
echo "========================================="
echo "Service Installation"
echo "========================================="

# Handle service installation if selected
if [ "$NEW_INSTALL_TYPE" = "service" ]; then
    echo -e "${BLUE}Installing as systemd service...${NC}"
    
    # Check if arr.service exists
    if [ ! -f "arr.service" ]; then
        echo -e "${RED}Error: arr.service file not found!${NC}"
        echo -e "${YELLOW}Continuing with setup, but service installation failed.${NC}"
    else
        # Get current directory path
        CURRENT_DIR=$(pwd)
        
        # Copy service file to systemd directory as a template service
        SERVICE_NAME="arr@$(basename "$CURRENT_DIR").service"
        
        if sudo cp arr.service "/etc/systemd/system/$SERVICE_NAME"; then
            echo -e "${GREEN}Service file copied to /etc/systemd/system/$SERVICE_NAME${NC}"
            
            # Reload systemd and enable the service
            if sudo systemctl daemon-reload && sudo systemctl enable "$SERVICE_NAME"; then
                echo -e "${GREEN}Service enabled successfully!${NC}"
                echo -e "${BLUE}You can now use:${NC}"
                echo "  sudo systemctl start $SERVICE_NAME    # Start the service"
                echo "  sudo systemctl stop $SERVICE_NAME     # Stop the service"
                echo "  sudo systemctl status $SERVICE_NAME   # Check service status"
            else
                echo -e "${RED}Failed to enable service${NC}"
            fi
        else
            echo -e "${RED}Failed to copy service file. Make sure you have sudo privileges.${NC}"
        fi
    fi
else
    echo -e "${BLUE}Skipping service installation (Docker stack mode selected)${NC}"
fi

echo ""
echo "========================================="
echo "Setup Complete!"
echo "========================================="
echo ""
echo -e "${GREEN}Your media server is now configured with:${NC}"
echo "• Timezone: $NEW_TZ"
echo "• Config Directory: $NEW_DOCKER_CONFIG_DIR"
echo "• Hostname: $NEW_HOSTNAME"
echo "• Media Directory: $NEW_MEDIA_DIR"
echo "• Downloads Directory: $DOWNLOADS_DIR"
echo "• VPN Type: $NEW_VPN_TYPE"
echo "• Installation Type: $NEW_INSTALL_TYPE"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Review the generated .env file if needed"
echo "2. Update your VPN credentials in .env if needed"
if [ "$NEW_INSTALL_TYPE" = "service" ]; then
    echo "3. Start the service: sudo systemctl start arr@$(basename "$(pwd)")"
else
    echo "3. Run: docker-compose up -d"
fi
echo "4. Configure your local DNS to point $NEW_HOSTNAME to this machine's IP"
echo ""
echo -e "${GREEN}All directories have been created with proper permissions!${NC}"
echo -e "${YELLOW}If you encounter permission issues, you may need to adjust ownership manually.${NC}"