#!/bin/bash

# parr-webhook installer
# Idempotent. Run from the parr project root: `sudo ./webhook/install.sh`
#
# Installs the adnanh/webhook daemon as a non-privileged systemd service that
# exposes a small set of host-level actions (reboot, shutdown, restart docker
# stack) gated by a shared token. See webhook/README.md for details.

set -euo pipefail

# ---------- pretty output ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}$*${NC}"; }
ok()    { echo -e "${GREEN}$*${NC}"; }
warn()  { echo -e "${YELLOW}$*${NC}"; }
fail()  { echo -e "${RED}$*${NC}" >&2; }

# ---------- preflight ----------
if [ "$(id -u)" -ne 0 ]; then
    fail "install.sh must be run as root (try: sudo $0)"
    exit 1
fi

# Resolve paths relative to the script so it works regardless of cwd.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PARR_DIR="$(cd -- "$SCRIPT_DIR/.." &>/dev/null && pwd)"
ENV_FILE="$PARR_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
    fail ".env not found at $ENV_FILE"
    fail "Run ./setup.sh from the parr project root first."
    exit 1
fi

# ---------- load .env (just the two vars we care about) ----------
WEBHOOK_TOKEN="$(grep -E '^WEBHOOK_TOKEN=' "$ENV_FILE" | head -1 | cut -d= -f2- | tr -d '"'"'")"
WEBHOOK_PORT="$(grep -E '^WEBHOOK_PORT=' "$ENV_FILE" | head -1 | cut -d= -f2- | tr -d '"'"'")"
WEBHOOK_PORT="${WEBHOOK_PORT:-9000}"

if [ -z "$WEBHOOK_TOKEN" ] || [ "$WEBHOOK_TOKEN" = "your_webhook_token_here" ]; then
    fail "WEBHOOK_TOKEN is missing or unset in $ENV_FILE"
    fail "Re-run ./setup.sh or set it manually to a 64-char hex string."
    exit 1
fi

# ---------- destination paths ----------
SERVICE_USER="parr-webhook"
ETC_DIR="/etc/parr-webhook"
HOOKS_FILE="$ETC_DIR/hooks.json"
BIN_DIR="/usr/local/bin"
SUDOERS_FILE="/etc/sudoers.d/parr-webhook"
SUDOERS_TMP="$(mktemp)"
SYSTEMD_UNIT="/etc/systemd/system/parr-webhook.service"

cleanup() { rm -f "$SUDOERS_TMP"; }
trap cleanup EXIT

# ---------- step 1: webhook binary ----------
info "==> ensuring webhook binary is installed"
if ! command -v webhook >/dev/null 2>&1; then
    if command -v apt-get >/dev/null 2>&1; then
        info "    installing via apt"
        DEBIAN_FRONTEND=noninteractive apt-get update -qq
        DEBIAN_FRONTEND=noninteractive apt-get install -y webhook >/dev/null
    else
        fail "    webhook binary not found and apt-get unavailable."
        fail "    Install it manually from https://github.com/adnanh/webhook/releases"
        fail "    Place the binary at /usr/bin/webhook and re-run this script."
        exit 1
    fi
fi
ok "    webhook: $(command -v webhook)"

# ---------- step 2: service user ----------
info "==> ensuring service user '$SERVICE_USER' exists"
if ! id -u "$SERVICE_USER" >/dev/null 2>&1; then
    useradd --system --shell /usr/sbin/nologin --no-create-home "$SERVICE_USER"
    ok "    created"
else
    ok "    already exists"
fi

# ---------- step 3: hooks.json ----------
info "==> rendering hooks.json"
install -d -m 0750 -o root -g "$SERVICE_USER" "$ETC_DIR"
# sed with a non-/ delimiter because the token is hex-only, but defensive.
sed "s|__WEBHOOK_TOKEN__|${WEBHOOK_TOKEN}|g" \
    "$SCRIPT_DIR/hooks.json.template" > "$HOOKS_FILE"
chown root:"$SERVICE_USER" "$HOOKS_FILE"
chmod 0640 "$HOOKS_FILE"
ok "    wrote $HOOKS_FILE (mode 0640)"

# ---------- step 4: action scripts ----------
info "==> installing action scripts to $BIN_DIR"
install -m 0755 "$SCRIPT_DIR/scripts/reboot.sh"   "$BIN_DIR/parr-webhook-reboot"
install -m 0755 "$SCRIPT_DIR/scripts/shutdown.sh" "$BIN_DIR/parr-webhook-shutdown"

# restart-docker needs the compose dir templated in
sed "s|__PARR_COMPOSE_DIR__|${PARR_DIR}|g" \
    "$SCRIPT_DIR/scripts/restart-docker.sh" > "$BIN_DIR/parr-webhook-restart-docker"
chmod 0755 "$BIN_DIR/parr-webhook-restart-docker"
ok "    parr-webhook-reboot, parr-webhook-shutdown, parr-webhook-restart-docker"

# ---------- step 5: sudoers drop-in ----------
info "==> installing sudoers drop-in"
cp "$SCRIPT_DIR/sudoers/parr-webhook" "$SUDOERS_TMP"
chmod 0440 "$SUDOERS_TMP"
if visudo -cf "$SUDOERS_TMP" >/dev/null; then
    install -m 0440 -o root -g root "$SUDOERS_TMP" "$SUDOERS_FILE"
    ok "    wrote $SUDOERS_FILE"
else
    fail "    sudoers file failed visudo validation. Aborting."
    exit 1
fi

# ---------- step 6: systemd unit ----------
info "==> installing systemd unit"
sed "s|__WEBHOOK_PORT__|${WEBHOOK_PORT}|g" \
    "$SCRIPT_DIR/systemd/parr-webhook.service" > "$SYSTEMD_UNIT"
chmod 0644 "$SYSTEMD_UNIT"
systemctl daemon-reload
systemctl enable parr-webhook.service >/dev/null 2>&1
systemctl restart parr-webhook.service
sleep 1

if systemctl is-active --quiet parr-webhook.service; then
    ok "    parr-webhook.service is active on port $WEBHOOK_PORT"
else
    fail "    parr-webhook.service failed to start. Check: journalctl -u parr-webhook -n 50"
    exit 1
fi

# ---------- summary ----------
echo
ok "============================================="
ok "parr-webhook installed."
ok "============================================="
cat <<EOF

Test locally:
  curl -X POST -H "X-Auth-Token: \$WEBHOOK_TOKEN" \\
       http://localhost:${WEBHOOK_PORT}/webhook/reboot

After Traefik picks up the new dynamic config and docker-compose.yml has
\`extra_hosts: host-gateway\` on traefik (run \`docker compose up -d traefik\`):

  curl -X POST -H "X-Auth-Token: \$WEBHOOK_TOKEN" \\
       http://\${HOSTNAME}/webhook/reboot

Add a Homarr Custom Widget pointing at the same URL with the X-Auth-Token
header to wire it into the dashboard.
EOF
