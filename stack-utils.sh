#!/bin/bash

# Stack Management Utilities for Docker Compose Media Server
# This file contains utility functions for managing the media server stack

# Colors for output (if not already defined)
if [[ -z "$RED" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
fi

# Global variables to track stack state
STACK_SERVICE_WAS_RUNNING=false
STACK_COMPOSE_WAS_RUNNING=false

# Function to check if stack is running as a service
is_service_running() {
    local service_name="${1:-arr.service}"
    if systemctl is-active --quiet "$service_name" 2>/dev/null; then
        return 0
    fi
    return 1
}

# Function to check if docker-compose stack is running
is_compose_running() {
    if docker compose ps --services --filter "status=running" 2>/dev/null | grep -q .; then
        return 0
    fi
    return 1
}

# Function to detect installation type from .env or auto-detect
get_install_type() {
    # First check if INSTALL_TYPE is set in environment
    if [[ -n "$INSTALL_TYPE" ]]; then
        echo "$INSTALL_TYPE"
        return
    fi
    
    # Auto-detect based on what's running
    if is_service_running "arr.service"; then
        echo "service"
    elif is_compose_running; then
        echo "docker"
    else
        # Default to docker if nothing is running
        echo "docker"
    fi
}

# Function to stop the stack (with state tracking)
stop_stack() {
    local install_type=$(get_install_type)
    local service_name="${1:-arr.service}"
    
    if [[ "$install_type" == "service" ]] && is_service_running "$service_name"; then
        echo -e "${BLUE}Stopping $service_name...${NC}"
        if sudo systemctl stop "$service_name"; then
            echo -e "${GREEN}Service stopped successfully${NC}"
            STACK_SERVICE_WAS_RUNNING=true
        else
            echo -e "${RED}Failed to stop service${NC}"
            return 1
        fi
        
        # Wait for services to fully stop
        echo -e "${BLUE}Waiting for services to stop...${NC}"
        sleep 10
        
    elif [[ "$install_type" == "docker" ]] && is_compose_running; then
        echo -e "${BLUE}Stopping docker-compose stack...${NC}"
        if docker compose down; then
            echo -e "${GREEN}Stack stopped successfully${NC}"
            STACK_COMPOSE_WAS_RUNNING=true
        else
            echo -e "${RED}Failed to stop stack${NC}"
            return 1
        fi
        
        # Wait for containers to fully stop
        echo -e "${BLUE}Waiting for containers to stop...${NC}"
        sleep 5
        
    else
        echo -e "${YELLOW}Stack doesn't appear to be running${NC}"
    fi
    
    return 0
}

# Function to start the stack (based on previous state)
start_stack() {
    local service_name="${1:-arr.service}"
    
    if [[ "$STACK_SERVICE_WAS_RUNNING" == "true" ]]; then
        echo -e "${BLUE}Starting $service_name...${NC}"
        if sudo systemctl start "$service_name"; then
            echo -e "${GREEN}Service started successfully${NC}"
        else
            echo -e "${RED}Failed to start service${NC}"
            return 1
        fi
        
    elif [[ "$STACK_COMPOSE_WAS_RUNNING" == "true" ]]; then
        echo -e "${BLUE}Starting docker-compose stack...${NC}"
        if docker compose up -d; then
            echo -e "${GREEN}Stack started successfully${NC}"
        else
            echo -e "${RED}Failed to start stack${NC}"
            return 1
        fi
        
    else
        echo -e "${YELLOW}Stack was not running before operation, leaving it stopped${NC}"
    fi
    
    return 0
}

# Function to restart the stack
restart_stack() {
    local service_name="${1:-arr.service}"
    
    echo -e "${BLUE}Restarting stack...${NC}"
    
    if stop_stack "$service_name"; then
        sleep 2
        start_stack "$service_name"
    else
        echo -e "${RED}Failed to stop stack for restart${NC}"
        return 1
    fi
}

# Function to get stack status
get_stack_status() {
    local install_type=$(get_install_type)
    local service_name="${1:-arr.service}"
    
    if [[ "$install_type" == "service" ]]; then
        if is_service_running "$service_name"; then
            echo "service_running"
        else
            echo "service_stopped"
        fi
    else
        if is_compose_running; then
            echo "compose_running"
        else
            echo "compose_stopped"
        fi
    fi
}

# Function to wait for services to be healthy
wait_for_stack_health() {
    local max_attempts="${1:-30}"
    local service_name="${2:-arr.service}"
    
    echo -e "${BLUE}Checking stack health...${NC}"
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo -n "Attempt $attempt/$max_attempts: "
        
        local install_type=$(get_install_type)
        
        if [[ "$install_type" == "service" ]]; then
            if is_service_running "$service_name"; then
                echo -e "${GREEN}Service is running and healthy!${NC}"
                return 0
            else
                echo -e "${YELLOW}Service not yet ready${NC}"
            fi
        else
            # Check if any containers are unhealthy
            local unhealthy=$(docker compose ps --format json 2>/dev/null | jq -r '.[] | select(.Health == "unhealthy") | .Name' 2>/dev/null || true)
            
            if [ -n "$unhealthy" ]; then
                echo -e "${YELLOW}Some containers are unhealthy: $unhealthy${NC}"
            else
                # Check if all expected services are running
                local running_services=$(docker compose ps --services --filter "status=running" 2>/dev/null | wc -l)
                local total_services=$(docker compose config --services 2>/dev/null | wc -l)
                
                if [ "$running_services" -eq "$total_services" ] && [ "$running_services" -gt 0 ]; then
                    echo -e "${GREEN}All services are running and healthy!${NC}"
                    return 0
                else
                    echo -e "${YELLOW}$running_services/$total_services services running${NC}"
                fi
            fi
        fi
        
        sleep 10
        attempt=$((attempt + 1))
    done
    
    echo -e "${RED}Health check timeout. Some services may not be fully ready.${NC}"
    return 1
}

# Function to show stack status information
show_stack_info() {
    local install_type=$(get_install_type)
    local service_name="${1:-arr.service}"
    
    echo -e "${BLUE}Stack Information:${NC}"
    echo "Installation type: $install_type"
    
    if [[ "$install_type" == "service" ]]; then
        echo "Service name: $service_name"
        if is_service_running "$service_name"; then
            echo -e "Status: ${GREEN}Running${NC}"
        else
            echo -e "Status: ${RED}Stopped${NC}"
        fi
        
        echo ""
        echo -e "${BLUE}Useful commands:${NC}"
        echo "• Check service status: sudo systemctl status $service_name"
        echo "• View logs: sudo journalctl -u $service_name -f"
        echo "• Stop service: sudo systemctl stop $service_name"
        echo "• Start service: sudo systemctl start $service_name"
    else
        if is_compose_running; then
            echo -e "Status: ${GREEN}Running${NC}"
        else
            echo -e "Status: ${RED}Stopped${NC}"
        fi
        
        echo ""
        echo -e "${BLUE}Useful commands:${NC}"
        echo "• Check stack status: docker compose ps"
        echo "• View logs: docker compose logs -f"
        echo "• Stop stack: docker compose down"
        echo "• Start stack: docker compose up -d"
    fi
    
    echo "• View container status: docker compose ps"
}