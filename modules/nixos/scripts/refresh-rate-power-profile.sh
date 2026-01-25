#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

log() {
  echo "refresh-rate-power-profile: $*"
}

runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
if [ -z "${NIRI_SOCKET:-}" ]; then
  for sock in "$runtime_dir"/niri.wayland-*.sock; do
    [ -S "$sock" ] || continue
    export NIRI_SOCKET="$sock"
    break
  done
fi
if [ -z "${WAYLAND_DISPLAY:-}" ]; then
  for sock in "$runtime_dir"/wayland-*; do
    [ -S "$sock" ] || continue
    export WAYLAND_DISPLAY="${sock##*/}"
    break
  done
fi
log "NIRI_SOCKET='${NIRI_SOCKET:-unset}' WAYLAND_DISPLAY='${WAYLAND_DISPLAY:-unset}'"

niri_msg() {
  timeout 2s niri msg "$@" 2>/dev/null
}

if ! niri_msg outputs >/dev/null 2>&1; then
  log "niri not available"
  exit 0
fi

output="eDP-1"
outputs_json="$(niri_msg -j outputs || true)"
if [ -z "$outputs_json" ]; then
  log "no outputs JSON"
  exit 0
fi
if ! echo "$outputs_json" | jq -e --arg output "$output" 'has($output)' >/dev/null; then
  output="$(echo "$outputs_json" | jq -r 'keys[] | select(startswith("eDP-") or startswith("LVDS"))' | head -n 1)"
  if [ -z "$output" ]; then
    log "no internal output found"
    exit 0
  fi
  log "using output=$output"
fi

profile="balanced"
if [ -r /var/lib/power-profiles-daemon/state.ini ]; then
  while IFS='=' read -r key value; do
    if [ "$key" = "Profile" ]; then
      profile="$value"
      break
    fi
  done < /var/lib/power-profiles-daemon/state.ini
fi

low_power=0
if [ "$profile" = "power-saver" ]; then
  low_power=1
fi
log "profile=$profile low_power=$low_power"

desired_refresh=165000
if [ "$low_power" = "1" ]; then
  desired_refresh=60000
fi
log "desired_refresh=$desired_refresh"

format_mode() {
  local width="$1"
  local height="$2"
  local refresh="$3"
  local whole=$((refresh / 1000))
  local frac=$((refresh % 1000))
  printf "%dx%d@%d.%03d" "$width" "$height" "$whole" "$frac"
}

max_attempts=3
attempt=1
while [ "$attempt" -le "$max_attempts" ]; do
  outputs_json="$(niri_msg -j outputs || true)"
  if [ -z "$outputs_json" ]; then
    log "no outputs JSON"
    exit 0
  fi
  if ! echo "$outputs_json" | jq -e --arg output "$output" 'has($output)' >/dev/null; then
    log "output $output missing"
    exit 0
  fi

  current_mode_index="$(echo "$outputs_json" | jq -r --arg output "$output" '.[$output].current_mode')"
  current_mode_fields="$(echo "$outputs_json" | jq -r --arg output "$output" '.[$output].modes[$current_mode] | "\(.width) \(.height) \(.refresh_rate)"' --argjson current_mode "$current_mode_index")"
  read -r current_width current_height current_refresh <<EOF
$current_mode_fields
EOF
  current_mode="$(format_mode "$current_width" "$current_height" "$current_refresh")"

  mode_fields="$(echo "$outputs_json" | jq -r --arg output "$output" --argjson target "$desired_refresh" '
    .[$output].modes as $modes
    | ($modes
        | map(.refresh_rate | tonumber)
        | map({rate: ., diff: (.-$target | abs)})
        | sort_by(.diff, .rate)
        | .[0].rate) as $best
    | ($modes | map(select((.refresh_rate | tonumber) == $best)) | .[0] // empty)
    | "\(.width) \(.height) \(.refresh_rate)"')"

  if [ -z "$mode_fields" ]; then
    log "no modes available for $output"
    break
  fi

  read -r target_width target_height target_refresh <<EOF
$mode_fields
EOF
  target_mode="$(format_mode "$target_width" "$target_height" "$target_refresh")"
  if [ "$target_refresh" != "$desired_refresh" ]; then
    log "desired refresh $desired_refresh not available, using $target_refresh"
  fi

  if [ "$current_mode" = "$target_mode" ]; then
    log "$output already at $current_mode"
    break
  fi

  log "switching $output from $current_mode to $target_mode"
  niri_msg output "$output" mode "$target_mode" || true

  attempt=$((attempt + 1))
  sleep 0.2
done

vrr_supported="$(echo "$outputs_json" | jq -r --arg output "$output" '.[$output].vrr_supported')"
if [ "$vrr_supported" = "true" ]; then
  if [ "$low_power" = "1" ]; then
    log "setting $output vrr off"
    niri_msg output "$output" vrr off || true
  else
    log "setting $output vrr on-demand"
    niri_msg output "$output" vrr on --on-demand || true
  fi
fi
