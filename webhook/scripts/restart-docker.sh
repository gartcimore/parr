#!/bin/bash
# Restart the parr docker compose stack.
#
# PARR_COMPOSE_DIR is templated in by install.sh at install time so we know
# which compose file to target without parsing .env at runtime.
set -e

COMPOSE_DIR="__PARR_COMPOSE_DIR__"

if [ ! -f "$COMPOSE_DIR/docker-compose.yml" ]; then
    echo "compose file missing at $COMPOSE_DIR/docker-compose.yml" >&2
    exit 1
fi

cd "$COMPOSE_DIR"
sudo /usr/bin/docker compose restart
