#!/usr/bin/env bash
set -eu

if [ "$#" -lt 1 ]; then
  echo "usage: gamescope-auto <command> [args...]" >&2
  exit 2
fi

socket="${NIRI_SOCKET:-}"
if [ -z "$socket" ] && [ -n "${XDG_RUNTIME_DIR:-}" ]; then
  for s in "$XDG_RUNTIME_DIR"/niri.wayland-*.sock; do
    [ -S "$s" ] || continue
    socket="$s"
    break
  done
fi

width=""
height=""
refresh_millihz=""

if [ -n "$socket" ]; then
  output_json="$(NIRI_SOCKET="$socket" /run/current-system/sw/bin/niri msg --json focused-output 2>/dev/null || true)"
  if [ -n "$output_json" ]; then
    width="$(printf '%s\n' "$output_json" | jq -r '.modes[.current_mode].width // empty')"
    height="$(printf '%s\n' "$output_json" | jq -r '.modes[.current_mode].height // empty')"
    refresh_millihz="$(printf '%s\n' "$output_json" | jq -r '.modes[.current_mode].refresh_rate // empty')"
  fi
fi

[ -n "$width" ] || width="${GAMESCOPE_WIDTH:-1920}"
[ -n "$height" ] || height="${GAMESCOPE_HEIGHT:-1080}"
[ -n "$refresh_millihz" ] || refresh_millihz="${GAMESCOPE_REFRESH_MILLIHZ:-60000}"

refresh_hz=$(( (refresh_millihz + 500) / 1000 ))

exec gamescope \
  -f \
  -W "$width" -H "$height" \
  -w "$width" -h "$height" \
  -r "$refresh_hz" \
  -- "$@"
