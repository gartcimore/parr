#!/bin/bash

# Main test runner for all infrastructure and configuration tests
# This script runs all test suites and provides a comprehensive report

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

print_header() {
    echo -e "${BOLD}${BLUE}=========================================${NC}"
    echo -e "${BOLD}${BLUE}$1${NC}"
    echo -e "${BOLD}${BLUE}=========================================${NC}"
}

print_suite() {
    echo -e "${BOLD}${YELLOW}>>> Running: $1${NC}"
}

print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ PASSED: $2${NC}"
    else
        echo -e "${RED}✗ FAILED: $2${NC}"
    fi
}

# Change to project root directory
cd "$(dirname "$0")/.."

print_header "Parr Media Server - Infrastructure & Configuration Tests"
echo ""

# Initialize counters
total_suites=0
passed_suites=0
failed_suites=0

# Test Suite 1: Environment Validation
print_suite "Environment Configuration Tests"
total_suites=$((total_suites + 1))
if ./tests/test-env-validation.sh; then
    passed_suites=$((passed_suites + 1))
    print_result 0 "Environment Configuration Tests"
else
    failed_suites=$((failed_suites + 1))
    print_result 1 "Environment Configuration Tests"
fi
echo ""

# Test Suite 2: Docker Compose Validation
print_suite "Docker Compose Configuration Tests"
total_suites=$((total_suites + 1))
if ./tests/test-docker-compose.sh; then
    passed_suites=$((passed_suites + 1))
    print_result 0 "Docker Compose Configuration Tests"
else
    failed_suites=$((failed_suites + 1))
    print_result 1 "Docker Compose Configuration Tests"
fi
echo ""

# Test Suite 3: Setup Scripts Validation
print_suite "Setup Scripts Tests"
total_suites=$((total_suites + 1))
if ./tests/test-setup-scripts.sh; then
    passed_suites=$((passed_suites + 1))
    print_result 0 "Setup Scripts Tests"
else
    failed_suites=$((failed_suites + 1))
    print_result 1 "Setup Scripts Tests"
fi
echo ""

# Test Suite 4: Backup System Tests
print_suite "Backup System Tests"
total_suites=$((total_suites + 1))
if ./tests/test-backup-system.sh; then
    passed_suites=$((passed_suites + 1))
    print_result 0 "Backup System Tests"
else
    failed_suites=$((failed_suites + 1))
    print_result 1 "Backup System Tests"
fi
echo ""

# Test Suite 5: Arr Configuration Generation Tests
print_suite "Arr Configuration Generation Tests"
total_suites=$((total_suites + 1))
if ./tests/test-generate-arr-configs.sh; then
    passed_suites=$((passed_suites + 1))
    print_result 0 "Arr Configuration Generation Tests"
else
    failed_suites=$((failed_suites + 1))
    print_result 1 "Arr Configuration Generation Tests"
fi
echo ""

# Final Summary
print_header "Test Results Summary"
echo ""
echo -e "${BOLD}Total Test Suites: $total_suites${NC}"
echo -e "${GREEN}${BOLD}Passed: $passed_suites${NC}"
echo -e "${RED}${BOLD}Failed: $failed_suites${NC}"
echo ""

if [ $failed_suites -eq 0 ]; then
    echo -e "${GREEN}${BOLD}🎉 All test suites passed! Your infrastructure configuration is solid.${NC}"
    echo ""
    echo -e "${BLUE}Your Parr media server configuration is ready for deployment!${NC}"
    exit 0
else
    echo -e "${RED}${BOLD}❌ $failed_suites test suite(s) failed.${NC}"
    echo ""
    echo -e "${YELLOW}Please review the failed tests above and fix the issues before deployment.${NC}"
    exit 1
fi