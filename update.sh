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

# Load environment variables
source .env

# Check if INSTALL_TYPE is set
if [ -z "$INSTALL_TYPE" ]; then
    echo -e "${YELLOW}Warning: INSTALL_TYPE not found in .env file.${NC}"
    echo "Assuming docker stack installation..."
    INSTALL_TYPE="docker"
fi

echo -e "${BLUE}Installation type: $INSTALL_TYPE${NC}"
echo ""

# Function to check if service is running
is_service_running() {
    local service_name="$1"
    systemctl is-active --quiet "$service_name" 2>/dev/null
}

# Function to check if docker compose stack is running
is_docker_stack_running() {
    docker compose ps --services --filter "status=running" 2>/dev/null | grep -q .
}

# Function to wait for services to be healthy
wait_for_health() {
    echo -e "${BLUE}Checking stack health...${NC}"
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo -n "Attempt $attempt/$max_attempts: "
        
        # Check if any containers are unhealthy
        unhealthy=$(docker compose ps --format json 2>/dev/null | jq -r '.[] | select(.Health == "unhealthy") | .Name' 2>/dev/null || true)
        
        if [ -n "$unhealthy" ]; then
            echo -e "${YELLOW}Some containers are unhealthy: $unhealthy${NC}"
        else
            # Check if all expected services are running
            running_services=$(docker compose ps --services --filter "status=running" 2>/dev/null | wc -l)
            total_services=$(docker compose config --services 2>/dev/null | wc -l)
            
            if [ "$running_services" -eq "$total_services" ] && [ "$running_services" -gt 0 ]; then
                echo -e "${GREEN}All services are running and healthy!${NC}"
                return 0
            else
                echo -e "${YELLOW}$running_services/$total_services services running${NC}"
            fi
        fi
        
        sleep 10
        attempt=$((attempt + 1))
    done
    
    echo -e "${RED}Health check timeout. Some services may not be fully ready.${NC}"
    return 1
}

# Main update logic
if [ "$INSTALL_TYPE" = "service" ]; then
    # Service mode
    SERVICE_NAME="arr@$(basename "$(pwd)")"
    
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
    if is_service_running "$SERVICE_NAME"; then
        echo -e "${BLUE}Stopping service $SERVICE_NAME...${NC}"
        if sudo systemctl stop "$SERVICE_NAME"; then
            echo -e "${GREEN}Service stopped successfully${NC}"
        else
            echo -e "${RED}Failed to stop service${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}Service $SERVICE_NAME is not running${NC}"
    fi
    
    # Pull latest images
    echo -e "${BLUE}Pulling latest Docker images...${NC}"
    if docker compose pull; then
        echo -e "${GREEN}Images updated successfully${NC}"
    else
        echo -e "${RED}Failed to pull images${NC}"
        exit 1
    fi
    
    # Start service
    echo -e "${BLUE}Starting service $SERVICE_NAME...${NC}"
    if sudo systemctl start "$SERVICE_NAME"; then
        echo -e "${GREEN}Service started successfully${NC}"
    else
        echo -e "${RED}Failed to start service${NC}"
        exit 1
    fi
    
    # Wait a moment for services to initialize
    sleep 5
    
    # Check service status
    echo -e "${BLUE}Checking service status...${NC}"
    if is_service_running "$SERVICE_NAME"; then
        echo -e "${GREEN}Service is running${NC}"
        wait_for_health
    else
        echo -e "${RED}Service failed to start properly${NC}"
        echo "Check logs with: sudo journalctl -u $SERVICE_NAME -f"
        exit 1
    fi
    
else
    # Docker stack mode
    echo "========================================="
    echo "Updating Docker Stack"
    echo "========================================="
    
    # Stop stack if running
    if is_docker_stack_running; then
        echo -e "${BLUE}Stopping Docker stack...${NC}"
        if docker compose down; then
            echo -e "${GREEN}Stack stopped successfully${NC}"
        else
            echo -e "${RED}Failed to stop stack${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}Docker stack is not running${NC}"
    fi
    
    # Pull latest images
    echo -e "${BLUE}Pulling latest Docker images...${NC}"
    if docker compose pull; then
        echo -e "${GREEN}Images updated successfully${NC}"
    else
        echo -e "${RED}Failed to pull images${NC}"
        exit 1
    fi
    
    # Start stack
    echo -e "${BLUE}Starting Docker stack...${NC}"
    if docker compose up -d; then
        echo -e "${GREEN}Stack started successfully${NC}"
    else
        echo -e "${RED}Failed to start stack${NC}"
        exit 1
    fi
    
    # Wait a moment for services to initialize
    sleep 5
    
    # Check stack health
    wait_for_health
fi

echo ""
echo "========================================="
echo "Update Complete!"
echo "========================================="
echo ""
echo -e "${GREEN}Your media server stack has been updated successfully!${NC}"
echo ""
echo -e "${BLUE}Useful commands:${NC}"
if [ "$INSTALL_TYPE" = "service" ]; then
    echo "• Check service status: sudo systemctl status $SERVICE_NAME"
    echo "• View logs: sudo journalctl -u $SERVICE_NAME -f"
    echo "• Stop service: sudo systemctl stop $SERVICE_NAME"
    echo "• Start service: sudo systemctl start $SERVICE_NAME"
else
    echo "• Check stack status: docker compose ps"
    echo "• View logs: docker compose logs -f"
    echo "• Stop stack: docker compose down"
    echo "• Start stack: docker compose up -d"
fi
echo "• View container status: docker compose ps"
echo ""
echo -e "${YELLOW}Note: It may take a few minutes for all services to be fully ready.${NC}"