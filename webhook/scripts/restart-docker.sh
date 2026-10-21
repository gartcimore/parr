#!/bin/bash
# Restart the parr docker compose stack.
#
# PARR_COMPOSE_DIR is templated in by install.sh at install time so we know
# which compose file to target without parsing .env at runtime.
#
# The `docker compose -f <path> restart` invocation below must match the
# pinned command in webhook/sudoers/parr-webhook exactly, or sudo will reject
# it. Do not change one without the other.
set -e

COMPOSE_DIR="__PARR_COMPOSE_DIR__"
COMPOSE_FILE="$COMPOSE_DIR/docker-compose.yml"

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "compose file missing at $COMPOSE_FILE" >&2
    exit 1
fi

sudo /usr/bin/docker compose -f "$COMPOSE_FILE" restart
