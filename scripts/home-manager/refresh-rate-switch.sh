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

state="$XDG_RUNTIME_DIR/refresh-rate-switch.last-profile"
[ "$profile" = "$(cat "$state" 2>/dev/null || true)" ] && exit 0

case "$profile" in
  power-saver)
    rate="3200x2000@60.001"
    vrr="off"
    label="60Hz + VRR off"
    ;;
  *)
    rate="3200x2000@165.002"
    vrr="on-demand"
    label="165Hz + VRR on-demand"
    ;;
esac

socket=""
i=0
while [ "$i" -lt 100 ]; do
  for s in "$XDG_RUNTIME_DIR"/niri.wayland-*.sock; do
    [ -S "$s" ] && socket="$s" && break
  done
  [ -n "$socket" ] && break
  i=$((i + 1))
  sleep 0.1
done
[ -n "$socket" ] || exit 0

niri() { NIRI_SOCKET="$socket" /run/current-system/sw/bin/niri msg output "eDP-1" "$@"; }

echo "refresh-rate-switch: profile=$profile rate=$rate vrr=$vrr" >&2
niri mode "$rate"
niri vrr "$vrr"

printf '%s\n' "$profile" > "$state"

notify-send -a "Refresh Rate Script" -h string:desktop-entry:dms \
  -i video-display "Display profile changed" "eDP-1: $label" || true
