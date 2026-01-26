#!/usr/bin/env bash
set -euo pipefail

profile="$(grep -m1 '^Profile=' /var/lib/power-profiles-daemon/state.ini 2>/dev/null | cut -d= -f2)"
profile="${profile:-balanced}"

state="/run/user/$(id -u)/refresh-rate-power-profile.last"
if [ -r "$state" ] && [ "$(cat "$state")" = "$profile" ]; then
  exit 0
fi
printf '%s\n' "$profile" > "$state"

runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
if [ -z "${NIRI_SOCKET:-}" ]; then
  for sock in "$runtime_dir"/niri.wayland-*.sock; do
    [ -S "$sock" ] || continue
    export NIRI_SOCKET="$sock"
    break
  done
fi
timeout 1s niri msg outputs >/dev/null 2>&1 || exit 0

if [ "$profile" = "power-saver" ]; then
  timeout 2s niri msg output eDP-1 vrr off || true
  timeout 2s niri msg output eDP-1 mode 3200x2000@60.001 || true
else
  timeout 2s niri msg output eDP-1 mode 3200x2000@165.002 || true
  timeout 2s niri msg output eDP-1 vrr on --on-demand || true
fi
