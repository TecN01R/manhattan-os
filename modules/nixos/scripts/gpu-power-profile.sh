#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

log() {
  echo "gpu-power-profile: $*"
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

systemctl_cmd="/run/current-system/sw/bin/systemctl"
have_systemctl=0
if [ -x "$systemctl_cmd" ]; then
  have_systemctl=1
fi

stop_nvidia_powerd() {
  if [ "$have_systemctl" = "1" ]; then
    "$systemctl_cmd" stop nvidia-powerd.service 2>/dev/null || true
  fi
}

start_nvidia_powerd() {
  if [ "$have_systemctl" = "1" ]; then
    "$systemctl_cmd" start nvidia-powerd.service 2>/dev/null || true
  fi
}

get_nvidia_devices() {
  for dev_path in /sys/bus/pci/devices/*; do
    [ -f "$dev_path/vendor" ] || continue
    vendor="$(<"$dev_path/vendor")"
    [ "$vendor" = "0x10de" ] || continue
    class="$(<"$dev_path/class")"
    case "$class" in
      0x03*|0x0403) ;;
      *) continue ;;
    esac
    echo "$dev_path"
  done
}

if [ "$low_power" = "1" ]; then
  stop_nvidia_powerd

  mapfile -t devices < <(get_nvidia_devices)
  if [ "${#devices[@]}" -eq 0 ]; then
    log "no NVIDIA devices found; nothing to disable"
    exit 0
  fi

  for dev in "${devices[@]}"; do
    addr="${dev##*/}"
    if [ -w "$dev/driver/unbind" ]; then
      if ! echo "$addr" > "$dev/driver/unbind"; then
        log "unbind failed: $addr"
      fi
    fi
    if [ -w "$dev/power/control" ]; then
      echo auto > "$dev/power/control" || true
    fi
  done

  for dev in "${devices[@]}"; do
    if [ -w "$dev/remove" ]; then
      if ! echo 1 > "$dev/remove"; then
        log "remove failed: ${dev##*/}"
      fi
    fi
  done
  log "nvidia devices removed"
else
  if [ -w /sys/bus/pci/rescan ]; then
    echo 1 > /sys/bus/pci/rescan
  fi

  sleep 1

  for dev in $(get_nvidia_devices); do
    if [ -w "$dev/power/control" ]; then
      echo on > "$dev/power/control" || true
    fi
  done

  start_nvidia_powerd
  log "nvidia devices rescanned"
fi
