{ config, lib, pkgs, ... }:

let
  cfg = config.manhattan.nvidia;

  cpuLowPowerCap = pkgs.writeShellScript "cpu-low-power-cap" ''
    set -euo pipefail
    shopt -s nullglob

    export PATH="${lib.makeBinPath [ pkgs.coreutils pkgs.power-profiles-daemon ]}:$PATH"

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
      e_cores=()
      p_cores=()
      cpu0_type="unknown"
      for cpu_dir in /sys/devices/system/cpu/cpu[0-9]*; do
        cpu_id="''${cpu_dir##*cpu}"
        all_cpus+=("$cpu_id")
        core_type_file="$cpu_dir/topology/core_type"
        if [ -f "$core_type_file" ]; then
          core_type="$(cat "$core_type_file")"
          if [ "$core_type" = "0" ]; then
            e_cores+=("$cpu_id")
            [ "$cpu_id" = "0" ] && cpu0_type="e"
          else
            p_cores+=("$cpu_id")
            [ "$cpu_id" = "0" ] && cpu0_type="p"
          fi
        fi
      done

      keep_p_count=2
      keep_e_count=4

      add_unique() {
        local value="$1"
        local existing
        for existing in "''${keep_cpus[@]}"; do
          if [ "$existing" = "$value" ]; then
            return 0
          fi
        done
        keep_cpus+=("$value")
      }

      keep_cpus=()
      if [ "''${#e_cores[@]}" -gt 0 ] || [ "''${#p_cores[@]}" -gt 0 ]; then
        if [ "$cpu0_type" != "p" ]; then
          found_cpu0=0
          for cpu_id in "''${e_cores[@]}"; do
            if [ "$cpu_id" = "0" ]; then
              found_cpu0=1
              break
            fi
          done
          if [ "$found_cpu0" = "0" ]; then
            e_cores+=("0")
          fi
        fi

        if [ "''${#p_cores[@]}" -gt 0 ]; then
          count=0
          for cpu_id in $(printf '%s\n' "''${p_cores[@]}" | sort -n); do
            add_unique "$cpu_id"
            count=$((count + 1))
            [ "$count" -ge "$keep_p_count" ] && break
          done
        fi

        if [ "''${#e_cores[@]}" -gt 0 ]; then
          count=0
          for cpu_id in $(printf '%s\n' "''${e_cores[@]}" | sort -n); do
            add_unique "$cpu_id"
            count=$((count + 1))
            [ "$count" -ge "$keep_e_count" ] && break
          done
        fi
      else
        count=0
        for cpu_id in $(printf '%s\n' "''${all_cpus[@]}" | sort -n); do
          add_unique "$cpu_id"
          count=$((count + 1))
          [ "$count" -ge $((keep_p_count + keep_e_count)) ] && break
        done
      fi

      expand_cpu_list() {
        local list="$1"
        local part
        local start
        local end
        IFS=',' read -r -a parts <<< "$list"
        for part in "''${parts[@]}"; do
          [ -z "$part" ] && continue
          if [[ "$part" == *-* ]]; then
            start="''${part%-*}"
            end="''${part#*-}"
            for i in $(seq "$start" "$end"); do
              echo "$i"
            done
          else
            echo "$part"
          fi
        done
      }

      expanded_cpus=()
      for keep_id in "''${keep_cpus[@]}"; do
        siblings_file="/sys/devices/system/cpu/cpu''${keep_id}/topology/thread_siblings_list"
        if [ -f "$siblings_file" ]; then
          siblings_list="$(cat "$siblings_file")"
          while read -r sibling_id; do
            expanded_cpus+=("$sibling_id")
          done < <(expand_cpu_list "$siblings_list")
        else
          expanded_cpus+=("$keep_id")
        fi
      done
      keep_cpus=("''${expanded_cpus[@]}")

      log "keeping cpus: ''${keep_cpus[*]}"

      for cpu_dir in /sys/devices/system/cpu/cpu[0-9]*; do
        cpu_id="''${cpu_dir##*cpu}"
        online_file="$cpu_dir/online"
        [ -f "$online_file" ] || continue

        keep=0
        for keep_id in "''${keep_cpus[@]}"; do
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
  '';

  niriPowerDisplay = pkgs.writeShellScript "niri-power-display" ''
    set -euo pipefail
    shopt -s nullglob

    export PATH="${lib.makeBinPath [ pkgs.coreutils pkgs.power-profiles-daemon pkgs.niri pkgs.jq ]}:$PATH"

    niri_msg() {
      timeout 2s niri msg "$@" 2>/dev/null
    }

    if ! niri_msg outputs >/dev/null 2>&1; then
      exit 0
    fi

    output="eDP-1"
    outputs_json="$(niri_msg -j outputs || true)"
    if [ -z "$outputs_json" ]; then
      exit 0
    fi
    if ! echo "$outputs_json" | jq -e --arg output "$output" 'has($output)' >/dev/null; then
      exit 0
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

    format_mode() {
      local width="$1"
      local height="$2"
      local refresh="$3"
      local whole=$((refresh / 1000))
      local frac=$((refresh % 1000))
      printf "%dx%d@%d.%03d" "$width" "$height" "$whole" "$frac"
    }

    current_mode_index="$(echo "$outputs_json" | jq -r --arg output "$output" '.[$output].current_mode')"
    current_mode_fields="$(echo "$outputs_json" | jq -r --arg output "$output" '.[$output].modes[$current_mode] | "\(.width) \(.height) \(.refresh_rate)"' --argjson current_mode "$current_mode_index")"
    read -r current_width current_height current_refresh <<EOF
$current_mode_fields
EOF
    current_mode="$(format_mode "$current_width" "$current_height" "$current_refresh")"

    if [ "$low_power" = "1" ]; then
      mode_fields="$(echo "$outputs_json" | jq -r --arg output "$output" --argjson w "$current_width" --argjson h "$current_height" '
        .[$output].modes
        | map(select(.width==$w and .height==$h))
        | sort_by(.refresh_rate)
        | .[0] // empty
        | "\(.width) \(.height) \(.refresh_rate)"')"
    else
      mode_fields="$(echo "$outputs_json" | jq -r --arg output "$output" --argjson w "$current_width" --argjson h "$current_height" '
        .[$output].modes
        | map(select(.width==$w and .height==$h))
        | sort_by(.refresh_rate)
        | .[-1] // empty
        | "\(.width) \(.height) \(.refresh_rate)"')"
    fi

    if [ -n "$mode_fields" ]; then
      read -r target_width target_height target_refresh <<EOF
$mode_fields
EOF
      target_mode="$(format_mode "$target_width" "$target_height" "$target_refresh")"

      if [ "$current_mode" != "$target_mode" ]; then
        niri_msg output "$output" mode "$target_mode" || true
      fi
    fi

    vrr_supported="$(echo "$outputs_json" | jq -r --arg output "$output" '.[$output].vrr_supported')"
    if [ "$vrr_supported" = "true" ]; then
      if [ "$low_power" = "1" ]; then
        niri_msg output "$output" vrr off || true
      else
        niri_msg output "$output" vrr on --on-demand || true
      fi
    fi
  '';
in
{
  options.manhattan.nvidia.enable = lib.mkEnableOption "NVIDIA drivers";

  config = lib.mkIf cfg.enable {
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia = {
      modesetting.enable = true;
      powerManagement.enable = false;
      powerManagement.finegrained = false;
      dynamicBoost.enable = true;
      open = true;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.latest;
    };

    systemd.services.cpu-low-power-cap = {
      description = "Adjust CPU and NVIDIA for power profile";
      after = [ "power-profiles-daemon.service" "upower.service" ];
      unitConfig.StartLimitIntervalSec = "0";
      serviceConfig = {
        Type = "oneshot";
        TimeoutStartSec = "10s";
        CPUAffinity = "0";
        ExecStart = cpuLowPowerCap;
      };
    };

    systemd.paths.cpu-low-power-cap = {
      wantedBy = [ "multi-user.target" ];
      unitConfig.StartLimitIntervalSec = "0";
      pathConfig = {
        PathChanged = "/var/lib/power-profiles-daemon/state.ini";
        PathExists = "/var/lib/power-profiles-daemon/state.ini";
        Unit = "cpu-low-power-cap.service";
      };
    };

    systemd.user.services.niri-power-display = {
      description = "Adjust niri output mode for power profile";
      wantedBy = [ "default.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = niriPowerDisplay;
      };
    };

    systemd.user.paths.niri-power-display = {
      wantedBy = [ "default.target" ];
      pathConfig = {
        PathChanged = "/var/lib/power-profiles-daemon/state.ini";
        PathExists = "/var/lib/power-profiles-daemon/state.ini";
        Unit = "niri-power-display.service";
      };
    };
  };
}
