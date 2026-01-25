#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

log() {
  echo "cpu-low-power-cap: $*"
}

profile="balanced"
if [ -r /var/lib/power-profiles-daemon/state.ini ]; then
  while IFS='=' read -r key value; do
    if [ "$key" = "Profile" ]; then
      profile="$value"
      break
    fi
  done < /var/lib/power-profiles-daemon/state.ini
fi

log "profile=$profile"

low_power=0
if [ "$profile" = "power-saver" ]; then
  low_power=1
fi
log "low_power=$low_power"

if [ "$low_power" = "1" ]; then
  all_cpus=()
  for cpu_dir in /sys/devices/system/cpu/cpu[0-9]*; do
    cpu_id="${cpu_dir##*cpu}"
    all_cpus+=("$cpu_id")
  done

  keep_p_count=2
  keep_e_count=8
  cpu0_id="0"
  prefer_p_key=""
  prefer_e_key=""

  core_key_for_cpu() {
    local cpu_id="$1"
    local core_id_file="/sys/devices/system/cpu/cpu${cpu_id}/topology/core_id"
    local package_id_file="/sys/devices/system/cpu/cpu${cpu_id}/topology/physical_package_id"
    local core_id=""
    local package_id=""
    if [ -f "$core_id_file" ]; then
      core_id="$(cat "$core_id_file")"
    fi
    if [ -f "$package_id_file" ]; then
      package_id="$(cat "$package_id_file")"
    fi
    if [ -n "$core_id" ]; then
      [ -z "$package_id" ] && package_id="0"
      echo "${package_id}:${core_id}"
    else
      echo ""
    fi
  }

  list_sorted_keys() {
    local key
    for key in "$@"; do
      printf '%s %s\n' "${core_first_cpu[$key]}" "$key"
    done | sort -n | while read -r _cpu key; do
      [ -n "$key" ] && printf '%s\n' "$key"
    done
  }

  select_core_keys() {
    local target_count="$1"
    local prefer_key="$2"
    shift 2
    local -A seen=()
    local selected=()
    local key
    if [ -n "$prefer_key" ]; then
      seen["$prefer_key"]=1
      selected+=("$prefer_key")
    fi
    for key in $(list_sorted_keys "$@"); do
      if [ -n "$prefer_key" ] && [ "$key" = "$prefer_key" ]; then
        continue
      fi
      if [ -z "${seen[$key]+x}" ]; then
        seen["$key"]=1
        selected+=("$key")
      fi
      [ "${#selected[@]}" -ge "$target_count" ] && break
    done
    printf '%s\n' "${selected[@]}"
  }

  add_selected_key() {
    local key="$1"
    if [ -z "$key" ]; then
      return 0
    fi
    if [ -z "${selected_key_set[$key]+x}" ]; then
      selected_key_set["$key"]=1
      selected_keys+=("$key")
    fi
  }

  declare -A core_max_freq=()
  declare -A core_first_cpu=()
  for cpu_id in "${all_cpus[@]}"; do
    key="$(core_key_for_cpu "$cpu_id")"
    if [ -z "$key" ]; then
      log "missing core_id for cpu${cpu_id}; skipping"
      exit 0
    fi
    freq_file="/sys/devices/system/cpu/cpu${cpu_id}/cpufreq/cpuinfo_max_freq"
    if [ ! -r "$freq_file" ]; then
      log "missing cpuinfo_max_freq for cpu${cpu_id}; skipping"
      exit 0
    fi
    freq="$(cat "$freq_file")"
    if [ -z "${core_max_freq[$key]+x}" ] || [ "$freq" -gt "${core_max_freq[$key]}" ]; then
      core_max_freq["$key"]="$freq"
    fi
    if [ -z "${core_first_cpu[$key]+x}" ] || [ "$cpu_id" -lt "${core_first_cpu[$key]}" ]; then
      core_first_cpu["$key"]="$cpu_id"
    fi
  done

  min_freq=""
  max_freq=""
  for key in "${!core_max_freq[@]}"; do
    freq="${core_max_freq[$key]}"
    if [ -z "$min_freq" ] || [ "$freq" -lt "$min_freq" ]; then
      min_freq="$freq"
    fi
    if [ -z "$max_freq" ] || [ "$freq" -gt "$max_freq" ]; then
      max_freq="$freq"
    fi
  done
  if [ -z "$min_freq" ] || [ -z "$max_freq" ] || [ "$min_freq" -eq "$max_freq" ]; then
    log "unable to derive P/E split from max freq; skipping"
    exit 0
  fi
  threshold=$(( (min_freq + max_freq) / 2 ))
  log "freq split min=$min_freq max=$max_freq threshold=$threshold"

  cpu0_key="$(core_key_for_cpu "$cpu0_id")"
  if [ -z "$cpu0_key" ]; then
    log "cpu0 core key unavailable; skipping"
    exit 0
  fi
  if [ -z "${core_max_freq[$cpu0_key]+x}" ]; then
    log "cpu0 core freq unavailable; skipping"
    exit 0
  fi
  if [ "${core_max_freq[$cpu0_key]}" -ge "$threshold" ]; then
    prefer_p_key="$cpu0_key"
  else
    prefer_e_key="$cpu0_key"
  fi

  p_core_keys=()
  e_core_keys=()
  for key in "${!core_max_freq[@]}"; do
    freq="${core_max_freq[$key]}"
    if [ "$freq" -ge "$threshold" ]; then
      p_core_keys+=("$key")
    else
      e_core_keys+=("$key")
    fi
  done

  keep_cpus=()
  if [ "$keep_p_count" -gt 0 ] && [ "${#p_core_keys[@]}" -lt "$keep_p_count" ]; then
    log "insufficient P cores detected; skipping"
    exit 0
  fi
  if [ "$keep_e_count" -gt 0 ] && [ "${#e_core_keys[@]}" -lt "$keep_e_count" ]; then
    log "insufficient E cores detected; skipping"
    exit 0
  fi

  selected_p_keys=()
  selected_e_keys=()
  if [ "$keep_p_count" -gt 0 ]; then
    mapfile -t selected_p_keys < <(select_core_keys "$keep_p_count" "$prefer_p_key" "${p_core_keys[@]}")
  fi
  if [ "$keep_e_count" -gt 0 ]; then
    mapfile -t selected_e_keys < <(select_core_keys "$keep_e_count" "$prefer_e_key" "${e_core_keys[@]}")
  fi

  declare -A selected_key_set=()
  selected_keys=()
  for key in "${selected_p_keys[@]}"; do
    add_selected_key "$key"
  done
  for key in "${selected_e_keys[@]}"; do
    add_selected_key "$key"
  done

  if [ "${#selected_keys[@]}" -eq 0 ]; then
    log "no cores selected; skipping"
    exit 0
  fi
  log "keeping cores: ${selected_keys[*]}"

  for cpu_id in "${all_cpus[@]}"; do
    key="$(core_key_for_cpu "$cpu_id")"
    if [ -n "${selected_key_set[$key]+x}" ]; then
      keep_cpus+=("$cpu_id")
    fi
  done

  log "keeping cpus: ${keep_cpus[*]}"

  for cpu_dir in /sys/devices/system/cpu/cpu[0-9]*; do
    cpu_id="${cpu_dir##*cpu}"
    online_file="$cpu_dir/online"
    [ -f "$online_file" ] || continue

    keep=0
    for keep_id in "${keep_cpus[@]}"; do
      if [ "$cpu_id" = "$keep_id" ]; then
        keep=1
        break
      fi
    done

    if [ "$keep" = "1" ]; then
      echo 1 > "$online_file" || true
    else
      echo 0 > "$online_file" || true
    fi
  done
  log "cpu online state updated"
else
  log "onlining all cpus"
  for online_file in /sys/devices/system/cpu/cpu[0-9]*/online; do
    echo 1 > "$online_file" || true
  done
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
