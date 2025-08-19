#!/bin/bash

# Test script for environment validation
# This script validates .env file format and required variables

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

# Test 1: Check if .env.sample exists
test_env_sample_exists() {
    print_test "Checking if .env.sample exists"
    if [ -f ".env.sample" ]; then
        print_pass ".env.sample file found"
        return 0
    else
        print_fail ".env.sample file not found"
        return 1
    fi
}

# Test 2: Validate required variables in .env.sample
test_required_variables() {
    print_test "Validating required variables in .env.sample"
    
    local required_vars=(
        "TZ"
        "DATA_DIR" 
        "DOCKER_CONFIG_DIR"
        "HOSTNAME"
        "VPN_TYPE"
        "SERVER_COUNTRIES"
        "OPENVPN_USER"
        "OPENVPN_PASSWORD"
        "WIREGUARD_PRIVATE_KEY"
        "HOMARR_SECRET_KEY"
    )
    
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if ! grep -q "^${var}=" .env.sample; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -eq 0 ]; then
        print_pass "All required variables found in .env.sample"
        return 0
    else
        print_fail "Missing required variables: ${missing_vars[*]}"
        return 1
    fi
}

# Test 3: Validate .env file format
test_env_format() {
    print_test "Validating .env file format"
    
    # Check for invalid characters or format
    if grep -q $'[\t]' .env.sample; then
        print_warn "Found tabs in .env.sample, should use spaces"
    fi
    
    # Check for proper format (KEY=VALUE)
    if grep -v '^#' .env.sample | grep -v '^$' | grep -v '^[A-Z_][A-Z0-9_]*=' > /dev/null; then
        print_fail "Invalid format found in .env.sample"
        return 1
    fi
    
    print_pass ".env.sample format is valid"
    return 0
}

# Test 4: Check for placeholder values
test_placeholder_values() {
    print_test "Checking for proper placeholder values"
    
    local placeholders=(
        "your_username+pmp"
        "your_password"
        "your_wireguard_private_key_here"
        "your_hostname.local"
    )
    
    local found_placeholders=0
    
    for placeholder in "${placeholders[@]}"; do
        if grep -q "$placeholder" .env.sample; then
            found_placeholders=$((found_placeholders + 1))
        fi
    done
    
    if [ $found_placeholders -gt 0 ]; then
        print_pass "Found $found_placeholders placeholder values (good for template)"
    else
        print_warn "No placeholder values found - ensure .env.sample is a template"
    fi
    
    return 0
}

# Test 5: Validate timezone format
test_timezone_format() {
    print_test "Validating timezone format in .env.sample"
    
    local tz_value=$(grep "^TZ=" .env.sample | cut -d'=' -f2)
    
    # Basic timezone format validation (Area/City)
    if [[ $tz_value =~ ^[A-Z][a-z]+/[A-Z][a-z_]+$ ]]; then
        print_pass "Timezone format is valid: $tz_value"
        return 0
    else
        print_warn "Timezone format may be invalid: $tz_value"
        return 0  # Warning, not failure
    fi
}

# Test 6: Check VPN type values
test_vpn_type() {
    print_test "Validating VPN type configuration"
    
    local vpn_type=$(grep "^VPN_TYPE=" .env.sample | cut -d'=' -f2)
    
    if [[ "$vpn_type" == "wireguard" || "$vpn_type" == "openvpn" ]]; then
        print_pass "VPN type is valid: $vpn_type"
        return 0
    else
        print_fail "Invalid VPN type: $vpn_type (should be 'wireguard' or 'openvpn')"
        return 1
    fi
}

# Main test execution
main() {
    echo "========================================="
    echo "Environment Configuration Tests"
    echo "========================================="
    echo ""
    
    local tests_passed=0
    local tests_failed=0
    
    # Run all tests
    local test_functions=(
        "test_env_sample_exists"
        "test_required_variables"
        "test_env_format"
        "test_placeholder_values"
        "test_timezone_format"
        "test_vpn_type"
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
        print_pass "All environment configuration tests passed!"
        exit 0
    else
        print_fail "$tests_failed test(s) failed"
        exit 1
    fi
}

# Run main function
main "$@"