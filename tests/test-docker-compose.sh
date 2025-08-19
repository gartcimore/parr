#!/bin/bash

# Test script for Docker Compose configuration validation
# This script validates docker-compose.yml structure and service definitions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Function to detect and use the correct Docker Compose command
get_compose_cmd() {
    if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        echo "docker compose"
    elif command -v docker-compose >/dev/null 2>&1; then
        echo "docker-compose"
    else
        echo ""
    fi
}

# Get the compose command
COMPOSE_CMD=$(get_compose_cmd)

if [ -z "$COMPOSE_CMD" ]; then
    print_fail "Neither 'docker compose' nor 'docker-compose' is available"
    exit 1
fi

print_test "Using Docker Compose command: $COMPOSE_CMD"

# Test 1: Validate docker-compose.yml syntax
test_compose_syntax() {
    print_test "Validating docker-compose.yml syntax"
    
    if $COMPOSE_CMD config --quiet >/dev/null 2>&1; then
        print_pass "docker-compose.yml syntax is valid"
        return 0
    else
        print_fail "docker-compose.yml has syntax errors"
        return 1
    fi
}

# Test 2: Check required services are defined
test_required_services() {
    print_test "Checking required services are defined"
    
    local required_services=(
        "socket-proxy"
        "traefik"
        "prowlarr"
        "radarr"
        "sonarr"
        "bazarr"
        "lidarr"
        "jellyfin"
        "jellyseer"
        "homarr"
        "gluetun"
        "qbittorrent"
    )
    
    local services=$($COMPOSE_CMD config --services 2>/dev/null)
    local missing_services=()
    
    for service in "${required_services[@]}"; do
        if ! echo "$services" | grep -q "^${service}$"; then
            missing_services+=("$service")
        fi
    done
    
    if [ ${#missing_services[@]} -eq 0 ]; then
        print_pass "All required services are defined"
        return 0
    else
        print_fail "Missing services: ${missing_services[*]}"
        return 1
    fi
}

# Test 3: Validate network configurations
test_network_config() {
    print_test "Validating network configurations"
    
    local config=$($COMPOSE_CMD config 2>/dev/null)
    
    # Check for required networks
    if ! echo "$config" | grep -q "traefik:"; then
        print_fail "traefik network not defined"
        return 1
    fi
    
    if ! echo "$config" | grep -q "socket_proxy:"; then
        print_fail "socket_proxy network not defined"
        return 1
    fi
    
    # Check socket_proxy network is internal
    if ! echo "$config" | grep -A 5 "socket_proxy:" | grep -q "internal: true"; then
        print_fail "socket_proxy network should be internal"
        return 1
    fi
    
    print_pass "Network configurations are valid"
    return 0
}

# Test 4: Validate Traefik labels
test_traefik_labels() {
    print_test "Validating Traefik labels on services"
    
    local services_with_web=("prowlarr" "radarr" "sonarr" "bazarr" "lidarr" "jellyfin" "jellyseer" "homarr")
    local config=$($COMPOSE_CMD config 2>/dev/null)
    
    for service in "${services_with_web[@]}"; do
        # Check for traefik.enable=true
        if ! echo "$config" | grep -A 50 "${service}:" | grep -q "traefik.enable.*true"; then
            print_fail "Service $service missing traefik.enable=true label"
            return 1
        fi
        
        # Check for router rule
        if ! echo "$config" | grep -A 50 "${service}:" | grep -q "traefik.http.routers.${service}.rule"; then
            print_fail "Service $service missing router rule"
            return 1
        fi
    done
    
    print_pass "All web services have proper Traefik labels"
    return 0
}

# Test 5: Validate volume mounts
test_volume_mounts() {
    print_test "Validating volume mount configurations"
    
    local config=$($COMPOSE_CMD config 2>/dev/null)
    
    # Check that services have proper config volume mounts
    local services_with_config=("prowlarr" "radarr" "sonarr" "bazarr" "lidarr" "jellyfin" "jellyseer" "homarr" "gluetun" "qbittorrent")
    
    for service in "${services_with_config[@]}"; do
        if ! echo "$config" | grep -A 20 "${service}:" | grep -q "DOCKER_CONFIG_DIR"; then
            print_warn "Service $service may be missing config volume mount"
        fi
    done
    
    # Check data volume mounts for *arr services (check for /data mount)
    local arr_services=("radarr" "sonarr" "bazarr" "lidarr")
    
    for service in "${arr_services[@]}"; do
        if ! echo "$config" | grep -A 30 "${service}:" | grep -E "(:/data|target: /data)"; then
            print_fail "Service $service missing data volume mount"
            return 1
        fi
    done
    
    print_pass "Volume mount configurations are valid"
    return 0
}

# Test 6: Validate environment variables usage
test_env_variables() {
    print_test "Validating environment variable usage"
    
    local config=$($COMPOSE_CMD config 2>/dev/null)
    
    # Check for required environment variables (they should be resolved in the config)
    local required_env_vars=("TZ" "DOCKER_CONFIG_DIR" "DATA_DIR" "HOSTNAME")
    
    for var in "${required_env_vars[@]}"; do
        # Check if the variable is used in the original docker-compose.yml
        if ! grep -q "\${${var}}" docker-compose.yml; then
            print_fail "Environment variable $var not used in docker-compose.yml"
            return 1
        fi
    done
    
    print_pass "Environment variables are properly used"
    return 0
}

# Test 7: Validate service dependencies
test_service_dependencies() {
    print_test "Validating service dependencies"
    
    local config=$($COMPOSE_CMD config 2>/dev/null)
    
    # Check qbittorrent depends on gluetun
    if ! echo "$config" | grep -A 10 "qbittorrent:" | grep -q "depends_on:"; then
        print_fail "qbittorrent should depend on gluetun"
        return 1
    fi
    
    # Check qbittorrent uses gluetun network
    if ! echo "$config" | grep -A 15 "qbittorrent:" | grep -q "network_mode.*gluetun"; then
        print_fail "qbittorrent should use gluetun network mode"
        return 1
    fi
    
    print_pass "Service dependencies are properly configured"
    return 0
}

# Test 8: Validate security configurations
test_security_config() {
    print_test "Validating security configurations"
    
    local config=$($COMPOSE_CMD config 2>/dev/null)
    
    # Check socket-proxy restrictions
    if ! echo "$config" | grep -A 10 "socket-proxy:" | grep -q "CONTAINERS.*1"; then
        print_fail "socket-proxy missing CONTAINERS=1 restriction"
        return 1
    fi
    
    if ! echo "$config" | grep -A 10 "socket-proxy:" | grep -q "POST.*0"; then
        print_fail "socket-proxy missing POST=0 restriction"
        return 1
    fi
    
    # Check gluetun capabilities
    if ! echo "$config" | grep -A 10 "gluetun:" | grep -q "NET_ADMIN"; then
        print_fail "gluetun missing NET_ADMIN capability"
        return 1
    fi
    
    print_pass "Security configurations are valid"
    return 0
}

# Main test execution
main() {
    echo "========================================="
    echo "Docker Compose Configuration Tests"
    echo "========================================="
    echo ""
    
    # Create temporary test .env file in a temp directory
    local temp_dir=$(mktemp -d)
    local test_env_file="$temp_dir/.env"
    
    print_test "Creating temporary test .env file from .env.sample"
    if [ -f ".env.sample" ]; then
        cp .env.sample "$test_env_file"
        # Set test values (using /tmp paths that won't be created)
        sed -i 's|DATA_DIR=.*|DATA_DIR=/tmp/test-data|' "$test_env_file"
        sed -i 's|DOCKER_CONFIG_DIR=.*|DOCKER_CONFIG_DIR=/tmp/test-config|' "$test_env_file"
        sed -i 's|HOSTNAME=.*|HOSTNAME=test.local|' "$test_env_file"
        
        # Export the variables for docker-compose to use
        export $(grep -v '^#' "$test_env_file" | xargs)
    else
        print_fail ".env.sample not found, cannot create test environment"
        exit 1
    fi
    
    local tests_passed=0
    local tests_failed=0
    
    # Run all tests
    local test_functions=(
        "test_compose_syntax"
        "test_required_services"
        "test_network_config"
        "test_traefik_labels"
        "test_volume_mounts"
        "test_env_variables"
        "test_service_dependencies"
        "test_security_config"
    )
    
    for test_func in "${test_functions[@]}"; do
        if $test_func; then
            tests_passed=$((tests_passed + 1))
        else
            tests_failed=$((tests_failed + 1))
        fi
        echo ""
    done
    
    # Summary
    echo "========================================="
    echo "Test Summary"
    echo "========================================="
    echo -e "${GREEN}Passed: $tests_passed${NC}"
    echo -e "${RED}Failed: $tests_failed${NC}"
    echo ""
    
    # Cleanup temporary directory
    if [ -n "$temp_dir" ] && [ -d "$temp_dir" ]; then
        rm -rf "$temp_dir"
    fi
    
    if [ $tests_failed -eq 0 ]; then
        print_pass "All Docker Compose tests passed!"
        exit 0
    else
        print_fail "$tests_failed test(s) failed"
        exit 1
    fi
}

# Run main function
main "$@"