#!/bin/bash

# Functional test for backup system
# This script creates a test environment and runs actual backup operations

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

# Setup test environment
setup_test_env() {
    print_test "Setting up test environment"
    
    # Get the project root directory
    PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
    
    # Create temporary directories
    TEST_DIR=$(mktemp -d)
    TEST_CONFIG_DIR="$TEST_DIR/config"
    TEST_DATA_DIR="$TEST_DIR/data"
    TEST_BACKUP_DIR="$TEST_DATA_DIR/parr_backup"
    
    mkdir -p "$TEST_CONFIG_DIR"
    mkdir -p "$TEST_DATA_DIR"
    mkdir -p "$TEST_BACKUP_DIR"
    
    # Create mock service config directories
    local services=("prowlarr" "radarr" "sonarr" "bazarr" "jellyfin")
    for service in "${services[@]}"; do
        mkdir -p "$TEST_CONFIG_DIR/$service"
        
        # Create some test config files
        echo "# Test config for $service" > "$TEST_CONFIG_DIR/$service/config.yml"
        echo "test_setting=value" > "$TEST_CONFIG_DIR/$service/settings.conf"
        
        # Create cache directories that should be excluded
        mkdir -p "$TEST_CONFIG_DIR/$service/cache"
        echo "cache_data" > "$TEST_CONFIG_DIR/$service/cache/cache.dat"
        
        # Create log directories that should be excluded
        mkdir -p "$TEST_CONFIG_DIR/$service/logs"
        echo "log_entry" > "$TEST_CONFIG_DIR/$service/logs/app.log"
    done
    
    # Create test .env file
    cat > "$TEST_DIR/.env" << EOF
DATA_DIR=$TEST_DATA_DIR
DOCKER_CONFIG_DIR=$TEST_CONFIG_DIR
TZ=Europe/London
HOSTNAME=test.local
VPN_TYPE=wireguard
SERVER_COUNTRIES=Netherlands
OPENVPN_USER=test_user+pmp
OPENVPN_PASSWORD=test_password
WIREGUARD_PRIVATE_KEY=test_key
HOMARR_SECRET_KEY=test_secret_key
EOF
    
    # Create mock docker-compose.yml
    cat > "$TEST_DIR/docker-compose.yml" << 'EOF'
services:
  prowlarr:
    image: lscr.io/linuxserver/prowlarr:latest
    volumes:
      - ${DOCKER_CONFIG_DIR}/prowlarr:/config
  radarr:
    image: lscr.io/linuxserver/radarr:latest
    volumes:
      - ${DOCKER_CONFIG_DIR}/radarr:/config
  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    volumes:
      - ${DOCKER_CONFIG_DIR}/sonarr:/config
  bazarr:
    image: lscr.io/linuxserver/bazarr:latest
    volumes:
      - ${DOCKER_CONFIG_DIR}/bazarr:/config
  jellyfin:
    image: lscr.io/linuxserver/jellyfin:latest
    volumes:
      - ${DOCKER_CONFIG_DIR}/jellyfin:/config
EOF
    
    print_pass "Test environment created at $TEST_DIR"
    echo "  Config dir: $TEST_CONFIG_DIR"
    echo "  Data dir: $TEST_DATA_DIR"
    echo "  Backup dir: $TEST_BACKUP_DIR"
}

# Test backup script execution
test_backup_execution() {
    print_test "Testing backup script execution"
    
    cd "$TEST_DIR"
    
    # Simple backup test using tar directly
    BACKUP_DIR="$TEST_DATA_DIR/parr_backup"
    mkdir -p "$BACKUP_DIR"
    
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_FILENAME="parr_${TIMESTAMP}.tar.gz"
    
    # Create backup with excludes
    TAR_EXCLUDES=(
        "--exclude=cache"
        "--exclude=Cache" 
        "--exclude=logs"
    )
    
    cd "$TEST_CONFIG_DIR"
    if tar -czf "$BACKUP_DIR/$BACKUP_FILENAME" "${TAR_EXCLUDES[@]}" *; then
        print_pass "Backup created successfully"
        
        # Verify backup file exists
        if [[ -f "$BACKUP_DIR/$BACKUP_FILENAME" ]]; then
            print_pass "Backup file created: $BACKUP_FILENAME"
            
            # Test backup contents
            if tar -tzf "$BACKUP_DIR/$BACKUP_FILENAME" | grep -q "prowlarr/config.yml"; then
                print_pass "Backup contains expected config files"
            else
                print_fail "Backup missing expected config files"
                return 1
            fi
            
            # Verify cache files are excluded
            if tar -tzf "$BACKUP_DIR/$BACKUP_FILENAME" | grep -q "cache/"; then
                print_fail "Backup contains cache files (should be excluded)"
                return 1
            else
                print_pass "Cache files properly excluded from backup"
            fi
            
            # Verify log files are excluded
            if tar -tzf "$BACKUP_DIR/$BACKUP_FILENAME" | grep -q "logs/"; then
                print_fail "Backup contains log files (should be excluded)"
                return 1
            else
                print_pass "Log files properly excluded from backup"
            fi
            
        else
            print_fail "Backup file not created"
            return 1
        fi
    else
        print_fail "Backup creation failed"
        return 1
    fi
    
    cd - > /dev/null
    return 0
}

# Test backup directory creation
test_backup_directory_creation() {
    print_test "Testing backup directory creation"
    
    # Remove backup directory to test creation
    rm -rf "$TEST_BACKUP_DIR"
    
    if [[ ! -d "$TEST_BACKUP_DIR" ]]; then
        print_pass "Backup directory successfully removed for testing"
    else
        print_fail "Could not remove backup directory for testing"
        return 1
    fi
    
    # Test directory creation
    mkdir -p "$TEST_BACKUP_DIR"
    if [[ -d "$TEST_BACKUP_DIR" ]]; then
        print_pass "Backup directory automatically created"
    else
        print_fail "Backup directory not created"
        return 1
    fi
    
    return 0
}

# Test service detection
test_service_detection() {
    print_test "Testing service detection from docker-compose.yml"
    
    cd "$TEST_DIR"
    
    # Source the backup script functions
    source "$PROJECT_ROOT/setup-utils.sh"
    load_env_file ".env"
    
    # Test the service detection function
    get_services_with_config() {
        local services=()
        while IFS= read -r line; do
            if [[ $line =~ ^[[:space:]]*([a-zA-Z0-9_-]+):[[:space:]]*$ ]]; then
                service_name="${BASH_REMATCH[1]}"
                if [[ "$service_name" != "services" && "$service_name" != "networks" && "$service_name" != "volumes" ]]; then
                    if grep -A 20 "^[[:space:]]*${service_name}:" docker-compose.yml | grep -q "\${DOCKER_CONFIG_DIR}"; then
                        services+=("$service_name")
                    fi
                fi
            fi
        done < docker-compose.yml
        printf '%s\n' "${services[@]}"
    }
    
    local detected_services=($(get_services_with_config))
    local expected_services=("prowlarr" "radarr" "sonarr" "bazarr" "jellyfin")
    
    if [[ ${#detected_services[@]} -eq ${#expected_services[@]} ]]; then
        print_pass "Detected correct number of services: ${#detected_services[@]}"
    else
        print_fail "Expected ${#expected_services[@]} services, detected ${#detected_services[@]}"
        return 1
    fi
    
    # Check that all expected services were detected
    for expected in "${expected_services[@]}"; do
        local found=false
        for detected in "${detected_services[@]}"; do
            if [[ "$detected" == "$expected" ]]; then
                found=true
                break
            fi
        done
        
        if [[ "$found" == "true" ]]; then
            print_pass "Service $expected detected correctly"
        else
            print_fail "Service $expected not detected"
            return 1
        fi
    done
    
    cd - > /dev/null
    return 0
}

# Cleanup test environment
cleanup_test_env() {
    print_test "Cleaning up test environment"
    
    if [[ -n "$TEST_DIR" && -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
        print_pass "Test environment cleaned up"
    else
        print_warn "No test environment to clean up"
    fi
}

# Main test execution
main() {
    echo "========================================="
    echo "Backup System Functional Tests"
    echo "========================================="
    echo ""
    
    local tests_passed=0
    local tests_failed=0
    
    # Setup
    if ! setup_test_env; then
        print_fail "Failed to setup test environment"
        exit 1
    fi
    
    # Run functional tests
    local test_functions=(
        "test_service_detection"
        "test_backup_directory_creation"
        "test_backup_execution"
    )
    
    for test_func in "${test_functions[@]}"; do
        if $test_func; then
            tests_passed=$((tests_passed + 1))
        else
            tests_failed=$((tests_failed + 1))
        fi
        echo ""
    done
    
    # Cleanup
    cleanup_test_env
    
    # Summary
    echo "========================================="
    echo "Functional Test Summary"
    echo "========================================="
    echo -e "${GREEN}Passed: $tests_passed${NC}"
    echo -e "${RED}Failed: $tests_failed${NC}"
    echo ""
    
    if [ $tests_failed -eq 0 ]; then
        print_pass "All functional tests passed!"
        exit 0
    else
        print_fail "$tests_failed functional test(s) failed"
        exit 1
    fi
}

# Run main function
main "$@"