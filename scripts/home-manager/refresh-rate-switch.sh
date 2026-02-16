#!/usr/bin/env bash
set -euo pipefail

profile=""
if [ -r /var/lib/power-profiles-daemon/state.ini ]; then
  profile="$(sed -n 's/^Profile=//p' /var/lib/power-profiles-daemon/state.ini | head -n1 || true)"
fi
[ -n "$profile" ] || profile="balanced"

runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
state="$runtime_dir/refresh-rate-switch.last-profile"
[ "$profile" = "$(cat "$state" 2>/dev/null || true)" ] && exit 0

case "$profile" in
  power-saver)
    mode="${REFRESH_RATE_LOW_MODE:-3200x2000@60}"
    label="60Hz"
    ;;
  *)
    mode="${REFRESH_RATE_HIGH_MODE:-3200x2000@165+vrr}"
    label="165Hz + VRR on"
    ;;
esac

command -v gnome-randr >/dev/null 2>&1 || exit 0

query=""
i=0
while [ "$i" -lt 100 ]; do
  query="$(gnome-randr query 2>/dev/null || true)"
  [ -n "$query" ] && break
  i=$((i + 1))
  sleep 0.1
done
[ -n "$query" ] || exit 0

connector="${REFRESH_RATE_CONNECTOR:-eDP-1}"
fallback_connector="$(printf '%s\n' "$query" | sed -n '/:/!s/^\([A-Za-z0-9._-]\+\) .*/\1/p' | head -n1 || true)"

apply_mode() {
  local target_connector="$1"
  local target_mode="$2"
  gnome-randr modify "$target_connector" --mode "$target_mode" --persistent >/dev/null
}

echo "refresh-rate-switch: profile=$profile mode=$mode connector=$connector" >&2
if ! apply_mode "$connector" "$mode" 2>/dev/null; then
  if [ -n "$fallback_connector" ] && [ "$fallback_connector" != "$connector" ]; then
    connector="$fallback_connector"
    if ! apply_mode "$connector" "$mode" 2>/dev/null; then
      if [ "$mode" != "${mode%+vrr}" ] && apply_mode "$connector" "${mode%+vrr}" 2>/dev/null; then
        mode="${mode%+vrr}"
        label="165Hz"
      else
        exit 0
      fi
    fi
  elif [ "$mode" != "${mode%+vrr}" ] && apply_mode "$connector" "${mode%+vrr}" 2>/dev/null; then
    mode="${mode%+vrr}"
    label="165Hz"
  else
    exit 0
  fi
fi

printf '%s\n' "$profile" >"$state"

notify-send -a "Refresh Rate Script" -i video-display \
  "Display profile changed" "$connector: $label" || true
