#!/bin/bash
# Reboot the host.
#
# Detached with setsid so the delayed reboot survives the webhook hook's process
# group being torn down when this script returns. The short delay lets the HTTP
# response reach the caller first. `/sbin/reboot` must match the sudoers grant.
set -e

setsid nohup bash -c 'sleep 3; sudo /sbin/reboot' \
    >/dev/null 2>&1 < /dev/null &
disown
exit 0
