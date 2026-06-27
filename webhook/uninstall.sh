#!/bin/bash

# parr-webhook uninstaller
# Removes the systemd service, user, sudoers drop-in, scripts, and config.
# Does NOT touch Traefik dynamic config or .env.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}$*${NC}"; }
ok()   { echo -e "${GREEN}$*${NC}"; }
fail() { echo -e "${RED}$*${NC}" >&2; }

if [ "$(id -u)" -ne 0 ]; then
    fail "uninstall.sh must be run as root (try: sudo $0)"
    exit 1
fi

info "==> stopping and disabling parr-webhook.service"
systemctl stop parr-webhook.service 2>/dev/null || true
systemctl disable parr-webhook.service 2>/dev/null || true
rm -f /etc/systemd/system/parr-webhook.service
systemctl daemon-reload
ok "    done"

info "==> removing scripts"
rm -f /usr/local/bin/parr-webhook-reboot \
      /usr/local/bin/parr-webhook-shutdown \
      /usr/local/bin/parr-webhook-restart-docker
ok "    done"

info "==> removing config"
rm -rf /etc/parr-webhook
ok "    done"

info "==> removing sudoers drop-in"
rm -f /etc/sudoers.d/parr-webhook
ok "    done"

info "==> removing service user"
if id -u parr-webhook >/dev/null 2>&1; then
    userdel parr-webhook 2>/dev/null || true
fi
ok "    done"

echo
ok "parr-webhook uninstalled."
echo "Note: the Traefik dynamic config at traefik/dynamic/webhook.yml is NOT"
echo "removed automatically. Delete it if you also want to drop the"
echo "/webhook/* route from Traefik."
