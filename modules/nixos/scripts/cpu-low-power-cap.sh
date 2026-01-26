#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

log() {
  echo "cpu-low-power-cap: $*"
}

get_profile() {
  local profile=""
  if command -v powerprofilesctl >/dev/null 2>&1; then
    profile="$(powerprofilesctl get 2>/dev/null || true)"
  fi
  if [ -z "$profile" ] && [ -r /etc/tuned/ppd_base_profile ]; then
    profile="$(cat /etc/tuned/ppd_base_profile 2>/dev/null || true)"
  fi
  if [ -z "$profile" ] && [ -r /var/lib/power-profiles-daemon/state.ini ]; then
    while IFS='=' read -r key value; do
      if [ "$key" = "Profile" ]; then
        profile="$value"
        break
      fi
    done < /var/lib/power-profiles-daemon/state.ini
  fi
  profile="$(printf '%s' "$profile" | tr -d '[:space:]')"
  if [ -z "$profile" ]; then
    profile="balanced"
  fi
  printf '%s\n' "$profile"
}

profile="$(get_profile)"

log "profile=$profile"

low_power=0
if [ "$profile" = "power-saver" ]; then
  low_power=1
fi
log "low_power=$low_power"

rapl_dir=""
for candidate in /sys/class/powercap/intel-rapl:0 /sys/devices/virtual/powercap/intel-rapl:0; do
  if [ -d "$candidate" ]; then
    rapl_dir="$candidate"
    break
  fi
done

if [ -z "$rapl_dir" ]; then
  log "intel-rapl not available; skipping"
else
  pl1_uw=20000000
  pl2_uw=30000000
  baseline_pl1_uw=105000000
  baseline_pl2_uw=162000000

  write_limit() {
    local constraint="$1"
    local value="$2"
    local label=$((constraint + 1))
    local path="$rapl_dir/constraint_${constraint}_power_limit_uw"
    if [ -w "$path" ] && [ -n "$value" ]; then
      echo "$value" > "$path"
      log "PL${label} set to $value"
    fi
  }

  if [ "$low_power" = "1" ]; then
    write_limit 0 "$pl1_uw"
    write_limit 1 "$pl2_uw"
  else
    write_limit 0 "$baseline_pl1_uw"
    write_limit 1 "$baseline_pl2_uw"
    log "restored baseline limits"
  fi
fi

nvidia_driver="/sys/bus/pci/drivers/nvidia"
if [ -d "$nvidia_driver" ]; then
  nvidia_power="on"
  if [ "$low_power" = "1" ]; then
    nvidia_power="auto"
  fi
  for dev_path in /sys/bus/pci/devices/*; do
    [ -f "$dev_path/vendor" ] || continue
    vendor="$(cat "$dev_path/vendor")"
    [ "$vendor" = "0x10de" ] || continue
    class="$(cat "$dev_path/class")"
    case "$class" in
      0x03*) ;;
      *) continue ;;
    esac

    if [ -w "$dev_path/power/control" ]; then
      echo "$nvidia_power" > "$dev_path/power/control" || true
    fi
  done
  log "nvidia power control set to $nvidia_power"
fi
