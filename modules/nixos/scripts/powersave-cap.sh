#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

log() {
  echo "powersave-cap: $*"
}

get_profile() {
  local profile=""
  if [ -r /etc/tuned/ppd_base_profile ]; then
    profile="$(cat /etc/tuned/ppd_base_profile 2>/dev/null || true)"
  fi
  profile="$(printf '%s' "$profile" | tr -d '[:space:]')"
  printf '%s\n' "$profile"
}

profile="$(get_profile)"
if [ -z "$profile" ]; then
  log "profile missing; skipping"
  exit 0
fi

log "profile=$profile"

low_power=0
if [ "$profile" = "power-saver" ]; then
  low_power=1
fi
log "low_power=$low_power"

psys_dir=""
for candidate in /sys/class/powercap/intel-rapl:* /sys/devices/virtual/powercap/intel-rapl:*; do
  [ -d "$candidate" ] || continue
  if [ -r "$candidate/name" ] && [ "$(cat "$candidate/name")" = "psys" ]; then
    psys_dir="$candidate"
    break
  fi
done

if [ -z "$psys_dir" ]; then
  log "psys not available; skipping"
  exit 0
fi

psys_long_uw=45000000
psys_short_uw=60000000
baseline_file="/run/powersave-cap.psys"

read_current_limits() {
  local long_path="$psys_dir/constraint_0_power_limit_uw"
  local short_path="$psys_dir/constraint_1_power_limit_uw"
  if [ ! -r "$long_path" ] || [ ! -r "$short_path" ]; then
    return 1
  fi
  current_long="$(cat "$long_path")"
  current_short="$(cat "$short_path")"
  return 0
}

write_limit() {
  local idx="$1"
  local value="$2"
  local label="$3"
  local path="$psys_dir/constraint_${idx}_power_limit_uw"
  if [ -w "$path" ]; then
    echo "$value" > "$path"
    log "$label set to $value"
  else
    log "$label not writable: $path"
  fi
}

if [ "$low_power" = "1" ]; then
  if [ ! -f "$baseline_file" ]; then
    if read_current_limits; then
      printf '%s %s\n' "$current_long" "$current_short" > "$baseline_file"
    fi
  fi
  write_limit 0 "$psys_long_uw" "psys long_term"
  write_limit 1 "$psys_short_uw" "psys short_term"
else
  if [ -f "$baseline_file" ]; then
    read -r baseline_long baseline_short < "$baseline_file" || true
    if [ -n "${baseline_long:-}" ] && [ -n "${baseline_short:-}" ]; then
      write_limit 0 "$baseline_long" "psys long_term"
      write_limit 1 "$baseline_short" "psys short_term"
      rm -f "$baseline_file"
    fi
  fi
fi
