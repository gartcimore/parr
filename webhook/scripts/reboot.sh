#!/bin/bash
# Reboot the host after a short delay so the HTTP response reaches the caller.
set -e
( sleep 3 && sudo /sbin/reboot ) >/dev/null 2>&1 &
disown
exit 0
