#!/bin/bash
# Power off the host.
#
# Detached with setsid so the delayed poweroff survives the webhook hook's
# process group being torn down when this script returns. The short delay lets
# the HTTP response reach the caller first. `/sbin/poweroff` must match the
# sudoers grant.
set -e

setsid nohup bash -c 'sleep 3; sudo /sbin/poweroff' \
    >/dev/null 2>&1 < /dev/null &
disown
exit 0
