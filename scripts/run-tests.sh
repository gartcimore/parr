#!/bin/bash

# Containerized test runner script
# This script runs tests in Docker containers with mounted volumes for inspection

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

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to clean up test output directory
cleanup_test_output() {
    if [ -d "test-output" ]; then
        print_info "Cleaning up previous test output..."
        rm -rf test-output
    fi
    mkdir -p test-output/{config,data,setup-config,setup-data,validation,compose,setup}
}

# Function to run a specific test service
run_test_service() {
    local service_name="$1"
    local description="$2"
    
    print_header "$description"
    
    if docker-compose -f docker-compose.test.yml run --rm "$service_name"; then
        print_success "$description completed successfully"
        return 0
    else
        print_error "$description failed"
        return 1
    fi
}

# Function to inspect test output
inspect_test_output() {
    print_header "Test Output Inspection"
    
    if [ -d "test-output" ]; then
        echo -e "${BLUE}Test output directory structure:${NC}"
        find test-output -type f -o -type d | sort | sed 's/^/  /'
        
        echo ""
        echo -e "${BLUE}Directory sizes:${NC}"
        du -sh test-output/* 2>/dev/null | sed 's/^/  /' || echo "  No output directories found"
        
        # Show created directories from setup tests
        if [ -d "test-output/setup-config" ] && [ "$(ls -A test-output/setup-config 2>/dev/null)" ]; then
            echo ""
            echo -e "${BLUE}Created config directories:${NC}"
            find test-output/setup-config -type d | sed 's/^/  /'
        fi
        
        if [ -d "test-output/setup-data" ] && [ "$(ls -A test-output/setup-data 2>/dev/null)" ]; then
            echo ""
            echo -e "${BLUE}Created data directories:${NC}"
            find test-output/setup-data -type d | sed 's/^/  /'
        fi
    else
        print_warning "No test output directory found"
    fi
}

# Function to build test image
build_test_image() {
    print_header "Building Test Container Image"
    
    if docker-compose -f docker-compose.test.yml build; then
        print_success "Test image built successfully"
        return 0
    else
        print_error "Failed to build test image"
        return 1
    fi
}

# Main function
main() {
    local test_type="${1:-all}"
    local failed_tests=0
    
    print_header "Parr Media Server - Containerized Testing"
    echo ""
    
    # Check if Docker is available
    if ! command -v docker >/dev/null 2>&1; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v docker-compose >/dev/null 2>&1; then
        print_error "Docker Compose is not installed or not in PATH"
        exit 1
    fi
    
    # Clean up and prepare
    cleanup_test_output
    
    # Build test image
    if ! build_test_image; then
        exit 1
    fi
    
    case "$test_type" in
        "all")
            print_info "Running all tests in containers..."
            
            # Run individual test suites
            run_test_service "test-validation" "Environment Validation Tests" || failed_tests=$((failed_tests + 1))
            run_test_service "test-compose" "Docker Compose Tests" || failed_tests=$((failed_tests + 1))
            run_test_service "test-setup" "Setup Scripts Tests" || failed_tests=$((failed_tests + 1))
            
            # Run comprehensive test suite
            run_test_service "test-runner" "Comprehensive Test Suite" || failed_tests=$((failed_tests + 1))
            ;;
        "validation")
            run_test_service "test-validation" "Environment Validation Tests" || failed_tests=$((failed_tests + 1))
            ;;
        "compose")
            run_test_service "test-compose" "Docker Compose Tests" || failed_tests=$((failed_tests + 1))
            ;;
        "setup")
            run_test_service "test-setup" "Setup Scripts Tests" || failed_tests=$((failed_tests + 1))
            ;;
        "full")
            run_test_service "test-runner" "Comprehensive Test Suite" || failed_tests=$((failed_tests + 1))
            ;;
        *)
            echo "Usage: $0 [all|validation|compose|setup|full]"
            echo ""
            echo "Test types:"
            echo "  all        - Run all individual test suites + comprehensive suite"
            echo "  validation - Run only environment validation tests"
            echo "  compose    - Run only Docker Compose tests"
            echo "  setup      - Run only setup script tests"
            echo "  full       - Run only the comprehensive test suite"
            exit 1
            ;;
    esac
    
    # Inspect test output
    inspect_test_output
    
    # Summary
    print_header "Test Results Summary"
    
    if [ $failed_tests -eq 0 ]; then
        print_success "All tests passed! 🎉"
        echo ""
        echo -e "${GREEN}Your Parr media server configuration is ready for deployment.${NC}"
        echo -e "${BLUE}Check the test-output/ directory for created files and directories.${NC}"
    else
        print_error "$failed_tests test suite(s) failed"
        echo ""
        echo -e "${YELLOW}Please review the test output above and check the test-output/ directory.${NC}"
        exit 1
    fi
}

# Cleanup function for script exit
cleanup() {
    print_info "Cleaning up containers..."
    docker-compose -f docker-compose.test.yml down --remove-orphans 2>/dev/null || true
}

# Set trap for cleanup
trap cleanup EXIT

# Run main function
main "$@"