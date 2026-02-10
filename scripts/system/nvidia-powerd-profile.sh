#!/usr/bin/env bash
set -eu

profile=""
if [ -r /var/lib/power-profiles-daemon/state.ini ]; then
  while IFS='=' read -r key value; do
    if [ "$key" = "Profile" ]; then
      profile="$value"
      break
    fi
  done < /var/lib/power-profiles-daemon/state.ini
fi
[ -n "$profile" ] || profile="balanced"

if [ "$profile" = "power-saver" ]; then
  systemctl stop nvidia-powerd.service
else
  systemctl start nvidia-powerd.service
fi
