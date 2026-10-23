#!/bin/bash
# Restart the Docker daemon on the host.
#
# This restarts docker.service (the whole engine), not a single compose project
# — Homarr can already restart individual containers, but not the daemon itself.
#
# NOTE: restarting dockerd stops and restarts EVERY container on the host. The
# webhook daemon runs on the host (systemd), not in a container, so it survives.
#
# The actual restart is detached with setsid so it survives the webhook hook's
# process group being torn down when this script returns. A short delay lets the
# HTTP 200 response reach the caller before dockerd (and the Traefik container)
# bounce. `systemctl restart docker` must match the sudoers grant exactly.
set -e

setsid nohup bash -c 'sleep 2; sudo /usr/bin/systemctl restart docker' \
    >/dev/null 2>&1 < /dev/null &
disown
exit 0
