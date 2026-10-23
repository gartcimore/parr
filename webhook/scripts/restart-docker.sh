#!/bin/bash
# Restart the Docker daemon on the host.
#
# This restarts the docker.service (the whole engine), not a single compose
# project — Homarr's Docker integration can already start/stop/restart
# individual containers, but it cannot bounce the daemon itself. That host-level
# action is what this webhook provides.
#
# NOTE: restarting dockerd stops and restarts EVERY container on the host, not
# just the parr stack. The webhook daemon runs on the host (systemd), not in a
# container, so it survives the restart and can still return its HTTP response.
#
# The `systemctl restart docker` invocation must match the pinned command in
# webhook/sudoers/parr-webhook exactly, or sudo will reject it. Do not change
# one without the other.
set -e

# Run in the background with a tiny delay so the HTTP response reaches the
# caller before the docker restart tears down the Traefik container in its path.
( sleep 2 && sudo /usr/bin/systemctl restart docker ) >/dev/null 2>&1 &
disown
exit 0
