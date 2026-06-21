#!/bin/bash

# Docker Compose Media Server Update Script
# This script updates the media server stack based on installation type

set -e

echo "========================================="
echo "Docker Compose Media Server Update"
echo "========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo -e "${RED}Error: .env file not found!${NC}"
    echo "Please run setup.sh first to configure your installation."
    exit 1
fi

# Check if setup-utils.sh exists and source it
if [ ! -f "setup-utils.sh" ]; then
    echo -e "${RED}Error: setup-utils.sh not found!${NC}"
    exit 1
fi

# Check if stack-utils.sh exists and source it
if [ ! -f "stack-utils.sh" ]; then
    echo -e "${RED}Error: stack-utils.sh not found!${NC}"
    exit 1
fi

# Source utility functions
source setup-utils.sh
source stack-utils.sh

# Load environment variables
load_env_file ".env"

# Get installation type (auto-detect if not set)
INSTALL_TYPE=$(get_install_type)

echo -e "${BLUE}Installation type: $INSTALL_TYPE${NC}"
echo ""

# Stack management functions are now in stack-utils.sh

# Main update logic
echo "========================================="
echo "Updating Media Server Stack"
echo "========================================="

# Pull latest images first (no downtime)
echo -e "${BLUE}Pulling latest Docker images...${NC}"
if docker compose pull; then
    echo -e "${GREEN}Images updated successfully${NC}"
else
    echo -e "${RED}Failed to pull images${NC}"
    exit 1
fi

# Update the stack based on installation type
if [ "$INSTALL_TYPE" = "service" ]; then
    # Service mode
    SERVICE_NAME="arr"
    
    echo "========================================="
    echo "Updating Service Installation"
    echo "========================================="
    
    # Check if service exists
    if ! systemctl list-unit-files | grep -q "^$SERVICE_NAME"; then
        echo -e "${RED}Error: Service $SERVICE_NAME not found!${NC}"
        echo "Please run setup.sh to install the service first."
        exit 1
    fi
    
    # Check if service is running and handle accordingly
    if is_service_running "$SERVICE_NAME"; then
        echo -e "${BLUE}Service is running, restarting to apply updates...${NC}"
        if sudo systemctl restart "$SERVICE_NAME"; then
            echo -e "${GREEN}Service restarted successfully${NC}"
        else
            echo -e "${RED}Failed to restart service${NC}"
            exit 1
        fi
    else
        echo -e "${BLUE}Service is stopped, starting with new images...${NC}"
        if sudo systemctl start "$SERVICE_NAME"; then
            echo -e "${GREEN}Service started successfully${NC}"
        else
            echo -e "${RED}Failed to start service${NC}"
            exit 1
        fi
    fi
    
    # Wait a moment for services to initialize
    sleep 5
    
    # Check service status and health
    wait_for_stack_health 30 "$SERVICE_NAME"
    
else
    # Docker stack mode - use docker compose up to restart only changed containers
    echo "========================================="
    echo "Updating Docker Stack"
    echo "========================================="
    
    # Use docker compose up -d which will only restart containers with new images
    if docker compose up -d; then
        echo -e "${GREEN}Stack updated successfully${NC}"
    else
        echo -e "${RED}Failed to update stack${NC}"
        exit 1
    fi
    
    # Wait a moment for services to initialize
    sleep 5
    
    # Check stack health
    wait_for_stack_health
fi

echo ""
echo "========================================="
echo "Update Complete!"
echo "========================================="
echo ""
echo -e "${GREEN}Your media server stack has been updated successfully!${NC}"
echo -e "${GREEN}Only containers with new images were restarted to minimize downtime.${NC}"
echo ""
show_stack_info "$SERVICE_NAME"
echo ""
echo -e "${YELLOW}Note: It may take a few minutes for all services to be fully ready.${NC}"