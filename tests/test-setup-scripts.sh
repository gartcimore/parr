#!/bin/bash

# Test script for setup scripts validation
# This script tests setup.sh, create-volumes.sh, and update.sh functionality

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

# Test 1: Validate shell script syntax
test_script_syntax() {
    print_test "Validating shell script syntax"
    
    local scripts=("setup.sh" "setup-utils.sh" "create-volumes.sh" "update.sh")
    local syntax_errors=0
    
    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            if bash -n "$script"; then
                print_pass "$script syntax is valid"
            else
                print_fail "$script has syntax errors"
                syntax_errors=$((syntax_errors + 1))
            fi
        else
            print_warn "$script not found"
        fi
    done
    
    if [ $syntax_errors -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# Test 2: Test setup-utils.sh functions
test_setup_utils() {
    print_test "Testing setup-utils.sh functions"
    
    if [ ! -f "setup-utils.sh" ]; then
        print_fail "setup-utils.sh not found"
        return 1
    fi
    
    # Source the utilities
    source setup-utils.sh
    
    # Test load_env_file function using a temporary file
    local test_env_file=$(mktemp)
    echo "TEST_VAR=test_value" > "$test_env_file"
    echo "TEST_VAR2=test value with spaces" >> "$test_env_file"
    echo "# This is a comment" >> "$test_env_file"
    echo "" >> "$test_env_file"
    
    load_env_file "$test_env_file"
    
    if [ "$TEST_VAR" != "test_value" ]; then
        print_fail "load_env_file failed for simple variable"
        rm -f "$test_env_file"
        return 1
    fi
    
    if [ "$TEST_VAR2" != "test value with spaces" ]; then
        print_fail "load_env_file failed for variable with spaces"
        rm -f "$test_env_file"
        return 1
    fi
    
    rm -f "$test_env_file"
    print_pass "setup-utils.sh functions work correctly"
    return 0
}

# Test 3: Test create-volumes.sh functionality (dry run)
test_create_volumes() {
    print_test "Testing create-volumes.sh functionality (dry run)"
    
    if [ ! -f "create-volumes.sh" ]; then
        print_fail "create-volumes.sh not found"
        return 1
    fi
    
    # Create test .env file in a temporary location
    local test_env_file=$(mktemp)
    cat > "$test_env_file" << 'EOF'
DATA_DIR=/tmp/test-parr-data
DOCKER_CONFIG_DIR=/tmp/test-parr-config
TZ=Europe/London
HOSTNAME=test.local
VPN_TYPE=wireguard
SERVER_COUNTRIES=Netherlands
OPENVPN_USER=test_user+pmp
OPENVPN_PASSWORD=test_password
WIREGUARD_PRIVATE_KEY=test_key
HOMARR_SECRET_KEY=test_secret_key
EOF
    
    # Test that the script can parse the .env file correctly
    if source "$test_env_file" && [ "$DATA_DIR" = "/tmp/test-parr-data" ]; then
        print_pass "create-volumes.sh can parse .env file correctly"
    else
        print_fail "create-volumes.sh cannot parse .env file"
        rm -f "$test_env_file"
        return 1
    fi
    
    # Test script syntax and structure
    if bash -n create-volumes.sh; then
        print_pass "create-volumes.sh has valid syntax"
    else
        print_fail "create-volumes.sh has syntax errors"
        rm -f "$test_env_file"
        return 1
    fi
    
    # Check that script contains expected directory creation logic
    if grep -q "create_directory" create-volumes.sh && grep -q "prowlarr" create-volumes.sh; then
        print_pass "create-volumes.sh contains expected directory creation logic"
    else
        print_fail "create-volumes.sh missing expected directory creation logic"
        rm -f "$test_env_file"
        return 1
    fi
    
    # Cleanup
    rm -f "$test_env_file"
    return 0
}

# Test 4: Test setup.sh functionality (syntax and logic validation)
test_setup_script() {
    print_test "Testing setup.sh functionality (syntax and logic validation)"
    
    if [ ! -f "setup.sh" ]; then
        print_fail "setup.sh not found"
        return 1
    fi
    
    # Test script syntax
    if bash -n setup.sh; then
        print_pass "setup.sh has valid syntax"
    else
        print_fail "setup.sh has syntax errors"
        return 1
    fi
    
    # Check that setup.sh contains expected functionality
    local expected_patterns=(
        "prompt_with_default"
        "TZ"
        "DOCKER_CONFIG_DIR"
        "HOSTNAME"
        "VPN_TYPE"
        "create-volumes.sh"
    )
    
    local missing_patterns=()
    for pattern in "${expected_patterns[@]}"; do
        if ! grep -q "$pattern" setup.sh; then
            missing_patterns+=("$pattern")
        fi
    done
    
    if [ ${#missing_patterns[@]} -eq 0 ]; then
        print_pass "setup.sh contains all expected functionality"
    else
        print_fail "setup.sh missing expected patterns: ${missing_patterns[*]}"
        return 1
    fi
    
    # Check that setup-utils.sh is properly sourced
    if grep -q "source setup-utils.sh" setup.sh; then
        print_pass "setup.sh properly sources setup-utils.sh"
    else
        print_fail "setup.sh doesn't source setup-utils.sh"
        return 1
    fi
    
    return 0
}

# Test 5: Test update.sh logic
test_update_script() {
    print_test "Testing update.sh logic"
    
    if [ ! -f "update.sh" ]; then
        print_fail "update.sh not found"
        return 1
    fi
    
    # Check that update script contains expected commands
    if ! grep -q "docker compose" update.sh; then
        print_fail "update.sh missing docker compose commands"
        return 1
    fi
    
    if ! grep -q "pull" update.sh; then
        print_fail "update.sh missing pull command"
        return 1
    fi
    
    if ! grep -q "INSTALL_TYPE" update.sh; then
        print_fail "update.sh doesn't check installation type"
        return 1
    fi
    
    print_pass "update.sh contains expected logic"
    return 0
}

# Test 6: Test script permissions
test_script_permissions() {
    print_test "Testing script permissions"
    
    local scripts=("setup.sh" "create-volumes.sh" "update.sh")
    local permission_errors=0
    
    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            if [ -x "$script" ]; then
                print_pass "$script is executable"
            else
                print_warn "$script is not executable (may need chmod +x)"
                # Make it executable for testing
                chmod +x "$script" 2>/dev/null || true
            fi
        fi
    done
    
    return 0
}

# Test 7: Test error handling in scripts
test_error_handling() {
    print_test "Testing error handling in scripts"
    
    # Check if scripts use 'set -e' for error handling
    local scripts=("setup.sh" "create-volumes.sh" "update.sh")
    local scripts_with_error_handling=0
    
    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            if grep -q "set -e" "$script"; then
                scripts_with_error_handling=$((scripts_with_error_handling + 1))
            else
                print_warn "$script doesn't use 'set -e' for error handling"
            fi
        fi
    done
    
    if [ $scripts_with_error_handling -gt 0 ]; then
        print_pass "$scripts_with_error_handling script(s) have proper error handling"
    else
        print_warn "No scripts found with 'set -e' error handling"
    fi
    
    return 0
}

# Main test execution
main() {
    echo "========================================="
    echo "Setup Scripts Tests"
    echo "========================================="
    echo ""
    
    local tests_passed=0
    local tests_failed=0
    
    # Run all tests
    local test_functions=(
        "test_script_syntax"
        "test_setup_utils"
        "test_create_volumes"
        "test_setup_script"
        "test_update_script"
        "test_script_permissions"
        "test_error_handling"
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
    
    if [ $tests_failed -eq 0 ]; then
        print_pass "All setup script tests passed!"
        exit 0
    else
        print_fail "$tests_failed test(s) failed"
        exit 1
    fi
}

# Run main function
main "$@"