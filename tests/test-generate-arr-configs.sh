#!/bin/bash

# Test script for generate-arr-configs.sh
# Tests the arr* configuration generation functionality

# Get the directory of this script
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source the script to test using absolute path
source "$PROJECT_ROOT/generate-arr-configs.sh"

# Test configuration
TEST_CONFIG_DIR="/tmp/test-arr-configs"
TEST_DATA_DIR="/tmp/test-data"

# Test counter
TESTS_RUN=0
TESTS_PASSED=0

# Helper functions
print_test_header() {
    echo "=== $1 ==="
}

print_success() {
    echo "✓ $1"
}

print_error() {
    echo "✗ $1"
}

print_info() {
    echo "ℹ $1"
}

run_test() {
    TESTS_RUN=$((TESTS_RUN + 1))
    if eval "$1"; then
        print_success "$2"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        print_error "$2"
    fi
}

# Setup test environment
setup_test_env() {
    print_test_header "Setting up test environment"
    
    # Clean up any existing test directories
    rm -rf "$TEST_CONFIG_DIR" "$TEST_DATA_DIR"
    
    # Create test directories
    mkdir -p "$TEST_CONFIG_DIR"
    mkdir -p "$TEST_DATA_DIR"
    
    # Set required environment variables
    export DOCKER_CONFIG_DIR="$TEST_CONFIG_DIR"
    export DATA_DIR="$TEST_DATA_DIR"
    export DELETE_AFTER_SEED="false"
    
    print_info "Test environment created at $TEST_CONFIG_DIR"
}

# Test generate_arr_base_config function
test_generate_arr_base_config() {
    print_test_header "Testing generate_arr_base_config function"
    
    local api_key
    api_key=$(generate_arr_base_config "sonarr" "8989")
    
    run_test "[ -n \"$api_key\" ]" "API key generated"
    run_test "[ ${#api_key} -eq 64 ]" "API key has correct length (64 characters)"
    run_test "[ -f \"$TEST_CONFIG_DIR/sonarr/config.xml\" ]" "Config.xml file created"
    run_test "grep -q \"<ApiKey>$api_key</ApiKey>\" \"$TEST_CONFIG_DIR/sonarr/config.xml\"" "API key present in config.xml"
    run_test "grep -q \"<Port>8989</Port>\" \"$TEST_CONFIG_DIR/sonarr/config.xml\"" "Port configured correctly"
    run_test "grep -q \"<UrlBase>/sonarr</UrlBase>\" \"$TEST_CONFIG_DIR/sonarr/config.xml\"" "URL base configured correctly"
}

# Test generate_arr_configs function
test_generate_arr_configs() {
    print_test_header "Testing generate_arr_configs function"
    
    local api_key
    api_key=$(generate_arr_configs "radarr" "7878" "movies" "$TEST_DATA_DIR/media/movies")
    
    run_test "[ -n \"$api_key\" ]" "API key generated"
    run_test "[ -f \"$TEST_CONFIG_DIR/radarr/config.xml\" ]" "Base config.xml created"
    run_test "[ -f \"$TEST_CONFIG_DIR/radarr/config/mediamanagement.json\" ]" "Media management config created"
    run_test "[ -f \"$TEST_CONFIG_DIR/radarr/config/downloadclient.json\" ]" "Download client config created"
    run_test "grep -q \"\\\"defaultRootFolderPath\\\": \\\"$TEST_DATA_DIR/media/movies\\\"\" \"$TEST_CONFIG_DIR/radarr/config/mediamanagement.json\"" "Root folder path configured"
    run_test "grep -q \"\\\"category\\\": \\\"movies\\\"\" \"$TEST_CONFIG_DIR/radarr/config/downloadclient.json\"" "Download category configured"
}

# Cleanup test environment
cleanup_test_env() {
    print_test_header "Cleaning up test environment"
    rm -rf "$TEST_CONFIG_DIR" "$TEST_DATA_DIR"
    print_info "Test environment cleaned up"
}

# Main test execution
main() {
    echo "Starting generate-arr-configs.sh tests"
    echo ""
    
    setup_test_env
    test_generate_arr_base_config
    test_generate_arr_configs
    cleanup_test_env
    
    echo ""
    echo "=== Test Results ==="
    echo "Tests run: $TESTS_RUN"
    echo "Tests passed: $TESTS_PASSED"
    echo "Tests failed: $((TESTS_RUN - TESTS_PASSED))"
    
    if [ $TESTS_PASSED -eq $TESTS_RUN ]; then
        echo "All tests passed!"
        exit 0
    else
        echo "Some tests failed!"
        exit 1
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi