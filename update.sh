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
    
    # Stop service if running
    stop_stack "$SERVICE_NAME"
    
    # Pull latest images
    echo -e "${BLUE}Pulling latest Docker images...${NC}"
    if docker compose pull; then
        echo -e "${GREEN}Images updated successfully${NC}"
    else
        echo -e "${RED}Failed to pull images${NC}"
        exit 1
    fi
    
    # Start service
    if ! start_stack "$SERVICE_NAME"; then
        echo -e "${RED}Failed to start service${NC}"
        exit 1
    fi
    
    # Wait a moment for services to initialize
    sleep 5
    
    # Check service status and health
    wait_for_stack_health 30 "$SERVICE_NAME"
    
else
    # Docker stack mode
    echo "========================================="
    echo "Updating Docker Stack"
    echo "========================================="
    
    # Stop stack if running
    stop_stack
    
    # Pull latest images
    echo -e "${BLUE}Pulling latest Docker images...${NC}"
    if docker compose pull; then
        echo -e "${GREEN}Images updated successfully${NC}"
    else
        echo -e "${RED}Failed to pull images${NC}"
        exit 1
    fi
    
    # Start stack
    if ! start_stack; then
        echo -e "${RED}Failed to start stack${NC}"
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
echo ""
show_stack_info "$SERVICE_NAME"
echo ""
echo -e "${YELLOW}Note: It may take a few minutes for all services to be fully ready.${NC}"