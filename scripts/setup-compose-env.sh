#!/bin/bash

# Helper script to detect and set up Docker Compose command
# This script exports COMPOSE_CMD environment variable for use in CI/CD

set -e

# Function to detect and use the correct Docker Compose command
detect_compose_cmd() {
    if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        echo "docker compose"
    elif command -v docker-compose >/dev/null 2>&1; then
        echo "docker-compose"
    else
        echo ""
    fi
}

# Get the compose command
COMPOSE_CMD=$(detect_compose_cmd)

if [ -z "$COMPOSE_CMD" ]; then
    echo "Error: Neither 'docker compose' nor 'docker-compose' is available"
    exit 1
fi

echo "Detected Docker Compose command: $COMPOSE_CMD"
echo "COMPOSE_CMD=$COMPOSE_CMD" >> $GITHUB_ENV