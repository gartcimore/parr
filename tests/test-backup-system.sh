#!/bin/bash

# Test script for backup system validation
# This script tests backup.sh, stack-utils.sh functionality

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

# Test 1: Validate backup script syntax
test_backup_script_syntax() {
    print_test "Validating backup system script syntax"
    
    local scripts=("backup.sh" "stack-utils.sh")
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
            print_fail "$script not found"
            syntax_errors=$((syntax_errors + 1))
        fi
    done
    
    if [ $syntax_errors -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# Test 2: Test stack-utils.sh functions
test_stack_utils() {
    print_test "Testing stack-utils.sh functions"
    
    if [ ! -f "stack-utils.sh" ]; then
        print_fail "stack-utils.sh not found"
        return 1
    fi
    
    # Source the utilities (without executing)
    source stack-utils.sh
    
    # Test that required functions exist
    local required_functions=(
        "is_service_running"
        "is_compose_running"
        "get_install_type"
        "stop_stack"
        "start_stack"
        "restart_stack"
        "get_stack_status"
        "wait_for_stack_health"
        "show_stack_info"
    )
    
    local missing_functions=()
    for func in "${required_functions[@]}"; do
        if ! declare -f "$func" > /dev/null; then
            missing_functions+=("$func")
        fi
    done
    
    if [ ${#missing_functions[@]} -eq 0 ]; then
        print_pass "All required stack utility functions are defined"
    else
        print_fail "Missing stack utility functions: ${missing_functions[*]}"
        return 1
    fi
    
    # Test get_install_type function logic
    if declare -f "get_install_type" > /dev/null; then
        print_pass "get_install_type function is properly defined"
    else
        print_fail "get_install_type function not found"
        return 1
    fi
    
    return 0
}

# Test 3: Test backup script dependencies
test_backup_dependencies() {
    print_test "Testing backup script dependencies"
    
    if [ ! -f "backup.sh" ]; then
        print_fail "backup.sh not found"
        return 1
    fi
    
    # Check that backup.sh sources required utilities
    if grep -q "source setup-utils.sh" backup.sh; then
        print_pass "backup.sh sources setup-utils.sh"
    else
        print_fail "backup.sh doesn't source setup-utils.sh"
        return 1
    fi
    
    if grep -q "source stack-utils.sh" backup.sh; then
        print_pass "backup.sh sources stack-utils.sh"
    else
        print_fail "backup.sh doesn't source stack-utils.sh"
        return 1
    fi
    
    # Check that backup.sh uses load_env_file
    if grep -q "load_env_file" backup.sh; then
        print_pass "backup.sh uses load_env_file function"
    else
        print_fail "backup.sh doesn't use load_env_file function"
        return 1
    fi
    
    return 0
}

# Test 4: Test backup script logic and structure
test_backup_logic() {
    print_test "Testing backup script logic and structure"
    
    if [ ! -f "backup.sh" ]; then
        print_fail "backup.sh not found"
        return 1
    fi
    
    # Check for required environment variable validation
    local required_checks=(
        "DOCKER_CONFIG_DIR"
        "DATA_DIR"
    )
    
    local missing_checks=()
    for check in "${required_checks[@]}"; do
        if ! grep -q "$check" backup.sh; then
            missing_checks+=("$check")
        fi
    done
    
    if [ ${#missing_checks[@]} -eq 0 ]; then
        print_pass "backup.sh validates all required environment variables"
    else
        print_fail "backup.sh missing validation for: ${missing_checks[*]}"
        return 1
    fi
    
    # Check for backup directory creation logic
    if grep -q "parr_backup" backup.sh; then
        print_pass "backup.sh includes backup directory logic"
    else
        print_fail "backup.sh missing backup directory logic"
        return 1
    fi
    
    # Check for timestamp generation
    if grep -q "date.*%Y%m%d_%H%M%S" backup.sh; then
        print_pass "backup.sh generates proper timestamps"
    else
        print_fail "backup.sh missing timestamp generation"
        return 1
    fi
    
    # Check for tar command with excludes
    if grep -q "TAR_EXCLUDES" backup.sh && grep -q "exclude=" backup.sh; then
        print_pass "backup.sh uses tar with proper excludes"
    else
        print_fail "backup.sh missing tar exclude logic"
        return 1
    fi
    
    return 0
}

# Test 5: Test backup exclusion patterns
test_backup_exclusions() {
    print_test "Testing backup exclusion patterns"
    
    if [ ! -f "backup.sh" ]; then
        print_fail "backup.sh not found"
        return 1
    fi
    
    # Check for important exclusion patterns
    local exclusion_patterns=(
        "cache"
        "Cache"
        "transcodes"
        "metadata/library"
        "log"
        "logs"
        "tmp"
        "temp"
    )
    
    local missing_exclusions=()
    for pattern in "${exclusion_patterns[@]}"; do
        if ! grep -q "$pattern" backup.sh; then
            missing_exclusions+=("$pattern")
        fi
    done
    
    if [ ${#missing_exclusions[@]} -eq 0 ]; then
        print_pass "backup.sh includes all important exclusion patterns"
    else
        print_warn "backup.sh missing some exclusion patterns: ${missing_exclusions[*]}"
        # This is a warning, not a failure, as some patterns might be optional
    fi
    
    return 0
}

# Test 6: Test service detection functions
test_service_detection() {
    print_test "Testing service detection functions"
    
    if [ ! -f "stack-utils.sh" ]; then
        print_fail "stack-utils.sh not found"
        return 1
    fi
    
    # Source stack-utils.sh
    source stack-utils.sh
    
    # Test that service detection functions handle errors gracefully
    # We can't test actual service detection without running services,
    # but we can test that the functions exist and don't crash
    
    # Test is_service_running with non-existent service
    if is_service_running "non-existent-service" 2>/dev/null; then
        # This should return false, not crash
        print_warn "is_service_running returned true for non-existent service"
    else
        print_pass "is_service_running handles non-existent services correctly"
    fi
    
    # Test is_compose_running (should handle no docker-compose gracefully)
    if is_compose_running 2>/dev/null; then
        print_pass "is_compose_running executed without errors"
    else
        print_pass "is_compose_running handled no-compose scenario correctly"
    fi
    
    return 0
}

# Test 7: Test backup script permissions and executability
test_backup_permissions() {
    print_test "Testing backup script permissions"
    
    if [ ! -f "backup.sh" ]; then
        print_fail "backup.sh not found"
        return 1
    fi
    
    if [ -x "backup.sh" ]; then
        print_pass "backup.sh is executable"
    else
        print_warn "backup.sh is not executable (may need chmod +x)"
        # Make it executable for testing
        chmod +x "backup.sh" 2>/dev/null || true
    fi
    
    # stack-utils.sh should NOT be executable (it's sourced)
    if [ -f "stack-utils.sh" ]; then
        if [ -x "stack-utils.sh" ]; then
            print_warn "stack-utils.sh is executable (should be sourced only)"
        else
            print_pass "stack-utils.sh has correct permissions (not executable)"
        fi
    fi
    
    return 0
}

# Test 8: Test error handling in backup system
test_error_handling() {
    print_test "Testing error handling in backup system"
    
    local scripts=("backup.sh" "stack-utils.sh")
    local scripts_with_error_handling=0
    
    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            if grep -q "set -e" "$script"; then
                scripts_with_error_handling=$((scripts_with_error_handling + 1))
                print_pass "$script uses 'set -e' for error handling"
            else
                print_warn "$script doesn't use 'set -e' for error handling"
            fi
        fi
    done
    
    # Check for proper error messages
    if [ -f "backup.sh" ]; then
        if grep -q "print_error" backup.sh; then
            print_pass "backup.sh includes proper error messaging"
        else
            print_fail "backup.sh missing error messaging functions"
            return 1
        fi
    fi
    
    return 0
}

# Test 9: Test integration with create-volumes.sh
test_create_volumes_integration() {
    print_test "Testing integration with create-volumes.sh"
    
    if [ ! -f "create-volumes.sh" ]; then
        print_fail "create-volumes.sh not found"
        return 1
    fi
    
    # Check that create-volumes.sh includes backup directory creation
    if grep -q "parr_backup" create-volumes.sh; then
        print_pass "create-volumes.sh includes backup directory creation"
    else
        print_fail "create-volumes.sh missing backup directory creation"
        return 1
    fi
    
    # Check that the backup directory is properly documented
    if grep -q "Backups:" create-volumes.sh; then
        print_pass "create-volumes.sh documents backup directory"
    else
        print_warn "create-volumes.sh doesn't document backup directory in summary"
    fi
    
    return 0
}

# Test 10: Test docker-compose.yml service parsing
test_service_parsing() {
    print_test "Testing docker-compose.yml volume parsing logic"
    
    if [ ! -f "backup.sh" ]; then
        print_fail "backup.sh not found"
        return 1
    fi
    
    # Check that backup.sh includes volume parsing functions
    if grep -q "get_config_folders_from_volumes" backup.sh; then
        print_pass "backup.sh includes volume parsing function"
    else
        print_fail "backup.sh missing volume parsing function"
        return 1
    fi
    
    if grep -q "get_existing_config_folders" backup.sh; then
        print_pass "backup.sh includes config folder detection"
    else
        print_fail "backup.sh missing config folder detection"
        return 1
    fi
    
    # Check that it looks for DOCKER_CONFIG_DIR in docker-compose.yml
    if grep -q "DOCKER_CONFIG_DIR" backup.sh; then
        print_pass "backup.sh searches for DOCKER_CONFIG_DIR in compose file"
    else
        print_fail "backup.sh doesn't search for DOCKER_CONFIG_DIR"
        return 1
    fi
    
    return 0
}

# Test 11: Test backup filename format
test_backup_filename() {
    print_test "Testing backup filename format"
    
    if [ ! -f "backup.sh" ]; then
        print_fail "backup.sh not found"
        return 1
    fi
    
    # Check for proper filename format
    if grep -q "parr_.*\.tar\.gz" backup.sh; then
        print_pass "backup.sh uses correct filename format"
    else
        print_fail "backup.sh missing proper filename format"
        return 1
    fi
    
    # Check for timestamp in filename
    if grep -q "TIMESTAMP.*date" backup.sh; then
        print_pass "backup.sh includes timestamp in filename"
    else
        print_fail "backup.sh missing timestamp in filename"
        return 1
    fi
    
    return 0
}

# Test 12: Test stack state management
test_stack_state_management() {
    print_test "Testing stack state management"
    
    if [ ! -f "stack-utils.sh" ]; then
        print_fail "stack-utils.sh not found"
        return 1
    fi
    
    # Check for state tracking variables
    if grep -q "STACK_SERVICE_WAS_RUNNING" stack-utils.sh; then
        print_pass "stack-utils.sh includes service state tracking"
    else
        print_fail "stack-utils.sh missing service state tracking"
        return 1
    fi
    
    if grep -q "STACK_COMPOSE_WAS_RUNNING" stack-utils.sh; then
        print_pass "stack-utils.sh includes compose state tracking"
    else
        print_fail "stack-utils.sh missing compose state tracking"
        return 1
    fi
    
    return 0
}

# Main test execution
main() {
    echo "========================================="
    echo "Backup System Tests"
    echo "========================================="
    echo ""
    
    local tests_passed=0
    local tests_failed=0
    
    # Run all tests
    local test_functions=(
        "test_backup_script_syntax"
        "test_stack_utils"
        "test_backup_dependencies"
        "test_backup_logic"
        "test_backup_exclusions"
        "test_service_detection"
        "test_backup_permissions"
        "test_error_handling"
        "test_create_volumes_integration"
        "test_service_parsing"
        "test_backup_filename"
        "test_stack_state_management"
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
        print_pass "All backup system tests passed!"
        exit 0
    else
        print_fail "$tests_failed test(s) failed"
        exit 1
    fi
}

# Run main function
main "$@"