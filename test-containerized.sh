#!/bin/bash

# Simple containerized test runner
# This script demonstrates how to run tests in containers with volume inspection

set -e

echo "🐳 Running Parr Media Server Tests in Containers"
echo "================================================"
echo ""

# Clean up any existing test output
if [ -d "test-output" ]; then
    echo "🧹 Cleaning up previous test output..."
    rm -rf test-output
fi

# Create test output directory
mkdir -p test-output

echo "🔨 Building test container..."
docker-compose -f docker-compose.test.yml build --quiet

echo ""
echo "🧪 Running Environment Validation Tests..."
docker-compose -f docker-compose.test.yml run --rm test-validation

echo ""
echo "🐋 Running Docker Compose Tests..."
docker-compose -f docker-compose.test.yml run --rm test-compose

echo ""
echo "⚙️  Running Setup Scripts Tests..."
docker-compose -f docker-compose.test.yml run --rm test-setup

echo ""
echo "📊 Test Results Summary:"
echo "========================"

# Show created directories
if [ -d "test-output" ]; then
    echo "📁 Created test directories:"
    find test-output -type d 2>/dev/null | sort | sed 's/^/   /'
    
    echo ""
    echo "📄 Created test files:"
    find test-output -type f 2>/dev/null | sort | sed 's/^/   /'
    
    echo ""
    echo "💾 Directory sizes:"
    du -sh test-output/* 2>/dev/null | sed 's/^/   /' || echo "   No output found"
else
    echo "❌ No test output directory found"
fi

echo ""
echo "✅ Containerized testing complete!"
echo "🔍 Check the test-output/ directory to inspect created files and directories"

# Cleanup containers
docker-compose -f docker-compose.test.yml down --remove-orphans 2>/dev/null || true